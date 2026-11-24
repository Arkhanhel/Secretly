// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Пузыри вложений по варианту 2a «Капсула»: голосовое, музыка, файл —
// одной ширины, круг 42 слева, без переполнений; чип скорости на играющем
// голосовом. `SECRETLY_SHOTS=папка` — настоящие снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/main.dart'
    show appLightBackgroundColors, buildSecretlyThemeForTest;
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/chat_screen.dart' show attachmentBubbleForTest;
import 'package:secretly_app/ui/theme_presets.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

AttachmentEventV1 _att({
  required String id,
  required String mime,
  int size = 2400000,
  List<int>? waveform,
  String? filename,
}) => AttachmentEventV1(
  eventId: id,
  blobId: 'blob-$id',
  fileKeyB64: 'AAAA',
  sizeBytes: size,
  mime: mime,
  waveform: waveform,
  filename: filename,
);

final _wave = [for (var i = 0; i < 48; i++) (20 + (i * 37) % 80)];

Widget _app(Brightness b) {
  final preset = resolveAppThemePreset(AppController.kDefaultAppThemePresetId);
  final theme = buildSecretlyThemeForTest(
    b,
    appPreset: preset,
    bubblePreset: resolveChatBubbleStylePreset(
      AppController.kDefaultBubbleStylePresetId,
    ),
    nicknamePreset: resolveNicknameStylePreset('accent'),
    indicatorPreset: resolveIndicatorColorPreset('theme'),
  );
  final dark = b == Brightness.dark;
  Widget row(Widget bubble, {required bool me}) => Align(
    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: bubble,
    ),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
    ),
    builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
    home: Scaffold(
      backgroundColor: dark
          ? preset.darkBgMid
          : appLightBackgroundColors(preset)[1],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              row(
                attachmentBubbleForTest(
                  attachment: _att(id: 'v1', mime: 'audio/mp4', waveform: _wave),
                  isMe: false,
                  duration: const Duration(seconds: 14),
                ),
                me: false,
              ),
              row(
                attachmentBubbleForTest(
                  attachment: _att(
                    id: 'f1',
                    mime: 'application/pdf',
                    filename: 'Маршрут_до_дачи.pdf',
                  ),
                  isMe: false,
                ),
                me: false,
              ),
              row(
                attachmentBubbleForTest(
                  attachment: _att(id: 'v2', mime: 'audio/mp4', waveform: _wave),
                  isMe: true,
                  playing: true,
                  position: const Duration(seconds: 5),
                  duration: const Duration(seconds: 12),
                  speed: 1.5,
                ),
                me: true,
              ),
              row(
                attachmentBubbleForTest(
                  attachment: _att(id: 'm1', mime: 'audio/mpeg', size: 9600000),
                  isMe: true,
                  playing: true,
                  position: const Duration(seconds: 72),
                  duration: const Duration(seconds: 228),
                  musicTitle: 'Ночной трамвай',
                  musicArtist: 'Полярные огни',
                ),
                me: true,
              ),
              row(
                attachmentBubbleForTest(
                  attachment: _att(
                    id: 'f2',
                    mime: 'application/zip',
                    size: 8100000,
                    filename: 'Фото_с_отпуска.zip',
                  ),
                  isMe: true,
                  uploadProgress: 0.38,
                  localState: 'pending',
                ),
                me: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final (p, tag) in [
    (TargetPlatform.iOS, 'ios'),
    (TargetPlatform.android, 'android'),
  ]) {
    for (final b in [Brightness.dark, Brightness.light]) {
      final bt = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('пузыри 2a без переполнений ($tag, $bt)', (t) async {
        t.view.physicalSize = const Size(390, 844) * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await t.pumpWidget(_app(b));
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(t.takeException(), isNull);
        // Чип скорости на играющем голосовом.
        expect(find.text('1,5×'), findsOneWidget);
        expect(find.text('Маршрут_до_дачи.pdf'), findsOneWidget);
        expect(find.text('Ночной трамвай'), findsOneWidget);
        await _shoot(t, 'bubbles_${tag}_$bt');
      }, variant: TargetPlatformVariant.only(p));
    }
  }
}
