// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../calls/call_state.dart';
import '../../../l10n/app_localizations.dart';

/// Подпись собеседника в звонке — без сырого `profile_id` (17.09.2026).
///
/// Имя подтягивается из контакта или метаданных профиля, и до того (или у
/// незнакомца) оно пустое. Компьютер подставлял туда `profile_id`, и человек
/// видел «3XBC-F5DJ-…». Как на телефоне (`34e0a83a`): пустое имя — «Входящий
/// звонок», пока звонят, и «Звонок» во время разговора. Строки — из общих
/// переводов, новых захардкоженных не добавляется.
///
/// [preferred] — имя, известное вызывающему лучше, чем состоянию звонка.
String desktopCallPeerTitle(
  CallState s,
  AppLocalizations l10n, {
  String preferred = '',
}) {
  final name = desktopCallPeerKnownName(s, preferred: preferred);
  if (name.isNotEmpty) return name;
  return s.phase == CallPhase.ringingIncoming
      ? l10n.callRecordIncomingCall
      : l10n.contactDetailsCall;
}

/// Настоящее имя собеседника или пустая строка. Для букв на заглушке: из
/// «Входящий звонок» вышло бы «ВЗ», а неизвестному положен «?».
String desktopCallPeerKnownName(CallState s, {String preferred = ''}) {
  final p = preferred.trim();
  if (p.isNotEmpty) return p;
  return s.peerName.trim();
}
