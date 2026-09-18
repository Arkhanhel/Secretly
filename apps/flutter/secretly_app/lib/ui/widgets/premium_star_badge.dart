// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// A tiny premium indicator — the same ✦ sparkle as [GoldPremiumBadge] — shown
/// next to a PAID (Premium/Teams) feature so free users can see it requires
/// Premium BEFORE they tap it.
///
/// SECURITY (TZ Appendix B / CLAUDE.md HARD RULE): only ever attach this to a
/// monetizable feature. NEVER to a security feature — E2EE, disappearing
/// messages, screenshot/screen-record protection, PIN/biometric unlock,
/// recovery kit, or contact verification. Those are free forever and must not
/// carry any pay indicator.
///
/// Visibility is fail-OPEN: callers pass `show: !FeatureGate.isUnlocked(state,
/// feature)`, so when monetization is disabled (kill-switch off) or the profile
/// already holds a paid tier, `isUnlocked` is true → `show` is false → the
/// badge renders nothing.
class PremiumStarBadge extends StatelessWidget {
  const PremiumStarBadge({super.key, this.size = 13, this.show = true});

  /// Sparkle icon size in logical pixels.
  final double size;

  /// When false the badge renders nothing.
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c.withValues(alpha: 0.32), width: 0.7),
      ),
      child: Icon(Icons.auto_awesome, size: size, color: c),
    );
  }
}
