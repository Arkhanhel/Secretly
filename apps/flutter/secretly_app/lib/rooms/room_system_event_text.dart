// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../models/e2e_payload_v1.dart';
import '../ui/room_l10n_bridge.dart';

abstract final class RoomSystemEventAction {
  static const String memberAdded = 'room_member_added';
  static const String memberJoined = 'room_member_joined';
  static const String joinRequested = 'room_join_requested';
  static const String joinRequestApproved = 'room_join_request_approved';
  static const String joinRequestDeclined = 'room_join_request_declined';
  static const String memberLeft = 'room_member_left';
  static const String memberRemoved = 'room_member_removed';
  static const String memberBanned = 'room_member_banned';
  static const String memberUnbanned = 'room_member_unbanned';
  static const String adminGranted = 'room_admin_granted';
  static const String adminRevoked = 'room_admin_revoked';
  static const String roleChanged = 'room_role_changed';
  static const String ownerTransferred = 'room_owner_transferred';
  static const String profileUpdated = 'room_profile_updated';
  static const String settingsUpdated = 'room_settings_updated';
  static const String memberTagUpdated = 'room_member_tag_updated';
}

enum _ParticipantCase { subject, object, to }

String formatSystemEventText(
  SystemEventV1 event, {
  required bool isRu,
  String? selfProfileId,
  String? localeTag,
}) {
  late final String resolvedLocaleTag;
  if (localeTag == null) {
    if (isRu) {
      resolvedLocaleTag = 'ru';
    } else {
      resolvedLocaleTag = 'en';
    }
  } else {
    resolvedLocaleTag = roomLocaleTagFromString(localeTag);
  }
  final action = (event.action ?? '').trim();
  final fallback = event.text.trim();
  if (action.isEmpty) {
    return fallback.isEmpty
        ? _roomEventText(
            resolvedLocaleTag,
            ru: 'Системное сообщение',
            en: 'System message',
          )
        : fallback;
  }

  final actor = _participantLabel(
    localeTag: resolvedLocaleTag,
    participantCase: _ParticipantCase.subject,
    selfProfileId: selfProfileId,
    profileId: event.actorProfileId,
    displayName: event.actorDisplayName,
  );
  final targetObject = _participantLabel(
    localeTag: resolvedLocaleTag,
    participantCase: _ParticipantCase.object,
    selfProfileId: selfProfileId,
    profileId: event.targetProfileId,
    displayName: event.targetDisplayName,
  );
  final targetTo = _participantLabel(
    localeTag: resolvedLocaleTag,
    participantCase: _ParticipantCase.to,
    selfProfileId: selfProfileId,
    profileId: event.targetProfileId,
    displayName: event.targetDisplayName,
  );
  final changedKeys = event.changedKeys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList(growable: false);

  return switch (action) {
    RoomSystemEventAction.memberAdded => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor добавил $targetObject.',
      en: '$actor added $targetObject.',
      uk: '$actor додав $targetObject.',
      es: '$actor agrego a $targetObject.',
      pt: '$actor adicionou $targetObject.',
      ptBr: '$actor adicionou $targetObject.',
      fr: '$actor a ajoute $targetObject.',
      de: '$actor hat $targetObject hinzugefuegt.',
    ),
    RoomSystemEventAction.memberJoined => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor присоединился к комнате.',
      en: '$actor joined the room.',
      uk: '$actor приєднався до кімнати.',
      es: '$actor se unio a la sala.',
      pt: '$actor entrou na sala.',
      ptBr: '$actor entrou na sala.',
      fr: '$actor a rejoint le salon.',
      de: '$actor ist dem Raum beigetreten.',
    ),
    RoomSystemEventAction.joinRequested => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor запросил вступление в комнату.',
      en: '$actor requested to join the room.',
      uk: '$actor попросив вступити до кімнати.',
      es: '$actor solicito unirse a la sala.',
      pt: '$actor pediu para entrar na sala.',
      ptBr: '$actor pediu para entrar na sala.',
      fr: '$actor a demande a rejoindre le salon.',
      de: '$actor hat angefragt, dem Raum beizutreten.',
    ),
    RoomSystemEventAction.joinRequestApproved => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor одобрил запрос на вступление от $targetObject.',
      en: '$actor approved a join request from $targetObject.',
      uk: '$actor схвалив запит на вступ від $targetObject.',
      es: '$actor aprobo la solicitud de $targetObject.',
      pt: '$actor aprovou o pedido de entrada de $targetObject.',
      ptBr: '$actor aprovou a solicitacao de entrada de $targetObject.',
      fr: '$actor a approuve la demande de $targetObject.',
      de: '$actor hat die Beitrittsanfrage von $targetObject genehmigt.',
    ),
    RoomSystemEventAction.joinRequestDeclined => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor отклонил запрос на вступление от $targetObject.',
      en: '$actor declined a join request from $targetObject.',
      uk: '$actor відхилив запит на вступ від $targetObject.',
      es: '$actor rechazo la solicitud de $targetObject.',
      pt: '$actor recusou o pedido de entrada de $targetObject.',
      ptBr: '$actor recusou a solicitacao de entrada de $targetObject.',
      fr: '$actor a refuse la demande de $targetObject.',
      de: '$actor hat die Beitrittsanfrage von $targetObject abgelehnt.',
    ),
    RoomSystemEventAction.memberLeft => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor покинул комнату.',
      en: '$actor left the room.',
      uk: '$actor вийшов з кімнати.',
      es: '$actor salio de la sala.',
      pt: '$actor saiu da sala.',
      ptBr: '$actor saiu da sala.',
      fr: '$actor a quitte le salon.',
      de: '$actor hat den Raum verlassen.',
    ),
    RoomSystemEventAction.memberRemoved => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor удалил $targetObject из комнаты.',
      en: '$actor removed $targetObject from the room.',
      uk: '$actor видалив $targetObject з кімнати.',
      es: '$actor elimino a $targetObject de la sala.',
      pt: '$actor removeu $targetObject da sala.',
      ptBr: '$actor removeu $targetObject da sala.',
      fr: '$actor a retire $targetObject du salon.',
      de: '$actor hat $targetObject aus dem Raum entfernt.',
    ),
    RoomSystemEventAction.memberBanned => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor заблокировал $targetObject в комнате.',
      en: '$actor banned $targetObject in the room.',
      uk: '$actor заблокував $targetObject у кімнаті.',
      es: '$actor bloqueo a $targetObject en la sala.',
      pt: '$actor bloqueou $targetObject na sala.',
      ptBr: '$actor baniu $targetObject na sala.',
      fr: '$actor a banni $targetObject du salon.',
      de: '$actor hat $targetObject im Raum gesperrt.',
    ),
    RoomSystemEventAction.memberUnbanned => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor снял бан с $targetObject.',
      en: '$actor unbanned $targetObject.',
      uk: '$actor розблокував $targetObject.',
      es: '$actor desbloqueo a $targetObject.',
      pt: '$actor desbloqueou $targetObject.',
      ptBr: '$actor desbaniu $targetObject.',
      fr: '$actor a debanni $targetObject.',
      de: '$actor hat $targetObject entsperrt.',
    ),
    RoomSystemEventAction.adminGranted => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor сделал $targetObject администратором.',
      en: '$actor made $targetObject an admin.',
      uk: '$actor зробив $targetObject адміністратором.',
      es: '$actor hizo a $targetObject administrador.',
      pt: '$actor tornou $targetObject administrador.',
      ptBr: '$actor tornou $targetObject administrador.',
      fr: '$actor a defini $targetObject comme administrateur.',
      de: '$actor hat $targetObject zum Administrator gemacht.',
    ),
    RoomSystemEventAction.adminRevoked => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor убрал $targetObject из администраторов.',
      en: '$actor removed $targetObject from admins.',
      uk: '$actor забрав права адміністратора у $targetObject.',
      es: '$actor quito a $targetObject de administradores.',
      pt: '$actor removeu $targetObject dos administradores.',
      ptBr: '$actor removeu $targetObject dos administradores.',
      fr: '$actor a retire $targetObject des administrateurs.',
      de: '$actor hat $targetObject aus den Admins entfernt.',
    ),
    RoomSystemEventAction.roleChanged => _roleChangedText(
      actor: actor,
      targetObject: targetObject,
      changedKeys: changedKeys,
      localeTag: resolvedLocaleTag,
    ),
    RoomSystemEventAction.ownerTransferred => _roomEventText(
      resolvedLocaleTag,
      ru: '$actor передал владение комнатой $targetTo.',
      en: '$actor transferred room ownership to $targetTo.',
      uk: '$actor передав право власності на кімнату $targetTo.',
      es: '$actor transfirio la propiedad de la sala a $targetTo.',
      pt: '$actor transferiu a propriedade da sala para $targetTo.',
      ptBr: '$actor transferiu a propriedade da sala para $targetTo.',
      fr: '$actor a transfere la propriete du salon a $targetTo.',
      de: '$actor hat den Raumbesitz an $targetTo uebertragen.',
    ),
    RoomSystemEventAction.profileUpdated => _profileUpdatedText(
      actor: actor,
      changedKeys: changedKeys,
      localeTag: resolvedLocaleTag,
    ),
    RoomSystemEventAction.settingsUpdated => _settingsUpdatedText(
      actor: actor,
      changedKeys: changedKeys,
      localeTag: resolvedLocaleTag,
    ),
    RoomSystemEventAction.memberTagUpdated => _memberTagUpdatedText(
      actor: actor,
      changedKeys: changedKeys,
      localeTag: resolvedLocaleTag,
    ),
    _ =>
      fallback.isEmpty
          ? _roomEventText(
              resolvedLocaleTag,
              ru: 'Системное сообщение',
              en: 'System message',
            )
          : fallback,
  };
}

