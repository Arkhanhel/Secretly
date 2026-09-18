// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../rooms/room_call_manager.dart';
import '../../rooms/room_call_media_state.dart';
import '../../rooms/room_call_state.dart';
import '../wave1_l10n.dart';

class ResolvedRoomCallReturnBannerState {
  const ResolvedRoomCallReturnBannerState({
    required this.joinedCount,
    required this.selfReconnecting,
    required this.selfSpeaking,
    required this.selfMuted,
  });

  final int joinedCount;
  final bool selfReconnecting;
  final bool selfSpeaking;
  final bool selfMuted;
}

ResolvedRoomCallReturnBannerState resolveRoomCallReturnBannerState(
  CachedRoomCall call, {
  RoomCallRuntimeState? runtimeState,
}) {
  var joinedCount = call.joinedParticipantCount;
  var selfReconnecting = call.selfParticipant?.isReconnecting ?? false;
  var runtimeJoinedCount = 0;
  var runtimeSelfReconnecting = false;

  if (runtimeState != null &&
      runtimeState.matches(roomId: call.roomId, callId: call.callId)) {
    for (final participant in runtimeState.participants) {
      if (participant.isJoined) {
        runtimeJoinedCount += 1;
      }
      if (participant.isSelf && participant.isReconnecting) {
        runtimeSelfReconnecting = true;
      }
    }
    if (runtimeJoinedCount > 0) {
      joinedCount = runtimeJoinedCount;
    }
    if (runtimeSelfReconnecting ||
        runtimeState.localMedia.runtimeReconnecting) {
      selfReconnecting = true;
    }
  }

  return ResolvedRoomCallReturnBannerState(
    joinedCount: joinedCount,
    selfReconnecting: selfReconnecting,
    selfSpeaking: call.selfParticipant?.speaking ?? false,
    selfMuted: call.selfParticipant?.muted ?? false,
  );
}

class RuntimeAwareRoomCallReturnBanner extends StatelessWidget {
  const RuntimeAwareRoomCallReturnBanner({
    super.key,
    required this.title,
    required this.call,
    required this.onTap,
    this.onMicTap,
    this.incoming = false,
    this.onDeclineTap,
    this.statusText,
    this.margin = EdgeInsets.zero,
    this.merged = false,
  });

  /// Bare fixed-height row for a FrostedIslandRowGroup: no own margin or
  /// rounded corners (the group clips the outer radius; inner seams stay
  /// square) — ISLAND GROUP 2026-07-17.
  final bool merged;

  final String title;
  final CachedRoomCall call;
  final VoidCallback onTap;
  final VoidCallback? onMicTap;

  /// 🔴 ВХОДЯЩИЙ ЗВОНОК (13.08.2026). Островок обязан быть виден с первой
  /// секунды — он же и страховка: если человек случайно свернул или потерял
  /// экран звонка, вернуться можно только через него.
  ///
  /// Ярко-голубой, и справа вместо микрофона — красное отклонение: пока звонок
  /// не принят, глушить микрофон бессмысленно, а сбросить нужно одним касанием.
  /// После принятия островок становится прежним зелёным с теми же кнопками.
  final bool incoming;
  final VoidCallback? onDeclineTap;
  final String? statusText;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final manager = RoomCallManager.instance;
    if (manager == null) {
      return _buildBanner();
    }
    return ValueListenableBuilder<RoomCallRuntimeState>(
      valueListenable: manager.state,
      builder: (context, runtimeState, _) {
        return _buildBanner(runtimeState: runtimeState);
      },
    );
  }

  Widget _buildBanner({RoomCallRuntimeState? runtimeState}) {
    final resolved = resolveRoomCallReturnBannerState(
      call,
      runtimeState: runtimeState,
    );
    return RoomCallReturnBanner(
      title: title,
      mediaType: call.mediaType,
      joinedCount: resolved.joinedCount,
      selfReconnecting: resolved.selfReconnecting,
      selfSpeaking: resolved.selfSpeaking,
      selfMuted: resolved.selfMuted,
      onTap: onTap,
      onMicTap: onMicTap,
      incoming: incoming,
      onDeclineTap: onDeclineTap,
      statusText: statusText,
      margin: margin,
    );
  }
}

