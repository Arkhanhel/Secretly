// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/widgets/secretly_sticker_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(height: 640, child: child)),
    );
  }

  // NOTE: the grouped-picker redesign (commit e0c9714a) removed the standalone
  // "Install pack" button + "Installed …" SnackBar from this widget. A remote-
  // only pack is now surfaced by a download badge on its top-bar icon; installs
  // are driven from the sticker send path, not from the picker. These tests
  // assert that current behavior (the old install-CTA tests were stale/red).

  testWidgets('sticker picker shows a download badge for a remote-only pack', (
    WidgetTester tester,
  ) async {
    final controller = _FakeStickerPickerController(installed: false);

    await tester.pumpWidget(
      wrapWithApp(
        SecretlyStickerPickerTab(
          controller: controller,
          recentStickers: const <SecretlyStickerDescriptor>[],
          onStickerSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('sticker picker omits the download badge for an installed pack', (
    WidgetTester tester,
  ) async {
    final controller = _FakeStickerPickerController(installed: true);

    await tester.pumpWidget(
      wrapWithApp(
        SecretlyStickerPickerTab(
          controller: controller,
          recentStickers: const <SecretlyStickerDescriptor>[],
          onStickerSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });
}

class _FakeStickerPickerController extends AppController {
  _FakeStickerPickerController({required bool installed})
    : _pack = _remotePack(installed: installed);

  final SecretlyStickerPack _pack;

  @override
  Future<List<SecretlyStickerPack>> loadStickerPickerPacks({
    bool refresh = true,
  }) async => <SecretlyStickerPack>[_pack];

  @override
  bool isStickerPackBusy({required String packId, required int packVersion}) =>
      false;

  // No-op install/uninstall so the picker never touches the real (uninitialized)
  // controller if a render path references them; the tests don't trigger either.
  @override
  Future<void> installStickerPack({
    required String packId,
    required int packVersion,
  }) async {}

  @override
  Future<void> uninstallStickerPack({
    required String packId,
    required int packVersion,
  }) async {}
}

SecretlyStickerPack _remotePack({required bool installed}) {
  return SecretlyStickerPack(
    id: 'studio_pack',
    version: 1,
    title: 'Studio',
    description: 'Design pack',
    iconStickerId: 'studio_palette',
    iconEmojiHint: '🎨',
    installed: installed,
    origin: SecretlyStickerPackOrigin.remote,
    stickers: <SecretlyStickerDescriptor>[
      SecretlyStickerDescriptor.placeholder(
        packId: 'studio_pack',
        packVersion: 1,
        stickerId: 'studio_palette',
        emojiHint: '🎨',
        label: 'Palette',
        keywords: const <String>['palette', 'design'],
      ),
    ],
  );
}
