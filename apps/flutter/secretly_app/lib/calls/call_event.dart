// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:secretly_app/l10n/app_localizations.dart';

import 'call_failure.dart';
import 'call_state.dart';

enum CallRecordDirection {
  incoming('incoming'),
  outgoing('outgoing');

  const CallRecordDirection(this.value);
  final String value;

  static CallRecordDirection fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'incoming':
        return CallRecordDirection.incoming;
      case 'outgoing':
      default:
        return CallRecordDirection.outgoing;
    }
  }
}

enum CallRecordScope {
  oneToOne('one_to_one'),
  room('room'),
  group('group');

  const CallRecordScope(this.value);
  final String value;

  static CallRecordScope fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'room':
        return CallRecordScope.room;
      case 'group':
        return CallRecordScope.group;
      case 'one_to_one':
      default:
        return CallRecordScope.oneToOne;
    }
  }
}

enum CallRecordMediaType {
  audio('audio'),
  video('video'),
  audioVideo('audio_video'),
  screenShare('screen_share');

  const CallRecordMediaType(this.value);
  final String value;

  static CallRecordMediaType fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'video':
        return CallRecordMediaType.video;
      case 'audio_video':
        return CallRecordMediaType.audioVideo;
      case 'screen_share':
        return CallRecordMediaType.screenShare;
      case 'audio':
      default:
        return CallRecordMediaType.audio;
    }
  }
}

enum CallRecordResult {
  completed('completed'),
  missed('missed'),
  declined('declined'),
  busy('busy'),
  failed('failed'),
  canceled('canceled'),
  ongoing('ongoing');

  const CallRecordResult(this.value);
  final String value;

  static CallRecordResult fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'missed':
        return CallRecordResult.missed;
      case 'declined':
        return CallRecordResult.declined;
      case 'busy':
        return CallRecordResult.busy;
      case 'failed':
        return CallRecordResult.failed;
      case 'canceled':
        return CallRecordResult.canceled;
      case 'ongoing':
        return CallRecordResult.ongoing;
      case 'completed':
      default:
        return CallRecordResult.completed;
    }
  }
}

CallRecordMediaType callRecordMediaTypeFromFlags({
  required bool isVideo,
  required bool hadScreenShare,
}) {
  if (hadScreenShare) return CallRecordMediaType.screenShare;
  return isVideo ? CallRecordMediaType.video : CallRecordMediaType.audio;
}

CallRecordResult callRecordResultFromEndReason({
  required CallEndReason reason,
  required bool didConnect,
  required CallRecordDirection direction,
}) {
  switch (reason) {
    case CallEndReason.localHangup:
    case CallEndReason.remoteHangup:
      if (didConnect) return CallRecordResult.completed;
      // 🔴 ЧЬЯ ЭТО ЛЕНТА (07.08.2026, поле: «после входа в приложение есть
      // пузырь о "Отменённом звонке", а не пропущенном»).
      //
      // Отменить звонок может только тот, кто звонил. Для получателя тот же
      // самый обрыв означает ровно противоположное: он звонок ПРОПУСТИЛ.
      // Раньше здесь возвращалось `canceled` независимо от направления, то
      // есть в ленту получателя подставлялась точка зрения звонившего.
      // Signal и WhatsApp в этом месте тоже пишут «Пропущенный».
      //
      // Осознанный отказ сюда не попадает: у «Отклонить» свои причины
      // `localDecline`/`remoteDecline` ниже, и он остаётся «Отклонённым».
      // Ровно поэтому проверка идёт по НАПРАВЛЕНИЮ, а не по тому, чей был
      // отбой: входящий без соединения — пропущен, кто бы его ни оборвал.
      return direction == CallRecordDirection.incoming
          ? CallRecordResult.missed
          : CallRecordResult.canceled;
    case CallEndReason.remoteSuperseded:
      return CallRecordResult.failed;
    case CallEndReason.remoteDecline:
    case CallEndReason.localDecline:
      return CallRecordResult.declined;
    case CallEndReason.timeout:
      return direction == CallRecordDirection.incoming
          ? CallRecordResult.missed
          : CallRecordResult.failed;
    case CallEndReason.error:
      return CallRecordResult.failed;
  }
}