class RoomCallReturnBanner extends StatelessWidget {
  const RoomCallReturnBanner({
    super.key,
    required this.title,
    required this.mediaType,
    required this.joinedCount,
    required this.selfReconnecting,
    required this.selfSpeaking,
    required this.onTap,
    this.selfMuted = false,
    this.onMicTap,
    this.incoming = false,
    this.onDeclineTap,
    this.statusText,
    this.margin = EdgeInsets.zero,
    this.merged = false,
  });

  /// Bare fixed-height row for a FrostedIslandRowGroup: no own margin or
  /// rounded corners (the group clips the outer radius; inner seams stay
  /// square) — ISLAND GROUP 2026-07-17.
  final bool merged;

  final String title;
  final String mediaType;
  final int joinedCount;
  final bool selfReconnecting;
  final bool selfSpeaking;
  final bool selfMuted;
  final VoidCallback onTap;
  final VoidCallback? onMicTap;

  /// 🔴 ВХОДЯЩИЙ ЗВОНОК (13.08.2026). Островок обязан быть виден с первой
  /// секунды — он же и страховка: если человек случайно свернул или потерял
  /// экран звонка, вернуться можно только через него.
  ///
  /// Ярко-голубой, и справа вместо микрофона — красное отклонение: пока звонок
  /// не принят, глушить микрофон бессмысленно, а сбросить нужно одним касанием.
  /// После принятия островок становится прежним зелёным с теми же кнопками.
  final bool incoming;
  final VoidCallback? onDeclineTap;
  final String? statusText;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';
    final Color background = incoming
        ? const Color(0xFF29B6F6)
        : selfReconnecting
        ? const Color(0xFFE67E22)
        : selfMuted
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF2FA66A);
    final effectiveStatusText =
        statusText ??
        (selfReconnecting
            ? wave1Text(
                context,
                ru: 'Переподключение...',
                en: 'Reconnecting...',
                uk: 'Перепідключення...',
                es: 'Reconectando...',
                pt: 'A reconectar...',
                ptBr: 'Reconectando...',
                fr: 'Reconnexion...',
                de: 'Neu verbinden...',
              )
            : selfSpeaking
            ? wave1Text(
                context,
                ru: 'Вы в эфире • $joinedCount',
                en: 'You are live • $joinedCount',
                uk: 'Ви в ефірі • $joinedCount',
                es: 'Estas en directo • $joinedCount',
                pt: 'Esta ao vivo • $joinedCount',
                ptBr: 'Voce esta ao vivo • $joinedCount',
                fr: 'Vous etes en direct • $joinedCount',
                de: 'Du bist live • $joinedCount',
              )
            : isVideo
            ? wave1Text(
                context,
                ru: 'Видео • $joinedCount в звонке',
                en: 'Video • $joinedCount in call',
                uk: 'Відео • $joinedCount у дзвінку',
                es: 'Video • $joinedCount en llamada',
                pt: 'Video • $joinedCount na chamada',
                fr: 'Video • $joinedCount en appel',
                de: 'Video • $joinedCount im Anruf',
              )
            : wave1Text(
                context,
                ru: 'Голос • $joinedCount в звонке',
                en: 'Voice • $joinedCount in call',
                uk: 'Голос • $joinedCount у дзвінку',
                es: 'Voz • $joinedCount en llamada',
                pt: 'Voz • $joinedCount na chamada',
                fr: 'Voix • $joinedCount en appel',
                de: 'Sprache • $joinedCount im Anruf',
              ));

    final BorderRadius? pillRadius = merged
        ? null
        : BorderRadius.circular(16);
    final banner = Padding(
      padding: merged ? EdgeInsets.zero : margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Fully rounded pill on all four corners — this floats under the
          // header like the app's other islands, it is not glued to the top
          // bar, so a flat top edge read as a visual bug. In merged mode the
          // enclosing island group owns the clip and the seams are square.
          borderRadius: pillRadius,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: pillRadius,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: merged ? 0 : 5,
            ),
            child: Row(
              children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title • $effectiveStatusText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (incoming)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDeclineTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMicTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        selfMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!merged) return banner;
    // Merged: the enclosing FrostedIslandRowGroup sizes the row (the call row
    // is deliberately slimmer than the music row), so do NOT pin a height here
    // — a hard 38 would overflow the group's slimmer slot.
    return SizedBox.expand(child: banner);
  }
}
