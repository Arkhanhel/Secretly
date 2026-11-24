// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/app_controller.dart';
import '../l10n/app_localizations.dart';
import '../security/social_recovery.dart';
import 'animations/page_transitions.dart';
import 'motion/press_feedback.dart';
import 'qr_scan_screen.dart';
import 'settings_group.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/apple_settings_row.dart';

/// Э3 «социальное восстановление»: вход из настроек безопасности.
///
/// Три роли на одном экране: владелец выбирает хранителей; хранитель
/// помогает восстановиться другому; новое устройство просит помощи.
/// Подписи — из общих локализаций (ARB), как в остальных экранах телефона.
class SocialRecoveryEntryCard extends StatelessWidget {
  const SocialRecoveryEntryCard({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Future<void> open(Widget page) => Navigator.of(context).push(
      SecretlyPageRoute<void>(builder: (_) => page),
    );
    // Android (23.11.2026): группа строк с цветными значками, как остальные
    // страницы настроек; переходы те же.
    if (settingsAndroidPanels) {
      return settingsRowsGroup([
        AppleSettingsRow(
          leading: const AppleRowIcon(
            tint: Color(0xFF34C759),
            icon: AdaptiveIcons.diversity_3_rounded,
          ),
          title: l10n.socialRecoveryGuardiansTitle,
          subtitle: l10n.socialRecoveryEntryGuardiansSubtitle,
          onTap: () => open(GuardiansSetupScreen(controller: controller)),
        ),
        AppleSettingsRow(
          leading: const AppleRowIcon(
            tint: Color(0xFFFF2D55),
            icon: AdaptiveIcons.volunteer_activism_rounded,
          ),
          title: l10n.socialRecoveryHelpSomeoneTitle,
          subtitle: l10n.socialRecoveryHelpSomeoneSubtitle,
          onTap: () => open(GuardianHelpScreen(controller: controller)),
        ),
        AppleSettingsRow(
          leading: const AppleRowIcon(
            tint: Color(0xFFFF9500),
            icon: AdaptiveIcons.restore_rounded,
          ),
          title: l10n.socialRecoveryRecoverMineTitle,
          subtitle: l10n.socialRecoveryRecoverMineSubtitle,
          onTap: () => open(RecoveryRequestScreen(controller: controller)),
        ),
      ]);
    }
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(AdaptiveIcons.diversity_3_rounded),
            title: Text(l10n.socialRecoveryGuardiansTitle),
            subtitle: Text(l10n.socialRecoveryEntryGuardiansSubtitle),
            onTap: () => open(GuardiansSetupScreen(controller: controller)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(AdaptiveIcons.volunteer_activism_rounded),
            title: Text(l10n.socialRecoveryHelpSomeoneTitle),
            subtitle: Text(l10n.socialRecoveryHelpSomeoneSubtitle),
            onTap: () => open(GuardianHelpScreen(controller: controller)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(AdaptiveIcons.restore_rounded),
            title: Text(l10n.socialRecoveryRecoverMineTitle),
            subtitle: Text(l10n.socialRecoveryRecoverMineSubtitle),
            onTap: () => open(RecoveryRequestScreen(controller: controller)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Владелец: выбор хранителей.
// ---------------------------------------------------------------------------

class GuardiansSetupScreen extends StatefulWidget {
  const GuardiansSetupScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<GuardiansSetupScreen> createState() => _GuardiansSetupScreenState();
}

class _GuardiansSetupScreenState extends State<GuardiansSetupScreen> {
  List<Contact> _contacts = const <Contact>[];
  SocialRecoveryGuardiansState? _state;
  final Set<String> _picked = <String>{};
  int _threshold = 2;
  bool _busy = false;
  String _error = '';
  StreamSubscription<void>? _sub;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = c.changed.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await c.listContacts();
    final state = await c.socialRecoveryGuardians();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _state = state;
      if (_picked.isEmpty && state != null) {
        _picked.addAll(state.guardians.map((g) => g.profileId));
        _threshold = state.threshold;
      }
    });
  }

  String _name(String pid) {
    for (final contact in _contacts) {
      if (contact.profileId == pid) {
        final n = (contact.displayName ?? '').trim();
        return n.isEmpty ? pid : n;
      }
    }
    return pid;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_picked.length < SocialRecovery.minGuardians) {
      setState(() {
        _error = l10n.socialRecoveryNeedTwoGuardians;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await c.setupSocialRecovery(
        guardianProfileIds: _picked.toList(),
        threshold: _threshold.clamp(2, _picked.length),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.socialRecoverySendSharesFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await c.clearSocialRecovery();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _picked.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = _state;
    final maxPick = SocialRecovery.maxGuardians;
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      appBar: AppBar(title: Text(l10n.socialRecoveryGuardiansTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            l10n.socialRecoveryOwnerIntro,
            style: theme.textTheme.bodyMedium,
          ),
          if (state != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  state.ready ? AdaptiveIcons.verified_rounded : AdaptiveIcons.hourglass_top_rounded,
                ),
                title: Text(
                  state.ready
                      ? l10n.socialRecoveryIsSetUp
                      : l10n.socialRecoveryWaitingConfirmations,
                ),
                subtitle: Text(
                  l10n.socialRecoveryConfirmedProgress(
                    state.accepted,
                    state.guardians.length,
                    state.threshold,
                  ),
                ),
              ),
            ),
            for (final g in state.guardians)
              ListTile(
                dense: true,
                leading: Icon(
                  switch (g.status) {
                    'accepted' => AdaptiveIcons.check_circle_rounded,
                    'failed' => AdaptiveIcons.error_outline_rounded,
                    _ => AdaptiveIcons.schedule_rounded,
                  },
                ),
                title: Text(_name(g.profileId)),
                subtitle: Text(
                  switch (g.status) {
                    'accepted' => l10n.socialRecoveryGuardianHoldsPart,
                    'failed' => l10n.socialRecoveryGuardianNotSent,
                    _ => l10n.socialRecoveryGuardianSentWaiting,
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.socialRecoveryPickContacts(maxPick),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.socialRecoveryNoContactsYet,
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final contact in _contacts)
            CheckboxListTile.adaptive(
              value: _picked.contains(contact.profileId),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        if (_picked.length < maxPick) _picked.add(contact.profileId);
                      } else {
                        _picked.remove(contact.profileId);
                      }
                      _threshold = _threshold.clamp(2, _picked.length < 2 ? 2 : _picked.length);
                    }),
              title: Text(_name(contact.profileId)),
            ),
          if (_picked.length >= 2) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.socialRecoveryThresholdLabel(_threshold, _picked.length),
              style: theme.textTheme.titleSmall,
            ),
            Slider.adaptive(
              value: _threshold.toDouble(),
              min: 2,
              max: _picked.length.toDouble(),
              divisions: _picked.length > 2 ? _picked.length - 2 : null,
              label: '$_threshold',
              onChanged: _picked.length > 2 && !_busy
                  ? (v) => setState(() => _threshold = v.round())
                  : null,
            ),
            Text(
              l10n.socialRecoveryThresholdWarning,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          PressFeedback(child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              state == null
                  ? l10n.socialRecoverySendParts
                  : l10n.socialRecoveryUpdateGuardians,
            ),
          )),
          if (state != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _clear,
              child: Text(l10n.socialRecoveryTurnOff),
            ),
          ],
        ],
      ),
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Хранитель: помочь восстановиться.
// ---------------------------------------------------------------------------

class GuardianHelpScreen extends StatefulWidget {
  const GuardianHelpScreen({
    super.key,
    required this.controller,
    this.initialCode,
  });
  final AppController controller;
  final RecoveryRequestCode? initialCode;

