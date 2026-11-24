// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Окно Premium (макет «Premium Hub», 23.11.2026).
///
/// Открывается островком «Premium» в шапке своего профиля. Один экран, два
/// состояния:
/// * бесплатный — каждая платная функция с живым примером, рамки и обложки,
///   сравнение лимитов (числа — из настоящих лимитов тарифов) и закреплённая
///   внизу кнопка покупки;
/// * подписчик — короткий залп конфетти при каждом открытии, «так вас видят
///   в чатах», тариф, дата продления, управление подпиской и «скоро».
///
/// Вместо медали — знак Secretly из разноцветных светлячков, который можно
/// наклонять пальцем ([PremiumFireflyLogo]).
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../billing/billing_service.dart';
import '../../billing/show_paywall.dart';
import '../../entitlements/cosmetic_catalog.dart';
import '../../entitlements/entitlement_models.dart';
import '../../l10n/app_localizations.dart';
import '../l10n.dart';
import '../apple_controls.dart' show appleBackIcon;
import '../icons/adaptive_icons.dart';
import '../motion/press_feedback.dart';
import '../paywall_screen.dart' show PaywallTrigger, restoreOutcomeMessage;
import '../profile_cosmetics_screen.dart';
import '../wave1_l10n.dart';
import '../widgets/frosted_header_island.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/premium_glass.dart' show ShimmerGoldText;
import 'cosmetic_animation_scope.dart';
import 'cosmetics_catalog.dart';
import 'premium_firefly_logo.dart';

const Color _gold = Color(0xFFE8A33D);

/// Цвета макета для тёмной и светлой темы.
class _HubTheme {
  const _HubTheme._({
    required this.dark,
    required this.bg,
    required this.scrim,
    required this.fg,
    required this.sub,
    required this.link,
    required this.card,
    required this.cardBorder,
    required this.cardShadow,
    required this.seam,
    required this.exBg,
    required this.goldTint,
    required this.goldText,
    required this.colHi,
    required this.chipNeutral,
    required this.ctaFade,
    required this.thumbBg,
    required this.thumbBorder,
    required this.wall,
    required this.shimmer,
  });

  final bool dark;
  final List<Color> bg, scrim, ctaFade, card, shimmer;
  final Color fg, sub, link, cardBorder, seam, exBg, goldTint, goldText;
  final Color colHi, chipNeutral, thumbBg, thumbBorder, wall;
  final List<BoxShadow> cardShadow;

  static const darkTheme = _HubTheme._(
    dark: true,
    bg: [Color(0xFF1D2733), Color(0xFF18222D), Color(0xFF151E27)],
    scrim: [Color(0xF01D2733), Color(0xB31D2733), Color(0x001D2733)],
    fg: Color(0xFFFFFFFF),
    sub: Color(0xFF7D8B99),
    link: Color(0xFF53A4F0),
    card: [Color(0x12FFFFFF), Color(0x08FFFFFF)],
    cardBorder: Color(0x1AFFFFFF),
    cardShadow: [],
    seam: Color(0x1AFFFFFF),
    exBg: Color(0x0FFFFFFF),
    goldTint: Color(0x24E8A33D),
    goldText: Color(0xFFE8A33D),
    colHi: Color(0x1FE8A33D),
    chipNeutral: Color(0x14FFFFFF),
    ctaFade: [Color(0x00151E27), Color(0xEB151E27)],
    thumbBg: Color(0x0AFFFFFF),
    thumbBorder: Color(0x14FFFFFF),
    wall: Color(0xFF141D27),
    shimmer: [
      Color(0xFFB9791E),
      Color(0xFFE8A33D),
      Color(0xFFFFF3C8),
      Color(0xFFE8A33D),
      Color(0xFFB9791E),
    ],
  );

  static const lightTheme = _HubTheme._(
    dark: false,
    bg: [Color(0xFFF4F7FA), Color(0xFFF0F3F7), Color(0xFFECF0F4)],
    scrim: [Color(0xF2F4F7FA), Color(0xB3F4F7FA), Color(0x00F4F7FA)],
    fg: Color(0xFF111418),
    sub: Color(0xFF536272),
    link: Color(0xFF1A8BD0),
    card: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    cardBorder: Color(0x00000000),
    cardShadow: [
      BoxShadow(color: Color(0x0A111418), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x14111418),
        blurRadius: 16,
        spreadRadius: -4,
        offset: Offset(0, 6),
      ),
    ],
    seam: Color(0x12000000),
    exBg: Color(0x0B111418),
    goldTint: Color(0x29E8A33D),
    goldText: Color(0xFFA86A12),
    colHi: Color(0x1FE8A33D),
    chipNeutral: Color(0x0F111418),
    ctaFade: [Color(0x00ECF0F4), Color(0xF0ECF0F4)],
    thumbBg: Color(0x08111418),
    thumbBorder: Color(0x14111418),
    wall: Color(0xFFE3ECF5),
    shimmer: [
      Color(0xFF8A5A12),
      Color(0xFFC98A22),
      Color(0xFFEBC06A),
      Color(0xFFC98A22),
      Color(0xFF8A5A12),
    ],
  );
}

