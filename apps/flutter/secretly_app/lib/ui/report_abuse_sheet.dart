// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'icons/app_icons.dart';
import 'support_request_utils.dart';
import 'wave1_l10n.dart';
import 'widgets/secretly_glass_sheet.dart';

enum ReportAbuseTargetType { profile, room }

enum ReportAbuseDeliveryMode { mailApp, clipboard }

class ReportAbuseTarget {
  const ReportAbuseTarget({
    required this.type,
    required this.id,
    required this.title,
    this.conversationId,
  });

  final ReportAbuseTargetType type;
  final String id;
  final String title;
  final String? conversationId;
}

class ReportAbuseResult {
  const ReportAbuseResult({
    required this.deliveryMode,
    required this.blockTarget,
  });

  final ReportAbuseDeliveryMode deliveryMode;
  final bool blockTarget;
}

class _ReportReason {
  const _ReportReason({
    required this.code,
    required this.icon,
    required this.enTitle,
    required this.ruTitle,
    required this.enSubtitle,
    required this.ruSubtitle,
    this.roomSpecific = false,
  });

  final String code;
  final IconData icon;
  final String enTitle;
  final String ruTitle;
  final String enSubtitle;
  final String ruSubtitle;
  final bool roomSpecific;

  String titleForLocale(String localeTag) {
    switch (code) {
      case 'spam_or_scam':
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Спам або шахрайство',
          es: 'Spam o fraude',
          pt: 'Spam ou fraude',
          fr: 'Spam ou arnaque',
          de: 'Spam oder Betrug',
        );
      case 'harassment_or_abuse':
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Переслідування або образи',
          es: 'Acoso o abuso',
          pt: 'Assedio ou abuso',
          fr: 'Harcelement ou abus',
          de: 'Belastigung oder Missbrauch',
        );
      case 'unsafe_or_illegal_content':
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Небезпечний або незаконний контент',
          es: 'Contenido inseguro o ilegal',
          pt: 'Conteudo inseguro ou ilegal',
          fr: 'Contenu dangereux ou illegal',
          de: 'Unsichere oder illegale Inhalte',
        );
      case 'impersonation':
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Видає себе за іншого',
          es: 'Suplantacion de identidad',
          pt: 'Falsa identidade',
          fr: 'Usurpation d identite',
          de: 'Gibt sich als jemand anderes aus',
        );
      case 'privacy_or_security':
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Проблема приватності або безпеки',
          es: 'Problema de privacidad o seguridad',
          pt: 'Problema de privacidade ou seguranca',
          fr: 'Probleme de confidentialite ou de securite',
          de: 'Datenschutz- oder Sicherheitsproblem',
        );
      default:
        return _reportTextForLocale(
          localeTag,
          ru: ruTitle,
          en: enTitle,
          uk: 'Інше',
          es: 'Otro',
          pt: 'Outro',
          fr: 'Autre',
          de: 'Sonstiges',
        );
    }
  }

  String subtitleForLocale(String localeTag) {
    if (code == 'spam_or_scam' && roomSpecific) {
      return _reportTextForLocale(
        localeTag,
        ru: ruSubtitle,
        en: enSubtitle,
        uk: 'Масові запрошення, фішинг або оманлива активність у кімнаті.',
        es: 'Invitaciones masivas, phishing o actividad enganosa en la sala.',
        pt: 'Convites em massa, phishing ou atividade enganosa na sala.',
        fr: 'Invitations massives, phishing ou activite trompeuse dans le salon.',
        de: 'Masseneinladungen, Phishing oder irrefuhrende Raumaktivitat.',
      );
    }
    switch (code) {
      case 'spam_or_scam':
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Небажані повідомлення, фішинг або оманлива поведінка.',
          es: 'Mensajes no deseados, phishing o comportamiento enganoso.',
          pt: 'Mensagens indesejadas, phishing ou comportamento enganoso.',
          fr: 'Messages indesirables, phishing ou comportement trompeur.',
          de: 'Unerwunschte Nachrichten, Phishing oder tauschendes Verhalten.',
        );
      case 'harassment_or_abuse':
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Погрози, цілеспрямовані образи або повторні небажані контакти.',
          es: 'Amenazas, abuso dirigido o contacto no deseado repetido.',
          pt: 'Ameacas, abuso direcionado ou contacto indesejado repetido.',
          ptBr: 'Ameacas, abuso direcionado ou contato indesejado repetido.',
          fr: 'Menaces, abus cibles ou contacts repetes non desires.',
          de: 'Drohungen, gezielter Missbrauch oder wiederholter unerwunschter Kontakt.',
        );
      case 'unsafe_or_illegal_content':
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Контент, який може порушувати правила безпеки або закон.',
          es: 'Contenido que puede infringir normas de seguridad o la ley.',
          pt: 'Conteudo que pode violar regras de seguranca ou a lei.',
          fr: 'Contenu pouvant enfreindre les regles de securite ou la loi.',
          de: 'Inhalte, die Sicherheitsregeln oder Gesetze verletzen konnten.',
        );
      case 'impersonation':
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Видає себе за іншу людину, команду або сервіс.',
          es: 'Finge ser otra persona, equipo o servicio.',
          pt: 'Finge ser outra pessoa, equipa ou servico.',
          ptBr: 'Finge ser outra pessoa, equipe ou servico.',
          fr: 'Pretend etre une autre personne, equipe ou service.',
          de: 'Gibt vor, eine andere Person, ein Team oder ein Dienst zu sein.',
        );
      case 'privacy_or_security':
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Витік персональних даних, підозрілі ключі або тиск щодо безпеки.',
          es: 'Datos personales filtrados, claves sospechosas o presion de seguridad.',
          pt: 'Dados pessoais expostos, chaves suspeitas ou pressao de seguranca.',
          fr: 'Donnees personnelles divulguees, cles suspectes ou pression de securite.',
          de: 'Offengelegte personliche Daten, verdachtige Schlussel oder Sicherheitsdruck.',
        );
      default:
        return _reportTextForLocale(
          localeTag,
          ru: ruSubtitle,
          en: enSubtitle,
          uk: 'Інша ситуація, яку має перевірити команда Secretly.',
          es: 'Otra situacion que el equipo de Secretly debe revisar.',
          pt: 'Outra situacao que a equipa Secretly deve rever.',
          ptBr: 'Outra situacao que a equipe Secretly deve revisar.',
          fr: 'Une autre situation que l equipe Secretly doit examiner.',
          de: 'Eine andere Situation, die das Secretly-Team prufen sollte.',
        );
    }
  }
}

