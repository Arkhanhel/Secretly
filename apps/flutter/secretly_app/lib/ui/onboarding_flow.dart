// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../app/onboarding_state.dart';
import '../security/backup_password_policy.dart';
import '../security/restore_error_classification.dart'
    show EncryptedRestoreException, EncryptedRestoreFailureKind;
import '../security/safe_backup.dart';
import 'app_asset_paths.dart';
import 'backup_refusal_text.dart';
import 'l10n.dart';
import 'motion/motion.dart';
import 'root_messenger.dart';
import 'safe_backup_file_io.dart';
import 'welcome/particle_logo_background.dart';
import 'welcome/welcome_hero.dart';
import 'welcome/welcome_style.dart';
import 'widgets/system_bottom_fade.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

// Первый запуск в стиле макета «Secretly Kit» (17.11.2026):
// приветствие → имя → ключи → резервная копия → уведомления → готово,
// и отдельно — восстановление (облако или файл).
//
// Поменялся только вид. Что сохраняется и когда — как было: имя пишется при
// «Продолжить», копия включается только с паролем по правилам
// `BackupPasswordPolicy`, без профиля копия откладывается, восстановление
// идёт теми же вызовами контроллера.

bool get _supportsPushPermissionPrompt =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Подпись частоты копии — те же строки, что были у выбора частоты.
String _intervalLabel(BuildContext context, int minutes) {
  final l10n = context.l10n;
  switch (minutes) {
    case 360:
      return l10n.onboardingInterval6Hours;
    case 720:
      return l10n.onboardingInterval12Hours;
    case 4320:
      return l10n.onboardingIntervalEvery3Days;
    case 10080:
      return l10n.onboardingIntervalWeekly;
    case 1440:
    default:
      return l10n.onboardingIntervalEveryDay;
  }
}

/// Плавное появление шага, как `sfIn` в макете: снизу на 12 точек и из
/// прозрачности.
Widget _stepTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: const Cubic(0.2, 0.8, 0.2, 1),
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.015),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// Колонка шага: содержимое сверху, кнопки прижаты к низу, при клавиатуре —
/// прокрутка.
class _StepColumn extends StatelessWidget {
  const _StepColumn({
    super.key,
    required this.content,
    required this.actions,
    this.topPadding = 64,
  });

