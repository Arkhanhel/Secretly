// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// 🔴 ЗАХВАТ ВКЛЮЧАЕТ ТОЛЬКО ЧЕЛОВЕК (ТЗ E2EE созвонов, ЗР-10, 06.10.2026).
///
/// Медиа созвона повторяет снимок реле: флаги `publishAudio`/`publishVideo`/
/// `publishScreenShare` считает сервер. До этой правки клиент включал по ним
/// микрофон и камеру как есть — то есть сервер мог включить микрофон
/// человеку, который его выключил. Вместе с «призрачным» участником это
/// подслушивание даже при сквозном шифровании.
///
/// Теперь включённым может быть только то, что человек включил сам:
/// `публиковать = реле_разрешает && человек_хочет`. Реле по-прежнему может
/// выключить (так работает модерация), но включить — нет.
///
/// Чего человек хочет, видно по его действиям: [RoomCallCaptureIntent.merge]
/// берёт из запроса только те поля, которые запрос МЕНЯЕТ относительно
/// текущего снимка. Поля, просто повторённые из снимка (экраны собирают
/// запрос из `selfParticipant`), желание не трогают — иначе подменённый
/// снимок протекал бы в желание при любом другом нажатии.
///
/// Нет записанного желания (например, созвон восстановлен после перезапуска)
/// — фильтр не применяется, и всё ровно как было.
library;

import '../transport/relay_client.dart';

/// Чего хочет человек: что из захвата включено им самим.
class RoomCallCaptureIntent {
  const RoomCallCaptureIntent({
    required this.callId,
    required this.audio,
    required this.video,
    required this.screenShare,
  });

  /// Созвон, к которому относится желание; пусто — ещё не известен (вход).
  final String callId;
  final bool audio;
  final bool video;
  final bool screenShare;

  /// Желание при входе: берётся целиком, это выбор человека на экране входа.
  factory RoomCallCaptureIntent.fromJoin({
    required bool muted,
    required bool deafened,
    required bool videoEnabled,
    required bool screenShareEnabled,
  }) => RoomCallCaptureIntent(
    callId: '',
    audio: !muted && !deafened,
    video: videoEnabled,
    screenShare: screenShareEnabled,
  );

  RoomCallCaptureIntent withCallId(String value) => RoomCallCaptureIntent(
    callId: value.trim(),
    audio: audio,
    video: video,
    screenShare: screenShare,
  );

  /// Новое желание после запроса «изменить своё состояние».
  ///
  /// [previous] — прежнее желание (может не быть); [relayNow] — своё
  /// состояние в текущем снимке реле (может не быть). Поле запроса берётся,
  /// только если оно отличается от снимка (человек нажал) или сравнивать не
  /// с чем.
  static RoomCallCaptureIntent merge({
    required String callId,
    required RoomCallCaptureIntent? previous,
    required ({
      bool muted,
      bool deafened,
      bool videoEnabled,
      bool screenShareEnabled,
    })?
    relayNow,
    required bool muted,
    required bool deafened,
    required bool videoEnabled,
    required bool screenShareEnabled,
  }) {
    final requestedAudio = !muted && !deafened;
    final prev = previous != null && previous.matchesCall(callId)
        ? previous
        : null;
    if (prev == null || relayNow == null) {
      return RoomCallCaptureIntent(
        callId: callId.trim(),
        audio: requestedAudio,
        video: videoEnabled,
        screenShare: screenShareEnabled,
      );
    }
    final relayAudio = !relayNow.muted && !relayNow.deafened;
    return RoomCallCaptureIntent(
      callId: callId.trim(),
      audio: requestedAudio != relayAudio ? requestedAudio : prev.audio,
      video: videoEnabled != relayNow.videoEnabled ? videoEnabled : prev.video,
      screenShare: screenShareEnabled != relayNow.screenShareEnabled
          ? screenShareEnabled
          : prev.screenShare,
    );
  }

  /// Относится ли желание к созвону [value]. Желание с входа (без callId)
  /// относится к первому созвону, в который вошли.
  bool matchesCall(String value) => callId.isEmpty || callId == value.trim();

  @override
  bool operator ==(Object other) =>
      other is RoomCallCaptureIntent &&
      other.callId == callId &&
      other.audio == audio &&
      other.video == video &&
      other.screenShare == screenShare;

  @override
  int get hashCode => Object.hash(callId, audio, video, screenShare);

  @override
  String toString() =>
      'RoomCallCaptureIntent(call: $callId, audio: $audio, video: $video, '
      'screen: $screenShare)';
}

/// Сессия медиа, в которой собственные флаги публикации урезаны желанием
/// человека: реле может только выключить. Нет желания или оно про другой
/// созвон — сессия возвращается как есть.
RelayRoomCallMediaSession applyRoomCallCaptureIntent(
  RelayRoomCallMediaSession session,
  RoomCallCaptureIntent? intent,
) {
  if (intent == null || !intent.matchesCall(session.callId)) return session;
  final self = session.selfParticipant;
  if (self == null) return session;
  final audio = self.publishAudio && intent.audio;
  final video = self.publishVideo && intent.video;
  final screen = self.publishScreenShare && intent.screenShare;
  if (audio == self.publishAudio &&
      video == self.publishVideo &&
      screen == self.publishScreenShare) {
    return session;
  }
  final participants = session.participants
      .map(
        (p) => p.isSelf
            ? RelayRoomCallMediaParticipant(
                profileId: p.profileId,
                deviceId: p.deviceId,
                joinState: p.joinState,
                isSelf: p.isSelf,
                supportsVideo: p.supportsVideo,
                supportsScreenShare: p.supportsScreenShare,
                muted: p.muted,
                deafened: p.deafened,
                videoEnabled: p.videoEnabled,
                screenShareEnabled: p.screenShareEnabled,
                speaking: p.speaking,
                publishAudio: audio,
                publishVideo: video,
                publishScreenShare: screen,
                receiveAudio: p.receiveAudio,
                receiveVideo: p.receiveVideo,
                receiveScreenShare: p.receiveScreenShare,
                updatedAtMs: p.updatedAtMs,
                e2eeCapable: p.e2eeCapable,
              )
            : p,
      )
      .toList(growable: false);
  return RelayRoomCallMediaSession(
    roomId: session.roomId,
    callId: session.callId,
    sessionId: session.sessionId,
    contractVersion: session.contractVersion,
    topology: session.topology,
    capabilityState: session.capabilityState,
    mediaType: session.mediaType,
    stateVersion: session.stateVersion,
    selfProfileId: session.selfProfileId,
    selfDeviceId: session.selfDeviceId,
    participantCount: session.participantCount,
    publishVideoSupported: session.publishVideoSupported,
    publishScreenShareSupported: session.publishScreenShareSupported,
    subscribeAllSupported: session.subscribeAllSupported,
    backend: session.backend,
    signal: session.signal,
    ice: session.ice,
    participants: participants,
  );
}