  @override
  State<GuardianHelpScreen> createState() => _GuardianHelpScreenState();
}

class _GuardianHelpScreenState extends State<GuardianHelpScreen> {
  List<GuardianShare> _held = const <GuardianShare>[];
  RecoveryRequestCode? _code;
  List<String> _words = const <String>[];
  String? _ownerPid;
  bool _confirmed = false;
  bool _busy = false;
  bool _done = false;
  String _error = '';

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
    final initial = widget.initialCode;
    if (initial != null) _setCode(initial);
  }

  Future<void> _load() async {
    final held = await c.heldGuardianShares();
    if (!mounted) return;
    setState(() {
      _held = held;
      if (held.length == 1) _ownerPid = held.single.ownerProfileId;
    });
  }

  Future<void> _setCode(RecoveryRequestCode code) async {
    final words = await SocialRecovery.checkWords(code.encode());
    if (!mounted) return;
    setState(() {
      _code = code;
      _words = words;
      _confirmed = false;
      _error = '';
    });
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = await Navigator.of(context).push<String>(
      SecretlyPageRoute<String>(
        builder: (_) => QrScanScreen(title: l10n.socialRecoveryCodeScanTitle),
      ),
    );
    if (raw == null) return;
    final code = RecoveryRequestCode.tryParse(raw);
    if (code == null) {
      setState(() {
        _error = l10n.socialRecoveryNotRecoveryCode;
      });
      return;
    }
    await _setCode(code);
  }

