// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../services/desktop_app_lock_service.dart';
import '../services/desktop_window_activity.dart';

/// Full-screen lock overlay shown over the entire desktop shell while
/// [DesktopAppLockService.locked] is true. Auto-prompts Touch ID once per lock
/// — as soon as the window is on screen AND focused — and exposes a manual
/// unlock button as a retry path.
class DesktopLockOverlay extends StatefulWidget {
  const DesktopLockOverlay({
    super.key,
    required this.service,
    this.windowVisible,
    this.windowFocused,
  });

  final DesktopAppLockService service;

  /// Окно на экране (не в трее и не свёрнуто). `null` — считаем, что на
  /// экране.
  final ValueListenable<bool>? windowVisible;

  /// Фокус окна. `null` — общий [DesktopWindowActivity.focused].
  final ValueListenable<bool>? windowFocused;

  @override
  State<DesktopLockOverlay> createState() => _DesktopLockOverlayState();
}

class _DesktopLockOverlayState extends State<DesktopLockOverlay> {
  bool _busy = false;
  /// Вид ошибки, а не её текст: подпись собирается в [build], иначе она
  /// застыла бы на языке, который стоял в момент неудачи.
  _LockError? _error;
  bool _autoPrompted = false;

  ValueListenable<bool> get _focused =>
      widget.windowFocused ?? DesktopWindowActivity.focused;

  /// 🔴 TOUCH ID — ТОЛЬКО ПЕРЕД ГЛАЗАМИ (01.10.2026). Замок взводится и
  /// тогда, когда окно спрятано или человек работает в другом приложении, а
  /// запрос отпечатка всплывал сразу — системным окном поверх чужой работы,
  /// про приложение, которого сейчас даже не видно. Теперь запрос ждёт, пока
  /// окно окажется на экране и в фокусе, и уходит один раз на каждый замок:
  /// потеря фокуса на время системного окна отпечатка второго не вызывает.
  bool get _windowActive =>
      _focused.value && (widget.windowVisible?.value ?? true);

  void _maybeAutoPrompt() {
    if (!mounted || _autoPrompted || !_windowActive) return;
    _autoPrompted = true;
    unawaited(_unlock());
  }

  @override
  void initState() {
    super.initState();
    _focused.addListener(_maybeAutoPrompt);
    widget.windowVisible?.addListener(_maybeAutoPrompt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrompt());
  }

