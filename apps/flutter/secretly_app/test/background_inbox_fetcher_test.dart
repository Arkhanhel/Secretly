// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/push/background_inbox_fetcher.dart';
import 'package:secretly_app/push/background_worker.dart';

// BACKGROUND DRAIN (2026-07-16, delivery-wake audit, client P0): the FCM
// background fetcher must be a strict no-op unless it is provably safe AND
// useful to run. These tests pin the guard order: main-isolate liveness first
// (a live app owns the drain — concurrent staging is wasted DB pressure),
// then configuration (never touch identity/DB before registration).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stands down while the main-isolate heartbeat is fresh', () async {
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey:
          DateTime.now().millisecondsSinceEpoch - 1000,
      BackgroundInboxFetcher.prefsBaseUrlKey: 'https://relay.example',
      'device_id': 'dev-1',
      'profile_id': 'prof-1',
    });
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_main_alive');
  });

  test('runs once the heartbeat is stale (past the liveness guard)', () async {
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey:
          DateTime.now().millisecondsSinceEpoch -
              BackgroundInboxFetcher.mainIsolateFreshMs -
              1000,
      // Deliberately unconfigured: asserts the liveness guard was PASSED and
      // the next guard (configuration) is the one that stops the run — no
      // identity/keystore/DB is touched in a unit-test environment.
      BackgroundInboxFetcher.prefsBaseUrlKey: '',
      'device_id': '',
      'profile_id': '',
    });
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_unconfigured');
  });

  test('skips when never configured (fresh install, no registration)',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_unconfigured');
  });

  test('rejects an unparseable base url', () async {
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsBaseUrlKey: '::::not a url::::',
      'device_id': 'dev-1',
      'profile_id': 'prof-1',
    });
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_bad_base_url');
  });

  // ── Уступка перестала быть тупиком (12.08.2026) ──────────────────────────
  //
  // Замер: главный изолят замёрз, пуши пришли на 13-й, 17-й и 22-й секунде —
  // все внутри окна живости в 25 с, и проход трижды ушёл ни с чем. На 25-й
  // секунде отметка протухла, но будить стало нечем: пуши кончились, а дедуп
  // реле не даёт разбудить теми же конвертами. Смс пролежали ЧЕТЫРЕ МИНУТЫ.

  test('🔴 почти протухшую отметку ДОЖИДАЕТСЯ, а не бросает', () async {
    // Возраст 22 с — ровно случай из замера. Ждать остаётся 3,5 с, и это
    // влезает в бюджет прохода.
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey:
          DateTime.now().millisecondsSinceEpoch -
              BackgroundInboxFetcher.mainIsolateFreshMs +
              3000,
      BackgroundInboxFetcher.prefsBaseUrlKey: '',
      'device_id': '',
      'profile_id': '',
    });
    // Дошёл до следующей задвижки — значит живость ПРОПУСТИЛА его, дождавшись.
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_unconfigured');
  });

  test('🔴 дождавшись, УСТУПАЕТ если главный ожил', () async {
    // Инвариант «один писатель в ратчет» дороже скорости. Если за время
    // ожидания главный подал признак жизни — уходим, как и раньше.
    final aliveKey = BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey;
    SharedPreferences.setMockInitialValues({
      aliveKey: DateTime.now().millisecondsSinceEpoch -
          BackgroundInboxFetcher.mainIsolateFreshMs +
          3000,
      BackgroundInboxFetcher.prefsBaseUrlKey: '',
      'device_id': '',
      'profile_id': '',
    });
    final run = BackgroundInboxFetcher.debugRunForTest();
    // Пока он ждёт — оживляем главный изолят.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(aliveKey, DateTime.now().millisecondsSinceEpoch);
    expect(await run, 'skip_main_alive');
  });

  test('🔴 ждать дольше бюджета не пытается', () async {
    // Свежая отметка: ждать пришлось бы почти 25 секунд при бюджете прохода в
    // 12. Дождались бы протухания и не успели забрать — поменяли бы одну
    // неудачу на другую.
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey:
          DateTime.now().millisecondsSinceEpoch - 500,
      BackgroundInboxFetcher.prefsBaseUrlKey: 'https://relay.example',
      'device_id': 'dev-1',
      'profile_id': 'prof-1',
    });
    final started = DateTime.now();
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_main_alive');
    // И уходит СРАЗУ, не съедая бюджет впустую.
    expect(DateTime.now().difference(started).inSeconds, lessThan(2));
  });

  test('давно протухшая отметка не заставляет ждать вовсе', () async {
    SharedPreferences.setMockInitialValues({
      BackgroundInboxFetcher.prefsMainIsolateAliveAtMsKey:
          DateTime.now().millisecondsSinceEpoch -
              BackgroundInboxFetcher.mainIsolateFreshMs -
              60000,
      BackgroundInboxFetcher.prefsBaseUrlKey: '',
      'device_id': '',
      'profile_id': '',
    });
    final started = DateTime.now();
    expect(await BackgroundInboxFetcher.debugRunForTest(), 'skip_unconfigured');
    expect(DateTime.now().difference(started).inSeconds, lessThan(2));
  });

  // Ограничитель заказов: без него активная переписка сыпала бы заказами в
  // планировщик, а Android за это душит его целиком — вместе с уже работающей
  // 15-минутной страховкой.
  test('🔴 повтор заказывается не чаще раза в минуту', () {
    const gap = BackgroundWorker.standDownRetryMinIntervalMs;
    // Ни разу не заказывали: отметки нет (0), а «сейчас» — эпоха.
    expect(
      BackgroundWorker.shouldScheduleStandDownRetry(
        lastAtMs: 0,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      ),
      isTrue,
    );
    expect(
      BackgroundWorker.shouldScheduleStandDownRetry(
          lastAtMs: 1000, nowMs: 1000 + gap - 1),
      isFalse,
    );
    expect(
      BackgroundWorker.shouldScheduleStandDownRetry(
          lastAtMs: 1000, nowMs: 1000 + gap),
      isTrue,
    );
  });
}
