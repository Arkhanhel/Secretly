// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart';

/// «Обои проводят сообщение» (2026-08-02).
///
/// Эта фича почти всё время обязана МОЛЧАТЬ: волна возникает на отправку и на
/// приход, и больше нигде. Молчание глазами не проверишь — отсюда тесты.
///
/// Что здесь НЕ проверяется и почему: сам шейдер. `FragmentProgram.fromAsset`
/// требует скомпилированного шейдера и GPU, которых у `flutter test` нет.
/// Поэтому проверяется всё, что решает, ЗАПУСКАТЬ ли волну и в какую сторону —
/// а отрисовка проверяется на устройстве. Painter при отсутствии шейдера или
/// поля не рисует слой вовсе, так что тестовая среда идёт по тому же пути, что
/// и телефон, на котором шейдер не загрузился.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TelegramWallpaperState> pump(
    WidgetTester tester, {
    required bool conduct,
    GlobalKey<TelegramWallpaperState>? key,
  }) async {
    final k = key ?? GlobalKey<TelegramWallpaperState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TelegramWallpaper(
          key: k,
          conduct: conduct,
          mode: ChatWallpaperAnimMode.off,
        ),
      ),
    );
    await tester.pump();
    return k.currentState!;
  }

  /// 🔴 Выключенный эффект не должен стоить НИЧЕГО — ни декода поля, ни
  /// компиляции шейдера. Иначе «выключено» означает лишь «невидимо».
  testWidgets('🔴 выключенный эффект не грузит ни поле, ни шейдер',
      (tester) async {
    final state = await pump(tester, conduct: false);
    expect(state.pulseAssetsRequested, isFalse);
    state.conductMessage(incoming: true);
    await tester.pump();
    expect(state.isConducting, isFalse,
        reason: 'при выключенном эффекте волна не имеет права запускаться');
    expect(state.pulseAssetsRequested, isFalse);
  });

  testWidgets('включённый эффект проводит сообщение', (tester) async {
    final state = await pump(tester, conduct: true);
    expect(state.isConducting, isFalse, reason: 'в покое волны нет');
    state.conductMessage(incoming: false);
    await tester.pump();
    expect(state.isConducting, isTrue);
    await tester.pump(kWallpaperPulseDuration + const Duration(milliseconds: 50));
    expect(state.isConducting, isFalse, reason: 'волна обязана закончиться');
  });

  testWidgets('направление света = направление общения', (tester) async {
    final state = await pump(tester, conduct: true);
    state.conductMessage(incoming: false);
    await tester.pump();
    expect(state.conductDirTop, 0, reason: 'исходящее уходит вверх');
    await tester.pump(kWallpaperPulseDuration + const Duration(milliseconds: 50));

    state.conductMessage(incoming: true);
    await tester.pump();
    expect(state.conductDirTop, 1, reason: 'входящее стекает сверху');
    await tester.pump(kWallpaperPulseDuration + const Duration(milliseconds: 50));
  });

  /// 🔴 БЫСТРАЯ ОТПРАВКА (правка по полевому отчёту 02.08.2026: «если писать
  /// быстро, анимации нет, пока не закончится прошлая»).
  ///
  /// Первая версия глушила новые волны, пока летит старая. Для пачки входящих
  /// это правильно, а для человека, который быстро пишет, — нет: он видит одну
  /// волну на пять сообщений. Теперь волны идут ДРУГ ЗА ДРУГОМ.
  testWidgets('🔴 быстрая отправка даёт волну за волной, а не одну',
      (tester) async {
    final state = await pump(tester, conduct: true);
    state.conductMessage(incoming: false);
    await tester.pump();
    expect(state.conductingCount, 1);

    // Пишем быстро: каждые 150 мс — заметно быстрее, чем 1.6 с жизни волны.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      state.conductMessage(incoming: false);
    }
    await tester.pump();
    expect(state.conductingCount, 4,
        reason: 'каждое сообщение обязано завести свою волну');

    // Пятая вытесняет самую старую, а не отбрасывается и не копится без конца.
    await tester.pump(const Duration(milliseconds: 150));
    state.conductMessage(incoming: false);
    await tester.pump();
    expect(state.conductingCount, kWallpaperMaxConcurrentPulses);

    await tester.pump(kWallpaperPulseDuration * 2);
    expect(state.isConducting, isFalse, reason: 'все волны обязаны догореть');
  });

  /// Встречные волны: исходящее и входящее летят одновременно и в разные
  /// стороны — это и есть «фон участвует в разговоре».
  testWidgets('исходящая и входящая волны летят одновременно навстречу',
      (tester) async {
    final state = await pump(tester, conduct: true);
    state.conductMessage(incoming: false);
    await tester.pump(const Duration(milliseconds: 200));
    state.conductMessage(incoming: true);
    await tester.pump();
    expect(state.conductingCount, 2);
    expect(state.conductDirTop, 1, reason: 'последняя заведённая — входящая');
    await tester.pump(kWallpaperPulseDuration * 2);
  });

  /// Потолок: пятая волна вытесняет самую старую, а не копится без конца.
  ///
  /// Отдельно про то, чего здесь НАМЕРЕННО нет: «минимального зазора» между
  /// волнами. Он выглядел экономией, но шейдер всё равно считает все четыре
  /// слота на каждый пиксель, так что лишняя волна не стоит ни одной операции
  /// на GPU — а зазор ровно и давал то, на что пожаловались.
  testWidgets('несколько сообщений в один кадр не ломают потолок',
      (tester) async {
    final state = await pump(tester, conduct: true);
    for (var i = 0; i < 7; i++) {
      state.conductMessage(incoming: false);
    }
    await tester.pump();
    expect(state.conductingCount, kWallpaperMaxConcurrentPulses);
    await tester.pump(kWallpaperPulseDuration * 2);
    expect(state.isConducting, isFalse);
  });

  /// 🔴 Кадры в фоне — чистая потеря батареи: их никто не видит, а рисуются они
  /// на том же GPU.
  testWidgets('🔴 уход в фон гасит летящую волну немедленно', (tester) async {
    final state = await pump(tester, conduct: true);
    state.conductMessage(incoming: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.isConducting, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(state.isConducting, isFalse,
        reason: 'волна обязана гаснуть сразу, а не «когда долетит»');

    // И в фоне новую не заводим.
    state.conductMessage(incoming: false);
    await tester.pump();
    expect(state.isConducting, isFalse);
  });

  testWidgets('выключение посреди волны гасит её, а не ждёт конца',
      (tester) async {
    final key = GlobalKey<TelegramWallpaperState>();
    final state = await pump(tester, conduct: true, key: key);
    state.conductMessage(incoming: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.isConducting, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: TelegramWallpaper(
          key: key,
          conduct: false,
          mode: ChatWallpaperAnimMode.off,
        ),
      ),
    );
    await tester.pump();
    expect(key.currentState!.isConducting, isFalse);
  });

  /// 🔴 Запечённое поле — единственное, что делает волну физикой, а не бегущей
  /// полосой. Если оно потеряется или перезапечётся неправильно, эффект тихо
  /// выродится, и заметить это на глаз почти невозможно.
  test('🔴 поле расстояний на месте и осмысленно', () async {
    final file = File('assets/wallpaper_fx/pattern_field.png');
    expect(file.existsSync(), isTrue,
        reason: 'пересобирается tools/bake_wallpaper_field.py');

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, 270);
    expect(image.height, 480);

    final data = await image.toByteData();
    final px = data!.buffer.asUint8List();
    var minR = 255, maxR = 0, minG = 255, maxG = 0, maxB = 0;
    for (var i = 0; i < px.length; i += 4) {
      if (px[i] < minR) minR = px[i];
      if (px[i] > maxR) maxR = px[i];
      if (px[i + 1] < minG) minG = px[i + 1];
      if (px[i + 1] > maxG) maxG = px[i + 1];
      if (px[i + 2] > maxB) maxB = px[i + 2];
    }
    // Оба поля обязаны покрывать почти весь диапазон: иначе волна не дойдёт от
    // края до края и оборвётся на полпути.
    expect(minR, lessThan(8));
    expect(maxR, greaterThan(240));
    expect(minG, lessThan(8));
    expect(maxG, greaterThan(240));
    expect(maxB, 0, reason: 'синий канал не используется — обязан быть пуст');
    image.dispose();
  });
}