String callRecordResultLabel(
  CallRecordResult result, {
  AppLocalizations? l10n,
  required bool isRu,
  required CallRecordDirection direction,
  required bool isVideo,
}) {
  if (l10n != null) {
    switch (result) {
      case CallRecordResult.completed:
        if (direction == CallRecordDirection.outgoing) {
          return isVideo
              ? l10n.callRecordOutgoingVideoCall
              : l10n.callRecordOutgoingCall;
        }
        return isVideo
            ? l10n.callRecordIncomingVideoCall
            : l10n.callRecordIncomingCall;
      case CallRecordResult.missed:
        return l10n.callRecordMissedCall;
      case CallRecordResult.declined:
        return l10n.callRecordDeclinedCall;
      case CallRecordResult.busy:
        return l10n.callRecordBusy;
      case CallRecordResult.failed:
        return l10n.callRecordFailed;
      case CallRecordResult.canceled:
        return l10n.callRecordCanceled;
      case CallRecordResult.ongoing:
        return l10n.callRecordOngoing;
    }
  }
  switch (result) {
    case CallRecordResult.completed:
      if (isRu) {
        if (direction == CallRecordDirection.outgoing) {
          return isVideo ? 'Исходящий видеозвонок' : 'Исходящий звонок';
        }
        return isVideo ? 'Входящий видеозвонок' : 'Входящий звонок';
      }
      if (direction == CallRecordDirection.outgoing) {
        return isVideo ? 'Outgoing video call' : 'Outgoing call';
      }
      return isVideo ? 'Incoming video call' : 'Incoming call';
    case CallRecordResult.missed:
      if (isRu) return 'Пропущенный звонок';
      return 'Missed call';
    case CallRecordResult.declined:
      if (isRu) return 'Отклонённый звонок';
      return 'Call declined';
    case CallRecordResult.busy:
      if (isRu) return 'Абонент занят';
      return 'Busy';
    case CallRecordResult.failed:
      if (isRu) return 'Ошибка связи';
      return 'Call failed';
    case CallRecordResult.canceled:
      if (isRu) return 'Отменённый звонок';
      return 'Call canceled';
    case CallRecordResult.ongoing:
      if (isRu) return 'Идёт звонок';
      return 'Ongoing call';
  }
}

