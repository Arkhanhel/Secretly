// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПРЕДУПРЕЖДЕНИЕ ПЕРЕД ОТКРЫТИЕМ ОПАСНОГО ФАЙЛА.
///
/// 🔴 Одно нажатие по полученному «счёт.pdf.lnk» запускало ярлык (30.09.2026):
/// файл уходил системе как есть, а она выбирает программу по расширению.
/// Теперь программу, сценарий, ярлык, документ с макросами и файл без
/// расширения одним нажатием не открываем: как Telegram Desktop, называем
/// НАСТОЯЩЕЕ расширение и предлагаем показать файл в папке. Открыть всё
/// равно можно — но только отдельной кнопкой.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';
import 'attachment_save.dart';

/// Что выбрал человек в предупреждении.
enum RiskyAttachmentChoice { showInFolder, openAnyway }

/// Текст предупреждения — с настоящим расширением файла.
String attachmentRiskText(AppLocalizations l10n, AttachmentOpenRisk risk) {
  return switch (risk.reason) {
    AttachmentRiskReason.executable => l10n.desktopFileRiskExtension(
      risk.extension,
    ),
    AttachmentRiskReason.noExtension => l10n.desktopFileRiskNoExtension,
    AttachmentRiskReason.mismatch => l10n.desktopFileRiskMismatch(
      risk.extension,
    ),
  };
}

/// Спрашивает, открывать ли опасный файл. `null` — человек передумал.
Future<RiskyAttachmentChoice?> confirmRiskyAttachmentOpen(
  BuildContext context, {
  required String fileName,
  required AttachmentOpenRisk risk,
}) {
  final l10n = AppLocalizations.of(context)!;
  final c = DColors.of(context);
  return DesktopDialog.show<RiskyAttachmentChoice>(
    context,
    title: l10n.desktopFileRiskTitle,
    size: DDialogSize.small,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DType.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: DSpace.s),
        Text(
          attachmentRiskText(l10n, risk),
          style: DType.body.copyWith(color: c.textSecondary),
        ),
      ],
    ),
    // Безопасное действие — главное: «Показать в папке». Открытие — рядом,
    // но тише, чтобы его выбирали, а не попадали в него.
    primary: DDialogAction(
      label: l10n.desktopFileRiskShowInFolder,
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).maybePop(RiskyAttachmentChoice.showInFolder),
    ),
    secondary: DDialogAction(
      label: l10n.desktopFileRiskOpenAnyway,
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).maybePop(RiskyAttachmentChoice.openAnyway),
    ),
  );
}

/// Можно ли отдать полученный файл внешней программе.
///
/// Обычный файл — сразу `true`. Опасный — сперва предупреждение: «Всё равно
/// открыть» даёт `true`; «Показать в папке» кладёт копию в «Загрузки/Secretly»
/// (с меткой «из интернета», см. [markFileFromInternet]), показывает её и
/// даёт `false`; закрытое окно — `false`.
///
/// Ошибки записи и показа папки не глотаются: о них рассказывает вызывающий,
/// своим обычным способом.
Future<bool> mayOpenReceivedFile(
  BuildContext context, {
  required File file,
  required String? fileName,
  required String? mime,
  required String blobId,
  Future<void> Function(String path)? reveal,
  Directory? downloadsOverride,
}) async {
  final risk = attachmentOpenRisk(fileName: fileName, mime: mime);
  if (risk == null) return true;
  final shown = safeDownloadFileName(
    suggestedAttachmentFileName(fileName: fileName, mime: mime, blobId: blobId),
  );
  final choice = await confirmRiskyAttachmentOpen(
    context,
    fileName: shown,
    risk: risk,
  );
  if (choice == RiskyAttachmentChoice.openAnyway) return true;
  if (choice == RiskyAttachmentChoice.showInFolder) {
    final copy = await exportAttachmentToDownloads(
      file,
      shown,
      downloadsOverride: downloadsOverride,
    );
    await (reveal ?? revealInFileManager)(copy.path);
  }
  return false;
}
