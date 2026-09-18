// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/app/app_controller.dart' show ChatEvent;
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/icons/app_icons.dart';
import 'package:secretly_app/ui/widgets/media_viewer.dart';

// MEDIA-VIEWER OVERHAUL (2026-07-16): the top bar is three separate frosted
// islands (back / title / actions), the bottom filmstrip is a centered
// true-aspect carousel, and a video seek timeline renders under it. These
// tests pin the photo-path chrome: islands present, filmstrip carousel
// renders one thumb per item, no timeline for photos, and tapping a thumb
// switches the page (counter updates).

// 1x1 transparent PNG.
final Uint8List _kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

MediaViewerItem _item(int i) {
  return MediaViewerItem(
    event: ChatEvent(
      eventId: 'evt-$i',
      createdAtMs: 1700000000000 + i,
      type: 'attachment',
      ciphertextB64: '',
      localCiphertextB64: null,
      senderDeviceId: 'dev-1',
      localState: 'applied',
      payloadEventId: 'pay-$i',
    ),
    attachment: AttachmentEventV1(
      eventId: 'evt-$i',
      blobId: 'blob-$i',
      fileKeyB64: '',
      sizeBytes: _kTinyPng.length,
      mime: 'image/png',
    ),
  );
}

Finder _thumbFinder() => find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == const Color(0xFF123456),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File pngFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('media_viewer_test');
    pngFile = File('${tempDir.path}/tiny.png');
    await pngFile.writeAsBytes(_kTinyPng);
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpViewer(WidgetTester tester, {int count = 3}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaViewerDialog(
          items: [for (var i = 0; i < count; i++) _item(i)],
          initialIndex: 0,
          chatTitle: 'Игорь',
          loadImageFile: (_) async => pngFile,
          thumbnailBuilder: (context, file, mime, {bool forStrip = false}) =>
              const ColoredBox(color: Color(0xFF123456)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('top bar renders three islands: back, title, actions', (
    tester,
  ) async {
    await pumpViewer(tester);
    expect(find.byIcon(AppIcons.arrowBack), findsOneWidget);
    expect(find.text('Игорь'), findsOneWidget);
    expect(find.byIcon(AppIcons.forward), findsOneWidget);
    expect(find.byIcon(AppIcons.moreVert), findsOneWidget);
  });

  testWidgets('filmstrip carousel renders and photos show no timeline', (
    tester,
  ) async {
    await pumpViewer(tester);
    // One thumbnail per item in the strip (distinct color: the widget tree
    // adds its own transparent ColoredBox internally).
    expect(_thumbFinder(), findsNWidgets(3));
    // Photo pages never register a video controller → no seek slider.
    expect(find.byType(Slider), findsNothing);
    // Counter starts at the first item.
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('tapping a strip thumb switches the page', (tester) async {
    await pumpViewer(tester);
    await tester.tap(_thumbFinder().at(2), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
  });
}
