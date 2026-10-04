// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../app/desktop_child_window_app.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';
import 'desktop_child_windows.dart';
import 'desktop_ui_prefs.dart';

/// Что показать в окошке уведомления. Уже с учётом приватности предпросмотра:
/// имя, текст и портрет сюда приходят, только если их можно показывать.
class DesktopNotificationCard {
  const DesktopNotificationCard({
    required this.title,
    required this.body,
    required this.payload,
    this.avatarPath,
    this.avatarSeed,
    this.canAct = false,
  });

  final String title;
  final String body;

  /// Куда ведёт щелчок — та же строка, что у системного уведомления.
  final String payload;
  final String? avatarPath;
  final String? avatarSeed;

  /// Показывать ли «Ответить» и «Прочитано» — то же правило, что у кнопок
  /// системного уведомления macOS: только когда отправитель назван
  /// (`notificationActionsAllowed`).
  final bool canAct;
}

class _Shown {
  _Shown(this.id, this.card, this.onTap);

  final String id;
  final ValueNotifier<DesktopNotificationCard> card;
  VoidCallback onTap;
  Future<void> Function(String text)? onReply;
  Future<void> Function()? onMarkRead;
  final ValueNotifier<bool> hovered = ValueNotifier<bool>(false);

  /// Человек печатает ответ: окошко не гаснет, пока не отправит или не
  /// передумает.
  final ValueNotifier<bool> replying = ValueNotifier<bool>(false);
  Timer? timer;
}

/// Уведомления в стиле Telegram — свои окошки в углу экрана (29.09.2026,
/// Р1, этап 5).
///
/// 🔴 Владелец (28.09): «уведомления почему-то как будто от Windows системные,
/// это неправильно, я хочу, чтобы были как в Telegram». Telegram Desktop на
/// Windows показывает свои окошки: портрет, имя, текст; щелчок открывает
/// переписку, окошко само гаснет, под мышью ждёт. Здесь так же:
/// * до трёх окошек стопкой в правом нижнем углу, новое — снизу;
/// * новое сообщение той же переписки обновляет её окошко, а не плодит новое;
/// * фокус не забирают: человек пишет в другой программе — и продолжает;
/// * не получилось — показывается системное уведомление, как раньше.
///
/// Только Windows: на macOS системные уведомления — привычный путь, и
/// Telegram для Mac пользуется ими же.
class DesktopNotificationWindows {
  DesktopNotificationWindows._();

  static final DesktopNotificationWindows instance =
      DesktopNotificationWindows._();

  static const int maxVisible = 3;
  static const Size size = Size(360, 84);
  static const Duration visibleFor = Duration(seconds: 6);

  /// Язык окна — тот же, что у приложения. Задаёт корень приложения.
  Locale? Function()? locale;
  Locale Function(List<Locale> deviceLocales)? resolveLocale;

  final List<_Shown?> _slots = List<_Shown?>.filled(maxVisible, null);
  int _seq = 0;

