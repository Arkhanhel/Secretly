// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
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

  final result = await DesktopDialog.show<String>(
    context,
    title: l10n.desktopBackupKeyPassword,
    size: DDialogSize.small,
    body: StatefulBuilder(
      builder: (ctx, setLocal) {
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
  first.dispose();
  again.dispose();
  return result;
}

/// Весь путь «сделать набор восстановления»: пароль → ключ → показ.
///
/// 🔴 ОДИН ПУТЬ НА ВСЁ ОКНО. Набор делается из настроек и — с 23.09.2026 —
/// при создании аккаунта на компьютере. Две копии одного пути разошлись бы
/// текстами и проверками, а это тот самый ключ, которым человек однажды будет
/// возвращать себе аккаунт: расхождение здесь стоит аккаунта.
///
/// Возвращает `true`, если набор создан и показан.
Future<bool> runRecoveryKitExport({
  required BuildContext context,
  required DesktopAppViewModel vm,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final password = await promptRecoveryKitPassword(context);
  if (password == null || password.isEmpty || !context.mounted) return false;

  String payload;
  try {
    payload = await vm.controller.createRecoveryKitPayload(password: password);
  } catch (e) {
    if (!context.mounted) return false;
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
    return false;
  }

  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecoveryKitScreen(payload: payload),
    ),
  );
  return true;
}