/// Размер в МБ/ГБ для подписей лимитов (двоичные единицы, как в лимитах).
String premiumHubSize(AppLocalizations l10n, int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;
  if (bytes >= gb && bytes % gb == 0) return l10n.premiumHubSizeGb(bytes ~/ gb);
  return l10n.premiumHubSizeMb((bytes / mb).round());
}

/// Ссылка «Управлять подпиской» магазина этой платформы.
Uri? premiumManageSubscriptionsUri() {
  if (kIsWeb) return null;
  if (Platform.isIOS || Platform.isMacOS) {
    return Uri.parse('https://apps.apple.com/account/subscriptions');
  }
  if (Platform.isAndroid) {
    return Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?package=com.secretly.secretly_app',
    );
  }
  return null;
}

class PremiumHubScreen extends StatefulWidget {
  const PremiumHubScreen({
    super.key,
    required this.controller,
    this.entitlementOverride,
  });

  final AppController controller;

  /// Только для проверок и снимков: состояние тарифа вместо настоящего.
  @visibleForTesting
  final EntitlementState? entitlementOverride;

  @override
  State<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends State<PremiumHubScreen>
    with TickerProviderStateMixin {
  static final bool _testing =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Общие часы живых примеров (12 с по кругу).
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  final ScrollController _scroll = ScrollController();
  List<_ConfettiPiece> _pieces = const [];
  bool _wasPaid = false;
  bool _restoring = false;

  AppController get _c => widget.controller;
  EntitlementState get _ent =>
      widget.entitlementOverride ?? _c.entitlementStateNow;
  bool get _paid => _ent.tier.isPaid;

  @override
  void initState() {
    super.initState();
    _wasPaid = _paid;
    _c.entitlements?.addListener(_onEntitlement);
    if (_wasPaid) {
      // Конфетти при каждом открытии — после въезда экрана.
      Future<void>.delayed(const Duration(milliseconds: 380), _fireConfetti);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        _testing || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  void _onEntitlement() {
    if (!mounted) return;
    final paid = _paid;
    if (paid && !_wasPaid) {
      // Только что купили — наверх и залп.
      if (_scroll.hasClients) _scroll.jumpTo(0);
      Future<void>.delayed(const Duration(milliseconds: 120), _fireConfetti);
    }
    _wasPaid = paid;
    setState(() {});
  }

  void _fireConfetti() {
    if (!mounted || _testing) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final size = MediaQuery.sizeOf(context);
    setState(() => _pieces = _ConfettiPiece.burst(size, math.Random()));
    HapticFeedback.lightImpact();
    _confetti.forward(from: 0);
  }

  @override
  void dispose() {
    _c.entitlements?.removeListener(_onEntitlement);
    _loop.dispose();
    _confetti.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    await showPaywall(context, PaywallTrigger.general);
    if (mounted) setState(() {});
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final localeTag = wave1LocaleTagFromContext(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final outcome = await BillingService.instance.restore();
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(restoreOutcomeMessage(localeTag, outcome))),
        );
    } catch (_) {
      // Магазин недоступен — экран остаётся как есть.
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _manage() async {
    final uri = premiumManageSubscriptionsUri();
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openCosmetics({int tab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileCosmeticsScreen(controller: _c, initialTab: tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).brightness == Brightness.dark
        ? _HubTheme.darkTheme
        : _HubTheme.lightTheme;
    final l10n = context.l10n;
    final paid = _paid;
    final pad = MediaQuery.paddingOf(context);
    final topInset = pad.top + 64;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.bg.last,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.bg,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: StreamBuilder<void>(
                  stream: _c.changed,
                  builder: (context, _) => ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topInset,
                      16,
                      (paid ? 44 : 124) + pad.bottom,
                    ),
                    children: [
                      _hero(t, l10n, paid),
                      const SizedBox(height: 22),
                      if (paid) ...[
                        _seenAs(t, l10n),
                        const SizedBox(height: 10),
                        _planCard(t, l10n),
                        const SizedBox(height: 22),
                      ],
                      _framesAndCovers(t, l10n, paid),
                      const SizedBox(height: 22),
                      ..._featureGroups(t, l10n, paid),
                      if (!paid) _limits(t, l10n),
                      if (paid) _soon(t, l10n),
                    ],
                  ),
                ),
              ),
              // Затемнение под островами шапки.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topInset + 10,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: t.scrim,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: pad.top + 4,
                height: 48,
                child: _header(t, l10n, paid),
              ),
              if (!paid)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _cta(t, l10n, pad.bottom),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confetti,
                        pieces: _pieces,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Шапка ──────────────────────────────────────────────────────────────

  Widget _header(_HubTheme t, AppLocalizations l10n, bool paid) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              child: PressFeedback(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: FrostedHeaderIsland(
                    radius: 24,
                    height: 48,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        appleBackIcon(AdaptiveIcons.arrow_back),
                        color: t.fg,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          l10n.premiumHubTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.fg,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: paid
                ? const SizedBox.shrink()
                // Длинное «Wiederherstellen» на узком экране — ужимается, а
                // не наезжает на заголовок.
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PressFeedback(
                    child: GestureDetector(
                      onTap: _restoring ? null : _restore,
                      child: FrostedHeaderIsland(
                        radius: 24,
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        child: Center(
                          child: _restoring
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: t.fg,
                                  ),
                                )
                              : Text(
                                  l10n.premiumHubRestore,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.fg,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Герой ──────────────────────────────────────────────────────────────

  Widget _hero(_HubTheme t, AppLocalizations l10n, bool paid) {
    return Column(
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Мягкое золотое свечение под знаком.
              AnimatedBuilder(
                animation: _loop,
                builder: (context, _) {
                  final s = math.sin(_loop.value * math.pi * 2 * 12 / 3.2);
                  return Transform.scale(
                    scale: 1 + 0.04 * (s + 1),
                    child: Opacity(
                      opacity: 0.85 + 0.075 * (s + 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _gold.withValues(alpha: t.dark ? 0.30 : 0.22),
                              _gold.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.68],
                          ),
                        ),
                        child: const SizedBox(width: 132, height: 132),
                      ),
                    ),
                  );
                },
              ),
              Semantics(
                image: true,
                label: l10n.premiumHubLogoHint,
                child: const PremiumFireflyLogo(size: 112),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: paid ? t.goldTint : t.chipNeutral,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                paid ? Icons.verified_rounded : Icons.person_rounded,
                size: 15,
                color: paid ? t.goldText : t.sub,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                paid ? l10n.premiumHubChipActive : l10n.premiumHubChipFree,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: paid ? t.goldText : t.sub,
                ),
              ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShimmerGoldText(
          paid ? l10n.premiumHubHeroPremium : l10n.premiumHubHeroFree,
          colors: t.shimmer,
          style: const TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            paid ? l10n.premiumHubSubPremium : l10n.premiumHubSubFree,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.45, color: t.sub),
          ),
        ),
      ],
    );
  }

  // ── Карточки ───────────────────────────────────────────────────────────

  Widget _card(_HubTheme t, {required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.card,
        ),
        border: t.dark ? Border.all(color: t.cardBorder) : null,
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(_HubTheme t, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.26,
                color: t.sub,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _seenAs(_HubTheme t, AppLocalizations l10n) {
    final name = _c.myNickname.trim().isNotEmpty
        ? _c.myNickname.trim()
        : l10n.secretlyUser;
    final emoji = (_c.myEmojiStatus ?? '').trim();
    return _card(
      t,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          FramedAvatar(
            size: 58,
            frameId: _c.myFrameId,
            avatarPath: _c.myAvatarPath,
            fallbackSeed: _c.profileId,
            fallbackName: name,
            fallbackId: _c.profileId,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premiumHubSeenAs,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.sub,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: t.fg,
                        ),
                      ),
                    ),
                    if (emoji.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(emoji, style: const TextStyle(fontSize: 17)),
                    ],
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, size: 19, color: _gold),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.onlineStatus,
                  style: TextStyle(fontSize: 13, color: t.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(_HubTheme t, AppLocalizations l10n) {
    final e = _ent;
    final String plan;
    switch (e.tier) {
      case EntitlementTier.lifetime:
        plan = l10n.premiumHubPlanLifetime;
      case EntitlementTier.team:
        plan = l10n.premiumHubPlanTeam;
      case EntitlementTier.legacy:
        plan = l10n.premiumHubPlanLegacy;
      case EntitlementTier.premium:
      case EntitlementTier.free:
        plan = l10n.premiumHubPlanPremium;
    }
    final renewing = e.tier == EntitlementTier.premium;
    final expires = e.expiresAtMs;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String? second;
    String? secondLabel;
    if (e.tier == EntitlementTier.lifetime) {
      secondLabel = l10n.premiumHubPayment;
      second = l10n.premiumHubOneTime;
    } else if (renewing && expires != null && expires > 0) {
      secondLabel = l10n.premiumHubRenews;
      second = DateFormat.yMMMMd(locale).format(
        DateTime.fromMillisecondsSinceEpoch(expires),
      );
    }
    final canManage = renewing && premiumManageSubscriptionsUri() != null;
    Widget row(String label, String value, {bool top = false}) => Container(
      decoration: BoxDecoration(
        border: top
            ? Border(top: BorderSide(color: t.seam, width: 0.5))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Flexible(
            child: Text(label, style: TextStyle(fontSize: 14, color: t.sub)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: t.fg,
              ),
            ),
          ),
        ],
      ),
    );
    return _card(
      t,
      child: Column(
        children: [
          row(l10n.premiumHubPlan, plan),
          if (second != null) row(secondLabel!, second, top: true),
          if (canManage)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _manage,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: t.seam, width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune_rounded, size: 19, color: t.link),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                        l10n.premiumHubManage,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.link,
                        ),
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

  // ── Рамки и обложки ────────────────────────────────────────────────────

  Widget _framesAndCovers(_HubTheme t, AppLocalizations l10n, bool paid) {
    final state = _ent;
    final myFrame = _c.myFrameId;
    final myCover = _c.myCoverId;
    final frames = kAllAvatarFrames.take(12).toList();
    final covers = kAllProfileCovers.take(10).toList();
    final name = _c.myNickname.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          t,
          l10n.premiumHubFramesCovers,
          trailing: GestureDetector(
            onTap: () => _openCosmetics(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.premiumHubAll,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.link,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: t.link),
              ],
            ),
          ),
        ),
        _card(
          t,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Сетка — без движения (как на экране выбора): дюжина живых
              // рамок разом тяжела; движение — на большом портрете.
              CosmeticAnimationScope(
                enabled: false,
                child: SizedBox(
                  // Под крупный шрифт системы: подпись рамки растёт вместе
                  // с ним (на ×1 — прежние ~100).
                  height:
                      82 +
                      MediaQuery.textScalerOf(context).scale(11.5) * 1.35,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: frames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = frames[i];
                      final selected = paid && myFrame == f.id;
                      final locked = !isCosmeticAllowed(
                        state,
                        CosmeticKind.avatarFrame,
                        f.id,
                      );
                      return _FrameThumb(
                        theme: t,
                        name: f.nameLocalized(context),
                        selected: selected,
                        locked: locked,
                        onTap: () => _openCosmetics(),
                        avatar: FramedAvatar(
                          size: 52,
                          frameId: f.id,
                          avatarPath: _c.myAvatarPath,
                          fallbackSeed: _c.profileId,
                          fallbackName: name.isEmpty ? null : name,
                          fallbackId: _c.profileId,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: covers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = covers[i];
                    final locked = !isCosmeticAllowed(
                      state,
                      CosmeticKind.profileCover,
                      c.id,
                    );
                    return _CoverThumb(
                      theme: t,
                      name: c.nameLocalized(context),
                      cover: coverStill(c.id),
                      selected: paid && myCover == c.id,
                      locked: locked,
                      onTap: () => _openCosmetics(tab: 1),
                    );
                  },
                ),
              ),
              if (!paid) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, size: 16, color: _gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.premiumHubFramesNote,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: t.sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Функции ────────────────────────────────────────────────────────────

  List<Widget> _featureGroups(_HubTheme t, AppLocalizations l10n, bool paid) {
    final free = EntitlementLimits.free;
    final prem = EntitlementLimits.premium;
    _FeatureRow r(IconData icon, String name, String desc, _Ex ex) =>
        _FeatureRow(icon: icon, name: name, desc: desc, ex: ex);
    final groups = <(String, List<_FeatureRow>)>[
      (
        l10n.premiumHubGroupProfile,
        [
          r(Icons.add_reaction_rounded, l10n.premiumHubStatusName,
              l10n.premiumHubStatusDesc, _Ex.status),
          r(Icons.star_rounded, l10n.premiumHubBadgeName,
              l10n.premiumHubBadgeDesc, _Ex.badge),
          r(Icons.movie_rounded, l10n.premiumHubVideoName,
              l10n.premiumHubVideoDesc, _Ex.video),
          r(Icons.add_photo_alternate_rounded, l10n.premiumHubCoverName,
              l10n.premiumHubCoverDesc, _Ex.cover),
        ],
      ),
      (
        l10n.premiumHubGroupChats,
        [
          r(Icons.wallpaper_rounded, l10n.premiumHubWallpaperName,
              l10n.premiumHubWallpaperDesc, _Ex.wallpaper),
          r(Icons.emoji_emotions_rounded, l10n.premiumHubStickersName,
              l10n.premiumHubStickersDesc, _Ex.sticker),
          r(Icons.apps_rounded, l10n.premiumHubAppIconName,
              l10n.premiumHubAppIconDesc, _Ex.appIcon),
          r(Icons.ring_volume_rounded, l10n.premiumHubRingtonesName,
              l10n.premiumHubRingtonesDesc, _Ex.ringtone),
        ],
      ),
      (
        l10n.premiumHubGroupFeatures,
        [
          r(Icons.record_voice_over_rounded, l10n.premiumHubVoiceName,
              l10n.premiumHubVoiceDesc, _Ex.voice),
          r(Icons.devices_rounded, l10n.premiumHubDevicesName,
              l10n.premiumHubDevicesDesc, _Ex.devices),
          // У бесплатного лимиты — в таблице сравнения ниже.
          if (paid) ...[
            r(
              Icons.cloud_upload_rounded,
              l10n.premiumHubFilesName(premiumHubSize(l10n, prem.attachmentBytes)),
              l10n.premiumHubFilesDesc(premiumHubSize(l10n, free.attachmentBytes)),
              _Ex.files,
            ),
            r(
              Icons.groups_rounded,
              l10n.premiumHubCallsName(prem.callParticipants),
              l10n.premiumHubCallsDesc(free.callParticipants),
              _Ex.calls,
            ),
            r(
              Icons.workspaces_rounded,
              l10n.premiumHubGroupsName,
              l10n.premiumHubGroupsDesc(prem.ownedGroups, free.ownedGroups),
              _Ex.groups,
            ),
          ],
        ],
      ),
    ];
    return [
      for (final (title, rows) in groups) ...[
        _sectionTitle(t, title),
        _card(
          t,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(top: BorderSide(color: t.seam, width: 0.5)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: t.goldTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(rows[i].icon, size: 19, color: _gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].name,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: t.fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rows[i].desc,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.25,
                                color: t.sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ExcludeSemantics(
                        child: _LiveExample(
                          kind: rows[i].ex,
                          theme: t,
                          clock: _loop,
                          voiceSample: l10n.premiumHubVoiceSample,
                          name: _c.myNickname.trim().isNotEmpty
                              ? _c.myNickname.trim().split(' ').first
                              : 'Secretly',
                          filesLabel: premiumHubSize(
                            l10n,
                            EntitlementLimits.premium.attachmentBytes,
                          ),
                          callsLabel:
                              '${EntitlementLimits.premium.callParticipants}',
                          groupsLabel:
                              '${EntitlementLimits.premium.ownedGroups}',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    ];
  }

  // ── Лимиты (бесплатный) ────────────────────────────────────────────────

  Widget _limits(_HubTheme t, AppLocalizations l10n) {
    final free = EntitlementLimits.free;
    final prem = EntitlementLimits.premium;
    String count(int v) => v < 0 ? l10n.premiumHubUnlimited : '$v';
    final rows = <(String, String, String)>[
      (
        l10n.premiumHubLimitFiles,
        premiumHubSize(l10n, free.attachmentBytes),
        premiumHubSize(l10n, prem.attachmentBytes),
      ),
      (
        l10n.premiumHubLimitCalls,
        count(free.callParticipants),
        count(prem.callParticipants),
      ),
      (
        l10n.premiumHubLimitOwnGroups,
        count(free.ownedGroups),
        count(prem.ownedGroups),
      ),
      (
        l10n.premiumHubLimitJoinedGroups,
        count(free.joinedGroups),
        count(prem.joinedGroups),
      ),
      (l10n.premiumHubLimitDevices, '1', l10n.premiumHubSeveral),
      (
        l10n.premiumHubLimitCosmetics,
        l10n.premiumHubSome,
        l10n.premiumHubAllValue,
      ),
    ];
    Widget cell(
      String text, {
      bool head = false,
      bool hi = false,
      bool top = true,
      BorderRadius? radius,
      TextAlign align = TextAlign.center,
      Color? color,
      FontWeight weight = FontWeight.w400,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: hi ? t.colHi : null,
          borderRadius: radius,
          border: top
              ? Border(top: BorderSide(color: t.seam, width: 0.5))
              : null,
        ),
        padding: EdgeInsets.symmetric(
          vertical: head ? 9 : 10,
          horizontal: align == TextAlign.start ? 0 : 4,
        ),
        alignment: align == TextAlign.start
            ? Alignment.centerLeft
            : Alignment.center,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: head ? 12 : 13.5,
            height: 1.25,
            fontWeight: weight,
            color: color ?? t.fg,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(t, l10n.premiumHubLimits),
        _card(
          t,
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(68),
              2: FixedColumnWidth(96),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
            children: [
              TableRow(
                children: [
                  cell('', head: true, top: false),
                  cell(
                    l10n.premiumHubColFree,
                    head: true,
                    top: false,
                    color: t.sub,
                    weight: FontWeight.w700,
                  ),
                  cell(
                    l10n.premiumHubColPremium,
                    head: true,
                    top: false,
                    hi: true,
                    color: t.goldText,
                    weight: FontWeight.w800,
                    radius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  children: [
                    cell(rows[i].$1, align: TextAlign.start),
                    cell(rows[i].$2, color: t.sub),
                    cell(
                      rows[i].$3,
                      hi: true,
                      weight: FontWeight.w700,
                      radius: i == rows.length - 1
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            )
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Скоро (подписчик) ──────────────────────────────────────────────────

  Widget _soon(_HubTheme t, AppLocalizations l10n) {
    final items = <(IconData, String)>[
      (Icons.workspaces_rounded, l10n.premiumHubSoonSpaces),
      (Icons.emoji_emotions_rounded, l10n.premiumHubSoonStickers),
      (Icons.auto_stories_rounded, l10n.premiumHubSoonStories),
      (Icons.smart_display_rounded, l10n.premiumHubSoonWatch),
      (Icons.videocam_rounded, l10n.premiumHubSoonHd),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(t, l10n.premiumHubSoon),
        _card(
          t,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(top: BorderSide(color: t.seam, width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: t.chipNeutral,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(items[i].$1, size: 19, color: t.sub),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            color: t.fg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.chipNeutral,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          l10n.premiumHubSoonChip,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Кнопка покупки ─────────────────────────────────────────────────────

  Widget _cta(_HubTheme t, AppLocalizations l10n, double bottomInset) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.ctaFade,
          stops: const [0, 0.4],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 30, 16, 16 + bottomInset),
        child: Semantics(
          button: true,
          child: PressFeedback(
            child: GestureDetector(
              onTap: _buy,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0B65A), Color(0xFFE0922C)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8CE8A33D),
                      blurRadius: 24,
                      spreadRadius: -6,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 21,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                      l10n.premiumHubGet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x59783C00),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
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
    );
  }
}

class _FeatureRow {
  const _FeatureRow({
    required this.icon,
    required this.name,
    required this.desc,
    required this.ex,
  });
  final IconData icon;
  final String name, desc;
  final _Ex ex;
}

class _FrameThumb extends StatelessWidget {
  const _FrameThumb({
    required this.theme,
    required this.name,
    required this.avatar,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final _HubTheme theme;
  final String name;
  final Widget avatar;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? (t.dark ? const Color(0x1AFFFFFF) : const Color(0x14E8A33D))
              : t.thumbBg,
          border: Border.all(
            color: selected ? const Color(0xCCE8A33D) : t.thumbBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 52, height: 52, child: avatar),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: t.fg,
                    ),
                  ),
                ),
              ],
            ),
            if (locked)
              const Positioned(right: -4, top: -4, child: _LockDot())
            else if (selected)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.theme,
    required this.name,
    required this.cover,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final _HubTheme theme;
  final String name;
  final Widget cover;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 136,
        height: 72,
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xCCE8A33D) : const Color(0x14FFFFFF),
            width: selected ? 1.6 : 1,
          ),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0B0E1C),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cover,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x73000000), Color(0x00000000)],
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 30,
              bottom: 9,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (locked) const Positioned(right: 7, top: 7, child: _LockDot()),
          ],
        ),
      ),
    );
  }
}

class _LockDot extends StatelessWidget {
  const _LockDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0x73000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_rounded, size: 14, color: _gold),
    );
  }
}

// ── Живые примеры ────────────────────────────────────────────────────────

enum _Ex {
  status,
  badge,
  video,
  cover,
  wallpaper,
  sticker,
  appIcon,
  ringtone,
  voice,
  devices,
  files,
  calls,
  groups,
}

/// Маленький живой пример справа от функции (78 × 46). Все примеры идут от
/// одних часов экрана — один тикер на всё окно.
class _LiveExample extends StatelessWidget {
  const _LiveExample({
    required this.kind,
    required this.theme,
    required this.clock,
    required this.voiceSample,
    required this.name,
    required this.filesLabel,
    required this.callsLabel,
    required this.groupsLabel,
  });

  final _Ex kind;
  final _HubTheme theme;
  final Animation<double> clock;
  final String voiceSample, name, filesLabel, callsLabel, groupsLabel;

  static const double _period = 12; // секунд в круге часов

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SizedBox(
      width: 78,
      height: 46,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: clock,
            builder: (context, _) =>
                _body(t, clock.value * _period),
          ),
        ),
      ),
    );
  }

  /// Синус с периодом [p] секунд (целое число кругов на 12 с — без рывка).
  static double _wave(double s, double p, [double shift = 0]) =>
      math.sin((s / p + shift) * math.pi * 2);

  Widget _box(_HubTheme t, Widget child, {Color? color, Decoration? deco}) =>
      DecoratedBox(
        decoration: deco ?? BoxDecoration(color: color ?? t.exBg),
        child: Center(child: child),
      );

  Widget _body(_HubTheme t, double s) {
    final name = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: t.fg,
    );
    switch (kind) {
      case _Ex.status:
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(this.name, maxLines: 1, overflow: TextOverflow.clip, style: name),
              ),
              const SizedBox(width: 4),
              Transform.translate(
                offset: Offset(0, -1.5 + 1.5 * _wave(s, 2.4)),
                child: Transform.rotate(
                  angle: -0.05 * (1 + _wave(s, 2.4)),
                  child: const Text('🌙', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      case _Ex.badge:
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(this.name, maxLines: 1, overflow: TextOverflow.clip, style: name),
              ),
              const SizedBox(width: 4),
              Opacity(
                opacity: 0.775 + 0.225 * _wave(s, 2),
                child: const Icon(Icons.star_rounded, size: 15, color: _gold),
              ),
            ],
          ),
        );
      case _Ex.video:
        final shift = (s / 4) % 1;
        return _box(
          t,
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(shift * math.pi * 2),
                    colors: const [
                      Color(0xFFE8813A),
                      Color(0xFFFF7FC3),
                      Color(0xFF9B5CF6),
                      Color(0xFF3390EC),
                      Color(0xFFE8813A),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -4,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      case _Ex.cover:
        final shift = (s / 6) % 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + shift * 2, -1),
              end: Alignment(1 + shift * 2, 1),
              tileMode: TileMode.mirror,
              colors: const [
                Color(0xFF2B1B5A),
                Color(0xFF1C5AA0),
                Color(0xFF0A7568),
                Color(0xFF2B1B5A),
              ],
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_rounded, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Icon(Icons.add_photo_alternate_rounded, size: 18, color: Colors.white),
            ],
          ),
        );
      case _Ex.wallpaper:
        return DecoratedBox(
          decoration: BoxDecoration(color: t.wall),
          child: Stack(
            children: [
              Positioned(
                left: 4 + 7 * (1 + _wave(s, 6)),
                top: 2 - 3 * (1 + _wave(s, 6)),
                child: const _Blob(color: Color(0xFF3390EC), size: 32),
              ),
              Positioned(
                right: 2 + 6 * (1 + _wave(s, 6, 0.5)),
                bottom: 2.5 * (1 + _wave(s, 6, 0.5)),
                child: const _Blob(color: Color(0xFFFF7FC3), size: 30),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 34,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xEBFFFFFF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 26,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3390EC),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case _Ex.sticker:
        return _box(
          t,
          Transform.translate(
            offset: Offset(0, -1.5 + 1.5 * _wave(s, 1.5)),
            child: Transform.rotate(
              angle: -0.05 * (1 + _wave(s, 1.5)),
              child: const Text('🦊', style: TextStyle(fontSize: 28)),
            ),
          ),
        );
      case _Ex.appIcon:
        Widget icon(double side, List<Color> c, {Widget? child}) => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(side * 0.3),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c,
            ),
          ),
          child: child,
        );
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon(16, const [Color(0xFF4DE1F2), Color(0xFF0891B2)]),
              const SizedBox(width: 5),
              icon(
                24,
                const [Color(0xFFF0B65A), Color(0xFFE0922C)],
                child: const Icon(Icons.lock_rounded, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 5),
              icon(16, const [Color(0xFF2E2E31), Color(0xFF1A1A1C)]),
            ],
          ),
        );
      case _Ex.ringtone:
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: 15, color: _gold),
              const SizedBox(width: 6),
              for (var i = 0; i < 5; i++) ...[
                Container(
                  width: 3,
                  height: 20 * (0.35 + 0.65 * (0.5 + 0.5 * _wave(s, 1.0 + i * 0.2, i * 0.13))),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
              ],
            ],
          ),
        );
      case _Ex.voice:
        // Текст «печатается» по буквам и мигает курсор.
        final sample = voiceSample;
        final cycle = (s % 3) / 3;
        final shown = (sample.length * math.min(1.0, cycle * 1.6)).floor();
        final caret = (s * 2).floor().isEven;
        return DecoratedBox(
          decoration: BoxDecoration(color: t.exBg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle_rounded, size: 13, color: t.link),
                    const SizedBox(width: 2),
                    for (final v in const [5.0, 9.0, 12.0, 7.0, 10.0, 4.0, 8.0, 6.0]) ...[
                      Container(
                        width: 2.5,
                        height: v,
                        decoration: BoxDecoration(
                          color: t.link,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sample.substring(0, shown.clamp(0, sample.length)),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: t.fg,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: caret ? 1 : 0,
                      child: Container(
                        width: 1.5,
                        height: 10,
                        margin: const EdgeInsets.only(left: 1),
                        color: t.fg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _Ex.devices:
        return _box(
          t,
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.laptop_mac_outlined, size: 24, color: t.fg),
                  const SizedBox(width: 2),
                  Icon(Icons.smartphone_outlined, size: 17, color: t.fg),
                ],
              ),
              Positioned(
                right: -2,
                top: -1,
                child: Opacity(
                  opacity: 0.775 + 0.225 * _wave(s, 1.5),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case _Ex.files:
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_rounded, size: 18, color: t.link),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  filesLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.fg),
                ),
              ),
            ],
          ),
        );
      case _Ex.calls:
        // Кружки внахлёст занимают ровно своё место (48), а не 60.
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 20,
                child: Stack(
                  children: [
                    for (final (i, c) in const [
                      Color(0xFFE8813A),
                      Color(0xFF3390EC),
                      Color(0xFF9B5CF6),
                    ].indexed)
                      Positioned(
                        left: 14.0 * i,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.wall, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  callsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.fg),
                ),
              ),
            ],
          ),
        );
      case _Ex.groups:
        return _box(
          t,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspaces_rounded, size: 17, color: t.link),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  groupsLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.fg),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ── Конфетти ─────────────────────────────────────────────────────────────

