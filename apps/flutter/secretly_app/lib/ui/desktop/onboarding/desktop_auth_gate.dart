// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../app/desktop_app_view_model.dart';
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';
import 'desktop_create_account_flow.dart';
import 'desktop_onboarding_screen.dart';
import 'desktop_restore_flow.dart';

/// Первый экран на свежем компьютере: КАК войти.
///
/// 🔴 ВЫБОРА НЕ БЫЛО ВООБЩЕ, И ЭТО БЫЛО ВЕРНО РОВНО ДО СМЕНЫ ЦЕНЫ.
///
/// Компьютерная версия делалась вторым экраном к ПЛАТНОМУ телефонному
/// приложению: раз человек уже купил телефонную версию, у него телефон есть по
/// условию, и единственный вход — привязка по QR. Приложение стало бесплатным
/// с подписками, и условие отпало: к нам теперь приходят люди без телефонной
/// версии вовсе.
///
/// 🔴 ЛИЧНОСТЬ НЕ СОЗДАЁТСЯ ДО ВЫБОРА. Привязка по QR заводит серверный
/// профиль уже на показе кода (`createDesktopLinkRequest` →
/// `_ensureKeysSetup(allowServerProfileAutoCreate: true)`), и этот профиль
/// потом заменяется профилем с телефона. Если бы экран выбора оставил всё как
/// есть, каждый ЗАПУСК плодил бы брошенный профиль на сервере ключей — ещё до
/// того, как человек что-нибудь выбрал. Поэтому ни одна кнопка здесь ничего не
/// создаёт: создаёт выбранный путь.
///
/// Порядок кнопок не алфавитный: «через телефон» первым, потому что у
/// большинства Secretly уже на телефоне, и это и самый быстрый путь, и самый
/// безопасный — аккаунт остаётся в двух местах сразу.
class DesktopAuthGate extends StatefulWidget {
  const DesktopAuthGate({super.key, required this.vm});

  final DesktopAppViewModel vm;

  @override
  State<DesktopAuthGate> createState() => _DesktopAuthGateState();
}

enum _AuthChoice { none, phone, create, restore }

class _DesktopAuthGateState extends State<DesktopAuthGate> {
  _AuthChoice _choice = _AuthChoice.none;

  void _back() => setState(() => _choice = _AuthChoice.none);

  @override
  Widget build(BuildContext context) {
    switch (_choice) {
      case _AuthChoice.phone:
        // Экран привязки НЕ ТРОНУТ: это единственный вход, который работал до
        // сегодняшнего дня, и ломать его ради нового выбора нельзя.
        return DesktopOnboardingScreen(vm: widget.vm, onBack: _back);
      case _AuthChoice.create:
        return DesktopCreateAccountFlow(vm: widget.vm, onBack: _back);
      case _AuthChoice.restore:
        return DesktopRestoreFlow(vm: widget.vm, onBack: _back);
      case _AuthChoice.none:
        return _buildChoice(context);
    }
  }

  Widget _buildChoice(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: c.bg,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DSpace.xl2),
        child: ConstrainedBox(
          // Тот же предел, что у настроек: колонка выбора на весь ультраширокий
          // монитор читалась бы так же плохо.
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.desktopAuthGateTitle,
                textAlign: TextAlign.center,
                style: DType.display.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: DSpace.s),
              Text(
                l10n.desktopAuthGateSubtitle,
                textAlign: TextAlign.center,
                style: DType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DSpace.xl2),
              _ChoiceCard(
                icon: FluentIcons.phone_24_regular,
                title: l10n.desktopAuthPhoneTitle,
                body: l10n.desktopAuthPhoneBody,
                primary: true,
                onTap: () => setState(() => _choice = _AuthChoice.phone),
              ),
              const SizedBox(height: DSpace.m),
              _ChoiceCard(
                icon: FluentIcons.person_add_24_regular,
                title: l10n.desktopAuthCreateTitle,
                body: l10n.desktopAuthCreateBody,
                onTap: () => setState(() => _choice = _AuthChoice.create),
              ),
              const SizedBox(height: DSpace.m),
              _ChoiceCard(
                icon: FluentIcons.arrow_counterclockwise_24_regular,
                title: l10n.desktopAuthRestoreTitle,
                body: l10n.desktopAuthRestoreBody,
                onTap: () => setState(() => _choice = _AuthChoice.restore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Одна из трёх дорог. Подпись под названием — не украшение: каждая дорога
/// имеет последствие, о котором человек не догадается сам (переедет ли
/// переписка, можно ли будет купить подписку).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  /// Рекомендуемая дорога — видна плотнее прочих, но НЕ единственная:
  /// остальные две не спрятаны и не приглушены до неразличимости.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        padding: const EdgeInsets.all(DSpace.l),
        decoration: BoxDecoration(
          color: primary
              ? c.accentPrimary.withValues(alpha: hovered ? 0.18 : 0.12)
              : (hovered ? c.hover : c.chatList),
          border: Border.all(
            color: primary
                ? c.accentPrimary.withValues(alpha: 0.55)
                : c.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: primary ? c.accentPrimary : c.textSecondary,
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: DType.title.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: DType.label
                        .copyWith(color: c.textSecondary, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DSpace.s),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
