// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Сквозное шифрование групповых созвонов: протокол ключей (v1).
///
/// ТЗ: `docs/TZ_GROUP_CALL_E2EE_2026-10-06.md`, §4.
///
/// Здесь только чистая логика без движка и сети: константы протокола,
/// идентичность участника в LiveKit, разбор служебных команд и проверка
/// пришедшего ключа. Всё это проверяется юнит-тестами строка в строку.
///
/// 🔴 Ключ — секрет. Ни одна функция этого файла не пишет его в журнал и не
/// кладёт в строку ошибки; для диагностики есть только [callKeyFingerprint].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Контракт открытого созвона: медиа видит сервер (так было всегда).
const String kRoomMediaContractV1 = 'room_media_v1';

/// Контракт созвона со сквозным шифрованием медиа.
const String kRoomMediaContractE2eeV1 = 'room_media_e2ee_v1';

/// Возможность устройства «понимаю ключи созвона» (`caps` в `E2ePayloadV1`).
const String kRoomCallKeyCapability = 'rc1';

/// Кольцо индексов ключей у шифратора.
const int kCallKeyRingSize = 16;

/// Длина ключа отправителя.
const int kCallKeyLength = 32;

/// Соль вывода ключа. Участвует в КАЖДОМ выводе ключа шифрования в нативе
/// (PBKDF2-SHA256), поэтому одинакова у всех: смена — это новая версия
/// протокола.
const String kCallRatchetSalt = 'secretly-call-v1';

/// Допуск часов для `sentAtMs`: широкий из-за устройств со сбитыми часами.
const Duration kCallKeyClockSkew = Duration(minutes: 10);

/// Больше стольких ключей в минуту от одного устройства не принимаем.
const int kCallKeyMaxGrantsPerMinute = 20;

/// Нормализованный контракт: всё незнакомое — открытый созвон, как раньше.
String normalizeRoomMediaContract(String? raw) {
  final value = (raw ?? '').trim();
  return value == kRoomMediaContractE2eeV1
      ? kRoomMediaContractE2eeV1
      : kRoomMediaContractV1;
}

bool isE2eeRoomMediaContract(String? raw) =>
    (raw ?? '').trim() == kRoomMediaContractE2eeV1;

// ── Идентичность в LiveKit ─────────────────────────────────────────────────
//
// Зеркало Rust `room_media_backend_participant_identity` (реле). Совпадение
// закреплено общим тест-вектором: так участник сам проверяет, чья дорожка, и
// не верит ни SFU, ни metadata токена.

/// `room_media_backend_safe_segment`: латиница, цифры, `-` и `_` остаются,
/// всё остальное — `_`; не длиннее [maxLen]; пусто — `x`.
String roomMediaSafeSegment(String value, int maxLen) {
  final out = StringBuffer();
  var length = 0;
  for (final rune in value.runes) {
    final isAsciiAlnum =
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A);
    final keep = isAsciiAlnum || rune == 0x2D || rune == 0x5F;
    out.writeCharCode(keep ? rune : 0x5F);
    length += 1;
    if (length >= maxLen) break;
  }
  return length == 0 ? 'x' : out.toString();
}

/// `room_media_backend_hash_suffix`: base64url без `=` от SHA-256, первые
/// [maxLen] знаков.
String roomMediaHashSuffix(String value, int maxLen) {
  final encoded = base64Url
      .encode(sha256.convert(utf8.encode(value)).bytes)
      .replaceAll('=', '');
  return encoded.length <= maxLen ? encoded : encoded.substring(0, maxLen);
}

/// Идентичность устройства [deviceId] профиля [profileId] в комнате LiveKit.
String roomMediaParticipantIdentity(String profileId, String deviceId) {
  final deviceSegment = roomMediaSafeSegment(deviceId, 18);
  final suffix = roomMediaHashSuffix('$profileId:$deviceId', 10);
  return 'secretly-participant-$deviceSegment-$suffix';
}