String formatCallDurationShort(int durationMs) {
  final totalSeconds = (durationMs / 1000).floor().clamp(0, 360000);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String buildCallEventPreviewText({
  AppLocalizations? l10n,
  required bool isRu,
  required CallRecordResult result,
  required CallRecordDirection direction,
  required bool isVideo,
  required int durationMs,
}) {
  final label = callRecordResultLabel(
    result,
    l10n: l10n,
    isRu: isRu,
    direction: direction,
    isVideo: isVideo,
  );
  if (result == CallRecordResult.completed && durationMs > 0) {
    return '$label · ${formatCallDurationShort(durationMs)}';
  }
  return label;
}

class CallJournalEntry {
  const CallJournalEntry({
    required this.callId,
    required this.callAttemptId,
    required this.convoId,
    required this.peerProfileId,
    required this.direction,
    required this.scope,
    required this.mediaType,
    required this.result,
    required this.startedAtMs,
    required this.connectedAtMs,
    required this.endedAtMs,
    required this.durationMs,
    required this.endReason,
    this.failureCode,
    required this.peerDisplayName,
    required this.peerAvatarPath,
    required this.didConnect,
    required this.hadVideo,
    required this.hadScreenShare,
    required this.qualitySummaryJson,
    required this.createdLocalEventId,
    required this.syncedChatEventId,
    required this.acknowledgedAtMs,
  });

  final String callId;
  final String callAttemptId;
  final String convoId;
  final String peerProfileId;
  final CallRecordDirection direction;
  final CallRecordScope scope;
  final CallRecordMediaType mediaType;
  final CallRecordResult result;
  final int startedAtMs;
  final int? connectedAtMs;
  final int endedAtMs;
  final int durationMs;
  final String? endReason;
  final CallFailureCode? failureCode;
  final String? peerDisplayName;
  final String? peerAvatarPath;
  final bool didConnect;
  final bool hadVideo;
  final bool hadScreenShare;
  final String? qualitySummaryJson;
  final String? createdLocalEventId;
  final String? syncedChatEventId;
  final int? acknowledgedAtMs;

  bool get isVideoLike =>
      mediaType == CallRecordMediaType.video ||
      mediaType == CallRecordMediaType.audioVideo ||
      mediaType == CallRecordMediaType.screenShare;

  bool get isAcknowledged => (acknowledgedAtMs ?? 0) > 0;

  CallEndReason? get endReasonValue => parseCallEndReason(endReason);

  static CallJournalEntry fromDbRow(Map<String, Object?> row) {
    int asInt(String key) => ((row[key] as num?) ?? 0).toInt();
    int? asNullableInt(String key) => (row[key] as num?)?.toInt();
    bool asBool(String key) => ((row[key] as num?)?.toInt() ?? 0) != 0;
    String asString(String key) => ((row[key] as String?) ?? '').trim();
    String? asNullableString(String key) {
      final value = ((row[key] as String?) ?? '').trim();
      return value.isEmpty ? null : value;
    }

    return CallJournalEntry(
      callId: asString('call_id'),
      callAttemptId: asString('call_attempt_id'),
      convoId: asString('convo_id'),
      peerProfileId: asString('peer_profile_id'),
      direction: CallRecordDirection.fromValue(asString('direction')),
      scope: CallRecordScope.fromValue(asString('scope')),
      mediaType: CallRecordMediaType.fromValue(asString('media_type')),
      result: CallRecordResult.fromValue(asString('result')),
      startedAtMs: asInt('started_at_ms'),
      connectedAtMs: asNullableInt('connected_at_ms'),
      endedAtMs: asInt('ended_at_ms'),
      durationMs: asInt('duration_ms'),
      endReason: asNullableString('end_reason'),
      failureCode: parseCallFailureCode(asNullableString('failure_code')),
      peerDisplayName: asNullableString('peer_display_name'),
      peerAvatarPath: asNullableString('peer_avatar_path'),
      didConnect: asBool('did_connect'),
      hadVideo: asBool('had_video'),
      hadScreenShare: asBool('had_screen_share'),
      qualitySummaryJson: asNullableString('quality_summary_json'),
      createdLocalEventId: asNullableString('created_local_event_id'),
      syncedChatEventId: asNullableString('synced_chat_event_id'),
      acknowledgedAtMs: asNullableInt('acknowledged_at_ms'),
    );
  }

  Map<String, Object?> toDbMap({
    required int nowMs,
    int? createdAtMs,
    int? acknowledgedAtMs,
  }) => {
    'call_id': callId,
    'call_attempt_id': callAttemptId,
    'convo_id': convoId,
    'peer_profile_id': peerProfileId,
    'direction': direction.value,
    'scope': scope.value,
    'media_type': mediaType.value,
    'result': result.value,
    'started_at_ms': startedAtMs,
    'connected_at_ms': connectedAtMs,
    'ended_at_ms': endedAtMs,
    'duration_ms': durationMs,
    'end_reason': endReason,
    'failure_code': failureCode?.name,
    'peer_display_name': peerDisplayName,
    'peer_avatar_path': peerAvatarPath,
    'did_connect': didConnect ? 1 : 0,
    'had_video': hadVideo ? 1 : 0,
    'had_screen_share': hadScreenShare ? 1 : 0,
    'quality_summary_json': qualitySummaryJson,
    'created_local_event_id': createdLocalEventId,
    'synced_chat_event_id': syncedChatEventId,
    'acknowledged_at_ms': acknowledgedAtMs ?? this.acknowledgedAtMs,
    'created_at_ms': createdAtMs ?? nowMs,
    'updated_at_ms': nowMs,
  };
}
