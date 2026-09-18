// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../entitlements/feature_gate.dart';
import '../rooms/room_invite_failure.dart';
import 'chat_screen.dart';
import 'paywall_screen.dart';
import 'room_policy_error_text.dart' show roomLimitErrorText;
import 'l10n.dart';
import '../billing/show_paywall.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_top_bar.dart';

class RoomInviteJoinScreen extends StatefulWidget {
  const RoomInviteJoinScreen({
    super.key,
    required this.controller,
    required this.target,
    this.onJoined,
  });

  final AppController controller;
  final RoomInviteTarget target;

  /// Чем открыть комнату после входа.
  ///
  /// Не задан — прежнее поведение телефона: экран заменяет себя на `ChatScreen`.
  /// Компьютер передаёт свой обработчик: там комната открывается в панели, а
  /// не отдельным экраном поверх окна.
  final Future<void> Function(String groupId)? onJoined;

  @override
  State<RoomInviteJoinScreen> createState() => _RoomInviteJoinScreenState();
}

class _RoomInviteJoinScreenState extends State<RoomInviteJoinScreen> {
  late Future<RoomInvitePreview> _previewFuture;
  bool _joining = false;

  String _t({
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

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.controller.resolveRoomInviteTarget(widget.target);
  }

  void _retryResolve() {
    setState(() {
      _previewFuture = widget.controller.resolveRoomInviteTarget(widget.target);
    });
  }

  Future<void> _openRoom(String groupId) async {
    final openInHost = widget.onJoined;
    if (openInHost != null) {
      Navigator.of(context).pop();
      await openInHost(groupId);
      return;
    }
    final title = await widget.controller.resolveConvoTitle(groupId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: groupId,
          title: title,
        ),
      ),
    );
  }

  Future<void> _join(RoomInvitePreview preview) async {
    if (_joining) return;
    final joinRequestSentText = _t(
      ru: 'Запрос отправлен. Вы войдёте после одобрения.',
      en: 'Join request sent. You will join after approval.',
      uk: 'Запит надіслано. Ви увійдете після схвалення.',
      es: 'Solicitud enviada. Entraras tras la aprobacion.',
      pt: 'Pedido enviado. Voce entrara apos a aprovacao.',
      ptBr: 'Pedido enviado. Voce entrara apos a aprovacao.',
      fr: 'Demande envoyée. Vous rejoindrez après approbation.',
      de: 'Anfrage gesendet. Sie treten nach der Genehmigung bei.',
    );
    setState(() {
      _joining = true;
    });
    try {
      final outcome = preview.isAlreadyMember
          ? RoomInviteJoinOutcome(
              groupId: preview.groupId,
              groupTitle: preview.groupTitle,
              disposition: RoomInviteJoinDisposition.active,
            )
          : await widget.controller.joinRoomViaInvite(
              widget.target,
              preview: preview,
            );
      if (!mounted) return;
      if (outcome.opensRoom) {
        await _openRoom(outcome.groupId);
        return;
      }
      setState(() {
        _previewFuture = Future.value(
          preview.copyWith(
            viewerMembershipStatus: RoomMembershipStatus.pending,
          ),
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(joinRequestSentText)));
    } on FeatureLockedException {
      // Free profile hit the joined-groups cap — show the paywall. No
      // membership change happened (the gate runs before redeeming the invite).
      if (!mounted) return;
      await showPaywall(context, PaywallTrigger.group);
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  String _errorText(Object error) {
    // Л-1 (17.09.2026): отказ по лимиту — понятным текстом, а не кодом сервера.
    final limitText = roomLimitErrorText(context.l10n, error);
    if (limitText != null) {
      return limitText;
    }
    if (error is RoomInviteFailure) {
      switch (error.code) {
        case RoomInviteFailureCode.invalidLink:
          return _t(
            ru: 'Ссылка-приглашение повреждена или неполная.',
            en: 'This invite link is invalid or incomplete.',
            uk: 'Посилання-запрошення пошкоджене або неповне.',
            es: 'Este enlace de invitacion no es valido o esta incompleto.',
            pt: 'Este link de convite e invalido ou incompleto.',
            ptBr: 'Este link de convite e invalido ou incompleto.',
            fr: 'Ce lien d invitation est invalide ou incomplet.',
            de: 'Dieser Einladungslink ist ungültig oder unvollständig.',
          );
        case RoomInviteFailureCode.inviteNotFound:
          return _t(
            ru: 'Создатель ссылки не смог подтвердить это приглашение.',
            en: 'The link creator could not confirm this invite.',
            uk: 'Автор посилання не зміг підтвердити це запрошення.',
            es: 'El creador del enlace no pudo confirmar esta invitacion.',
            pt: 'O criador do link nao conseguiu confirmar este convite.',
            ptBr: 'O criador do link nao conseguiu confirmar este convite.',
            fr: 'Le createur du lien na pas pu confirmer cette invitation.',
            de: 'Der Linkersteller konnte diese Einladung nicht bestätigen.',
          );
        case RoomInviteFailureCode.inviteRevoked:
          return _t(
            ru: 'Это приглашение уже отозвано.',
            en: 'This invite has already been revoked.',
            uk: 'Це запрошення вже відкликано.',
            es: 'Esta invitacion ya fue revocada.',
            pt: 'Este convite ja foi revogado.',
            ptBr: 'Este convite ja foi revogado.',
            fr: 'Cette invitation a deja ete revoquee.',
            de: 'Diese Einladung wurde bereits widerrufen.',
          );
        case RoomInviteFailureCode.inviteExpired:
          return _t(
            ru: 'Срок действия этой ссылки-приглашения уже истёк.',
            en: 'This invite link has already expired.',
            uk: 'Термін дії цього посилання-запрошення вже минув.',
            es: 'Este enlace de invitacion ya expiro.',
            pt: 'Este link de convite ja expirou.',
            ptBr: 'Este link de convite ja expirou.',
            fr: 'Ce lien d invitation a deja expire.',
            de: 'Dieser Einladungslink ist bereits abgelaufen.',
          );
        case RoomInviteFailureCode.inviteUsageLimitReached:
          return _t(
            ru: 'Лимит вступлений по этой ссылке уже исчерпан.',
            en: 'This invite link already reached its join limit.',
            uk: 'Ліміт вступів за цим посиланням уже вичерпано.',
            es: 'Este enlace ya alcanzo su limite de ingresos.',
            pt: 'Este link ja atingiu o limite de entradas.',
            ptBr: 'Este link ja atingiu o limite de entradas.',
            fr: 'Ce lien a deja atteint sa limite d utilisations.',
            de: 'Dieser Link hat sein Beitrittslimit erreicht.',
          );
        case RoomInviteFailureCode.inviteCreatorUnavailable:
          return _t(
            ru: 'Создатель ссылки сейчас недоступен. Попробуйте позже.',
            en: 'The invite creator is unavailable right now. Try again later.',
            uk: 'Автор посилання зараз недоступний. Спробуйте пізніше.',
            es: 'El creador del enlace no esta disponible ahora. Intentalo mas tarde.',
            pt: 'O criador do link esta indisponivel agora. Tente mais tarde.',
            ptBr:
                'O criador do link esta indisponivel agora. Tente mais tarde.',
            fr: 'Le createur du lien est indisponible. Reessayez plus tard.',
            de: 'Der Linkersteller ist gerade nicht verfügbar. Versuchen Sie es später erneut.',
          );
        case RoomInviteFailureCode.previewTimedOut:
          return _t(
            ru: 'Не удалось загрузить данные комнаты вовремя.',
            en: 'Timed out while loading room details.',
            uk: 'Не вдалося вчасно завантажити дані кімнати.',
            es: 'Se agoto el tiempo al cargar los detalles de la sala.',
            pt: 'Tempo esgotado ao carregar os detalhes da sala.',
            ptBr: 'Tempo esgotado ao carregar os detalhes da sala.',
            fr: 'Delai depasse pendant le chargement du salon.',
            de: 'Zeitüberschreitung beim Laden der Raumdetails.',
          );
        case RoomInviteFailureCode.joinTimedOut:
          return _t(
            ru: 'Подтверждение входа заняло слишком много времени.',
            en: 'Timed out while waiting for the join confirmation.',
            uk: 'Підтвердження входу тривало занадто довго.',
            es: 'Se agoto el tiempo esperando la confirmacion de ingreso.',
            pt: 'Tempo esgotado aguardando a confirmacao de entrada.',
            ptBr: 'Tempo esgotado aguardando a confirmacao de entrada.',
            fr: 'Delai depasse en attendant la confirmation.',
            de: 'Zeitüberschreitung beim Warten auf die Bestätigung.',
          );
        case RoomInviteFailureCode.banned:
          return _t(
            ru: 'Вы были заблокированы в этой комнате.',
            en: 'You are banned from this room.',
            uk: 'Вас заблоковано в цій кімнаті.',
            es: 'Tienes bloqueado el acceso a esta sala.',
            pt: 'Voce esta bloqueado nesta sala.',
            ptBr: 'Voce esta bloqueado nesta sala.',
            fr: 'Vous etes bloque dans ce salon.',
            de: 'Sie sind in diesem Raum gesperrt.',
          );
        case RoomInviteFailureCode.generic:
          break;
      }
    }
    final fallback = error.toString().trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return _t(
      ru: 'Не удалось открыть приглашение.',
      en: 'Unable to open this invite.',
      uk: 'Не вдалося відкрити запрошення.',
      es: 'No se pudo abrir esta invitacion.',
      pt: 'Nao foi possivel abrir este convite.',
      ptBr: 'Nao foi possivel abrir este convite.',
      fr: 'Impossible d ouvrir cette invitation.',
      de: 'Diese Einladung konnte nicht geöffnet werden.',
    );
  }

  String _historyText(RoomInvitePreview preview) {
    if (preview.chatHistoryVisible) {
      return _t(
        ru: 'Новые участники видят историю комнаты.',
        en: 'New members can see the room history.',
        uk: 'Нові учасники бачать історію кімнати.',
        es: 'Los nuevos miembros pueden ver el historial de la sala.',
        pt: 'Novos membros podem ver o historico da sala.',
        ptBr: 'Novos membros podem ver o historico da sala.',
        fr: 'Les nouveaux membres peuvent voir l historique du salon.',
        de: 'Neue Mitglieder können den Raumverlauf sehen.',
      );
    }
    return _t(
      ru: 'Новые участники начинают без прошлой истории сообщений.',
      en: 'New members start without previous message history.',
      uk: 'Нові учасники починають без попередньої історії повідомлень.',
      es: 'Los nuevos miembros empiezan sin historial de mensajes previo.',
      pt: 'Novos membros entram sem historico anterior de mensagens.',
      ptBr: 'Novos membros entram sem historico anterior de mensagens.',
      fr: 'Les nouveaux membres commencent sans ancien historique de messages.',
      de: 'Neue Mitglieder starten ohne bisherigen Nachrichtenverlauf.',
    );
  }

  String _joinModeText(RoomInvitePreview preview) {
    if (preview.isJoinRequestPending) {
      return _t(
        ru: 'Ваш запрос уже ожидает одобрения.',
        en: 'Your join request is already pending approval.',
        uk: 'Ваш запит уже очікує схвалення.',
        es: 'Tu solicitud ya espera aprobacion.',
        pt: 'Seu pedido ja esta aguardando aprovacao.',
        ptBr: 'Seu pedido ja esta aguardando aprovacao.',
        fr: 'Votre demande attend deja une approbation.',
        de: 'Ihre Beitrittsanfrage wartet bereits auf Genehmigung.',
      );
    }
    if (preview.isBanned) {
      return _t(
        ru: 'Для этого профиля доступ в комнату закрыт.',
        en: 'This profile cannot join the room.',
        uk: 'Для цього профілю доступ до кімнати закрито.',
        es: 'Este perfil no puede unirse a la sala.',
        pt: 'Este perfil nao pode entrar na sala.',
        ptBr: 'Este perfil nao pode entrar na sala.',
        fr: 'Ce profil ne peut pas rejoindre le salon.',
        de: 'Dieses Profil kann dem Raum nicht beitreten.',
      );
    }
    if (preview.joinApprovalRequired) {
      return _t(
        ru: 'Новые участники вступают только после одобрения запроса.',
        en: 'New members join only after the request is approved.',
        uk: 'Нові учасники входять лише після схвалення запиту.',
        es: 'Los nuevos miembros entran solo despues de aprobar la solicitud.',
        pt: 'Novos membros entram apenas apos a aprovacao do pedido.',
        ptBr: 'Novos membros entram apenas apos a aprovacao do pedido.',
        fr: 'Les nouveaux membres rejoignent seulement apres approbation.',
        de: 'Neue Mitglieder treten erst nach Genehmigung der Anfrage bei.',
      );
    }
    return _t(
      ru: 'По этой ссылке можно вступить сразу.',
      en: 'This invite link allows immediate access.',
      uk: 'За цим посиланням можна увійти одразу.',
      es: 'Este enlace permite acceso inmediato.',
      pt: 'Este link permite acesso imediato.',
      ptBr: 'Este link permite acesso imediato.',
      fr: 'Ce lien permet un acces immediat.',
      de: 'Dieser Einladungslink erlaubt direkten Zugriff.',
    );
  }

  RoomMemberRole _effectiveJoinRole(RoomMemberRole role) {
    return switch (role) {
      RoomMemberRole.owner ||
      RoomMemberRole.admin ||
      RoomMemberRole.moderator => RoomMemberRole.member,
      RoomMemberRole.member ||
      RoomMemberRole.restricted ||
      RoomMemberRole.guest => role,
    };
  }

  String _joinRoleText(RoomInvitePreview preview) {
    final roleText = switch (_effectiveJoinRole(preview.allowedRole)) {
      RoomMemberRole.member => _t(
        ru: 'участника',
        en: 'member',
        uk: 'учасник',
        es: 'miembro',
        pt: 'membro',
        fr: 'membre',
        de: 'Mitglied',
      ),
      RoomMemberRole.restricted => _t(
        ru: 'ограниченного участника',
        en: 'restricted member',
        uk: 'учасник з обмеженнями',
        es: 'miembro restringido',
        pt: 'membro restrito',
        fr: 'membre restreint',
        de: 'eingeschränktes Mitglied',
      ),
      RoomMemberRole.guest => _t(
        ru: 'только чтение',
        en: 'read-only member',
        uk: 'лише читання',
        es: 'miembro de solo lectura',
        pt: 'membro somente leitura',
        fr: 'membre en lecture seule',
        de: 'Mitglied mit Lesezugriff',
      ),
      RoomMemberRole.owner ||
      RoomMemberRole.admin ||
      RoomMemberRole.moderator => _t(
        ru: 'участника',
        en: 'member',
        uk: 'учасник',
        es: 'miembro',
        pt: 'membro',
        fr: 'membre',
        de: 'Mitglied',
      ),
    };
    return _t(
      ru: 'Роль после входа: $roleText.',
      en: 'Join role: $roleText.',
      uk: 'Роль після входу: $roleText.',
      es: 'Rol al entrar: $roleText.',
      pt: 'Funcao ao entrar: $roleText.',
      ptBr: 'Funcao ao entrar: $roleText.',
      fr: 'Role apres entree : $roleText.',
      de: 'Rolle nach Beitritt: $roleText.',
    );
  }

  String _linkUsageText(RoomInvitePreview preview) {
    final maxUses = preview.maxUses;
    final remainingUses = preview.remainingUses;
    if (maxUses == null || remainingUses == null) {
      return _t(
        ru: 'Количество вступлений по этой ссылке не ограничено.',
        en: 'This link has unlimited joins.',
        uk: 'Кількість вступів за цим посиланням не обмежена.',
        es: 'Este enlace no limita el numero de ingresos.',
        pt: 'Este link tem entradas ilimitadas.',
        ptBr: 'Este link tem entradas ilimitadas.',
        fr: 'Ce lien permet un nombre illimite d entrees.',
        de: 'Dieser Link erlaubt unbegrenzt viele Beitritte.',
      );
    }
    return _t(
      ru: 'Осталось использований: $remainingUses из $maxUses.',
      en: 'Uses left: $remainingUses of $maxUses.',
      uk: 'Залишилося використань: $remainingUses з $maxUses.',
      es: 'Usos restantes: $remainingUses de $maxUses.',
      pt: 'Usos restantes: $remainingUses de $maxUses.',
      ptBr: 'Usos restantes: $remainingUses de $maxUses.',
      fr: 'Utilisations restantes : $remainingUses sur $maxUses.',
      de: 'Verbleibende Nutzungen: $remainingUses von $maxUses.',
    );
  }

  String _expiryText(RoomInvitePreview preview) {
    final expiresAtMs = preview.expiresAtMs;
    if (expiresAtMs == null) {
      return _t(
        ru: 'Ссылка не ограничена по времени.',
        en: 'This link does not expire by time.',
        uk: 'Посилання не має обмеження за часом.',
        es: 'Este enlace no caduca por tiempo.',
        pt: 'Este link nao expira por tempo.',
        ptBr: 'Este link nao expira por tempo.',
        fr: 'Ce lien n expire pas dans le temps.',
        de: 'Dieser Link läuft zeitlich nicht ab.',
      );
    }
    final material = MaterialLocalizations.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(expiresAtMs).toLocal();
    final dateText = material.formatShortDate(date);
    final timeText = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return _t(
      ru: 'Ссылка действует до $dateText, $timeText.',
      en: 'This link is valid until $dateText, $timeText.',
      uk: 'Посилання діє до $dateText, $timeText.',
      es: 'Este enlace es valido hasta $dateText, $timeText.',
      pt: 'Este link e valido ate $dateText, $timeText.',
      ptBr: 'Este link e valido ate $dateText, $timeText.',
      fr: 'Ce lien est valide jusqu au $dateText, $timeText.',
      de: 'Dieser Link ist gültig bis $dateText, $timeText.',
    );
  }

  Widget _buildPreviewAvatar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RoomInvitePreview preview,
  ) {
    ImageProvider<Object>? imageProvider;
    final avatarPath = (preview.avatarPath ?? '').trim();
    if (avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
      }
    }
    final avatarBytes = preview.avatarBytes;
    if (imageProvider == null &&
        avatarBytes != null &&
        avatarBytes.isNotEmpty) {
      imageProvider = MemoryImage(avatarBytes);
    }

    final seed =
        ((preview.avatarHash ?? '').trim().isNotEmpty
                ? (preview.avatarHash ?? '').trim()
                : preview.groupId)
            .trim();
    if (imageProvider != null) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: imageProvider,
      );
    }
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 34,
      seed: seed,
      displayName: preview.groupTitle,
      fallbackId: preview.groupId,
      labelStyle: theme.textTheme.titleMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _t(
            ru: 'Приглашение в комнату',
            en: 'Room invite',
            uk: 'Запрошення до кімнати',
            es: 'Invitacion a sala',
            pt: 'Convite de sala',
            fr: 'Invitation au salon',
            de: 'Raum-Einladung',
          ),
        ),
      ),
      body: FutureBuilder<RoomInvitePreview>(
        future: _previewFuture,
        builder: (context, snapshot) {
          Widget child;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = _InviteStateCard(
              icon: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
              title: _t(
                ru: 'Проверяем приглашение…',
                en: 'Checking invite…',
                uk: 'Перевіряємо запрошення…',
                es: 'Comprobando invitacion…',
                pt: 'Verificando convite…',
                fr: 'Verification de l invitation…',
                de: 'Einladung wird geprüft…',
              ),
              body: _t(
                ru: 'Загружаем сведения о комнате у создателя ссылки.',
                en: 'Loading room details from the link creator.',
                uk: 'Завантажуємо відомості про кімнату від автора посилання.',
                es: 'Cargando detalles de la sala desde el creador del enlace.',
                pt: 'Carregando detalhes da sala pelo criador do link.',
                ptBr: 'Carregando detalhes da sala pelo criador do link.',
                fr: 'Chargement des details du salon depuis le createur du lien.',
                de: 'Raumdetails werden vom Linkersteller geladen.',
              ),
            );
          } else if (snapshot.hasError) {
            child = _InviteStateCard(
              icon: Icon(
                Icons.link_off_rounded,
                size: 30,
                color: colorScheme.error,
              ),
              title: _t(
                ru: 'Приглашение недоступно',
                en: 'Invite unavailable',
                uk: 'Запрошення недоступне',
                es: 'Invitacion no disponible',
                pt: 'Convite indisponivel',
                fr: 'Invitation indisponible',
                de: 'Einladung nicht verfügbar',
              ),
              body: _errorText(snapshot.error!),
              footer: FilledButton.tonalIcon(
                onPressed: _retryResolve,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _t(
                    ru: 'Повторить',
                    en: 'Retry',
                    uk: 'Повторити',
                    es: 'Reintentar',
                    pt: 'Tentar novamente',
                    fr: 'Réessayer',
                    de: 'Erneut versuchen',
                  ),
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            child = _InviteStateCard(
              icon: Icon(
                Icons.groups_rounded,
                size: 30,
                color: colorScheme.primary,
              ),
              title: _t(
                ru: 'Комната не найдена',
                en: 'Room not found',
                uk: 'Кімнату не знайдено',
                es: 'Sala no encontrada',
                pt: 'Sala nao encontrada',
                fr: 'Salon introuvable',
                de: 'Raum nicht gefunden',
              ),
              body: _t(
                ru: 'Не удалось получить данные комнаты по этой ссылке.',
                en: 'Could not resolve a room for this invite link.',
                uk: 'Не вдалося отримати дані кімнати за цим посиланням.',
                es: 'No se pudo resolver una sala para este enlace.',
                pt: 'Nao foi possivel resolver uma sala para este link.',
                ptBr: 'Nao foi possivel resolver uma sala para este link.',
                fr: 'Impossible de trouver un salon pour ce lien.',
                de: 'Für diesen Einladungslink konnte kein Raum gefunden werden.',
              ),
            );
          } else {
            final preview = snapshot.data!;
            final description = (preview.description ?? '').trim();
            final actionLabel = preview.isAlreadyMember
                ? _t(
                    ru: 'Открыть комнату',
                    en: 'Open room',
                    uk: 'Відкрити кімнату',
                    es: 'Abrir sala',
                    pt: 'Abrir sala',
                    fr: 'Ouvrir le salon',
                    de: 'Raum öffnen',
                  )
                : preview.isJoinRequestPending
                ? _t(
                    ru: 'Ожидает одобрения',
                    en: 'Pending approval',
                    uk: 'Очікує схвалення',
                    es: 'Pendiente de aprobacion',
                    pt: 'Aguardando aprovacao',
                    ptBr: 'Aguardando aprovacao',
                    fr: 'En attente d approbation',
                    de: 'Wartet auf Genehmigung',
                  )
                : preview.isBanned
                ? _t(
                    ru: 'Доступ закрыт',
                    en: 'Access blocked',
                    uk: 'Доступ закрито',
                    es: 'Acceso bloqueado',
                    pt: 'Acesso bloqueado',
                    fr: 'Accès bloqué',
                    de: 'Zugriff gesperrt',
                  )
                : _t(
                    ru: 'Вступить в комнату',
                    en: 'Join room',
                    uk: 'Увійти до кімнати',
                    es: 'Unirse a la sala',
                    pt: 'Entrar na sala',
                    fr: 'Rejoindre le salon',
                    de: 'Raum beitreten',
                  );
            final actionIcon = _joining
                ? null
                : preview.isAlreadyMember
                ? Icons.forum_rounded
                : preview.isJoinRequestPending
                ? Icons.hourglass_top_rounded
                : preview.isBanned
                ? Icons.block_rounded
                : Icons.login_rounded;
            final actionDisabled =
                _joining || preview.isJoinRequestPending || preview.isBanned;
            child = Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreviewAvatar(context, theme, colorScheme, preview),
                    const SizedBox(height: 18),
                    Text(
                      preview.groupTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description.isEmpty
                          ? _t(
                              ru: 'У этой комнаты пока нет описания.',
                              en: 'This room does not have a description yet.',
                              uk: 'У цієї кімнати поки немає опису.',
                              es: 'Esta sala aun no tiene descripcion.',
                              pt: 'Esta sala ainda nao tem descricao.',
                              ptBr: 'Esta sala ainda nao tem descricao.',
                              fr: 'Ce salon n a pas encore de description.',
                              de: 'Dieser Raum hat noch keine Beschreibung.',
                            )
                          : description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _InviteInfoRow(
                      icon: Icons.person_outline_rounded,
                      text: _t(
                        ru: 'Ссылку создал: ${preview.inviterDisplayName}',
                        en: 'Link created by ${preview.inviterDisplayName}',
                        uk: 'Посилання створив: ${preview.inviterDisplayName}',
                        es: 'Enlace creado por ${preview.inviterDisplayName}',
                        pt: 'Link criado por ${preview.inviterDisplayName}',
                        ptBr: 'Link criado por ${preview.inviterDisplayName}',
                        fr: 'Lien créé par ${preview.inviterDisplayName}',
                        de: 'Link erstellt von ${preview.inviterDisplayName}',
                      ),
                    ),
                    _InviteInfoRow(
                      icon: Icons.group_outlined,
                      text: _t(
                        ru: 'Участников: ${preview.memberCount}',
                        en: 'Members: ${preview.memberCount}',
                        uk: 'Учасників: ${preview.memberCount}',
                        es: 'Miembros: ${preview.memberCount}',
                        pt: 'Membros: ${preview.memberCount}',
                        fr: 'Membres : ${preview.memberCount}',
                        de: 'Mitglieder: ${preview.memberCount}',
                      ),
                    ),
                    _InviteInfoRow(
                      icon: Icons.history_toggle_off_rounded,
                      text: _historyText(preview),
                    ),
                    _InviteInfoRow(
                      icon: preview.joinApprovalRequired
                          ? Icons.admin_panel_settings_outlined
                          : Icons.flash_on_rounded,
                      text: _joinModeText(preview),
                    ),
                    _InviteInfoRow(
                      icon: Icons.shield_outlined,
                      text: _joinRoleText(preview),
                    ),
                    _InviteInfoRow(
                      icon: Icons.link_rounded,
                      text: _linkUsageText(preview),
                    ),
                    _InviteInfoRow(
                      icon: Icons.schedule_rounded,
                      text: _expiryText(preview),
                    ),
                    if (preview.isAlreadyMember) ...[
                      const SizedBox(height: 10),
                      Text(
                        _t(
                          ru: 'Вы уже состоите в этой комнате.',
                          en: 'You are already a member of this room.',
                          uk: 'Ви вже є учасником цієї кімнати.',
                          es: 'Ya eres miembro de esta sala.',
                          pt: 'Voce ja e membro desta sala.',
                          ptBr: 'Voce ja e membro desta sala.',
                          fr: 'Vous etes deja membre de ce salon.',
                          de: 'Sie sind bereits Mitglied dieses Raums.',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (preview.isJoinRequestPending) ...[
                      const SizedBox(height: 10),
                      Text(
                        _t(
                          ru: 'Повторно отправлять запрос не нужно. Откройте экран позже или дождитесь одобрения.',
                          en: 'No need to send another request. Reopen this screen later or wait for approval.',
                          uk: 'Повторно надсилати запит не потрібно. Відкрийте екран пізніше або дочекайтеся схвалення.',
                          es: 'No hace falta enviar otra solicitud. Vuelve a abrir esta pantalla mas tarde o espera la aprobacion.',
                          pt: 'Nao e necessario enviar outro pedido. Abra esta tela depois ou aguarde a aprovacao.',
                          ptBr:
                              'Nao e necessario enviar outro pedido. Abra esta tela depois ou aguarde a aprovacao.',
                          fr: 'Inutile d envoyer une autre demande. Rouvrez cet écran plus tard ou attendez l approbation.',
                          de: 'Sie müssen keine weitere Anfrage senden. Öffnen Sie diesen Bildschirm später erneut oder warten Sie auf die Genehmigung.',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (preview.isBanned) ...[
                      const SizedBox(height: 10),
                      Text(
                        _t(
                          ru: 'Этому профилю закрыт доступ на вступление в эту комнату.',
                          en: 'This profile has been blocked from joining this room.',
                          uk: 'Цьому профілю закрито доступ до вступу в цю кімнату.',
                          es: 'Este perfil tiene bloqueado el ingreso a esta sala.',
                          pt: 'Este perfil foi bloqueado para entrar nesta sala.',
                          ptBr:
                              'Este perfil foi bloqueado para entrar nesta sala.',
                          fr: 'Ce profil a ete bloque pour rejoindre ce salon.',
                          de: 'Dieses Profil wurde für den Beitritt zu diesem Raum gesperrt.',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: actionDisabled ? null : () => _join(preview),
                      icon: _joining
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(actionIcon),
                      label: Text(actionLabel),
                    ),
                    if (!preview.isAlreadyMember)
                      TextButton(
                        onPressed: _joining
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Text(
                          _t(
                            ru: 'Позже',
                            en: 'Later',
                            uk: 'Пізніше',
                            es: 'Mas tarde',
                            pt: 'Mais tarde',
                            fr: 'Plus tard',
                            de: 'Später',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 24,
              16,
              24,
            ),
            children: [child],
          );
        },
      ),
    );
  }
}

class _InviteStateCard extends StatelessWidget {
  const _InviteStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
  });

  final Widget icon;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 18), footer!],
          ],
        ),
      ),
    );
  }
}

class _InviteInfoRow extends StatelessWidget {
  const _InviteInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