String _roomEventText(
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
  return roomTextForLocale(
    localeTag,
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

String _profileUpdatedText({
  required String actor,
  required List<String> changedKeys,
  required String localeTag,
}) {
  final uniqueKeys = changedKeys.toSet().toList(growable: false);
  if (uniqueKeys.length == 1) {
    return switch (uniqueKeys.first) {
      'title' => _roomEventText(
        localeTag,
        ru: '$actor изменил название комнаты.',
        en: '$actor changed the room name.',
        uk: '$actor змінив назву кімнати.',
        es: '$actor cambio el nombre de la sala.',
        pt: '$actor alterou o nome da sala.',
        ptBr: '$actor alterou o nome da sala.',
        fr: '$actor a modifie le nom du salon.',
        de: '$actor hat den Raumnamen geaendert.',
      ),
      'description' => _roomEventText(
        localeTag,
        ru: '$actor обновил описание комнаты.',
        en: '$actor updated the room description.',
        uk: '$actor оновив опис кімнати.',
        es: '$actor actualizo la descripcion de la sala.',
        pt: '$actor atualizou a descricao da sala.',
        ptBr: '$actor atualizou a descricao da sala.',
        fr: '$actor a mis a jour la description du salon.',
        de: '$actor hat die Raumbeschreibung aktualisiert.',
      ),
      'avatar' => _roomEventText(
        localeTag,
        ru: '$actor обновил фото комнаты.',
        en: '$actor updated the room photo.',
        uk: '$actor оновив фото кімнати.',
        es: '$actor actualizo la foto de la sala.',
        pt: '$actor atualizou a foto da sala.',
        ptBr: '$actor atualizou a foto da sala.',
        fr: '$actor a mis a jour la photo du salon.',
        de: '$actor hat das Raumfoto aktualisiert.',
      ),
      _ => _roomEventText(
        localeTag,
        ru: '$actor обновил профиль комнаты.',
        en: '$actor updated the room profile.',
        uk: '$actor оновив профіль кімнати.',
        es: '$actor actualizo el perfil de la sala.',
        pt: '$actor atualizou o perfil da sala.',
        ptBr: '$actor atualizou o perfil da sala.',
        fr: '$actor a mis a jour le profil du salon.',
        de: '$actor hat das Raumprofil aktualisiert.',
      ),
    };
  }
  return _roomEventText(
    localeTag,
    ru: '$actor обновил профиль комнаты.',
    en: '$actor updated the room profile.',
    uk: '$actor оновив профіль кімнати.',
    es: '$actor actualizo el perfil de la sala.',
    pt: '$actor atualizou o perfil da sala.',
    ptBr: '$actor atualizou o perfil da sala.',
    fr: '$actor a mis a jour le profil du salon.',
    de: '$actor hat das Raumprofil aktualisiert.',
  );
}

String _settingsUpdatedText({
  required String actor,
  required List<String> changedKeys,
  required String localeTag,
}) {
  final labels = changedKeys
      .map((key) => _settingLabel(key, localeTag: localeTag))
      .where((label) => label.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (labels.isEmpty) {
    return _roomEventText(
      localeTag,
      ru: '$actor обновил настройки комнаты.',
      en: '$actor updated room settings.',
      uk: '$actor оновив налаштування кімнати.',
      es: '$actor actualizo los ajustes de la sala.',
      pt: '$actor atualizou as definicoes da sala.',
      ptBr: '$actor atualizou as configuracoes da sala.',
      fr: '$actor a mis a jour les reglages du salon.',
      de: '$actor hat die Raumeinstellungen aktualisiert.',
    );
  }
  return _roomEventText(
    localeTag,
    ru: '$actor обновил настройки комнаты: ${labels.join(', ')}.',
    en: '$actor updated room settings: ${labels.join(', ')}.',
    uk: '$actor оновив налаштування кімнати: ${labels.join(', ')}.',
    es: '$actor actualizo ajustes de la sala: ${labels.join(', ')}.',
    pt: '$actor atualizou definicoes da sala: ${labels.join(', ')}.',
    ptBr: '$actor atualizou configuracoes da sala: ${labels.join(', ')}.',
    fr: '$actor a mis a jour les reglages du salon : ${labels.join(', ')}.',
    de: '$actor hat Raumeinstellungen aktualisiert: ${labels.join(', ')}.',
  );
}

String _memberTagUpdatedText({
  required String actor,
  required List<String> changedKeys,
  required String localeTag,
}) {
  final tagKey = changedKeys.firstWhere(
    (key) => key.startsWith('tag:'),
    orElse: () => '',
  );
  final tagValue = tagKey.startsWith('tag:')
      ? tagKey.substring('tag:'.length).trim()
      : '';
  if (tagValue.isEmpty) {
    return _roomEventText(
      localeTag,
      ru: '$actor очистил свой тег в комнате.',
      en: '$actor cleared their room tag.',
      uk: '$actor очистив свій тег у кімнаті.',
      es: '$actor borro su etiqueta de sala.',
      pt: '$actor limpou a sua etiqueta da sala.',
      ptBr: '$actor limpou sua etiqueta da sala.',
      fr: '$actor a efface son tag de salon.',
      de: '$actor hat den eigenen Raum-Tag geloescht.',
    );
  }
  return _roomEventText(
    localeTag,
    ru: '$actor установил тег в комнате: "$tagValue".',
    en: '$actor set their room tag to "$tagValue".',
    uk: '$actor встановив тег у кімнаті: "$tagValue".',
    es: '$actor establecio su etiqueta de sala en "$tagValue".',
    pt: '$actor definiu a sua etiqueta da sala como "$tagValue".',
    ptBr: '$actor definiu sua etiqueta da sala como "$tagValue".',
    fr: '$actor a defini son tag de salon sur "$tagValue".',
    de: '$actor hat den eigenen Raum-Tag auf "$tagValue" gesetzt.',
  );
}

String _roleChangedText({
  required String actor,
  required String targetObject,
  required List<String> changedKeys,
  required String localeTag,
}) {
  final roleKey = changedKeys.firstWhere(
    (key) => key.startsWith('role:'),
    orElse: () => '',
  );
  final roleValue = roleKey.startsWith('role:')
      ? roleKey.substring('role:'.length).trim().toLowerCase()
      : '';
  final roleLabel = _systemEventRoleLabel(roleValue, localeTag: localeTag);
  if (roleLabel == null) {
    return _roomEventText(
      localeTag,
      ru: '$actor обновил роль $targetObject.',
      en: '$actor updated $targetObject\'s role.',
      uk: '$actor оновив роль $targetObject.',
      es: '$actor actualizo el rol de $targetObject.',
      pt: '$actor atualizou a funcao de $targetObject.',
      ptBr: '$actor atualizou a funcao de $targetObject.',
      fr: '$actor a mis a jour le role de $targetObject.',
      de: '$actor hat die Rolle von $targetObject aktualisiert.',
    );
  }
  return _roomEventText(
    localeTag,
    ru: '$actor сделал $targetObject $roleLabel.',
    en: '$actor made $targetObject $roleLabel.',
    uk: '$actor зробив $targetObject $roleLabel.',
    es: '$actor hizo a $targetObject $roleLabel.',
    pt: '$actor tornou $targetObject $roleLabel.',
    ptBr: '$actor tornou $targetObject $roleLabel.',
    fr: '$actor a defini $targetObject comme $roleLabel.',
    de: '$actor hat $targetObject zu $roleLabel gemacht.',
  );
}

String _settingLabel(String key, {required String localeTag}) {
  return switch (key) {
    'reactions_mode' => _roomEventText(
      localeTag,
      ru: 'реакции',
      en: 'reactions',
      uk: 'реакції',
      es: 'reacciones',
      pt: 'reacoes',
      ptBr: 'reacoes',
      fr: 'reactions',
      de: 'Reaktionen',
    ),
    'allow_text' => _roomEventText(
      localeTag,
      ru: 'текстовые сообщения',
      en: 'text messages',
      uk: 'текстові повідомлення',
      es: 'mensajes de texto',
      pt: 'mensagens de texto',
      ptBr: 'mensagens de texto',
      fr: 'messages texte',
      de: 'Textnachrichten',
    ),
    'allow_media' => _roomEventText(
      localeTag,
      ru: 'медиа',
      en: 'media',
      uk: 'медіа',
      es: 'medios',
      pt: 'multimedia',
      ptBr: 'midia',
      fr: 'medias',
      de: 'Medien',
    ),
    'allow_add_members' => _roomEventText(
      localeTag,
      ru: 'добавление участников',
      en: 'adding members',
      uk: 'додавання учасників',
      es: 'agregar miembros',
      pt: 'adicionar membros',
      ptBr: 'adicionar membros',
      fr: 'ajout de membres',
      de: 'Mitglieder hinzufuegen',
    ),
    'allow_pin_messages' => _roomEventText(
      localeTag,
      ru: 'закрепление',
      en: 'pinning',
      uk: 'закріплення',
      es: 'fijar mensajes',
      pt: 'fixar mensagens',
      ptBr: 'fixar mensagens',
      fr: 'epinglage',
      de: 'Anheften',
    ),
    'allow_change_group_info' => _roomEventText(
      localeTag,
      ru: 'изменение профиля комнаты',
      en: 'room profile editing',
      uk: 'редагування профілю кімнати',
      es: 'edicion del perfil de sala',
      pt: 'edicao do perfil da sala',
      ptBr: 'edicao do perfil da sala',
      fr: 'modification du profil du salon',
      de: 'Raumprofil bearbeiten',
    ),
    'allow_change_tag' => _roomEventText(
      localeTag,
      ru: 'изменение тега',
      en: 'tag editing',
      uk: 'редагування тегу',
      es: 'edicion de etiqueta',
      pt: 'edicao da etiqueta',
      ptBr: 'edicao da etiqueta',
      fr: 'modification du tag',
      de: 'Tag bearbeiten',
    ),
    'join_approval_required' => _roomEventText(
      localeTag,
      ru: 'одобрение вступления',
      en: 'join approval',
      uk: 'схвалення вступу',
      es: 'aprobacion de entrada',
      pt: 'aprovacao de entrada',
      ptBr: 'aprovacao de entrada',
      fr: 'approbation d adhesion',
      de: 'Beitrittsfreigabe',
    ),
    'slow_mode' => 'slow mode',
    'chat_history_visible' => _roomEventText(
      localeTag,
      ru: 'видимость истории',
      en: 'chat history visibility',
      uk: 'видимість історії',
      es: 'visibilidad del historial',
      pt: 'visibilidade do historico',
      ptBr: 'visibilidade do historico',
      fr: 'visibilite de l historique',
      de: 'Sichtbarkeit des Chatverlaufs',
    ),
    _ => key,
  };
}

String? _systemEventRoleLabel(String role, {required String localeTag}) {
  return switch (role) {
    'admin' => _roomEventText(
      localeTag,
      ru: 'администратором',
      en: 'an admin',
      uk: 'адміністратором',
      es: 'administrador',
      pt: 'administrador',
      ptBr: 'administrador',
      fr: 'administrateur',
      de: 'einem Administrator',
    ),
    'moderator' => _roomEventText(
      localeTag,
      ru: 'модератором',
      en: 'a moderator',
      uk: 'модератором',
      es: 'moderador',
      pt: 'moderador',
      ptBr: 'moderador',
      fr: 'moderateur',
      de: 'einem Moderator',
    ),
    'member' => _roomEventText(
      localeTag,
      ru: 'обычным участником',
      en: 'a member',
      uk: 'учасником',
      es: 'miembro',
      pt: 'membro',
      ptBr: 'membro',
      fr: 'membre',
      de: 'einem Mitglied',
    ),
    'restricted' => _roomEventText(
      localeTag,
      ru: 'ограниченным участником',
      en: 'a restricted member',
      uk: 'учасником з обмеженнями',
      es: 'miembro restringido',
      pt: 'membro restrito',
      ptBr: 'membro restrito',
      fr: 'membre restreint',
      de: 'einem eingeschraenkten Mitglied',
    ),
    'guest' => _roomEventText(
      localeTag,
      ru: 'участником только для чтения',
      en: 'a read-only member',
      uk: 'учасником лише для читання',
      es: 'miembro de solo lectura',
      pt: 'membro apenas leitura',
      ptBr: 'membro somente leitura',
      fr: 'membre en lecture seule',
      de: 'einem Nur-Lesen-Mitglied',
    ),
    _ => null,
  };
}

String _participantLabel({
  required String localeTag,
  required _ParticipantCase participantCase,
  String? selfProfileId,
  String? profileId,
  String? displayName,
}) {
  final cleanedSelfProfileId = (selfProfileId ?? '').trim();
  final cleanedProfileId = (profileId ?? '').trim();
  if (cleanedSelfProfileId.isNotEmpty &&
      cleanedProfileId == cleanedSelfProfileId) {
    return switch (participantCase) {
      _ParticipantCase.subject => _roomEventText(
        localeTag,
        ru: 'Вы',
        en: 'You',
        uk: 'Ви',
        es: 'Tu',
        pt: 'Voce',
        ptBr: 'Voce',
        fr: 'Vous',
        de: 'Du',
      ),
      _ParticipantCase.object => _roomEventText(
        localeTag,
        ru: 'вас',
        en: 'you',
        uk: 'вас',
        es: 'ti',
        pt: 'voce',
        ptBr: 'voce',
        fr: 'vous',
        de: 'dich',
      ),
      _ParticipantCase.to => _roomEventText(
        localeTag,
        ru: 'вам',
        en: 'you',
        uk: 'вам',
        es: 'ti',
        pt: 'voce',
        ptBr: 'voce',
        fr: 'vous',
        de: 'dich',
      ),
    };
  }

  final cleanedDisplayName = (displayName ?? '').trim();
  if (cleanedDisplayName.isNotEmpty) {
    return cleanedDisplayName;
  }
  if (cleanedProfileId.isNotEmpty) {
    return cleanedProfileId;
  }
  return switch (participantCase) {
    _ParticipantCase.subject => _roomEventText(
      localeTag,
      ru: 'Кто-то',
      en: 'Someone',
      uk: 'Хтось',
      es: 'Alguien',
      pt: 'Alguem',
      ptBr: 'Alguem',
      fr: 'Quelqu un',
      de: 'Jemand',
    ),
    _ParticipantCase.object || _ParticipantCase.to => _roomEventText(
      localeTag,
      ru: 'этого участника',
      en: 'this member',
      uk: 'цього учасника',
      es: 'este miembro',
      pt: 'este membro',
      ptBr: 'este membro',
      fr: 'ce membre',
      de: 'dieses Mitglied',
    ),
  };
}
