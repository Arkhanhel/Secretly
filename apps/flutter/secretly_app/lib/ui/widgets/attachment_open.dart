// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Opening a received file for the person: in-app PDF and text readers,
/// otherwise the system «Open with», with a share/Downloads way out when no app
/// can take the type.
///
/// П9 (media audit 15.11.2026): this lived privately inside the chat screen,
/// so the Files tab of the shared-media gallery could not reuse it and only
/// showed «Saved to (private path)» — the file never opened. Moved here
/// unchanged; the chat now calls this same function.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/pdf_document.dart';
import '../../app/platform_file_open.dart';
import '../../attachments/attachment_naming.dart';
import '../../models/e2e_payload_v1.dart';
import '../animations/page_transitions.dart';
import '../chat_screen_l10n.dart';
import '../document_reader_screen.dart';
import '../motion/app_dialogs.dart';
import '../secretly_snackbar.dart';
import '../text_file_reader_screen.dart';
import 'attachment_actions.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// Opens [file] (the decrypted [attachment]) the way the chat does.
Future<void> openAttachmentFileForUser(
  BuildContext context, {
  required AttachmentEventV1 attachment,
  required File file,
  int? createdAtMs,
}) async {
  final effectiveCreatedAtMs =
      createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
  final suggestedName = attachmentDownloadSuggestedName(
    attachment,
    effectiveCreatedAtMs,
    file,
  );
  // IN-APP READER (2026-07-29): a PDF opens in OUR full-screen reader — same
  // chrome as the photo gallery — instead of being handed to another app that
  // may not exist ("Нет приложения для открытия"). Pages are rasterised by the
  // platform's own PDF renderer; see PdfDocument for why we do not bundle an
  // engine. If the file cannot be opened as a PDF (encrypted/corrupt) or the
  // platform has no renderer yet, fall through to the external-app path below.
  final mime = attachment.mime ?? attachmentMimeForOrNull(file.path) ?? '';
  final looksPdf =
      mime.toLowerCase().contains('pdf') ||
      file.path.toLowerCase().endsWith('.pdf');
  if (looksPdf && PdfDocument.isSupported) {
    final doc = await PdfDocument.open(file.path);
    if (doc != null) {
      if (!context.mounted) {
        doc.dispose();
        return;
      }
      await Navigator.of(context).push(
        SecretlyPageRoute(
          builder: (_) => DocumentReaderScreen(
            document: doc,
            title: suggestedName,
            // Через общий путь: он даёт файлу правильное имя НА ДИСКЕ и тип
            // по имени. Здесь стояло прямое обращение, и потому документ
            // уходил под служебным именем кэша — `<blobId>.bin`.
            onShare: () => shareAttachmentFile(
              attachment: attachment,
              createdAtMs: effectiveCreatedAtMs,
              source: file,
            ),
          ),
        ),
      );
      return;
    }
  }
  // Plain text (.txt/.log/.json/.csv/…) opens in-app too. Unlike PDF this
  // needs no rendering engine — we just decode the bytes — so it costs nothing
  // in size or attack surface, and it saves the same dead end on a phone with
  // no text viewer installed.
  if (TextFileReaderScreen.canOpen(path: file.path, mime: mime)) {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => TextFileReaderScreen(
          file: file,
          title: suggestedName,
          onShare: () => shareAttachmentFile(
            attachment: attachment,
            createdAtMs: effectiveCreatedAtMs,
            source: file,
          ),
        ),
      ),
    );
    return;
  }
  final opened = await PlatformFileOpen.open(
    // 🔴 Наружу отдаём файл с ПРАВИЛЬНЫМ ИМЕНЕМ НА ДИСКЕ и типом, выведенным
    // из имени. Здесь уходил кэш `<blobId>.bin` с обезличенным типом — по
    // такому описанию система не находит ни одного приложения, и человек
    // видел «нет приложения для открытия» даже там, где приложение есть.
    path: (await prepareAttachmentFileForExport(
      source: file,
      filename: suggestedName,
      mime: attachment.mime,
      createdAtMs: effectiveCreatedAtMs,
    )).path,
    mime: attachmentMimeFor(filename: suggestedName, mime: attachment.mime),
    displayName: suggestedName,
  );
  if (opened || !context.mounted) return;
  // NO-VIEWER FALLBACK (2026-07-29, field report "не открывается PDF — пишет
  // «Нет приложения для открытия»"): a direct VIEW intent only succeeds when
  // some installed app claims that exact mime, so on a phone without a PDF /
  // document viewer the user hit a dead end — the file was decrypted and ready
  // on disk, but there was no way to reach it. Offer the system share sheet
  // instead: its chooser lists every app that can take the file (viewers,
  // Drive, browser, mail), which is the standard Android way out of this, and
  // it also lets the user move the file somewhere they can open it.
  final decision = await showModalBottomSheet<String>(
  sheetAnimationStyle: appSheetAnimationStyle,
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              chatText(
                sheetContext,
                ru: 'На устройстве нет приложения для этого типа файла',
                en: 'No app on this device can open this file type',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(AdaptiveIcons.ios_share_rounded),
            title: Text(
              chatText(
                sheetContext,
                ru: 'Открыть в другом приложении',
                en: 'Open with another app',
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop('share'),
          ),
          // A file nothing can display should still be RETRIEVABLE: put it in
          // the phone's public Downloads (visible in Files / any file manager)
          // so an installer, archive or office document can be dealt with
          // outside the app. Android only — iOS has no shared Downloads, and
          // its share sheet already covers "save to Files".
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(AdaptiveIcons.download_rounded),
              title: Text(
                chatText(
                  sheetContext,
                  ru: 'Сохранить в Загрузки',
                  en: 'Save to Downloads',
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('save'),
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (decision == 'save') {
    try {
      final saved = await const MethodChannel(
        'secretly/media_store',
      ).invokeMethod<String>('saveToDownloads', {
        'fileName': suggestedName,
        'sourcePath': file.path,
        // 🔴 Тип обязателен. Без него запись шла типом
        // `application/octet-stream`, и система считала файл двоичным мусором:
        // установщик не предлагал поставить apk, проводник не открывал
        // документ, и в «Недавних» файл не появлялся.
        'mimeType': attachmentMimeFor(
          filename: suggestedName,
          mime: attachment.mime,
        ),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            saved != null && saved.trim().isNotEmpty
                ? chatText(
                    context,
                    ru: 'Сохранено в Загрузки',
                    en: 'Saved to Downloads',
                  )
                : chatText(
                    context,
                    ru: 'Не удалось сохранить',
                    en: 'Could not save',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text('$e')),
      );
    }
    return;
  }
  if (decision != 'share') return;
  try {
    // Тот же довод, что в `_shareSingleAttachment`: наружу должен уходить файл
    // с правильным именем НА ДИСКЕ, а не имя в параметрах.
    await shareAttachmentFile(
      attachment: attachment,
      createdAtMs: effectiveCreatedAtMs,
      source: file,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(content: Text('$e')),
    );
  }
}
