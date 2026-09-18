// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer skeleton placeholder for content loading.
///
/// Replaces CircularProgressIndicator with a professional shimmer effect.
/// Use [ShimmerBox] for individual placeholders or [ShimmerList] for lists.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      highlightColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer skeleton for a full contact details page.
class ShimmerContactDetails extends StatelessWidget {
  const ShimmerContactDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      highlightColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar placeholder
            const CircleAvatar(radius: 48, backgroundColor: Colors.white),
            const SizedBox(height: 16),
            // Name placeholder
            Container(
              width: 160,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            // Status placeholder
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 32),
            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 52,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Info cards placeholder
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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

/// Shimmer skeleton for a media grid (photos/files).
class ShimmerMediaGrid extends StatelessWidget {
  const ShimmerMediaGrid({super.key, this.itemCount = 9});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      highlightColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: itemCount,
        itemBuilder: (context, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton for a list of settings-like rows.
class ShimmerSettingsList extends StatelessWidget {
  const ShimmerSettingsList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      highlightColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(itemCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100 + (i * 20.0).clamp(0, 80),
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 60 + (i * 15.0).clamp(0, 60),
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
