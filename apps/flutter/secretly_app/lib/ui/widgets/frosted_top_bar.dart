// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import '../theme_presets.dart';
import 'island_backdrop.dart';

class FrostedTopBarBackground extends StatelessWidget {
  const FrostedTopBarBackground({super.key, this.sigma = 16});

  final double sigma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final visuals = theme.extension<ChatVisualsThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final top = visuals?.topBarTop ?? cs.surface;
    final bottom = visuals?.topBarBottom ?? cs.surfaceContainerHighest;
    // Frosted OFF ⇒ a fully opaque bar. These alphas (0.5–0.66) are readable
    // over a blur but let the page show through without one, which is what
    // made the panels look see-through (field report 2026-08-01).
    final frosted = PanelPrefs.frostedEnabled.value;
    final topAlpha = !frosted ? 1.0 : (isDark ? 0.58 : 0.66);
    final bottomAlpha = !frosted ? 1.0 : (isDark ? 0.5 : 0.58);
    final solid = opaquePanelFill(context);
    return ClipRect(
      child: _topBarBlur(
        frosted: frosted,
        sigma: sigma,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                frosted ? top.withValues(alpha: topAlpha) : solid,
                frosted ? bottom.withValues(alpha: bottomAlpha) : solid,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

AppBar frostedAppBar({
  Widget? title,
  Widget? leading,
  double? leadingWidth,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  Widget? flexibleSpace,
  double? toolbarHeight,
  double? titleSpacing,
  bool automaticallyImplyLeading = true,
  bool centerTitle = false,
}) {
  return AppBar(
    title: title,
    leading: leading,
    leadingWidth: leadingWidth,
    actions: actions,
    bottom: bottom,
    flexibleSpace: flexibleSpace ?? const FrostedTopBarBackground(),
    toolbarHeight: toolbarHeight,
    titleSpacing: titleSpacing,
    automaticallyImplyLeading: automaticallyImplyLeading,
    centerTitle: centerTitle,
    forceMaterialTransparency: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}


/// Blur only when frosted panels are on — off, the bar already paints a solid
/// plate and a backdrop pass would be pure cost for no visible change.
Widget _topBarBlur({
  required bool frosted,
  required double sigma,
  required Widget child,
}) {
  if (!frosted) return child;
  // VIBRANCY TEST (2026-07-17): blur + saturation, see island_backdrop.
  return BackdropFilter(
    filter: islandBackdropFilter(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
