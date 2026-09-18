// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/session_v1.dart';
import 'package:secretly_app/ratchet/wire_v1.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/attested_senders.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔴 ЧУЖИЕ СЛУЖЕБНЫЕ КОМАНДЫ (17.09.2026, docs/TZ_SENDER_AUTH_2026-09-17.md).
//
// Номер устройства отправителя — слова самого провода: рукопожатие подписи
// не несёт, реле отправителя не сообщает. Проверено настоящей криптографией:
// чужак с одной лишь открытой связкой ключей получателя назывался его же
// телефоном или компьютером, и провод открывался. Отсюда:
//   • провод от имени САМОГО устройства проходил проверку «своё устройство»;
//   • «сеанс завершён» от «своего» стирал приложение сразу;
//   • «очистить историю» стирала любую названную переписку от кого угодно;
//   • реакции ставились и снимались за других людей и в чужих чатах;
//   • конверт комнаты привязывал устройство к любому профилю, и к моему.

const _me = 'owner-1';
const _myDevice = 'owner-device';
const _myDesktop = 'owner-desktop';

String _command(String prefix, Map<String, Object?> body) =>
    '$prefix${base64Url.encode(utf8.encode(jsonEncode(body)))}';

Future<({AppController controller, AppDb db})> _owner() async {
  final db = await AppDb.openForTesting();
  addTearDown(db.close);
  final controller = AppController()
    ..seedRoomRuntimeForTesting(
      db: db,
      profileId: _me,
      deviceId: _myDevice,
      crypto: DartCryptoProvider(
        Uint8List.fromList(List<int>.generate(32, (i) => i)),
      ),
    )
    ..seedKnownOwnDeviceIdsForTesting(const <String>[_myDesktop]);
  return (controller: controller, db: db);
}

Future<bool> _deliver(
  AppController controller,
  AppDb db,
  String text, {
  required String senderDeviceId,
  String? senderProfileId,
  int nowMs = 50000,
}) {
  final payload = E2ePayloadV1(
    senderDeviceId: senderDeviceId,
    createdAtMs: nowMs,
    events: [MsgEventV1(eventId: 'wrap-${text.hashCode}', text: text)],
  );
  return controller.handleDecryptedInboundPayloadForTesting(
    db: db,
    msgId: 'transport-${text.hashCode}-$senderDeviceId',
    ciphertextB64: 'AA==',
    plainBytes: Uint8List.fromList(payload.encode()),
    payload: payload,
    senderDeviceId: senderDeviceId,
    senderProfileId: senderProfileId,
    nowMs: nowMs,
  );
}

Future<void> _message(
  AppDb db, {
  required String convoId,
  required String payloadEventId,
  int createdAtMs = 1000,
}) {
  return db.insertEvent(
    eventId: 'local-$payloadEventId',
    convoId: convoId,
    type: 'msg',
    senderDeviceId: 'someone',
    ciphertextB64: 'AA==',
    createdAtMs: createdAtMs,
    payloadEventId: payloadEventId,
  );
}

Future<void> _authoritativeRoom(AppDb db, String groupId) async {
  await db.convoEnsureGroup(groupId: groupId, title: 'Комната');
  await db.groupSettingsUpsert(
    groupId: groupId,
    ownerProfileId: 'admin-1',
    reactionsMode: 'all',
    allowText: true,
    allowMedia: true,
    allowAddMembers: true,
    allowPinMessages: true,
    allowChangeGroupInfo: true,
    allowChangeTag: true,
    joinApprovalRequired: false,
    slowModeSeconds: 0,
    chatHistoryVisible: true,
    membershipVersion: 1,
    stateVersion: 1,
  );
  for (final pid in const ['admin-1', 'member-1', _me]) {
    await db.groupMemberEnsure(groupId: groupId, memberProfileId: pid);
  }
}

