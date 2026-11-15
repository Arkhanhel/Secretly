// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../security/app_security_manager.dart';
import 'l10n.dart';
import 'security_lock_flow.dart';

/// Раздел «Код принуждения» в настройках замка приложения (Э2).
///
/// Показывается только в основном пространстве и только при парольном замке:
/// в обманке этого раздела нет, чтобы она выглядела как обычная установка.
class SecurityDuressSection extends StatefulWidget {
  const SecurityDuressSection({
    super.key,
    required this.manager,
    required this.enabled,
    required this.onError,
  });

  final AppSecurityManager manager;

  /// Экран занят другим сохранением.
  final bool enabled;
  final ValueChanged<String> onError;

  @override
  State<SecurityDuressSection> createState() => _SecurityDuressSectionState();
}

class _SecurityDuressSectionState extends State<SecurityDuressSection> {
  static const int _wipeAfterAttempts = 10;

  DuressStatus? _status;
  int? _wipeAfter;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final status = await widget.manager.duressStatus();
    final wipeAfter = await widget.manager.wipeAfterFailedAttempts();
    if (!mounted) return;
    setState(() {
      _status = status;
      _wipeAfter = wipeAfter;
      _loaded = true;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !widget.enabled) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
    } on AppSecurityException catch (e) {
      widget.onError(e.message);
    } catch (_) {
      widget.onError(l10n.duressSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _reload();
    }
  }

  Future<void> _setCode() async {
    final l10n = AppLocalizations.of(context)!;
    // Свой заголовок и пояснение: общий экран называется «Пароль для
    // приложения», и задание кода принуждения на нём выглядело как смена
    // настоящего пароля (найдено при живой проверке 13.10.2026).
    final password = await openPasswordSetupFlow(
      context: context,
      scope: SecurityLockScope.app,
      title: l10n.duressSetupTitle,
      description: l10n.duressSetupDescription,
    );
    if (!mounted || password == null) return;
    await _run(
      () => widget.manager.setDuressPassword(
        password: password,
        wipeMain: _status?.wipeMain ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configured = _status != null;
    final disabled = _busy || !widget.enabled;
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(l10n.duressSectionTitle),
            subtitle: Text(
              configured
                  ? l10n.duressSectionSubtitleSet
                  : l10n.duressSectionSubtitleUnset,
            ),
            trailing: TextButton(
              onPressed: disabled ? null : _setCode,
              child: Text(
                configured ? l10n.duressSectionChange : l10n.duressSectionSetUp,
              ),
            ),
          ),
          if (configured) ...<Widget>[
            const Divider(height: 1),
            SwitchListTile(
              value: _status!.wipeMain,
              onChanged: disabled
                  ? null
                  : (value) =>
                        _run(() => widget.manager.setDuressWipeMain(value)),
              title: Text(l10n.duressWipeMainTitle),
              subtitle: Text(l10n.duressWipeMainSubtitle),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(l10n.duressRemoveCode),
              onTap: disabled
                  ? null
                  : () => _run(widget.manager.clearDuressPassword),
            ),
          ],
          const Divider(height: 1),
          SwitchListTile(
            value: _wipeAfter != null,
            onChanged: disabled
                ? null
                : (value) => _run(
                    () => widget.manager.setWipeAfterFailedAttempts(
                      value ? _wipeAfterAttempts : null,
                    ),
                  ),
            title: Text(
              l10n.duressWipeAfterAttemptsTitle(_wipeAfterAttempts),
            ),
            subtitle: Text(l10n.duressWipeAfterAttemptsSubtitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text(
              l10n.duressSectionFootnote,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