/// Отпечаток ключа для журнала: первые 4 байта SHA-256 в hex. Сам ключ не
/// пишется никогда.
String callKeyFingerprint(Uint8List key) {
  final digest = sha256.convert(key).bytes;
  final buf = StringBuffer();
  for (final b in digest.take(4)) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

// ── Служебные команды ──────────────────────────────────────────────────────

enum RoomCallKeyReason { join, rotate, reply }

/// Общее у обеих команд: созвон и отправитель (его идентичность в LiveKit).
sealed class RoomCallKeyCommand {
  const RoomCallKeyCommand({
    required this.roomId,
    required this.callId,
    required this.identity,
    required this.sentAtMs,
  });

  final String roomId;
  final String callId;

  /// `I(P, D)` отправителя.
  final String identity;
  final int sentAtMs;
}

/// Ключ отправителя: `room_call_key`.
final class RoomCallKeyGrant extends RoomCallKeyCommand {
  RoomCallKeyGrant({
    required super.roomId,
    required super.callId,
    required super.identity,
    required super.sentAtMs,
    required this.epoch,
    required this.keyIndex,
    required Uint8List key,
    required this.reason,
  }) : key = Uint8List.fromList(key);

  final int epoch;
  final int keyIndex;
  final Uint8List key;
  final RoomCallKeyReason reason;

  /// Не печатает ключ: в журнал может попасть только отпечаток.
  @override
  String toString() =>
      'RoomCallKeyGrant(callId: $callId, epoch: $epoch, '
      'keyIndex: $keyIndex, reason: ${reason.name}, '
      'fp: ${callKeyFingerprint(key)})';
}

/// Просьба прислать ключ: `room_call_key_request`.
final class RoomCallKeyRequest extends RoomCallKeyCommand {
  const RoomCallKeyRequest({
    required super.roomId,
    required super.callId,
    required super.identity,
    required super.sentAtMs,
    required this.want,
  });

  /// Чей ключ нужен (`I` того, кому адресована просьба).
  final String want;
}

/// Кодек команд ключей созвона. Формат как у прочих служебных команд:
/// префикс + base64url(JSON).
abstract final class RoomCallKeyCommandCodec {
  static const String prefix = '__secretly_room_call_key_v1__:';
  static const String actionKey = 'room_call_key';
  static const String actionRequest = 'room_call_key_request';

  static bool isEncodedText(String text) => text.trim().startsWith(prefix);

  static String encode(RoomCallKeyCommand command) {
    final Map<String, Object?> json = switch (command) {
      RoomCallKeyGrant g => <String, Object?>{
        'v': 1,
        'action': actionKey,
        'contract': kRoomMediaContractE2eeV1,
        'roomId': g.roomId,
        'callId': g.callId,
        'identity': g.identity,
        'epoch': g.epoch,
        'keyIndex': g.keyIndex,
        'key': base64Url.encode(g.key).replaceAll('=', ''),
        'reason': g.reason.name,
        'sentAtMs': g.sentAtMs,
      },
      RoomCallKeyRequest r => <String, Object?>{
        'v': 1,
        'action': actionRequest,
        'contract': kRoomMediaContractE2eeV1,
        'roomId': r.roomId,
        'callId': r.callId,
        'identity': r.identity,
        'want': r.want,
        'sentAtMs': r.sentAtMs,
      },
    };
    return '$prefix${base64Url.encode(utf8.encode(jsonEncode(json)))}';
  }

  /// Разбор. Всё, что не строго по формату, — `null`; ошибка не содержит
  /// содержимого команды.
  static RoomCallKeyCommand? decode(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(prefix)) return null;
    final raw = trimmed.substring(prefix.length).trim();
    if (raw.isEmpty) return null;
    final Map<String, Object?> json;
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(raw)));
      if (decoded is! Map) return null;
      json = decoded.cast<String, Object?>();
    } catch (_) {
      return null;
    }
    if (json['v'] != 1) return null;
    if (json['contract'] != kRoomMediaContractE2eeV1) return null;
    final roomId = _string(json['roomId']);
    final callId = _string(json['callId']);
    final identity = _string(json['identity']);
    final sentAtMs = _int(json['sentAtMs']);
    if (roomId.isEmpty ||
        callId.isEmpty ||
        identity.isEmpty ||
        sentAtMs == null) {
      return null;
    }
    switch (json['action']) {
      case actionKey:
        final epoch = _int(json['epoch']);
        final keyIndex = _int(json['keyIndex']);
        final reason = RoomCallKeyReason.values
            .where((r) => r.name == json['reason'])
            .firstOrNull;
        final key = _base64UrlBytes(json['key']);
        if (epoch == null ||
            keyIndex == null ||
            reason == null ||
            key == null) {
          return null;
        }
        return RoomCallKeyGrant(
          roomId: roomId,
          callId: callId,
          identity: identity,
          sentAtMs: sentAtMs,
          epoch: epoch,
          keyIndex: keyIndex,
          key: key,
          reason: reason,
        );
      case actionRequest:
        final want = _string(json['want']);
        if (want.isEmpty) return null;
        return RoomCallKeyRequest(
          roomId: roomId,
          callId: callId,
          identity: identity,
          sentAtMs: sentAtMs,
          want: want,
        );
    }
    return null;
  }

  static String _string(Object? v) => v is String ? v.trim() : '';

  static int? _int(Object? v) => v is int ? v : null;

  static Uint8List? _base64UrlBytes(Object? v) {
    if (v is! String || v.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Url.decode(base64Url.normalize(v)));
    } catch (_) {
      return null;
    }
  }
}

