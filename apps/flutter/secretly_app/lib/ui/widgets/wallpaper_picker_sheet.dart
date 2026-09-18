// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../chat_wallpapers.dart';
import '../icons/app_icons.dart';

/// Telegram-style wallpaper picker: a tall, draggable, scrollable grid sheet.
///
/// Returns the picked wallpaper id (or null if dismissed). Previews render via
/// [buildChatWallpaperBackground] so bundled / file / server wallpapers and
/// gradient fallbacks all work uniformly (and server tiles download lazily).
/// [isLocked] marks premium (server) wallpapers with a gold lock chip; gating
/// itself is enforced by the caller after the sheet returns.
Future<String?> showWallpaperPickerSheet(
  BuildContext context, {
  required String title,
  required List<ChatWallpaperOption> options,
  required String? selectedId,
  bool Function(String id)? isLocked,
  bool Function(String id)? isAnimated,
  // For an UNLOCKED animated wallpaper: open the fullscreen preview instead of
  // applying immediately. Returns the id to apply (after "Set"), or null if the
  // preview was dismissed. Locked animated tiles fall through to the normal
  // pop → caller paywall path.
  Future<String?> Function(BuildContext ctx, String id)? onAnimatedUnlockedTap,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Material(
              color: cs.surface.withValues(alpha: 0.98),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: options.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.62,
                            ),
                        itemBuilder: (context, i) {
                          final option = options[i];
                          final isSel = option.id == selectedId;
                          final locked = isLocked?.call(option.id) ?? false;
                          final animated =
                              isAnimated?.call(option.id) ?? false;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              // Unlocked animated wallpaper → fullscreen preview
                              // (mode picker + Set). Locked ones fall through to
                              // the normal pop so the caller shows the paywall.
                              if (animated &&
                                  !locked &&
                                  onAnimatedUnlockedTap != null) {
                                final applied = await onAnimatedUnlockedTap(
                                  context,
                                  option.id,
                                );
                                if (applied != null && context.mounted) {
                                  Navigator.of(context).pop(applied);
                                }
                                return;
                              }
                              Navigator.of(context).pop(option.id);
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: buildChatWallpaperBackground(
                                    context,
                                    option.id,
                                    preview: true,
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel
                                          ? cs.primary
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.4,
                                            ),
                                      width: isSel ? 2.5 : 1,
                                    ),
                                  ),
                                ),
                                if (locked)
                                  const Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: Color(0xFFD4A11E),
                                    ),
                                  ),
                                if (isSel)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(
                                      AppIcons.checkCircleSolid,
                                      size: 20,
                                      color: cs.primary,
                                    ),
                                  ),
                                // Small "animated" indicator on live wallpapers.
                                if (animated)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.42,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.motion_photos_on,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
