// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_controller.dart';
import 'wave1_l10n.dart';

const MethodChannel _nativeShareChannel = MethodChannel('secretly/share');

Future<void> shareTextExternally({
  required String text,
  String? subject,
}) async {
  final normalizedText = text.trim();
  final normalizedSubject = subject?.trim();
  if (normalizedText.isEmpty) return;

  if (Platform.isAndroid) {
    try {
      await _nativeShareChannel
          .invokeMethod<void>('shareText', <String, Object?>{
            'text': normalizedText,
            if (normalizedSubject != null && normalizedSubject.isNotEmpty)
              'subject': normalizedSubject,
          });
      return;
    } catch (_) {
      // Fall back to share_plus if the native bridge is unavailable.
    }
  }

  await SharePlus.instance.share(
    ShareParams(text: normalizedText, subject: normalizedSubject),
  );
}

String buildProfileShareText({
  required String profileId,
  required bool isRu,
  String? displayName,
}) {
  final normalizedProfileId = normalizeSharedProfileId(profileId);
  if (normalizedProfileId.isEmpty) return '';
  final appLink = buildProfileShareLink(profileId: normalizedProfileId);
  return appLink;
}

String buildInviteFriendShareText({
  required AppController controller,
  bool? isRu,
  String? localeTag,
}) {
  final name = controller.myNickname.trim();
  final profileId = normalizeSharedProfileId(controller.profileId);
  var tag = localeTag;
  if (tag == null || tag.trim().isEmpty) {
    final useRussianFallback = isRu == true;
    if (useRussianFallback) {
      tag = 'ru';
    } else {
      tag = 'en';
    }
  }
  final nameSuffix = name.isNotEmpty ? ' - $name' : '';

  return wave1TextForLocale(
    tag,
    ru: <String>[
      'Привет! Я использую Secretly - защищённый мессенджер для приватного общения.',
      'Установи приложение, будем общаться там.',
      'Скачать: https://www.secretlyapp.com/download',
      'Добавь меня в контакты.',
      if (profileId.isNotEmpty) 'Мой ID в Secretly: $profileId',
    ].join('\n'),
    en: <String>[
      'Let\'s chat on Secretly$nameSuffix',
      'A private messenger with E2EE encryption, secure chats, and protected calls.',
      'Download the app: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'My Secretly ID: $profileId',
    ].join('\n'),
    uk: <String>[
      'Привіт! Я користуюся Secretly$nameSuffix.',
      'Це приватний месенджер з E2EE, захищеними чатами і дзвінками.',
      'Завантажити: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'Мій ID у Secretly: $profileId',
    ].join('\n'),
    es: <String>[
      'Hablemos en Secretly$nameSuffix.',
      'Un mensajero privado con cifrado E2EE, chats seguros y llamadas protegidas.',
      'Descarga la app: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'Mi ID de Secretly: $profileId',
    ].join('\n'),
    pt: <String>[
      'Vamos conversar no Secretly$nameSuffix.',
      'Um mensageiro privado com cifragem E2EE, chats seguros e chamadas protegidas.',
      'Descarregar a app: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'O meu ID Secretly: $profileId',
    ].join('\n'),
    ptBr: <String>[
      'Vamos conversar no Secretly$nameSuffix.',
      'Um mensageiro privado com criptografia E2EE, conversas seguras e chamadas protegidas.',
      'Baixe o app: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'Meu ID no Secretly: $profileId',
    ].join('\n'),
    fr: <String>[
      'Discutons sur Secretly$nameSuffix.',
      'Une messagerie privee avec chiffrement E2EE, chats securises et appels proteges.',
      'Telecharger l app : https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'Mon ID Secretly : $profileId',
    ].join('\n'),
    de: <String>[
      'Lass uns auf Secretly chatten$nameSuffix.',
      'Ein privater Messenger mit E2EE, sicheren Chats und geschutzten Anrufen.',
      'App herunterladen: https://www.secretlyapp.com/download',
      if (profileId.isNotEmpty) 'Meine Secretly-ID: $profileId',
    ].join('\n'),
  );
}
