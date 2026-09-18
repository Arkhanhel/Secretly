// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'animations/animations.dart';
import 'l10n.dart';
import 'widgets/frosted_top_bar.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.title});

  /// Optional app-bar title. When null the localized `scanQr` label is used,
  /// so the screen never falls back to a hardcoded English string.
  final String? title;

  static Future<String?> scan(BuildContext context, {String? title}) {
    return Navigator.of(context).push<String>(
      SecretlyPageRoute(builder: (_) => QrScanScreen(title: title)),
    );
  }

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(widget.title ?? context.l10n.scanQr)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              final codes = capture.barcodes;
              final raw = codes.isNotEmpty ? codes.first.rawValue : null;
              if (raw == null || raw.trim().isEmpty) return;
              _done = true;
              Navigator.of(context).pop(raw);
            },
          ),
          const ScanLineOverlay(),
        ],
      ),
    );
  }
}
