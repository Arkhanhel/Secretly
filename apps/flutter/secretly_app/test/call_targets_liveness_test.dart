// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/transport/relay_client.dart';

/// 🔴 ЗВОНОК ЗОВЁТ ТОЛЬКО ТЕХ, КТО МОЖЕТ ОТВЕТИТЬ СЕЙЧАС.
///
/// ЗАМЕР 15.08: половина сигналов звонка уходила на копию устройства,
/// оставшуюся от переустановки (молчит пятые сутки, токена пушей нет). Каждый
/// её сигнал — запрос в лимит по IP, а лимит рвёт живой разговор:
///
///   fcbea652 → baecdd9f: 23   живой iPhone
///   fcbea652 → 7d1e2be2: 22   мёртвая копия
///
/// 🔴 СООБЩЕНИЯ ЭТИМ ПРАВИЛОМ НЕ ЗАТРОНУТЫ. Копия им не мешает: сообщение
/// полежит в ящике семь дней и дождётся хозяина. Исключать её из ДОСТАВКИ
/// нельзя — человек из отпуска вернулся бы к пустому чату.
void main() {
  const nowMs = 1_800_000_000_000;
  const day = 24 * 60 * 60 * 1000;

  RelayDeviceLiveness live(String id, int silentDays, {bool superseded = false}) =>
      RelayDeviceLiveness(
        deviceId: id,
        lastSignalMs: nowMs - silentDays * day,
        superseded: superseded,
      );

  test('🔴 молчание БОЛЬШЕ НЕ отсеивает — звоним на все устройства (В-1)', () {
    // 🔴 ПРАВИЛО ПЕРЕВЁРНУТО 11.09.2026, и это осознанно.
    //
    // Раньше здесь ожидалось `['iphone']`: копия, молчащая пятые сутки,
    // отбрасывалась. Полевой разбор показал, что признак «давно молчит» не
    // равен «не может ответить»:
    //
    //   * телефон владельца числился молчащим трое суток — он не ходит на
    //     реле сам, ему приходят пуши, и будится он мгновенно;
    //   * десктоп, открытый накануне, выглядел свежим — но был закрыт, и
    //     будить его нечем.
    //
    // Отбор оставлял десктоп и выбрасывал телефон: звонок не приходил вовсе.
    // Требование владельца — звонить на ВСЕ подключённые устройства.
    //
    // Прежнее опасение (лишние сигналы жгут предел по IP) закрывается
    // потолком веера и отсевом `superseded`, а не выбором одного устройства.
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['iphone', 'копия'],
      liveness: [live('iphone', 0), live('копия', 5)],
      nowMs: nowMs,
    );
    expect(out, ['iphone', 'копия']);
  });

  test('🔴 потолок веера: больше пяти устройств не зовём', () {
    final many = List<String>.generate(8, (i) => 'dev$i');
    final out = AppController.narrowCallTargetsByLiveness(
      targets: many,
      // dev0 самый свежий, dev7 самый давний.
      liveness: [for (var i = 0; i < 8; i++) live('dev$i', i)],
      nowMs: nowMs,
    );
    expect(out.length, 5, reason: 'потолок веера');
    expect(out, ['dev0', 'dev1', 'dev2', 'dev3', 'dev4'],
        reason: 'режем по свежести — первыми идут те, кто вероятнее ответит');
  });

  test('🔴 вытеснённое устройство отсеивается даже при расширенном веере', () {
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['живое', 'вытеснено'],
      liveness: [live('живое', 9), live('вытеснено', 0, superseded: true)],
      nowMs: nowMs,
    );
    expect(out, ['живое'],
        reason: 'superseded — единственная оставшаяся причина отсева');
  });

  test('🔴 устройство, молчавшее НОЧЬ, остаётся — оно живое', () {
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['телефон', 'планшет'],
      liveness: [live('телефон', 0), live('планшет', 1)],
      nowMs: nowMs,
    );
    expect(out, ['телефон', 'планшет'], reason: 'сутки молчания — это не смерть');
  });

  test('🔴 НИКОГДА не сужает до пустого — иначе звонки исчезнут совсем', () {
    // Единственный телефон, не заходивший неделю. Если отсеять — человек
    // перестанет принимать звонки вовсе.
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['единственный'],
      liveness: [live('единственный', 7)],
      nowMs: nowMs,
    );
    expect(out, ['единственный']);

    final both = AppController.narrowCallTargetsByLiveness(
      targets: const ['один', 'два'],
      liveness: [live('один', 9), live('два', 11)],
      nowMs: nowMs,
    );
    expect(both, ['один', 'два'], reason: 'все молчат — зовём всех, как раньше');
  });

  test('🔴 старое реле не присылает отметок — ведём себя как раньше', () {
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['a', 'b'],
      liveness: const [],
      nowMs: nowMs,
    );
    expect(out, ['a', 'b']);
  });

  test('устройство, о котором реле не знает, остаётся', () {
    // Не нам хоронить то, о чём нет данных.
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['известное', 'новое'],
      liveness: [live('известное', 0)],
      nowMs: nowMs,
    );
    expect(out, ['известное', 'новое']);
  });

  test('вытесненное устройство отсеивается независимо от молчания', () {
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['живое', 'вытесненное'],
      liveness: [live('живое', 0), live('вытесненное', 0, superseded: true)],
      nowMs: nowMs,
    );
    expect(out, ['живое']);
  });

  test('🔴 прыжок часов не отсеивает живое устройство', () {
    // Отметка «в будущем» из-за расхождения часов не повод молчать.
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['a', 'b'],
      liveness: [
        live('a', 0),
        RelayDeviceLiveness(deviceId: 'b', lastSignalMs: nowMs + 5 * day, superseded: false),
      ],
      nowMs: nowMs,
    );
    expect(out, ['a', 'b']);
  });

  test('одно устройство в списке не трогается вовсе', () {
    final out = AppController.narrowCallTargetsByLiveness(
      targets: const ['единственный'],
      liveness: [live('единственный', 30)],
      nowMs: nowMs,
    );
    expect(out, ['единственный']);
  });

  group('лечение сессии', () {
    test('🔴 мёртвую копию НЕ лечим — конверт до неё не доедет', () {
      expect(
        AppController.healTargetLooksUnreachableIn(
          liveness: [live('копия', 5)],
          deviceId: 'копия',
          nowMs: nowMs,
        ),
        isTrue,
      );
    });

    test('🔴 живое устройство лечим — иначе сессия не починится', () {
      // Убрать лечение у живых значит вернуть «однажды подружились, больше
      // никогда не починится» (инцидент 13.07).
      expect(
        AppController.healTargetLooksUnreachableIn(
          liveness: [live('телефон', 0)],
          deviceId: 'телефон',
          nowMs: nowMs,
        ),
        isFalse,
      );
    });

    test('🔴 нет данных о устройстве — ЛЕЧИМ, как раньше', () {
      // Молчание реле не доказывает смерть устройства.
      expect(
        AppController.healTargetLooksUnreachableIn(
          liveness: const [],
          deviceId: 'неизвестное',
          nowMs: nowMs,
        ),
        isFalse,
      );
    });

    test('устройство, молчавшее ночь, лечим', () {
      expect(
        AppController.healTargetLooksUnreachableIn(
          liveness: [live('планшет', 1)],
          deviceId: 'планшет',
          nowMs: nowMs,
        ),
        isFalse,
      );
    });

    test('вытесненное устройство не лечим', () {
      expect(
        AppController.healTargetLooksUnreachableIn(
          liveness: [live('старое', 0, superseded: true)],
          deviceId: 'старое',
          nowMs: nowMs,
        ),
        isTrue,
      );
    });
  });
}
