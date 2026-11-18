// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../backup_refusal_text.dart';
import '../../welcome/welcome_style.dart';
import '../app/desktop_app_view_model.dart';
import 'desktop_auth_scaffold.dart';

/// Восстановление аккаунта на компьютере.
///
/// 🔴 НАБОР ВОССТАНОВЛЕНИЯ — ПЕРВЫМ, И ЭТО НЕ ВКУСОВЩИНА. Копия на сервере
/// требует ввести Secretly ID руками, а его не помнит наизусть НИКТО: это
/// не имя и не почта. В наборе восстановления ID уже записан, человеку нужен
/// только пароль от самого набора. Поставить копию первой значило бы начинать
/// разговор с вопроса, на который у большинства нет ответа.
class DesktopRestoreFlow extends StatefulWidget {
  const DesktopRestoreFlow({
    super.key,
    required this.vm,
    required this.onBack,
    this.onUsePhone,
  });

  final DesktopAppViewModel vm;
  final VoidCallback onBack;

  /// Перейти к привязке по телефону (из подсказки и из предупреждения о
  /// переносе личности). `null` — такой дороги рядом нет.
  final VoidCallback? onUsePhone;

  @override
  State<DesktopRestoreFlow> createState() => _DesktopRestoreFlowState();
}

enum _RestoreWay { pick, kit, server }

class _DesktopRestoreFlowState extends State<DesktopRestoreFlow> {
  _RestoreWay _way = _RestoreWay.pick;

