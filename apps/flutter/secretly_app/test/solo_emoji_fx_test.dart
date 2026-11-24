// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Эмодзи отдельным сообщением (макет «Solo Emoji»): у 63 эмодзи — эффект на
// весь экран; крупная анимация один раз у человека (и по касанию), без
// «статичной» по кругу; эмодзи чуть меньше. `SECRETLY_SHOTS=папка` — снимки.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/reaction_burst.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_widgets.dart';
import 'package:secretly_app/ui/chat/solo_emoji_fx.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();
const _screen = Size(390, 844);
const _origin = Offset(110, 560);

void main() {
  test('у 63 эмодзи макета — свой эффект и своё движение', () {
    // 63 эмодзи макета + 🌞 с эффектом «Солнце» (у ☀️ нет анимации Noto).
    expect(kSoloEmojiWithEffect, hasLength(64));
    for (final e in [...kSoloEmojiWithEffect, '🦖']) {
      final fx = soloEmojiEffect(
        e,
        screen: _screen,
        origin: _origin,
        random: math.Random(3),
      );
      expect(fx.particles, isNotEmpty, reason: e);
      // ⚡ только вспыхивает, 🤩 стоит (так в макете) — остальные движутся.
      if (e != '⚡' && e != '🤩') expect(fx.card, isNotEmpty, reason: e);
      expect(fx.durationMs, inInclusiveRange(400, 6000), reason: e);
      // Движение эмодзи считается на всём отрезке без ошибок.
      for (final t in [0.0, 0.3, 0.7, 1.0]) {
        soloEmojiCardTransform(fx, fx.cardMs * t);
        expect(soloEmojiCardOpacity(fx, fx.cardMs * t), inInclusiveRange(0, 1));
      }
    }
  });

  testWidgets('эффекты на весь экран рисуются без ошибок (снимки)', (t) async {
    t.view.physicalSize = _screen * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    const shots = ['❤️', '🔥', '🎉', '👻', '⚡', '😭'];
    for (final e in [...kSoloEmojiWithEffect, '🦖']) {
      final fx = soloEmojiEffect(
        e,
        screen: _screen,
        origin: _origin,
        random: math.Random(5),
      );
      for (final k in [0.15, 0.4, 0.75]) {
        await t.pumpWidget(
          RepaintBoundary(
            key: _shotKey,
            child: ColoredBox(
              color: const Color(0xFF18222D),
              child: CustomPaint(
                size: _screen,
                painter: ReactionBurstPainter(
                  particles: fx.particles,
                  ms: fx.durationMs * k,
                  origin: _origin,
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull, reason: '$e $k');
        final dir = _shots;
        if (k == 0.4 && shots.contains(e) && dir != null && dir.isNotEmpty) {
          await t.runAsync(() async {
            final b =
                _shotKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final img = await b.toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$dir/solo_${shots.indexOf(e)}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
    }
  });

  test('«уже видел» — один раз у человека, переживает перезапуск', () async {
    SharedPreferences.setMockInitialValues({});
    SoloEmojiSeen.resetForTest();
    expect(SoloEmojiSeen.isSeen('solo:e1'), isFalse);
    SoloEmojiSeen.markSeen('solo:e1');
    expect(SoloEmojiSeen.isSeen('solo:e1'), isTrue);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('solo_emoji_fx_seen_v1'), contains('solo:e1'));
  });

  test('🔴 сообщение-эмодзи: меньше, без вечной анимации, один раз', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    final at = src.indexOf('class _SoloEmojiMessageState');
    final body = src.substring(at, at + 6000);
    expect(body.contains('size: kSoloEmojiSize'), isTrue);
    expect(kSoloEmojiSize, lessThan(160));
    // Уже виденное — неподвижный первый кадр, не проигрывание.
    expect(
      body.contains(
        'mode: _play ? _NotoLottieMode.once : _NotoLottieMode.preview',
      ),
      isTrue,
    );
    expect(body.contains('SoloEmojiSeen.isSeen(_seenId)'), isTrue);
    expect(body.contains('SoloEmojiSeen.markSeen(_seenId)'), isTrue);
    expect(body.contains('onTap: _start'), isTrue);
    expect(body.contains('NotoLottieMode.looping'), isFalse);
  });

  group('23.11.2026: серая точка в панели эмодзи', () {
    test('все эмодзи с эффектом есть в панели и помечаются', () {
      // 63 эмодзи макета + 🌞 с эффектом «Солнце» (у ☀️ нет анимации Noto).
    expect(kSoloEmojiWithEffect, hasLength(64));
      for (final e in kSoloEmojiWithEffect) {
        expect(hasSoloEmojiEffect(e), isTrue);
        // ☀️ нет в каталоге анимированных Noto (api.json): эффект готов, но
        // отдельным сообщением такой эмодзи пока не распознаётся.
        if (e == '☀️') {
          expect(kNotoCodepoints.containsKey(e), isFalse);
          continue;
        }
        expect(kNotoCodepoints.containsKey(e), isTrue, reason: '$e нет в каталоге');
        expect(kNotoSkinToneHidden.contains(e), isFalse, reason: '$e скрыт');
        expect(hasSoloEmojiEffect(e), isTrue);
      }
      expect(hasSoloEmojiEffect('🦄'), isFalse);
      // Тон кожи — без своего эффекта, без точки.
      expect(hasSoloEmojiEffect('👍🏽'), isFalse);
    });

    testWidgets('точка рисуется справа вверху и только с fxDot', (t) async {
      Future<int> topRightInk(Color? dot) async {
        final key = GlobalKey();
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: PanelEmojiGlyph(emoji: ' ', fxDot: dot),
                ),
              ),
            ),
          ),
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await t.runAsync(() => boundary.toImage());
        final data = (await t.runAsync(
          () => img!.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        var n = 0;
        for (var y = 2; y < 10; y++) {
          for (var x = 36; x < 44; x++) {
            if (data.getUint8((y * 46 + x) * 4 + 3) > 0) n++;
          }
        }
        return n;
      }

      expect(await topRightInk(null), 0);
      expect(await topRightInk(const Color(0x998E8E93)), greaterThan(4));
    });
  });

  group('23.11.2026: 63 эффекта макета', () {
    // Весь список макета (solo.html, LIST) — по порядку.
    const design = [
      '❤️', '🔥', '🎉', '😂', '😘', '👻', '🤯', '⚡', '🚀', '🥶', '👍', '😭', //
      '🙏', '🥰', '😍', '😊', '🥺', '😅', '🤔', '👏', '😎', '😡', '💯', '🤗', //
      '💩', '🎂', '🌹', '👋', '💀', '🥳', '🤣', '😢', '😁', '😉', '😋', '🤪', //
      '🙄', '😴', '😱', '😳', '🤩', '😇', '🤡', '🤮', '😏', '😔', '😬', '🫠', //
      '😈', '🤑', '💔', '❤️‍🔥', '💪', '🙌', '🫶', '👀', '✨', '🌈', '☀️', '🎁', //
      '🏆', '🍾', '🌚', //
    ];

    test('каждый эмодзи макета — свой эффект, конечный и короче 6 с', () {
      expect(design, hasLength(63));
      expect(kSoloEmojiWithEffect, containsAll(design));
      // Свой эффект, а не общий эффект реакции: у каждого — своя ветка.
      final src = File('lib/ui/chat/solo_emoji_fx.dart').readAsStringSync();
      for (final e in design) {
        expect(
          src.contains("case '$e':") || src.contains("case '$e' ||"),
          isTrue,
          reason: e,
        );
      }
      for (final screen in const [Size(390, 844), Size(360, 640), Size(430, 520)]) {
        for (final origin in [
          Offset(screen.width * .28, screen.height * .66),
          Offset(screen.width * .72, screen.height * .5),
        ]) {
          for (final e in design) {
            final fx = soloEmojiEffect(e,
                screen: screen, origin: origin, random: math.Random(7));
            expect(fx.particles, isNotEmpty, reason: e);
            if (e != '⚡' && e != '🤩') expect(fx.cards, isNotEmpty, reason: e);
            for (final d in [fx.durationMs, fx.layerMs, fx.cardMs, fx.screenMs]) {
              expect(d.isFinite, isTrue, reason: e);
              expect(d, lessThan(6000), reason: '$e $d');
            }
            expect(fx.durationMs, greaterThan(400), reason: e);
            for (final p in fx.particles) {
              expect(p.duration, greaterThan(0), reason: e);
              expect(p.frames, isNotEmpty, reason: e);
            }
          }
        }
      }
    });

    test('все 63 строятся быстро (и самые тяжёлые)', () {
      final sw = Stopwatch()..start();
      var total = 0;
      for (var k = 0; k < 3; k++) {
        for (final e in design) {
          total += soloEmojiEffect(e,
                  screen: _screen, origin: _origin, random: math.Random(k))
              .particles
              .length;
        }
      }
      sw.stop();
      expect(total, greaterThan(63 * 3 * 10));
      // Три полных прохода по всем 63 — с большим запасом даже на CI.
      expect(sw.elapsedMilliseconds, lessThan(1500));
      for (final e in ['🔥', '🎉', '🍾', '🏆', '😭', '😱']) {
        final w = Stopwatch()..start();
        soloEmojiEffect(e, screen: _screen, origin: _origin);
        expect(w.elapsedMilliseconds, lessThan(60), reason: e);
      }
    });

    test('ZWJ и знак варианта: ❤️‍🔥 и ❤ без U+FE0F — тот же эффект', () {
      expect(hasSoloEmojiEffect('❤️‍🔥'), isTrue);
      expect(hasSoloEmojiEffect('❤‍🔥'), isTrue);
      expect(hasSoloEmojiEffect('❤'), isTrue);
      expect(hasSoloEmojiEffect('☀'), isTrue);
      expect(hasSoloEmojiEffect(' 🫶 '), isTrue);
      expect(hasSoloEmojiEffect('🔥🔥'), isFalse);
      int n(String e) => soloEmojiEffect(e,
              screen: _screen, origin: _origin, random: math.Random(2))
          .particles
          .length;
      expect(n('❤‍🔥'), n('❤️‍🔥'));
      expect(n('❤'), n('❤️'));
      // ❤️‍🔥 — не ❤️ и не 🔥.
      expect(n('❤️‍🔥'), isNot(n('❤️')));
      expect(n('❤️‍🔥'), isNot(n('🔥')));
    });

    test('чат трясётся и качается, эмодзи окрашивается — и всё возвращается', () {
      SoloEmojiEffect fx(String e) => soloEmojiEffect(e,
          screen: _screen, origin: _origin, random: math.Random(4));
      for (final e in ['🤣', '🤪', '🤮', '🙄', '😱', '😳', '🤯', '💯', '🎁']) {
        final f = fx(e);
        expect(f.screen, isNotEmpty, reason: e);
        final mid = soloEmojiScreenPoseAt(f, f.screen.first.delay + f.screen.first.ms * .3);
        expect(mid, isNotNull, reason: e);
        expect(mid!.isIdentity(), isFalse, reason: e);
        expect(soloEmojiScreenPoseAt(f, f.screenMs + 1), isNull, reason: e);
      }
      // 🤣 качает чат вокруг середины экрана, 😳 — приближает к эмодзи.
      final zoom = soloEmojiScreenPoseAt(fx('😳'), 1000)!;
      final at = MatrixUtils.transformPoint(zoom, _origin);
      expect((at - _origin).distance, lessThan(.5));
      for (final e in ['😡', '😳', '⚡', '☀️']) {
        final f = fx(e);
        expect(f.tints, isNotEmpty, reason: e);
        final t = f.tints.first;
        expect(soloEmojiCardFilter(f, t.delay + t.ms * .5), isNotNull, reason: e);
        expect(soloEmojiCardFilter(f, f.cardMs + 1), isNull, reason: e);
      }
      // Без эффекта — без окраски и без движения чата.
      expect(fx('👍').tints, isEmpty);
      expect(soloEmojiCardFilter(fx('❤️'), 300), isNull);
      // Поворот эмодзи — вокруг 50 % / 85 % (как в макете), а не центра.
      final wobble = soloEmojiCardTransform(fx('😂'), 150);
      final pivot = MatrixUtils.transformPoint(
        wobble,
        const Offset(0, .35 * kSoloEmojiSize),
      );
      expect((pivot - const Offset(0, .35 * kSoloEmojiSize)).dy.abs(), lessThan(8));
      expect(soloEmojiCardTransform(fx('😂'), 5000).isIdentity(), isTrue);
    });

    test('слова-звукоподражания — латиницей, без русских слов', () {
      final words = <String>{};
      for (final e in design) {
        final f = soloEmojiEffect(e,
            screen: _screen, origin: _origin, random: math.Random(9));
        for (final p in f.particles) {
          if (p.shape == ReactionShape.word) words.add(p.glyph!);
        }
      }
      expect(words, containsAll(['HA-HA', 'HONK!', 'HONK HONK!', 'hmm…', 'oops…', 'Z', 'MWAHAHA', '!!']));
      for (final w in words) {
        expect(RegExp('[а-яА-ЯёЁіїєґ]').hasMatch(w), isFalse, reason: w);
      }
    });

    testWidgets('лента качается вместе с эффектом и встаёт на место', (t) async {
      resetSoloFxForTest();
      final nav = GlobalKey<NavigatorState>();
      final box = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Scaffold(
            body: SoloEmojiScreenMotion(
              child: SizedBox.expand(key: box, child: const ColoredBox(color: Colors.blue)),
            ),
          ),
        ),
      );
      final ctx = box.currentContext!;
      final fx = soloEmojiEffect('🤣',
          screen: const Size(800, 600), origin: const Offset(200, 400),
          random: math.Random(1));
      expect(playSoloEmojiFx(context: ctx, effect: fx, origin: const Offset(200, 400)), isTrue);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(soloEmojiScreenPose.value, isNotNull);
      final rt = ctx.findAncestorRenderObjectOfType<RenderTransform>()!;
      final m = Matrix4.identity();
      rt.applyPaintTransform(box.currentContext!.findRenderObject()! as RenderBox, m);
      expect(m.isIdentity(), isFalse);
      await t.pumpAndSettle();
      expect(soloEmojiScreenPose.value, isNull);
      final m2 = Matrix4.identity();
      rt.applyPaintTransform(box.currentContext!.findRenderObject()! as RenderBox, m2);
      expect(m2.isIdentity(), isTrue);
      expect(t.takeException(), isNull);
    });

    test('🔴 правила владельца: без вечной анимации, один за раз, Lottie не переигрывает', () {
      final src = File('lib/ui/chat/solo_emoji_fx.dart').readAsStringSync();
      expect(src.contains('repeat('), isFalse);
      expect(src.contains('if (_soloFxBusy) return false;'), isTrue);
      final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
      final at = chat.indexOf('class _SoloEmojiMessageState');
      final body = chat.substring(at, at + 9000);
      // Обёртка движения/окраски не пересоздаёт Lottie (глобальный ключ).
      expect(body.contains('key: _lottieKey'), isTrue);
      expect(body.contains('_lottieKey = GlobalKey()'), isTrue);
      expect(body.contains('soloEmojiCardFilter(e, ms)'), isTrue);
      expect(body.contains('media.disableAnimations'), isTrue);
      expect(chat.contains('return SoloEmojiScreenMotion(child: VideoNoteOutsideTap('), isTrue);
    });
  });
}