  /// 🔴 ВСЕ ДЕЛА СО СТОПКОЙ — ПО ОЧЕРЕДИ (29.09.2026, разбор Р1).
  ///
  /// Показ и гашение ждут окно ОС (открыть, закрыть, переставить), и между
  /// этими ожиданиями список мест менял другой показ или гашение: окошко,
  /// гаснущее по таймеру, двигало стопку, пока новое ещё открывалось, а
  /// неудачное открытие чистило место 0 — уже чужое. Окошко, потерявшее место,
  /// не гасло НИКОГДА: висело поверх всех окон до выхода из приложения.
  /// Теперь каждое дело начинается, когда закончилось предыдущее; первое —
  /// сразу, как и раньше.
  Future<void>? _tail;

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final previous = _tail;
    final run = previous == null ? op() : previous.then((_) => op());
    final tail = run.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return run;
  }

  /// Только Windows; в тестах площадку подменяют (см. правило CI о службах
  /// за `Platform.isX`: иначе на машине проверки код не исполняется вовсе).
  @visibleForTesting
  static bool debugForceWindows = false;

  bool get enabled =>
      (Platform.isWindows || debugForceWindows) &&
      DesktopUiPrefs.customNotifications.value;

  /// Показать окошко. `false` — своё окошко не вышло, покажите системное.
  ///
  /// [onReply] и [onMarkRead] — «Ответить» и «Прочитано» из окошка, как у
  /// Telegram; зовутся, только если [DesktopNotificationCard.canAct].
  Future<bool> present(
    DesktopNotificationCard card, {
    required bool sound,
    required VoidCallback onTap,
    Future<void> Function(String text)? onReply,
    Future<void> Function()? onMarkRead,
  }) async {
    if (!enabled) return false;
    return _enqueue(
      () => _presentNow(
        card,
        sound: sound,
        onTap: onTap,
        onReply: onReply,
        onMarkRead: onMarkRead,
      ),
    );
  }

  Future<bool> _presentNow(
    DesktopNotificationCard card, {
    required bool sound,
    required VoidCallback onTap,
    Future<void> Function(String text)? onReply,
    Future<void> Function()? onMarkRead,
  }) async {
    final windows = DesktopChildWindows.instance;
    if (!await windows.isSupported()) return false;
    // Windows просит не беспокоить (презентация, полноэкранная программа,
    // заблокированный экран) — окошко поверх всех и было бы беспокойством.
    if (!await windows.acceptsNotifications()) return false;

    final same = _slots.whereType<_Shown>().where(
      (s) => s.card.value.payload == card.payload,
    );
    if (same.isNotEmpty) {
      final shown = same.first;
      shown.card.value = card;
      shown.onTap = onTap;
      shown.onReply = onReply;
      shown.onMarkRead = onMarkRead;
      _arm(shown);
      if (sound) unawaited(windows.playNotificationSound());
      return true;
    }

    // Новое — снизу, как у Telegram: старые поднимаются на место выше, а
    // самое старое (верхнее) при нехватке мест уходит.
    final oldest = _slots.last;
    if (oldest != null) {
      _slots[maxVisible - 1] = null;
      oldest.timer?.cancel();
      await windows.close(oldest.id);
    }
    for (var i = maxVisible - 1; i > 0; i--) {
      final below = _slots[i - 1];
      _slots[i] = below;
      _slots[i - 1] = null;
      if (below != null) await windows.placeAtCorner(below.id, i);
    }
    const slot = 0;
    final id = 'notification-${_seq++}';
    final shown = _Shown(id, ValueNotifier<DesktopNotificationCard>(card), onTap)
      ..onReply = onReply
      ..onMarkRead = onMarkRead;
    _slots[slot] = shown;
    final ok = await windows.open(
      DesktopChildWindowSpec(
        id: id,
        title: card.title,
        size: size,
        minSize: size,
        notificationSlot: slot,
        builder: (_) => DesktopChildWindowApp(
          locale: locale?.call(),
          resolveLocale: resolveLocale ?? (l) => l.first,
          home: DesktopNotificationView(
            card: shown.card,
            hovered: shown.hovered,
            replying: shown.replying,
            onOpen: () {
              shown.onTap();
              unawaited(dismiss(id));
            },
            onClose: () => unawaited(dismiss(id)),
            // Окошко рождается без фокуса — печатать в него можно только
            // после «Ответить».
            onStartReply: () =>
                unawaited(DesktopChildWindows.instance.allowFocus(id)),
            onReply: (text) async {
              final send = shown.onReply;
              if (send == null) return;
              await send(text);
              unawaited(dismiss(id));
            },
            onMarkRead: () async {
              final mark = shown.onMarkRead;
              if (mark != null) await mark();
              unawaited(dismiss(id));
            },
          ),
        ),
      ),
    );
    if (!ok) {
      // Место — по самому окошку, а не по номеру: номер 0 к этой минуте мог
      // быть уже чужим.
      final at = _slots.indexOf(shown);
      if (at >= 0) _slots[at] = null;
      await _compact();
      return false;
    }
    shown.hovered.addListener(() => _arm(shown));
    shown.replying.addListener(() => _arm(shown));
    _arm(shown);
    if (sound) unawaited(windows.playNotificationSound());
    return true;
  }

  /// Гаснет через [visibleFor]; под мышью и пока человек пишет ответ — ждёт.
  void _arm(_Shown shown) {
    shown.timer?.cancel();
    if (shown.hovered.value ||
        shown.replying.value ||
        !_slots.contains(shown)) {
      return;
    }
    shown.timer = Timer(visibleFor, () => unawaited(dismiss(shown.id)));
  }

  Future<void> dismiss(String id) => _enqueue(() => _dismissNow(id));

  Future<void> _dismissNow(String id) async {
    final slot = _slots.indexWhere((s) => s?.id == id);
    if (slot >= 0) {
      final shown = _slots[slot]!;
      _slots[slot] = null;
      shown.timer?.cancel();
    }
    // Окно ОС закрываем, даже если места у окошка нет: окошко, потерявшее
    // место, иначе висело бы поверх всех окон навсегда.
    await DesktopChildWindows.instance.close(id);
    if (slot >= 0) await _compact();
  }

  /// Стопка сползает вниз: пустых мест посередине не остаётся.
  Future<void> _compact() async {
    final remaining = _slots.whereType<_Shown>().toList(growable: false);
    for (var k = 0; k < maxVisible; k++) {
      final next = k < remaining.length ? remaining[k] : null;
      final moved = next != null && !identical(_slots[k], next);
      _slots[k] = next;
      if (moved) await DesktopChildWindows.instance.placeAtCorner(next.id, k);
    }
  }

  /// Открыли переписку в главном окне — её окошко больше не нужно.
  Future<void> dismissFor(String payload) => _enqueue(() async {
    final ids = _slots
        .whereType<_Shown>()
        .where((s) => s.card.value.payload == payload)
        .map((s) => s.id)
        .toList(growable: false);
    for (final id in ids) {
      await _dismissNow(id);
    }
  });

  /// Погасить все окошки — перезапуск приложения (смена профиля) или выход:
  /// щелчок по окошку вёл бы в службу уведомлений, которой уже нет.
  Future<void> dismissAll() => _enqueue(() async {
    final ids = _slots
        .whereType<_Shown>()
        .map((s) => s.id)
        .toList(growable: false);
    for (final id in ids) {
      await _dismissNow(id);
    }
  });

  @visibleForTesting
  List<String?> get debugSlots =>
      _slots.map((s) => s?.id).toList(growable: false);

  @visibleForTesting
  void debugReset() {
    for (final s in _slots) {
      s?.timer?.cancel();
    }
    _slots.fillRange(0, maxVisible, null);
    _seq = 0;
    _tail = null;
  }
}