  final TextEditingController _payload = TextEditingController();
  final TextEditingController _kitPassword = TextEditingController();
  final TextEditingController _profileId = TextEditingController();
  final TextEditingController _backupPassword = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _payload.dispose();
    _kitPassword.dispose();
    _profileId.dispose();
    _backupPassword.dispose();
    super.dispose();
  }

  /// Техническую приставку Dart человеку показывать незачем.
  String _clean(Object e) {
    var text = e.toString();
    for (final prefix in const ['Bad state: ', 'StateError: ', 'Exception: ']) {
      if (text.startsWith(prefix)) text = text.substring(prefix.length);
    }
    return text;
  }

  Future<void> _restoreFromKit() async {
    final l10n = AppLocalizations.of(context)!;
    final payload = _payload.text.trim();
    final password = _kitPassword.text;
    if (payload.isEmpty || password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vm.controller.restoreFromRecoveryKitPayload(
        payload: payload,
        password: password,
      );
      // Дальше экран сменит корень: восстановление снимает запрет входа.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.desktopAuthRestoreFailed(_clean(e));
      });
    }
  }

  Future<void> _restoreFromServer() async {
    final l10n = AppLocalizations.of(context)!;
    final pid = _profileId.text.trim();
    final password = _backupPassword.text;
    if (pid.isEmpty || password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ctrl = widget.vm.controller;
      // Подписать запрос нечем — ключей на этом компьютере ещё нет. Зато есть
      // пароль копии: из него выводится токен доступа, он и заменяет подпись
      // (тот же путь, что у телефона при восстановлении на новом устройстве).
      final (exists, payload, _) = await ctrl.backupGetFromServer(
        pid,
        useDeviceAuth: false,
        backupPassword: password,
      );
      if (!mounted) return;
      if (!exists || payload == null || payload.trim().isEmpty) {
        setState(() {
          _busy = false;
          _error = serverBackupRefusalText(
            context,
            l10n,
            ctrl.lastServerBackupRefusal,
            fallback: l10n.desktopAuthBackupNotFound,
          );
        });
        return;
      }
      final plain = await ctrl.decryptSafeBackupPayloadForRestore(
        payload: payload,
        password: password,
      );
      if (!mounted) return;
      // 🔴 СНАЧАЛА — ПОСЛЕДСТВИЯ (01.10.2026). Восстановление ниже забирает
      // у устройства, сделавшего копию (обычно телефона), его личность:
      // компьютер становится ТЕМ ЖЕ устройством. Пока телефон жив, у одной
      // личности два хозяина — сообщения достаются одному из двух, второй
      // может перестать расшифровывать чаты. Раньше об этом не говорилось
      // ни слова. Спрашиваем после проверки пароля: иначе человек прочёл бы
      // предупреждение ради копии, которую всё равно не открыть.
      //
      // Путь «восстановить как новое устройство» у контроллера есть
      // (`restoreAsNewDevice: true`), но для компьютера он не бесследен:
      // рассылает контактам весть о новом устройстве, заводит в аккаунте
      // устройство, которого телефон не привязывал, и с правилами
      // мультиустройства на сервере не сверен. Поэтому личность по-прежнему
      // переиспользуется, а человеку прямо сказано, чем это грозит, и
      // предложена привязка по QR.
      if (!await _confirmTakeOver()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await ctrl.restoreFromSafeBackup(
        plain,
        completeOnboarding: true,
        // Как на телефоне: личность из копии переиспользуется. Заводить новое
        // устройство здесь значило бы разойтись с тем, что уже проверено.
        restoreAsNewDevice: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.desktopAuthRestoreFailed(_clean(e));
      });
    }
  }

  /// «Компьютер станет устройством, сделавшим копию» — да или нет.
  ///
  /// В окне три выхода (макет 17.11.2026): подключиться через телефон — это
  /// и есть безопасный путь, всё равно восстановить, отмена.
  Future<bool> _confirmTakeOver() async {
    final l10n = AppLocalizations.of(context)!;
    final usePhone = widget.onUsePhone;
    final answer = await showWelcomeDialog<String>(
      context: context,
      builder: (ctx) {
        final s = WelcomeStyle.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.desktopRestoreTakeOverTitle,
                style: s.title.copyWith(fontSize: 24, height: 1.18),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.desktopRestoreTakeOverBody, style: s.body),
            const SizedBox(height: 22),
            if (usePhone != null) ...[
              WelcomePrimaryButton(
                label: l10n.welcomeDesktopTakeOverUsePhone,
                height: s.fluent ? 40 : 50,
                onPressed: () => Navigator.of(ctx).maybePop('phone'),
              ),
              const SizedBox(height: 8),
            ],
            WelcomePrimaryButton(
              label: l10n.desktopRestoreTakeOverConfirm,
              height: s.fluent ? 40 : 48,
              danger: true,
              onPressed: () => Navigator.of(ctx).maybePop('restore'),
            ),
            const SizedBox(height: 4),
            WelcomeTextButton(
              label: l10n.cancel,
              onPressed: () => Navigator.of(ctx).maybePop('cancel'),
            ),
          ],
        );
      },
    );
    if (answer == 'phone' && usePhone != null) usePhone();
    return answer == 'restore';
  }

  /// Выбор способа ↔ форма — тем же плавным переходом, что шаги входа.
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: const Cubic(0.2, 0.8, 0.2, 1),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<_RestoreWay>(_way),
        child: _page(context),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_way) {
      case _RestoreWay.pick:
        return DesktopAuthScaffold(
          onBack: widget.onBack,
          title: l10n.desktopAuthRestoreTitle,
          subtitle: l10n.desktopAuthRestoreBody,
          children: [
            WelcomeGlass(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    WelcomeChoiceRow(
                      first: true,
                      title: l10n.desktopAuthKitOptionTitle,
                      subtitle: l10n.desktopAuthKitOptionBody,
                      onTap: () => setState(() => _way = _RestoreWay.kit),
                    ),
                    WelcomeChoiceRow(
                      title: l10n.desktopAuthServerOptionTitle,
                      subtitle: l10n.desktopAuthServerOptionBody,
                      onTap: () => setState(() => _way = _RestoreWay.server),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onUsePhone != null) ...[
              const SizedBox(height: 28),
              _UsePhoneHint(onTap: widget.onUsePhone!),
            ],
          ],
        );
      case _RestoreWay.kit:
        return _form(
          title: l10n.desktopAuthKitOptionTitle,
          subtitle: l10n.desktopAuthKitOptionBody,
          fields: [
            WelcomeTextField(
              controller: _payload,
              autofocus: true,
              hint: l10n.desktopAuthKitPasteHint,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            WelcomeTextField(
              controller: _kitPassword,
              hint: l10n.password,
              obscure: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _restoreFromKit(),
            ),
          ],
          ready: _payload.text.trim().isNotEmpty &&
              _kitPassword.text.isNotEmpty,
          onSubmit: _restoreFromKit,
        );
      case _RestoreWay.server:
        return _form(
          title: l10n.desktopAuthServerOptionTitle,
          subtitle: l10n.desktopAuthServerOptionBody,
          fields: [
            Semantics(
              label: l10n.mySecretlyId,
              child: WelcomeTextField(
                controller: _profileId,
                autofocus: true,
                hint: l10n.secretlyIdHint,
                monospace: true,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            WelcomeTextField(
              controller: _backupPassword,
              hint: l10n.password,
              obscure: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _restoreFromServer(),
            ),
          ],
          ready: _profileId.text.trim().isNotEmpty &&
              _backupPassword.text.isNotEmpty,
          onSubmit: _restoreFromServer,
        );
    }
  }

  Widget _form({
    required String title,
    required String subtitle,
    required List<Widget> fields,
    required bool ready,
    required VoidCallback onSubmit,
  }) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    return DesktopAuthScaffold(
      // Назад — к выбору способа, а не к началу: человек уже решил, что
      // восстанавливает, и заставлять его решать это заново незачем.
      onBack: _busy ? null : () => setState(() => _way = _RestoreWay.pick),
      title: title,
      subtitle: subtitle,
      children: [
        ...fields,
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.error,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        WelcomePrimaryButton(
          label: _busy ? l10n.desktopAuthRestoring : l10n.desktopAuthRestoreTitle,
          onPressed: (_busy || !ready) ? null : onSubmit,
        ),
      ],
    );
  }
}

/// «Телефон с Secretly под рукой? Войдите через него — так телефон не
/// потеряет доступ.» Ссылка внутри фразы ведёт к привязке по QR.
class _UsePhoneHint extends StatefulWidget {
  const _UsePhoneHint({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_UsePhoneHint> createState() => _UsePhoneHintState();
}

class _UsePhoneHintState extends State<_UsePhoneHint> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = widget.onTap;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    const mark = '\u0001';
    final parts = l10n.welcomeDesktopUsePhonePrompt(mark).split(mark);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: l10n.welcomeDesktopUsePhoneLink,
            recognizer: _tap,
            mouseCursor: SystemMouseCursors.click,
            style: TextStyle(
              color: s.text,
              decoration: TextDecoration.underline,
              decorationColor: s.text,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join()),
        ],
      ),
      textAlign: TextAlign.center,
      style: s.body.copyWith(fontSize: 14, color: s.textSecondary),
    );
  }
}
