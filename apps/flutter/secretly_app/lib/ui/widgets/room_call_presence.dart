// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../rooms/room_call_state.dart';
import '../icons/app_icons.dart';
import '../wave1_l10n.dart';

String _presenceText(
  BuildContext context, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}

String formatRoomCallPresenceText(
  BuildContext context,
  CachedRoomCall? call, {
  required String inactiveLabel,
}) {
  if (call == null || !call.isActive) {
    return inactiveLabel;
  }
  final joinedCount = call.joinedParticipantCount;
  final selfJoined = call.selfParticipant?.isJoined ?? false;
  final selfReconnecting = call.selfParticipant?.isReconnecting ?? false;
  final isVideo = call.mediaType == 'video';
  if (selfReconnecting) {
    return isVideo
        ? _presenceText(
            context,
            ru: 'Переподключение к видеозвонку • $joinedCount в звонке',
            en: 'Reconnecting to video room call • $joinedCount in call',
            uk: 'Перепідключення до відеодзвінка • $joinedCount у дзвінку',
            es: 'Reconectando a la videollamada de sala • $joinedCount en llamada',
            pt: 'A reconectar a chamada de video da sala • $joinedCount na chamada',
            ptBr:
                'Reconectando a chamada de video da sala • $joinedCount na chamada',
            fr: 'Reconnexion a l appel video du salon • $joinedCount en appel',
            de: 'Verbindung zum Video-Raumanruf wird wiederhergestellt • $joinedCount im Anruf',
          )
        : _presenceText(
            context,
            ru: 'Переподключение к голосовому звонку • $joinedCount в звонке',
            en: 'Reconnecting to voice room call • $joinedCount in call',
            uk: 'Перепідключення до голосового дзвінка • $joinedCount у дзвінку',
            es: 'Reconectando a la llamada de voz de sala • $joinedCount en llamada',
            pt: 'A reconectar a chamada de voz da sala • $joinedCount na chamada',
            ptBr:
                'Reconectando a chamada de voz da sala • $joinedCount na chamada',
            fr: 'Reconnexion a l appel vocal du salon • $joinedCount en appel',
            de: 'Verbindung zum Sprach-Raumanruf wird wiederhergestellt • $joinedCount im Anruf',
          );
  }
  if (selfJoined) {
    return isVideo
        ? _presenceText(
            context,
            ru: 'Вы в активном видеозвонке • $joinedCount в звонке',
            en: 'You are in the active video room call • $joinedCount in call',
            uk: 'Ви в активному відеодзвінку • $joinedCount у дзвінку',
            es: 'Estas en la videollamada de sala activa • $joinedCount en llamada',
            pt: 'Esta na chamada de video ativa da sala • $joinedCount na chamada',
            ptBr:
                'Voce esta na chamada de video ativa da sala • $joinedCount na chamada',
            fr: 'Vous etes dans l appel video actif du salon • $joinedCount en appel',
            de: 'Du bist im aktiven Video-Raumanruf • $joinedCount im Anruf',
          )
        : _presenceText(
            context,
            ru: 'Вы в активном голосовом звонке • $joinedCount в звонке',
            en: 'You are in the active voice room call • $joinedCount in call',
            uk: 'Ви в активному голосовому дзвінку • $joinedCount у дзвінку',
            es: 'Estas en la llamada de voz de sala activa • $joinedCount en llamada',
            pt: 'Esta na chamada de voz ativa da sala • $joinedCount na chamada',
            ptBr:
                'Voce esta na chamada de voz ativa da sala • $joinedCount na chamada',
            fr: 'Vous etes dans l appel vocal actif du salon • $joinedCount en appel',
            de: 'Du bist im aktiven Sprach-Raumanruf • $joinedCount im Anruf',
          );
  }
  return isVideo
      ? _presenceText(
          context,
          ru: 'Активный видеозвонок • $joinedCount в звонке',
          en: 'Active video room call • $joinedCount in call',
          uk: 'Активний відеодзвінок • $joinedCount у дзвінку',
          es: 'Videollamada de sala activa • $joinedCount en llamada',
          pt: 'Chamada de video ativa da sala • $joinedCount na chamada',
          fr: 'Appel video actif du salon • $joinedCount en appel',
          de: 'Aktiver Video-Raumanruf • $joinedCount im Anruf',
        )
      : _presenceText(
          context,
          ru: 'Активный голосовой звонок • $joinedCount в звонке',
          en: 'Active voice room call • $joinedCount in call',
          uk: 'Активний голосовий дзвінок • $joinedCount у дзвінку',
          es: 'Llamada de voz de sala activa • $joinedCount en llamada',
          pt: 'Chamada de voz ativa da sala • $joinedCount na chamada',
          fr: 'Appel vocal actif du salon • $joinedCount en appel',
          de: 'Aktiver Sprach-Raumanruf • $joinedCount im Anruf',
        );
}

