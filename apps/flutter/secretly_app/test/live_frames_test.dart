// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЖИВЫЕ РАМКИ: каталог, вырез под фотографию, порог размера, нажатие.
//
// Двадцать четыре персонажа приходят готовым набором `profile_fx` — его файлы
// выгружены со страницы дизайна и правке не подлежат. Проверять надо не их
// внутренности, а СТЫК: то, что мы вокруг них построили и что сломается при
// следующей выгрузке, если стык разойдётся.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';
import 'package:secretly_app/ui/widgets/framed_avatar.dart';

Future<ui.Image> _render(
  String id,
  double box, {
  bool pressed = false,
  bool ringOnly = false,
  double pad = 0,
  double seconds = 3,
}) async {
  final sim = makeLiveFrame(id)!..active = pressed;
  for (var i = 0; i < seconds * 60; i++) {
    sim.tick(1 / 60);
  }
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.translate(pad, pad);
  LiveFramePainter(
    sim: sim,
    palette: FramePalette(true, const Color(0xFF16161A)),
    ringOnly: ringOnly,
  ).paint(canvas, Size.square(box));
  final side = (box + pad * 2).round();
  return rec.endRecording().toImage(side, side);
}

Future<Uint8List> _pixels(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();

void main() {
  group('каталог', () {
    test('🔴 живые рамки НЕ попали в список атласа', () {
      // Семь проверок вокруг kAvatarFrames пекут петли. У живых рамок петли
      // нет, и попадание туда означало бы печь несуществующее.
      final atlas = kAvatarFrames.map((f) => f.id).toSet();
      for (final id in kLiveFrameIds) {
        expect(atlas.contains(id), isFalse, reason: '$id пролез в атлас');
      }
    });

    test('набор перенесён целиком, идентификаторы не столкнулись', () {
      expect(kLiveFrameIds.length, 24);
      final ids = kAllAvatarFrames.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, kAvatarFrames.length + kLiveFrameIds.length);
      for (final id in kLiveFrameIds) {
        expect(frameById(id), isNotNull, reason: 'рамка $id не рисуется');
        expect(makeLiveFrame(id), isNotNull);
      }
      expect(makeLiveFrame('cosmic'), isNull, reason: 'обычная рамка не живая');
    });

    testWidgets('название переведено на все восемь языков', (tester) async {
      for (final tag in const ['ru', 'en', 'uk', 'es', 'pt', 'fr', 'de']) {
        late BuildContext ctx;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Localizations(
              locale: Locale(tag),
              delegates: const [
                DefaultWidgetsLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
              ],
              child: Builder(
                builder: (c) {
                  ctx = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        for (final f in kLivingAvatarFrames) {
          expect(
            f.nameLocalized(ctx).trim(),
            isNotEmpty,
            reason: '${f.id}/$tag: названия нет',
          );
        }
      }
    });
  });

  group('кнопка «разбудить»', () {
    test('🔴 у каждой рамки СВОЙ глагол на восьми языках', () {
      // Общее «Оживить» на все двадцать четыре было бы короче, но перестало бы
      // объяснять, что произойдёт: кота гладят, пластинку скретчат, призрак
      // говорит «бу». Новая рамка без подписи молча осталась бы без кнопки —
      // здесь это падение, а не сюрприз на экране.
      for (final id in kLiveFrameIds) {
        for (final tag in const ['ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de']) {
          final label = liveFrameActionLabelForLocale(tag, id);
          expect(label, isNotNull, reason: '$id/$tag: подписи нет');
          expect(label!.trim(), isNotEmpty);
        }
      }
      expect(liveFrameActionLabelForLocale('ru', 'cosmic'), isNull);
      expect(liveFrameActionLabelForLocale('ru', null), isNull);
    });

    test('🔴 у каждой рамки задано время возврата, и оно в разумных границах', () {
      // Выходка возвращается сама. Ноль означал бы, что её никто не увидит,
      // а десяток секунд — что человек будет ждать, пока кот отпустит уши.
      for (final id in kLiveFrameIds) {
        final d = liveFrameActionDuration(id);
        expect(d.inMilliseconds, greaterThanOrEqualTo(1000), reason: id);
        expect(d.inMilliseconds, lessThanOrEqualTo(6000), reason: id);
      }
    });

    testWidgets('🔴 нажатие доходит до персонажа сквозь чужой портрет', (
      tester,
    ) async {
      // Рамку рисует не тот, кто знает про нажатие: `FramedAvatar` зовёт
      // `frame.builder(size)` — подпись, общая у всех сорока четырёх рамок.
      // Проверяем сквозной путь: область наверху, портрет внизу.
      final press = ValueNotifier<bool>(false);
      addTearDown(press.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LiveFramePressScope(
            pressed: press,
            child: const Center(
              child: FramedAvatar(
                size: 96,
                fallbackSeed: 'seed',
                fallbackName: 'Имя',
                frameId: 'cat',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      final state = tester.state(find.byType(LiveFrameView));
      expect((state as dynamic).debugSim.active, isFalse);

      press.value = true;
      await tester.pump();
      expect(
        (state as dynamic).debugSim.active,
        isTrue,
        reason: 'персонаж не узнал о нажатии',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 выходка заканчивается САМА, вторым нажатием не надо', (
      tester,
    ) async {
      // Решение владельца 23.09.2026. Нажатие здесь — тычок, а не режим:
      // оставлять человека с кнопкой «выключить обратно» значит превращать
      // шалость в то, про что надо помнить.
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: LiveFramePressHost(
            frameId: 'ghost',
            child: Builder(
              builder: (c) {
                inner = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final press = LiveFramePressScope.controllerOf(inner)!;
      press.value = true;
      await tester.pump();
      expect(LiveFramePressScope.of(inner), isTrue);

      // «Бу!» длится 1.8 с — за секунду до конца состояние ещё держится.
      await tester.pump(liveFrameActionDuration('ghost') * 0.5);
      expect(press.value, isTrue, reason: 'выходка оборвалась на полуслове');
      await tester.pump(liveFrameActionDuration('ghost'));
      expect(press.value, isFalse, reason: 'персонаж не вернулся в покой');
    });
  });

  group('рисование', () {
    test('🔴 вырез под фотографию: центр вне задних частей', () {
      for (final id in kLiveFrameIds) {
        final sim = makeLiveFrame(id)!;
        final hole = LiveFramePainter.photoHole(sim);
        expect(
          hole.contains(Offset(sim.cx, sim.cy)),
          isFalse,
          reason: '$id: задние части полезли на лицо',
        );
        expect(
          hole.contains(Offset(sim.cx, sim.cy - sim.av - 6)),
          isTrue,
          reason: '$id: за краем фотографии рисовать нечем',
        );
      }
    });

    testWidgets('🔴 ни одна рамка не закрывает лицо', (tester) async {
      // Рамка — украшение ВОКРУГ портрета. Единственное исключение — свет
      // экрана у «Кодера»: он и должен падать на лицо, но остаётся плёнкой
      // (около 50 из 255), а не заслонкой.
      await tester.runAsync(() async {
        for (final id in kLiveFrameIds) {
          for (final pressed in const [false, true]) {
            final img = await _render(id, 200, pressed: pressed);
            final b = await _pixels(img);
            var worst = 0;
            for (var y = 80; y < 120; y++) {
              for (var x = 80; x < 120; x++) {
                final a = b[(y * 200 + x) * 4 + 3];
                if (a > worst) worst = a;
              }
            }
            expect(
              worst,
              lessThan(96),
              reason: '$id (${pressed ? 'нажато' : 'покой'}): лицо закрыто '
                  'непрозрачностью $worst',
            );
          }
        }
      });
    });

    testWidgets('🔴 в строке списка рисуется ОДНО кольцо и не вылезает', (
      tester,
    ) async {
      // Холст персонажа почти вдвое шире портрета: в строке списка наушники
      // «Меломана» легли бы на имя собеседника.
      await tester.runAsync(() async {
        const box = 40.0, pad = 60.0;
        for (final id in kLiveFrameIds) {
          final img = await _render(id, box, ringOnly: true, pad: pad);
          final b = await _pixels(img);
          final w = img.width;
          // Допуск в 6 % — это сам край кольца: он проходит ровно по стороне
          // квадрата, а «дыхание» добавляет к радиусу полторы единицы макета.
          const slack = box * 0.06;
          var outside = 0;
          for (var y = 0; y < img.height; y++) {
            for (var x = 0; x < w; x++) {
              final inBox =
                  x >= pad - slack &&
                  x < pad + box + slack &&
                  y >= pad - slack &&
                  y < pad + box + slack;
              if (!inBox && b[(y * w + x) * 4 + 3] > 8) outside++;
            }
          }
          expect(outside, 0, reason: '$id: вылез на $outside точек');
        }
      });
    });

    testWidgets('🔴 в большом размере персонаж ВЫХОДИТ за квадрат', (
      tester,
    ) async {
      // Обратная половина: если однажды вылет «починят» обрезкой, от
      // персонажа останется одно кольцо и пропадёт вся затея.
      await tester.runAsync(() async {
        var flat = 0;
        for (final id in kLiveFrameIds) {
          const box = 120.0, pad = 90.0;
          final img = await _render(id, box, pad: pad);
          final b = await _pixels(img);
          final w = img.width;
          var outside = 0;
          for (var y = 0; y < img.height; y++) {
            for (var x = 0; x < w; x++) {
              final inBox = x >= pad && x < pad + box && y >= pad && y < pad + box;
              if (!inBox && b[(y * w + x) * 4 + 3] > 8) outside++;
            }
          }
          if (outside < 50) flat++;
        }
        // Не у каждой рамки есть что вынести за край — «Аура» и «Жидкий хром»
        // живут на самом кольце. Но если за край не выходит НИКТО, значит
        // обрезали всех.
        expect(flat, lessThan(kLiveFrameIds.length - 8),
            reason: 'персонажи перестали выходить за квадрат');
      });
    });

    testWidgets('кадр рисуется без исключений на всех размерах', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final id in kLiveFrameIds) {
          for (final s in const [40.0, 64.0, 96.0, 164.0]) {
            final img = await _render(id, s, seconds: 1);
            expect(img.width, s.round());
          }
        }
      });
    });
  });

  group('в настоящем окне', () {
    testWidgets('🔴 портрет с любой живой рамкой живёт и умирает без ошибок', (
      tester,
    ) async {
      // Пиксельные проверки рисуют холст напрямую и не трогают виджет: тикер,
      // подписку на TickerMode и dispose не проверяет никто. Ровно там и живут
      // поломки, которые видно только запущенным приложением.
      for (final id in kLiveFrameIds) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: FramedAvatar(
                size: 96,
                fallbackSeed: 'seed',
                fallbackName: 'Имя',
                frameId: id,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull, reason: '$id упал на кадре');
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        expect(tester.takeException(), isNull, reason: '$id упал на снятии');
      }
    });

    testWidgets('🔴 список гасит движение, а персонажа оставляет', (
      tester,
    ) async {
      // Решение владельца 23.09.2026: в шапке чата и на значке внизу рамки
      // живые, в списках — те же персонажи, но неподвижные. Различает их не
      // размер (52 в списке против 42 в шапке), а МЕСТО: список выключает
      // `TickerMode`, и живая рамка это видит.
      await tester.pumpWidget(
        const MaterialApp(
          home: TickerMode(
            enabled: false,
            child: Center(
              child: FramedAvatar(
                size: 52,
                fallbackSeed: 'seed',
                fallbackName: 'Имя',
                frameId: 'music',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      // Если бы тикер крутился, `pumpAndSettle` не сошёлся бы никогда.
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    });

    test('🔴 рамка на десктопе НЕ пропадает с выключенной анимацией', () {
      // Настройка называется «Анимация рамок и статусов». Раньше здесь стоял
      // `animateFrames ? frameById(...) : null`, и выключение убирало
      // украшение целиком: у собеседника пропадала купленная рамка, а в окне
      // выбора плитки показывали голый портрет.
      final src = File(
        'lib/ui/desktop/primitives/avatar.dart',
      ).readAsStringSync();
      expect(src.contains('frameById(frameId) : null'), isFalse);
      expect(src.contains('final frame = frameById(frameId);'), isTrue);
      expect(src.contains('enabled: animateFrames'), isTrue);
    });
  });
}
