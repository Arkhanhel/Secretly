// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics/diag_log.dart';

/// С-13 (разбор 22.11.2026): расшифрованные копии, которые просмотр медиа
/// оставлял на диске.
///
///  • «Копировать» на Android: плагин `pasteboard` пишет снимок в
///    `<кэш>/<uuid>.png` и отдаёт буферу ссылку на файл — и никогда его не
///    удаляет. В буфере держится одна картинка, поэтому прежние копии
///    убираются перед каждой новой; последняя — при следующих запусках, когда
///    ей больше получаса (дольше в буфере обмена её обычно не держат).
///  • Выгрузки правленых снимков для «Поделиться» / «Сохранить» лежат в
///    `<временная>/secretly_edited/`. Сразу их удалять нельзя: приложение,
///    которому поделились, читает файл позже. Убираются старше получаса — при
///    закрытии просмотра и при запуске.
///
/// Трогаем ТОЛЬКО свои имена в своих временных папках: `<uuid>.png` в корне
/// кэша (имя ровно в формате UUID плагина) и всё внутри `secretly_edited/`.
/// Файлы человека (галерея, «Файлы», загрузки) здесь не лежат.
///
/// Выключатель — [kDecryptedTempCleanup] (`false` — как было, ничего не
/// удаляем).
const bool kDecryptedTempCleanup = true;

/// Сколько живёт копия, прежде чем её уберёт уборка.
const Duration kDecryptedTempMaxAge = Duration(minutes: 30);

final RegExp _pasteboardName = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$',
);

/// Имя копии буфера обмена плагина `pasteboard` (Android).
bool isPasteboardCopyName(String name) => _pasteboardName.hasMatch(name);

/// Убрать старые расшифрованные копии. [tempDir] и [now] — для тестов.
/// Возвращает число удалённых файлов. Никогда не бросает.
Future<int> sweepDecryptedTempCopies({
  Directory? tempDir,
  DateTime? now,
  Duration maxAge = kDecryptedTempMaxAge,
}) async {
  if (!kDecryptedTempCleanup) return 0;
  try {
    final tmp = tempDir ?? await getTemporaryDirectory();
    if (!await tmp.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    var removed = 0;
    Future<void> dropIfOld(File f) async {
      try {
        final st = await f.stat();
        if (st.modified.isAfter(cutoff)) return;
        await f.delete();
        removed++;
      } catch (_) {}
    }

    if (Platform.isAndroid || tempDir != null) {
      await for (final e in tmp.list(followLinks: false)) {
        if (e is File && isPasteboardCopyName(p.basename(e.path))) {
          await dropIfOld(e);
        }
      }
    }
    final edited = Directory(p.join(tmp.path, 'secretly_edited'));
    if (await edited.exists()) {
      await for (final e in edited.list(followLinks: false)) {
        if (e is File) await dropIfOld(e);
      }
    }
    if (removed > 0) {
      DiagLog.event('storage', 'decrypted_temp_swept', {'files': removed});
    }
    return removed;
  } catch (_) {
    return 0;
  }
}

/// Перед новой записью в буфер обмена: прежние копии буфера уже не в нём.
/// Только Android (iPhone кладёт байты в буфер, без файла).
Future<int> sweepPasteboardCopies({Directory? tempDir}) async {
  if (!kDecryptedTempCleanup) return 0;
  if (tempDir == null && !Platform.isAndroid) return 0;
  try {
    final tmp = tempDir ?? await getTemporaryDirectory();
    if (!await tmp.exists()) return 0;
    var removed = 0;
    await for (final e in tmp.list(followLinks: false)) {
      if (e is File && isPasteboardCopyName(p.basename(e.path))) {
        try {
          await e.delete();
          removed++;
        } catch (_) {}
      }
    }
    return removed;
  } catch (_) {
    return 0;
  }
}
