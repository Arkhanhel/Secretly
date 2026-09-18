// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

/// Marks a subtree where the user's "animate peers' cosmetics" setting applies
/// (chat/room LISTS and the in-chat screen). Premium avatar frames and status
/// emoji inside a disabled scope render as a STATIC frame — zero animation
/// load when many premium contacts share the screen.
///
/// Profile pages (own + peer's) and the cosmetics picker deliberately do NOT
/// add this scope, so cosmetics always animate there — the cosmetic itself
/// stays discoverable ([CosmeticAnimationScope.of] defaults to `true` with no
/// ancestor scope).
class CosmeticAnimationScope extends InheritedWidget {
  const CosmeticAnimationScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  /// Whether cosmetics may animate inside this subtree.
  final bool enabled;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CosmeticAnimationScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(CosmeticAnimationScope oldWidget) =>
      oldWidget.enabled != enabled;
}

/// Marks a subtree as a SHOWCASE for cosmetics — a profile page, where a single
/// avatar is the subject of the screen and is drawn several times larger than a
/// list row.
///
/// Inside it, an animated frame stops using the shared baked atlas and paints
/// live from vectors instead: full resolution at any size (the atlas caps its
/// textures at 116px, which is a 3x stretch on a profile avatar — visibly soft)
/// and one frame per vsync (a baked loop trades frames for memory, which reads
/// as stutter once the avatar is big). That costs a millisecond or two per
/// frame, which is affordable for the ONE frame a profile shows and would not
/// be for the twenty a chat list shows — so lists deliberately stay on the
/// atlas, with its motion gate and its shared textures.
class CosmeticShowcaseScope extends InheritedWidget {
  const CosmeticShowcaseScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CosmeticShowcaseScope>() !=
      null;

  @override
  bool updateShouldNotify(CosmeticShowcaseScope oldWidget) => false;
}
