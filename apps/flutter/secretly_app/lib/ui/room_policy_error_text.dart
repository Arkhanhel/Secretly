// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../l10n/app_localizations.dart';
import '../rooms/room_invite_failure.dart';
import '../rooms/room_policy_failure.dart';
import '../transport/relay_client.dart' show RelayHttpException;
import 'wave1_l10n.dart';

String _policyText(
  AppLocalizations l10n, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1TextForLocale(
    l10n.localeName,
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

/// Код отказа сервера по лимитам комнат (ответ 402), где бы он ни ехал:
/// в исключении реле, в обёртке правил комнаты или в отказе приглашения.
/// Раньше человек видел сам код — «group_member_limit_reached» (Л-1, 17.09).
String? roomLimitCodeOf(Object error) {
  final text = switch (error) {
    RoomPolicyFailure(:final message) => message,
    RoomInviteFailure(:final message) => message ?? '',
    RelayHttpException(:final responseBody, :final message) =>
      '${responseBody ?? ''} $message',
    _ => error.toString(),
  };
  for (final code in const <String>[
    'group_member_limit_reached',
    'group_join_limit_reached',
    'group_create_limit_reached',
  ]) {
    if (text.contains(code)) return code;
  }
  return null;
}

/// Понятный текст отказа по лимитам комнат, или null.
String? roomLimitErrorText(AppLocalizations l10n, Object error) {
  switch (roomLimitCodeOf(error)) {
    case 'group_member_limit_reached':
      return _policyText(
        l10n,
        ru: 'Комната заполнена — больше участников сейчас добавить нельзя. Комнаты растут дальше, когда у всех участников свежая версия Secretly.',
        en: 'This room is full — no more members can join right now. Rooms can grow further once every member runs the latest Secretly.',
        uk: 'Кімната заповнена — більше учасників зараз додати не можна. Кімнати ростуть далі, коли в усіх учасників свіжа версія Secretly.',
        es: 'La sala esta llena: ahora no pueden entrar mas miembros. Las salas pueden crecer cuando todos usan la version mas reciente de Secretly.',
        pt: 'A sala esta cheia: nao e possivel adicionar mais membros agora. As salas podem crescer quando todos usarem a versao mais recente do Secretly.',
        ptBr: 'A sala esta cheia: nao e possivel adicionar mais membros agora. As salas podem crescer quando todos usarem a versao mais recente do Secretly.',
        fr: 'Ce salon est complet : impossible d ajouter des membres pour le moment. Il pourra grandir quand tous les membres auront la derniere version de Secretly.',
        de: 'Dieser Raum ist voll – gerade konnen keine weiteren Mitglieder beitreten. Raume wachsen weiter, sobald alle Mitglieder die neueste Secretly-Version nutzen.',
      );
    case 'group_join_limit_reached':
      return _policyText(
        l10n,
        ru: 'Вы уже состоите в наибольшем числе комнат. Выйдите из одной из них, чтобы вступить в новую.',
        en: 'You are already in the maximum number of rooms. Leave one to join another.',
        uk: 'Ви вже в найбільшій кількості кімнат. Вийдіть з однієї, щоб вступити в нову.',
        es: 'Ya estas en el numero maximo de salas. Sal de una para unirte a otra.',
        pt: 'Voce ja esta no numero maximo de salas. Saia de uma para entrar em outra.',
        ptBr: 'Voce ja esta no numero maximo de salas. Saia de uma para entrar em outra.',
        fr: 'Vous etes deja dans le nombre maximal de salons. Quittez-en un pour en rejoindre un autre.',
        de: 'Du bist bereits in der maximalen Anzahl von Raumen. Verlasse einen, um einem neuen beizutreten.',
      );
    case 'group_create_limit_reached':
      return _policyText(
        l10n,
        ru: 'Достигнут предел комнат, которые вы можете создать.',
        en: 'You have reached the limit of rooms you can create.',
        uk: 'Досягнуто межі кімнат, які ви можете створити.',
        es: 'Has alcanzado el limite de salas que puedes crear.',
        pt: 'Voce atingiu o limite de salas que pode criar.',
        ptBr: 'Voce atingiu o limite de salas que pode criar.',
        fr: 'Vous avez atteint la limite de salons que vous pouvez creer.',
        de: 'Du hast die Grenze fur Raume erreicht, die du erstellen kannst.',
      );
  }
  return null;
}

String? tryRoomPolicyErrorText(AppLocalizations l10n, Object error) {
  final limitText = roomLimitErrorText(l10n, error);
  if (limitText != null) {
    return limitText;
  }
  if (error is! RoomPolicyFailure) {
    return null;
  }

  switch (error.code) {
    case RoomPolicyFailureCode.notMember:
      return l10n.roomPolicyNotMember;
    case RoomPolicyFailureCode.adminOnly:
      return l10n.roomPolicyAdminsOnly;
    case RoomPolicyFailureCode.moderationOnly:
      return _policyText(
        l10n,
        ru: 'Только владельцы, администраторы и модераторы могут делать это в комнате.',
        en: 'Only room owners, admins, and moderators can do that in this room.',
        uk: 'Лише власники, адміністратори і модератори можуть робити це в кімнаті.',
        es: 'Solo propietarios, administradores y moderadores pueden hacer eso en esta sala.',
        pt: 'So proprietarios, administradores e moderadores podem fazer isso nesta sala.',
        fr: 'Seuls les proprietaires, admins et moderateurs peuvent faire cela dans ce salon.',
        de: 'Nur Besitzer, Admins und Moderatoren konnen das in diesem Raum tun.',
      );
    case RoomPolicyFailureCode.serviceUnavailable:
      return _policyText(
        l10n,
        ru: 'Сервис комнат сейчас недоступен. Повторите действие после восстановления relay.',
        en: 'Room service is unavailable right now. Try again when the relay reconnects.',
        uk: 'Сервіс кімнат зараз недоступний. Повторіть після відновлення relay.',
        es: 'El servicio de salas no esta disponible ahora. Intentalo cuando el relay se reconecte.',
        pt: 'O servico de salas esta indisponivel agora. Tente quando o relay voltar.',
        fr: 'Le service des salons est indisponible. Reessayez quand le relais se reconnecte.',
        de: 'Der Raumdienst ist gerade nicht verfugbar. Versuche es erneut, wenn der Relay neu verbindet.',
      );
    case RoomPolicyFailureCode.transportBlocked:
      return error.message;
    case RoomPolicyFailureCode.textMessagesDisabled:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может отправлять текстовые сообщения в этой комнате.',
        en: 'Your role cannot send text messages in this room.',
        uk: 'Ваша роль не може надсилати текстові повідомлення в цій кімнаті.',
        es: 'Tu rol no puede enviar mensajes de texto en esta sala.',
        pt: 'A sua funcao nao pode enviar mensagens de texto nesta sala.',
        ptBr: 'Sua funcao nao pode enviar mensagens de texto nesta sala.',
        fr: 'Votre role ne peut pas envoyer de messages texte dans ce salon.',
        de: 'Deine Rolle kann in diesem Raum keine Textnachrichten senden.',
      );
    case RoomPolicyFailureCode.mediaDisabled:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может отправлять медиа в этой комнате.',
        en: 'Your role cannot send media in this room.',
        uk: 'Ваша роль не може надсилати медіа в цій кімнаті.',
        es: 'Tu rol no puede enviar multimedia en esta sala.',
        pt: 'A sua funcao nao pode enviar media nesta sala.',
        ptBr: 'Sua funcao nao pode enviar midia nesta sala.',
        fr: 'Votre role ne peut pas envoyer de medias dans ce salon.',
        de: 'Deine Rolle kann in diesem Raum keine Medien senden.',
      );
    case RoomPolicyFailureCode.reactionsDisabled:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может использовать реакции в этой комнате.',
        en: 'Your role cannot use reactions in this room.',
        uk: 'Ваша роль не може використовувати реакції в цій кімнаті.',
        es: 'Tu rol no puede usar reacciones en esta sala.',
        pt: 'A sua funcao nao pode usar reacoes nesta sala.',
        fr: 'Votre role ne peut pas utiliser de reactions dans ce salon.',
        de: 'Deine Rolle kann in diesem Raum keine Reaktionen verwenden.',
      );
    case RoomPolicyFailureCode.reactionNotAllowed:
      return l10n.roomPolicyReactionNotAllowed;
    case RoomPolicyFailureCode.slowModeActive:
      return l10n.roomPolicySlowMode(error.retryAfterSeconds ?? 0);
    case RoomPolicyFailureCode.addMembersDenied:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может добавлять участников в эту комнату.',
        en: 'Your role cannot add participants to this room.',
        uk: 'Ваша роль не може додавати учасників до цієї кімнати.',
        es: 'Tu rol no puede agregar participantes a esta sala.',
        pt: 'A sua funcao nao pode adicionar participantes a esta sala.',
        fr: 'Votre role ne peut pas ajouter de participants a ce salon.',
        de: 'Deine Rolle kann diesem Raum keine Teilnehmer hinzufugen.',
      );
    case RoomPolicyFailureCode.pinMessagesDenied:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может закреплять сообщения в этой комнате.',
        en: 'Your role cannot pin messages in this room.',
        uk: 'Ваша роль не може закріплювати повідомлення в цій кімнаті.',
        es: 'Tu rol no puede fijar mensajes en esta sala.',
        pt: 'A sua funcao nao pode fixar mensagens nesta sala.',
        fr: 'Votre role ne peut pas epingler de messages dans ce salon.',
        de: 'Deine Rolle kann in diesem Raum keine Nachrichten anheften.',
      );
    case RoomPolicyFailureCode.groupInfoChangeDenied:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может изменять профиль группы.',
        en: 'Your role cannot change the group profile.',
        uk: 'Ваша роль не може змінювати профіль групи.',
        es: 'Tu rol no puede cambiar el perfil del grupo.',
        pt: 'A sua funcao nao pode alterar o perfil do grupo.',
        fr: 'Votre role ne peut pas modifier le profil du groupe.',
        de: 'Deine Rolle kann das Gruppenprofil nicht andern.',
      );
    case RoomPolicyFailureCode.changeOwnTagDenied:
      return _policyText(
        l10n,
        ru: 'Ваша роль не может изменять ваш тег в этой комнате.',
        en: 'Your role cannot change your room tag in this room.',
        uk: 'Ваша роль не може змінювати ваш тег у цій кімнаті.',
        es: 'Tu rol no puede cambiar tu etiqueta en esta sala.',
        pt: 'A sua funcao nao pode alterar a sua etiqueta nesta sala.',
        ptBr: 'Sua funcao nao pode alterar sua tag nesta sala.',
        fr: 'Votre role ne peut pas modifier votre tag dans ce salon.',
        de: 'Deine Rolle kann dein Raum-Tag in diesem Raum nicht andern.',
      );
    case RoomPolicyFailureCode.invalidOwnTag:
      return _policyText(
        l10n,
        ru: 'Тег комнаты должен быть не длиннее 32 символов и не содержать управляющие символы.',
        en: 'Room tag must be 32 characters or fewer and cannot contain control characters.',
        uk: 'Тег кімнати має бути не довшим за 32 символи і без керівних символів.',
        es: 'La etiqueta de sala debe tener 32 caracteres o menos y no contener caracteres de control.',
        pt: 'A etiqueta da sala deve ter 32 caracteres ou menos e nao conter caracteres de controlo.',
        ptBr:
            'A tag da sala deve ter 32 caracteres ou menos e nao conter caracteres de controle.',
        fr: 'Le tag du salon doit avoir 32 caracteres maximum et ne peut pas contenir de caracteres de controle.',
        de: 'Das Raum-Tag darf hochstens 32 Zeichen lang sein und keine Steuerzeichen enthalten.',
      );
    case RoomPolicyFailureCode.noRecipients:
      return _policyText(
        l10n,
        ru: 'В комнате нет активных участников, которым можно доставить сообщение.',
        en: 'No active participants are available to receive this message yet.',
        uk: 'У кімнаті немає активних учасників для доставки повідомлення.',
        es: 'No hay participantes activos para recibir este mensaje todavia.',
        pt: 'Ainda nao ha participantes ativos para receber esta mensagem.',
        ptBr: 'Ainda nao ha participantes ativos para receber esta mensagem.',
        fr: 'Aucun participant actif ne peut encore recevoir ce message.',
        de: 'Es sind noch keine aktiven Teilnehmer verfugbar, um diese Nachricht zu erhalten.',
      );
    case RoomPolicyFailureCode.allRecipientsUnavailable:
      return _policyText(
        l10n,
        ru: 'Не удалось доставить сообщение: устройства участников сейчас недоступны.',
        en: 'Message could not be delivered: no participant devices are reachable right now.',
        uk: 'Не вдалося доставити повідомлення: пристрої учасників зараз недоступні.',
        es: 'No se pudo entregar el mensaje: ningun dispositivo de los participantes esta accesible.',
        pt: 'Nao foi possivel entregar a mensagem: nenhum dispositivo dos participantes esta acessivel.',
        ptBr:
            'Nao foi possivel entregar a mensagem: nenhum dispositivo dos participantes esta acessivel.',
        fr: 'Le message n a pas pu etre livre: aucun appareil de participant n est joignable.',
        de: 'Nachricht konnte nicht zugestellt werden: kein Teilnehmergerat ist erreichbar.',
      );
    case RoomPolicyFailureCode.generic:
      return error.message;
  }
}

String roomPolicyErrorText(AppLocalizations l10n, Object error) {
  return tryRoomPolicyErrorText(l10n, error) ??
      l10n.actionFailed(error.toString());
}
