// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Общий круг медиа 2a: воспроизведение, скачивание, отправка с отменой,
// повтор — поверх фото/видео и в строке файла. `SECRETLY_SHOTS=папка`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/chat_media_circle.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Widget _photo(Widget child, {bool light = false}) => Container(
  width: 170,
  height: 130,
  margin: const EdgeInsets.all(6),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: light
          ? const [Color(0xFFF7EEDC), Color(0xFFDDE8F0)]
          : const [Color(0xFF5E7C8A), Color(0xFF2A3B4A)],
    ),
  ),
  child: Center(child: child),
);

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

void main() {
  setUpAll(_loadFonts);

  testWidgets('все состояния круга без ошибок; касание доходит', (t) async {
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            RepaintBoundary(key: _shotKey, child: child),
        home: Scaffold(
          backgroundColor: const Color(0xFF18222D),
          body: Wrap(
            children: [
              _photo(const ChatMediaCircle(glyph: ChatMediaGlyph.play)),
              _photo(
                const ChatMediaCircle(glyph: ChatMediaGlyph.play),
                light: true,
              ),
              _photo(
                ChatMediaCircle(
                  glyph: ChatMediaGlyph.cancel,
                  ring: true,
                  progress: 0.42,
                  onTap: () => taps++,
                  semanticsLabel: 'Отменить',
                ),
              ),
              _photo(
                const ChatMediaCircle(
                  glyph: ChatMediaGlyph.download,
                  ring: true,
                  progress: 0.7,
                ),
                light: true,
              ),
              _photo(
                const ChatMediaCircle(
                  glyph: ChatMediaGlyph.cancel,
                  ring: true,
                ),
              ),
              _photo(const ChatMediaCircle(glyph: ChatMediaGlyph.retry)),
              Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B5278),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatMediaCircle(
                      glyph: ChatMediaGlyph.download,
                      style: ChatMediaCircleStyle.accent,
                      size: 42,
                      ring: true,
                    ),
                    SizedBox(width: 10),
                    ChatMediaCircle(
                      glyph: ChatMediaGlyph.document,
                      style: ChatMediaCircleStyle.accent,
                      size: 42,
                    ),
                    SizedBox(width: 10),
                    ChatMediaCircle(
                      glyph: ChatMediaGlyph.play,
                      style: ChatMediaCircleStyle.accent,
                      size: 42,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 30));
    }
    expect(t.takeException(), isNull);
    await t.tap(find.bySemanticsLabel('Отменить'));
    expect(taps, 1);
    final dir = _shots;
    if (dir != null && dir.isNotEmpty) {
      await t.runAsync(() async {
        final b =
            _shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/media_circles_iOS.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('кольцо: ход по часовой, пусто при нуле', () {
    final a = ChatMediaRingPainter(progress: 0.5, rotation: 0);
    final b = ChatMediaRingPainter(progress: 0.5, rotation: 0);
    expect(a.shouldRepaint(b), isFalse);
    expect(
      a.shouldRepaint(ChatMediaRingPainter(progress: 0.6, rotation: 0)),
      isTrue,
    );
  });
}
