// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Shared, mobile-safe renderer for the premium **emoji status** shown next to
// names (contact-details hero, chat header, chats-list rows).
//
// Why a separate widget instead of reusing chat_screen's `_NotoEmojiLottie`?
// That widget — and its loader/codepoint table — are PRIVATE to
// `chat_screen.dart`, and the user has been explicit that the mobile chat
// design must not be modified in this sprint. So this file ports the same
// recipe into a small public widget that the three status display sites can
// import without touching the chat screen.
//
// Rendering ladder:
//   1. emoji is in the Noto animation catalog → **looping Lottie**
//      (animated; loops forever for the hero / header / list rows),
//   2. … else (unknown emoji, or while the Lottie is still downloading on a
//      cold cache) the bare system glyph (best effort).
//
// NOTE on the (removed) static-PNG step. An earlier version fetched the Noto
// `{cp}/512.png` raster *in parallel* with the Lottie and preferred whichever
// arrived. That was the bug behind "animated status never animates":
//   * Every key in `kNotoCodepoints` IS animatable (the table is literally the
//     Noto *animation* manifest), so the PNG only ever loaded for emoji that
//     ALSO had a Lottie — pure redundancy.
//   * The PNG is smaller than the multi-layer Lottie JSON, so on a cold cache
//     `setState(_png)` usually won the race and rendered a STATIC image; and if
//     the Lottie request transiently failed while the PNG succeeded, the widget
//     was stuck on the static raster forever.
// Dropping the PNG removes the race entirely: a catalog emoji is always either
// the looping Lottie or (briefly, while downloading) the system glyph.
//
// Disk caching reuses the SAME `noto_emoji_{cp}.json` filename that
// `chat_screen.dart` and `lib/ui/desktop/chat/noto_emoji_lottie.dart` already
// populate, so an emoji downloaded once by chat animates here for free (and
// vice-versa).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http_pkg;
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../premium/cosmetic_animation_scope.dart';
import 'noto_emoji_catalog.dart';

/// True when [emoji] has an animated Noto Lottie we can fetch/render.
bool isAnimatableStatusEmoji(String emoji) =>
    kNotoCodepoints.containsKey(emoji.trim());

// ─── Shared Lottie loader (mirrors chat_screen's private loader) ──────────────

final Map<String, File> _notoLottieCache = <String, File>{};
final Map<String, Future<File?>> _notoLottieFutures = <String, Future<File?>>{};

Future<File?> _loadStatusLottieFile(String emoji) {
  final codepoint = kNotoCodepoints[emoji.trim()];
  if (codepoint == null) return Future<File?>.value(null);
  final existing = _notoLottieFutures[codepoint];
  if (existing != null) return existing;
  final future = _doLoadLottie(codepoint);
  _notoLottieFutures[codepoint] = future;
  // Do NOT cache a *failed* fetch forever: if the download fell through to null
  // (offline / transient CDN error), drop the future so the next display retries
  // instead of being permanently stuck on the glyph.
  future.then((f) {
    if (f == null) _notoLottieFutures.remove(codepoint);
  });
  return future;
}

Future<File?> _doLoadLottie(String codepoint) async {
  if (_notoLottieCache.containsKey(codepoint)) return _notoLottieCache[codepoint];
  try {
    final dir = await getTemporaryDirectory();
    // Reuse the SAME filename chat/desktop use so the cache is shared.
    final file = File(p.join(dir.path, 'noto_emoji_$codepoint.json'));
    if (await file.exists() && await file.length() > 0) {
      _notoLottieCache[codepoint] = file;
      return file;
    }
    final uri = Uri.parse(
      'https://fonts.gstatic.com/s/e/notoemoji/latest/$codepoint/lottie.json',
    );
    final response =
        await http_pkg.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      await file.writeAsBytes(response.bodyBytes);
      _notoLottieCache[codepoint] = file;
      return file;
    }
  } catch (_) {
    // Fall through to null — caller drops to the bare glyph and will retry.
  }
  return null;
}

