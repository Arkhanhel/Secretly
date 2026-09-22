// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../contact_action_error_text.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/desktop_text_field.dart';
import 'desktop_app_view_model.dart';

/// Дать контакту своё имя.
///
/// 🔴 ОДИН ВЫЗОВ НА ОБА МЕСТА, И ЭТО НЕ ЭКОНОМИЯ СТРОК. Переименовать контакт
/// можно из раздела «Контакты» и из карточки человека в переписке. Две копии
/// одного окна расходятся не сразу и не целиком: сперва в одной появится
/// подсказка, потом в другой — другое сообщение об ошибке, и человек получит
/// два разных обещания об одном действии. Ровно так в этом окне уже было с
/// выходом из аккаунта (см. `showSignOutDialog`).
///
/// Управляющий берётся через [DesktopAppViewModel], а не напрямую: шов между
/// окном и приложением держит `desktop_controller_seam_ratchet_test`.
///
/// Возвращает `true`, если имя сохранено.
Future<bool> showRenameContactDialog({
  required BuildContext context,
  required DesktopAppViewModel vm,
  required String profileId,
  String? currentName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ctrl = TextEditingController(text: (currentName ?? '').trim());
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.desktopChatsRename,
    size: DDialogSize.small,
    body: DesktopTextField(
      controller: ctrl,
      autofocus: true,
      // Не обязательное: пустое поле СНИМАЕТ своё имя и возвращает то,
      // которым человек назвался сам. Это отдельное действие, и ради него
      // отдельной кнопки заводить не нужно — достаточно стереть.
      hintText: l10n.nameOptionalLabel,
      prefixIcon: FluentIcons.tag_24_regular,
      onSubmitted: (_) => Navigator.of(context).maybePop(true),
    ),
    primary: DDialogAction(
      label: l10n.contactDetailsSave,
      onPressed: () => Navigator.of(context).maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      kind: DButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(false),
    ),
  );
  final name = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || !context.mounted) return false;

  try {
    await vm.controller.renameContact(
      profileId: profileId,
      displayName: name.isEmpty ? null : name,
    );
  } catch (e) {
    if (!context.mounted) return false;
    // Те же слова, что на телефоне: своя формулировка означала бы два разных
    // объяснения одному отказу в одном приложении.
    DesktopSnackbar.show(
      context,
      message: contactActionErrorText(l10n, e),
      kind: DSnackKind.error,
    );
    return false;
  }
  if (!context.mounted) return true;
  unawaited(vm.refreshNow());
  DesktopSnackbar.show(
    context,
    message: l10n.desktopContactsRenamed,
    kind: DSnackKind.success,
  );
  return true;
}
