// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../app/app_controller.dart';
import '../app/onboarding_state.dart';
import '../security/backup_password_policy.dart';
import '../security/restore_error_classification.dart'
    show EncryptedRestoreException, EncryptedRestoreFailureKind;
import '../security/safe_backup.dart';
import 'app_asset_paths.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'root_messenger.dart';
import 'safe_backup_file_io.dart';
import 'widgets/system_bottom_fade.dart';

// ─── palette ─────────────────────────────────────────────────────────────────

const _bgDeep = Color(0xFF000000);
const _accent1 = Color(0xFF4A6BFF);
const _accent2 = Color(0xFF33A2FF);
const _accentPurple = Color(0xFF7B5CFF);
const _glassWhite = Color(0x14FFFFFF);
const _glassBorder = Color(0x22FFFFFF);
const _lightEdgeToEdgeOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

bool get _supportsPushPermissionPrompt =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// ─── entry point ─────────────────────────────────────────────────────────────

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
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _back() {
    if (_currentPage <= 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    widget.onComplete();
  }

  Future<void> _showCompletion() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _openRestoreAccount() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (ctx, anim, _) => _RestoreAccountPage(
          controller: widget.controller,
          onComplete: _finish,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSystemFadeVisibility(
      enabled: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _lightEdgeToEdgeOverlayStyle,
        child: Scaffold(
          backgroundColor: _bgDeep,
          body: Stack(
            children: [
              const _AnimatedBackground(),
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _WelcomePage(onNext: _next, onHasAccount: _openRestoreAccount),
                _ProfilePage(controller: widget.controller, onNext: _next),
                _BackupPage(
                  controller: widget.controller,
                  onFinish: _showCompletion,
                ),
                _CompletionPage(
                  controller: widget.controller,
                  onFinish: _finish,
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 12,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _currentPage == 0
                      ? const SizedBox.shrink(
                          key: ValueKey('onboarding-back-hidden'),
                        )
                      : _OnboardingBackButton(
                          key: const ValueKey('onboarding-back-visible'),
                          onTap: _back,
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _PageDots(current: _currentPage, total: 4),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _OnboardingBackButton extends StatelessWidget {
  const _OnboardingBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: l10n.onboardingBackTooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: _glassWhite,
          foregroundColor: Colors.white.withValues(alpha: 0.90),
          side: const BorderSide(color: _glassBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
    );
  }
}

// ─── animated background ─────────────────────────────────────────────────────

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _orb1;
  late final AnimationController _orb2;
  late final AnimationController _orb3;

  @override
  void initState() {
    super.initState();
    _orb1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _orb2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
    _orb3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orb1.dispose();
    _orb2.dispose();
    _orb3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_orb1, _orb2, _orb3]),
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _BackgroundPainter(
          t1: _orb1.value,
          t2: _orb2.value,
          t3: _orb3.value,
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.t1, required this.t2, required this.t3});
  final double t1, t2, t3;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF000000), Color(0xFF000000), Color(0xFF020304)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.15 + 0.12 * math.sin(t1 * math.pi * 2)),
        size.height * (0.22 + 0.10 * math.cos(t1 * math.pi * 2)),
      ),
      radius: size.width * 0.38,
      color: _accent1.withValues(alpha: 0.030 + 0.018 * t1),
    );

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.80 + 0.08 * math.cos(t2 * math.pi * 2)),
        size.height * (0.30 + 0.12 * math.sin(t2 * math.pi * 2)),
      ),
      radius: size.width * 0.45,
      color: _accentPurple.withValues(alpha: 0.024 + 0.014 * t2),
    );

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.50 + 0.10 * math.sin(t3 * math.pi * 2 + 1.0)),
        size.height * (0.78 + 0.07 * math.cos(t3 * math.pi * 2)),
      ),
      radius: size.width * 0.42,
      color: _accent2.withValues(alpha: 0.020 + 0.012 * t3),
    );
    _drawParticles(canvas, size, t1, t2);
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawParticles(Canvas canvas, Size size, double t1, double t2) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final rand = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final bx = rand.nextDouble();
      final by = rand.nextDouble();
      final phase = rand.nextDouble() * math.pi * 2;
      final x = size.width * (bx + 0.012 * math.sin(t1 * math.pi * 2 + phase));
      final y = size.height * (by + 0.012 * math.cos(t2 * math.pi * 2 + phase));
      canvas.drawCircle(Offset(x, y), 1.0 + rand.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.t1 != t1 || old.t2 != t2 || old.t3 != t3;
}

