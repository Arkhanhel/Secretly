// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

String chatLocaleTagFromContext(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return chatLocaleTag(locale.languageCode, countryCode: locale.countryCode);
}

String chatLocaleTag(String languageCode, {String? countryCode}) {
  final language = languageCode.trim().toLowerCase();
  final country = (countryCode ?? '').trim().toUpperCase();
  if (language == 'pt' && country == 'BR') return 'pt_BR';
  if (language == 'pt') return 'pt';
  if (<String>{'de', 'en', 'es', 'fr', 'ru', 'uk'}.contains(language)) {
    return language;
  }
  return 'en';
}

String chatTextForLocale(
  String localeTag, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  final direct = switch (localeTag) {
    'ru' => ru,
    'uk' => uk,
    'es' => es,
    'pt' => pt,
    'pt_BR' => ptBr ?? pt,
    'fr' => fr,
    'de' => de,
    _ => en,
  };
  if (direct != null) return direct;
  final mapped = _chatTextTranslations[en];
  if (mapped == null) return en;
  return mapped[localeTag] ??
      (localeTag == 'pt_BR' ? mapped['pt'] : null) ??
      en;
}

String chatText(
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
  return chatTextForLocale(
    chatLocaleTagFromContext(context),
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

bool chatLocaleIsRussian(BuildContext context) {
  return chatLocaleTagFromContext(context) == 'ru';
}

/// Подзаголовок «был(а) …» для шапки чата.
///
/// 🔴 [timestampMs] = null ИЛИ ноль означает «время неизвестно», и это НЕ то же
/// самое, что «был в 1970 году» (полевой отчёт 03.08.2026: в шапке висело
/// «был(а) 01.01 03:00»).
///
/// Как это получалось: шапка передавала сюда жёсткий ноль как заглушку, пока не
/// подтянется настоящее присутствие, а `DateTime.fromMillisecondsSinceEpoch(0)`
/// честно форматировался в 01.01.1970 00:00 UTC — то есть 01.01 03:00 по
/// Москве. Сервер тут ни при чём: тот же экран показал бы 1970 год и с
/// мгновенным ответом.
///
/// Неизвестное время читается как «был(а) недавно», а НЕ «не в сети»: человек
/// мог написать секунду назад, и объявлять его офлайн в этот момент — врать
/// пользователю ровно так же, как это делал 1970 год, только незаметнее.
String chatLastSeenText(
  BuildContext context, {
  required int? timestampMs,
  required DateTime now,
}) {
  final localeTag = chatLocaleTagFromContext(context);
  final ts = timestampMs ?? 0;
  // ts <= 0 — «неизвестно»; ts в будущем — часы разошлись, тоже «недавно».
  final ms = ts <= 0 ? 0 : now.millisecondsSinceEpoch - ts;
  if (ms <= 0) {
    return chatTextForLocale(
      localeTag,
      ru: 'был(а) недавно',
      en: 'last seen recently',
      uk: 'був(ла) недавно',
      es: 'visto recientemente',
      pt: 'visto recentemente',
      fr: 'vu récemment',
      de: 'kürzlich gesehen',
    );
  }

  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final mon = (dt.month).toString().padLeft(2, '0');

  final todayStart = DateTime(now.year, now.month, now.day);
  if (dt.isAfter(todayStart)) {
    return chatTextForLocale(
      localeTag,
      ru: 'был(а) в $hh:$mm',
      en: 'last seen at $hh:$mm',
      uk: 'був(ла) о $hh:$mm',
      es: 'visto a las $hh:$mm',
      pt: 'visto às $hh:$mm',
      fr: 'vu à $hh:$mm',
      de: 'zuletzt um $hh:$mm',
    );
  }

  return chatTextForLocale(
    localeTag,
    ru: 'был(а) $dd.$mon $hh:$mm',
    en: 'last seen $dd.$mon $hh:$mm',
    uk: 'був(ла) $dd.$mon $hh:$mm',
    es: 'visto $dd.$mon $hh:$mm',
    pt: 'visto $dd.$mon $hh:$mm',
    fr: 'vu le $dd.$mon $hh:$mm',
    de: 'zuletzt $dd.$mon $hh:$mm',
  );
}

String chatRoomInviteMembersText(
  BuildContext context, {
  required int memberCount,
}) {
  final localeTag = chatLocaleTagFromContext(context);
  return chatTextForLocale(
    localeTag,
    ru: '$memberCount участников',
    en: '$memberCount members',
    uk: '$memberCount учасників',
    es: '$memberCount miembros',
    pt: '$memberCount membros',
    fr: '$memberCount membres',
    de: '$memberCount Mitglieder',
  );
}

const Map<String, Map<String, String>> _chatTextTranslations = {
  'New note': {
    'uk': 'Нова нотатка',
    'es': 'Nueva nota',
    'pt': 'Nova nota',
    'fr': 'Nouvelle note',
    'de': 'Neue Notiz',
  },
  'Room': {
    'uk': 'Кімната',
    'es': 'Sala',
    'pt': 'Sala',
    'fr': 'Salon',
    'de': 'Raum',
  },
  'Unknown artist': {
    'uk': 'Невідомий виконавець',
    'es': 'Artista desconocido',
    'pt': 'Artista desconhecido',
    'fr': 'Artiste inconnu',
    'de': 'Unbekannter Künstler',
  },
  'Voice message': {
    'uk': 'Голосове повідомлення',
    'es': 'Mensaje de voz',
    'pt': 'Mensagem de voz',
    'fr': 'Message vocal',
    'de': 'Sprachnachricht',
  },
  'Contact': {
    'uk': 'Контакт',
    'es': 'Contacto',
    'pt': 'Contato',
    'fr': 'Contact',
    'de': 'Kontakt',
  },
  'Room invite': {
    'uk': 'Запрошення до кімнати',
    'es': 'Invitación a sala',
    'pt': 'Convite de sala',
    'fr': 'Invitation au salon',
    'de': 'Raum-Einladung',
  },
  'You are already in the room': {
    'uk': 'Ви вже в кімнаті',
    'es': 'Ya estás en la sala',
    'pt': 'Você já está na sala',
    'fr': 'Vous êtes déjà dans le salon',
    'de': 'Sie sind bereits im Raum',
  },
  'Approval required': {
    'uk': 'Потрібне схвалення',
    'es': 'Se requiere aprobación',
    'pt': 'Aprovação necessária',
    'fr': 'Approbation requise',
    'de': 'Genehmigung erforderlich',
  },
  'Direct join': {
    'uk': 'Прямий вхід',
    'es': 'Unirse directamente',
    'pt': 'Entrada direta',
    'fr': 'Rejoindre directement',
    'de': 'Direkt beitreten',
  },
  'with history': {
    'uk': 'з історією',
    'es': 'con historial',
    'pt': 'com histórico',
    'fr': 'avec historique',
    'de': 'mit Verlauf',
  },
  'without history': {
    'uk': 'без історії',
    'es': 'sin historial',
    'pt': 'sem histórico',
    'fr': 'sans historique',
    'de': 'ohne Verlauf',
  },
  'Could not open link': {
    'uk': 'Не вдалося відкрити посилання',
    'es': 'No se pudo abrir el enlace',
    'pt': 'Não foi possível abrir o link',
    'fr': 'Impossible d\'ouvrir le lien',
    'de': 'Link konnte nicht geöffnet werden',
  },
  'Failed to open chat': {
    'uk': 'Не вдалося відкрити чат',
    'es': 'No se pudo abrir el chat',
    'pt': 'Não foi possível abrir o chat',
    'fr': 'Impossible d\'ouvrir le chat',
    'de': 'Chat konnte nicht geöffnet werden',
  },
  'Chat wallpapers': {
    'uk': 'Шпалери чату',
    'es': 'Fondos de chat',
    'pt': 'Papéis de parede do chat',
    'fr': 'Fonds d\'écran du chat',
    'de': 'Chat-Hintergründe',
  },
  'Hidden': {
    'uk': 'Приховано',
    'es': 'Oculto',
    'pt': 'Oculto',
    'fr': 'Masqué',
    'de': 'Verborgen',
  },
  'Sender only': {
    'uk': 'Лише відправник',
    'es': 'Solo remitente',
    'pt': 'Apenas remetente',
    'fr': 'Expéditeur uniquement',
    'de': 'Nur Absender',
  },
  'Sender + message': {
    'uk': 'Відправник та повідомлення',
    'es': 'Remitente + mensaje',
    'pt': 'Remetente + mensagem',
    'fr': 'Expéditeur + message',
    'de': 'Absender + Nachricht',
  },
  'Notifications': {
    'uk': 'Сповіщення',
    'es': 'Notificaciones',
    'pt': 'Notificações',
    'fr': 'Notifications',
    'de': 'Benachrichtigungen',
  },
  'Enabled': {
    'uk': 'Увімкнено',
    'es': 'Activado',
    'pt': 'Ativado',
    'fr': 'Activé',
    'de': 'Aktiviert',
  },
  'Sound': {
    'uk': 'Звук',
    'es': 'Sonido',
    'pt': 'Som',
    'fr': 'Son',
    'de': 'Ton',
  },
  'Vibration': {
    'uk': 'Вібрація',
    'es': 'Vibración',
    'pt': 'Vibração',
    'fr': 'Vibration',
    'de': 'Vibration',
  },
  'Video call': {
    'uk': 'Відеодзвінок',
    'es': 'Videollamada',
    'pt': 'Videochamada',
    'fr': 'Appel vidéo',
    'de': 'Videoanruf',
  },
  'Clear history': {
    'uk': 'Очистити історію',
    'es': 'Borrar historial',
    'pt': 'Limpar histórico',
    'fr': 'Effacer l\'historique',
    'de': 'Verlauf löschen',
  },
  'Delete chat': {
    'uk': 'Видалити чат',
    'es': 'Eliminar chat',
    'pt': 'Excluir chat',
    'fr': 'Supprimer le chat',
    'de': 'Chat löschen',
  },
  'Delete for everyone?': {
    'uk': 'Видалити для всіх?',
    'es': '¿Eliminar para todos?',
    'pt': 'Excluir para todos?',
    'fr': 'Supprimer pour tout le monde?',
    'de': 'Für alle löschen?',
  },
  'Cancel': {
    'uk': 'Скасувати',
    'es': 'Cancelar',
    'pt': 'Cancelar',
    'fr': 'Annuler',
    'de': 'Abbrechen',
  },
  'Delete': {
    'uk': 'Видалити',
    'es': 'Eliminar',
    'pt': 'Excluir',
    'fr': 'Supprimer',
    'de': 'Löschen',
  },
  'Open': {
    'uk': 'Відкрити',
    'es': 'Abrir',
    'pt': 'Abrir',
    'fr': 'Ouvrir',
    'de': 'Öffnen',
  },
  'Download': {
    'uk': 'Завантажити',
    'es': 'Descargar',
    'pt': 'Baixar',
    'fr': 'Télécharger',
    'de': 'Herunterladen',
  },
  'Share': {
    'uk': 'Поділитися',
    'es': 'Compartir',
    'pt': 'Compartilhar',
    'fr': 'Partager',
    'de': 'Teilen',
  },
  'Pinned messages': {
    'uk': 'Закріплені повідомлення',
    'es': 'Mensajes fijados',
    'pt': 'Mensagens fixadas',
    'fr': 'Messages épinglés',
    'de': 'Angeheftete Nachrichten',
  },
  'Cancel sending': {
    'uk': 'Скасувати відправку',
    'es': 'Cancelar envío',
    'pt': 'Cancelar envio',
    'fr': 'Annuler l\'envoi',
    'de': 'Senden abbrechen',
  },
  'Retry sending': {
    'uk': 'Повторити відправку',
    'es': 'Reintentar envío',
    'pt': 'Tentar enviar novamente',
    'fr': 'Réessayer l\'envoi',
    'de': 'Erneut senden',
  },
  'Personal notebook': {
    'uk': 'Особистий блокнот',
    'es': 'Cuaderno personal',
    'pt': 'Caderno pessoal',
    'fr': 'Carnet personnel',
    'de': 'Persönliches Notizbuch',
  },
  'Your role cannot send messages in this room.': {
    'uk': 'Ваша роль не може надсилати повідомлення в цій кімнаті.',
    'es': 'Tu rol no puede enviar mensajes en esta sala.',
    'pt': 'Sua função não pode enviar mensagens nesta sala.',
    'fr': 'Votre rôle ne peut pas envoyer de messages dans ce salon.',
    'de': 'Ihre Rolle kann in diesem Raum keine Nachrichten senden.',
  },
  'Only administrators can send messages.': {
    'uk': 'Лише адміністратори можуть надсилати повідомлення.',
    'es': 'Solo los administradores pueden enviar mensajes.',
    'pt': 'Apenas administradores podem enviar mensagens.',
    'fr': 'Seuls les administrateurs peuvent envoyer des messages.',
    'de': 'Nur Administratoren können Nachrichten senden.',
  },
  'Only administrators can send media.': {
    'uk': 'Лише адміністратори можуть надсилати медіа.',
    'es': 'Solo los administradores pueden enviar medios.',
    'pt': 'Apenas administradores podem enviar mídia.',
    'fr': 'Seuls les administrateurs peuvent envoyer des médias.',
    'de': 'Nur Administratoren können Medien senden.',
  },
  'Failed to open invite': {
    'uk': 'Не вдалося відкрити запрошення',
    'es': 'No se pudo abrir la invitación',
    'pt': 'Não foi possível abrir o convite',
    'fr': 'Impossible d\'ouvrir l\'invitation',
    'de': 'Einladung konnte nicht geöffnet werden',
  },
  'You': {'uk': 'Ви', 'es': 'Tú', 'pt': 'Você', 'fr': 'Vous', 'de': 'Sie'},
  'Pinned message': {
    'uk': 'Закріплене повідомлення',
    'es': 'Mensaje fijado',
    'pt': 'Mensagem fixada',
    'fr': 'Message épinglé',
    'de': 'Angeheftete Nachricht',
  },
  'Copied': {
    'uk': 'Скопійовано',
    'es': 'Copiado',
    'pt': 'Copiado',
    'fr': 'Copié',
    'de': 'Kopiert',
  },
  'Some messages were skipped because of privacy restrictions.': {
    'uk': 'Деякі повідомлення пропущено через обмеження приватності.',
    'es': 'Algunos mensajes se omitieron por restricciones de privacidad.',
    'pt': 'Algumas mensagens foram ignoradas por restrições de privacidade.',
    'fr':
        'Certains messages ont été ignorés à cause des restrictions de confidentialité.',
    'de':
        'Einige Nachrichten wurden wegen Datenschutzeinschränkungen übersprungen.',
  },
  'Delete message?': {
    'uk': 'Видалити повідомлення?',
    'es': '¿Eliminar mensaje?',
    'pt': 'Excluir mensagem?',
    'fr': 'Supprimer le message ?',
    'de': 'Nachricht löschen?',
  },
  'Delete messages?': {
    'uk': 'Видалити повідомлення?',
    'es': '¿Eliminar mensajes?',
    'pt': 'Excluir mensagens?',
    'fr': 'Supprimer les messages ?',
    'de': 'Nachrichten löschen?',
  },
  'Choose whether to delete the messages only on this device or for everyone.': {
    'uk': 'Виберіть, видалити повідомлення лише на цьому пристрої чи для всіх.',
    'es':
        'Elige si quieres eliminar los mensajes solo en este dispositivo o para todos.',
    'pt':
        'Escolha se deseja excluir as mensagens apenas neste dispositivo ou para todos.',
    'fr':
        'Choisissez si les messages doivent être supprimés seulement sur cet appareil ou pour tout le monde.',
    'de':
        'Wählen Sie, ob die Nachrichten nur auf diesem Gerät oder für alle gelöscht werden sollen.',
  },
  'Messages will be deleted only on this device.': {
    'uk': 'Повідомлення буде видалено лише на цьому пристрої.',
    'es': 'Los mensajes se eliminarán solo en este dispositivo.',
    'pt': 'As mensagens serão excluídas apenas neste dispositivo.',
    'fr': 'Les messages seront supprimés uniquement sur cet appareil.',
    'de': 'Die Nachrichten werden nur auf diesem Gerät gelöscht.',
  },
  'Show all': {
    'uk': 'Показати все',
    'es': 'Mostrar todo',
    'pt': 'Mostrar tudo',
    'fr': 'Tout afficher',
    'de': 'Alle anzeigen',
  },
  'Copy': {
    'uk': 'Копіювати',
    'es': 'Copiar',
    'pt': 'Copiar',
    'fr': 'Copier',
    'de': 'Kopieren',
  },
  'Forward': {
    'uk': 'Переслати',
    'es': 'Reenviar',
    'pt': 'Reencaminhar',
    'fr': 'Transférer',
    'de': 'Weiterleiten',
  },
  'More': {'uk': 'Ще', 'es': 'Más', 'pt': 'Mais', 'fr': 'Plus', 'de': 'Mehr'},
  'Call': {
    'uk': 'Дзвінок',
    'es': 'Llamar',
    'pt': 'Chamada',
    'fr': 'Appel',
    'de': 'Anruf',
  },
  'Room call': {
    'uk': 'Дзвінок кімнати',
    'es': 'Llamada de sala',
    'pt': 'Chamada da sala',
    'fr': 'Appel du salon',
    'de': 'Raumanruf',
  },
  'Editing message': {
    'uk': 'Редагування повідомлення',
    'es': 'Editando mensaje',
    'pt': 'Editando mensagem',
    'fr': 'Modification du message',
    'de': 'Nachricht bearbeiten',
  },
  'Paste photo': {
    'uk': 'Вставити фото',
    'es': 'Pegar foto',
    'pt': 'Colar foto',
    'fr': 'Coller la photo',
    'de': 'Foto einfügen',
  },
  'Emoji': {
    'uk': 'Емодзі',
    'es': 'Emoji',
    'pt': 'Emoji',
    'fr': 'Emoji',
    'de': 'Emoji',
  },
  'Stickers': {
    'uk': 'Стікери',
    'es': 'Stickers',
    'pt': 'Stickers',
    'fr': 'Stickers',
    'de': 'Sticker',
  },
  'Search emoji': {
    'uk': 'Пошук емодзі',
    'es': 'Buscar emoji',
    'pt': 'Buscar emoji',
    'fr': 'Rechercher un emoji',
    'de': 'Emoji suchen',
  },
  'No app found to open this file': {
    'uk': 'Не знайдено застосунок для відкриття цього файла',
    'es': 'No se encontró ninguna app para abrir este archivo',
    'pt': 'Nenhum app encontrado para abrir este arquivo',
    'fr': 'Aucune app trouvée pour ouvrir ce fichier',
    'de': 'Keine App zum Öffnen dieser Datei gefunden',
  },
  'Could not edit this message.': {
    'uk': 'Не вдалося відредагувати це повідомлення.',
    'es': 'No se pudo editar este mensaje.',
    'pt': 'Não foi possível editar esta mensagem.',
    'fr': 'Impossible de modifier ce message.',
    'de': 'Diese Nachricht konnte nicht bearbeitet werden.',
  },
  'Forwarded from': {
    'uk': 'Переслано від',
    'es': 'Reenviado de',
    'pt': 'Reencaminhado de',
    'fr': 'Transféré de',
    'de': 'Weitergeleitet von',
  },
  'Some forwarded messages were skipped because the sender restricted forwarding.': {
    'uk':
        'Деякі переслані повідомлення пропущено, бо відправник обмежив пересилання.',
    'es':
        'Algunos mensajes reenviados se omitieron porque el remitente restringió el reenvío.',
    'pt':
        'Algumas mensagens reencaminhadas foram ignoradas porque o remetente restringiu o reencaminhamento.',
    'fr':
        'Certains messages transférés ont été ignorés car l\'expéditeur a limité le transfert.',
    'de':
        'Einige weitergeleitete Nachrichten wurden übersprungen, weil der Absender das Weiterleiten eingeschränkt hat.',
  },
  'These messages cannot be forwarded because the sender restricted forwarding.': {
    'uk':
        'Ці повідомлення не можна переслати, бо відправник обмежив пересилання.',
    'es':
        'Estos mensajes no se pueden reenviar porque el remitente restringió el reenvío.',
    'pt':
        'Estas mensagens não podem ser reencaminhadas porque o remetente restringiu o reencaminhamento.',
    'fr':
        'Ces messages ne peuvent pas être transférés car l\'expéditeur a limité le transfert.',
    'de':
        'Diese Nachrichten können nicht weitergeleitet werden, weil der Absender das Weiterleiten eingeschränkt hat.',
  },
  'Clear history?': {
    'uk': 'Очистити історію?',
    'es': '¿Borrar historial?',
    'pt': 'Limpar histórico?',
    'fr': 'Effacer l\'historique ?',
    'de': 'Verlauf löschen?',
  },
  'Messages will be cleared for you and the other participant on all connected devices.': {
    'uk':
        'Повідомлення буде очищено для вас і співрозмовника на всіх підключених пристроях.',
    'es':
        'Los mensajes se borrarán para ti y la otra persona en todos los dispositivos conectados.',
    'pt':
        'As mensagens serão limpas para você e a outra pessoa em todos os dispositivos conectados.',
    'fr':
        'Les messages seront effacés pour vous et l\'autre participant sur tous les appareils connectés.',
    'de':
        'Die Nachrichten werden für Sie und die andere Person auf allen verbundenen Geräten gelöscht.',
  },
  'owner': {
    'uk': 'власник',
    'es': 'propietario',
    'pt': 'proprietário',
    'fr': 'propriétaire',
    'de': 'Inhaber',
  },
  'admin': {
    'uk': 'адміністратор',
    'es': 'admin',
    'pt': 'admin',
    'fr': 'admin',
    'de': 'Admin',
  },
  'moderator': {
    'uk': 'модератор',
    'es': 'moderador',
    'pt': 'moderador',
    'fr': 'modérateur',
    'de': 'Moderator',
  },
  'member': {
    'uk': 'учасник',
    'es': 'miembro',
    'pt': 'membro',
    'fr': 'membre',
    'de': 'Mitglied',
  },
  'restricted member': {
    'uk': 'учасник з обмеженнями',
    'es': 'miembro restringido',
    'pt': 'membro restrito',
    'fr': 'membre restreint',
    'de': 'eingeschränktes Mitglied',
  },
  'read-only member': {
    'uk': 'учасник лише для читання',
    'es': 'miembro de solo lectura',
    'pt': 'membro somente leitura',
    'fr': 'membre en lecture seule',
    'de': 'Mitglied mit Lesezugriff',
  },
  'Mention everyone in the room': {
    'uk': 'Згадати всіх у кімнаті',
    'es': 'Mencionar a todos en la sala',
    'pt': 'Mencionar todos na sala',
    'fr': 'Mentionner tout le salon',
    'de': 'Alle im Raum erwähnen',
  },
  'Mention the owner, admins, and moderators': {
    'uk': 'Згадати власника, адміністраторів і модераторів',
    'es': 'Mencionar al propietario, admins y moderadores',
    'pt': 'Mencionar o proprietário, admins e moderadores',
    'fr': 'Mentionner le propriétaire, les admins et les modérateurs',
    'de': 'Inhaber, Admins und Moderatoren erwähnen',
  },
  'Open chat': {
    'uk': 'Відкрити чат',
    'es': 'Abrir chat',
    'pt': 'Abrir chat',
    'fr': 'Ouvrir le chat',
    'de': 'Chat öffnen',
  },
  'Message': {
    'uk': 'Написати',
    'es': 'Mensaje',
    'pt': 'Mensagem',
    'fr': 'Message',
    'de': 'Nachricht',
  },
  'Open the card to review the room and join.': {
    'uk': 'Відкрийте картку, щоб переглянути кімнату й приєднатися.',
    'es': 'Abre la tarjeta para revisar la sala y unirte.',
    'pt': 'Abra o cartão para revisar a sala e entrar.',
    'fr': 'Ouvrez la carte pour consulter le salon et le rejoindre.',
    'de': 'Öffnen Sie die Karte, um den Raum zu prüfen und beizutreten.',
  },
  'History for new members is enabled': {
    'uk': 'Історію для нових учасників увімкнено',
    'es': 'El historial para nuevos miembros está activado',
    'pt': 'O histórico para novos membros está ativado',
    'fr': 'L\'historique pour les nouveaux membres est activé',
    'de': 'Verlauf für neue Mitglieder ist aktiviert',
  },
  'History for new members is disabled': {
    'uk': 'Історію для нових учасників вимкнено',
    'es': 'El historial para nuevos miembros está desactivado',
    'pt': 'O histórico para novos membros está desativado',
    'fr': 'L\'historique pour les nouveaux membres est désactivé',
    'de': 'Verlauf für neue Mitglieder ist deaktiviert',
  },
  'Open room': {
    'uk': 'Відкрити кімнату',
    'es': 'Abrir sala',
    'pt': 'Abrir sala',
    'fr': 'Ouvrir le salon',
    'de': 'Raum öffnen',
  },
  'Open request': {
    'uk': 'Відкрити заявку',
    'es': 'Abrir solicitud',
    'pt': 'Abrir pedido',
    'fr': 'Ouvrir la demande',
    'de': 'Anfrage öffnen',
  },
  'Request access': {
    'uk': 'Запросити доступ',
    'es': 'Solicitar acceso',
    'pt': 'Solicitar acesso',
    'fr': 'Demander l\'accès',
    'de': 'Zugriff anfragen',
  },
  'Join room': {
    'uk': 'Приєднатися',
    'es': 'Unirse a la sala',
    'pt': 'Entrar na sala',
    'fr': 'Rejoindre le salon',
    'de': 'Raum beitreten',
  },
  'Actions': {
    'uk': 'Дії',
    'es': 'Acciones',
    'pt': 'Ações',
    'fr': 'Actions',
    'de': 'Aktionen',
  },
  'Save to gallery': {
    'uk': 'Зберегти в галерею',
    'es': 'Guardar en la galería',
    'pt': 'Salvar na galeria',
    'fr': 'Enregistrer dans la galerie',
    'de': 'In Galerie speichern',
  },
  'Show all media': {
    'uk': 'Показати всі медіа',
    'es': 'Mostrar todos los medios',
    'pt': 'Mostrar todas as mídias',
    'fr': 'Afficher tous les médias',
    'de': 'Alle Medien anzeigen',
  },
  'Show in chat': {
    'uk': 'Показати в чаті',
    'es': 'Mostrar en chat',
    'pt': 'Mostrar no chat',
    'fr': 'Afficher dans le chat',
    'de': 'Im Chat anzeigen',
  },
  'Reply': {
    'uk': 'Відповісти',
    'es': 'Responder',
    'pt': 'Responder',
    'fr': 'Répondre',
    'de': 'Antworten',
  },
  'Search GIFs': {
    'uk': 'Пошук GIF',
    'es': 'Buscar GIF',
    'pt': 'Buscar GIFs',
    'fr': 'Rechercher des GIF',
    'de': 'GIFs suchen',
  },
  'Loading...': {
    'uk': 'Завантаження...',
    'es': 'Cargando...',
    'pt': 'Carregando...',
    'fr': 'Chargement...',
    'de': 'Wird geladen...',
  },
  'No GIFs found': {
    'uk': 'GIF не знайдено',
    'es': 'No se encontraron GIF',
    'pt': 'Nenhum GIF encontrado',
    'fr': 'Aucun GIF trouvé',
    'de': 'Keine GIFs gefunden',
  },
  'Today': {
    'uk': 'Сьогодні',
    'es': 'Hoy',
    'pt': 'Hoje',
    'fr': 'Aujourd\'hui',
    'de': 'Heute',
  },
  'Tomorrow': {
    'uk': 'Завтра',
    'es': 'Mañana',
    'pt': 'Amanhã',
    'fr': 'Demain',
    'de': 'Morgen',
  },
  'Video call started': {
    'uk': 'Відеодзвінок розпочато',
    'es': 'Videollamada iniciada',
    'pt': 'Videochamada iniciada',
    'fr': 'Appel vidéo lancé',
    'de': 'Videoanruf gestartet',
  },
  'Voice call started': {
    'uk': 'Голосовий дзвінок розпочато',
    'es': 'Llamada de voz iniciada',
    'pt': 'Chamada de voz iniciada',
    'fr': 'Appel vocal lancé',
    'de': 'Sprachanruf gestartet',
  },
  'Join': {
    'uk': 'Увійти',
    'es': 'Unirse',
    'pt': 'Entrar',
    'fr': 'Rejoindre',
    'de': 'Beitreten',
  },
};
