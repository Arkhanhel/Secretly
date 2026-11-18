// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../welcome/particle_logo_background.dart';
import '../../welcome/welcome_hero.dart';
import '../../welcome/welcome_style.dart';
import '../app/desktop_app_view_model.dart';
import 'desktop_create_account_flow.dart';
import 'desktop_onboarding_screen.dart';
import 'desktop_restore_flow.dart';

/// Вход на компьютере: приветствие, потом выбор из трёх дорог (макет
/// «Secretly Kit», 17.11.2026).
///
/// 🔴 ВЫБОР ИЗ ТРЁХ, А НЕ СРАЗУ QR (23.09.2026). Компьютерная версия делалась
/// вторым экраном к телефонному приложению; приложение стало бесплатным, и
/// приходят те, у кого телефонной версии нет вовсе. Телефон — первым и
/// главной кнопкой: у большинства Secretly уже там, и это самый быстрый и
/// самый безопасный путь (аккаунт остаётся в двух местах).
///
/// 🔴 Пояснения к дорогам — в значках «?» у каждой кнопки (решение владельца
/// 17.11.2026: минималистично, но не молча). Про подписку у «Нового
/// аккаунта» по-прежнему сказано ДО создания — в его «?».
///
/// Экран выбора сам ничего не создаёт: привязка заводит серверный профиль уже
/// на показе QR, и делать это до выбора нельзя.
class DesktopAuthGate extends StatefulWidget {
  const DesktopAuthGate({super.key, required this.vm});

  final DesktopAppViewModel vm;

  @override
  State<DesktopAuthGate> createState() => _DesktopAuthGateState();
}

enum _AuthChoice { welcome, none, phone, create, restore }

class _DesktopAuthGateState extends State<DesktopAuthGate> {
  _AuthChoice _choice = _AuthChoice.welcome;

  void _go(_AuthChoice choice) => setState(() => _choice = choice);
  void _back() => _go(_AuthChoice.none);

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return ColoredBox(
      color: s.dark ? const Color(0xFF060607) : Colors.white,
      child: WelcomeBackdrop(
        mood: _choice == _AuthChoice.welcome
            ? WelcomeBackgroundMood.hero
            : WelcomeBackgroundMood.calm,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: const Cubic(0.2, 0.8, 0.2, 1),
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.015),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<_AuthChoice>(_choice),
            child: _page(context),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_choice) {
      case _AuthChoice.welcome:
        return WelcomeHero(
          large: true,
          primaryLabel: l10n.welcomeStart,
          onPrimary: () => _go(_AuthChoice.none),
        );
      case _AuthChoice.phone:
        return DesktopOnboardingScreen(vm: widget.vm, onBack: _back);
      case _AuthChoice.create:
        return DesktopCreateAccountFlow(vm: widget.vm, onBack: _back);
      case _AuthChoice.restore:
        return DesktopRestoreFlow(
          vm: widget.vm,
          onBack: _back,
          onUsePhone: () => _go(_AuthChoice.phone),
        );
      case _AuthChoice.none:
        return _buildChoice(context);
    }
  }

  Widget _buildChoice(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 64,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WelcomeHeading(
                            title: l10n.welcomeDesktopChooseTitle,
                            body: l10n.welcomeDesktopChooseBody,
                            titleSize: 34,
                          ),
                          const SizedBox(height: 36),
                          WelcomePrimaryButton(
                            label: l10n.desktopAuthPhoneTitle,
                            onPressed: () => _go(_AuthChoice.phone),
                            trailing: WelcomeInfoDot(
                              message: l10n.desktopAuthPhoneBody,
                              color: s.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          WelcomeOrDivider(label: l10n.welcomeOr),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: WelcomeSecondaryButton(
                                  label: l10n.welcomeDesktopNewAccount,
                                  onPressed: () => _go(_AuthChoice.create),
                                  trailing: WelcomeInfoDot(
                                    message: l10n.desktopAuthCreateBody,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: WelcomeSecondaryButton(
                                  label: l10n.desktopAuthRestoreTitle,
                                  onPressed: () => _go(_AuthChoice.restore),
                                  trailing: WelcomeInfoDot(
                                    message: l10n.desktopAuthRestoreBody,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          child: WelcomeBackButton(
            tooltip: l10n.desktopAuthBack,
            onPressed: () => _go(_AuthChoice.welcome),
          ),
        ),
      ],
    );
  }
}
