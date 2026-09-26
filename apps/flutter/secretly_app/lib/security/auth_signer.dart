// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

class AuthEnvelopeV1 {
  const AuthEnvelopeV1({
    required this.tsMs,
    required this.nonceB64,
    required this.signatureB64,
  });

  final int tsMs;
  final String nonceB64;
  final String signatureB64;
}

class AuthSigner {
  AuthSigner._();

  static List<String> _normalizedDeviceIds(Iterable<String> deviceIds) {
    final ids = deviceIds
        .map((deviceId) => deviceId.trim())
        .where((deviceId) => deviceId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    ids.sort();
    return ids;
  }

  static String randomNonceB64({int bytes = 16}) {
    final rng = Random.secure();
    final b = Uint8List(bytes);
    for (var i = 0; i < b.length; i++) {
      b[i] = rng.nextInt(256);
    }
    return base64Encode(b);
  }

  static Future<String> signEd25519B64({
    required SimpleKeyPair identityKeyPair,
    required List<int> message,
  }) async {
    final sig = await Ed25519().sign(message, keyPair: identityKeyPair);
    return base64Encode(sig.bytes);
  }

  static List<int> keysRegisterMessage({
    required String profileId,
    required String deviceId,
    required int tsMs,
    required String nonceB64,
    required String identityKeyPubB64,
  }) {
    return utf8.encode(
      'SECRETLY-DEVICE-REGISTER-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'identity_key_pub_b64=$identityKeyPubB64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static Future<String> keysPublishMessageOtkHashB64({
    required List<Map<String, Object?>> oneTimePrekeys,
  }) async {
    // Must match server: sort by prekey_id asc, hash (i64 BE) + pub_b64 + "\n".
    final list = [...oneTimePrekeys];
    list.sort((a, b) {
      final ai = (a['prekey_id'] as num).toInt();
      final bi = (b['prekey_id'] as num).toInt();
      return ai.compareTo(bi);
    });

    final sink = BytesBuilder(copy: false);
    for (final k in list) {
      final id = (k['prekey_id'] as num).toInt();
      final pub = (k['prekey_pub_b64'] as String?) ?? '';
      final idBytes = ByteData(8)..setInt64(0, id, Endian.big);
      sink.add(idBytes.buffer.asUint8List());
      sink.add(utf8.encode(pub));
      sink.add(const [0x0A]);
    }

    final h = await Sha256().hash(sink.toBytes());
    return base64Encode(h.bytes);
  }

  static List<int> keysPublishMessage({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    required String oneTimePrekeysSha256B64,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-PUBLISH-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'identity_key_pub_b64=$identityKeyPubB64\n'
      'signed_prekey_pub_b64=$signedPrekeyPubB64\n'
      'signed_prekey_sig_b64=$signedPrekeySigB64\n'
      'one_time_prekeys_sha256_b64=$oneTimePrekeysSha256B64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysProfileMetaSetMessage({
    required String profileId,
    required String deviceId,
    required String nickname,
    required String avatarPngB64,
    required String bio,
    required String privacyAudienceJson,
    required bool searchableByNickname,
  }) {
    return utf8.encode(
      'SECRETLY-PROFILE-META-SET-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'nickname=$nickname\n'
      'avatar_png_b64=$avatarPngB64\n'
      'bio=$bio\n'
      'privacy_audience_json=$privacyAudienceJson\n'
      'searchable_by_nickname=${searchableByNickname ? 1 : 0}\n',
    );
  }

  static List<int> keysProfileInactivitySetMessage({
    required String profileId,
    required String deviceId,
    required int? deleteAfterInactivityMonths,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-PROFILE-INACTIVITY-SET-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'delete_after_inactivity_months=${deleteAfterInactivityMonths?.toString() ?? ''}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysProfileInactivityHeartbeatMessage({
    required String profileId,
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-PROFILE-INACTIVITY-HEARTBEAT-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysBackupSetMessage({
    required String profileId,
    required String deviceId,
    required String payloadSha256B64,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-BACKUP-SET-V1\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'payload_sha256_b64=$payloadSha256B64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Э-1 (SEC-01): подпись сохранения архива ВМЕСТЕ с опорой токена доступа.
  ///
  /// Опора обязана быть под подписью — иначе посредник подменил бы проверочное
  /// значение и запер владельца в его собственном архиве. Отдельная версия
  /// сообщения, а не расширение прежней: старые сборки продолжают подписывать
  /// ровно то, что подписывали всегда, и сервер разбирает обе.
  static List<int> keysBackupSetMessageV2({
    required String profileId,
    required String deviceId,
    required String payloadSha256B64,
    required String accessSaltB64,
    required String accessVerifierB64,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-BACKUP-SET-V2\n'
      'profile_id=$profileId\n'
      'device_id=$deviceId\n'
      'payload_sha256_b64=$payloadSha256B64\n'
      'access_salt_b64=$accessSaltB64\n'
      'access_verifier_b64=$accessVerifierB64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// SEC-07: подпись запроса метаданных профиля.
  ///
  /// Эндпоинт отвечает и без неё — так его вызывают уже выпущенные сборки. Но
  /// предъявившему подпись сервер отдаёт точное время присутствия, а
  /// остальным огрублённое до часа: по точному можно было следить за чужим
  /// распорядком дня, зная лишь полупубличный идентификатор.
  static List<int> keysProfileMetaGetMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-PROFILE-META-GET-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysDeviceLookupMessage({
    required String requesterDeviceId,
    required String targetDeviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-DEVICE-LOOKUP-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'target_device_id=$targetDeviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysProfileSearchMessage({
    required String requesterDeviceId,
    required String query,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-PROFILE-SEARCH-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'query=$query\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// П-5 (25.09.2026): «что со мной?» — устройство спрашивает о себе.
  /// ОБЯЗАНО совпадать с Rust `keys_device_self_status_auth_message`.
  static List<int> keysDeviceSelfStatusMessage({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-DEVICE-SELF-STATUS-V1\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// П-1 (25.09.2026): связка ОДНОГО устройства. ОБЯЗАНО совпадать с Rust
  /// `keys_fetch_device_bundle_auth_message`.
  static List<int> keysFetchDeviceBundleMessage({
    required String requesterDeviceId,
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-FETCH-DEVICE-BUNDLE-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysListDevicesMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-LIST-DEVICES-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysFetchBundleMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-BUNDLE-FETCH-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysDeleteDeviceMessage({
    required String requesterDeviceId,
    required String profileId,
    required String targetDeviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-DELETE-DEVICE-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'target_device_id=$targetDeviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysDeleteProfileMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-DELETE-PROFILE-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysBackupGetMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-BACKUP-GET-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysEntitlementsGetMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-ENTITLEMENTS-GET-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysLegacyClaimMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-LEGACY-CLAIM-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> keysRedeemMessage({
    required String requesterDeviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-KEYS-REDEEM-V1\n'
      'requester_device_id=$requesterDeviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHelloMessage({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HELLO-V1\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static Future<String> sha256B64(List<int> bytes) async {
    final h = await Sha256().hash(bytes);
    return base64Encode(h.bytes);
  }

  static List<int> relayHttpWelcomeMessage({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-WELCOME-V1\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpPendingMessage({
    required String deviceId,
    required int fromSeq,
    required int limit,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-PENDING-V1\n'
      'device_id=$deviceId\n'
      'from_seq=$fromSeq\n'
      'limit=$limit\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Support ticket submit (TZ 2026-07-24). MUST byte-match the relay's
  /// `http_support_submit_auth_message`.
  static List<int> relayHttpSupportSubmitMessage({
    required String deviceId,
    required String ticketId,
    required String replyPubkeyB64,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-SUPPORT-SUBMIT-V1\n'
      'device_id=$deviceId\n'
      'ticket_id=$ticketId\n'
      'reply_pubkey_b64=$replyPubkeyB64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Support replies poll. MUST byte-match `http_support_replies_auth_message`.
  static List<int> relayHttpSupportRepliesMessage({
    required String deviceId,
    required int from,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-SUPPORT-REPLIES-V1\n'
      'device_id=$deviceId\n'
      'from=$from\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Текст подписи для `/v1/pending_check` — «держишь ли ты ещё мои конверты
  /// для этого получателя». Должен посимвольно совпадать с
  /// `http_pending_check_auth_message` в реле.
  ///
  /// msg_id входят в подпись: иначе посредник мог бы подменить список и
  /// заставить нас поверить, что доставлено то, что не доставлено.
  static List<int> relayHttpPendingCheckMessage({
    required String deviceId,
    required String toDeviceId,
    required List<String> msgIds,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-PENDING-CHECK-V1\n'
      'device_id=$deviceId\n'
      'to_device_id=$toDeviceId\n'
      'msg_ids=${msgIds.join(',')}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpAckMessage({
    required String deviceId,
    required int seq,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ACK-V1\n'
      'device_id=$deviceId\n'
      'seq=$seq\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Mirrors Rust `http_cancel_scheduled_auth_message` (2026-07-19): the
  /// sender retracts a still-held "send later" row so it can re-upload the
  /// same message under a fresh session.
  static List<int> relayHttpCancelScheduledMessage({
    required String deviceId,
    required String toDeviceId,
    required String msgId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-CANCEL-SCHEDULED-V1\n'
      'device_id=$deviceId\n'
      'to_device_id=$toDeviceId\n'
      'msg_id=$msgId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRebindMessage({
    required String newDeviceId,
    required String oldDeviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-REBIND-V1\n'
      'new_device_id=$newDeviceId\n'
      'old_device_id=$oldDeviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpSendMessage({
    required String fromDeviceId,
    required String toDeviceId,
    required String msgId,
    required String ciphertextB64,
    required int ttlSeconds,
    String? transportMetaJson,
    required int tsMs,
    required String nonceB64,
  }) {
    final normalizedTransportMetaJson = (transportMetaJson ?? '').trim();
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-SEND-V1\n'
      'from_device_id=$fromDeviceId\n'
      'to_device_id=$toDeviceId\n'
      'msg_id=$msgId\n'
      'ciphertext_b64=$ciphertextB64\n'
      'ttl_seconds=$ttlSeconds\n'
      'transport_meta_json=$normalizedTransportMetaJson\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// К-2 (17.09.2026): подпись рассылки комнатного провода. ОБЯЗАНА
  /// совпадать с Rust `http_room_broadcast_auth_message` побайтно: шифртекст и
  /// список получателей входят как SHA-256 (base64), список — отсортированный
  /// и склеенный переводом строки.
  static List<int> relayHttpRoomBroadcastMessage({
    required String fromDeviceId,
    required String roomId,
    required String msgId,
    required String ciphertextB64,
    required List<String> recipients,
    required int ttlSeconds,
    required int deliverAtMs,
    String? transportMetaJson,
    required int tsMs,
    required String nonceB64,
  }) {
    String digest(String text) =>
        base64Encode(crypto.sha256.convert(utf8.encode(text)).bytes);
    final sorted = [...recipients]..sort();
    return utf8.encode(
      'SECRETLY-RELAY-ROOM-BROADCAST-V1\n'
      'from_device_id=$fromDeviceId\n'
      'room_id=$roomId\n'
      'msg_id=$msgId\n'
      'ciphertext_sha256_b64=${digest(ciphertextB64)}\n'
      'recipients_sha256_b64=${digest(sorted.join('\n'))}\n'
      'ttl_seconds=$ttlSeconds\n'
      'deliver_at_ms=$deliverAtMs\n'
      'transport_meta_json=${(transportMetaJson ?? '').trim()}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpCallSessionMessage({
    required String deviceId,
    required String callId,
    required String callAttemptId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-CALL-SESSION-V1\n'
      'device_id=$deviceId\n'
      'call_id=$callId\n'
      'call_attempt_id=$callAttemptId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpIceConfigMessage({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ICE-CONFIG-V1\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpBlobUploadMessage({
    required String deviceId,
    required int ttlSeconds,
    required String bodySha256B64,
    required String accessTokenSha256B64,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-BLOB-UPLOAD-V1\n'
      'device_id=$deviceId\n'
      'ttl_seconds=$ttlSeconds\n'
      'body_sha256_b64=$bodySha256B64\n'
      'access_token_sha256_b64=$accessTokenSha256B64\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpBlobGetMessage({
    required String deviceId,
    required String blobId,
    String? accessTokenSha256B64,
    required int tsMs,
    required String nonceB64,
  }) {
    final message = StringBuffer()
      ..write('SECRETLY-RELAY-HTTP-BLOB-GET-V1\n')
      ..write('device_id=$deviceId\n')
      ..write('blob_id=$blobId\n');
    if (accessTokenSha256B64 != null) {
      message.write('access_token_sha256_b64=$accessTokenSha256B64\n');
    }
    message
      ..write('ts_ms=$tsMs\n')
      ..write('nonce_b64=$nonceB64\n');
    return utf8.encode(message.toString());
  }

  static List<int> relayHttpBlocksListMessage({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-BLOCKS-LIST-V1\n'
      'device_id=$deviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  /// Sprint 2 R3: auth message for `GET /v1/active_devices/{device_id}/{profile_id}`.
  /// The requester (`deviceId`) signs the message; `profileId` identifies the
  /// peer whose active-device set we are probing. Must stay in lockstep with
  /// `http_active_devices_auth_message` on the relay (server/relay/src/main.rs).
  static List<int> relayHttpActiveDevicesMessage({
    required String deviceId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ACTIVE-DEVICES-V1\n'
      'device_id=$deviceId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpBlocksSetMessage({
    required String deviceId,
    required String blockedProfileId,
    required bool blocked,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-BLOCKS-SET-V1\n'
      'device_id=$deviceId\n'
      'blocked_profile_id=$blockedProfileId\n'
      'blocked=${blocked ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpPushTokenSetMessage({
    required String deviceId,
    required String token,
    required String platform,
    required bool enabled,
    String? policyB64,
    required int tsMs,
    required String nonceB64,
  }) {
    // AUD-013: the `policy_b64=` line is always emitted (possibly empty) so
    // the client matches `http_push_token_set_auth_message` on the server.
    final normalizedPolicyB64 = (policyB64 ?? '').trim();
    final message = StringBuffer()
      ..write('SECRETLY-RELAY-HTTP-PUSH-TOKEN-SET-V1\n')
      ..write('device_id=$deviceId\n')
      ..write('token=$token\n')
      ..write('platform=$platform\n')
      ..write('enabled=${enabled ? 1 : 0}\n')
      ..write('policy_b64=$normalizedPolicyB64\n')
      ..write('ts_ms=$tsMs\n')
      ..write('nonce_b64=$nonceB64\n');
    return utf8.encode(message.toString());
  }

  static List<int> relayHttpProfileDeleteMessage({
    required String deviceId,
    required String profileId,
    required List<String> deviceIds,
    required int tsMs,
    required String nonceB64,
  }) {
    final normalizedDeviceIds = _normalizedDeviceIds(deviceIds).join(',');
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-PROFILE-DELETE-V1\n'
      'device_id=$deviceId\n'
      'profile_id=$profileId\n'
      'device_ids=$normalizedDeviceIds\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCreateMessage({
    required String deviceId,
    required String roomId,
    required String title,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CREATE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'title=$title\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomGetMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-GET-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomMembersListMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-MEMBERS-LIST-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomMembersUpsertMessage({
    required String deviceId,
    required String roomId,
    required String profileId,
    required String status,
    required String role,
    String? sourceLinkId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-MEMBERS-UPSERT-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'profile_id=$profileId\n'
      'status=$status\n'
      'role=$role\n'
      'source_link_id=${(sourceLinkId ?? '').trim()}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomMemberUnbanMessage({
    required String deviceId,
    required String roomId,
    required String profileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-MEMBER-UNBAN-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'profile_id=$profileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomMemberTagSetMessage({
    required String deviceId,
    required String roomId,
    String? tag,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-MEMBER-TAG-SET-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'tag=${(tag ?? '').trim()}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomTransferOwnershipMessage({
    required String deviceId,
    required String roomId,
    required String nextOwnerProfileId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-TRANSFER-OWNERSHIP-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'next_owner_profile_id=$nextOwnerProfileId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomProfileUpdateMessage({
    required String deviceId,
    required String roomId,
    required String title,
    String? description,
    String? avatarHash,
    String? avatarImageB64,
    bool clearAvatar = false,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-PROFILE-UPDATE-V2\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'title=$title\n'
      'description=${(description ?? '').trim()}\n'
      'avatar_hash=${(avatarHash ?? '').trim()}\n'
      'avatar_image_b64=${(avatarImageB64 ?? '').trim()}\n'
      'clear_avatar=${clearAvatar ? 'true' : 'false'}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomSettingsUpdateMessage({
    required String deviceId,
    required String roomId,
    required String reactionsMode,
    required bool allowText,
    required bool allowMedia,
    required bool allowAddMembers,
    required bool allowPinMessages,
    required bool allowChangeGroupInfo,
    required bool allowChangeTag,
    required bool joinApprovalRequired,
    required int slowModeSeconds,
    required bool chatHistoryVisible,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-SETTINGS-UPDATE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'reactions_mode=$reactionsMode\n'
      'allow_text=${allowText ? 1 : 0}\n'
      'allow_media=${allowMedia ? 1 : 0}\n'
      'allow_add_members=${allowAddMembers ? 1 : 0}\n'
      'allow_pin_messages=${allowPinMessages ? 1 : 0}\n'
      'allow_change_group_info=${allowChangeGroupInfo ? 1 : 0}\n'
      'allow_change_tag=${allowChangeTag ? 1 : 0}\n'
      'join_approval_required=${joinApprovalRequired ? 1 : 0}\n'
      'slow_mode_seconds=$slowModeSeconds\n'
      'chat_history_visible=${chatHistoryVisible ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomMessageAdmissionMessage({
    required String deviceId,
    required String roomId,
    required String messageId,
    required String kind,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-MESSAGE-ADMISSION-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'message_id=$messageId\n'
      'kind=$kind\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomPinnedMessageSetMessage({
    required String deviceId,
    required String roomId,
    String? messageId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-PINNED-MESSAGE-SET-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'message_id=${(messageId ?? '').trim()}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomLeaveMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-LEAVE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomDeleteMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-DELETE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallGetMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-GET-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallJoinMessage({
    required String deviceId,
    required String roomId,
    required String mediaType,
    required bool supportsVideo,
    required bool supportsScreenShare,
    required bool muted,
    required bool deafened,
    required bool videoEnabled,
    required bool screenShareEnabled,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-JOIN-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'media_type=$mediaType\n'
      'supports_video=${supportsVideo ? 1 : 0}\n'
      'supports_screen_share=${supportsScreenShare ? 1 : 0}\n'
      'muted=${muted ? 1 : 0}\n'
      'deafened=${deafened ? 1 : 0}\n'
      'video_enabled=${videoEnabled ? 1 : 0}\n'
      'screen_share_enabled=${screenShareEnabled ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallSelfUpdateMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required bool reconnecting,
    required bool muted,
    required bool deafened,
    required bool videoEnabled,
    required bool screenShareEnabled,
    required bool speaking,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-SELF-UPDATE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'reconnecting=${reconnecting ? 1 : 0}\n'
      'muted=${muted ? 1 : 0}\n'
      'deafened=${deafened ? 1 : 0}\n'
      'video_enabled=${videoEnabled ? 1 : 0}\n'
      'screen_share_enabled=${screenShareEnabled ? 1 : 0}\n'
      'speaking=${speaking ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallLeaveMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-LEAVE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallParticipantRemoveMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required String participantDeviceId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-PARTICIPANT-REMOVE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'participant_device_id=$participantDeviceId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallEndMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-END-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallMediaGetMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-MEDIA-GET-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomCallMediaJoinMessage({
    required String deviceId,
    required String roomId,
    required String callId,
    required bool publishAudio,
    required bool publishVideo,
    required bool publishScreenShare,
    required bool subscribeAll,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-CALL-MEDIA-JOIN-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'call_id=$callId\n'
      'publish_audio=${publishAudio ? 1 : 0}\n'
      'publish_video=${publishVideo ? 1 : 0}\n'
      'publish_screen_share=${publishScreenShare ? 1 : 0}\n'
      'subscribe_all=${subscribeAll ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomInviteLinksListMessage({
    required String deviceId,
    required String roomId,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-INVITE-LINKS-LIST-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomInviteLinksCreateMessage({
    required String deviceId,
    required String roomId,
    int? expiresAtMs,
    int? maxUses,
    required bool requiresApproval,
    required String allowedRole,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-INVITE-LINKS-CREATE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'expires_at_ms=${expiresAtMs?.toString() ?? ''}\n'
      'max_uses=${maxUses?.toString() ?? ''}\n'
      'requires_approval=${requiresApproval ? 1 : 0}\n'
      'allowed_role=$allowedRole\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomInviteLinkRevokeMessage({
    required String deviceId,
    required String roomId,
    required String linkId,
    required bool revoked,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-INVITE-LINK-REVOKE-V1\n'
      'device_id=$deviceId\n'
      'room_id=$roomId\n'
      'link_id=$linkId\n'
      'revoked=${revoked ? 1 : 0}\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomInvitePreviewMessage({
    required String deviceId,
    required String slug,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-INVITE-PREVIEW-V1\n'
      'device_id=$deviceId\n'
      'slug=$slug\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }

  static List<int> relayHttpRoomInviteRedeemMessage({
    required String deviceId,
    required String slug,
    required int tsMs,
    required String nonceB64,
  }) {
    return utf8.encode(
      'SECRETLY-RELAY-HTTP-ROOM-INVITE-REDEEM-V1\n'
      'device_id=$deviceId\n'
      'slug=$slug\n'
      'ts_ms=$tsMs\n'
      'nonce_b64=$nonceB64\n',
    );
  }
}