// ── Проверка пришедшего ключа (§4.2) ───────────────────────────────────────

enum RoomCallKeyVerdict {
  /// Принять и поставить шифратору.
  accept,

  /// Тот же ключ той же эпохи уже стоит — молча пропустить.
  duplicate,

  /// Отказ: сообщение отбрасывается, счётчик в диагностике.
  rejectNotPairwiseSender,
  rejectDeviceNotOfProfile,
  rejectNotRoomMember,
  rejectNotInCall,
  rejectIdentityMismatch,
  rejectWrongCall,
  rejectNotE2eeCall,
  rejectMalformedKey,
  rejectStaleEpoch,
  rejectEpochConflict,
  rejectClock,
  rejectRateLimited,
}

/// Что известно о созвоне, в котором мы находимся, и об отправителе. Всё
/// это — локальное знание; сервер здесь ничего не решает.
class RoomCallKeyCheckInput {
  const RoomCallKeyCheckInput({
    required this.pairwiseSenderDeviceId,
    required this.senderProfileId,
    required this.senderDeviceBelongsToProfile,
    required this.senderIsActiveRoomMember,
    required this.senderDeviceInCallSnapshot,
    required this.activeRoomId,
    required this.activeCallId,
    required this.activeCallIsE2ee,
    required this.lastEpochFromSender,
    required this.lastKeyFromSender,
    required this.grantsFromSenderLastMinute,
    required this.nowMs,
  });

  /// Устройство, от которого пришла попарная посылка (его назвало реле, и
  /// его подтвердила сессия Double Ratchet).
  final String pairwiseSenderDeviceId;
  final String senderProfileId;

  /// Устройство числится у профиля по локальному списку устройств.
  final bool senderDeviceBelongsToProfile;

  /// Профиль — действующий член комнаты: не вышел и не забанен.
  final bool senderIsActiveRoomMember;

  /// Устройство есть в снимке созвона (joined/joining/reconnecting).
  final bool senderDeviceInCallSnapshot;

  final String? activeRoomId;
  final String? activeCallId;
  final bool activeCallIsE2ee;

  /// Последняя принятая эпоха от этого отправителя в этом созвоне.
  final int? lastEpochFromSender;

  /// Ключ этой последней эпохи (для распознавания дубля).
  final Uint8List? lastKeyFromSender;

  final int grantsFromSenderLastMinute;
  final int nowMs;
}

