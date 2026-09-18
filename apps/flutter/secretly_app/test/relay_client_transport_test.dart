// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/calls/call_ice_config.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/transport/relay_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _CloseTrackingWebSocketSink implements WebSocketSink {
  int closeCalls = 0;
  final Completer<void> _done = Completer<void>();

  @override
  Future get done => _done.future;

  @override
  void add(dynamic event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future close([int? closeCode, String? closeReason]) {
    closeCalls += 1;
    if (!_done.isCompleted) {
      _done.complete();
    }
    return _done.future;
  }
}

class _CloseTrackingWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  _CloseTrackingWebSocketChannel({required Future<void> ready})
    : _ready = ready;

  final Future<void> _ready;
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>();
  final _CloseTrackingWebSocketSink _sink = _CloseTrackingWebSocketSink();

  int get closeCalls => _sink.closeCalls;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => _ready;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _streamController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RelayClient> buildRelayClient({
    required AppDb db,
    required http.Client httpClient,
    required SimpleKeyPair identityKeyPair,
    Future<bool> Function({
      required String msgId,
      required String ciphertextB64,
    })?
    onDelivered,
    Future<int> Function()? loadNextSeq,
    Future<void> Function(int nextSeq)? saveNextSeq,
  }) async {
    return RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: httpClient,
      identityKeyPairOverride: identityKeyPair,
      onDelivered:
          onDelivered ??
          ({required msgId, required ciphertextB64}) async => true,
      loadNextSeq: loadNextSeq ?? () async => 1,
      saveNextSeq: saveNextSeq ?? (_) async {},
    );
  }

  group('RelayClient transport', () {
    test('connect closes websocket when ready fails before listen', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final client = MockClient((request) async => http.Response('{}', 200));
      final failure = TimeoutException('test websocket ready timeout');
      late final _CloseTrackingWebSocketChannel channel;
      RelayClient? relay;

      try {
        relay = RelayClient(
          db: db,
          deviceId: 'self-device',
          selfProfileId: 'self-profile',
          deviceKeys: DeviceKeys.create(),
          wsUrl: Uri.parse('ws://example.test/ws'),
          httpBaseUrl: Uri.parse('https://example.test'),
          httpClient: client,
          identityKeyPairOverride: kp,
          webSocketConnector: (_, {pingInterval, connectTimeout}) {
            channel = _CloseTrackingWebSocketChannel(
              ready: Future<void>.error(failure),
            );
            return channel;
          },
          onDelivered: ({required msgId, required ciphertextB64}) async => true,
          loadNextSeq: () async => 1,
          saveNextSeq: (_) async {},
        );

        await expectLater(relay.connect(), throwsA(same(failure)));

        expect(channel.closeCalls, 1);
      } finally {
        await relay?.close();
        await db.close();
      }
    });

    test('unrecoverable undecryptable deliveries are seen and acked', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final requests = <http.Request>[];
      final savedNextSeqs = <int>[];
      final controller = AppController();
      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'self-profile',
        deviceId: 'self-device',
      );
      controller.seedKeysRuntimeForTesting(
        keys: KeysClient(baseUrl: Uri.parse('https://example.test')),
      );
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      });
      RelayClient? relay;

      try {
        relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
          onDelivered: ({required msgId, required ciphertextB64}) {
            return controller.handleDeliveredForTesting(
              msgId: msgId,
              ciphertextB64: ciphertextB64,
            );
          },
          saveNextSeq: (nextSeq) async {
            savedNextSeqs.add(nextSeq);
          },
        );

        await relay.debugHandleDeliverForTest(
          Deliver(
            deviceId: 'self-device',
            seq: 1,
            msgId: 'msg-undecipherable',
            ciphertextB64: '!!!',
          ),
        );

        expect(await db.inboxHasSeen('msg-undecipherable'), isTrue);
        expect(savedNextSeqs, <int>[2]);
        expect(requests.map((request) => request.url.path), <String>[
          '/v1/ack',
        ]);
      } finally {
        await relay?.disconnect();
        await db.close();
      }
    });

    test(
      'inbound delivery apply failures are dropped and acked after retry cap',
      () async {
        final db = await AppDb.openForTesting();
        final kp = await Ed25519().newKeyPair();
        final requests = <http.Request>[];
        final savedNextSeqs = <int>[];
        var deliveryAttempts = 0;
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        });
        RelayClient? relay;

        try {
          relay = await buildRelayClient(
            db: db,
            httpClient: client,
            identityKeyPair: kp,
            onDelivered: ({required msgId, required ciphertextB64}) async {
              deliveryAttempts += 1;
              throw StateError('apply failed');
            },
            saveNextSeq: (nextSeq) async {
              savedNextSeqs.add(nextSeq);
            },
          );

          for (var attempt = 0; attempt < 6; attempt += 1) {
            await relay.debugHandleDeliverForTest(
              Deliver(
                deviceId: 'self-device',
                seq: 1,
                msgId: 'msg-deliver-fail',
                ciphertextB64: 'AA==',
              ),
            );
          }

          expect(deliveryAttempts, 6);
          expect(await db.inboxHasSeen('msg-deliver-fail'), isTrue);
          expect(savedNextSeqs, <int>[2]);
          expect(requests.map((request) => request.url.path), <String>[
            '/v1/ack',
          ]);
        } finally {
          await relay?.disconnect();
          await db.close();
        }
      },
    );

    test('HTTP ack failures are exposed in relay diagnostics', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final requests = <http.Request>[];
      final savedNextSeqs = <int>[];
      RelayClient? relay;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/ack') {
          return http.Response('server unavailable', 503);
        }
        return http.Response('{}', 200);
      });

      try {
        relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
          saveNextSeq: (nextSeq) async {
            savedNextSeqs.add(nextSeq);
          },
        );

        await relay.debugHandleDeliverForTest(
          Deliver(
            deviceId: 'self-device',
            seq: 1,
            msgId: 'msg-ack-fails',
            ciphertextB64: 'AA==',
          ),
        );

        expect(await db.inboxHasSeen('msg-ack-fails'), isTrue);
        expect(savedNextSeqs, <int>[2]);
        expect(
          requests.map((request) => request.url.path),
          contains('/v1/ack'),
        );
        expect(relay.ackFailureCount, 1);
        expect(relay.lastAckFailureAtMs, greaterThan(0));
        expect(relay.lastAckFailureSummary, contains('503'));
      } finally {
        await relay?.disconnect();
        await db.close();
      }
    });

    test('HTTP outbox accept marks sent and releases lease', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      try {
        await db.insertEvent(
          eventId: 'evt-http-ok',
          convoId: 'convo-http',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: nowMs,
          localState: MessageLocalState.pending,
        );
        await db.outboxUpsert(
          msgId: 'msg-http-ok',
          toDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: nowMs,
          createdAtMs: nowMs,
          correlationId: 'corr-http-ok',
          convoId: 'convo-http',
          eventIdRef: 'evt-http-ok',
          transportHint: 'http',
        );

        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        await relay.pumpOutbox();

        expect(captured.method, 'POST');
        expect(captured.url.path, '/v1/send');
        expect(captured.headers['x-secretly-device-id'], 'self-device');
        expect(captured.headers['x-secretly-signature-b64'], isNotEmpty);

        final outboxRows = await db.outboxListForEventRef('evt-http-ok');
        expect(outboxRows, hasLength(1));
        expect(outboxRows.first['state'], OutboxSendState.sent);
        expect(outboxRows.first['locked_by_worker'], isNull);
        expect(outboxRows.first['locked_at_ms'], isNull);

        final events = await db.listEvents('convo-http');
        expect(events.first['local_state'], MessageLocalState.sent);

        final attempts = await db.messageAttemptLogList(
          localEventId: 'evt-http-ok',
        );
        expect(attempts, hasLength(1));
        expect(attempts.first['result'], 'accepted');
        expect(attempts.first['transport'], 'http');
      } finally {
        await db.close();
      }
    });

    test('HTTP outbox exception schedules retry and releases lease', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final client = MockClient((request) async {
        throw Exception('network down');
      });

      try {
        await db.insertEvent(
          eventId: 'evt-http-retry',
          convoId: 'convo-retry',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: nowMs,
          localState: MessageLocalState.pending,
        );
        await db.outboxUpsert(
          msgId: 'msg-http-retry',
          toDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: nowMs,
          createdAtMs: nowMs,
          correlationId: 'corr-http-retry',
          convoId: 'convo-retry',
          eventIdRef: 'evt-http-retry',
          transportHint: 'http',
        );

        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        await relay.pumpOutbox();

        final outboxRows = await db.outboxListForEventRef('evt-http-retry');
        expect(outboxRows, hasLength(1));
        expect(outboxRows.first['state'], OutboxSendState.sending);
        expect(outboxRows.first['attempt_count'], 1);
        expect(outboxRows.first['locked_by_worker'], isNull);
        expect(outboxRows.first['locked_at_ms'], isNull);

        final events = await db.listEvents('convo-retry');
        expect(events.first['local_state'], MessageLocalState.sending);

        final attempts = await db.messageAttemptLogList(
          localEventId: 'evt-http-retry',
        );
        expect(attempts, hasLength(1));
        expect(attempts.first['result'], 'exception_retry');
        expect(
          attempts.first['error_code'],
          MessageFailureReason.relayUnavailable,
        );
      } finally {
        await db.close();
      }
    });

    test('HTTP outbox includes transport metadata when present', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      try {
        await db.insertEvent(
          eventId: 'evt-http-meta',
          convoId: 'convo-meta',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: nowMs,
          localState: MessageLocalState.pending,
        );
        await db.outboxUpsert(
          msgId: 'msg-http-meta',
          toDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: nowMs,
          createdAtMs: nowMs,
          correlationId: 'corr-http-meta',
          convoId: 'convo-meta',
          eventIdRef: 'evt-http-meta',
          transportHint: 'call_signal',
          transportMetaJson:
              '{"kind":"call_signal_v1","call":{"action":"invite","call_id":"call-1","call_attempt_id":"call-1","signal_id":"signal-1","created_at_ms":1234}}',
        );

        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        await relay.pumpOutbox();

        expect(captured.body, contains('transport_meta_json'));
        expect(captured.body, contains('call_signal_v1'));
        expect(captured.body, contains('signal-1'));
      } finally {
        await db.close();
      }
    });

    test(
      'setPushToken signs requests with symmetric auth message (AUD-013)',
      () async {
        final db = await AppDb.openForTesting();
        final kp = await Ed25519().newKeyPair();
        final publicKey = await kp.extractPublicKey();
        final policyB64 = base64Encode(utf8.encode('{"v":2}'));
        http.Request? captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        });

        try {
          final relay = await buildRelayClient(
            db: db,
            httpClient: client,
            identityKeyPair: kp,
          );

          await relay.setPushToken(
            token: 'push-token-ios',
            platform: 'ios',
            enabled: true,
            policyB64: policyB64,
          );

          final req = captured!;
          final tsMs = int.parse(req.headers['x-secretly-ts-ms']!);
          final nonceB64 = req.headers['x-secretly-nonce-b64']!;
          final sigB64 = req.headers['x-secretly-signature-b64']!;
          final msg = AuthSigner.relayHttpPushTokenSetMessage(
            deviceId: 'self-device',
            token: 'push-token-ios',
            platform: 'ios',
            enabled: true,
            policyB64: policyB64,
            tsMs: tsMs,
            nonceB64: nonceB64,
          );
          final valid = await Ed25519().verify(
            msg,
            signature: Signature(base64Decode(sigB64), publicKey: publicKey),
          );
          expect(valid, isTrue);
          expect(req.body, contains('policy_b64'));
        } finally {
          await db.close();
        }
      },
    );

    test('setPushToken surfaces 401 without legacy retry (AUD-013)', () async {
      // The relay always rebuilds the `policy_b64=` line when verifying
      // auth, so a retry without that line could never succeed. The
      // fallback path has been removed and the client must now surface the
      // 401 to the caller instead of issuing a second, useless request.
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final policyB64 = base64Encode(utf8.encode('{"v":2}'));
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('bad signature', 401);
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        await expectLater(
          () => relay.setPushToken(
            token: 'push-token-ios',
            platform: 'ios',
            enabled: true,
            policyB64: policyB64,
          ),
          throwsA(isA<StateError>()),
        );

        expect(requests, hasLength(1));
        expect(requests.first.url.path, '/v1/push/self-device');
        expect(requests.first.body, contains('policy_b64'));
      } finally {
        await db.close();
      }
    });

    test('HTTP call session lookup signs request and parses response', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"exists":true,"device_id":"self-device","call_id":"call-42","call_attempt_id":"attempt-42","state":"reconnecting","last_action":"need_offer","ended_at_ms":null}',
          200,
        );
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final snapshot = await relay.getCallSession(
          callId: 'call-42',
          callAttemptId: 'attempt-42',
        );

        expect(captured.method, 'GET');
        expect(
          captured.url.path,
          '/v1/call-session/self-device/call-42/attempt-42',
        );
        expect(captured.headers['x-secretly-device-id'], 'self-device');
        expect(captured.headers['x-secretly-signature-b64'], isNotEmpty);
        expect(snapshot.exists, isTrue);
        expect(snapshot.state, 'reconnecting');
        expect(snapshot.lastAction, 'need_offer');
        expect(snapshot.isEnded, isFalse);
      } finally {
        await db.close();
      }
    });

    test('HTTP call session lookup parses superseded ended attempt', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final client = MockClient((request) async {
        return http.Response(
          '{"exists":true,"device_id":"self-device","call_id":"call-42","call_attempt_id":"attempt-old","state":"ended","last_action":"superseded","ended_at_ms":456}',
          200,
        );
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final snapshot = await relay.getCallSession(
          callId: 'call-42',
          callAttemptId: 'attempt-old',
        );

        expect(snapshot.exists, isTrue);
        expect(snapshot.callAttemptId, 'attempt-old');
        expect(snapshot.state, 'ended');
        expect(snapshot.lastAction, 'superseded');
        expect(snapshot.endedAtMs, 456);
        expect(snapshot.isEnded, isTrue);
      } finally {
        await db.close();
      }
    });

    test('HTTP ice config lookup signs request and parses policy', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"device_id":"self-device","policy":"relay_only","expires_at_ms":123456,"ice_servers":[{"urls":["turns:turn.secretly.test:5349?transport=tcp"],"username":"u","credential":"c"}]}',
          200,
        );
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final snapshot = await relay.getIceConfig();

        expect(captured.method, 'GET');
        expect(captured.url.path, '/v1/ice/self-device');
        expect(captured.headers['x-secretly-device-id'], 'self-device');
        expect(captured.headers['x-secretly-signature-b64'], isNotEmpty);
        expect(snapshot.policy, CallNetworkPolicy.relayOnly);
        expect(snapshot.rtcIceTransportPolicy, 'relay');
        expect(snapshot.iceServers, hasLength(1));
      } finally {
        await db.close();
      }
    });

    test('HTTP room endpoints sign requests and parse responses', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final captured = <http.Request>[];
      final roomBase =
          '{"room_id":"group:room-1","version":2,"membership_version":3,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch","created_at_ms":1000,"updated_at_ms":2000}';
      final roomAfterMembership =
          '{"room_id":"group:room-1","version":2,"membership_version":4,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch","created_at_ms":1000,"updated_at_ms":2100}';
      final roomAfterTag =
          '{"room_id":"group:room-1","version":2,"membership_version":5,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch","created_at_ms":1000,"updated_at_ms":2125}';
      final roomAfterUnban =
          '{"room_id":"group:room-1","version":2,"membership_version":6,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch","created_at_ms":1000,"updated_at_ms":2150}';
      final roomAfterTransfer =
          '{"room_id":"group:room-1","version":3,"membership_version":6,"owner_profile_id":"peer-profile","created_by_device_id":"self-device","title":"Launch","created_at_ms":1000,"updated_at_ms":2200}';
      final inviteActive =
          '{"link_id":"link-1","room_id":"group:room-1","slug":"slug-1","created_by_profile_id":"self-profile","expires_at_ms":456000,"max_uses":10,"use_count":1,"remaining_uses":9,"requires_approval":false,"allowed_role":"member","revoked":false,"created_at_ms":1234,"updated_at_ms":2345}';
      final inviteRevoked =
          '{"link_id":"link-1","room_id":"group:room-1","slug":"slug-1","created_by_profile_id":"self-profile","expires_at_ms":456000,"max_uses":10,"use_count":1,"remaining_uses":9,"requires_approval":false,"allowed_role":"member","revoked":true,"created_at_ms":1234,"updated_at_ms":3456}';
      final client = MockClient((request) async {
        captured.add(request);
        return switch ('${request.method} ${request.url.path}') {
          'POST /v1/rooms' => http.Response(
            '{"ok":true,"created":true,"room":$roomBase}',
            200,
          ),
          'GET /v1/rooms/group%3Aroom-1' => http.Response(roomBase, 200),
          'GET /v1/rooms/group%3Aroom-1/members' => http.Response(
            '{"room":$roomBase,"members":[{"room_id":"group:room-1","profile_id":"self-profile","status":"active","role":"owner","source_link_id":null,"tag":null,"created_at_ms":1000,"updated_at_ms":2000},{"room_id":"group:room-1","profile_id":"peer-profile","status":"active","role":"member","source_link_id":null,"tag":"pilot","created_at_ms":1500,"updated_at_ms":2000}]}',
            200,
          ),
          'POST /v1/rooms/group%3Aroom-1/members' => http.Response(
            '{"ok":true,"changed":true,"room":$roomAfterMembership,"membership":{"room_id":"group:room-1","profile_id":"peer-profile","status":"active","role":"admin","source_link_id":null,"tag":"pilot","created_at_ms":1500,"updated_at_ms":2100}}',
            200,
          ),
          'POST /v1/rooms/group%3Aroom-1/member-tag' => http.Response(
            '{"ok":true,"changed":true,"room":$roomAfterTag,"membership":{"room_id":"group:room-1","profile_id":"self-profile","status":"active","role":"owner","source_link_id":null,"tag":"launch-lead","created_at_ms":1000,"updated_at_ms":2125}}',
            200,
          ),
          'POST /v1/rooms/group%3Aroom-1/members/peer-profile/unban' =>
            http.Response(
              '{"ok":true,"changed":true,"room":$roomAfterUnban,"membership":{"room_id":"group:room-1","profile_id":"peer-profile","status":"removed","role":"member","source_link_id":null,"tag":"pilot","created_at_ms":1500,"updated_at_ms":2150}}',
              200,
            ),
          'POST /v1/rooms/group%3Aroom-1/transfer-ownership' => http.Response(
            '{"ok":true,"room":$roomAfterTransfer,"previous_owner_membership":{"room_id":"group:room-1","profile_id":"self-profile","status":"active","role":"admin","source_link_id":null,"tag":"launch-lead","created_at_ms":1000,"updated_at_ms":2200},"next_owner_membership":{"room_id":"group:room-1","profile_id":"peer-profile","status":"active","role":"owner","source_link_id":null,"tag":"pilot","created_at_ms":1500,"updated_at_ms":2200}}',
            200,
          ),
          'GET /v1/rooms/group%3Aroom-1/invite-links' => http.Response(
            '{"room":$roomAfterTransfer,"invite_links":[$inviteActive]}',
            200,
          ),
          'POST /v1/rooms/group%3Aroom-1/invite-links' => http.Response(
            '{"ok":true,"changed":true,"room":$roomAfterTransfer,"invite_link":$inviteActive}',
            200,
          ),
          'POST /v1/rooms/group%3Aroom-1/invite-links/link-1/revoke' =>
            http.Response(
              '{"ok":true,"changed":true,"room":$roomAfterTransfer,"invite_link":$inviteRevoked}',
              200,
            ),
          'GET /v1/room-invites/slug-1' => http.Response(
            '{"room":$roomAfterTransfer,"invite_link":$inviteActive,"active_member_count":2,"availability":"available","requester_membership":null}',
            200,
          ),
          'POST /v1/room-invites/slug-1/redeem' => http.Response(
            '{"ok":true,"changed":true,"disposition":"active","room":$roomAfterTransfer,"invite_link":$inviteActive,"membership":{"room_id":"group:room-1","profile_id":"self-profile","status":"active","role":"member","source_link_id":"link-1","created_at_ms":2300,"updated_at_ms":2300}}',
            200,
          ),
          _ => http.Response('not found', 404),
        };
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final created = await relay.createRoom(
          roomId: 'group:room-1',
          title: 'Launch',
        );
        final room = await relay.getRoom(roomId: 'group:room-1');
        final members = await relay.listRoomMembers(roomId: 'group:room-1');
        final membershipMutation = await relay.upsertRoomMembership(
          roomId: 'group:room-1',
          profileId: 'peer-profile',
          status: 'active',
          role: 'admin',
        );
        final tagMutation = await relay.setRoomMemberTag(
          roomId: 'group:room-1',
          tag: 'launch-lead',
        );
        final unbanned = await relay.unbanRoomMember(
          roomId: 'group:room-1',
          profileId: 'peer-profile',
        );
        final transferred = await relay.transferRoomOwnership(
          roomId: 'group:room-1',
          nextOwnerProfileId: 'peer-profile',
        );
        final inviteLinks = await relay.listRoomInviteLinks(
          roomId: 'group:room-1',
        );
        final createdInvite = await relay.createRoomInviteLink(
          roomId: 'group:room-1',
          expiresAtMs: 456000,
          maxUses: 10,
        );
        final revokedInvite = await relay.setRoomInviteLinkRevoked(
          roomId: 'group:room-1',
          linkId: 'link-1',
          revoked: true,
        );
        final preview = await relay.previewRoomInvite(slug: 'slug-1');
        final redeemed = await relay.redeemRoomInvite(slug: 'slug-1');

        expect(created.created, isTrue);
        expect(created.room.roomId, 'group:room-1');
        expect(room.title, 'Launch');
        expect(members.members, hasLength(2));
        expect(members.members.last.tag, 'pilot');
        expect(membershipMutation.membership.role, 'admin');
        expect(tagMutation.membership.tag, 'launch-lead');
        expect(unbanned.membership.status, 'removed');
        expect(transferred.room.ownerProfileId, 'peer-profile');
        expect(inviteLinks.inviteLinks, hasLength(1));
        expect(createdInvite.inviteLink.slug, 'slug-1');
        expect(revokedInvite.inviteLink.revoked, isTrue);
        expect(preview.availability, 'available');
        expect(preview.activeMemberCount, 2);
        expect(redeemed.disposition, 'active');
        expect(redeemed.membership.sourceLinkId, 'link-1');

        expect(
          captured.map((request) => '${request.method} ${request.url.path}'),
          <String>[
            'POST /v1/rooms',
            'GET /v1/rooms/group%3Aroom-1',
            'GET /v1/rooms/group%3Aroom-1/members',
            'POST /v1/rooms/group%3Aroom-1/members',
            'POST /v1/rooms/group%3Aroom-1/member-tag',
            'POST /v1/rooms/group%3Aroom-1/members/peer-profile/unban',
            'POST /v1/rooms/group%3Aroom-1/transfer-ownership',
            'GET /v1/rooms/group%3Aroom-1/invite-links',
            'POST /v1/rooms/group%3Aroom-1/invite-links',
            'POST /v1/rooms/group%3Aroom-1/invite-links/link-1/revoke',
            'GET /v1/room-invites/slug-1',
            'POST /v1/room-invites/slug-1/redeem',
          ],
        );
        for (final request in captured) {
          expect(request.headers['x-secretly-device-id'], 'self-device');
          expect(request.headers['x-secretly-signature-b64'], isNotEmpty);
        }

        final createBody = jsonDecode(captured[0].body) as Map<String, dynamic>;
        expect(createBody['room_id'], 'group:room-1');
        expect(createBody['title'], 'Launch');

        final membershipBody =
            jsonDecode(captured[3].body) as Map<String, dynamic>;
        expect(membershipBody['profile_id'], 'peer-profile');
        expect(membershipBody['status'], 'active');
        expect(membershipBody['role'], 'admin');

        final tagBody = jsonDecode(captured[4].body) as Map<String, dynamic>;
        expect(tagBody['tag'], 'launch-lead');

        final unbanBody = jsonDecode(captured[5].body) as Map<String, dynamic>;
        expect(unbanBody, isEmpty);

        final transferBody =
            jsonDecode(captured[6].body) as Map<String, dynamic>;
        expect(transferBody['next_owner_profile_id'], 'peer-profile');

        final createInviteBody =
            jsonDecode(captured[8].body) as Map<String, dynamic>;
        expect(createInviteBody['expires_at_ms'], 456000);
        expect(createInviteBody['max_uses'], 10);
        expect(createInviteBody['allowed_role'], 'member');

        final revokeBody = jsonDecode(captured[9].body) as Map<String, dynamic>;
        expect(revokeBody['revoked'], isTrue);
      } finally {
        await db.close();
      }
    });

    test(
      'HTTP room state mutation endpoints sign requests and parse responses',
      () async {
        final db = await AppDb.openForTesting();
        final kp = await Ed25519().newKeyPair();
        final captured = <http.Request>[];
        const roomAfterProfile =
            '{"room_id":"group:room-2","version":5,"membership_version":7,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch Pad","description":"Release lane","avatar_hash":"hash-1","avatar_image_b64":"QQ==","reactions_mode":"all","allow_text":true,"allow_media":true,"allow_add_members":true,"allow_pin_messages":true,"allow_change_group_info":true,"allow_change_tag":false,"join_approval_required":false,"slow_mode_seconds":0,"chat_history_visible":false,"created_at_ms":1000,"updated_at_ms":2400}';
        const roomAfterSettings =
            '{"room_id":"group:room-2","version":6,"membership_version":7,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch Pad","description":"Release lane","avatar_hash":"hash-1","avatar_image_b64":"QQ==","reactions_mode":"selected","allow_text":false,"allow_media":true,"allow_add_members":false,"allow_pin_messages":true,"allow_change_group_info":false,"allow_change_tag":true,"join_approval_required":true,"slow_mode_seconds":30,"chat_history_visible":true,"created_at_ms":1000,"updated_at_ms":2500}';
        const roomAfterLeave =
            '{"room_id":"group:room-2","version":7,"membership_version":8,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch Pad","description":"Release lane","avatar_hash":"hash-1","avatar_image_b64":"QQ==","reactions_mode":"selected","allow_text":false,"allow_media":true,"allow_add_members":false,"allow_pin_messages":true,"allow_change_group_info":false,"allow_change_tag":true,"join_approval_required":true,"slow_mode_seconds":30,"chat_history_visible":true,"created_at_ms":1000,"updated_at_ms":2600}';
        final client = MockClient((request) async {
          captured.add(request);
          return switch ('${request.method} ${request.url.path}') {
            'POST /v1/rooms/group%3Aroom-2/profile' => http.Response(
              '{"ok":true,"changed":true,"room":$roomAfterProfile}',
              200,
            ),
            'POST /v1/rooms/group%3Aroom-2/settings' => http.Response(
              '{"ok":true,"changed":true,"room":$roomAfterSettings}',
              200,
            ),
            'POST /v1/rooms/group%3Aroom-2/leave' => http.Response(
              '{"ok":true,"changed":true,"room":$roomAfterLeave,"membership":{"room_id":"group:room-2","profile_id":"self-profile","status":"left","role":"owner","source_link_id":null,"created_at_ms":1000,"updated_at_ms":2600}}',
              200,
            ),
            _ => http.Response('not found', 404),
          };
        });

        try {
          final relay = await buildRelayClient(
            db: db,
            httpClient: client,
            identityKeyPair: kp,
          );

          final profileResult = await relay.updateRoomProfile(
            roomId: 'group:room-2',
            title: 'Launch Pad',
            description: 'Release lane',
            avatarHash: 'hash-1',
            avatarImageB64: 'QQ==',
          );
          final settingsResult = await relay.updateRoomSettings(
            roomId: 'group:room-2',
            reactionsMode: 'selected',
            allowText: false,
            allowMedia: true,
            allowAddMembers: false,
            allowPinMessages: true,
            allowChangeGroupInfo: false,
            allowChangeTag: true,
            joinApprovalRequired: true,
            slowModeSeconds: 30,
            chatHistoryVisible: true,
          );
          final leaveResult = await relay.leaveRoom(roomId: 'group:room-2');

          expect(profileResult.changed, isTrue);
          expect(profileResult.room.title, 'Launch Pad');
          expect(profileResult.room.description, 'Release lane');
          expect(profileResult.room.avatarHash, 'hash-1');
          expect(profileResult.room.avatarImageB64, 'QQ==');

          expect(settingsResult.changed, isTrue);
          expect(settingsResult.room.reactionsMode, 'selected');
          expect(settingsResult.room.allowText, isFalse);
          expect(settingsResult.room.allowAddMembers, isFalse);
          expect(settingsResult.room.allowChangeTag, isTrue);
          expect(settingsResult.room.joinApprovalRequired, isTrue);
          expect(settingsResult.room.slowModeSeconds, 30);
          expect(settingsResult.room.chatHistoryVisible, isTrue);

          expect(leaveResult.changed, isTrue);
          expect(leaveResult.room.membershipVersion, 8);
          expect(leaveResult.membership.status, 'left');
          expect(leaveResult.membership.role, 'owner');

          expect(
            captured.map((request) => '${request.method} ${request.url.path}'),
            <String>[
              'POST /v1/rooms/group%3Aroom-2/profile',
              'POST /v1/rooms/group%3Aroom-2/settings',
              'POST /v1/rooms/group%3Aroom-2/leave',
            ],
          );
          for (final request in captured) {
            expect(request.headers['x-secretly-device-id'], 'self-device');
            expect(request.headers['x-secretly-signature-b64'], isNotEmpty);
          }

          final profileBody =
              jsonDecode(captured[0].body) as Map<String, dynamic>;
          expect(profileBody['title'], 'Launch Pad');
          expect(profileBody['description'], 'Release lane');
          expect(profileBody['avatar_hash'], 'hash-1');
          expect(profileBody['avatar_image_b64'], 'QQ==');

          final settingsBody =
              jsonDecode(captured[1].body) as Map<String, dynamic>;
          expect(settingsBody['reactions_mode'], 'selected');
          expect(settingsBody['allow_text'], isFalse);
          expect(settingsBody['allow_add_members'], isFalse);
          expect(settingsBody['allow_change_tag'], isTrue);
          expect(settingsBody['join_approval_required'], isTrue);
          expect(settingsBody['slow_mode_seconds'], 30);
          expect(settingsBody['chat_history_visible'], isTrue);

          final leaveBody =
              jsonDecode(captured[2].body) as Map<String, dynamic>;
          expect(leaveBody, isEmpty);
        } finally {
          await db.close();
        }
      },
    );

    test('HTTP room call moderation endpoints sign requests and parse responses', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      final captured = <http.Request>[];
      const roomJson =
          '{"room_id":"group:room-2b","version":6,"membership_version":7,"owner_profile_id":"self-profile","created_by_device_id":"self-device","title":"Launch Pad","description":"Release lane","avatar_hash":null,"avatar_image_b64":null,"reactions_mode":"all","allow_text":true,"allow_media":true,"allow_add_members":true,"allow_pin_messages":true,"allow_change_group_info":true,"allow_change_tag":false,"join_approval_required":false,"slow_mode_seconds":0,"chat_history_visible":false,"created_at_ms":1000,"updated_at_ms":2500}';
      const activeCallJson =
          '{"call_id":"call-1","room_id":"group:room-2b","state":"active","media_type":"video","created_by_profile_id":"self-profile","created_by_device_id":"self-device","state_version":4,"started_at_ms":1000,"updated_at_ms":3000,"ended_at_ms":null,"expires_at_ms":9000}';
      const endedCallJson =
          '{"call_id":"call-1","room_id":"group:room-2b","state":"ended","media_type":"video","created_by_profile_id":"self-profile","created_by_device_id":"self-device","state_version":5,"started_at_ms":1000,"updated_at_ms":4000,"ended_at_ms":4000,"expires_at_ms":12000}';
      const selfParticipantJoinedJson =
          '{"call_id":"call-1","room_id":"group:room-2b","profile_id":"self-profile","device_id":"self-device","join_state":"joined","supports_video":true,"supports_screen_share":false,"muted":false,"deafened":false,"video_enabled":true,"screen_share_enabled":false,"speaking":false,"joined_at_ms":1000,"left_at_ms":null,"updated_at_ms":3000}';
      const selfParticipantLeftJson =
          '{"call_id":"call-1","room_id":"group:room-2b","profile_id":"self-profile","device_id":"self-device","join_state":"left","supports_video":true,"supports_screen_share":false,"muted":false,"deafened":false,"video_enabled":false,"screen_share_enabled":false,"speaking":false,"joined_at_ms":1000,"left_at_ms":4000,"updated_at_ms":4000}';
      const peerParticipantRemovedJson =
          '{"call_id":"call-1","room_id":"group:room-2b","profile_id":"peer-profile","device_id":"peer-device","join_state":"removed","supports_video":false,"supports_screen_share":false,"muted":false,"deafened":false,"video_enabled":false,"screen_share_enabled":false,"speaking":false,"joined_at_ms":1200,"left_at_ms":3000,"updated_at_ms":3000}';
      final client = MockClient((request) async {
        captured.add(request);
        return switch ('${request.method} ${request.url.path}') {
          'POST /v1/rooms/group%3Aroom-2b/call/call-1/participants/peer-device/remove' =>
            http.Response(
              '{"ok":true,"changed":true,"room":$roomJson,"call":$activeCallJson,"participants":[$selfParticipantJoinedJson,$peerParticipantRemovedJson],"self_participant":$selfParticipantJoinedJson}',
              200,
            ),
          'POST /v1/rooms/group%3Aroom-2b/call/call-1/end' => http.Response(
            '{"ok":true,"changed":true,"room":$roomJson,"call":$endedCallJson,"participants":[$selfParticipantLeftJson,$peerParticipantRemovedJson],"self_participant":$selfParticipantLeftJson}',
            200,
          ),
          _ => http.Response('not found', 404),
        };
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final removed = await relay.removeRoomCallParticipant(
          roomId: 'group:room-2b',
          callId: 'call-1',
          participantDeviceId: 'peer-device',
        );
        final ended = await relay.endRoomCall(
          roomId: 'group:room-2b',
          callId: 'call-1',
        );

        expect(
          captured.map((request) => '${request.method} ${request.url.path}'),
          <String>[
            'POST /v1/rooms/group%3Aroom-2b/call/call-1/participants/peer-device/remove',
            'POST /v1/rooms/group%3Aroom-2b/call/call-1/end',
          ],
        );
        for (final request in captured) {
          expect(request.headers['x-secretly-device-id'], 'self-device');
          expect(request.headers['x-secretly-signature-b64'], isNotEmpty);
          expect(jsonDecode(request.body) as Map<String, dynamic>, isEmpty);
        }

        expect(removed.changed, isTrue);
        expect(removed.call.state, 'active');
        expect(removed.selfParticipant, isNotNull);
        expect(
          removed.participants
              .firstWhere(
                (participant) => participant.deviceId == 'peer-device',
              )
              .joinState,
          'removed',
        );

        expect(ended.changed, isTrue);
        expect(ended.call.state, 'ended');
        expect(ended.call.endedAtMs, 4000);
        expect(ended.selfParticipant, isNotNull);
        expect(ended.selfParticipant!.joinState, 'left');
      } finally {
        await db.close();
      }
    });

    test('HTTP room message admission signs request and parses response', () async {
      final db = await AppDb.openForTesting();
      final kp = await Ed25519().newKeyPair();
      late http.Request captured;
      const roomJson =
          '{"room_id":"group:room-3","version":8,"membership_version":9,"owner_profile_id":"owner-profile","created_by_device_id":"owner-device","title":"Launch Room","description":null,"avatar_hash":null,"avatar_image_b64":null,"reactions_mode":"all","allow_text":true,"allow_media":true,"allow_add_members":true,"allow_pin_messages":true,"allow_change_group_info":true,"allow_change_tag":false,"join_approval_required":false,"slow_mode_seconds":15,"chat_history_visible":false,"created_at_ms":1000,"updated_at_ms":3000}';
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true,"message_id":"00000000-0000-0000-0000-00000000b301","kind":"text","admitted_at_ms":3000,"next_allowed_at_ms":18000,"room":$roomJson}',
          200,
        );
      });

      try {
        final relay = await buildRelayClient(
          db: db,
          httpClient: client,
          identityKeyPair: kp,
        );

        final result = await relay.admitRoomMessage(
          roomId: 'group:room-3',
          messageId: '00000000-0000-0000-0000-00000000b301',
          kind: 'text',
        );

        expect(captured.method, 'POST');
        expect(
          captured.url.path,
          '/v1/rooms/group%3Aroom-3/message-admissions',
        );
        expect(captured.headers['x-secretly-device-id'], 'self-device');
        expect(captured.headers['x-secretly-signature-b64'], isNotEmpty);

        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['message_id'], '00000000-0000-0000-0000-00000000b301');
        expect(body['kind'], 'text');

        expect(result.ok, isTrue);
        expect(result.messageId, '00000000-0000-0000-0000-00000000b301');
        expect(result.kind, 'text');
        expect(result.admittedAtMs, 3000);
        expect(result.nextAllowedAtMs, 18000);
        expect(result.room.roomId, 'group:room-3');
        expect(result.room.slowModeSeconds, 15);
      } finally {
        await db.close();
      }
    });

    test(
      'HTTP room pinned message mutation signs request and parses response',
      () async {
        final db = await AppDb.openForTesting();
        final kp = await Ed25519().newKeyPair();
        final captured = <http.Request>[];
        const roomPinnedJson =
            '{"room_id":"group:room-4","version":9,"membership_version":9,"owner_profile_id":"owner-profile","created_by_device_id":"owner-device","title":"Launch Room","description":null,"avatar_hash":null,"avatar_image_b64":null,"reactions_mode":"all","allow_text":true,"allow_media":true,"allow_add_members":true,"allow_pin_messages":true,"allow_change_group_info":true,"allow_change_tag":false,"join_approval_required":false,"slow_mode_seconds":0,"chat_history_visible":false,"pinned_message_id":"event-pin-1","created_at_ms":1000,"updated_at_ms":3100}';
        const roomUnpinnedJson =
            '{"room_id":"group:room-4","version":10,"membership_version":9,"owner_profile_id":"owner-profile","created_by_device_id":"owner-device","title":"Launch Room","description":null,"avatar_hash":null,"avatar_image_b64":null,"reactions_mode":"all","allow_text":true,"allow_media":true,"allow_add_members":true,"allow_pin_messages":true,"allow_change_group_info":true,"allow_change_tag":false,"join_approval_required":false,"slow_mode_seconds":0,"chat_history_visible":false,"pinned_message_id":null,"created_at_ms":1000,"updated_at_ms":3200}';
        final client = MockClient((request) async {
          captured.add(request);
          return switch (captured.length) {
            1 => http.Response(
              '{"ok":true,"changed":true,"room":$roomPinnedJson}',
              200,
            ),
            2 => http.Response(
              '{"ok":true,"changed":true,"room":$roomUnpinnedJson}',
              200,
            ),
            _ => http.Response('not found', 404),
          };
        });

        try {
          final relay = await buildRelayClient(
            db: db,
            httpClient: client,
            identityKeyPair: kp,
          );

          final pinned = await relay.setRoomPinnedMessage(
            roomId: 'group:room-4',
            messageId: 'event-pin-1',
          );
          final unpinned = await relay.setRoomPinnedMessage(
            roomId: 'group:room-4',
            messageId: null,
          );

          expect(captured, hasLength(2));
          expect(captured[0].method, 'POST');
          expect(
            captured[0].url.path,
            '/v1/rooms/group%3Aroom-4/pinned-message',
          );
          expect(captured[0].headers['x-secretly-device-id'], 'self-device');
          expect(captured[0].headers['x-secretly-signature-b64'], isNotEmpty);

          final firstBody =
              jsonDecode(captured[0].body) as Map<String, dynamic>;
          expect(firstBody['message_id'], 'event-pin-1');

          final secondBody =
              jsonDecode(captured[1].body) as Map<String, dynamic>;
          expect(secondBody['message_id'], isNull);

          expect(pinned.changed, isTrue);
          expect(pinned.room.pinnedMessageId, 'event-pin-1');
          expect(unpinned.changed, isTrue);
          expect(unpinned.room.pinnedMessageId, isNull);
        } finally {
          await db.close();
        }
      },
    );
  });
}
