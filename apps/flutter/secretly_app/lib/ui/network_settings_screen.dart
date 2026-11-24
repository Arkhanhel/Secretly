// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_controller.dart';
import '../l10n/app_localizations.dart';
import '../transport/envelope_file.dart';
import '../transport/transport_core.dart' show TransportStatus;
import '../transport/transport_paths.dart';
import 'animations/page_transitions.dart';
import 'app_asset_paths.dart';
import 'motion/app_dialogs.dart';
import 'motion/press_feedback.dart';
import 'settings_group.dart';
import 'widgets/frosted_top_bar.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/apple_settings_row.dart';
import 'package:secretly_app/ui/apple_glass.dart';

/// Экран «Сеть» (Э1): каким путём приложение доходит до серверов, прокси
/// волонтёра, SOCKS и Tor. Сообщения файлом — в [OfflineTransferScreen]. Подписи — из общих локализаций (ARB).
Future<void> openNetworkSettings({
  required BuildContext context,
  required AppController controller,
}) {
  return Navigator.of(context).push(
    SecretlyPageRoute(
      builder: (_) => NetworkSettingsScreen(controller: controller),
    ),
  );
}

/// Файл сообщений без сети: по имени или по типу.
bool isOfflineEnvelopeFileName(String? name, {String? mime}) {
  if ((mime ?? '').trim().toLowerCase() == EnvelopeFile.mimeType) return true;
  return (name ?? '').trim().toLowerCase().endsWith('.${EnvelopeFile.fileExtension}');
}

/// Импорт файла сообщений без сети с итогом для человека. Общий для экрана
/// «Сеть», «Поделиться → Secretly» и открытия файла из другого приложения.
/// Возвращает число принятых сообщений или `null`, если файл отвергнут.
Future<int?> importOfflineEnvelopesWithFeedback(
  BuildContext context,
  AppController controller,
  List<int> bytes,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void toast(String text) =>
      messenger?.showSnackBar(SnackBar(content: Text(text)));
  try {
    final count = await controller.importOfflineEnvelopes(bytes);
    toast(
      count == 0
          ? l10n.netSettingsImportNoNewMessages
          : l10n.netSettingsImportReceived(count),
    );
    return count;
  } on EnvelopeFileException {
    toast(l10n.netSettingsImportNotEnvelopeFile);
  } catch (_) {
    toast(l10n.netSettingsImportCouldNotOpen);
  }
  return null;
}