/// Проверка `room_call_key` по всем правилам §4.2. Чистая функция.
RoomCallKeyVerdict checkRoomCallKeyGrant(
  RoomCallKeyGrant grant,
  RoomCallKeyCheckInput input,
) {
  // 1. Попарная сессия от устройства, которое реле назвало отправителем.
  final senderDeviceId = input.pairwiseSenderDeviceId.trim();
  final senderProfileId = input.senderProfileId.trim();
  if (senderDeviceId.isEmpty || senderProfileId.isEmpty) {
    return RoomCallKeyVerdict.rejectNotPairwiseSender;
  }
  // 2. Устройство профиля, профиль в комнате, устройство в созвоне.
  if (!input.senderDeviceBelongsToProfile) {
    return RoomCallKeyVerdict.rejectDeviceNotOfProfile;
  }
  if (!input.senderIsActiveRoomMember) {
    return RoomCallKeyVerdict.rejectNotRoomMember;
  }
  if (!input.senderDeviceInCallSnapshot) {
    return RoomCallKeyVerdict.rejectNotInCall;
  }
  // 3. Идентичность — функция от (P, D), а не то, что написано в сообщении.
  if (grant.identity !=
      roomMediaParticipantIdentity(senderProfileId, senderDeviceId)) {
    return RoomCallKeyVerdict.rejectIdentityMismatch;
  }
  // 4. Наш созвон, и он зашифрованный.
  if (grant.roomId != (input.activeRoomId ?? '').trim() ||
      grant.callId != (input.activeCallId ?? '').trim()) {
    return RoomCallKeyVerdict.rejectWrongCall;
  }
  if (!input.activeCallIsE2ee) {
    return RoomCallKeyVerdict.rejectNotE2eeCall;
  }
  // 5. Форма ключа и эпоха.
  if (grant.key.length != kCallKeyLength ||
      grant.keyIndex < 0 ||
      grant.keyIndex >= kCallKeyRingSize ||
      grant.epoch < 1) {
    return RoomCallKeyVerdict.rejectMalformedKey;
  }
  final lastEpoch = input.lastEpochFromSender;
  if (lastEpoch != null) {
    if (grant.epoch == lastEpoch) {
      final lastKey = input.lastKeyFromSender;
      if (lastKey != null && _constantTimeEquals(lastKey, grant.key)) {
        return RoomCallKeyVerdict.duplicate;
      }
      return RoomCallKeyVerdict.rejectEpochConflict;
    }
    if (grant.epoch < lastEpoch) {
      return RoomCallKeyVerdict.rejectStaleEpoch;
    }
  }
  // 6. Часы: ±10 минут.
  final skew = kCallKeyClockSkew.inMilliseconds;
  if (grant.sentAtMs < input.nowMs - skew ||
      grant.sentAtMs > input.nowMs + skew) {
    return RoomCallKeyVerdict.rejectClock;
  }
  // 7. Не больше 20 ключей в минуту от одного устройства.
  if (input.grantsFromSenderLastMinute >= kCallKeyMaxGrantsPerMinute) {
    return RoomCallKeyVerdict.rejectRateLimited;
  }
  return RoomCallKeyVerdict.accept;
}

/// Проверка просьбы о ключе: те же правила 1–4 и 6, плюс просят именно нас.
RoomCallKeyVerdict checkRoomCallKeyRequest(
  RoomCallKeyRequest request,
  RoomCallKeyCheckInput input, {
  required String selfIdentity,
}) {
  final senderDeviceId = input.pairwiseSenderDeviceId.trim();
  final senderProfileId = input.senderProfileId.trim();
  if (senderDeviceId.isEmpty || senderProfileId.isEmpty) {
    return RoomCallKeyVerdict.rejectNotPairwiseSender;
  }
  if (!input.senderDeviceBelongsToProfile) {
    return RoomCallKeyVerdict.rejectDeviceNotOfProfile;
  }
  if (!input.senderIsActiveRoomMember) {
    return RoomCallKeyVerdict.rejectNotRoomMember;
  }
  if (!input.senderDeviceInCallSnapshot) {
    return RoomCallKeyVerdict.rejectNotInCall;
  }
  if (request.identity !=
      roomMediaParticipantIdentity(senderProfileId, senderDeviceId)) {
    return RoomCallKeyVerdict.rejectIdentityMismatch;
  }
  if (request.roomId != (input.activeRoomId ?? '').trim() ||
      request.callId != (input.activeCallId ?? '').trim() ||
      request.want != selfIdentity) {
    return RoomCallKeyVerdict.rejectWrongCall;
  }
  if (!input.activeCallIsE2ee) {
    return RoomCallKeyVerdict.rejectNotE2eeCall;
  }
  final skew = kCallKeyClockSkew.inMilliseconds;
  if (request.sentAtMs < input.nowMs - skew ||
      request.sentAtMs > input.nowMs + skew) {
    return RoomCallKeyVerdict.rejectClock;
  }
  return RoomCallKeyVerdict.accept;
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
