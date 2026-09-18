// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';

/// Thin bridge to the PLATFORM's own PDF renderer (Android
/// `android.graphics.pdf.PdfRenderer`; iOS PDFKit), used by the in-app document
/// reader.
///
/// Why the OS renderer and not a bundled engine: a PDF that arrived in a chat is
/// untrusted input, and PDF parsing is a classic remote-code-execution surface.
/// The system component is patched by the platform vendor, whereas a vendored
/// pdfium copy would be ours to keep current forever — not a trade an E2EE
/// messenger should take. It also keeps the APK from growing.
///
/// Pages come back as PNG bytes and are drawn by our own viewer, so the reader
/// chrome matches the photo gallery exactly.
class PdfDocument {
  PdfDocument._(this.path, this.pageCount);

  static const MethodChannel _channel = MethodChannel('secretly/pdf');

  final String path;
  final int pageCount;

  /// Rendered pages, keyed by "index@width". Bounded so a long document read
  /// end-to-end cannot grow the heap without limit — full-page PNGs are big.
  final LinkedHashMap<String, Uint8List> _pages = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlight = {};
  static const int _maxCachedPages = 8;

  /// True when this platform can render PDFs in-app. Elsewhere the caller falls
  /// back to handing the file to another app.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Opens [path] and reads its page count, or returns null when the file is not
  /// a readable PDF (encrypted, corrupt, or an unsupported platform) — the
  /// caller then offers the share sheet instead of showing a broken reader.
  static Future<PdfDocument?> open(String path) async {
    if (!isSupported) return null;
    try {
      final count = await _channel.invokeMethod<int>('pageCount', {
        'path': path,
      });
      if (count == null || count <= 0) return null;
      return PdfDocument._(path, count);
    } catch (_) {
      return null;
    }
  }

  /// Renders page [index] at [width] logical-times-pixel-ratio pixels. Repeated
  /// calls for the same page+width are coalesced, so a fast swipe that revisits
  /// a page never renders it twice.
  Future<Uint8List?> renderPage(int index, {required int width}) {
    final key = '$index@$width';
    final cached = _pages[key];
    if (cached != null) {
      // Refresh LRU position.
      _pages.remove(key);
      _pages[key] = cached;
      return Future.value(cached);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = () async {
      try {
        final bytes = await _channel.invokeMethod<Uint8List>('renderPage', {
          'path': path,
          'index': index,
          'width': width,
        });
        if (bytes != null) {
          _pages[key] = bytes;
          while (_pages.length > _maxCachedPages) {
            _pages.remove(_pages.keys.first);
          }
        }
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(key);
      }
    }();
    _inFlight[key] = future;
    return future;
  }

  /// Warms the pages adjacent to [index] so a swipe lands on an already-rendered
  /// page instead of a spinner. Fire-and-forget by design.
  void preloadAround(int index, {required int width}) {
    for (final neighbour in [index - 1, index + 1]) {
      if (neighbour < 0 || neighbour >= pageCount) continue;
      unawaited(renderPage(neighbour, width: width));
    }
  }

  void dispose() {
    _pages.clear();
    _inFlight.clear();
  }
}
