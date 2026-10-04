// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../security/backup_password_policy.dart';
import '../../recovery_kit_screen.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/desktop_text_field.dart';
import 'desktop_app_view_model.dart';
import '../primitives/desktop_screen_window.dart';
import '../services/desktop_clipboard_guard.dart';

/// Требования к паролю набора восстановления — НА ЯЗЫКЕ ОКНА.
///
/// 🔴 ЗДЕСЬ БЫЛО ЖЁСТКО ЗАШИТО «ПО-РУССКИ». `BackupPasswordPolicy` знает два
/// языка и выбирает их логическим `isRu`, а окно настроек передавало `true`
/// всегда — то есть немец, испанец и бразилец получали требования к паролю
/// по-русски. Причём ровно в том месте, где человек уже озадачен: пароль не
/// принимают, а почему — написано на языке, которого он не знает.
///
/// Общий файл политики не трогаем: он делит код с выпущенной мобильной
/// версией. Перевод живёт здесь, в окне, и берётся из тех же переводов, что и
/// всё остальное.
String desktopPasswordRequirements(AppLocalizations l10n) =>
    l10n.backupPwRequirements;

/// Что именно не так с паролем — на языке окна и по порядку правил.
String desktopPasswordProblems(
  AppLocalizations l10n,
  BackupPasswordValidation validation,
) {
  String one(BackupPasswordProblem p) {
    switch (p) {
      case BackupPasswordProblem.tooShort:
        return l10n.backupPwTooShort(BackupPasswordPolicy.minLength);
      case BackupPasswordProblem.tooLong:
        return l10n.backupPwTooLong(BackupPasswordPolicy.maxLength);
      case BackupPasswordProblem.nonAscii:
        return l10n.backupPwNonAscii;
      case BackupPasswordProblem.outerWhitespace:
        return l10n.backupPwOuterSpace;
      case BackupPasswordProblem.missingUppercase:
        return l10n.backupPwNeedUpper;
      case BackupPasswordProblem.missingSpecial:
        return l10n.backupPwNeedSpecial;
    }
  }

  return validation.problems.map(one).join(' ');
}

/// Спросить пароль для набора восстановления — с подтверждением и проверкой.
///
/// 🔴 ПРОВЕРКА ЗДЕСЬ, А НЕ ПОСЛЕ. Первая версия окна не проверяла пароль
/// вовсе: слабый принимался, а отказ прилетал потом сырой английской строкой
/// «Bad state: Password must be at least 8 characters». Требования показаны
/// СРАЗУ — человек подбирает пароль один раз, а не угадывает правила.
///
/// Возвращает `null`, если человек передумал.
Future<String?> promptRecoveryKitPassword(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final first = TextEditingController();
  final again = TextEditingController();
  String? error;
  ModalRoute<Object?>? route;

  final result = await DesktopDialog.show<String>(
    context,
    title: l10n.desktopBackupKeyPassword,
    size: DDialogSize.small,
    body: StatefulBuilder(
      builder: (ctx, setLocal) {
        route ??= ModalRoute.of(ctx);
        final c = DColors.of(ctx);
        void submit() {
          final a = first.text;
          final b = again.text;
          final validation = BackupPasswordPolicy.validate(a);
          if (!validation.isValid) {
            setLocal(() => error = desktopPasswordProblems(l10n, validation));
            return;
          }
          if (a != b) {
            setLocal(() => error = l10n.desktopBackupPasswordsDiffer);
            return;
          }
          Navigator.of(ctx).maybePop(a);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.desktopBackupKeyPasswordHint,
              style: DType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DSpace.m),
            DesktopTextField(
              controller: first,
              hintText: l10n.password,
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: DSpace.s),
            DesktopTextField(
              controller: again,
              hintText: l10n.desktopBackupPasswordAgain,
              obscureText: true,
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: DSpace.s),
            Text(
              error ?? desktopPasswordRequirements(l10n),
              style: DType.caption.copyWith(
                color: error != null ? c.danger : c.textDisabled,
              ),
            ),
            const SizedBox(height: DSpace.m),
            Align(
              alignment: Alignment.centerRight,
              child: DesktopButton(
                label: l10n.desktopListCreate,
                kind: DButtonKind.filled,
                onPressed: submit,
              ),
            ),
          ],
        );
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
  // 🔴 Окно ещё доигрывает закрытие и перестраивает поля (30.09.2026):
  // освобождённые сразу поля ловили «TextEditingController used after being
  // disposed». Освобождаем, когда окно ушло совсем.
  void release() {
    first.dispose();
    again.dispose();
  }

  final closing = route;
  if (closing == null) {
    release();
  } else {
    unawaited(closing.completed.then((_) => release()));
  }
  return result;
}

/// Чем кончилась выдача набора восстановления.
enum RecoveryKitOutcome {
  /// Набор не создан, или окно закрыли, ничего не сохранив.
  notSaved,

  /// Набор записан в файл, который человек выбрал сам.
  savedToFile,

  /// Человек явно подтвердил, что сохранил набор иначе (текст, снимок QR).
  confirmedByPerson,
}

/// Куда записать файл набора; `null` — человек передумал.
typedef RecoveryKitSavePathPicker =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
    });

