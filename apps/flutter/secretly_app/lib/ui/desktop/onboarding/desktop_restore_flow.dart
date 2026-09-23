// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../app/desktop_app_view_model.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_text_field.dart';
import '../primitives/hover_listener.dart';
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
  });

  final DesktopAppViewModel vm;
  final VoidCallback onBack;

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
          _error = l10n.desktopAuthBackupNotFound;
        });
        return;
      }
      final plain = await ctrl.decryptSafeBackupPayloadForRestore(
        payload: payload,
        password: password,
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_way) {
      case _RestoreWay.pick:
        return DesktopAuthScaffold(
          onBack: widget.onBack,
          title: l10n.desktopAuthRestoreTitle,
          subtitle: l10n.desktopAuthRestoreBody,
          children: [
            _WayCard(
              icon: FluentIcons.key_24_regular,
              title: l10n.desktopAuthKitOptionTitle,
              body: l10n.desktopAuthKitOptionBody,
              onTap: () => setState(() => _way = _RestoreWay.kit),
            ),
            const SizedBox(height: DSpace.m),
            _WayCard(
              icon: FluentIcons.cloud_arrow_down_24_regular,
              title: l10n.desktopAuthServerOptionTitle,
              body: l10n.desktopAuthServerOptionBody,
              onTap: () => setState(() => _way = _RestoreWay.server),
            ),
          ],
        );
      case _RestoreWay.kit:
        return _form(
          title: l10n.desktopAuthKitOptionTitle,
          subtitle: l10n.desktopAuthKitOptionBody,
          fields: [
            DesktopTextField(
              controller: _payload,
              autofocus: true,
              hintText: l10n.desktopAuthKitPasteHint,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: DSpace.m),
            DesktopTextField(
              controller: _kitPassword,
              hintText: l10n.password,
              obscureText: true,
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
            DesktopTextField(
              controller: _profileId,
              autofocus: true,
              hintText: l10n.mySecretlyId,
              prefixIcon: FluentIcons.fingerprint_24_regular,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: DSpace.m),
            DesktopTextField(
              controller: _backupPassword,
              hintText: l10n.password,
              obscureText: true,
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
    final c = DColors.of(context);
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
          const SizedBox(height: DSpace.m),
          Text(
            _error!,
            style: DType.label.copyWith(color: c.danger, height: 1.45),
          ),
        ],
        const SizedBox(height: DSpace.xl),
        DesktopButton(
          label: _busy ? l10n.desktopAuthRestoring : l10n.desktopAuthRestoreTitle,
          kind: DButtonKind.filled,
          expand: true,
          onPressed: (_busy || !ready) ? null : onSubmit,
        ),
      ],
    );
  }
}

class _WayCard extends StatelessWidget {
  const _WayCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        padding: const EdgeInsets.all(DSpace.l),
        decoration: BoxDecoration(
          color: hovered ? c.hover : c.chatList,
          border: Border.all(color: c.borderSubtle),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: c.textSecondary),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: DType.body.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(body,
                      style: DType.label
                          .copyWith(color: c.textSecondary, height: 1.45)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textDisabled),
          ],
        ),
      ),
    );
  }
}