  @override
  void dispose() {
    _focused.removeListener(_maybeAutoPrompt);
    widget.windowVisible?.removeListener(_maybeAutoPrompt);
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.service.requestUnlock(
      reason: AppLocalizations.of(context)!.desktopUnlockPrompt,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        // F-17: tell the truth about WHY. A missing platform authenticator is
        // not a failed attempt, and repeating "could not verify" would send
        // the user in circles retrying something that can never succeed.
        // Advice must be actionable from where the user is STANDING. This
        // screen is a locked overlay: settings, and therefore the support
        // chat, are behind the very lock that is failing. Pointing at support
        // from here would send someone in a circle, so the way out named here
        // is the phone — which is reachable. The lock itself is NOT shared
        // with the phone (it lives in this computer's preferences), so the
        // phone is a way to reach support, not a switch (17.09.2026).
        _error = widget.service.unlockUnavailable.value
            ? _LockError.noService
            : _LockError.failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final supported = widget.service.biometricSupported.value;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.bg.withValues(alpha: 0.85),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(DSpace.xl2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: c.elevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.borderSubtle),
                    ),
                    child: Icon(
                      FluentIcons.lock_closed_24_regular,
                      size: 30,
                      color: c.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: DSpace.xl),
                  Text(
                    l10n.desktopLockedTitle,
                    style: DType.title.copyWith(color: c.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DSpace.s),
                  Text(
                    supported
                        ? l10n.desktopLockedTouchIdPrompt
                        : l10n.desktopLockedPasswordPrompt,
                    textAlign: TextAlign.center,
                    style: DType.body.copyWith(color: c.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: DSpace.m),
                    Text(
                      _error == _LockError.noService
                          ? l10n.desktopLockedNoService
                          : l10n.desktopLockedFailed,
                      textAlign: TextAlign.center,
                      style: DType.caption.copyWith(color: c.danger),
                    ),
                  ],
                  const SizedBox(height: DSpace.xl2),
                  DesktopButton(
                    label: _busy ? l10n.desktopLockedWaiting : l10n.desktopLockedUnlock,
                    kind: DButtonKind.tonal,
                    // E13: never gate unlock on biometric support — requestUnlock
                    // uses biometricOnly:false, so it falls back to the device
                    // password. Disabling this when Touch ID is absent locked the
                    // user out of their own app with no recourse.
                    onPressed: _busy ? null : _unlock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Что именно не получилось при разблокировке.
enum _LockError { failed, noService }

/// 🔴 ЗАМКИ ОКНА — НАД НАВИГАТОРОМ, А НЕ ВНУТРИ ГЛАВНОГО ЭКРАНА (30.09.2026).
///
/// Раньше оба замка («Вход в приложение» и Touch ID) рисовались внутри
/// главного экрана. А всё, что открывается поверх него, — просмотр фото,
/// видео и документов, окна посередине (набор восстановления!), диалоги,
/// окно отправки медиа, выдача ⌘K — маршруты корневого навигатора, то есть
/// ВЫШЕ главного экрана. Замок срабатывал по таймеру, а открытый документ
/// оставался поверх замка — с работающими кнопками.
///
/// Теперь замки стоят над навигатором, как на телефоне (`MaterialApp.builder`
/// в `main.dart`): поверх них из этого окна не рисуется ничто. Всё под замком
/// не получает ни фокуса (иначе набор продолжал бы уходить в поле ввода
/// переписки), ни нажатий, ни экранного диктора.
///
/// И форма дерева от замка НЕ ЗАВИСИТ: раньше запертое окно оборачивалось в
/// лишний `Stack`, и каждое запирание пересоздавало оболочку — открытый чат,
/// прокрутка и поиск терялись на каждом Touch ID.
class DesktopLockGate extends StatefulWidget {
  const DesktopLockGate({
    super.key,
    required this.locked,
    required this.child,
    this.layers = const <Widget>[],
    this.animate,
  });

  /// Заперто ли окно хоть одним замком.
  final bool locked;

  /// Навигатор приложения со всеми его маршрутами.
  final Widget child;

  /// Экраны замков и то, что разрешено поверх них, — сверху вниз по порядку.
  /// Дети `Stack`: у каждого свой ключ, чтобы смена одного замка не
  /// пересоздавала другой.
  final List<Widget> layers;

  /// Окно на экране. Скрытое окно не должно рисовать анимацию замка.
  final ValueListenable<bool>? animate;

  @override
  State<DesktopLockGate> createState() => _DesktopLockGateState();
}

class _DesktopLockGateState extends State<DesktopLockGate> {
  /// Где был фокус, когда окно заперли: после разблокировки он возвращается
  /// туда же — в недописанное сообщение, а не в никуда.
  FocusNode? _focusBeforeLock;

  @override
  void didUpdateWidget(DesktopLockGate old) {
    super.didUpdateWidget(old);
    if (!old.locked && widget.locked) {
      _focusBeforeLock = FocusManager.instance.primaryFocus;
    } else if (old.locked && !widget.locked) {
      final node = _focusBeforeLock;
      _focusBeforeLock = null;
      if (node != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (node.context != null && node.canRequestFocus) {
            node.requestFocus();
          }
        });
      }
    }
  }

  Widget _buildLayers() {
    if (!widget.locked || widget.layers.isEmpty) {
      return const SizedBox.shrink();
    }
    final Widget layers = Material(
      type: MaterialType.transparency,
      child: Stack(fit: StackFit.expand, children: widget.layers),
    );
    final animate = widget.animate;
    if (animate == null) return layers;
    return ValueListenableBuilder<bool>(
      valueListenable: animate,
      builder: (context, on, child) => TickerMode(enabled: on, child: child!),
      child: layers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(
            excluding: locked,
            // Под замком окно не движется (01.10.2026): слой замка почти
            // непрозрачен и размыт, а обои, рамки и статусы под ним
            // перерисовывали экран впустую. Флаг меняется, `TickerMode` стоит
            // всегда — переписка под замком не пересоздаётся.
            child: AbsorbPointer(
              absorbing: locked,
              child: TickerMode(enabled: !locked, child: widget.child),
            ),
          ),
        ),
        // Свой слой: поле пароля и подсказки кнопок замка ищут его среди
        // предков, а слой навигатора лежит ниже замка.
        IgnorePointer(
          ignoring: !locked,
          child: Overlay.wrap(child: _buildLayers()),
        ),
      ],
    );
  }
}

