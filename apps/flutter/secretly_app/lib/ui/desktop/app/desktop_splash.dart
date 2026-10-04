// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import '../../../l10n/app_localizations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../chat/attachment_save.dart' show revealInFileManager;
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../services/desktop_diag_file_log.dart';

/// Boot-time splash shown while [AppController.init()] is in progress.
/// Mirrors the visual language of the mobile startup surface but stays
/// inside the desktop design tokens.
///
/// 🔴 ЗАПУСК, КОТОРЫЙ НЕ УДАЛСЯ, ТАК И ГОВОРИТ (01.10.2026). Раньше ошибка
/// открытия базы или чтения ключа оставляла крутиться кружок — вечно, с сырым
/// текстом исключения под ним, и выйти из этого можно было только закрыв
/// приложение. Теперь при ошибке ([error]) кружок сменяется знаком ошибки, а
/// при слишком долгом запуске ([slow]) кружок остаётся — запуск ведь идёт, —
/// и в обоих случаях есть «Повторить» и «Открыть папку журнала».
class DesktopSplash extends StatelessWidget {
  const DesktopSplash({
    super.key,
    this.error,
    this.slow = false,
    this.onRetry,
    this.onOpenLogs,
  });

  /// Текст ошибки запуска; `null` — запуск идёт.
  final String? error;

  /// Запуск идёт дольше разумного.
  final bool slow;

  /// Начать запуск заново. `null` — кнопки нет.
  final VoidCallback? onRetry;

  /// Показать папку журнала. `null` — кнопки нет.
  final VoidCallback? onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final failed = error != null;
    final stuck = failed || slow;
    return Container(
      color: c.bg,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.elevated,
                  border: Border.all(color: c.borderSubtle),
                ),
                child: Center(
                  child: failed
                      ? Icon(
                          FluentIcons.error_circle_24_regular,
                          size: 28,
                          color: c.danger,
                        )
                      : SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: DSpace.l),
            Text(
              'Secretly',
              style: DType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DSpace.xs),
            Text(
              failed ? l10n.desktopStartupFailedTitle : l10n.desktopSplashLoading,
              textAlign: TextAlign.center,
              style: DType.caption.copyWith(
                color: failed ? c.danger : c.textSecondary,
              ),
            ),
            if (stuck) ...[
              const SizedBox(height: DSpace.l),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!failed)
                      Text(
                        l10n.desktopStartupSlowTitle,
                        textAlign: TextAlign.center,
                        style: DType.body.copyWith(color: c.textPrimary),
                      ),
                    if (!failed) const SizedBox(height: DSpace.xs),
                    Text(
                      failed
                          ? l10n.desktopStartupFailedBody
                          : l10n.desktopStartupSlowBody,
                      textAlign: TextAlign.center,
                      style: DType.body.copyWith(color: c.textSecondary),
                    ),
                    if (failed) ...[
                      const SizedBox(height: DSpace.s),
                      // Сама причина — мелко и выделяемо: её копируют в
                      // письмо, а не читают вслух.
                      SelectableText(
                        error!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        style: DType.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DSpace.l),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: DSpace.s,
                runSpacing: DSpace.s,
                children: [
                  if (onRetry != null)
                    DesktopButton(
                      label: l10n.desktopStartupRetry,
                      onPressed: onRetry,
                    ),
                  if (onOpenLogs != null)
                    DesktopButton(
                      label: l10n.desktopStartupOpenLogs,
                      kind: DButtonKind.tonal,
                      onPressed: onOpenLogs,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Показывает журнал запуска в файловом менеджере (Finder, Проводник).
///
/// Файл журнала выделяется, если он есть; иначе открывается его папка —
/// журнал мог не завестись как раз из-за той беды, что сорвала запуск.
Future<void> openDesktopLogFolder() async {
  try {
    var dir = DesktopDiagFileLog.directoryPath;
    if (dir == null) {
      final base = await getApplicationSupportDirectory();
      dir = p.join(base.path, 'logs');
    }
    final log = File(p.join(dir, DesktopDiagFileLog.fileName));
    if (await log.exists()) {
      await revealInFileManager(log.path);
      return;
    }
    await Directory(dir).create(recursive: true);
    if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  } catch (_) {
    // Файловый менеджер не открылся — показывать больше нечего.
  }
}