const List<Color> _confettiColors = [
  Color(0xFFE8A33D),
  Color(0xFFFFF3C8),
  Color(0xFFF0B65A),
  Color(0xFF3390EC),
  Color(0xFF84B9E3),
  Color(0xFFFF7FC3),
  Color(0xFFFFFFFF),
  Color(0xFF59E4CD),
];

/// Одна бумажка: стартовая точка и скорость (px за кадр 60 Гц, как в макете).
class _ConfettiPiece {
  _ConfettiPiece(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.w,
    this.h,
    this.r,
    this.vr,
    this.f,
    this.vf,
    this.color,
    this.round,
  );

  final double x, y, vx, vy, w, h, r, vr, f, vf;
  final Color color;
  final bool round;

  /// Залп макета: две пушки с боков и россыпь из-под знака.
  static List<_ConfettiPiece> burst(Size size, math.Random rnd) {
    final out = <_ConfettiPiece>[];
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);
    void spawn(double x, double y, double deg, double spread, int n, double v0, double v1) {
      for (var i = 0; i < n; i++) {
        final a = (deg + between(-spread, spread)) * math.pi / 180;
        final v = between(v0, v1);
        out.add(
          _ConfettiPiece(
            x,
            y,
            math.cos(a) * v,
            math.sin(a) * v,
            between(5, 9),
            between(3.5, 6),
            between(0, 6.28),
            between(-0.25, 0.25),
            between(0, 6.28),
            between(0.08, 0.2),
            _confettiColors[i % _confettiColors.length],
            rnd.nextDouble() < 0.22,
          ),
        );
      }
    }