/// Окошко уведомления: портрет, имя, текст; под мышью — «Ответить»,
/// «Прочитано» и крестик. «Ответить» превращает текст в поле ответа — как у
/// Telegram Desktop.
class DesktopNotificationView extends StatefulWidget {
  const DesktopNotificationView({
    super.key,
    required this.card,
    required this.hovered,
    required this.replying,
    required this.onOpen,
    required this.onClose,
    this.onStartReply,
    this.onReply,
    this.onMarkRead,
  });

  final ValueListenable<DesktopNotificationCard> card;
  final ValueNotifier<bool> hovered;
  final ValueNotifier<bool> replying;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  /// Окошку — принимать клавиатуру (Windows: снять «без фокуса»).
  final VoidCallback? onStartReply;
  final Future<void> Function(String text)? onReply;
  final Future<void> Function()? onMarkRead;

  @override
  State<DesktopNotificationView> createState() =>
      _DesktopNotificationViewState();
}

class _DesktopNotificationViewState extends State<DesktopNotificationView> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startReply() {
    widget.onStartReply?.call();
    widget.replying.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _cancelReply() {
    widget.replying.value = false;
    _text.clear();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final reply = widget.onReply;
    if (text.isEmpty || reply == null || _sending) return;
    setState(() => _sending = true);
    try {
      await reply(text);
    } catch (_) {
      // Не ушло — поле с текстом остаётся: человек повторит или откроет чат.
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      onEnter: (_) => widget.hovered.value = true,
      onExit: (_) => widget.hovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.replying,
        builder: (ctx, replying, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Пока пишут ответ, щелчок по окошку не должен уводить в чат.
          onTap: replying ? null : widget.onOpen,
          child: ColoredBox(
            color: c.elevated,
            child: ValueListenableBuilder<DesktopNotificationCard>(
              valueListenable: widget.card,
              builder: (ctx, card, _) {
                final path = (card.avatarPath ?? '').trim();
                final canAct = card.canAct &&
                    widget.onReply != null &&
                    widget.onMarkRead != null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Avatar(
                        name: card.title,
                        seed: card.avatarSeed,
                        size: 44,
                        image: path.isEmpty ? null : Avatar.fileImage(path),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    card.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DType.bodyStrong.copyWith(
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<bool>(
                                  valueListenable: widget.hovered,
                                  builder: (ctx, hovered, _) => AnimatedOpacity(
                                    opacity: hovered || replying ? 1 : 0,
                                    duration: DMotion.fast,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (canAct && !replying) ...[
                                          _PopupButton(
                                            icon: FluentIcons
                                                .arrow_reply_16_regular,
                                            tooltip: l10n.chatMenuReply,
                                            onTap: _startReply,
                                          ),
                                          _PopupButton(
                                            icon: FluentIcons
                                                .checkmark_16_regular,
                                            tooltip: l10n
                                                .notificationActionMarkRead,
                                            onTap: () => unawaited(
                                              widget.onMarkRead!(),
                                            ),
                                          ),
                                        ],
                                        _PopupButton(
                                          icon: FluentIcons.dismiss_16_regular,
                                          tooltip: replying
                                              ? l10n.cancel
                                              : l10n.close,
                                          onTap: replying
                                              ? _cancelReply
                                              : widget.onClose,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (replying)
                              _replyField(c, l10n)
                            else
                              Text(
                                card.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DType.caption.copyWith(
                                  color: c.textSecondary,
                                  height: 1.25,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _replyField(DColorSet c, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _cancelReply,
            },
            child: TextField(
              controller: _text,
              focusNode: _focus,
              enabled: !_sending,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_send()),
              style: DType.caption.copyWith(color: c.textPrimary),
              cursorColor: c.accentPrimary,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: c.bubblePeer,
                hintText: l10n.messageHint,
                hintStyle: DType.caption.copyWith(color: c.textTertiary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _PopupButton(
          icon: FluentIcons.send_16_filled,
          tooltip: l10n.send,
          accent: true,
          onTap: _sending ? null : () => unawaited(_send()),
        ),
      ],
    );
  }
}

/// Кнопка окошка — 26 точек, чтобы три помещались рядом с именем.
class _PopupButton extends StatelessWidget {
  const _PopupButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: HoverListener(
          onTap: onTap,
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          builder: (ctx, hovered, _) => AnimatedContainer(
            duration: DMotion.fast,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent
                  ? c.accentPrimary
                  : (hovered ? c.hover : Colors.transparent),
            ),
            child: Icon(
              icon,
              size: 15,
              color: accent ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