String _reaction({
  required String convoId,
  required String eventId,
  required String actor,
  String emoji = '🔥',
  bool removed = false,
}) {
  return _command('__secretly_reaction_v1__:', <String, Object?>{
    'v': 1,
    'convoId': convoId,
    'eventId': eventId,
    'emoji': emoji,
    'removed': removed,
    'actorProfileId': actor,
    'actorName': 'Имя',
  });
}

String _clear(String convoId, int cutoffMs) {
  return _command('__secretly_clear_history_v1__:', <String, Object?>{
    'v': 1,
    'convoId': convoId,
    'cutoffCreatedAtMs': cutoffMs,
    'scope': convoId.startsWith('group:') ? 'room' : 'direct',
  });
}

Future<List<String>> _reactors(AppDb db, String eventId) async {
  final rows = await db.messageReactionsForEventIds(<String>[eventId]);
  return rows.map((r) => r['profile_id'] as String).toList()..sort();
}

Future<int> _eventCount(AppDb db, String convoId) async {
  final rows = await db.rawQueryForTesting(
    'SELECT COUNT(*) c FROM events WHERE convo_id = ?',
    <Object?>[convoId],
  );
  return (rows.first['c'] as num).toInt();
}

/// Провод первого сообщения сеанса, собранный «чужаком» по открытой связке
/// ключей получателя [bundle]; в заголовке — любой [claimedSender].
Future<Uint8List> _strangerPrekeyWire({
  required DeviceKeyBundleV1 bundle,
  required String claimedSender,
  required String text,
  List<String> caps = const <String>[],
}) async {
  final init = await PrekeyHandshakeV1().initiatorCreate(
    selfDeviceId: claimedSender,
    peerDeviceId: _myDevice,
    recipientSignedPrekeyPubB64: bundle.signedPrekeyPubB64,
  );
  final dr = DoubleRatchetV3();
  final state = await dr.initInitiator(
    peerDeviceId: _myDevice,
    rootKey: init.session.rootKey,
    handshakeEphKeyPair: init.ephKeyPair,
    recipientSignedPrekeyPub: Uint8List.fromList(
      base64Decode(bundle.signedPrekeyPubB64),
    ),
  );
  final header = <String, Object?>{
    ...init.header.toJson(),
    'dh_pub_b64': base64Encode(state.dhSelfPub),
    'pn': state.pn,
    'n': state.ns,
    'se': 1,
  };
  final payload = E2ePayloadV1(
    senderDeviceId: claimedSender,
    createdAtMs: 1,
    events: [MsgEventV1(eventId: 'w-${text.hashCode}', text: text)],
    caps: caps,
  );
  final enc = await dr.encrypt(
    state: state,
    plaintext: Uint8List.fromList(payload.encode()),
    aad: Uint8List.fromList(utf8.encode(jsonEncode(header))),
  );
  return RatchetWireV3.encodePrekey(
    header: header,
    ratchetCiphertext: enc.ciphertext,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('провод от имени самого устройства', () {
    const secureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final vault = <String, String>{};

    setUp(() {
      vault.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorage, (call) async {
            final args = Map<Object?, Object?>.from(
              call.arguments as Map<Object?, Object?>? ?? const {},
            );
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return key == null ? null : vault[key];
              case 'write':
                if (key != null) vault[key] = (args['value'] as String?) ?? '';
                return null;
              case 'delete':
                if (key != null) vault.remove(key);
                return null;
              case 'readAll':
                return Map<String, String>.from(vault);
              case 'deleteAll':
                vault.clear();
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorage, null);
    });

    test('заголовок читается у обоих форматов', () {
      final v3 = RatchetWireV3.encodePrekey(
        header: const <String, Object?>{
          'sender_device_id': ' dev-3 ',
          'sender_eph_pub_b64': 'AA==',
          'spk_id': 1,
        },
        ratchetCiphertext: Uint8List(8),
      );
      expect(claimedWireSenderDeviceId(v3), 'dev-3');
      final v1 = RatchetWireV1.encodeSession(
        senderDeviceId: 'dev-1',
        ratchetCiphertext: Uint8List(8),
      );
      expect(claimedWireSenderDeviceId(v1), 'dev-1');
      expect(claimedWireSenderDeviceId(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('🔴 чужак с открытой связкой ключей не выдаёт себя за этот телефон',
        () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      // Открытая связка ключей телефона — её отдаёт сервер любому устройству.
      final bundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
        profileId: _me,
        deviceId: _myDevice,
        allocateOneTimePrekeys: 4,
      );
      final ratchet = RatchetSessionManagerV3(
        db: db,
        deviceKeys: DeviceKeys.create(),
        keysClient: KeysClient(baseUrl: Uri.parse('https://keys.invalid')),
      );
      final controller = AppController()
        ..seedRoomRuntimeForTesting(
          db: db,
          profileId: _me,
          deviceId: _myDevice,
          crypto: DartCryptoProvider(
            Uint8List.fromList(List<int>.generate(32, (i) => i)),
          ),
          ratchetV3: ratchet,
        )
        ..seedKeysRuntimeForTesting(
          keys: KeysClient(baseUrl: Uri.parse('https://keys.invalid')),
        );

      // Провод собирает чужак: X3DH только на его одноразовом ключе.
      final init = await PrekeyHandshakeV1().initiatorCreate(
        selfDeviceId: _myDevice,
        peerDeviceId: _myDevice,
        recipientSignedPrekeyPubB64: bundle.signedPrekeyPubB64,
      );
      final dr = DoubleRatchetV3();
      final state = await dr.initInitiator(
        peerDeviceId: _myDevice,
        rootKey: init.session.rootKey,
        handshakeEphKeyPair: init.ephKeyPair,
        recipientSignedPrekeyPub: Uint8List.fromList(
          base64Decode(bundle.signedPrekeyPubB64),
        ),
      );
      final header = <String, Object?>{
        ...init.header.toJson(),
        'dh_pub_b64': base64Encode(state.dhSelfPub),
        'pn': state.pn,
        'n': state.ns,
        'se': 1,
      };
      final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
      final revoke = _command('__secretly_session_revoked_v1__:', {
        'profileId': _me,
        'targetDeviceId': _myDevice,
        'requesterDeviceId': _myDevice,
        'revokedAtMs': 1,
      });
      final payload = E2ePayloadV1(
        senderDeviceId: _myDevice,
        createdAtMs: 1,
        events: [MsgEventV1(eventId: 'evil', text: revoke)],
      );
      final enc = await dr.encrypt(
        state: state,
        plaintext: Uint8List.fromList(payload.encode()),
        aad: headerBytes,
      );
      final wire = RatchetWireV3.encodePrekey(
        header: header,
        ratchetCiphertext: enc.ciphertext,
      );

      var probes = 0;
      controller.ownDeviceRegistrationProbeForTesting = () async {
        probes++;
        return OwnDeviceRegistration.gone;
      };
      final handled = await controller.handleDeliveredForTesting(
        msgId: 'evil-wire',
        ciphertextB64: base64Encode(wire),
      );
      expect(handled, isTrue, reason: 'подделку подтверждаем реле и забываем');
      expect(
        await db.sessionV3Get(_myDevice),
        isNull,
        reason: 'ратчет не должен заводить сеанс «с самим собой»',
      );
      expect(controller.sessionRevokeConfirmationForTesting, isNull);
      expect(probes, 0);
    });
    test('🔴 реле назвало другого отправителя — провод отброшен до ратчета',
        () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      addTearDown(AttestedSenders.clearForTesting);
      final bundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
        profileId: _me,
        deviceId: _myDevice,
        allocateOneTimePrekeys: 4,
      );
      final keys = KeysClient(baseUrl: Uri.parse('https://keys.invalid'));
      final controller = AppController()
        ..seedRoomRuntimeForTesting(
          db: db,
          profileId: _me,
          deviceId: _myDevice,
          crypto: DartCryptoProvider(
            Uint8List.fromList(List<int>.generate(32, (i) => i)),
          ),
          ratchetV3: RatchetSessionManagerV3(
            db: db,
            deviceKeys: DeviceKeys.create(),
            keysClient: keys,
          ),
        )
        ..seedKeysRuntimeForTesting(keys: keys);

      // Чужак называет себя моим компьютером; реле знает, кто он на самом деле.
      final forged = await _strangerPrekeyWire(
        bundle: bundle,
        claimedSender: _myDesktop,
        text: 'forged',
      );
      AttestedSenders.record('forged-wire', 'evil-device');
      expect(
        await controller.handleDeliveredForTesting(
          msgId: 'forged-wire',
          ciphertextB64: base64Encode(forged),
        ),
        isTrue,
      );
      expect(await db.sessionV3Get(_myDesktop), isNull);

      // Без слова реле (старое реле, старая строка) — прежнее поведение:
      // провод открывается, а значит отбросила его именно сверка.
      final legacy = await _strangerPrekeyWire(
        bundle: bundle,
        claimedSender: _myDesktop,
        text: 'legacy',
      );
      await controller.handleDeliveredForTesting(
        msgId: 'legacy-wire',
        ciphertextB64: base64Encode(legacy),
      );
      expect(await db.sessionV3Get(_myDesktop), isNotNull);
    });

    test('принятый провод записывает возможности отправителя', () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      final bundle = await DeviceKeys.create().createOrLoadAndAllocateOtk(
        profileId: _me,
        deviceId: _myDevice,
        allocateOneTimePrekeys: 4,
      );
      final keys = KeysClient(baseUrl: Uri.parse('https://keys.invalid'));
      final controller = AppController()
        ..seedRoomRuntimeForTesting(
          db: db,
          profileId: _me,
          deviceId: _myDevice,
          crypto: DartCryptoProvider(
            Uint8List.fromList(List<int>.generate(32, (i) => i)),
          ),
          ratchetV3: RatchetSessionManagerV3(
            db: db,
            deviceKeys: DeviceKeys.create(),
            keysClient: keys,
          ),
        )
        ..seedKeysRuntimeForTesting(keys: keys);
      final wire = await _strangerPrekeyWire(
        bundle: bundle,
        claimedSender: 'peer-new-build',
        text: 'hello',
        caps: const [E2ePayloadV1.capRoomKeyV2],
      );
      AttestedSenders.record('caps-wire', 'peer-new-build');
      await controller.handleDeliveredForTesting(
        msgId: 'caps-wire',
        ciphertextB64: base64Encode(wire),
      );
      expect(
        await db.deviceIdsWithCap(
          deviceIds: const ['peer-new-build'],
          cap: E2ePayloadV1.capRoomKeyV2,
        ),
        {'peer-new-build'},
      );
    });
  });

  group('возможности устройства (rk2)', () {
    test('поле caps: пишется только непустым, старый разбор его пропускает', () {
      final withCaps = E2ePayloadV1(
        senderDeviceId: 'd',
        createdAtMs: 1,
        events: const [],
        caps: const [E2ePayloadV1.capRoomKeyV2],
      );
      expect(E2ePayloadV1.decode(withCaps.encode()).caps, ['rk2']);
      final plain = E2ePayloadV1(senderDeviceId: 'd', createdAtMs: 1, events: const []);
      expect(utf8.decode(plain.encode()).contains('caps'), isFalse);
      expect(E2ePayloadV1.decode(plain.encode()).caps, isEmpty);
    });

    test('база: возможности по устройствам', () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      await db.deviceCapsPut(deviceId: 'new-dev', caps: const ['rk2'], nowMs: 1);
      await db.deviceCapsPut(deviceId: 'other-dev', caps: const ['x'], nowMs: 1);
      expect(
        await db.deviceIdsWithCap(
          deviceIds: const ['new-dev', 'other-dev', 'old-dev'],
          cap: 'rk2',
        ),
        {'new-dev'},
      );
    });

    test('🔴 ключ комнаты уходит только устройствам с меткой, и сборка её шлёт', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final deliver = src.substring(
        src.indexOf('  Future<void> _deliverRoomKeyTo({'),
        src.indexOf('  Future<void> _deliverRoomKeyTo({') + 2500,
      );
      expect(deliver.contains('for (final d in devices.where(capable.contains))'), isTrue);
      final control = src.substring(
        src.indexOf('  Future<void> sendControlMessage({'),
        src.indexOf('  Future<void> sendControlMessage({') + 6000,
      );
      expect(control.contains('caps: const <String>[E2ePayloadV1.capRoomKeyV2]'), isTrue);
    });
  });

  group('«сеанс завершён»', () {
    late List<Duration> savedDelays;
    setUp(() {
      savedDelays = AppController.sessionRevokeConfirmDelays;
      AppController.sessionRevokeConfirmDelays = const <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ];
    });
    tearDown(() {
      AppController.sessionRevokeConfirmDelays = savedDelays;
    });

    String revoke({String target = _myDevice, String pid = _me}) =>
        _command('__secretly_session_revoked_v1__:', {
          'profileId': pid,
          'targetDeviceId': target,
          'requesterDeviceId': _myDesktop,
          'revokedAtMs': 1,
          'reason': 'end_session',
        });

    Future<({int resets, int probes})> run(
      List<OwnDeviceRegistration> answers, {
      String sender = _myDesktop,
      String? senderPid,
    }) async {
      final o = await _owner();
      var resets = 0;
      var probes = 0;
      o.controller
        ..ownDeviceRegistrationProbeForTesting = () async {
          probes++;
          return answers[(probes - 1).clamp(0, answers.length - 1)];
        }
        ..sessionRevokeResetForTesting = () async {
          resets++;
        };
      await _deliver(
        o.controller,
        o.db,
        revoke(),
        senderDeviceId: sender,
        senderProfileId: senderPid,
      );
      await o.controller.sessionRevokeConfirmationForTesting;
      return (resets: resets, probes: probes);
    }

    test('🔴 сервер говорит «устройство на месте» — данные не трогаем', () async {
      final r = await run(const [OwnDeviceRegistration.present]);
      expect(r.resets, 0);
      expect(r.probes, 3, reason: 'спросили по расписанию и отступили');
    });

    test('регистрацию сняли чуть позже — стираем один раз', () async {
      final r = await run(const [
        OwnDeviceRegistration.present,
        OwnDeviceRegistration.gone,
      ]);
      expect(r.resets, 1);
      expect(r.probes, 2);
    });

    test('сервер недоступен — не стираем', () async {
      final r = await run(const [OwnDeviceRegistration.unknown]);
      expect(r.resets, 0);
    });

    test('от постороннего — даже не спрашиваем', () async {
      final r = await run(
        const [OwnDeviceRegistration.gone],
        sender: 'stranger-device',
        senderPid: 'stranger-1',
      );
      expect(r.probes, 0);
      expect(r.resets, 0);
    });

    test('разбор ответа сервера', () {
      expect(
        ownDeviceRegistrationFromLookupError(
          StateError(
            'lookupProfileByDeviceAuthed failed: 401 unknown requester device',
          ),
        ),
        OwnDeviceRegistration.gone,
      );
      expect(
        ownDeviceRegistrationFromLookupError(
          StateError('lookupProfileByDeviceAuthed failed: 401 bad signature'),
        ),
        OwnDeviceRegistration.unknown,
      );
      expect(
        ownDeviceRegistrationFromLookupError(
          StateError('lookupProfileByDeviceAuthed failed: 503 unknown requester device'),
        ),
        OwnDeviceRegistration.unknown,
      );
      expect(
        ownDeviceRegistrationFromLookupError(Exception('SocketException')),
        OwnDeviceRegistration.unknown,
      );
    });
  });

  group('«очистить историю»', () {
    test('🔴 посторонний не стирает мой чат с другим человеком', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'f-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', 40000),
        senderDeviceId: 'stranger-device',
        senderProfileId: 'stranger-1',
      );
      expect(await _eventCount(o.db, 'friend-1'), 1);
    });

    test('собеседник очищает нашу с ним переписку — как и раньше', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'f-1');
      await _message(
        o.db,
        convoId: 'friend-1',
        payloadEventId: 'f-2',
        createdAtMs: 45000,
      );
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', 40000),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      expect(await _eventCount(o.db, 'friend-1'), 1, reason: 'после отсечки — живо');
    });

    test('устройство без привязки узнаётся по списку адресатов', () async {
      final o = await _owner();
      await o.db.contactDeviceUpsert(
        profileId: 'friend-1',
        deviceId: 'friend-device',
        identityKeyPubB64: 'aWs=',
        signedPrekeyPubB64: 'c3Br',
        signedPrekeySigB64: 'c2ln',
      );
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'f-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', 40000),
        senderDeviceId: 'friend-device',
      );
      expect(await _eventCount(o.db, 'friend-1'), 0);
    });

    test('неузнанный отправитель ничего не стирает', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'f-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', 40000),
        senderDeviceId: 'nobody-device',
      );
      expect(await _eventCount(o.db, 'friend-1'), 1);
    });

    test('🔴 дата из будущего не глушит переписку навсегда', () async {
      final o = await _owner();
      const now = 50000;
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'old');
      await _message(
        o.db,
        convoId: 'friend-1',
        payloadEventId: 'later',
        createdAtMs: now + const Duration(hours: 1).inMilliseconds,
      );
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', now + const Duration(days: 36500).inMilliseconds),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
        nowMs: now,
      );
      expect(await _eventCount(o.db, 'friend-1'), 1);
      expect(
        clampInboundClearCutoffMs(999999999, nowMs: 1000),
        1000 + kInboundClearCutoffMaxLead.inMilliseconds,
      );
      expect(clampInboundClearCutoffMs(900, nowMs: 1000), 900);
    });

    test('комната: участник не стирает, владелец стирает', () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('group:r', 40000),
        senderDeviceId: 'member-device',
        senderProfileId: 'member-1',
      );
      expect(await _eventCount(o.db, 'group:r'), 1);
      await _deliver(
        o.controller,
        o.db,
        _clear('group:r', 40000),
        senderDeviceId: 'admin-device',
        senderProfileId: 'admin-1',
      );
      expect(await _eventCount(o.db, 'group:r'), 0);
    });

    test('🔴 очистка от участника без прав: паркуется, при повторе не зацикливается',
        () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('group:r', 40000),
        senderDeviceId: 'member-device',
        senderProfileId: 'member-1',
      );
      expect(await _eventCount(o.db, 'group:r'), 1);
      expect(await o.db.deferredRoomInboundCountAll(), 1);

      // Прав так и не дали: повтор отказывает и НЕ паркует снова.
      await o.controller.flushDeferredRoomInboundForTesting(o.db, 'group:r');
      expect(await _eventCount(o.db, 'group:r'), 1);
      expect(await o.db.deferredRoomInboundCountAll(), 0);
    });

    test('незнакомую комнату не заводит', () async {
      final o = await _owner();
      await _deliver(
        o.controller,
        o.db,
        _clear('group:nowhere', 40000),
        senderDeviceId: 'admin-device',
        senderProfileId: 'admin-1',
      );
      expect(await o.db.groupSettingsGet('group:nowhere'), isNull);
      expect(await o.db.convoGet('group:nowhere'), isNull);
    });

    test('свой аппарат повторяет моё действие в любой переписке', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'f-1');
      await _deliver(
        o.controller,
        o.db,
        _clear('friend-1', 40000),
        senderDeviceId: _myDesktop,
      );
      expect(await _eventCount(o.db, 'friend-1'), 0);
    });
  });

  group('реакции', () {
    test('собеседник отмечает сообщение в нашей переписке', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'p-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: _me, eventId: 'p-1', actor: 'friend-1'),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      final rows = await o.db.messageReactionsForEventIds(const ['p-1']);
      expect(rows, hasLength(1));
      expect(rows.single['profile_id'], 'friend-1');
      expect(
        rows.single['convo_id'],
        'friend-1',
        reason: 'хранится в переписке с отправителем, а не под моим профилем',
      );
    });

    test('🔴 за другого человека — нельзя, и мою реакцию не снять', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'friend-1', payloadEventId: 'p-1');
      await o.db.messageReactionUpsert(
        eventId: 'p-1',
        convoId: 'friend-1',
        profileId: _me,
        emoji: '❤️',
      );
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: _me, eventId: 'p-1', actor: 'mom-1'),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      await _deliver(
        o.controller,
        o.db,
        _reaction(
          convoId: _me,
          eventId: 'p-1',
          actor: _me,
          emoji: '❤️',
          removed: true,
        ),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      expect(await _reactors(o.db, 'p-1'), [_me]);
    });

    test('🔴 сообщение из чужой переписки — отбрасывается', () async {
      final o = await _owner();
      await _message(o.db, convoId: 'mom-1', payloadEventId: 'secret');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: _me, eventId: 'secret', actor: 'friend-1'),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      expect(await _reactors(o.db, 'secret'), isEmpty);
    });

    test('реакция раньше сообщения — сохраняется, как прежде', () async {
      final o = await _owner();
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: _me, eventId: 'not-yet', actor: 'friend-1'),
        senderDeviceId: 'friend-device',
        senderProfileId: 'friend-1',
      );
      expect(await _reactors(o.db, 'not-yet'), ['friend-1']);
    });

    test('переписка-заявка: хранится под req:', () async {
      final o = await _owner();
      await o.db.convoEnsureRequest(peerProfileId: 'friend-2');
      await _message(o.db, convoId: 'req:friend-2', payloadEventId: 'q-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'req:$_me', eventId: 'q-1', actor: 'friend-2'),
        senderDeviceId: 'friend2-device',
        senderProfileId: 'friend-2',
      );
      final rows = await o.db.messageReactionsForEventIds(const ['q-1']);
      expect(rows.single['convo_id'], 'req:friend-2');
    });

    test('комната: участник — да, посторонний — нет', () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:r', eventId: 'r-1', actor: 'member-1'),
        senderDeviceId: 'member-device',
        senderProfileId: 'member-1',
      );
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:r', eventId: 'r-1', actor: 'stranger-1'),
        senderDeviceId: 'stranger-device',
        senderProfileId: 'stranger-1',
      );
      expect(await _reactors(o.db, 'r-1'), ['member-1']);
      final rows = await o.db.messageReactionsForEventIds(const ['r-1']);
      expect(rows.single['convo_id'], 'group:r');
    });

    test('🔴 реакция нового участника не теряется: применяется, когда он в составе',
        () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:r', eventId: 'r-1', actor: 'newbie-1'),
        senderDeviceId: 'newbie-device',
        senderProfileId: 'newbie-1',
      );
      expect(await _reactors(o.db, 'r-1'), isEmpty);
      expect(await o.db.deferredRoomInboundCountAll(), 1);

      await o.db.groupMemberEnsure(
        groupId: 'group:r',
        memberProfileId: 'newbie-1',
      );
      await o.controller.flushDeferredRoomInboundForTesting(o.db, 'group:r');
      expect(await _reactors(o.db, 'r-1'), ['newbie-1']);
      expect(await o.db.deferredRoomInboundCountAll(), 0);
    });

    test('неопознанное устройство в комнате: ждёт, пока его узнают', () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:r', eventId: 'r-1', actor: 'member-1'),
        senderDeviceId: 'member-new-phone',
      );
      expect(await _reactors(o.db, 'r-1'), isEmpty);
      expect(await o.db.deferredRoomInboundCountAll(), 1);

      await o.controller.flushDeferredRoomInboundForTesting(o.db, 'group:r');
      expect(await o.db.deferredRoomInboundCountAll(), 1, reason: 'ещё не узнан');

      await o.db.deviceProfileUpsert(
        deviceId: 'member-new-phone',
        profileId: 'member-1',
      );
      await o.controller.flushDeferredRoomInboundForTesting(o.db, 'group:r');
      expect(await _reactors(o.db, 'r-1'), ['member-1']);
      expect(await o.db.deferredRoomInboundCountAll(), 0);
    });

    test('чужая комната и чужая переписка — не паркуются', () async {
      final o = await _owner();
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:nowhere', eventId: 'x-1', actor: 'stranger-1'),
        senderDeviceId: 'stranger-device',
        senderProfileId: 'stranger-1',
      );
      expect(await o.db.deferredRoomInboundCountAll(), 0);
    });

    test('старая комната без настроек: по составу', () async {
      final o = await _owner();
      await o.db.convoEnsureGroup(groupId: 'group:old', title: 'Старая');
      await o.db.groupMemberEnsure(
        groupId: 'group:old',
        memberProfileId: 'member-1',
      );
      await _message(o.db, convoId: 'group:old', payloadEventId: 'o-1');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:old', eventId: 'o-1', actor: 'member-1'),
        senderDeviceId: 'member-device',
        senderProfileId: 'member-1',
      );
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:old', eventId: 'o-1', actor: 'stranger-1'),
        senderDeviceId: 'stranger-device',
        senderProfileId: 'stranger-1',
      );
      expect(await _reactors(o.db, 'o-1'), ['member-1']);
      expect(
        await o.db.groupSettingsGet('group:old'),
        isNull,
        reason: 'проверка прав не заводит настройки со мной во владельцах',
      );
    });

    test('свой аппарат ставит мою реакцию в комнате', () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _message(o.db, convoId: 'group:r', payloadEventId: 'r-2');
      await _deliver(
        o.controller,
        o.db,
        _reaction(convoId: 'group:r', eventId: 'r-2', actor: _me),
        senderDeviceId: _myDesktop,
      );
      expect(await _reactors(o.db, 'r-2'), [_me]);
    });
  });

  group('конверт комнаты и привязка устройства', () {
    String roomEnvelope({required String claimedSender}) {
      return _command('__secretly_group_msg_v1__:', <String, Object?>{
        'v': 1,
        'kind': 'message',
        'groupId': 'group:r',
        'groupTitle': 'Комната',
        'msgEventId': 'env-${claimedSender.hashCode}',
        'text': 'привет',
        'createdAtMs': 5000,
        'memberProfileIds': const ['admin-1', 'member-1', _me],
        'senderProfileId': claimedSender,
      });
    }

    test('🔴 устройство, узнанное сервером, не переписывается на мой профиль',
        () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await o.db.deviceProfileUpsert(
        deviceId: 'member-device',
        profileId: 'member-1',
      );
      await _deliver(
        o.controller,
        o.db,
        roomEnvelope(claimedSender: _me),
        senderDeviceId: 'member-device',
        senderProfileId: 'member-1',
      );
      expect(await o.db.deviceProfileCached('member-device'), 'member-1');
      expect(await o.db.deviceIdsForProfile(_me), isEmpty);
      expect(o.controller.isOwnDeviceId('member-device'), isFalse);
    });

    test('неузнанное устройство не получает привязку со слов конверта',
        () async {
      final o = await _owner();
      await _authoritativeRoom(o.db, 'group:r');
      await _deliver(
        o.controller,
        o.db,
        roomEnvelope(claimedSender: 'admin-1'),
        senderDeviceId: 'unknown-device',
      );
      expect(await o.db.deviceProfileCached('unknown-device'), isNull);
    });
  });
}
