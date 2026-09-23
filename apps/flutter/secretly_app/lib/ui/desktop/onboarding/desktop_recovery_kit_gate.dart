// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../app/desktop_app_view_model.dart';
import '../app/recovery_kit_export.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import 'desktop_account_setup.dart';
import 'desktop_auth_scaffold.dart';

/// Обязательный шаг после создания аккаунта НА КОМПЬЮТЕРЕ: сохранить набор
/// восстановления.
///
/// 🔴 ПОЧЕМУ ЗДЕСЬ НЕТ «ПРОПУСТИТЬ» (решение владельца, 23.09.2026).
///
/// У Secretly нет ни почты, ни номера телефона, ни учётной записи магазина:
/// личность — это ключи на устройстве. Аккаунт, заведённый на компьютере и
/// нигде больше, умирает вместе с диском — и вернуть его не может НИКТО,
/// включая нас. «Пропустить» здесь означало бы предложить человеку риск,
/// последствия которого он на этом экране оценить не может: он ещё не знает,
/// что у него не будет ни письма «восстановить доступ», ни звонка в поддержку.
///
/// 🔴 И ВТОРОЕ, МЕНЕЕ ОЧЕВИДНОЕ. Привязка устроена только в сторону
/// «телефон → компьютер». Телефон присоединяется к аккаунту, созданному здесь,
/// ВОССТАНОВЛЕНИЕМ — то есть этим самым набором. Без него аккаунт не только
/// нельзя вернуть: его нельзя и перенести на телефон, а значит нельзя купить
/// подписку, которая продаётся только в магазинах.
///
/// Экран показывает КОРЕНЬ окна поверх оболочки, а не создание аккаунта:
/// создание снимает запрет входа в тот же кадр и уходит со сцены. Признак
/// живёт в настройках устройства, поэтому шаг переживает и закрытие окна.
class DesktopRecoveryKitGate extends StatefulWidget {
  const DesktopRecoveryKitGate({super.key, required this.vm});

  final DesktopAppViewModel vm;

  @override
  State<DesktopRecoveryKitGate> createState() => _DesktopRecoveryKitGateState();
}

class _DesktopRecoveryKitGateState extends State<DesktopRecoveryKitGate> {
  bool _busy = false;
  bool _done = false;

  Future<void> _makeKit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await runRecoveryKitExport(context: context, vm: widget.vm);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
  }

  Future<void> _finish() async {
    await DesktopAccountSetup.clearKitPending();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return DesktopAuthScaffold(
      // Уйти нельзя: это и есть смысл шага.
      title: l10n.desktopAuthKitTitle,
      subtitle: l10n.desktopAuthKitBody,
      children: [
        if (_done) ...[
          Container(
            padding: const EdgeInsets.all(DSpace.l),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.12),
              border: Border.all(color: c.success.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(DRadii.md),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.checkmark_circle_24_regular,
                    size: 22, color: c.success),
                const SizedBox(width: DSpace.m),
                Expanded(
                  child: Text(
                    l10n.desktopAuthKitSaved,
                    style: DType.body.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DSpace.xl),
          DesktopButton(
            label: l10n.desktopAuthContinue,
            kind: DButtonKind.filled,
            expand: true,
            onPressed: () => _finish(),
          ),
        ] else
          DesktopButton(
            label: l10n.desktopAuthKitAction,
            kind: DButtonKind.filled,
            icon: FluentIcons.key_24_regular,
            expand: true,
            onPressed: _busy ? null : () => _makeKit(),
          ),
      ],
    );
  }
}
