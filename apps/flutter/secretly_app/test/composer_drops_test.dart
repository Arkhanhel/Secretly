// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Поле ввода «Капля» (макет 1a, 22.11.2026): три капли, размеры платформ,
// перетекание микрофона в стрелку без смены размера, сжатие при отправке,
// «линза» при нажатии. `SECRETLY_SHOTS=папка` — снимки с настоящего кода.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/composer_drops.dart';

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

class _Composer extends StatefulWidget {
  const _Composer({
    required this.text,
    this.video = false,
    this.pulse = 0,
    this.reply = false,
  });

  final String text;
  final bool video;
  final int pulse;
  final bool reply;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final GlobalKey _dropKey = GlobalKey();
  late final TextEditingController _c = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant _Composer old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.text = widget.text;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ComposerDropStyle.of(
      context,
      frosted: true,
      accentTop: const Color(0xFF1FA597),
      accentBottom: const Color(0xFF6A4FD0),
      solidFill: const Color(0xFF1B2430),
    );
    final has = widget.text.trim().isNotEmpty;
    final fs = style.glass ? 17.0 : 16.0;
    return BackdropGroup(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ComposerAttachDrop(style: style, tooltip: 'Attach', onTap: () {}),
            const SizedBox(width: 8),
            Expanded(
              child: ComposerFieldDrop(
                style: style,
                header: !widget.reply
                    ? null
                    : const Padding(
                        // Как настоящий ответ в chat_screen.
                        padding: EdgeInsets.fromLTRB(12, 8, 6, 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 3,
                              height: 34,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(3)),
                                  color: Color(0xFF5BC0EB),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('В ответ Анна', style: TextStyle(color: Color(0xFF5BC0EB), fontWeight: FontWeight.w700, fontSize: 11)),
                                  Text('Скину макеты вечером', maxLines: 1, style: TextStyle(fontSize: 11, color: Color(0x99FFFFFF))),
                                ],
                              ),
                            ),
                            SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 20, color: Color(0x85FFFFFF))),
                          ],
                        ),
                      ),
                trailing: ComposerEmojiDrop(
                  style: style,
                  tooltip: 'Emoji',
                  onTap: () {},
                  child: Icon(ComposerDropIcons.mood, size: 24, color: style.icon),
                ),
                child: TextField(
                  controller: _c,
                  maxLines: 6,
                  minLines: 1,
                  style: TextStyle(fontSize: fs, height: 22 / fs),
                  decoration: InputDecoration(
                    hintText: 'Сообщение',
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: (style.size - 22) / 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ComposerActionDropView(
              key: _dropKey,
              style: style,
              action: has
                  ? ComposerDropAction.send
                  : (widget.video ? ComposerDropAction.video : ComposerDropAction.mic),
              filled: has,
              pulse: widget.pulse,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _phone(Widget composer, {required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7FE0),
        brightness: brightness,
      ),
    ),
    home: RepaintBoundary(
      key: _shotKey,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF0F1620) : const Color(0xFFEAF0F6),
        body: Stack(
          children: [
            // Обои макета: цветные пятна, чтобы было видно стекло.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.8, .85),
                    radius: .9,
                    colors: [
                      const Color(0xFF2E9FE4).withValues(alpha: dark ? .32 : .25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.9, .6),
                    radius: .8,
                    colors: [
                      const Color(0xFF6A4FD0).withValues(alpha: dark ? .34 : .22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 90,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A7568), Color(0xFF1C5AA0), Color(0xFF553BA8)],
                    ),
                  ),
                  child: const Text(
                    'Почти, ищу ключи',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 20, child: composer),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _frames(WidgetTester t, [int n = 40]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final b in Brightness.values) {
      testWidgets('капли: ${platform.name} ${b.name}', (t) async {
        t.view.physicalSize = const Size(390 * 2, 260 * 2);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        debugDefaultTargetPlatformOverride = platform;
        final ios = platform == TargetPlatform.iOS;
        final side = ios ? 44.0 : 48.0;

        await t.pumpWidget(_phone(const _Composer(text: ''), brightness: b));
        await _frames(t, 5);
        // Три капли одной высоты, прижаты к низу.
        final action = find.byType(ComposerActionDropView);
        expect(t.getSize(action), Size(side, side));
        expect(t.getSize(find.byType(ComposerAttachDrop)).height, side);
        expect(t.getSize(find.byType(ComposerFieldDrop)).height, side);
        expect(
          t.getBottomLeft(find.byType(ComposerAttachDrop)).dy,
          t.getBottomLeft(action).dy,
        );
        await _shot(t, 'composer_1a_${platform.name}_${b.name}_empty');

        // Первый символ: микрофон перетекает в стрелку, размер тот же.
        await t.pumpWidget(_phone(const _Composer(text: 'Нашла ключи'), brightness: b));
        await _frames(t, 40);
        expect(t.getSize(action), Size(side, side));
        await _shot(t, 'composer_1a_${platform.name}_${b.name}_text');

        // Длинный текст — поле растёт, капли у нижней строки.
        await t.pumpWidget(
          _phone(
            const _Composer(
              text: 'Если пробки будут большие, поедем по объездной через мост, так быстрее и спокойнее, я проверила',
            ),
            brightness: b,
          ),
        );
        await _frames(t, 20);
        expect(t.getSize(find.byType(ComposerFieldDrop)).height, greaterThan(side));
        expect(t.getSize(action), Size(side, side));
        expect(
          t.getBottomLeft(find.byType(ComposerFieldDrop)).dy,
          t.getBottomLeft(action).dy,
        );
        await _shot(t, 'composer_1a_${platform.name}_${b.name}_multiline');
        expect(t.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('отправка: капля сжимается до 0,8 и возвращается', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await t.pumpWidget(_phone(const _Composer(text: 'Привет'), brightness: Brightness.dark));
    await _frames(t, 30);
    await t.pumpWidget(
      _phone(const _Composer(text: 'Привет', pulse: 1), brightness: Brightness.dark),
    );
    await _frames(t, 8);
    final scale = t.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(ComposerActionDropView),
        matching: find.byType(AnimatedScale),
      ).first,
    );
    expect(scale.scale, .8);
    await _frames(t, 40);
    final back = t.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(ComposerActionDropView),
        matching: find.byType(AnimatedScale),
      ).first,
    );
    expect(back.scale, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('«линза»: нажатие «+» увеличивает каплю до 1,12', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await t.pumpWidget(_phone(const _Composer(text: ''), brightness: Brightness.dark));
    await _frames(t, 5);
    final g = await t.startGesture(t.getCenter(find.byType(ComposerAttachDrop)));
    await _frames(t, 3);
    final s = t.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(ComposerAttachDrop),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(s.scale, 1.12);
    await g.up();
    await _frames(t, 30);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('кружок: значок камеры, без заливки', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await t.pumpWidget(
      _phone(const _Composer(text: '', video: true), brightness: Brightness.dark),
    );
    await _frames(t, 30);
    final opacities = t
        .widgetList<AnimatedOpacity>(
          find.descendant(
            of: find.byType(ComposerActionDropView),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((o) => o.opacity)
        .toList();
    // Заливка 0; mic 0, video 1, send 0.
    expect(opacities.first, 0);
    expect(opacities.sublist(opacities.length - 3), [0, 1, 0]);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('ответ выезжает из капли поля: ${platform.name}', (t) async {
      t.view.physicalSize = const Size(390 * 2, 300 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      debugDefaultTargetPlatformOverride = platform;
      final side = platform == TargetPlatform.iOS ? 44.0 : 48.0;
      await t.pumpWidget(
        _phone(const _Composer(text: ''), brightness: Brightness.dark),
      );
      await _frames(t, 5);
      expect(t.getSize(find.byType(ComposerFieldDrop)).height, side);
      await t.pumpWidget(
        _phone(
          const _Composer(text: '', reply: true),
          brightness: Brightness.dark,
        ),
      );
      await _frames(t, 8);
      await _shot(t, 'composer_1a_${platform.name}_reply_mid');
      await _frames(t, 30);
      // Капля поля выросла вверх; «+» и кнопка той же высоты внизу.
      expect(
        t.getSize(find.byType(ComposerFieldDrop)).height,
        greaterThan(side + 30),
      );
      expect(t.getSize(find.byType(ComposerAttachDrop)).height, side);
      expect(
        t.getBottomLeft(find.byType(ComposerFieldDrop)).dy,
        t.getBottomLeft(find.byType(ComposerAttachDrop)).dy,
      );
      await _shot(t, 'composer_1a_${platform.name}_reply');
      expect(t.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