  final List<Widget> content;
  final List<Widget> actions;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                minHeight: box.maxHeight,
              ),
              child: SizedBox(
                width: box.maxWidth,
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, topPadding, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...content,
                        const Spacer(),
                        const SizedBox(height: 32),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── entry point ─────────────────────────────────────────────────────────────

enum _Step { welcome, name, keys, backup, notify, done }

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.controller,
    required this.onComplete,
  });

  final AppController controller;
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.welcome;
  bool _restoreOpen = false;
  WelcomeBackgroundMood _restoreMood = WelcomeBackgroundMood.calm;

  void _go(_Step step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
  }

  bool get _canGoBack => _step == _Step.name;

  void _back() {
    if (_step == _Step.name) _go(_Step.welcome);
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    widget.onComplete();
  }

  void _afterBackup() {
    _go(_supportsPushPermissionPrompt ? _Step.notify : _Step.done);
  }

  Future<void> _openRestoreAccount() async {
    setState(() {
      _restoreOpen = true;
      _restoreMood = WelcomeBackgroundMood.calm;
    });
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        // Под восстановлением остаётся тот же фон: страница прозрачная, а
        // поток входа на это время рисует только фон.
        opaque: false,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (ctx, anim, _) => _RestoreAccountPage(
          controller: widget.controller,
          onComplete: _finish,
          onMood: (mood) {
            if (mounted) setState(() => _restoreMood = mood);
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            _stepTransition(child, anim),
      ),
    );
    if (mounted) setState(() => _restoreOpen = false);
  }

  WelcomeBackgroundMood get _mood {
    if (_restoreOpen) return _restoreMood;
    switch (_step) {
      case _Step.welcome:
        return WelcomeBackgroundMood.hero;
      case _Step.keys:
        return WelcomeBackgroundMood.work;
      case _Step.done:
        return WelcomeBackgroundMood.success;
      case _Step.name:
      case _Step.backup:
      case _Step.notify:
        return WelcomeBackgroundMood.calm;
    }
  }

  Widget _page() {
    switch (_step) {
      case _Step.welcome:
        return _WelcomePage(
          onNext: () => _go(_Step.name),
          onHasAccount: _openRestoreAccount,
        );
      case _Step.name:
        return _NamePage(
          controller: widget.controller,
          onNext: () => _go(_Step.keys),
        );
      case _Step.keys:
        return _KeysPage(
          controller: widget.controller,
          onDone: () => _go(_Step.backup),
        );
      case _Step.backup:
        return _BackupPage(
          controller: widget.controller,
          onNext: _afterBackup,
        );
      case _Step.notify:
        return _NotifyPage(onNext: () => _go(_Step.done));
      case _Step.done:
        return _CompletionPage(
          controller: widget.controller,
          onFinish: _finish,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    return BottomSystemFadeVisibility(
      enabled: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: s.overlayStyle,
        child: PopScope(
          canPop: !_canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: s.dark ? const Color(0xFF060607) : Colors.white,
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                Positioned.fill(child: ParticleLogoBackground(mood: _mood)),
                if (!_restoreOpen)
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Motion.fade,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: _stepTransition,
                      child: KeyedSubtree(
                        key: ValueKey<_Step>(_step),
                        child: _page(),
                      ),
                    ),
                  ),
                if (!_restoreOpen)
                  Positioned(
                    top: 0,
                    left: 10,
                    child: SafeArea(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _canGoBack
                            ? WelcomeBackButton(
                                key: const ValueKey('onboarding-back-visible'),
                                tooltip: context.l10n.onboardingBackTooltip,
                                onPressed: _back,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('onboarding-back-hidden'),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PAGE: WELCOME ───────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext, required this.onHasAccount});
  final VoidCallback onNext;
  final VoidCallback onHasAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WelcomeHero(
      primaryLabel: l10n.welcomeCreateAccount,
      onPrimary: onNext,
      secondaryLabel: l10n.welcomeHaveAccount,
      onSecondary: onHasAccount,
    );
  }
}

// ─── PAGE: NAME ──────────────────────────────────────────────────────────────

class _NamePage extends StatefulWidget {
  const _NamePage({required this.controller, required this.onNext});
  final AppController controller;
  final VoidCallback onNext;

  @override
  State<_NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<_NamePage> {
  final _nickCtrl = TextEditingController();
  final _nickFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nickCtrl.text = widget.controller.myNickname;
    _nickCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nickCtrl.dispose();
    _nickFocus.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_saving) return;
    _nickFocus.unfocus();
    setState(() => _saving = true);
    try {
      await widget.controller.setMyNickname(_nickCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _StepColumn(
      content: [
        Center(child: WelcomeInitialAvatar(name: _nickCtrl.text)),
        const SizedBox(height: 28),
        WelcomeHeading(title: l10n.welcomeNameTitle, body: l10n.welcomeNameBody),
        const SizedBox(height: 28),
        WelcomeNameField(
          controller: _nickCtrl,
          focusNode: _nickFocus,
          hint: l10n.welcomeNameHint,
          onSubmitted: (_) => _onNext(),
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.continueAction,
          busy: _saving,
          onPressed: _onNext,
        ),
      ],
    );
  }
}

// ─── PAGE: KEYS ──────────────────────────────────────────────────────────────

/// «Создаём ключи». Ключи этого устройства заводятся ещё при запуске; экран
/// показывает их готовность и ждёт, пока профиль появится на сервере (на
/// медленной сети первого запуска это бывает не сразу). Ждёт не дольше
/// [_profileWait] — дальше путь не перекрывается: шаг копии сам знает, что
/// делать без профиля.
class _KeysPage extends StatefulWidget {
  const _KeysPage({required this.controller, required this.onDone});
  final AppController controller;
  final VoidCallback onDone;

  @override
  State<_KeysPage> createState() => _KeysPageState();
}

class _KeysPageState extends State<_KeysPage> {
  static const _phraseTime = Duration(milliseconds: 1100);
  static const _profileWait = Duration(seconds: 10);
  int _step = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    for (var i = 1; i <= 2; i++) {
      await Future<void>.delayed(_phraseTime);
      if (!mounted) return;
      setState(() => _step = i);
    }
    await Future<void>.delayed(_phraseTime);
    const poll = Duration(milliseconds: 250);
    var waited = Duration.zero;
    while (mounted &&
        !widget.controller.hasServerProfile &&
        waited < _profileWait) {
      await Future<void>.delayed(poll);
      waited += poll;
    }
    if (!mounted) return;
    setState(() => _step = 3);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final phrases = [
      l10n.welcomeKeysStepIdentity,
      l10n.welcomeKeysStepPrekeys,
      l10n.welcomeKeysStepStorage,
    ];
    final ready = _step >= 3;
    final id = widget.controller.hasServerProfile
        ? widget.controller.profileId.trim()
        : '';
    final height = MediaQuery.sizeOf(context).height;
    // Крупный текст из настроек iPhone (17.11.2026): на маленьком экране с
    // текстом ×2 низ шага не помещался. Отступ сверху сжимается вместе с
    // ростом текста (при обычном размере — прежние 42 %), а на крайний случай
    // шаг прокручивается.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final top = height * 0.42 / scale;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, top, 24, 24),
            child: Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: _stepTransition,
                    child: ready
                        ? Column(
                            key: const ValueKey('keys-ready'),
                            children: [
                              WelcomeHeading(
                                title: l10n.welcomeKeysReady,
                                titleSize: 30,
                              ),
                              if (id.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  id,
                                  textAlign: TextAlign.center,
                                  style: s.mono.copyWith(
                                    fontSize: 15,
                                    letterSpacing: 1.8,
                                    color: s.text.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            phrases[_step.clamp(0, 2)],
                            key: ValueKey('keys-$_step'),
                            textAlign: TextAlign.center,
                            style: s.title.copyWith(fontSize: 26, height: 1.2),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                WelcomeProgressLine(
                  value: ready ? 1 : (_step + 0.5) / 3,
                ),
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
        ),
      ),
    );
  }
}

// ─── PAGE: BACKUP ────────────────────────────────────────────────────────────

class _BackupPage extends StatefulWidget {
  const _BackupPage({required this.controller, required this.onNext});
  final AppController controller;
  final VoidCallback onNext;

  @override
  State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage> {
  late bool _serverEnabled;
  late int _intervalMin;
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  bool _show = false;
  bool _saving = false;
  bool _enabled = false;

  static const _intervals = [
    6 * 60,
    12 * 60,
    24 * 60,
    3 * 24 * 60,
    7 * 24 * 60,
  ];

  @override
  void initState() {
    super.initState();
    _serverEnabled = widget.controller.safeBackupAutoServerEnabled;
    _intervalMin = widget.controller.safeBackupAutoIntervalMin;
    if (!_intervals.contains(_intervalMin)) {
      _intervalMin = 24 * 60;
    }
    _p1.addListener(_onChanged);
    _p2.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    _f1.dispose();
    _f2.dispose();
    super.dispose();
  }

  BackupPasswordValidation get _validation =>
      BackupPasswordPolicy.validate(_p1.text);

  bool get _canEnable =>
      _validation.isValid && _p1.text == _p2.text && !_saving;

  // 🔴 Play, отзыв 7.11.2026: с этой страницы было не уйти. Профиль ещё не
  // создан (медленная сеть при первом запуске) — пароль копии сохранить
  // некуда, `setSafeBackupAutoPassword` бросал «profile not ready», и
  // «Готово» каждый раз снова спрашивало пароль. Копия — не условие входа:
  // без профиля она просто откладывается, включить её можно в Настройках.
  Future<void> _onFinish() async {
    // 🔴 Локализованную строку берём ЗАРАНЕЕ, пока экран точно на месте.
    //
    // За `context.l10n` стоит поиск по дереву виджетов, и на снятом элементе
    // он падает — то есть попытка сказать «копия не сохранилась» упала бы
    // раньше, чем успела что-нибудь сказать.
    final failedMessage = context.l10n.onboardingBackupSaveFailed;
    final laterMessage = context.l10n.onboardingBackupLater;
    if (!_canEnable) return;
    final password = _p1.text;
    // Профиля ещё нет — копия откладывается (см. выше).
    if (!widget.controller.hasServerProfile) {
      setState(() => _saving = true);
      try {
        await widget.controller.setSafeBackupAutoEnabled(false);
      } catch (_) {}
      showRootSnackBar(
        SecretlySnackBar(content: Text(laterMessage)),
        context: mounted ? context : null,
      );
      widget.onNext();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.setSafeBackupAutoEnabled(true);
      await widget.controller.setSafeBackupAutoServerEnabled(_serverEnabled);
      await widget.controller.setSafeBackupAutoIntervalMinutes(_intervalMin);
      await widget.controller.setSafeBackupAutoPassword(password);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _enabled = true;
      });
    } catch (_) {
      // Строка взята ДО ожидания (см. `failedMessage` выше): за `context.l10n`
      // стоит тот же поиск по дереву, и на снятом элементе он упал бы первым.
      //
      // 🔴 Сбой сохранения настроек копии больше не держит человека на этой
      // странице (отзыв 7.11.2026): копию выключаем, говорим об этом и
      // пускаем дальше — включить её можно в Настройках.
      try {
        await widget.controller.setSafeBackupAutoEnabled(false);
      } catch (_) {}
      showRootSnackBar(
        SecretlySnackBar(content: Text(failedMessage)),
        context: mounted ? context : null,
      );
      widget.onNext();
    }
  }

  /// «Настроить позже». Копия без пароля работать не может, поэтому если она
  /// почему-то включена, а пароля нет — выключаем; иначе ничего не трогаем.
  Future<void> _later() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.controller.safeBackupAutoEnabled &&
          !await widget.controller.hasSafeBackupAutoPassword()) {
        await widget.controller.setSafeBackupAutoEnabled(false);
      }
    } catch (_) {}
    widget.onNext();
  }

  String _problemText(BuildContext context, BackupPasswordProblem problem) {
    final l10n = context.l10n;
    switch (problem) {
      case BackupPasswordProblem.tooShort:
        return l10n.backupPasswordTooShort(BackupPasswordPolicy.minLength);
      case BackupPasswordProblem.tooLong:
        return l10n.backupPasswordTooLong(BackupPasswordPolicy.maxLength);
      case BackupPasswordProblem.nonAscii:
        return l10n.backupPasswordNonAscii;
      case BackupPasswordProblem.outerWhitespace:
        return l10n.backupPasswordOuterWhitespace;
      case BackupPasswordProblem.missingUppercase:
        return l10n.backupPasswordMissingUppercase;
      case BackupPasswordProblem.missingSpecial:
        return l10n.backupPasswordMissingSpecial;
    }
  }

  Widget _meter(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final pw = _p1.text;
    final v = _validation;
    // Четыре правила политики — четыре деления полоски.
    const rules = 4;
    var met = 0;
    if (pw.length >= BackupPasswordPolicy.minLength) met++;
    if (pw.contains(RegExp('[A-Z]'))) met++;
    if (!v.problems.contains(BackupPasswordProblem.missingSpecial)) met++;
    if (!v.problems.contains(BackupPasswordProblem.nonAscii) &&
        !v.problems.contains(BackupPasswordProblem.outerWhitespace) &&
        !v.problems.contains(BackupPasswordProblem.tooLong)) {
      met++;
    }
    final double fill;
    final Color color;
    final String label;
    if (pw.isEmpty) {
      fill = 0;
      color = s.error;
      label = l10n.backupPasswordRequirements;
    } else if (!v.isValid) {
      fill = (met / rules).clamp(0.08, 0.75);
      color = met >= 3 ? const Color(0xFFFF9F0A) : s.error;
      label = _problemText(context, v.problems.first);
    } else {
      final strong = pw.length >= 12;
      fill = strong ? 1 : 0.75;
      color = const Color(0xFF30D158);
      label = strong ? l10n.welcomePasswordVeryStrong : l10n.welcomePasswordStrong;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: s.text.withValues(alpha: 0.08)),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 350),
                      widthFactor: fill,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(label, style: s.caption.copyWith(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: _stepTransition,
      child: _enabled ? _buildDone(context) : _buildForm(context),
    );
  }

  Widget _buildDone(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    return _StepColumn(
      key: const ValueKey('backup-done'),
      topPadding: MediaQuery.sizeOf(context).height * 0.22,
      content: [
        Center(
          child: ExcludeSemantics(
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
                child: Icon(AdaptiveIcons.check_rounded, color: s.success, size: 38),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        WelcomeHeading(
          title: l10n.welcomeBackupOnTitle,
          body: l10n.welcomeBackupOnBody(_intervalLabel(context, _intervalMin)),
          titleSize: 30,
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.continueAction,
          onPressed: widget.onNext,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final mismatch = _p2.text.isNotEmpty &&
        _p2.text.length >= _p1.text.length &&
        _p2.text != _p1.text;
    return _StepColumn(
      key: const ValueKey('backup-form'),
      content: [
        WelcomeHeading(
          title: l10n.welcomeBackupTitle,
          body: _serverEnabled
              ? l10n.welcomeBackupBodyCloud
              : l10n.welcomeBackupBodyDevice,
        ),
        const SizedBox(height: 26),
        WelcomeSegmented<bool>(
          value: _serverEnabled,
          options: [
            (true, l10n.welcomeBackupInCloud),
            (false, l10n.welcomeBackupOnDevice),
          ],
          onChanged: _saving
              ? null
              : (v) => setState(() => _serverEnabled = v),
        ),
        const SizedBox(height: 26),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WelcomeTextField(
                controller: _p1,
                focusNode: _f1,
                hint: l10n.welcomeBackupPasswordHint,
                obscure: !_show,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _f2.requestFocus(),
                trailing: TextButton(
                  onPressed: () => setState(() => _show = !_show),
                  style: TextButton.styleFrom(
                    foregroundColor: s.textSecondary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    _show ? l10n.welcomePasswordHide : l10n.welcomePasswordShow,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _meter(context),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Motion.standard,
                child: _validation.isValid || _p2.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: WelcomeTextField(
                          controller: _p2,
                          focusNode: _f2,
                          hint: l10n.welcomeBackupPasswordRepeatHint,
                          obscure: !_show,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            TextInput.finishAutofillContext(shouldSave: true);
                            _onFinish();
                          },
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (mismatch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.onboardingPasswordsDoNotMatch,
                      style: TextStyle(
                        color: s.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.welcomeBackupEnable,
          busy: _saving,
          onPressed: _canEnable
              ? () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  TextInput.finishAutofillContext(shouldSave: true);
                  _onFinish();
                }
              : null,
        ),
        const SizedBox(height: 6),
        WelcomeTextButton(
          label: l10n.welcomeBackupLater,
          onPressed: _saving ? null : _later,
        ),
      ],
    );
  }
}

// ─── PAGE: NOTIFICATIONS ─────────────────────────────────────────────────────

class _NotifyPage extends StatefulWidget {
  const _NotifyPage({required this.onNext});
  final VoidCallback onNext;

  @override
  State<_NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<_NotifyPage> {
  bool _asking = false;

  Future<void> _allow() async {
    if (_asking) return;
    setState(() => _asking = true);
    if (_supportsPushPermissionPrompt) {
      try {
        // Play, отзыв 7.11.2026: без предела «Далее» висело, если ответ
        // системы не приходил (на части телефонов без служб Google).
        // Окно разрешения остаётся на экране, ответ человека запишется сам.
        await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true)
            .timeout(const Duration(seconds: 15));
      } catch (_) {}
    }
    widget.onNext();
  }

  Widget _preview(
    BuildContext context, {
    required String text,
    String? time,
    bool front = true,
  }) {
    final s = WelcomeStyle.of(context);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: s.dark
            ? Color.fromRGBO(40, 40, 44, front ? 0.75 : 0.5)
            : Color.fromRGBO(255, 255, 255, front ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(s.material ? 24 : 22),
        boxShadow: front
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: s.dark ? 0.35 : 0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(AppAssetPaths.appIconPng, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Secretly',
                        style: TextStyle(
                          color: s.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (time != null)
                      Text(time, style: s.caption.copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: s.text.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (front) return card;
    return Opacity(
      opacity: 0.55,
      child: Transform.scale(scale: 0.96, child: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _StepColumn(
      content: [
        const SizedBox(height: 20),
        // Образец уведомления — картинка, а не содержимое: читалке незачем.
        ExcludeSemantics(
          child: Column(
            children: [
              _preview(
                context,
                text: l10n.welcomeNotifyPreviewMessage,
                time: l10n.welcomeNotifyNow,
              ),
              const SizedBox(height: 8),
              _preview(
                context,
                text: l10n.welcomeNotifyPreviewCall,
                front: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        WelcomeHeading(
          title: l10n.welcomeNotifyTitle,
          body: l10n.welcomeNotifyBody,
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.welcomeNotifyAllow,
          busy: _asking,
          onPressed: _allow,
        ),
        const SizedBox(height: 6),
        WelcomeTextButton(
          label: l10n.welcomeNotifyNotNow,
          onPressed: _asking ? null : widget.onNext,
        ),
      ],
    );
  }
}

// ─── PAGE: DONE ──────────────────────────────────────────────────────────────

class _CompletionPage extends StatefulWidget {
  const _CompletionPage({required this.controller, required this.onFinish});

  final AppController controller;
  final Future<void> Function() onFinish;

  @override
  State<_CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<_CompletionPage> {
  bool _copied = false;
  bool _finishing = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyId(BuildContext context) async {
    final id = widget.controller.profileId.trim();
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
    // `maybeOf`: сообщение об удачном копировании не стоит того, чтобы из-за
    // него падало приложение, если экран успел закрыться.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SecretlySnackBar(content: Text(context.l10n.onboardingSecretlyIdCopied)),
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onFinish();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final name = widget.controller.myNickname.trim();
    final profileId = widget.controller.hasServerProfile
        ? widget.controller.profileId.trim()
        : '';
    return _StepColumn(
      topPadding: MediaQuery.sizeOf(context).height * 0.2,
      content: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: const Cubic(0.2, 1.4, 0.4, 1),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: WelcomeInitialAvatar(name: name, size: 96, ring: true),
          ),
        ),
        const SizedBox(height: 24),
        WelcomeHeading(
          title: name.isEmpty
              ? l10n.welcomeDoneTitleNoName
              : l10n.welcomeDoneTitle(name),
          body: l10n.welcomeDoneBody,
        ),
        if (profileId.isNotEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: Semantics(
              button: true,
              label: '${l10n.onboardingYourSecretlyId}: $profileId',
              value: _copied ? l10n.welcomeCopied : l10n.welcomeCopy,
              excludeSemantics: true,
              onTap: () => _copyId(context),
              child: Material(
                color: s.text.withValues(alpha: 0.07),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _copyId(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(profileId, style: s.mono),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _copied
                                ? s.success.withValues(alpha: 0.18)
                                : s.text.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _copied ? l10n.welcomeCopied : l10n.welcomeCopy,
                            style: TextStyle(
                              color: _copied ? s.success : s.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.welcomeDoneIdCaption,
            textAlign: TextAlign.center,
            style: s.caption.copyWith(fontSize: 12.5),
          ),
        ],
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.welcomeOpenApp,
          busy: _finishing,
          onPressed: _finish,
        ),
      ],
    );
  }
}

// ─── RESTORE ACCOUNT ─────────────────────────────────────────────────────────

enum _RestoreView { pick, cloud, file, working }

enum _RestorePhase { download, decrypt, apply }

class _RestoreAccountPage extends StatefulWidget {
  const _RestoreAccountPage({
    required this.controller,
    required this.onComplete,
    required this.onMood,
  });

  final AppController controller;
  final Future<void> Function() onComplete;
  final ValueChanged<WelcomeBackgroundMood> onMood;

  @override
  State<_RestoreAccountPage> createState() => _RestoreAccountPageState();
}

class _RestoreAccountPageState extends State<_RestoreAccountPage> {
  static final Object _manualBackupFilePick = Object();

  _RestoreView _view = _RestoreView.pick;
  _RestoreView _formView = _RestoreView.pick;
  _RestorePhase _phase = _RestorePhase.download;

  // Облако. Поле ID начинается ПУСТЫМ: восстановление с сервера — это вход в
  // ДРУГОЙ (ваш настоящий) Secretly ID, а не в только что созданный на этой
  // установке. Подставленный id нового устройства человеку приходилось
  // стирать каждый раз.
  final _pidC = TextEditingController();
  final _cloudPwC = TextEditingController();
  final _pidF = FocusNode();
  final _cloudPwF = FocusNode();

  // Файл.
  String? _filePayload;
  String? _fileName;
  String? _fileMeta;
  final _filePwC = TextEditingController();
  final _filePwF = FocusNode();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_pidC, _cloudPwC, _filePwC]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _pidC.dispose();
    _cloudPwC.dispose();
    _pidF.dispose();
    _cloudPwF.dispose();
    _filePwC.dispose();
    _filePwF.dispose();
    super.dispose();
  }

  void _show(_RestoreView view) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _view = view;
      if (view != _RestoreView.working) _formView = view;
    });
    widget.onMood(
      view == _RestoreView.working
          ? WelcomeBackgroundMood.work
          : WelcomeBackgroundMood.calm,
    );
  }

  void _setPhase(_RestorePhase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  /// Ошибка — назад к форме, с которой начали.
  void _backToForm() {
    if (mounted && _view == _RestoreView.working) _show(_formView);
  }

  void _back() {
    if (_view == _RestoreView.working) return;
    if (_view == _RestoreView.pick) {
      Navigator.of(context).pop();
    } else {
      _show(_RestoreView.pick);
    }
  }

  /// 🔴 СООБЩЕНИЕ ПЕРЕЖИВАЕТ ЭКРАН (15.09.2026, найдено на живом телефоне).
  ///
  /// Здесь стояло `ScaffoldMessenger.of(context)` под охраной `mounted` — и
  /// этого было мало. Запрос резервной копии с сервера длится дольше, чем
  /// живёт страница: к моменту ответа её элемент уже снят с дерева, а у
  /// снятого элемента поиск наследуемых виджетов не находит ничего. Вместо
  /// надписи приложение роняло `No ScaffoldMessenger widget found` —
  /// неперехваченным исключением, то есть человек, у которого не
  /// восстановился аккаунт, не получал никакого объяснения.
  ///
  /// Теперь сообщение идёт через корневой `ScaffoldMessenger` приложения: он
  /// есть всегда и ни от какого экрана не зависит. Проверки `mounted` тут
  /// больше нет намеренно — она отменяла ровно то, ради чего это написано.
  void _snack(String msg) {
    showRootSnackBar(
      SecretlySnackBar(content: Text(msg)),
      context: mounted ? context : null,
    );
  }

  String _formatBackupBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  String _formatBackupCandidateModified(DateTime modifiedAt) {
    final dt = modifiedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _backupCandidateLocationLabel(SafeBackupFileCandidate candidate) {
    switch (candidate.location) {
      case SafeBackupFileCandidateLocation.appLocal:
        return context.l10n.onboardingBackupLocalCandidate;
      case SafeBackupFileCandidateLocation.downloads:
        return context.l10n.onboardingDownloads;
      case SafeBackupFileCandidateLocation.externalFolder:
        return context.l10n.onboardingDeviceFolder;
    }
  }

  String _backupCandidateSubtitle(SafeBackupFileCandidate candidate) {
    return '${_backupCandidateLocationLabel(candidate)} · ${_formatBackupBytes(candidate.sizeBytes)} · ${_formatBackupCandidateModified(candidate.modifiedAt)}';
  }

  Future<void> _pickBackupFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final candidates = await discoverSafeBackupFilesOnDevice();
      if (!mounted) return;
      final action = await showWelcomeSheet<Object>(
        context: context,
        builder: (ctx) => _FoundBackupsSheet(
          candidates: candidates,
          subtitleOf: _backupCandidateSubtitle,
          manualPick: _manualBackupFilePick,
        ),
      );
      if (!mounted || action == null) return;
      try {
        if (identical(action, _manualBackupFilePick)) {
          final payload = await pickSafeBackupPayloadFromFile(
            dialogTitle: context.l10n.onboardingChooseBackupFileTitle,
          );
          if (!mounted || payload == null || payload.isEmpty) return;
          setState(() {
            _filePayload = payload;
            _fileName = context.l10n.welcomeRestoreFileChosen;
            _fileMeta = _formatBackupBytes(utf8Length(payload));
          });
        } else if (action is SafeBackupFileCandidate) {
          final payload = await readSafeBackupPayloadFromPath(action.path);
          if (!mounted || payload == null || payload.isEmpty) return;
          setState(() {
            _filePayload = payload;
            _fileName = action.displayName;
            _fileMeta = _backupCandidateSubtitle(action);
          });
        }
        _filePwF.requestFocus();
      } catch (_) {
        _snack(context.l10n.onboardingReadBackupFailed);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Длина текста в байтах UTF-8 — для подписи размера выбранного файла.
  static int utf8Length(String s) {
    var n = 0;
    for (final r in s.runes) {
      n += r < 0x80
          ? 1
          : r < 0x800
          ? 2
          : r < 0x10000
          ? 3
          : 4;
    }
    return n;
  }

  Future<void> _restoreFromServer() async {
    final profileId = _pidC.text.trim();
    final password = _cloudPwC.text;
    if (profileId.isEmpty || password.isEmpty) return;
    _setPhase(_RestorePhase.download);
    _show(_RestoreView.working);
    try {
      final (exists, payload, _) = await widget.controller.backupGetFromServer(
        profileId,
        useDeviceAuth: false,
        // Э-1 (SEC-01): пароль уже введён в этой же форме — из него выводится
        // токен доступа, заменяющий подпись там, где ключей ещё нет.
        backupPassword: password,
      );
      if (!mounted) return;
      if (!exists || payload == null || payload.trim().isEmpty) {
        _backToForm();
        _snack(
          serverBackupRefusalText(
            context,
            context.l10n,
            widget.controller.lastServerBackupRefusal,
            fallback: context.l10n.onboardingServerBackupNotFound,
          ),
        );
        return;
      }

      try {
        _setPhase(_RestorePhase.decrypt);
        final plain = await widget.controller
            .decryptSafeBackupPayloadForRestore(
              payload: payload,
              password: password,
            );
        if (!mounted) return;
        final confirmed = await _confirmSafeBackupRestore(plain);
        if (!confirmed) {
          _backToForm();
          return;
        }
        _setPhase(_RestorePhase.apply);
        await widget.controller.restoreFromSafeBackup(
          plain,
          completeOnboarding: true,
          // FIX (2026-07-13, device-churn): reuse the backed-up identity by
          // default. И-1 (TZ_I1_IDENTITY_2026-07-21): under the verified
          // server switch restoreFromSafeBackup OVERRIDES this and comes up
          // as a new device — the snapshot carries no ratchet tables, so
          // reusing the id would wake a live identity over clean sessions,
          // the exact desync И-1 forbids. The in-flight loss that motivated
          // `false` is now covered by rotation convergence (announce +
          // learn-on-receive + NACK resend).
          restoreAsNewDevice: false,
        );
      } catch (e) {
        _backToForm();
        _snack(_describeError(e));
        return;
      }

      if (!mounted) return;
      await widget.onComplete();
      // 🔴 Закрытие экрана — уборка ПОСЛЕ успеха, и её отказ не повод
      // показывать «восстановление не удалось». `maybeOf` вместо `of`: к
      // этому мгновению страницы может уже не быть — её снимает переход на
      // главный экран, который делает `onComplete`.
      if (mounted) Navigator.maybeOf(context)?.pop();
    } catch (e) {
      _backToForm();
      _snack(_describeError(e));
    }
  }

  Future<void> _restoreFromFile() async {
    final payload = _filePayload;
    final pw = _filePwC.text;
    if (payload == null || payload.isEmpty || pw.isEmpty) return;
    _setPhase(_RestorePhase.decrypt);
    _show(_RestoreView.working);
    try {
      try {
        final plain = await widget.controller
            .decryptSafeBackupPayloadForRestore(payload: payload, password: pw);
        if (!mounted) return;
        final confirmed = await _confirmSafeBackupRestore(plain);
        if (!confirmed) {
          _backToForm();
          return;
        }
        _setPhase(_RestorePhase.apply);
        await widget.controller.restoreFromSafeBackup(
          plain,
          completeOnboarding: true,
          // FIX (2026-07-13, device-churn): reuse the backed-up identity by
          // default. И-1 (TZ_I1_IDENTITY_2026-07-21): under the verified
          // server switch restoreFromSafeBackup OVERRIDES this and comes up
          // as a new device — the snapshot carries no ratchet tables, so
          // reusing the id would wake a live identity over clean sessions,
          // the exact desync И-1 forbids. The in-flight loss that motivated
          // `false` is now covered by rotation convergence (announce +
          // learn-on-receive + NACK resend).
          restoreAsNewDevice: false,
        );
      } catch (e) {
        _backToForm();
        _snack(_describeError(e));
        return;
      }

      if (!mounted) return;
      await widget.onComplete();
      if (mounted) Navigator.maybeOf(context)?.pop();
    } catch (e) {
      _backToForm();
      _snack(_describeError(e));
    }
  }

  int _snapshotRowCount(SafeBackupPlainV1 plain, String table) {
    final rows = plain.dbSnapshot?[table];
    return rows is List ? rows.length : 0;
  }

  Future<bool> _confirmSafeBackupRestore(SafeBackupPlainV1 plain) async {
    final fileCount = plain.filesB64ByRelativePath?.length ?? 0;
    final l10n = context.l10n;
    final ok = await showWelcomeSheet<bool>(
      context: context,
      builder: (ctx) {
        final s = WelcomeStyle.of(ctx);
        final rows = [
          l10n.onboardingSecretlyIdSummary(plain.profileId),
          l10n.onboardingContactsSummary(plain.contacts.length),
          l10n.onboardingMessagesSummary(_snapshotRowCount(plain, 'events')),
          l10n.onboardingChatsSummary(
            _snapshotRowCount(plain, 'conversations'),
          ),
          l10n.onboardingMediaFilesSummary(fileCount),
        ];
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.onboardingRestoreThisBackupTitle,
                  style: s.title.copyWith(fontSize: 26, height: 1.15),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.onboardingRestoreThisBackupBody, style: s.body),
              const SizedBox(height: 20),
              WelcomeGlass(
                fill: s.sheetCardFill,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                          child: Text(
                            rows[i],
                            style: TextStyle(
                              color: i == 0 ? s.text : s.textSecondary,
                              fontSize: i == 0 ? 15 : 14,
                              fontWeight:
                                  i == 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              WelcomePrimaryButton(
                label: l10n.restore,
                height: 52,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 6),
              WelcomeTextButton(
                label: l10n.cancel,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        );
      },
    );
    return ok == true;
  }

  String _describeError(Object e) {
    if (e is EncryptedRestoreException) {
      return e.kind == EncryptedRestoreFailureKind.wrongPassword
          ? context.l10n.wrongPassword
          : context.l10n.onboardingBrokenBackup;
    }
    return context.l10n.onboardingRestoreFailed;
  }

  // ── views ──

  Widget _pickView(BuildContext context) {
    final l10n = context.l10n;
    return _StepColumn(
      key: const ValueKey('restore-pick'),
      content: [
        WelcomeHeading(
          title: l10n.welcomeRestoreTitle,
          body: l10n.welcomeRestoreSubtitle,
        ),
        const SizedBox(height: 28),
        WelcomeGlass(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                WelcomeChoiceRow(
                  first: true,
                  title: l10n.welcomeRestoreCloudTitle,
                  subtitle: l10n.welcomeRestoreCloudBody,
                  onTap: () => _show(_RestoreView.cloud),
                ),
                WelcomeChoiceRow(
                  title: l10n.welcomeRestoreFileTitle,
                  subtitle: l10n.onboardingRestoreFromDeviceSubtitle,
                  onTap: () => _show(_RestoreView.file),
                ),
              ],
            ),
          ),
        ),
      ],
      actions: const [],
    );
  }

  Widget _cloudView(BuildContext context) {
    final l10n = context.l10n;
    final ready = _pidC.text.trim().isNotEmpty && _cloudPwC.text.isNotEmpty;
    return _StepColumn(
      key: const ValueKey('restore-cloud'),
      content: [
        WelcomeHeading(
          title: l10n.welcomeRestoreCloudTitle,
          body: l10n.welcomeRestoreCloudFormBody,
        ),
        const SizedBox(height: 24),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: l10n.secretlyIdLabel,
                child: WelcomeTextField(
                  controller: _pidC,
                  focusNode: _pidF,
                  hint: l10n.secretlyIdHint,
                  monospace: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _cloudPwF.requestFocus(),
                ),
              ),
              const SizedBox(height: 10),
              WelcomeTextField(
                controller: _cloudPwC,
                focusNode: _cloudPwF,
                hint: l10n.welcomeRestoreBackupPasswordHint,
                obscure: true,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _restoreFromServer(),
              ),
            ],
          ),
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.restore,
          onPressed: ready ? _restoreFromServer : null,
        ),
      ],
    );
  }

  Widget _fileView(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final hasFile = _filePayload != null;
    final ready = hasFile && _filePwC.text.isNotEmpty;
    return _StepColumn(
      key: const ValueKey('restore-file'),
      content: [
        WelcomeHeading(
          title: l10n.welcomeRestoreFileFormTitle,
          body: l10n.welcomeRestoreFileFormBody,
        ),
        const SizedBox(height: 24),
        if (!hasFile)
          Semantics(
            button: true,
            label: l10n.welcomeRestoreFilePick,
            hint: l10n.onboardingRestoreFromDeviceSubtitle,
            excludeSemantics: true,
            onTap: _picking ? null : _pickBackupFile,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _picking ? null : _pickBackupFile,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: s.text.withValues(alpha: 0.18),
                  radius: 20,
                ),
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: _picking
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: SecretlySpinner(
                              strokeWidth: 2.2,
                              color: s.text,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.welcomeRestoreFilePick,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: s.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.onboardingRestoreFromDeviceSubtitle,
                                  textAlign: TextAlign.center,
                                  style: s.caption,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          )
        else
          WelcomeGlass(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 36,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s.dark
                            ? const Color(0xFFF5F5F4)
                            : const Color(0xFFE6E6EA),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 3,
                            width: double.infinity,
                            child: ColoredBox(color: Color(0xFFC9C9CC)),
                          ),
                          SizedBox(height: 4),
                          SizedBox(
                            height: 3,
                            width: 16,
                            child: ColoredBox(color: Color(0xFFC9C9CC)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: s.text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fileMeta ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: s.caption.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _picking
                        ? null
                        : () => setState(() {
                            _filePayload = null;
                            _fileName = null;
                            _fileMeta = null;
                          }),
                    style: TextButton.styleFrom(
                      foregroundColor: s.textSecondary,
                    ),
                    child: Text(l10n.welcomeRestoreFileOther),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        WelcomeTextField(
          controller: _filePwC,
          focusNode: _filePwF,
          hint: l10n.password,
          obscure: true,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _restoreFromFile(),
        ),
      ],
      actions: [
        WelcomePrimaryButton(
          label: l10n.restore,
          onPressed: ready ? _restoreFromFile : null,
        ),
      ],
    );
  }

  Widget _workingView(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final text = switch (_phase) {
      _RestorePhase.download => l10n.welcomeRestoreStepDownload,
      _RestorePhase.decrypt => l10n.welcomeRestoreStepDecrypt,
      _RestorePhase.apply => l10n.welcomeRestoreStepApply,
    };
    final progress = switch (_phase) {
      _RestorePhase.download => 0.2,
      _RestorePhase.decrypt => 0.55,
      _RestorePhase.apply => 0.85,
    };
    return SafeArea(
      key: const ValueKey('restore-working'),
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.sizeOf(context).height * 0.42,
            24,
            24,
          ),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: _stepTransition,
                  child: Text(
                    text,
                    key: ValueKey(_phase),
                    textAlign: TextAlign.center,
                    style: s.title.copyWith(fontSize: 26, height: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              WelcomeProgressLine(value: progress),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  l10n.welcomeRestoreNote,
                  textAlign: TextAlign.center,
                  style: s.caption.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final working = _view == _RestoreView.working;
    final Widget view = switch (_view) {
      _RestoreView.pick => _pickView(context),
      _RestoreView.cloud => _cloudView(context),
      _RestoreView.file => _fileView(context),
      _RestoreView.working => _workingView(context),
    };
    return PopScope(
      canPop: _view == _RestoreView.pick,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: _stepTransition,
                child: view,
              ),
            ),
            if (!working)
              Positioned(
                top: 0,
                left: 10,
                child: SafeArea(
                  child: WelcomeBackButton(
                    tooltip: context.l10n.onboardingBackTooltip,
                    onPressed: _back,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Лист «Найденные резервные копии»: список копий на устройстве и выбор
/// файла вручную.
class _FoundBackupsSheet extends StatelessWidget {
  const _FoundBackupsSheet({
    required this.candidates,
    required this.subtitleOf,
    required this.manualPick,
  });

  final List<SafeBackupFileCandidate> candidates;
  final String Function(SafeBackupFileCandidate) subtitleOf;
  final Object manualPick;

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            candidates.isEmpty
                ? l10n.onboardingNoBackupsFound
                : l10n.onboardingFoundBackups,
            style: s.title.copyWith(fontSize: 24, height: 1.15),
          ),
        ),
        const SizedBox(height: 10),
        if (candidates.isEmpty)
          Text(l10n.onboardingNoBackupsFoundBody, style: s.body)
        else
          Flexible(
            child: WelcomeGlass(
              fill: s.sheetCardFill,
              child: Material(
                type: MaterialType.transparency,
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: candidates.length,
                  itemBuilder: (ctx, i) => WelcomeChoiceRow(
                    first: i == 0,
                    title: candidates[i].displayName,
                    subtitle: subtitleOf(candidates[i]),
                    onTap: () => Navigator.of(ctx).pop(candidates[i]),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        WelcomeSecondaryButton(
          label: l10n.chooseManually,
          onPressed: () => Navigator.of(context).pop(manualPick),
        ),
        const SizedBox(height: 6),
        WelcomeTextButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ],
    );
  }
}

/// Пунктирная рамка поля «Найти копию на устройстве».
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
