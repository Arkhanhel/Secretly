// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Анимация реакций (макет «Reactions Animation»): эффекты всех 54 эмодзи
// строятся и рисуются; полёт садится в чип (знак скрыт в полёте → пружина и
// кольцо при посадке → эффект снят); снятие — сжатие. Меню в чате — сторожа.
// `SECRETLY_SHOTS=папка` — снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/reaction_burst.dart';
import 'package:secretly_app/ui/chat/reaction_fx.dart';

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

const _main = ['❤️', '🔥', '😁', '👍', '👎', '🥰', '👏'];

void main() {
  setUpAll(_loadFonts);

  test('пружина макета: перелёт до 1,09 и покой в 1', () {
    const c = ReactionSpringCurve();
    expect(c.transform(0), 0);
    expect(c.transform(1), 1);
    expect(c.transform(0.36), closeTo(1.09, 0.001));
    expect(c.transform(0.6), lessThan(1));
  });

  test('у каждого из 54 эмодзи — свой эффект, конечный и непустой', () {
    for (final e in [..._main, ...kReactionMoreEmoji, '🦖']) {
      final ps = reactionBurstFor(e, random: math.Random(1));
      expect(ps, isNotEmpty, reason: e);
      final d = reactionBurstDuration(ps);
      expect(d, inInclusiveRange(200, 3500), reason: e);
      for (final p in ps) {
        expect(p.frames, isNotEmpty, reason: e);
        expect(p.at(p.delay + p.duration / 2), isNotNull, reason: e);
      }
    }
    expect(kReactionMoreEmoji, hasLength(47));
  });

  test('количество частиц растёт с силой эффекта', () {
    final weak = reactionBurstFor('😁', random: math.Random(2), intensity: 0.4);
    final strong =
        reactionBurstFor('😁', random: math.Random(2), intensity: 1.8);
    expect(strong.length, greaterThan(weak.length));
  });

  testWidgets('эффекты рисуются без ошибок (снимки главных семи)', (t) async {
    t.view.physicalSize = const Size(700, 420) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final sets = {
      for (final e in [..._main, ...kReactionMoreEmoji, '🦖'])
        e: reactionBurstFor(e, random: math.Random(7)),
    };
    for (final ms in [80.0, 300.0, 700.0, 1300.0]) {
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _shotKey,
            child: ColoredBox(
              color: const Color(0xFF18222D),
              child: Wrap(
                children: [
                  for (final e in _main)
                    SizedBox(
                      width: 175,
                      height: 210,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ReactionBurstPainter(
                                particles: sets[e]!,
                                ms: ms,
                                origin: const Offset(87, 120),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 70,
                            top: 102,
                            child: Text(e, style: const TextStyle(fontSize: 30)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      if (ms == 300) await _shoot(t, 'rx_burst_300');
    }
    // Остальные 48 — рисуются без ошибок.
    for (final e in sets.keys.skip(_main.length)) {
      await t.pumpWidget(
        CustomPaint(
          painter: ReactionBurstPainter(
            particles: sets[e]!,
            ms: 400,
            origin: const Offset(100, 100),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: e);
    }
  });

  testWidgets('🔴 полёт садится в чип: скрыт → посадка с пружиной → снят', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    const fxId = 'evt1|❤️';
    final reg = ReactionFxRegistry.instance;
    reg.clear(fxId);
    final ctxKey = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            RepaintBoundary(key: _shotKey, child: child),
        home: Scaffold(
          key: ctxKey,
          backgroundColor: const Color(0xFF18222D),
          body: Align(
            alignment: const Alignment(-0.6, 0.4),
            child: Container(
              width: 260,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0xF22A3848),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Тогда завтра в 11:00 показываем команде',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  ReactionChipFxScope(
                    fxId: fxId,
                    ringColor: const Color(0xFF3390EC),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3390EC),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const ReactionGlyphFxScope(
                        fxId: fxId,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: Center(
                            child: Text('❤️', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    launchReactionFlight(
      context: ctxKey.currentContext!,
      emoji: '❤️',
      start: const Rect.fromLTWH(60, 300, 34, 34),
      bubble: null,
      fxId: fxId,
      haptics: false,
      emojiBuilder: (e, size, play) => Center(
        child: Text(e, style: TextStyle(fontSize: size * 0.8)),
      ),
    );
    await t.pump();
    expect(reg.of(fxId), ReactionChipFx.waiting);
    // В полёте знак в чипе скрыт.
    final glyphOpacity = t.widget<Opacity>(
      find
          .descendant(
            of: find.byType(ReactionGlyphFxScope),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(glyphOpacity.opacity, 0);
    await t.pump(const Duration(milliseconds: 260));
    await _shoot(t, 'rx_flight_mid');
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 100));
    await _shoot(t, 'rx_landed_burst');
    expect(t.takeException(), isNull);
    // Посадка в чип.
    await t.pump(const Duration(milliseconds: 1300));
    await t.pump();
    expect(reg.of(fxId), ReactionChipFx.landed);
    await t.pump(const Duration(milliseconds: 120));
    await _shoot(t, 'rx_chip_pulse');
    await t.pump(const Duration(seconds: 2));
    expect(reg.of(fxId), isNull, reason: 'эффект снят после посадки');
    expect(t.takeException(), isNull);
  });

  testWidgets('снятие: чип сжимается и гаснет', (t) async {
    const fxId = 'evt2|👍';
    final reg = ReactionFxRegistry.instance;
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ReactionChipFxScope(
            fxId: fxId,
            ringColor: Colors.blue,
            child: SizedBox(width: 40, height: 24),
          ),
        ),
      ),
    );
    reg.set(fxId, ReactionChipFx.removing);
    await t.pump();
    await t.pump(const Duration(milliseconds: 260));
    final o = t.widget<Opacity>(
      find
          .descendant(
            of: find.byType(ReactionChipFxScope),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(o.opacity, lessThan(0.05));
    reg.clear(fxId);
  });

  test('🔴 чат: меню реакций на новых анимациях, а не одним масштабом', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(src.contains('await showReactionMenu<String>('), isTrue);
    expect(src.contains('launchReactionFlight('), isTrue);
    expect(src.contains("pop('fly:\$e')"), isTrue);
    expect(src.contains('flight: true'), isTrue);
    expect(src.contains('ReactionChipFxScope('), isTrue);
    expect(src.contains('ReactionCollapse('), isTrue);
    expect(src.contains('_staggerMenuItems('), isTrue);
    // Полёт сам оживляет чип — старое раздувание ×2.75 в чипе не запускается.
    final apply = src.substring(
      src.indexOf('Future<void> _applyReaction({'),
      src.indexOf('Future<void> _applyReaction({') + 4000,
    );
    expect(apply.contains('if (!flight) {'), isTrue);
  });

  test('🔴 двойное касание ❤️ — та же анимация полёта, что из меню', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(
      RegExp(r"\(\) =>\s*_applyReaction\(\s*eventId:\s*reactionEventId,\s*emoji: '❤️'")
          .hasMatch(src),
      isFalse,
      reason: 'двойное касание снова ставит реакцию без полёта',
    );
    final body = src.substring(
      src.indexOf('Future<void> _doubleTapReact('),
      src.indexOf('Future<void> _doubleTapReact(') + 1600,
    );
    expect(body.contains('launchReactionFlight('), isTrue);
    expect(body.contains('flight: true'), isTrue);
  });
}
