// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../design/tokens.dart';
import '../../primitives/avatar.dart';
import '../../../widgets/broken_media_box.dart';

/// Full-screen modal preview of a conversation's avatar.
/// - If [imagePath] is set and the file exists -> renders the image.
/// - Otherwise -> renders a large [Avatar] with initials/gradient.
///
/// Closed by tap or Esc.
Future<void> showAvatarPreviewDialog(
  BuildContext context, {
  required String name,
  String? imagePath,
  AvatarShape shape = AvatarShape.round,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (dialogCtx) {
      return _AvatarPreviewDialog(
        name: name,
        imagePath: imagePath,
        shape: shape,
      );
    },
  );
}

class _AvatarPreviewDialog extends StatelessWidget {
  const _AvatarPreviewDialog({
    required this.name,
    this.imagePath,
    this.shape = AvatarShape.round,
  });

  /// Форма портрета без фотографии. С фотографией не используется: снимок
  /// показывается целиком, как он есть.
  final AvatarShape shape;

  final String name;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final path = imagePath?.trim() ?? '';
    final hasFile = path.isNotEmpty && File(path).existsSync();
    return Semantics(
             button: true,
             label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
             child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: hasFile
                    ? InteractiveViewer(
                        maxScale: 4,
                        child: Image.file(
                          File(path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const BrokenMediaBox(
                            iconSize: 40,
                            onDarkSurface: true,
                          ),
                        ),
                      )
                    : Hero(
                        tag: 'desktop-avatar-preview-$name',
                        child: Avatar(
                          name: name.isEmpty ? '?' : name,
                          size: 280,
                          shape: shape,
                        ),
                      ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Semantics(
                           button: true,
                           label: AppLocalizations.of(context)!.close,
                           child: InkWell(
                      borderRadius: BorderRadius.circular(DRadii.pill),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.elevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.borderSubtle),
                        ),
                        child: Icon(
                          FluentIcons.dismiss_24_regular,
                          size: 20,
                          color: c.textPrimary,
                        ),
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
}