// ─── page dots ───────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: active
                ? const LinearGradient(colors: [_accent1, _accent2])
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.22),
          ),
        );
      }),
    );
  }
}

// ─── shared widgets ───────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  const _GradientButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) {
        _press.forward();
        widget.onTap();
      },
      onTapCancel: () => _press.forward(),
      child: ScaleTransition(
        scale: _press,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [_accent1, _accent2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent1.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _glassBorder),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? _accent1).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor ?? _accent1, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _accent1.withValues(alpha: 0.80),
          ),
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 4, bottom: 8),
  child: Text(
    text.toUpperCase(),
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.38),
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  ),
);

// ─── PAGE 1: WELCOME ─────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  const _WelcomePage({required this.onNext, required this.onHasAccount});
  final VoidCallback onNext;
  final VoidCallback onHasAccount;

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _titleCtrl;
  late final AnimationController _cardsCtrl;
  late final AnimationController _btnCtrl;
  late final AnimationController _fingerprintCtrl;

  // Derived animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _cardsFade;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fingerprintCtrl = AnimationController(vsync: this);

    _logoScale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _titleSlide = Tween<double>(
      begin: 28,
      end: 0,
    ).animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));
    _titleFade = CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut);
    _cardsFade = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _logoCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _titleCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _cardsCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _cardsCtrl.dispose();
    _btnCtrl.dispose();
    _fingerprintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, bottomPad + 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: size.height * 0.06),

          // Logo + brand
          FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: Column(
                children: [
                  _LogoHero(
                    controller: _fingerprintCtrl,
                    onDuration: (d) {
                      _fingerprintCtrl.duration = d * 2;
                      _fingerprintCtrl.repeat();
                    },
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [_accent1, _accent2],
                    ).createShader(b),
                    child: const Text(
                      'Secretly',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tagline
          AnimatedBuilder(
            animation: _titleCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _titleSlide.value),
              child: FadeTransition(opacity: _titleFade, child: child),
            ),
            child: Column(
              children: [
                Text(
                  context.l10n.onboardingWelcomeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.onboardingWelcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 15.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: size.height * 0.05),

          // Feature cards
          FadeTransition(
            opacity: _cardsFade,
            child: const RepaintBoundary(child: _FeatureCards()),
          ),

          SizedBox(height: size.height * 0.05),

          // CTA
          FadeTransition(
            opacity: _btnFade,
            child: _GradientButton(
              label: context.l10n.onboardingCreateAccount,
              icon: Icons.arrow_forward_rounded,
              onTap: widget.onNext,
            ),
          ),

          const SizedBox(height: 12),

          // Already have account
          FadeTransition(
            opacity: _btnFade,
            child: GestureDetector(
              onTap: widget.onHasAccount,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _glassBorder, width: 1.5),
                  color: _glassWhite,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restore_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.onboardingAlreadyHaveAccount,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero({required this.controller, required this.onDuration});
  final AnimationController controller;
  final void Function(Duration d) onDuration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring 1
        Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _accent1.withValues(alpha: 0.22),
                _accent1.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // Inner glow ring 2
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _accent1.withValues(alpha: 0.32),
                _accent1.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // Icon container
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2A6E), Color(0xFF1130A8)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent1.withValues(alpha: 0.5),
                blurRadius: 32,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: _accent1.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Lottie.asset(
                AppAssetPaths.fingerprintLottie,
                controller: controller,
                animate: false,
                repeat: false,
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
                onLoaded: (c) => onDuration(c.duration),
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.fingerprint,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    final features = [
      (
        Icons.lock_outline_rounded,
        _accent1,
        context.l10n.onboardingFeatureE2eTitle,
        context.l10n.onboardingFeatureE2eBody,
      ),
      (
        Icons.visibility_off_outlined,
        _accentPurple,
        context.l10n.onboardingFeaturePrivacyTitle,
        context.l10n.onboardingFeaturePrivacyBody,
      ),
      (
        Icons.shield_outlined,
        _accent2,
        context.l10n.onboardingFeatureRelayTitle,
        context.l10n.onboardingFeatureRelayBody,
      ),
    ];
    return Column(
      children: List.generate(features.length, (i) {
        final (icon, color, title, desc) = features[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i < features.length - 1 ? 10 : 0),
          child: _GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── PAGE 2: PROFILE SETUP ───────────────────────────────────────────────────

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.controller, required this.onNext});
  final AppController controller;
  final VoidCallback onNext;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  final _nickCtrl = TextEditingController();
  final _nickFocus = FocusNode();
  bool _notifEnabled = true;
  bool _callsEnabled = true;

  @override
  void initState() {
    super.initState();
    _nickCtrl.text = widget.controller.myNickname;
    _callsEnabled = widget.controller.incomingCallsEnabled;

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<double>(
      begin: 32,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 80)).then((_) {
        if (mounted) _enterCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _nickCtrl.dispose();
    _nickFocus.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    _nickFocus.unfocus();
    await widget.controller.setMyNickname(_nickCtrl.text.trim());
    await widget.controller.setIncomingCallsEnabled(_callsEnabled);
    if (_notifEnabled && _supportsPushPermissionPrompt) {
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: FadeTransition(opacity: _fade, child: child),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topPad + 32, 24, bottomPad + 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  _PageIcon(
                    icon: Icons.person_outline_rounded,
                    color: _accent1,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.onboardingProfileTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingProfileSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
            _sectionLabel(l10n.onboardingProfileNameSection),
            _NicknameField(controller: _nickCtrl, focusNode: _nickFocus),

            const SizedBox(height: 28),
            _sectionLabel(l10n.onboardingNotificationsSection),

            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: l10n.onboardingMessageNotificationsTitle,
              subtitle: l10n.onboardingMessageNotificationsSubtitle,
              value: _notifEnabled,
              onChanged: (v) => setState(() => _notifEnabled = v),
              iconColor: _accent1,
            ),

            const SizedBox(height: 10),

            _SettingsTile(
              icon: Icons.call_outlined,
              title: l10n.onboardingIncomingCallsTitle,
              subtitle: l10n.onboardingIncomingCallsSubtitle,
              value: _callsEnabled,
              onChanged: (v) => setState(() => _callsEnabled = v),
              iconColor: _accent2,
            ),

            const SizedBox(height: 36),

            _GradientButton(
              label: l10n.continueAction,
              icon: Icons.arrow_forward_rounded,
              onTap: _onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorder),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.onboardingProfileNameHint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.badge_outlined,
            color: Colors.white.withValues(alpha: 0.45),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(40)],
        textInputAction: TextInputAction.done,
      ),
    );
  }
}

// ─── PAGE 3: BACKUP SETUP ────────────────────────────────────────────────────

class _BackupPage extends StatefulWidget {
  const _BackupPage({required this.controller, required this.onFinish});
  final AppController controller;
  final Future<void> Function() onFinish;

  @override
  State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  late bool _backupEnabled;
  late bool _serverEnabled;
  late bool _includeMedia;
  late int _intervalMin;
  bool _saving = false;

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
    _backupEnabled = widget.controller.safeBackupAutoEnabled;
    _serverEnabled = widget.controller.safeBackupAutoServerEnabled;
    _includeMedia = widget.controller.safeBackupIncludeMedia;
    _intervalMin = widget.controller.safeBackupAutoIntervalMin;
    if (!_intervals.contains(_intervalMin)) {
      _intervalMin = 24 * 60;
    }

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<double>(
      begin: 32,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 80)).then((_) {
        if (mounted) _enterCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _onFinish() async {
    // 🔴 Локализованную строку берём ЗАРАНЕЕ, пока экран точно на месте.
    //
    // За `context.l10n` стоит поиск по дереву виджетов, и на снятом элементе
    // он падает — то есть попытка сказать «копия не сохранилась» упала бы
    // раньше, чем успела что-нибудь сказать.
    final failedMessage = context.l10n.onboardingBackupSaveFailed;
    setState(() => _saving = true);
    try {
      await widget.controller.setSafeBackupAutoEnabled(_backupEnabled);
      await widget.controller.setSafeBackupAutoServerEnabled(_serverEnabled);
      await widget.controller.setSafeBackupIncludeMedia(_includeMedia);
      await widget.controller.setSafeBackupAutoIntervalMinutes(_intervalMin);
      final hasBackupPassword = await widget.controller
          .hasSafeBackupAutoPassword();
      if (_backupEnabled && !hasBackupPassword) {
        if (!mounted) return;
        final password = await _promptAutoBackupPassword();
        if (password == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await widget.controller.setSafeBackupAutoPassword(password);
      }
      await widget.onFinish();
    } catch (_) {
      // Строка взята ДО ожидания (см. `failedMessage` выше): за `context.l10n`
      // стоит тот же поиск по дереву, и на снятом элементе он упал бы первым.
      if (mounted) setState(() => _saving = false);
      showRootSnackBar(
        SecretlySnackBar(content: Text(failedMessage)),
        context: mounted ? context : null,
      );
    }
  }

  String _passwordRequirementsText(BuildContext context) {
    return context.l10n.backupPasswordRequirements;
  }

  String _passwordProblemText(
    BuildContext context,
    BackupPasswordProblem problem,
  ) {
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

  String _passwordProblemsText(
    BuildContext context,
    BackupPasswordValidation validation,
  ) {
    return validation.problems
        .map((problem) => _passwordProblemText(context, problem))
        .join('\n');
  }

  Future<String?> _promptAutoBackupPassword() async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final f1 = FocusNode();
    final f2 = FocusNode();

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final validation = BackupPasswordPolicy.validate(p1.text);
            final matches = p1.text == p2.text;
            final canSubmit = validation.isValid && matches;

            void submit() {
              if (!canSubmit) return;
              TextInput.finishAutofillContext(shouldSave: true);
              Navigator.of(ctx).pop(p1.text);
            }

            return AlertDialog(
              title: Text(context.l10n.onboardingBackupPasswordTitle),
              content: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: p1,
                      focusNode: f1,
                      decoration: InputDecoration(
                        labelText: context.l10n.password,
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => f2.requestFocus(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: p2,
                      focusNode: f2,
                      decoration: InputDecoration(
                        labelText: context.l10n.confirmPassword,
                        errorText: p2.text.isNotEmpty && !matches
                            ? context.l10n.onboardingPasswordsDoNotMatch
                            : null,
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _passwordRequirementsText(context),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    if (p1.text.isNotEmpty && !validation.isValid) ...[
                      const SizedBox(height: 8),
                      Text(
                        _passwordProblemsText(context, validation),
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: canSubmit ? submit : null,
                  child: Text(context.l10n.continueAction),
                ),
              ],
            );
          },
        );
      },
    );

    f1.dispose();
    f2.dispose();
    p1.dispose();
    p2.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: FadeTransition(opacity: _fade, child: child),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topPad + 32, 24, bottomPad + 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  _PageIcon(
                    icon: Icons.cloud_outlined,
                    color: const Color(0xFF34D399),
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.onboardingBackupTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingBackupSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
            _sectionLabel(l10n.onboardingAutoBackupSection),

            _SettingsTile(
              icon: Icons.backup_outlined,
              title: l10n.onboardingAutoBackupTitle,
              subtitle: l10n.onboardingAutoBackupSubtitle,
              value: _backupEnabled,
              onChanged: (v) => setState(() => _backupEnabled = v),
              iconColor: const Color(0xFF34D399),
            ),

            if (_backupEnabled) ...[
              const SizedBox(height: 28),
              _sectionLabel(l10n.onboardingStorageTypeSection),
              _StorageTypePicker(
                serverEnabled: _serverEnabled,
                onChanged: (v) => setState(() => _serverEnabled = v),
              ),

              const SizedBox(height: 16),
              _SettingsTile(
                icon: Icons.perm_media_outlined,
                title: l10n.onboardingBackupMediaTitle,
                subtitle: l10n.onboardingBackupMediaSubtitle,
                value: _includeMedia,
                onChanged: (v) => setState(() => _includeMedia = v),
                iconColor: _accentPurple,
              ),

              const SizedBox(height: 28),
              _sectionLabel(l10n.onboardingFrequencySection),
              _FrequencyChips(
                intervals: _intervals,
                selected: _intervalMin,
                onSelected: (v) => setState(() => _intervalMin = v),
              ),
            ],

            const SizedBox(height: 36),

            _saving
                ? const Center(
                    child: CircularProgressIndicator(color: _accent2),
                  )
                : _GradientButton(
                    label: l10n.onboardingEnterSecretly,
                    icon: Icons.lock_open_rounded,
                    onTap: _onFinish,
                  ),

            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _saving ? null : _onFinish,
                child: Text(
                  l10n.onboardingSkipBackup,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionPage extends StatelessWidget {
  const _CompletionPage({required this.controller, required this.onFinish});

  final AppController controller;
  final Future<void> Function() onFinish;

  Future<void> _copyId(BuildContext context) async {
    final id = controller.profileId.trim();
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    // `maybeOf`: сообщение об удачном копировании не стоит того, чтобы из-за
    // него падало приложение, если экран успел закрыться.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SecretlySnackBar(content: Text(context.l10n.onboardingSecretlyIdCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final profileId = controller.profileId.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPad + 44, 24, bottomPad + 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                _PageIcon(
                  icon: Icons.check_rounded,
                  color: const Color(0xFF34D399),
                  size: 70,
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.onboardingRegistrationCompleteTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingRegistrationCompleteSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingYourSecretlyId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  profileId.isEmpty ? 'unknown' : profileId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: profileId.isEmpty ? null : () => _copyId(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l10n.onboardingCopyId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: const Color(0xFFFFC857).withValues(alpha: 0.95),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.onboardingRecoveryWarning,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 14,
                      height: 1.42,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            label: l10n.onboardingEnterSecretly,
            icon: Icons.arrow_forward_rounded,
            onTap: onFinish,
          ),
        ],
      ),
    );
  }
}

class _StorageTypePicker extends StatelessWidget {
  const _StorageTypePicker({
    required this.serverEnabled,
    required this.onChanged,
  });
  final bool serverEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _GlassCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _StorageTypeOption(
            icon: Icons.cloud_outlined,
            label: l10n.onboardingStorageCloud,
            desc: l10n.onboardingStorageCloudSubtitle,
            selected: serverEnabled,
            onTap: () => onChanged(true),
            color: _accent2,
          ),
          const SizedBox(width: 6),
          _StorageTypeOption(
            icon: Icons.phone_android_outlined,
            label: l10n.onboardingStorageLocal,
            desc: l10n.onboardingStorageLocalSubtitle,
            selected: !serverEnabled,
            onTap: () => onChanged(false),
            color: _accentPurple,
          ),
        ],
      ),
    );
  }
}

class _StorageTypeOption extends StatelessWidget {
  const _StorageTypeOption({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.55), width: 1.5)
                : Border.all(color: Colors.transparent),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? color : Colors.white.withValues(alpha: 0.40),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyChips extends StatelessWidget {
  const _FrequencyChips({
    required this.intervals,
    required this.selected,
    required this.onSelected,
  });
  final List<int> intervals;
  final int selected;
  final ValueChanged<int> onSelected;

  String _labelFor(BuildContext context, int minutes) {
    final l10n = context.l10n;
    switch (minutes) {
      case 360:
        return l10n.onboardingInterval6Hours;
      case 720:
        return l10n.onboardingInterval12Hours;
      case 1440:
        return l10n.onboardingIntervalEveryDay;
      case 4320:
        return l10n.onboardingIntervalEvery3Days;
      case 10080:
        return l10n.onboardingIntervalWeekly;
      default:
        return l10n.onboardingIntervalEveryDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: intervals.map((min) {
        final label = _labelFor(context, min);
        final isSelected = min == selected;
        return GestureDetector(
          onTap: () => onSelected(min),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSelected
                  ? const LinearGradient(colors: [_accent1, _accent2])
                  : null,
              color: isSelected ? null : _glassWhite,
              border: Border.all(
                color: isSelected
                    ? _accent1.withValues(alpha: 0.6)
                    : _glassBorder,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _accent1.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.60),
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── page icon ────────────────────────────────────────────────────────────────

class _PageIcon extends StatelessWidget {
  const _PageIcon({
    required this.icon,
    required this.color,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.9,
          height: size * 1.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.30),
                color.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: size * 0.48),
        ),
      ],
    );
  }
}

// ─── RESTORE ACCOUNT PAGE ────────────────────────────────────────────────────

class _RestoreAccountPage extends StatefulWidget {
  const _RestoreAccountPage({
    required this.controller,
    required this.onComplete,
  });

  final AppController controller;
  final Future<void> Function() onComplete;

  @override
  State<_RestoreAccountPage> createState() => _RestoreAccountPageState();
}

class _RestoreAccountPageState extends State<_RestoreAccountPage>
    with SingleTickerProviderStateMixin {
  static final Object _manualBackupFilePick = Object();

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
      if (mounted) _enterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  void _setLoading(bool v) {
    if (mounted) setState(() => _loading = v);
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

  Future<String?> _pickBackupPayloadWithAutoSearch() async {
    final candidates = await discoverSafeBackupFilesOnDevice();
    if (!mounted) return null;

    final action = await showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          candidates.isEmpty
              ? context.l10n.onboardingNoBackupsFound
              : context.l10n.onboardingFoundBackups,
        ),
        content: SizedBox(
          width: 460,
          child: candidates.isEmpty
              ? Text(context.l10n.onboardingNoBackupsFoundBody)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final candidate = candidates[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          candidate.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_backupCandidateSubtitle(candidate)),
                        onTap: () => Navigator.of(ctx).pop(candidate),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(context.l10n.cancel),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(ctx).pop(_manualBackupFilePick),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(context.l10n.chooseManually),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return null;
    try {
      if (identical(action, _manualBackupFilePick)) {
        return pickSafeBackupPayloadFromFile(
          dialogTitle: context.l10n.onboardingChooseBackupFileTitle,
        );
      }
      if (action is SafeBackupFileCandidate) {
        return readSafeBackupPayloadFromPath(action.path);
      }
    } catch (_) {
      _snack(context.l10n.onboardingReadBackupFailed);
    }
    return null;
  }

  Future<void> _setMediaBackup(bool value) async {
    await widget.controller.setSafeBackupIncludeMedia(value);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _restoreFromServer() async {
    _setLoading(true);
    try {
      // Start EMPTY: restoring from server means entering ANOTHER (your real)
      // Secretly ID, not this fresh install's freshly-generated one. Pre-filling
      // the new device's id just made the user erase it every time.
      final pidC = TextEditingController();
      final pwC = TextEditingController();
      final f1 = FocusNode();
      final f2 = FocusNode();

      final res = await showDialog<({String profileId, String password})>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            _RestoreServerDialog(pidC: pidC, pwC: pwC, f1: f1, f2: f2),
      );

      f1.dispose();
      f2.dispose();
      pidC.dispose();
      pwC.dispose();

      if (res == null || !mounted) {
        _setLoading(false);
        return;
      }

      final (exists, payload, _) = await widget.controller.backupGetFromServer(
        res.profileId,
        useDeviceAuth: false,
        // Э-1 (SEC-01): пароль уже введён в этом же диалоге — из него выводится
        // токен доступа, заменяющий подпись там, где ключей ещё нет.
        backupPassword: res.password,
      );
      if (!mounted) return;
      if (!exists || payload == null || payload.trim().isEmpty) {
        _setLoading(false);
        _snack(context.l10n.onboardingServerBackupNotFound);
        return;
      }

      try {
        final plain = await widget.controller
            .decryptSafeBackupPayloadForRestore(
              payload: payload,
              password: res.password,
            );
        if (!mounted) return;
        final confirmed = await _confirmSafeBackupRestore(plain);
        if (!confirmed) {
          _setLoading(false);
          return;
        }
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
        _setLoading(false);
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
      _setLoading(false);
      _snack(_describeError(e));
    }
  }

  Future<void> _restoreFromFile() async {
    _setLoading(true);
    try {
      final payload = await _pickBackupPayloadWithAutoSearch();
      if (!mounted) {
        _setLoading(false);
        return;
      }
      if (payload == null || payload.isEmpty) {
        _setLoading(false);
        return;
      }

      final pwC = TextEditingController();
      final f = FocusNode();
      final pw = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PasswordDialog(
          controller: pwC,
          focusNode: f,
          title: context.l10n.onboardingBackupPasswordTitle,
        ),
      );
      f.dispose();
      pwC.dispose();

      if (pw == null || !mounted) {
        _setLoading(false);
        return;
      }

      try {
        final plain = await widget.controller
            .decryptSafeBackupPayloadForRestore(payload: payload, password: pw);
        if (!mounted) return;
        final confirmed = await _confirmSafeBackupRestore(plain);
        if (!confirmed) {
          _setLoading(false);
          return;
        }
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
        _setLoading(false);
        _snack(_describeError(e));
        return;
      }

      if (!mounted) return;
      await widget.onComplete();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _setLoading(false);
      _snack(_describeError(e));
    }
  }

  int _snapshotRowCount(SafeBackupPlainV1 plain, String table) {
    final rows = plain.dbSnapshot?[table];
    return rows is List ? rows.length : 0;
  }

  Future<bool> _confirmSafeBackupRestore(SafeBackupPlainV1 plain) async {
    final fileCount = plain.filesB64ByRelativePath?.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.onboardingRestoreThisBackupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.onboardingRestoreThisBackupBody),
            const SizedBox(height: 14),
            Text(context.l10n.onboardingSecretlyIdSummary(plain.profileId)),
            Text(context.l10n.onboardingContactsSummary(plain.contacts.length)),
            Text(
              context.l10n.onboardingMessagesSummary(
                _snapshotRowCount(plain, 'events'),
              ),
            ),
            Text(
              context.l10n.onboardingChatsSummary(
                _snapshotRowCount(plain, 'conversations'),
              ),
            ),
            Text(context.l10n.onboardingMediaFilesSummary(fileCount)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.restore),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final includeMedia = widget.controller.safeBackupIncludeMedia;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _lightEdgeToEdgeOverlayStyle,
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: Stack(
          children: [
            const _AnimatedBackground(),
            SafeArea(
              child: AnimatedBuilder(
                animation: _enterCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: FadeTransition(opacity: _fade, child: child),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    topPad + 16,
                    24,
                    bottomPad + 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back button row
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _glassWhite,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _glassBorder),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white.withValues(alpha: 0.80),
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      _PageIcon(
                        icon: Icons.restore_rounded,
                        color: _accentPurple,
                        size: 72,
                      ),

                      const SizedBox(height: 20),

                      Text(
                        context.l10n.onboardingRestoreLoginTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        context.l10n.onboardingRestoreLoginSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _glassWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _glassBorder),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: includeMedia,
                          activeThumbColor: _accent2,
                          onChanged: _loading ? null : _setMediaBackup,
                          title: Text(
                            context.l10n.onboardingBackupMediaTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.onboardingRestoreMediaSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.46),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Restore from server
                      _RestoreOptionCard(
                        icon: Icons.cloud_download_outlined,
                        color: _accent2,
                        title: context.l10n.onboardingRestoreFromCloudTitle,
                        subtitle:
                            context.l10n.onboardingRestoreFromCloudSubtitle,
                        onTap: _loading ? null : _restoreFromServer,
                      ),

                      const SizedBox(height: 12),

                      // Restore from file
                      _RestoreOptionCard(
                        icon: Icons.folder_open_outlined,
                        color: _accentPurple,
                        title: context.l10n.onboardingRestoreFromDeviceTitle,
                        subtitle:
                            context.l10n.onboardingRestoreFromDeviceSubtitle,
                        onTap: _loading ? null : _restoreFromFile,
                      ),

                      const SizedBox(height: 48),

                      if (_loading)
                        Column(
                          children: [
                            const CircularProgressIndicator(color: _accent2),
                            const SizedBox(height: 14),
                            Text(
                              context.l10n.onboardingRestoring,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreOptionCard extends StatefulWidget {
  const _RestoreOptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  State<_RestoreOptionCard> createState() => _RestoreOptionCardState();
}

class _RestoreOptionCardState extends State<_RestoreOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _press.reverse() : null,
      onTapUp: enabled
          ? (_) {
              _press.forward();
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => _press.forward() : null,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.32),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.color.withValues(alpha: 0.60),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreServerDialog extends StatelessWidget {
  const _RestoreServerDialog({
    required this.pidC,
    required this.pwC,
    required this.f1,
    required this.f2,
  });

  final TextEditingController pidC;
  final TextEditingController pwC;
  final FocusNode f1;
  final FocusNode f2;

  @override
  Widget build(BuildContext context) {
    void submit() {
      final pid = pidC.text.trim();
      final pw = pwC.text;
      if (pid.isEmpty || pw.isEmpty) return;
      Navigator.of(context).pop((profileId: pid, password: pw));
    }

    return AlertDialog(
      title: Text(context.l10n.onboardingRestoreFromServerTitle),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pidC,
              focusNode: f1,
              decoration: InputDecoration(
                labelText: context.l10n.secretlyIdLabel,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => f2.requestFocus(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pwC,
              focusNode: f2,
              decoration: InputDecoration(
                labelText: context.l10n.onboardingBackupPasswordTitle,
              ),
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: submit, child: Text(context.l10n.restore)),
      ],
    );
  }
}

class _PasswordDialog extends StatelessWidget {
  const _PasswordDialog({
    required this.controller,
    required this.focusNode,
    required this.title,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;

  @override
  Widget build(BuildContext context) {
    void submit() {
      final pw = controller.text;
      if (pw.isEmpty) return;
      Navigator.of(context).pop(pw);
    }

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        decoration: InputDecoration(labelText: context.l10n.password),
        keyboardType: TextInputType.visiblePassword,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: submit, child: Text(context.l10n.restore)),
      ],
    );
  }
}
