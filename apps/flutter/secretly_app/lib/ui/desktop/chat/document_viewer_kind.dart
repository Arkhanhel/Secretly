// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ЧЕМ ПОКАЗЫВАТЬ ПОЛУЧЕННЫЙ ФАЙЛ.
///
/// 🔴 ЗАЧЕМ ВООБЩЕ СВОЙ ПРОСМОТР. Файл открывался чужой программой: значит,
/// расшифрованный документ уходит другому приложению, попадает в его список
/// недавних и в его кэш. Для переписки со сквозным шифрованием это самое
/// слабое место пути. Что можем показать сами — показываем сами.
library;

import 'package:path/path.dart' as p;

enum DesktopViewerKind {
  /// Показываем страницами через системный PDFKit.
  pdf,

  /// Показываем текстом прямо в окне.
  text,

  /// Своего просмотра нет — отдаём внешней программе, как раньше.
  external_,
}

/// Расширения, которые читаются как обычный текст. Список намеренно узкий:
/// показать «как текст» исполняемый файл — не помощь, а каша на экране.
const Set<String> kDesktopTextExtensions = <String>{
  '.txt', '.md', '.markdown', '.log', '.csv', '.tsv', '.json', '.xml',
  '.yaml', '.yml', '.ini', '.conf', '.cfg', '.toml', '.srt', '.vtt',
  '.dart', '.rs', '.py', '.js', '.ts', '.html', '.css', '.sh', '.sql',
};

/// Больше этого текст не показываем: окно не читалка бревна на сто мегабайт.
const int kDesktopTextViewerMaxBytes = 2 * 1024 * 1024;

DesktopViewerKind desktopViewerKindFor({
  String? mime,
  String? fileName,
  int sizeBytes = 0,
}) {
  final m = (mime ?? '').trim().toLowerCase();
  final ext = p.extension((fileName ?? '').trim()).toLowerCase();

  if (m == 'application/pdf' || m == 'application/x-pdf' || ext == '.pdf') {
    return DesktopViewerKind.pdf;
  }
  final looksText =
      m.startsWith('text/') ||
      m == 'application/json' ||
      m == 'application/xml' ||
      kDesktopTextExtensions.contains(ext);
  if (looksText) {
    // Огромный текст не тянем в память: для него честнее внешняя программа.
    if (sizeBytes > kDesktopTextViewerMaxBytes) {
      return DesktopViewerKind.external_;
    }
    return DesktopViewerKind.text;
  }
  return DesktopViewerKind.external_;
}
