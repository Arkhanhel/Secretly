// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' show Offset, Rect, Size;

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the desktop window's geometry (size + position) so it's restored on
/// the next launch instead of always re-centering at a fixed size. Desktop-only;
/// values are clamped to sane bounds so a corrupt/old pref can't open an
/// unusable window.
class DesktopWindowState {
  DesktopWindowState._();

  static const String _kW = 'desktop_window_w';
  static const String _kH = 'desktop_window_h';
  static const String _kX = 'desktop_window_x';
  static const String _kY = 'desktop_window_y';

  // Matches WindowOptions.minimumSize in main_desktop.dart.
  static const double _minW = 960;
  static const double _minH = 640;
  static const double _maxDim = 12000;

  static Future<void> save(Rect bounds) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kW, bounds.width);
      await p.setDouble(_kH, bounds.height);
      await p.setDouble(_kX, bounds.left);
      await p.setDouble(_kY, bounds.top);
    } catch (_) {
      // best-effort — losing the saved geometry just re-centers next launch
    }
  }

  /// Returns the saved bounds (size + top-left), or null if none / invalid.
  static Future<Rect?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final w = p.getDouble(_kW);
      final h = p.getDouble(_kH);
      if (w == null || h == null) return null;
      final cw = w.clamp(_minW, _maxDim);
      final ch = h.clamp(_minH, _maxDim);
      final x = p.getDouble(_kX) ?? 0;
      final y = p.getDouble(_kY) ?? 0;
      return Rect.fromLTWH(x, y, cw, ch);
    } catch (_) {
      return null;
    }
  }

  static Size sizeOr(Rect? bounds, Size fallback) =>
      bounds == null ? fallback : Size(bounds.width, bounds.height);

  /// True if the window's title-bar strip would land on a currently-attached
  /// display, so restoring [bounds] won't open the window off-screen (e.g.
  /// after a monitor was unplugged / rearranged). Best-effort: on any probe
  /// failure or unknown layout, returns true (don't block the restore).
  static Future<bool> isReachable(Rect bounds) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) return true;
      // The grabbable title-bar strip at the top of the window.
      final titleStrip = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 40);
      for (final d in displays) {
        final pos = d.visiblePosition ?? Offset.zero;
        final sz = d.visibleSize ?? d.size;
        if ((pos & sz).overlaps(titleStrip)) return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }
}