/// Каким звонком можно управлять поверх замка.
enum DesktopLockCallKind { incoming, direct, room }

/// Звонок поверх замка — только то, что нужно кнопкам.
@immutable
class DesktopLockCall {
  const DesktopLockCall({
    required this.kind,
    this.muted = false,
    this.video = false,
  });

  final DesktopLockCallKind kind;
  final bool muted;
  final bool video;
}

/// 🔴 ЗВОНОК ПОВЕРХ ЗАМКА — БЕЗ ИМЕНИ И ЛИЦА (30.09.2026).
///
/// Замок «Вход в приложение» раньше снимался на время звонка — правило
/// телефона, чтобы входящий можно было принять. Но снимался он целиком:
/// позвони на запертый компьютер — и открыта вся переписка. Теперь замок
/// остаётся, а поверх него — ровно управление звонком: ответить, отклонить,
/// микрофон, положить трубку. Кто на связи, замок не говорит — то же решение,
/// что у мини-окон: запертое приложение не показывает, с кем идёт разговор.
///
/// Нужна полоса только звонкам, живущим в главном окне: окна звонков ОС (Р1)
/// замок не накрывает вовсе.
class DesktopLockCallStrip extends StatelessWidget {
  const DesktopLockCallStrip({
    super.key,
    required this.call,
    this.onAccept,
    this.onDecline,
    this.onToggleMic,
    this.onEnd,
  });

  final DesktopLockCall call;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onToggleMic;

  /// Положить трубку; у созвона комнаты — выйти из него.
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final String label;
    final List<Widget> actions;
    switch (call.kind) {
      case DesktopLockCallKind.incoming:
        label = l10n.callRecordIncomingCall;
        actions = [
          DesktopButton(
            label: l10n.callDecline,
            kind: DButtonKind.danger,
            size: DButtonSize.small,
            onPressed: onDecline,
          ),
          DesktopButton(
            label: call.video ? l10n.desktopCallAnswerVideo : l10n.desktopCallAnswer,
            size: DButtonSize.small,
            onPressed: onAccept,
          ),
        ];
      case DesktopLockCallKind.direct:
      case DesktopLockCallKind.room:
        final room = call.kind == DesktopLockCallKind.room;
        label = room ? l10n.desktopCallInProgress : l10n.contactDetailsCall;
        actions = [
          DesktopButton(
            label: call.muted ? l10n.desktopCallMicOn : l10n.desktopCallMicOff,
            icon: call.muted
                ? FluentIcons.mic_off_24_regular
                : FluentIcons.mic_24_regular,
            kind: DButtonKind.tonal,
            size: DButtonSize.small,
            onPressed: onToggleMic,
          ),
          DesktopButton(
            label: room ? l10n.desktopCallLeaveCall : l10n.callControlEnd,
            icon: FluentIcons.call_end_24_regular,
            kind: DButtonKind.danger,
            size: DButtonSize.small,
            onPressed: onEnd,
          ),
        ];
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 56, left: DSpace.l, right: DSpace.l),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.s,
          ),
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(DRadii.lg),
            border: Border.all(color: c.borderSubtle),
            boxShadow: DShadows.floating,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DSpace.s,
            runSpacing: DSpace.s,
            children: [
              Icon(FluentIcons.call_24_filled, size: 18, color: c.voice),
              Text(label, style: DType.body.copyWith(color: c.textPrimary)),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
