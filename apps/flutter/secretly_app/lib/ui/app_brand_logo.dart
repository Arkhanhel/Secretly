// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../app/app_controller.dart';
import '../entitlements/entitlement_models.dart';
import 'app_asset_paths.dart';
import 'icons/app_icons.dart';
import 'premium_features_sheet.dart';
import 'widgets/premium_glass.dart';

class AppBrandLogo extends StatefulWidget {
  const AppBrandLogo({super.key, this.compact = false, this.controller});

  final bool compact;
  final AppController? controller;

  static const String _fingerprintAssetPath = AppAssetPaths.fingerprintLottie;

  @override
  State<AppBrandLogo> createState() => _AppBrandLogoState();
}

class _AppBrandLogoState extends State<AppBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fingerprintController;
  Duration? _compositionDuration;

  @override
  void initState() {
    super.initState();
    _fingerprintController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _fingerprintController.dispose();
    super.dispose();
  }

  void _syncAnimationMode({required bool isReady}) {
    final compositionDuration = _compositionDuration;
    if (compositionDuration == null) return;
    if (isReady) {
      if (_fingerprintController.isAnimating) {
        _fingerprintController.stop(canceled: false);
      }
      if (_fingerprintController.value != 1.0) {
        _fingerprintController.value = 1.0;
      }
      return;
    }
    final targetDuration = compositionDuration * 2;
    if (_fingerprintController.duration != targetDuration) {
      _fingerprintController.duration = targetDuration;
    }
    if (!_fingerprintController.isAnimating) {
      _fingerprintController.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    final markSize = widget.compact ? 28.0 : 34.0;
    final ctrl = widget.controller;
    // The fingerprint pulses ONLY when the device loses its network path; it
    // stays calm whenever there is connectivity. Server health-check flaps
    // (keys/relay) must NOT animate it. No controller → assume calm.
    final isReady = ctrl == null || ctrl.networkOnline;
    _syncAnimationMode(isReady: isReady);
    final fingerprintTint = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black;

    final mark = SizedBox(
      width: markSize,
      height: markSize,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 4.5 : 4.0),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(fingerprintTint, BlendMode.srcIn),
          child: Lottie.asset(
            AppBrandLogo._fingerprintAssetPath,
            controller: _fingerprintController,
            animate: false,
            repeat: false,
            fit: BoxFit.contain,
            frameRate: FrameRate.max,
            onLoaded: (composition) {
              _compositionDuration = composition.duration;
              _syncAnimationMode(isReady: isReady);
            },
            errorBuilder: (_, __, ___) => Icon(
              AppIcons.fingerprint,
              size: widget.compact ? 18 : 22,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );

    if (widget.compact) return mark;

    // Title + (optional) premium badge. Wrapped in a scale-down FittedBox so on
    // narrow phones / large accessibility text scales the whole wordmark group
    // shrinks uniformly to the width the island gives it instead of letting the
    // gold "Premium" pill overflow past the rounded island edge. The host island
    // sits in an Expanded, so the loose maxWidth ceiling reaches this FittedBox
    // and bounds the scale; at normal sizes the group fits and renders 1:1.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Secretly', style: titleStyle, maxLines: 1),
                if (ctrl != null) _PremiumBadgeSlot(controller: ctrl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the shimmering gold "Premium" badge next to the app name for paid
/// users. Reactive: appears the moment an entitlement is granted (e.g. right
/// after a successful purchase). Renders nothing for free users.
class _PremiumBadgeSlot extends StatelessWidget {
  const _PremiumBadgeSlot({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    Widget slot(bool paid) => paid
        ? Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Premium users tap the badge to see everything their plan
              // includes (localized features + short descriptions).
              onTap: () => showPremiumFeaturesSheet(context),
              child: const GoldPremiumBadge(),
            ),
          )
        : const SizedBox.shrink();
    final listenable = controller.entitlements;
    if (listenable == null) {
      return slot(controller.entitlementStateNow.tier.isPaid);
    }
    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, state, _) => slot(state.tier.isPaid),
    );
  }
}
