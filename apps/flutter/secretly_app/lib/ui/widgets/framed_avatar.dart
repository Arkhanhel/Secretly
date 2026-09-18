// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../premium/cosmetics_catalog.dart';
import 'avatar_initials.dart';

/// Avatar (photo or initials fallback) with an optional premium animated
/// [frameId] ring drawn around it. Drop-in for every avatar site: total widget
/// stays [size]×[size] (the avatar shrinks slightly to make room for the ring),
/// so existing layouts are unaffected. No frame → plain avatar, zero animation.
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    required this.size,
    required this.fallbackSeed,
    this.avatarPath,
    this.fallbackName,
    this.fallbackId,
    this.frameId,
    this.border,
    this.labelStyle,
  });

  final double size;
  final String fallbackSeed;
  final String? avatarPath;
  final String? fallbackName;
  final String? fallbackId;
  final String? frameId;
  final BoxBorder? border;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final frame = frameById(frameId);
    // Snug fit: photo ≈ 0.86·S so its edge meets the ring inner edge (r≈0.455·S,
    // stroke ≈0.055·S → inner ≈0.428·S) with no visible gap.
    final inset = frame != null ? size * 0.07 : 0.0;
    final avatarD = size - inset * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        // The frame texture is drawn slightly larger than the avatar box so its
        // blurred glow can fade OUTSIDE the ring instead of being hard-clipped
        // into a square. Don't clip that overspill.
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: avatarD,
            height: avatarD,
            child: _avatar(context, avatarD),
          ),
          if (frame != null) Positioned.fill(child: frame.builder(size)),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, double d) {
    final p = avatarPath;
    if (p != null && p.isNotEmpty) {
      // Decode to the on-screen avatar size (px = logical diameter × DPR) so a
      // large source photo doesn't decode at full resolution into memory. Square
      // box → one dimension is enough; rounds up to keep BoxFit.cover crisp.
      final cacheDim = (d * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipOval(
        child: Image.file(
          File(p),
          width: d,
          height: d,
          fit: BoxFit.cover,
          cacheWidth: cacheDim,
          cacheHeight: cacheDim,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(context, d),
        ),
      );
    }
    return _fallback(context, d);
  }

  Widget _fallback(BuildContext context, double d) =>
      AvatarInitials.fallbackBubble(
        context: context,
        radius: d / 2,
        seed: fallbackSeed,
        displayName: fallbackName,
        fallbackId: fallbackId,
        border: border,
        labelStyle: labelStyle,
      );
}
