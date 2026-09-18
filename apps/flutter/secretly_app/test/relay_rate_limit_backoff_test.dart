// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

/// 🔴 ОТСТУПЛЕНИЕ ПРИ «СЛИШКОМ МНОГО ЗАПРОСОВ».
///
/// ЗАМЕР 14.08 (8 минут поля, звонки владельца): **413 запросов выборки и 438
/// ответов 429**. Ящик был закрыт больше половины времени, принятый звонок не
/// собирался — `offer` и `ice` не могли доехать, `call_ended reason=timeout`.
///
/// Корень не в лимите реле, а в том, что клиент его НЕ ЗАМЕЧАЛ: на 429 он делал
/// `return` без паузы, и следующий запрос уходил через 0,4 секунды. Бакет не
/// успевал восстановиться никогда — приложение держало себя в блокировке само.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 🔴 Ступень отступления укорочена НА ВРЕМЯ ТЕСТА. С настоящей секундой этот
  // файл держал прогон и сдвигал тайминг соседних тестов — один из них уже упал
  // так, проходя при этом в одиночку.
  setUp(() => RelayClient.rateLimitBackoffStartMsForTest = 120);
  tearDown(() => RelayClient.rateLimitBackoffStartMsForTest = 1000);

  Future<RelayClient> build({
    required AppDb db,
    required http.Client httpClient,
    required SimpleKeyPair identityKeyPair,
  }) async => RelayClient(
    db: db,
    deviceId: 'self-device',
    selfProfileId: 'self-profile',
    deviceKeys: DeviceKeys.create(),
    wsUrl: Uri.parse('ws://example.test/ws'),
    httpBaseUrl: Uri.parse('https://example.test'),
    httpClient: httpClient,
    identityKeyPairOverride: identityKeyPair,
    onDelivered: ({required msgId, required ciphertextB64}) async => true,
    loadNextSeq: () async => 1,
    saveNextSeq: (_) async {},
  );

  test('🔴 после 429 следующая выборка НЕ идёт в сеть', () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      return http.Response('rate_limited', 429);
    });
    final relay = await build(db: db, httpClient: client, identityKeyPair: kp);

    await relay.pumpInbox(force: true);
    expect(requests, 1, reason: 'первый запрос обязан уйти');

    // Раньше здесь уходил второй запрос — и так по разу в 0,4 секунды, пока
    // человек ждал звонка.
    await relay.pumpInbox(force: true);
    await relay.pumpInbox(force: true);
    expect(
      requests,
      1,
      reason: 'пока держится отступление, в сеть не ходим ни разу',
    );
  });

  test('🔴 успешный ответ снимает отступление — молчать вечно нельзя', () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    var requests = 0;
    var refuse = true;
    final client = MockClient((request) async {
      requests += 1;
      if (refuse) return http.Response('rate_limited', 429);
      return http.Response('{"items":[]}', 200);
    });
    final relay = await build(db: db, httpClient: client, identityKeyPair: kp);

    await relay.pumpInbox(force: true);
    expect(requests, 1);

    // Ждём дольше первой ступени и отвечаем успехом.
    refuse = false;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await relay.pumpInbox(force: true);
    expect(requests, 2, reason: 'после паузы запрос обязан уйти');

    // Успех обнулил отступление: следующая выборка идёт сразу.
    await relay.pumpInbox(force: true);
    expect(
      requests,
      3,
      reason: 'лимит — состояние сервера, держаться за него дольше нужного '
          'значит терять доставку',
    );
  });

  test('🔴 ПАЧКА отказов не разгоняет паузу до потолка', () async {
    // ЗАМЕР ПОЛЯ 15.08 во время звонка: пауза выросла 1→2→4→8→16→30 секунд за
    // 160 МИЛЛИСЕКУНД, потому что удваивалась на каждый отказ из пачки.
    // Полминуты молчания посреди разговора убивают звонок вернее, чем
    // исходное долбление сервера.
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      return http.Response('rate_limited', 429);
    });
    final relay = await build(db: db, httpClient: client, identityKeyPair: kp);

    // Пачка одновременных выборок — так и ведёт себя звонок.
    await Future.wait([
      relay.pumpInbox(force: true),
      relay.pumpInbox(force: true),
      relay.pumpInbox(force: true),
      relay.pumpInbox(force: true),
    ]);

    // Ждём чуть дольше ОДНОЙ ступени. Если пачка разогнала паузу — запрос не
    // уйдёт, и это тот самый отказ доставки посреди звонка.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final before = requests;
    await relay.pumpInbox(force: true);
    expect(
      requests,
      before + 1,
      reason: 'после ОДНОЙ ступени связь обязана вернуться, а не молчать 30 с',
    );
  });
}
