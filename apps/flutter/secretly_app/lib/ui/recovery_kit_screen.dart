// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'animations/animations.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'widgets/frosted_top_bar.dart';

class RecoveryKitScreen extends StatelessWidget {
  const RecoveryKitScreen({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.recoveryKit)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 16),
        children: [
          Center(
            child: AnimatedQrReveal(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 100),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 280,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SecretlySnackBar(content: Text(l10n.copied)));
            },
            icon: const Icon(AppIcons.copy),
            label: Text(l10n.copy),
          ),
          const SizedBox(height: 12),
          Text(payload, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
