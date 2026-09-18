// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../billing/show_paywall.dart';
import 'icons/app_icons.dart';
import 'paywall_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/premium_glass.dart';

/// Telegram-style upsell dialog shown when a picked file exceeds the free
/// attachment ceiling but WOULD fit under Premium. Explains why the file was
/// not sent and offers a one-tap route to the paywall. On-brand: neutral
/// surface, gold accent only on the Premium action.
Future<void> showAttachmentTooLargeDialog({
  required BuildContext context,
  required int fileBytes,
  required int limitBytes,
}) async {
  final cs = Theme.of(context).colorScheme;
  // File size in DECIMAL MB so it matches what the OS file browser showed the
  // user (iOS Files / Android use MB = 10^6); the free ceiling in BINARY MB so
  // it reads as the advertised round "100 MB" (100 MiB). Different divisors on
  // purpose — each number then matches the surface the user compares it to.
  final fileMb = (fileBytes / 1000000).round();
  final limitMb = (limitBytes / (1024 * 1024)).round();

  final wantsPremium = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: cs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPremiumGold.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  AppIcons.fileOutline,
                  size: 28,
                  color: kPremiumGold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                wave1Text(
                  dialogContext,
                  ru: 'Файл слишком большой',
                  en: 'File is too large',
                  uk: 'Файл завеликий',
                  es: 'El archivo es demasiado grande',
                  pt: 'O ficheiro é demasiado grande',
                  ptBr: 'O arquivo é muito grande',
                  fr: 'Le fichier est trop volumineux',
                  de: 'Datei ist zu groß',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                wave1Text(
                  dialogContext,
                  ru: 'Этот файл — $fileMb МБ. Бесплатно можно отправлять файлы '
                      'до $limitMb МБ. Оформите Premium, чтобы делиться файлами '
                      'до 1 ГБ.',
                  en: 'This file is $fileMb MB. Free accounts can send files up '
                      'to $limitMb MB. Get Premium to share files up to 1 GB.',
                  uk: 'Цей файл — $fileMb МБ. Безкоштовно можна надсилати файли '
                      'до $limitMb МБ. Оформіть Premium, щоб ділитися файлами '
                      'до 1 ГБ.',
                  es: 'Este archivo pesa $fileMb MB. Las cuentas gratuitas '
                      'pueden enviar archivos de hasta $limitMb MB. Consigue '
                      'Premium para compartir archivos de hasta 1 GB.',
                  pt: 'Este ficheiro tem $fileMb MB. As contas gratuitas podem '
                      'enviar ficheiros até $limitMb MB. Obtenha o Premium para '
                      'partilhar ficheiros até 1 GB.',
                  ptBr: 'Este arquivo tem $fileMb MB. Contas gratuitas podem '
                      'enviar arquivos de até $limitMb MB. Assine o Premium para '
                      'compartilhar arquivos de até 1 GB.',
                  fr: 'Ce fichier fait $fileMb Mo. Les comptes gratuits peuvent '
                      'envoyer des fichiers jusqu’à $limitMb Mo. Passez à Premium '
                      'pour partager des fichiers jusqu’à 1 Go.',
                  de: 'Diese Datei ist $fileMb MB groß. Kostenlose Konten können '
                      'Dateien bis zu $limitMb MB senden. Hol dir Premium, um '
                      'Dateien bis zu 1 GB zu teilen.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPremiumGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    wave1Text(
                      dialogContext,
                      ru: 'Оформить Premium',
                      en: 'Get Premium',
                      uk: 'Оформити Premium',
                      es: 'Obtener Premium',
                      pt: 'Obter o Premium',
                      ptBr: 'Assinar o Premium',
                      fr: 'Passer à Premium',
                      de: 'Premium holen',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  wave1Text(
                    dialogContext,
                    ru: 'Позже',
                    en: 'Not now',
                    uk: 'Пізніше',
                    es: 'Ahora no',
                    pt: 'Agora não',
                    ptBr: 'Agora não',
                    fr: 'Plus tard',
                    de: 'Später',
                  ),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (wantsPremium == true && context.mounted) {
    await showPaywall(context, PaywallTrigger.file);
  }
}
