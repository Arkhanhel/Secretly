// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Boot-time splash shown while [AppController.init()] is in progress.
/// Mirrors the visual language of the mobile startup surface but stays
/// inside the desktop design tokens.
class DesktopSplash extends StatelessWidget {
  const DesktopSplash({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      color: c.bg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.elevated,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DSpace.l),
          Text(
            'Secretly',
            style: DType.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            'Загрузка профиля…',
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
          if (error != null) ...[
            const SizedBox(height: DSpace.l),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: DType.caption.copyWith(color: c.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