/// Small inline widget that renders a premium emoji [emoji] as a looping Noto
/// Lottie animation.
///
/// * Animatable emoji (anything in [kNotoCodepoints]) → looping Lottie.
/// * Unknown emoji, or the brief window while the Lottie downloads on a cold
///   cache → the bare system glyph.
///
/// Set [animate] = false to render the Lottie's first frame only (static) — used
/// in long lists where a screenful of looping animations would be wasteful.
class NotoStatusEmoji extends StatefulWidget {
  const NotoStatusEmoji({
    super.key,
    required this.emoji,
    this.size = 20.0,
    this.animate = true,
  });

  final String emoji;
  final double size;

  /// Loop the Lottie (hero / header / list). When false the Lottie shows its
  /// first frame only.
  final bool animate;

  @override
  State<NotoStatusEmoji> createState() => _NotoStatusEmojiState();
}

class _NotoStatusEmojiState extends State<NotoStatusEmoji> {
  File? _lottie;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resolve(widget.emoji);
  }

  @override
  void didUpdateWidget(covariant NotoStatusEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji != widget.emoji) {
      setState(() => _lottie = null);
      _resolve(widget.emoji);
    }
  }

  void _resolve(String emoji) {
    final generation = ++_loadGeneration;
    final trimmed = emoji.trim();
    final codepoint = kNotoCodepoints[trimmed];
    if (codepoint == null) {
      // Unknown emoji — nothing to fetch, build() falls back to the glyph.
      return;
    }
    // Synchronous cache hit first (no flicker for already-downloaded assets).
    if (_notoLottieCache.containsKey(codepoint)) {
      _lottie = _notoLottieCache[codepoint];
      return;
    }
    _loadStatusLottieFile(trimmed).then((f) {
      if (!mounted || generation != _loadGeneration || f == null) return;
      setState(() => _lottie = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final lottie = _lottie;
    // Owner setting: inside a disabled CosmeticAnimationScope (chat/room lists
    // + in-chat when "animate peers' cosmetics" is off) render the first frame
    // only — zero per-frame load. Profile pages have no scope → always animate.
    final animate = widget.animate && CosmeticAnimationScope.of(context);
    if (lottie != null) {
      // Explicit `animate` + `repeat` so the auto-animation loops deterministically
      // (relying on Lottie's `animate: null` auto-detect can resolve to false on
      // the first frame before the composition's duration is known, which leaves
      // the emoji frozen — the original symptom). With `animate: true, repeat:
      // true` the LottieBuilder starts an infinite auto-animation immediately.
      return RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Lottie.file(
            lottie,
            width: size,
            height: size,
            repeat: animate,
            animate: animate,
            fit: BoxFit.contain,
            // A screenful of premium status emoji otherwise CPU-rasterises N
            // looping Lotties on every display frame — the "many animated
            // statuses lag/heat the phone" report. RenderCache.raster keeps each
            // rendered frame as a bitmap and reuses it across loops AND across
            // every widget showing the same emoji at the same size (the cache is
            // keyed by composition+frame+size), so after the first loop it is a
            // cheap blit instead of a re-rasterisation; FrameRate(30) halves the
            // distinct frames + tick work. Visually identical for these small,
            // slow loops. Applies on iOS and Android alike.
            frameRate: const FrameRate(30),
            renderCache: RenderCache.raster,
            errorBuilder: (_, __, ___) => _glyph(size),
          ),
        ),
      );
    }
    return _glyph(size);
  }

  Widget _glyph(double size) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            widget.emoji,
            style: TextStyle(
              fontSize: size * 0.86,
              height: 1.0,
              // Route a codepoint the UI font lacks to the platform colour-
              // emoji font instead of a tofu box (.notdef cross).
              fontFamilyFallback: _kStatusEmojiFontFallback,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

const List<String> _kStatusEmojiFontFallback = <String>[
  // 'Apple Color Emoji' omitted on purpose — in fontFamilyFallback it makes the
  // SPACE resolve to the emoji font on iOS/macOS (huge spaces). Apple platforms
  // render colour emoji via the system cascade without it.
  'Noto Color Emoji',
  'NotoColorEmoji',
];
