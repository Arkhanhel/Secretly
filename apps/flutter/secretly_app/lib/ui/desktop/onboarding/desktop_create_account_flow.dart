// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../welcome/particle_logo_background.dart';
import '../../welcome/welcome_style.dart';
import '../app/desktop_app_view_model.dart';
import 'desktop_account_setup.dart';
import 'desktop_auth_scaffold.dart';

/// Создание нового аккаунта прямо на компьютере.
///
/// Низ — [AppController.createDesktopAccountOnThisComputer]: заводит серверный
/// профиль, снимает запрет входа и перезапускает приложение. Здесь — только
/// два человеческих шага вокруг него: имя и обещание про набор восстановления.
///
/// 🔴 ШАГ «СОХРАНИТЕ НАБОР» ЖИВЁТ НЕ ЗДЕСЬ. Создание профиля снимает запрет
/// входа в тот же кадр, и корень окна меняет этот экран на оболочку — шаг,
/// живущий внутри него, исчез бы вместе с ним. Поэтому перед созданием
/// взводится флаг [DesktopAccountSetup.markKitPending], а показывает шаг
/// корень, поверх оболочки. Заодно это переживает закрытие окна посреди
/// создания.
class DesktopCreateAccountFlow extends StatefulWidget {
  const DesktopCreateAccountFlow({
    super.key,
    required this.vm,
    required this.onBack,
  });

  final DesktopAppViewModel vm;
  final VoidCallback onBack;

  @override
  State<DesktopCreateAccountFlow> createState() =>
      _DesktopCreateAccountFlowState();
}

class _DesktopCreateAccountFlowState extends State<DesktopCreateAccountFlow> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _setWorking(true);
    try {
      // Флаг взводится ДО создания, а не после: создание снимает запрет входа
      // и уводит этот экран со сцены. Успеть взвести его «потом» нельзя.
      await DesktopAccountSetup.markKitPending();
      // 🔴 НЕ `createNewServerProfileForCurrentDevice` (30.09.2026): на
      // компьютере тот выходит из аккаунта, а не создаёт его, — человек
      // возвращался к выбору входа ни с чем. Имя уходит сюда же: после
      // создания контроллер перезапускается, и звать `setMyNickname` у
      // уходящего контроллера значило бы потерять имя в гонке.
      await widget.vm.controller.createDesktopAccountOnThisComputer(
        nickname: name,
      );
      // Дальше корень перезапустится: запрет входа снят.
    } catch (e) {
      // Аккаунт не создан — флаг снимаем, иначе шаг «сохраните набор» повис
      // бы над оболочкой, которой ещё нет.
      await DesktopAccountSetup.clearKitPending();
      if (!mounted) return;
      var text = e.toString();
      for (final prefix in const ['Bad state: ', 'StateError: ']) {
        if (text.startsWith(prefix)) text = text.substring(prefix.length);
      }
      _setWorking(false);
      setState(() {
        _busy = false;
        _error = l10n.desktopAuthCreateFailed(text);
      });
    }
  }

  /// Ход создания, пока идёт [AppController.createDesktopAccountOnThisComputer]:
  /// фразы сменяются по очереди, полоска растёт, фон «работает».
  int _phase = 0;
  Timer? _phaseTimer;

  void _setWorking(bool working) {
    _phaseTimer?.cancel();
    _phaseTimer = null;
    if (working) {
      _phase = 0;
      _phaseTimer = Timer.periodic(const Duration(milliseconds: 1100), (t) {
        if (!mounted || _phase >= 2) return;
        setState(() => _phase++);
      });
    }
    WelcomeBackdrop.setMood(
      context,
      working ? WelcomeBackgroundMood.work : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _busy ? _working(context) : _form(context),
    );
  }

  Widget _working(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    final phrases = [
      l10n.welcomeKeysStepIdentity,
      l10n.welcomeKeysStepPrekeys,
      l10n.welcomeKeysStepStorage,
    ];
    return Center(
      key: const ValueKey('create-working'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.sizeOf(context).height * 0.52,
          24,
          24,
        ),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              label: l10n.desktopAuthCreating,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: Text(
                  phrases[_phase.clamp(0, 2)],
                  key: ValueKey(_phase),
                  textAlign: TextAlign.center,
                  style: s.title.copyWith(fontSize: 26, height: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            WelcomeProgressLine(value: (_phase + 0.5) / 3),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                l10n.welcomeKeysNote,
                textAlign: TextAlign.center,
                style: s.caption.copyWith(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    return DesktopAuthScaffold(
      key: const ValueKey('create-form'),
      onBack: _busy ? null : widget.onBack,
      title: l10n.desktopAuthNameTitle,
      subtitle: l10n.desktopAuthNameBody,
      leading: WelcomeInitialAvatar(name: _name.text),
      children: [
        WelcomeNameField(
          controller: _name,
          focusNode: _nameFocus,
          hint: l10n.desktopProfileName,
          onSubmitted: (_) => _create(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.error,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Сбитые часы — самая частая и самая непонятная причина отказа:
          // сервер отвергает подпись, а человек видит только «не удалось».
          Text(
            l10n.desktopAuthCheckClock,
            textAlign: TextAlign.center,
            style: s.caption,
          ),
        ],
        const SizedBox(height: 36),
        WelcomePrimaryButton(
          label: l10n.desktopAuthContinue,
          // Пустое имя не пропускаем: без него собеседники увидят сырой
          // идентификатор вместо человека.
          onPressed: (_busy || _name.text.trim().isEmpty) ? null : _create,
        ),
      ],
    );
  }
}
