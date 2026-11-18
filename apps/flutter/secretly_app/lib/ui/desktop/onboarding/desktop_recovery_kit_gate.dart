// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../welcome/particle_logo_background.dart';
import '../../welcome/welcome_style.dart';
import '../app/desktop_app_view_model.dart';
import '../app/recovery_kit_export.dart';
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
  const DesktopRecoveryKitGate({
    super.key,
    required this.vm,
    @visibleForTesting this.pickSavePath,
  });

  final DesktopAppViewModel vm;

  /// Системный выбор места для файла; подменяется только в проверках.
  final RecoveryKitSavePathPicker? pickSavePath;

  @override
  State<DesktopRecoveryKitGate> createState() => _DesktopRecoveryKitGateState();
}

class _DesktopRecoveryKitGateState extends State<DesktopRecoveryKitGate> {
  bool _busy = false;

  /// 🔴 Шаг пройден, только когда набор записан в файл или человек явно
  /// подтвердил, что сохранил его иначе (30.09.2026). Раньше закрытие окна с
  /// QR считалось успехом, и шаг писал «Набор сохранён», не сохранив ничего.
  RecoveryKitOutcome _outcome = RecoveryKitOutcome.notSaved;

  Future<void> _makeKit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await runRecoveryKitExport(
      context: context,
      vm: widget.vm,
      pickSavePath: widget.pickSavePath,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  Future<void> _finish() async {
    await DesktopAccountSetup.clearKitPending();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    final saved = _outcome != RecoveryKitOutcome.notSaved;
    final Widget step;
    if (saved) {
      step = DesktopAuthScaffold(
        key: const ValueKey('kit-saved'),
        // Уйти нельзя: это и есть смысл шага.
        showBack: false,
        title: _outcome == RecoveryKitOutcome.savedToFile
            ? l10n.desktopAuthKitSaved
            : l10n.desktopAuthKitConfirmed,
        subtitle: l10n.welcomeDesktopKitKeepApart,
        leading: ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: const Cubic(0.2, 1.4, 0.4, 1),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.success.withValues(alpha: 0.14),
              ),
              child: Icon(Icons.check_rounded, color: s.success, size: 38),
            ),
          ),
        ),
        children: [
          WelcomePrimaryButton(
            label: l10n.desktopAuthContinue,
            onPressed: () => _finish(),
          ),
        ],
      );
    } else {
      step = DesktopAuthScaffold(
        key: const ValueKey('kit-open'),
        // Уйти нельзя: это и есть смысл шага.
        showBack: false,
        title: l10n.desktopAuthKitTitle,
        subtitle: l10n.desktopAuthKitBody,
        children: [
          WelcomePrimaryButton(
            label: l10n.desktopAuthKitAction,
            onPressed: _busy ? null : () => _makeKit(),
          ),
        ],
      );
    }
    return ColoredBox(
      color: s.dark ? const Color(0xFF060607) : Colors.white,
      child: WelcomeBackdrop(
        mood: saved
            ? WelcomeBackgroundMood.success
            : WelcomeBackgroundMood.calm,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: step,
        ),
      ),
    );
  }
}