/// То же по пути к файлу. Если файл не читается (iOS отдаёт файлы из
/// «Файлов» под защитой, без копии), подсказывает путь изнутри приложения.
Future<int?> importOfflineEnvelopeFileWithFeedback(
  BuildContext context,
  AppController controller,
  String path,
) async {
  final List<int> bytes;
  try {
    final file = File(path);
    if (await file.length() > EnvelopeFile.maxFileBytes) {
      throw const FileSystemException('too large');
    }
    bytes = await file.readAsBytes();
  } catch (_) {
    if (!context.mounted) return null;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.netSettingsImportCouldNotRead,
        ),
      ),
    );
    return null;
  }
  if (!context.mounted) return null;
  return importOfflineEnvelopesWithFeedback(context, controller, bytes);
}

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late final TextEditingController _proxy;
  late final TextEditingController _socks;
  Timer? _refresh;
  String _error = '';

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _proxy = TextEditingController(
      text: c.transportProxyPort == 443
          ? c.transportProxyHost
          : '${c.transportProxyHost}:${c.transportProxyPort}',
    );
    _socks = TextEditingController(text: c.transportSocksAddr);
    _refresh = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _proxy.dispose();
    _socks.dispose();
    super.dispose();
  }

  String _pathLabel(AppLocalizations l10n, String? kind) => switch (kind) {
    'direct' => l10n.netSettingsPathDirect,
    'ip' => l10n.netSettingsPathFallback,
    'mirror' => l10n.netSettingsPathMirror,
    'cdn' => l10n.netSettingsPathCdn,
    'proxy' => l10n.netSettingsPathProxy,
    'socks' => l10n.netSettingsPathSocks,
    'tor' => l10n.netSettingsPathTor,
    _ => l10n.netSettingsPathDirect,
  };

  Future<void> _saveProxy() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _proxy.text.trim().toLowerCase();
    if (raw.isEmpty) {
      await c.setTransportProxy(host: '');
      setState(() => _error = '');
      return;
    }
    final parsed = tryParseTransportProxyUri(Uri.parse('secretly://proxy#$raw'));
    if (parsed == null) {
      setState(() {
        _error = l10n.netSettingsProxyHostError;
      });
      return;
    }
    await c.setTransportProxy(host: parsed.$1, port: parsed.$2);
    setState(() => _error = '');
  }

  Future<void> _saveSocks() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _socks.text.trim();
    if (raw.isNotEmpty && !RegExp(r'^[0-9a-z.\-]+:[0-9]{2,5}$').hasMatch(raw)) {
      setState(() {
        _error = l10n.netSettingsSocksAddressError;
      });
      return;
    }
    await c.setTransportSocks(raw);
    setState(() => _error = '');
  }

  /// Э1б: Tor на телефоне — через Orbot.
  ///
  /// Встроенного клиента Tor у нас нет, и для России и Ирана он без мостов
  /// почти бесполезен: сами узлы Tor там заблокированы, а мосты умеет добывать
  /// Orbot. Поэтому мы не делаем вид, что умеем Tor сами, а подставляем адрес
  /// SOCKS, на котором Orbot его отдаёт. Проверить, запущен ли Orbot, из
  /// приложения нельзя — обещать этого нельзя тоже, поэтому подпись говорит
  /// прямо: установите и запустите.
  Future<void> _useOrbot() async {
    final l10n = AppLocalizations.of(context)!;
    const orbotSocks = '127.0.0.1:9050';
    _socks.text = orbotSocks;
    await c.setTransportSocks(orbotSocks);
    if (!mounted) return;
    setState(() => _error = '');
    _toast(l10n.netSettingsOrbotDone);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = c.transportStatus();
    final enabled = c.transportPathsEnabled;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final bottomPad = MediaQuery.of(context).padding.bottom + 32;
    if (settingsAndroidPanels) {
      return AppleSettingsPageTheme(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: frostedAppBar(title: Text(l10n.netSettingsTitle)),
          body: _buildAndroidList(
            context,
            l10n: l10n,
            status: status,
            enabled: enabled,
            topPad: topPad,
            bottomPad: bottomPad,
          ),
        ),
      );
    }
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.netSettingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: <Widget>[
          SettingsPageIntro(
            icon: Image.asset(
              '${AppAssetPaths.settingsIconsDir}/privat/w11-block.png',
              color: _networkAmber,
              colorBlendMode: BlendMode.srcIn,
            ),
            color: _networkAmber,
            text: l10n.settingsIntroNetwork,
            inset: 4,
          ),
          const SizedBox(height: 14),
          // Состояние: каким путём идём к серверам сейчас. Зелёная, когда
          // путь известен; серая, когда обходные пути выключены.
          SettingsStatusCard(
            good: status != null,
            title: status == null
                ? l10n.netSettingsPathToServersTitle
                : _pathLabel(l10n, status.currentKind),
            subtitle: status == null
                ? l10n.netSettingsPathDirectOff
                : l10n.netSettingsPathToServersTitle,
          ),
          const SizedBox(height: 4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(AdaptiveIcons.help_outline_rounded),
              title: Text(l10n.netHowItWorksTitle),
              subtitle: Text(l10n.netHowItWorksSubtitle),
              trailing: const Icon(AdaptiveIcons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                SecretlyPageRoute<void>(
                  builder: (_) => const NetworkHowItWorksScreen(),
                ),
              ),
            ),
          ),
          SettingsGroupHeader(
            l10n.settingsGroupBlocked,
            inset: 16,
            help: SettingsHelp(
              title: l10n.settingsGroupBlocked,
              text: l10n.settingsCaptionBlocked,
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SecretlySwitchListTile(
              value: enabled,
              onChanged: (v) => c.setTransportPathsEnabled(v),
              title: Text(l10n.netSettingsTryAlternativeTitle),
              subtitle: Text(l10n.netSettingsTryAlternativeSubtitle),
            ),
          ),
          SettingsGroupHeader(
            l10n.settingsGroupManual,
            inset: 16,
            help: SettingsHelp(
              title: l10n.settingsGroupManual,
              text: l10n.settingsHelpManual,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.netSettingsVolunteerProxyTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.netSettingsVolunteerProxyDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _proxy,
                    enabled: enabled,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'proxy.example.org',
                      border: const OutlineInputBorder(),
                      suffixIcon: PressFeedback(child: IconButton(
                        icon: const Icon(AdaptiveIcons.check_rounded),
                        onPressed: enabled ? _saveProxy : null,
                      )),
                    ),
                    onSubmitted: (_) => _saveProxy(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.netSettingsSocksTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _socks,
                    enabled: enabled,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: '127.0.0.1:9050',
                      border: const OutlineInputBorder(),
                      suffixIcon: PressFeedback(child: IconButton(
                        icon: const Icon(AdaptiveIcons.check_rounded),
                        onPressed: enabled ? _saveSocks : null,
                      )),
                    ),
                    onSubmitted: (_) => _saveSocks(),
                  ),
                  if (_error.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(AdaptiveIcons.shield_moon_rounded),
                  title: Text(l10n.netSettingsOrbotTitle),
                  subtitle: Text(l10n.netSettingsOrbotSubtitle),
                  onTap: enabled ? _useOrbot : null,
                ),
                if (c.transportTorOffered) ...<Widget>[
                  const Divider(height: 1),
                  SecretlySwitchListTile(
                    value: c.transportTorAllowed,
                    onChanged: enabled
                        ? (v) => c.setTransportTorAllowed(v)
                        : null,
                    title: Text(l10n.netSettingsTorTitle),
                    subtitle: Text(l10n.netSettingsTorSubtitle),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Передача сообщений без интернета живёт в своём разделе (макет
          // владельца, 11.2026) — отсюда на неё короткая дорога.
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(AdaptiveIcons.outbox_rounded),
              title: Text(l10n.settingsGroupOffline),
              subtitle: Text(l10n.settingsHubOfflineSub),
              trailing: const Icon(AdaptiveIcons.chevron_right_rounded),
              onTap: () => openOfflineTransfer(context: context, controller: c),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

extension on _NetworkSettingsScreenState {
  /// Android (23.11.2026, владелец: «доделай все категории, половина на
  /// старом стиле»): состояние, переключатели и пути — строками групп, поля
  /// адресов — в панели с плотными отступами. Сохранение и проверки те же.
  Widget _buildAndroidList(
    BuildContext context, {
    required AppLocalizations l10n,
    required TransportStatus? status,
    required bool enabled,
    required double topPad,
    required double bottomPad,
  }) {
    final theme = Theme.of(context);
    final secondary = AppleGlass.secondaryLabel(
      theme.brightness == Brightness.dark,
    );
    InputDecoration field(String hint, VoidCallback onSave) => InputDecoration(
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(),
      suffixIcon: PressFeedback(
        child: IconButton(
          icon: const Icon(AdaptiveIcons.check_rounded),
          onPressed: enabled ? onSave : null,
        ),
      ),
    );
    final fieldTitle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      children: <Widget>[
        SettingsPageIntro(
          icon: Image.asset(
            '${AppAssetPaths.settingsIconsDir}/privat/w11-block.png',
            color: _networkAmber,
            colorBlendMode: BlendMode.srcIn,
          ),
          color: _networkAmber,
          text: l10n.settingsIntroNetwork,
        ),
        const SizedBox(height: 12),
        // Состояние: зелёный значок, когда путь известен; серый, когда
        // обходные пути выключены.
        settingsRowsGroup(<Widget>[
          AppleSettingsRow(
            leading: AppleRowIcon(
              tint: status != null
                  ? const Color(0xFF34C759)
                  : const Color(0xFF8E8E93),
              icon: AdaptiveIcons.network_check_rounded,
            ),
            title: l10n.netSettingsPathToServersTitle,
            subtitle: status == null ? l10n.netSettingsPathDirectOff : null,
            trailing: status == null
                ? null
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      _pathLabel(l10n, status.currentKind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF7CDCA4)
                            : const Color(0xFF1E7A45),
                      ),
                    ),
                  ),
          ),
          AppleSettingsRow(
            leading: const AppleRowIcon(
              tint: Color(0xFF0A84FF),
              icon: AdaptiveIcons.help_outline_rounded,
            ),
            title: l10n.netHowItWorksTitle,
            subtitle: l10n.netHowItWorksSubtitle,
            onTap: () => Navigator.of(context).push(
              SecretlyPageRoute<void>(
                builder: (_) => const NetworkHowItWorksScreen(),
              ),
            ),
          ),
        ]),
        SettingsGroupHeader(
          l10n.settingsGroupBlocked,
          help: SettingsHelp(
            title: l10n.settingsGroupBlocked,
            text: l10n.settingsCaptionBlocked,
          ),
        ),
        settingsRowsGroup(<Widget>[
          AppleSettingsRow(
            leading: const AppleRowIcon(
              tint: Color(0xFFFF9500),
              icon: AdaptiveIcons.vpn_lock_rounded,
            ),
            title: l10n.netSettingsTryAlternativeTitle,
            subtitle: l10n.netSettingsTryAlternativeSubtitle,
            trailing: SecretlySwitch(
              value: enabled,
              onChanged: (v) => c.setTransportPathsEnabled(v),
            ),
            onTap: () => c.setTransportPathsEnabled(!enabled),
          ),
        ]),
        SettingsGroupHeader(
          l10n.settingsGroupManual,
          help: SettingsHelp(
            title: l10n.settingsGroupManual,
            text: l10n.settingsHelpManual,
          ),
        ),
        SettingsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.netSettingsVolunteerProxyTitle, style: fieldTitle),
              const SizedBox(height: 2),
              Text(
                l10n.netSettingsVolunteerProxyDescription,
                style: TextStyle(fontSize: 13, height: 1.3, color: secondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proxy,
                enabled: enabled,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: field('proxy.example.org', _saveProxy),
                onSubmitted: (_) => _saveProxy(),
              ),
              const SizedBox(height: 12),
              Text(l10n.netSettingsSocksTitle, style: fieldTitle),
              const SizedBox(height: 8),
              TextField(
                controller: _socks,
                enabled: enabled,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: field('127.0.0.1:9050', _saveSocks),
                onSubmitted: (_) => _saveSocks(),
              ),
              if (_error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        settingsRowsGroup(<Widget>[
          AppleSettingsRow(
            leading: const AppleRowIcon(
              tint: Color(0xFF7D4CDB),
              icon: AdaptiveIcons.shield_moon_rounded,
            ),
            title: l10n.netSettingsOrbotTitle,
            subtitle: l10n.netSettingsOrbotSubtitle,
            showChevron: false,
            onTap: enabled ? _useOrbot : null,
          ),
          if (c.transportTorOffered)
            AppleSettingsRow(
              leading: const AppleRowIcon(
                tint: Color(0xFF5E5CE6),
                icon: AdaptiveIcons.public_rounded,
              ),
              title: l10n.netSettingsTorTitle,
              subtitle: l10n.netSettingsTorSubtitle,
              trailing: SecretlySwitch(
                value: c.transportTorAllowed,
                onChanged: enabled ? (v) => c.setTransportTorAllowed(v) : null,
              ),
              onTap: enabled
                  ? () => c.setTransportTorAllowed(!c.transportTorAllowed)
                  : null,
            ),
        ]),
        const SizedBox(height: 12),
        // Короткая дорога в «Без интернета», как на iPhone.
        settingsRowsGroup(<Widget>[
          AppleSettingsRow(
            leading: const AppleRowIcon(
              tint: _offlineGreen,
              icon: AdaptiveIcons.outbox_rounded,
            ),
            title: l10n.settingsGroupOffline,
            subtitle: l10n.settingsHubOfflineSub,
            onTap: () => openOfflineTransfer(context: context, controller: c),
          ),
        ]),
      ],
    );
  }
}

/// Цвета разделов — те же, что у значков в главном списке настроек.
const Color _networkAmber = Color(0xFFE0A43A);
const Color _offlineGreen = Color(0xFF35B86B);

/// Раздел «Без интернета»: сообщения файлом. Сама передача прежняя —
/// [AppController.exportOfflineEnvelopes] / [importOfflineEnvelopesWithFeedback].
Future<void> openOfflineTransfer({
  required BuildContext context,
  required AppController controller,
}) {
  return Navigator.of(context).push(
    SecretlyPageRoute<void>(
      builder: (_) => OfflineTransferScreen(controller: controller),
    ),
  );
}

class OfflineTransferScreen extends StatefulWidget {
  const OfflineTransferScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<OfflineTransferScreen> createState() => _OfflineTransferScreenState();
}

class _OfflineTransferScreenState extends State<OfflineTransferScreen> {
  AppController get c => widget.controller;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> _exportOffline() async {
    final l10n = AppLocalizations.of(context)!;
    final contacts = await c.listContacts();
    if (!mounted) return;
    if (contacts.isEmpty) {
      _toast(l10n.netSettingsNoContactsYet);
      return;
    }
    final picked = await showModalBottomSheet<String>(
  sheetAnimationStyle: appSheetAnimationStyle,
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: Text(
                l10n.netSettingsPickRecipientTitle,
                style: Theme.of(sheetCtx).textTheme.titleSmall,
              ),
            ),
            for (final contact in contacts)
              ListTile(
                title: Text(
                  (contact.displayName ?? '').trim().isEmpty
                      ? contact.profileId
                      : contact.displayName!.trim(),
                ),
                onTap: () => Navigator.of(sheetCtx).pop(contact.profileId),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      final bytes = await c.exportOfflineEnvelopes(picked);
      if (bytes == null) {
        _toast(l10n.netSettingsNothingToCarry);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, EnvelopeFile.suggestedFileName(DateTime.now())),
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path, mimeType: EnvelopeFile.mimeType)]),
      );
    } catch (_) {
      _toast(l10n.netSettingsCouldNotCreateFile);
    }
  }

  Future<void> _importOffline() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final bytes = result?.files.single.bytes;
      if (bytes == null || !mounted) return;
      await importOfflineEnvelopesWithFeedback(context, c, bytes);
    } catch (_) {
      _toast(l10n.netSettingsImportCouldNotOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final bottomPad = MediaQuery.of(context).padding.bottom + 32;
    // Android (23.11.2026): шаги — в панели, два действия — строками группы
    // со значками и «›», как в «Настройках» iOS, без больших кнопок.
    if (settingsAndroidPanels) {
      return AppleSettingsPageTheme(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: frostedAppBar(title: Text(l10n.settingsGroupOffline)),
          body: ListView(
            padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
            children: <Widget>[
              SettingsPageIntro(
                icon: Image.asset(
                  '${AppAssetPaths.settingsIconsDir}/w11-invite.png',
                  color: _offlineGreen,
                  colorBlendMode: BlendMode.srcIn,
                ),
                color: _offlineGreen,
                text: l10n.settingsIntroOffline,
              ),
              SettingsGroupHeader(l10n.netHowItWorksTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SettingsStepsCard(
                  steps: <(String, String)>[
                    (l10n.offlineStep1Title, l10n.offlineStep1Body),
                    (l10n.offlineStep2Title, l10n.offlineStep2Body),
                    (l10n.offlineStep3Title, l10n.offlineStep3Body),
                  ],
                ),
              ),
              SettingsGroupHeader(l10n.settingsGroupSend),
              settingsRowsGroup(<Widget>[
                AppleSettingsRow(
                  leading: const AppleRowIcon(
                    tint: Color(0xFF0A84FF),
                    icon: AdaptiveIcons.outbox_rounded,
                  ),
                  title: l10n.netSettingsSendWithoutNetworkTitle,
                  onTap: _exportOffline,
                ),
              ]),
              SettingsGroupCaption(l10n.settingsCaptionOffline),
              SettingsGroupHeader(l10n.settingsGroupReceive),
              settingsRowsGroup(<Widget>[
                AppleSettingsRow(
                  leading: const AppleRowIcon(
                    tint: _offlineGreen,
                    icon: AdaptiveIcons.move_to_inbox_rounded,
                  ),
                  title: l10n.netSettingsOpenMessageFileTitle,
                  onTap: _importOffline,
                ),
              ]),
              SettingsGroupCaption(l10n.netSettingsOpenMessageFileSubtitle),
            ],
          ),
        ),
      );
    }
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.settingsGroupOffline)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: <Widget>[
          SettingsPageIntro(
            icon: Image.asset(
              '${AppAssetPaths.settingsIconsDir}/w11-invite.png',
              color: _offlineGreen,
              colorBlendMode: BlendMode.srcIn,
            ),
            color: _offlineGreen,
            text: l10n.settingsIntroOffline,
            inset: 4,
          ),
          SettingsGroupHeader(l10n.netHowItWorksTitle, inset: 16),
          SettingsStepsCard(
            steps: <(String, String)>[
              (l10n.offlineStep1Title, l10n.offlineStep1Body),
              (l10n.offlineStep2Title, l10n.offlineStep2Body),
              (l10n.offlineStep3Title, l10n.offlineStep3Body),
            ],
          ),
          SettingsGroupHeader(l10n.settingsGroupSend, inset: 16),
          SettingsActionButton(
            primary: true,
            icon: AdaptiveIcons.outbox_rounded,
            label: l10n.netSettingsSendWithoutNetworkTitle,
            onPressed: _exportOffline,
          ),
          SettingsGroupCaption(l10n.settingsCaptionOffline, inset: 16),
          SettingsGroupHeader(l10n.settingsGroupReceive, inset: 16),
          SettingsActionButton(
            icon: AdaptiveIcons.move_to_inbox_rounded,
            label: l10n.netSettingsOpenMessageFileTitle,
            onPressed: _importOffline,
          ),
          SettingsGroupCaption(
            l10n.netSettingsOpenMessageFileSubtitle,
            inset: 16,
          ),
        ],
      ),
    ),
    );
  }
}

/// «Как это работает»: обход блокировок и связь без интернета простыми
/// словами. Только текст — ничего не меняет и ничего не проверяет.
class NetworkHowItWorksScreen extends StatelessWidget {
  const NetworkHowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final steps = <(String, String)>[
      (l10n.netHowStep1Title, l10n.netHowStep1Body),
      (l10n.netHowStep2Title, l10n.netHowStep2Body),
      (l10n.netHowStep3Title, l10n.netHowStep3Body),
      (l10n.netHowStep4Title, l10n.netHowStep4Body),
      (l10n.netHowStep5Title, l10n.netHowStep5Body),
      (l10n.netHowStep6Title, l10n.netHowStep6Body),
    ];
    // Android (23.11.2026): шесть шагов одной панелью с номерами, как шаги
    // «Без интернета», а не шесть отдельных карточек.
    if (settingsAndroidPanels) {
      return AppleSettingsPageTheme(
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.netHowItWorksTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[SettingsStepsCard(steps: steps)],
          ),
        ),
      );
    }
    // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
      appBar: AppBar(title: Text(l10n.netHowItWorksTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          for (var i = 0; i < steps.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              steps[i].$1,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[i].$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
