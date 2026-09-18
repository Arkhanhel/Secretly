// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../calls/call_manager.dart';
import '../../calls/call_state.dart';
import '../wave1_l10n.dart';
import 'room_call_return_banner.dart';

class CallReturnBanner extends StatelessWidget {
  const CallReturnBanner({
    super.key,
    this.margin = EdgeInsets.zero,
    this.merged = false,
  });

  final EdgeInsets margin;

  /// Bare 38px row for a FrostedIslandRowGroup (ISLAND GROUP 2026-07-17).
  final bool merged;

  @override
  Widget build(BuildContext context) {
    final manager = CallManager.instance;
    if (manager == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<CallState>(
      valueListenable: manager.state,
      builder: (context, state, _) {
        if (!state.isActive || !state.isUiMinimized) {
          return const SizedBox.shrink();
        }

        final incoming = state.phase == CallPhase.ringingIncoming;
        final peerName = state.peerName.trim();
        // К-8: имя может не разрешиться (звонок с незнакомого устройства). Тогда
        // НЕ «неизвестно», а честное «Входящий звонок».
        final title = peerName.isNotEmpty
            ? peerName
            : incoming
            ? wave1Text(
                context,
                ru: 'Входящий звонок',
                en: 'Incoming call',
                uk: 'Вхідний дзвінок',
                es: 'Llamada entrante',
                pt: 'Chamada recebida',
                ptBr: 'Chamada recebida',
                fr: 'Appel entrant',
                de: 'Eingehender Anruf',
              )
            : wave1Text(context, ru: 'Звонок', en: 'Call');
        final participantCount = switch (state.phase) {
          CallPhase.ringingOutgoing || CallPhase.ringingIncoming => 1,
          _ => 2,
        };
        final statusText = switch (state.phase) {
          CallPhase.ringingOutgoing => wave1Text(
            context,
            ru: 'Звоним...',
            en: 'Calling...',
            uk: 'Дзвонимо...',
            es: 'Llamando...',
            pt: 'A chamar...',
            ptBr: 'Chamando...',
            fr: 'Appel...',
            de: 'Anruf...',
          ),
          CallPhase.ringingIncoming => wave1Text(
            context,
            ru: 'Входящий звонок',
            en: 'Incoming call',
            uk: 'Вхідний дзвінок',
            es: 'Llamada entrante',
            pt: 'Chamada recebida',
            ptBr: 'Chamada recebida',
            fr: 'Appel entrant',
            de: 'Eingehender Anruf',
          ),
          CallPhase.connecting => wave1Text(
            context,
            ru: 'Подключение...',
            en: 'Connecting...',
            uk: 'Підключення...',
            es: 'Conectando...',
            pt: 'A ligar...',
            ptBr: 'Conectando...',
            fr: 'Connexion...',
            de: 'Verbindung...',
          ),
          _ => null,
        };

        return RoomCallReturnBanner(
          title: title,
          mediaType: state.isVideo ? 'video' : 'audio',
          joinedCount: participantCount,
          selfReconnecting: state.phase == CallPhase.reconnecting,
          selfSpeaking: false,
          selfMuted: state.isMuted,
          statusText: statusText,
          margin: margin,
          merged: merged,
          incoming: incoming,
          onTap: manager.resumeCallUi,
          onMicTap: () => unawaited(manager.toggleMute()),
          onDeclineTap: incoming
              ? () => unawaited(manager.declineIncoming())
              : null,
        );
      },
    );
  }
}