  Future<void> _paste() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = RecoveryRequestCode.tryParse(data?.text ?? '');
    if (code == null) {
      setState(() {
        _error = l10n.socialRecoveryNoCodeInClipboard;
      });
      return;
    }
    await _setCode(code);
  }

  Future<void> _release() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _code;
    final owner = _ownerPid;
    if (code == null || owner == null || !_confirmed) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await c.releaseGuardianShare(ownerProfileId: owner, request: code);
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = l10n.socialRecoverySendFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      appBar: AppBar(title: Text(l10n.socialRecoveryHelpRecoverTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (_held.isEmpty)
            Text(
              l10n.socialRecoveryNotGuardianYet,
              style: theme.textTheme.bodyMedium,
            )
          else ...<Widget>[
            Text(
              l10n.socialRecoveryWhoAreYouHelping,
              style: theme.textTheme.titleSmall,
            ),
            RadioGroup<String>(
              groupValue: _ownerPid,
              onChanged: (v) {
                if (_done || v == null) return;
                setState(() => _ownerPid = v);
              },
              child: Column(
                children: <Widget>[
                  for (final s in _held)
                    RadioListTile<String>.adaptive(
                      value: s.ownerProfileId,
                      enabled: !_done,
                      title: Text(s.ownerName.isEmpty ? s.ownerProfileId : s.ownerName),
                      subtitle: Text(
                        l10n.socialRecoveryThresholdOfGuardians(
                          s.threshold,
                          s.guardians,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: PressFeedback(child: OutlinedButton.icon(
                    onPressed: _done ? null : _scan,
                    icon: const Icon(AdaptiveIcons.qr_code_scanner_rounded),
                    label: Text(l10n.socialRecoveryScanCode),
                  )),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressFeedback(child: OutlinedButton.icon(
                    onPressed: _done ? null : _paste,
                    icon: const Icon(AdaptiveIcons.content_paste_rounded),
                    label: Text(l10n.socialRecoveryPasteCode),
                  )),
                ),
              ],
            ),
            if (_code != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.socialRecoveryCheckWordsByVoice,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _words.join('  ·  '),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.socialRecoveryCheckWordsExplanation,
                        style: theme.textTheme.bodySmall,
                      ),
                      CheckboxListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _confirmed,
                        onChanged: _done ? null : (v) => setState(() => _confirmed = v == true),
                        title: Text(l10n.socialRecoveryHeardWordsConfirm),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PressFeedback(child: FilledButton(
                onPressed: !_confirmed || _ownerPid == null || _busy || _done ? null : _release,
                child: Text(
                  _done
                      ? l10n.socialRecoverySent
                      : l10n.socialRecoverySendMyPart,
                ),
              )),
            ],
          ],
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Новое устройство: попросить хранителей.
// ---------------------------------------------------------------------------

class RecoveryRequestScreen extends StatefulWidget {
  const RecoveryRequestScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<RecoveryRequestScreen> createState() => _RecoveryRequestScreenState();
}

class _RecoveryRequestScreenState extends State<RecoveryRequestScreen> {
  RecoveryRequestCode? _code;
  List<String> _words = const <String>[];
  ({int received, int threshold}) _progress = (received: 0, threshold: 0);
  bool _started = false;
  StreamSubscription<void>? _sub;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _sub = c.changed.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final code = await c.startSocialRecoveryRequest();
    final words = await SocialRecovery.checkWords(code.encode());
    if (!mounted) return;
    setState(() {
      _code = code;
      _words = words;
      _started = true;
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    final p = await c.socialRecoveryProgress();
    if (mounted) setState(() => _progress = p);
  }

  Future<void> _cancel() async {
    await c.cancelSocialRecoveryRequest();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final code = _code;
    final error = c.socialRecoveryLastError;
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      appBar: AppBar(title: Text(l10n.socialRecoveryRecoverProfileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (!_started) ...<Widget>[
            Text(
              l10n.socialRecoveryRecoverIntro,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            PressFeedback(child: FilledButton(
              onPressed: _start,
              child: Text(l10n.socialRecoveryShowCodeToGuardians),
            )),
          ] else if (code != null) ...<Widget>[
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: code.encode(), size: 220),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _words.join('  ·  '),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.socialRecoveryShowCodeHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            PressFeedback(child: OutlinedButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: code.encode())),
              icon: const Icon(AdaptiveIcons.copy_rounded),
              label: Text(l10n.socialRecoveryCopyCode),
            )),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(AdaptiveIcons.group_rounded),
                title: Text(
                  _progress.threshold == 0
                      ? l10n.socialRecoveryWaitingGuardians
                      : l10n.socialRecoveryReceivedProgress(
                          _progress.received,
                          _progress.threshold,
                        ),
                ),
                subtitle: error == null
                    ? null
                    : Text(
                        error == 'auth_failed'
                            ? l10n.socialRecoveryPartDidNotFit
                            : l10n.socialRecoveryAssembleFailed(error),
                      ),
              ),
            ),
            TextButton(
              onPressed: _cancel,
              child: Text(l10n.socialRecoveryCancel),
            ),
          ],
        ],
      ),
    ),
    );
  }
}