String roomCallPresenceHeadline(BuildContext context, CachedRoomCall call) {
  final selfJoined = call.selfParticipant?.isJoined ?? false;
  final selfReconnecting = call.selfParticipant?.isReconnecting ?? false;
  if (selfReconnecting) {
    return _presenceText(
      context,
      ru: 'Звонок восстанавливается',
      en: 'Room call is reconnecting',
      uk: 'Дзвінок відновлюється',
      es: 'La llamada de sala se esta reconectando',
      pt: 'A chamada da sala esta a reconectar',
      ptBr: 'A chamada da sala esta reconectando',
      fr: 'L appel du salon se reconnecte',
      de: 'Raum-Anruf verbindet sich neu',
    );
  }
  if (selfJoined) {
    return _presenceText(
      context,
      ru: 'Вы уже в звонке комнаты',
      en: 'You are already in the room call',
      uk: 'Ви вже у дзвінку кімнати',
      es: 'Ya estas en la llamada de sala',
      pt: 'Ja esta na chamada da sala',
      ptBr: 'Voce ja esta na chamada da sala',
      fr: 'Vous etes deja dans l appel du salon',
      de: 'Du bist bereits im Raum-Anruf',
    );
  }
  return _presenceText(
    context,
    ru: 'В комнате активный звонок',
    en: 'Room call is active',
    uk: 'У кімнаті активний дзвінок',
    es: 'La llamada de sala esta activa',
    pt: 'A chamada da sala esta ativa',
    fr: 'L appel du salon est actif',
    de: 'Raum-Anruf ist aktiv',
  );
}

String roomCallPresenceActionLabel(BuildContext context, CachedRoomCall call) {
  if (call.selfParticipant?.isJoined ?? false) {
    return _presenceText(
      context,
      ru: 'Вернуться к звонку',
      en: 'Return to call',
    );
  }
  return _presenceText(context, ru: 'Присоединиться к звонку', en: 'Join call');
}

Color roomCallPresenceAccent(CachedRoomCall call, ColorScheme colorScheme) {
  return call.selfParticipant?.isReconnecting ?? false
      ? const Color(0xFFE67E22)
      : colorScheme.primary;
}

class RoomCallPresenceCard extends StatelessWidget {
  const RoomCallPresenceCard({super.key, required this.call, this.onTap});

  final CachedRoomCall call;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = roomCallPresenceAccent(call, cs);
    final callIcon = call.mediaType == 'video'
        ? AppIcons.video
        : AppIcons.callAlt;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            cs.surfaceContainerHigh.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(callIcon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomCallPresenceHeadline(context, call),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRoomCallPresenceText(
                        context,
                        call,
                        inactiveLabel: _presenceText(
                          context,
                          ru: 'Комната',
                          en: 'Room',
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onTap,
              icon: Icon(callIcon, size: 16),
              label: Text(roomCallPresenceActionLabel(context, call)),
            ),
          ],
        ],
      ),
    );
  }
}