Future<String?> _systemSavePath({
  required String dialogTitle,
  required String fileName,
}) => FilePicker.platform.saveFile(
  dialogTitle: dialogTitle,
  fileName: fileName,
);

/// Весь путь «сделать набор восстановления»: пароль → ключ → сохранение.
///
/// 🔴 ОДИН ПУТЬ НА ВСЁ ОКНО. Набор делается из настроек и — с 23.09.2026 —
/// при создании аккаунта на компьютере. Две копии одного пути разошлись бы
/// текстами и проверками, а это тот самый ключ, которым человек однажды будет
/// возвращать себе аккаунт: расхождение здесь стоит аккаунта.
///
/// 🔴 «СОЗДАН» ≠ «СОХРАНЁН» (30.09.2026). Раньше путь кончался показом
/// телефонного экрана с QR, и закрытие этого окна считалось успехом — шаг
/// входа писал «Набор сохранён», хотя не сохранялось ничего. Теперь успех —
/// это файл, записанный туда, куда выбрал человек, либо его явное
/// подтверждение, что набор сохранён иначе.
Future<RecoveryKitOutcome> runRecoveryKitExport({
  required BuildContext context,
  required DesktopAppViewModel vm,
  // `null` — системное окно «Сохранить»; своё передают только проверки.
  RecoveryKitSavePathPicker? pickSavePath,
  // `null` — общий сторож буфера; свой передают только проверки.
  @visibleForTesting DesktopClipboardGuard? guardClipboard,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final password = await promptRecoveryKitPassword(context);
  if (password == null || password.isEmpty || !context.mounted) {
    return RecoveryKitOutcome.notSaved;
  }

  String payload;
  try {
    payload = await vm.controller.createRecoveryKitPayload(password: password);
  } catch (e) {
    if (!context.mounted) return RecoveryKitOutcome.notSaved;
    // «Bad state: …» человеку не сообщает ничего — снимаем техническую
    // приставку, как это уже делает панель серверной копии.
    var text = e.toString();
    for (final prefix in const ['Bad state: ', 'StateError: ']) {
      if (text.startsWith(prefix)) text = text.substring(prefix.length);
    }
    DesktopSnackbar.show(
      context,
      message: l10n.desktopBackupKeyFailed(text),
      kind: DSnackKind.error,
    );
    return RecoveryKitOutcome.notSaved;
  }

  if (!context.mounted) return RecoveryKitOutcome.notSaved;
  return _showKitReady(
    context,
    payload: payload,
    pickSavePath: pickSavePath ?? _systemSavePath,
    guardClipboard: guardClipboard,
  );
}

/// «Набор готов»: сохранить в файл, показать QR и текст, или подтвердить, что
/// сохранён иначе. Закрыть окно можно всегда — но тогда набор НЕ сохранён.
Future<RecoveryKitOutcome> _showKitReady(
  BuildContext context, {
  required String payload,
  required RecoveryKitSavePathPicker pickSavePath,
  DesktopClipboardGuard? guardClipboard,
}) async {
  final l10n = AppLocalizations.of(context)!;
  var outcome = RecoveryKitOutcome.notSaved;
  String? savedPath;
  String? error;

  Future<void> confirmElsewhere(BuildContext ctx) async {
    final yes = await DesktopDialog.show<bool>(
      ctx,
      title: l10n.desktopKitConfirmTitle,
      size: DDialogSize.small,
      body: Text(
        l10n.desktopKitConfirmBody,
        style: DType.body.copyWith(color: DColors.of(ctx).textSecondary),
      ),
      primary: DDialogAction(
        label: l10n.desktopKitConfirmYes,
        onPressed: () => Navigator.of(ctx).maybePop(true),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(ctx).maybePop(false),
      ),
    );
    if (yes != true || !ctx.mounted) return;
    outcome = RecoveryKitOutcome.confirmedByPerson;
    Navigator.of(ctx).maybePop(outcome);
  }

  final result = await DesktopDialog.show<RecoveryKitOutcome>(
    context,
    title: l10n.desktopKitReadyTitle,
    size: DDialogSize.medium,
    barrierDismissible: false,
    body: StatefulBuilder(
      builder: (ctx, setLocal) {
        final c = DColors.of(ctx);
        Future<void> saveToFile() async {
          String? path;
          try {
            path = await pickSavePath(
              dialogTitle: l10n.desktopKitSaveDialogTitle,
              fileName: 'Secretly-recovery-kit.txt',
            );
            if (path == null) return;
            await File(path).writeAsString('$payload\n', flush: true);
          } catch (e) {
            setLocal(() => error = l10n.desktopKitSaveFailed(desktopErrorText(e)));
            return;
          }
          setLocal(() {
            savedPath = path;
            error = null;
            outcome = RecoveryKitOutcome.savedToFile;
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.desktopKitReadyBody,
              style: DType.body.copyWith(color: c.textSecondary, height: 1.45),
            ),
            const SizedBox(height: DSpace.l),
            if (savedPath != null) ...[
              Text(
                l10n.desktopKitSavedTo(savedPath!),
                style: DType.label.copyWith(color: c.success, height: 1.4),
              ),
              const SizedBox(height: DSpace.m),
              DesktopButton(
                label: l10n.close,
                kind: DButtonKind.filled,
                expand: true,
                onPressed: () => Navigator.of(ctx).maybePop(outcome),
              ),
            ] else ...[
              DesktopButton(
                label: l10n.desktopKitSaveToFile,
                icon: FluentIcons.arrow_download_24_regular,
                kind: DButtonKind.filled,
                expand: true,
                onPressed: () => unawaited(saveToFile()),
              ),
              if (error != null) ...[
                const SizedBox(height: DSpace.s),
                Text(error!, style: DType.caption.copyWith(color: c.danger)),
              ],
              const SizedBox(height: DSpace.s),
              DesktopButton(
                label: l10n.desktopKitShowQr,
                kind: DButtonKind.tonal,
                expand: true,
                // 🔴 Телефонный экран копирует набор в буфер и там его
                // оставляет. Сторож снаружи (экран заморожен): через минуту
                // после копирования и при закрытии окна буфер стирается, если
                // в нём всё ещё набор (01.10.2026).
                onPressed: () => unawaited(
                  (guardClipboard ?? DesktopClipboardGuard.instance).guard(
                    payload,
                    showDesktopScreenWindow<void>(
                      ctx,
                      builder: (_) => RecoveryKitScreen(payload: payload),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DSpace.s),
              DesktopButton(
                label: l10n.desktopKitSavedElsewhere,
                kind: DButtonKind.ghost,
                expand: true,
                onPressed: () => unawaited(confirmElsewhere(ctx)),
              ),
              const SizedBox(height: DSpace.s),
              DesktopButton(
                label: l10n.close,
                kind: DButtonKind.ghost,
                expand: true,
                onPressed: () => Navigator.of(ctx).maybePop(outcome),
              ),
            ],
          ],
        );
      },
    ),
  );
  return result ?? outcome;
}