String _reportText(
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

String _reportTextForLocale(
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
  return wave1TextForLocale(
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

String reportAbuseMenuLabel(BuildContext context) {
  // L10N FIX (2026-07-17): was ru/en only — every other locale showed
  // English "Report" on the contact and room profile menus.
  return _reportText(
    context,
    ru: 'Пожаловаться',
    en: 'Report',
    uk: 'Поскаржитися',
    es: 'Denunciar',
    pt: 'Denunciar',
    ptBr: 'Denunciar',
    fr: 'Signaler',
    de: 'Melden',
  );
}

String reportAbuseDeliveryMessage(
  BuildContext context,
  ReportAbuseResult result,
) {
  switch (result.deliveryMode) {
    case ReportAbuseDeliveryMode.mailApp:
      return _reportText(
        context,
        ru: 'Черновик отчета открыт в почте. Отправьте письмо, чтобы завершить жалобу.',
        en: 'Report draft opened in mail. Send it to submit the report.',
        uk: 'Чернетку звіту відкрито в пошті. Надішліть лист, щоб завершити скаргу.',
        es: 'El borrador del reporte se abrio en el correo. Envialo para enviar el reporte.',
        pt: 'O rascunho da denuncia abriu no email. Envie-o para concluir.',
        ptBr: 'O rascunho da denuncia abriu no email. Envie-o para concluir.',
        fr: 'Le brouillon du signalement est ouvert dans l email. Envoyez-le pour terminer.',
        de: 'Der Berichtsentwurf wurde in Mail geoffnet. Sende ihn, um die Meldung abzuschliessen.',
      );
    case ReportAbuseDeliveryMode.clipboard:
      return _reportText(
        context,
        ru: 'Не удалось открыть почту. Текст жалобы скопирован в буфер обмена.',
        en: 'Could not open mail. Report text copied to clipboard.',
        uk: 'Не вдалося відкрити пошту. Текст скарги скопійовано в буфер обміну.',
        es: 'No se pudo abrir el correo. El texto del reporte se copio al portapapeles.',
        pt: 'Nao foi possivel abrir o email. O texto da denuncia foi copiado.',
        ptBr:
            'Nao foi possivel abrir o email. O texto da denuncia foi copiado.',
        fr: 'Impossible d ouvrir l email. Le texte du signalement a ete copie.',
        de: 'Mail konnte nicht geoffnet werden. Der Meldungstext wurde kopiert.',
      );
  }
}

Future<ReportAbuseResult?> showReportAbuseSheet({
  required BuildContext context,
  required ReportAbuseTarget target,
  required String buildMarker,
  required String reporterDeviceId,
  required String reporterProfileId,
  Iterable<String> additionalTechnicalLines = const <String>[],
  bool allowBlockTarget = false,
  bool targetAlreadyBlocked = false,
}) async {
  final detailsController = TextEditingController();
  var selectedReasonCode = '';
  var blockTarget = false;
  var submitting = false;

  try {
    return await showModalBottomSheet<ReportAbuseResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final localeTag = wave1LocaleTagFromContext(sheetContext);
            final reasons = _reportReasons(target.type);
            final selectedReason = _findReason(reasons, selectedReasonCode);
            final details = detailsController.text.trim();
            final canSubmit =
                !submitting && (selectedReason != null || details.isNotEmpty);
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            Future<void> submit() async {
              final effectiveReason =
                  selectedReason ??
                  _ReportReason(
                    code: 'other',
                    icon: AppIcons.errorOutline,
                    enTitle: 'Other safety concern',
                    ruTitle: 'Другая проблема безопасности',
                    enSubtitle: 'The details explain the issue.',
                    ruSubtitle: 'Описание поясняет проблему.',
                  );
              setSheetState(() {
                submitting = true;
              });
              final result = await _sendReport(
                target: target,
                reason: effectiveReason,
                localeTag: localeTag,
                details: details,
                buildMarker: buildMarker,
                reporterDeviceId: reporterDeviceId,
                reporterProfileId: reporterProfileId,
                additionalTechnicalLines: additionalTechnicalLines,
                blockTarget: blockTarget,
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(result);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SecretlyGlassSheetSurface(
                // Лист и так во всю ширину; SafeArea внутри держит содержимое
                // над системной панелью, пока поверхность уходит за неё.
                flushToEdges: true,
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: SecretlyGlassSheetHandle()),
                          const SizedBox(height: 16),
                          _ReportHeader(target: target),
                          const SizedBox(height: 16),
                          Text(
                            _reportText(
                              sheetContext,
                              ru: 'Причина',
                              en: 'Reason',
                            ),
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          for (final reason in reasons) ...[
                            _ReasonTile(
                              reason: reason,
                              isSelected: reason.code == selectedReasonCode,
                              onTap: () {
                                setSheetState(() {
                                  selectedReasonCode = reason.code;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 6),
                          TextField(
                            controller: detailsController,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 1200,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: _reportText(
                                sheetContext,
                                ru: 'Дополнительные детали',
                                en: 'Additional details',
                                uk: 'Додаткові деталі',
                                es: 'Detalles adicionales',
                                pt: 'Detalhes adicionais',
                                fr: 'Details supplementaires',
                                de: 'Weitere Details',
                              ),
                              hintText: _reportText(
                                sheetContext,
                                ru: 'Опишите, что произошло. Содержимое сообщений не прикладывается автоматически.',
                                en: 'Describe what happened. Message contents are not attached automatically.',
                                uk: 'Опишіть, що сталося. Вміст повідомлень не додається автоматично.',
                                es: 'Describe lo que paso. El contenido de los mensajes no se adjunta automaticamente.',
                                pt: 'Descreva o que aconteceu. O conteudo das mensagens nao e anexado automaticamente.',
                                fr: 'Decrivez ce qui s est passe. Le contenu des messages n est pas joint automatiquement.',
                                de: 'Beschreibe, was passiert ist. Nachrichteninhalte werden nicht automatisch angehangt.',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (allowBlockTarget && !targetAlreadyBlocked) ...[
                            const SizedBox(height: 4),
                            CheckboxListTile.adaptive(
                              value: blockTarget,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                _reportText(
                                  sheetContext,
                                  ru: 'Заблокировать после жалобы',
                                  en: 'Block after reporting',
                                  uk: 'Заблокувати після скарги',
                                  es: 'Bloquear despues de reportar',
                                  pt: 'Bloquear depois de denunciar',
                                  fr: 'Bloquer apres le signalement',
                                  de: 'Nach der Meldung blockieren',
                                ),
                              ),
                              subtitle: Text(
                                _reportText(
                                  sheetContext,
                                  ru: 'Пользователь не сможет доставлять вам сообщения.',
                                  en: 'This user will not be able to deliver messages to you.',
                                  uk: 'Користувач не зможе доставляти вам повідомлення.',
                                  es: 'Este usuario no podra enviarte mensajes.',
                                  pt: 'Este utilizador nao podera enviar-lhe mensagens.',
                                  ptBr:
                                      'Este usuario nao podera enviar mensagens para voce.',
                                  fr: 'Cet utilisateur ne pourra plus vous envoyer de messages.',
                                  de: 'Dieser Nutzer kann dir keine Nachrichten mehr zustellen.',
                                ),
                              ),
                              onChanged: (value) {
                                setSheetState(() {
                                  blockTarget = value ?? false;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: canSubmit ? submit : null,
                            icon: submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(AppIcons.errorOutline),
                            label: Text(
                              submitting
                                  ? _reportText(
                                      sheetContext,
                                      ru: 'Подготовка...',
                                      en: 'Preparing...',
                                      uk: 'Підготовка...',
                                      es: 'Preparando...',
                                      pt: 'A preparar...',
                                      ptBr: 'Preparando...',
                                      fr: 'Preparation...',
                                      de: 'Vorbereitung...',
                                    )
                                  : _reportText(
                                      sheetContext,
                                      ru: 'Отправить жалобу',
                                      en: 'Submit report',
                                      uk: 'Надіслати скаргу',
                                      es: 'Enviar reporte',
                                      pt: 'Enviar denuncia',
                                      fr: 'Envoyer le signalement',
                                      de: 'Meldung senden',
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(sheetContext).pop(null),
                            child: Text(
                              _reportText(
                                sheetContext,
                                ru: 'Отмена',
                                en: 'Cancel',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    detailsController.dispose();
  }
}

Future<ReportAbuseResult> _sendReport({
  required ReportAbuseTarget target,
  required _ReportReason reason,
  required String localeTag,
  required String details,
  required String buildMarker,
  required String reporterDeviceId,
  required String reporterProfileId,
  required Iterable<String> additionalTechnicalLines,
  required bool blockTarget,
}) async {
  final technicalInfo = buildSupportTechnicalInfo(
    buildMarker: buildMarker,
    deviceId: reporterDeviceId,
    profileId: reporterProfileId,
    additionalLines: additionalTechnicalLines,
  );
  final payload = buildAbuseReportPayload(
    targetType: _targetTypeName(target.type),
    targetId: target.id,
    targetTitle: target.title,
    conversationId: target.conversationId,
    reasonCode: reason.code,
    reasonLabel: reason.titleForLocale(localeTag),
    details: details,
    technicalInfo: technicalInfo,
  );
  const supportEmail = 'technical.support@secretlyapp.com';
  final subject = Uri.encodeComponent(
    'Secretly Abuse Report: ${_targetTypeName(target.type)}',
  );
  final body = Uri.encodeComponent(payload);
  final mailUri = Uri.parse('mailto:$supportEmail?subject=$subject&body=$body');
  var opened = false;
  try {
    opened = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (opened) {
    return ReportAbuseResult(
      deliveryMode: ReportAbuseDeliveryMode.mailApp,
      blockTarget: blockTarget,
    );
  }
  await Clipboard.setData(ClipboardData(text: payload));
  return ReportAbuseResult(
    deliveryMode: ReportAbuseDeliveryMode.clipboard,
    blockTarget: blockTarget,
  );
}

List<_ReportReason> _reportReasons(ReportAbuseTargetType targetType) {
  final roomSpecific = targetType == ReportAbuseTargetType.room;
  return <_ReportReason>[
    _ReportReason(
      code: 'spam_or_scam',
      icon: AppIcons.errorOutline,
      enTitle: 'Spam or scam',
      ruTitle: 'Спам или мошенничество',
      enSubtitle: roomSpecific
          ? 'Mass invites, phishing, or misleading room activity.'
          : 'Unwanted messages, phishing, or deceptive behavior.',
      ruSubtitle: roomSpecific
          ? 'Массовые приглашения, фишинг или обман в комнате.'
          : 'Нежелательные сообщения, фишинг или обман.',
      roomSpecific: roomSpecific,
    ),
    _ReportReason(
      code: 'harassment_or_abuse',
      icon: AppIcons.block,
      enTitle: 'Harassment or abuse',
      ruTitle: 'Травля или оскорбления',
      enSubtitle: 'Threats, targeted abuse, or repeated unwanted contact.',
      ruSubtitle: 'Угрозы, травля или повторные нежелательные обращения.',
    ),
    _ReportReason(
      code: 'unsafe_or_illegal_content',
      icon: AppIcons.shield,
      enTitle: 'Unsafe or illegal content',
      ruTitle: 'Опасный или незаконный контент',
      enSubtitle: 'Content that may violate safety rules or law.',
      ruSubtitle:
          'Контент, который может нарушать правила безопасности или закон.',
    ),
    _ReportReason(
      code: 'impersonation',
      icon: AppIcons.personOutline,
      enTitle: 'Impersonation',
      ruTitle: 'Выдаёт себя за другого',
      enSubtitle: 'Pretending to be another person, team, or service.',
      ruSubtitle: 'Выдаёт себя за человека, команду или сервис.',
    ),
    _ReportReason(
      code: 'privacy_or_security',
      icon: AppIcons.security,
      enTitle: 'Privacy or security issue',
      ruTitle: 'Проблема приватности или безопасности',
      enSubtitle:
          'Leaked personal data, suspicious keys, or security pressure.',
      ruSubtitle:
          'Утечка данных, подозрительные ключи или давление по безопасности.',
    ),
    _ReportReason(
      code: 'other',
      icon: AppIcons.more,
      enTitle: 'Other',
      ruTitle: 'Другое',
      enSubtitle: 'Something else the Secretly team should review.',
      ruSubtitle: 'Другая ситуация, которую должна проверить команда Secretly.',
    ),
  ];
}

_ReportReason? _findReason(Iterable<_ReportReason> reasons, String code) {
  for (final reason in reasons) {
    if (reason.code == code) return reason;
  }
  return null;
}

String _targetTypeName(ReportAbuseTargetType type) {
  return switch (type) {
    ReportAbuseTargetType.profile => 'profile',
    ReportAbuseTargetType.room => 'room',
  };
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.target});

  final ReportAbuseTarget target;

  @override
  Widget build(BuildContext context) {
    final targetName = target.title.trim().isEmpty ? target.id : target.title;
    final targetTypeLabel = target.type == ReportAbuseTargetType.room
        ? _reportText(
            context,
            ru: 'комнату',
            en: 'room',
            uk: 'кімнату',
            es: 'sala',
            pt: 'sala',
            fr: 'salon',
            de: 'Raum',
          )
        : _reportText(
            context,
            ru: 'пользователя',
            en: 'user',
            uk: 'користувача',
            es: 'usuario',
            pt: 'utilizador',
            ptBr: 'usuario',
            fr: 'utilisateur',
            de: 'Nutzer',
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          child: const Icon(AppIcons.errorOutline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _reportText(context, ru: 'Пожаловаться', en: 'Report'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _reportText(
                  context,
                  ru: 'Отправьте жалобу на $targetTypeLabel "$targetName". Содержимое сообщений не прикладывается автоматически.',
                  en: 'Submit a report about this $targetTypeLabel "$targetName". Message contents are not attached automatically.',
                  uk: 'Надішліть скаргу на $targetTypeLabel "$targetName". Вміст повідомлень не додається автоматично.',
                  es: 'Envia un reporte sobre este $targetTypeLabel "$targetName". El contenido de los mensajes no se adjunta automaticamente.',
                  pt: 'Envie uma denuncia sobre este $targetTypeLabel "$targetName". O conteudo das mensagens nao e anexado automaticamente.',
                  fr: 'Envoyez un signalement sur ce $targetTypeLabel "$targetName". Le contenu des messages n est pas joint automatiquement.',
                  de: 'Sende eine Meldung zu diesem $targetTypeLabel "$targetName". Nachrichteninhalte werden nicht automatisch angehangt.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  final _ReportReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.72)
        : colorScheme.outlineVariant.withValues(alpha: 0.38);
    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.38)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  reason.icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.titleForLocale(
                          wave1LocaleTagFromContext(context),
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason.subtitleForLocale(
                          wave1LocaleTagFromContext(context),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? AppIcons.radioChecked : AppIcons.radioUnchecked,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
