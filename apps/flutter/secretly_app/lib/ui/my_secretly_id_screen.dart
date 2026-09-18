// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/app_controller.dart';
import 'animations/animations.dart';
import 'contact_qr_flow.dart';
import 'secretly_snackbar.dart';
import 'share_utils.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';

enum MySecretlyIdTab { myQr, scanQr }

class MySecretlyIdScreen extends StatefulWidget {
  const MySecretlyIdScreen({
    super.key,
    required this.controller,
    this.initialTab = MySecretlyIdTab.myQr,
  });

  final AppController controller;
  final MySecretlyIdTab initialTab;

  @override
  State<MySecretlyIdScreen> createState() => _MySecretlyIdScreenState();
}

class _MySecretlyIdScreenState extends State<MySecretlyIdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _scanTabLoaded = false;

  @override
  void initState() {
    super.initState();
    _scanTabLoaded = widget.initialTab == MySecretlyIdTab.scanQr;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.index,
    )..addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && !_scanTabLoaded) {
      setState(() => _scanTabLoaded = true);
      return;
    }
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(wave1Text(context, ru: 'QR-код', en: 'QR code')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: wave1Text(context, ru: 'Мой QR-код', en: 'My QR code'),
            ),
            Tab(
              text: wave1Text(
                context,
                ru: 'Сканировать QR',
                en: 'Scan QR code',
                uk: 'Сканувати QR',
                es: 'Escanear QR',
                pt: 'Digitalizar QR',
                ptBr: 'Escanear QR',
                fr: 'Scanner le QR',
                de: 'QR scannen',
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: [
          _MyQrPane(controller: widget.controller),
          _scanTabLoaded
              ? _EmbeddedQrScannerPane(controller: widget.controller)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _MyQrPane extends StatelessWidget {
  const _MyQrPane({required this.controller});

  final AppController controller;

  Future<void> _shareInviteFriend(BuildContext context) async {
    await shareTextExternally(
      text: buildInviteFriendShareText(
        controller: controller,
        localeTag: wave1LocaleTagFromContext(context),
      ),
    );
  }

  Future<void> _copyQrPayload(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          wave1Text(context, ru: 'QR-код скопирован', en: 'QR code copied'),
        ),
      ),
    );
  }

  Future<void> _copySecretlyId(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          wave1Text(
            context,
            ru: 'ID скопирован',
            en: 'ID copied',
            uk: 'ID скопійовано',
            es: 'ID copiado',
            pt: 'ID copiado',
            ptBr: 'ID copiado',
            fr: 'ID copie',
            de: 'ID kopiert',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = controller.profileId;
    final deviceId = controller.deviceId;
    final keysBaseUrl = controller.keysBaseUrl;
    final nickname = controller.myNickname.trim();
    final shareNick = controller.shareNicknameInQr;
    final isDark = theme.brightness == Brightness.dark;
    final idLabel = wave1Text(
      context,
      ru: 'Ваш ID в Secretly',
      en: 'Your Secretly ID',
      uk: 'Ваш ID у Secretly',
      es: 'Tu ID de Secretly',
      pt: 'O seu ID Secretly',
      ptBr: 'Seu ID no Secretly',
      fr: 'Votre ID Secretly',
      de: 'Deine Secretly-ID',
    );
    final inviteLabel = wave1Text(
      context,
      ru: 'Пригласить друзей',
      en: 'Invite friends',
      uk: 'Запросити друзів',
      es: 'Invitar amigos',
      pt: 'Convidar amigos',
      fr: 'Inviter des amis',
      de: 'Freunde einladen',
    );
    final copyLabel = wave1Text(
      context,
      ru: 'Скопировать ID',
      en: 'Copy ID',
      uk: 'Скопіювати ID',
      es: 'Copiar ID',
      pt: 'Copiar ID',
      ptBr: 'Copiar ID',
      fr: 'Copier l ID',
      de: 'ID kopieren',
    );
    final qrDescription = wave1Text(
      context,
      ru: 'Покажите друзьям этот QR-код, чтобы они могли быстро начать с вами чат.',
      en: 'Show this QR code to friends so they can quickly start a chat with you.',
      uk: 'Покажіть друзям цей QR-код, щоб вони швидко почали чат з вами.',
      es: 'Muestra este codigo QR a tus amigos para que puedan iniciar un chat contigo rapidamente.',
      pt: 'Mostre este codigo QR aos amigos para iniciarem rapidamente uma conversa consigo.',
      ptBr:
          'Mostre este codigo QR aos amigos para iniciarem uma conversa com voce rapidamente.',
      fr: 'Montrez ce QR code a vos amis pour qu ils commencent vite un chat avec vous.',
      de: 'Zeige Freunden diesen QR-Code, damit sie schnell einen Chat mit dir starten konnen.',
    );
    final qrForeground = isDark ? Colors.white : Colors.black;
    final qrBackground = isDark ? const Color(0xFF111111) : Colors.white;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: FutureBuilder<String>(
          future: controller.identityKeyPubB64(),
          builder: (context, snap) {
            final ik = snap.data;
            final safeNick = nickname
                .replaceAll(RegExp(r'[\r\n&]'), ' ')
                .trim();
            final qrData = (ik != null && ik.isNotEmpty)
                ? 'secretly_id=$id\nkeys_base_url=$keysBaseUrl\ndevice_id=$deviceId\nidentity_key_pub_b64=$ik'
                : 'secretly_id=$id\nkeys_base_url=$keysBaseUrl\ndevice_id=$deviceId';
            final withNick = (shareNick && safeNick.isNotEmpty)
                ? '$qrData\nnickname=$safeNick'
                : qrData;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      idLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: SelectableText(
                            id,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            tooltip: copyLabel,
                            onPressed: () => _copySecretlyId(context, id),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _shareInviteFriend(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(inviteLabel),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      qrDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const qrOuterPadding = 28.0;
                        final availableWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 420.0;
                        final qrSize = (availableWidth - qrOuterPadding)
                            .clamp(180.0, 280.0)
                            .toDouble();
                        return GestureDetector(
                          onLongPress: () => _copyQrPayload(context, withNick),
                          child: AnimatedQrReveal(
                            duration: const Duration(milliseconds: 500),
                            delay: const Duration(milliseconds: 100),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: qrBackground,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: QrImageView(
                                  data: withNick,
                                  version: QrVersions.auto,
                                  size: qrSize,
                                  backgroundColor: qrBackground,
                                  eyeStyle: QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: qrForeground,
                                  ),
                                  dataModuleStyle: QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: qrForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmbeddedQrScannerPane extends StatefulWidget {
  const _EmbeddedQrScannerPane({required this.controller});

  final AppController controller;

  @override
  State<_EmbeddedQrScannerPane> createState() => _EmbeddedQrScannerPaneState();
}

class _EmbeddedQrScannerPaneState extends State<_EmbeddedQrScannerPane> {
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed camera with NO top gap: the preview fills the whole pane and
    // the frosted top bar + tab bar float over it (same as QrScanScreen).
    // Previously a top padding pushed the preview below the bars, leaving a
    // blank strip between the camera and the top panel.
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) async {
            if (_busy) return;
            final codes = capture.barcodes;
            final raw = codes.isNotEmpty ? codes.first.rawValue : null;
            if (raw == null || raw.trim().isEmpty || !mounted) return;
            _busy = true;
            try {
              await handleContactQrScan(
                context: context,
                controller: widget.controller,
                raw: raw,
                openChatOnSuccess: true,
              );
            } finally {
              _busy = false;
            }
          },
        ),
        const ScanLineOverlay(),
      ],
    );
  }
}