    final y = size.height * 0.43;
    spawn(-6, y, -58, 16, 70, 11, 19);
    spawn(size.width + 6, y, -122, 16, 70, 11, 19);
    spawn(size.width / 2, size.height * 0.2, -90, 70, 36, 5, 10);
    return out;
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.pieces})
    : super(repaint: progress);

  final Animation<double> progress;
  final List<_ConfettiPiece> pieces;

  static const double _durMs = 2300;

  @override
  void paint(Canvas canvas, Size size) {
    final v = progress.value;
    if (pieces.isEmpty || v <= 0 || v >= 1) return;
    final elapsedMs = v * _durMs;
    // Шаги по 60 Гц (как в макете): аналитически, без накопления состояния.
    final n = elapsedMs / 16.67;
    final alpha = elapsedMs < 1500 ? 1.0 : math.max(0.0, 1 - (elapsedMs - 1500) / (_durMs - 1500));
    const g = 0.34;
    const dx = 0.982, dy = 0.986;
    final ldx = math.log(dx), ldy = math.log(dy);
    final sx = (math.pow(dx, n) - 1) / ldx; // Σ dx^k
    final sy = (math.pow(dy, n) - 1) / ldy;
    final paint = Paint();
    for (final p in pieces) {
      final x = p.x + p.vx * sx;
      // Тяжесть: g добавляется к скорости каждый шаг, скорость затухает.
      final y = p.y + p.vy * sy + g * (n - sy) / (1 - dy);
      if (y > size.height + 20) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.r + p.vr * n);
      canvas.scale(1, math.cos(p.f + p.vf * n));
      paint.color = p.color.withValues(alpha: alpha);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.h * 0.6, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.pieces != pieces;
}
