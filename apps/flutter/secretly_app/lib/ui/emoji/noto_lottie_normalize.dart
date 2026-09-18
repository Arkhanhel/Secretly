// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// 🔴 THE `tm` + `sr` DEFECT (2026-08-02, field report: "😁 disappears at some
/// stage, though it doesn't on the Noto site").
///
/// A Lottie precomposition layer can carry BOTH:
///   * `tm` — time remapping: an explicit curve saying which second of the
///     precomp to show at each moment; and
///   * `sr` — time stretch: a multiplier on the layer's own playback speed.
///
/// After Effects (and lottie-web, which is what the Noto preview site runs)
/// treat time remapping as the FINAL word: once `tm` is present, `sr` no
/// longer applies, because the remap curve already states the exact time.
/// `lottie` for Flutter divides by the time stretch anyway — the division in
/// `CompositionLayer.setProgress` is not guarded by the remapping branch. The
/// remapped time is therefore inflated by `1 / sr`.
///
/// For 😁 (`1f601`) that is not subtle. Its second precomp instance is visible
/// over the last quarter of the animation and remaps onto internal frames
/// 122.5…176.6, while the precomp's artwork ends at frame 187.5. Divided by
/// `sr = 0.6` the same window lands on frames 204…294 — past the end of every
/// layer inside. Nothing is drawn, so the emoji vanishes for the final ~700 ms
/// and then snaps back when the controller resets. Exactly the reported
/// symptom, and the reason it looks correct on the Noto site.
///
/// The cure is to restore the After Effects meaning before the file is parsed:
/// where a layer has time remapping, its time stretch is neutralised. With
/// `sr = 1` the remapped window lands back on 122.5…176.6 — continuous with
/// the instance that precedes it, and inside the artwork.
///
/// DIRECTION OF FAILURE: every failure here leaves the ORIGINAL bytes in place,
/// so the worst case is today's behaviour, never something new. Unparseable
/// JSON, an unexpected shape, an encoding error — all return null, meaning
/// "nothing to change".
///
/// This is rare but not unique: of 37 sampled Noto animations only `1f601`
/// combines the two, which is why it is the single emoji that misbehaves.
/// Normalising by rule rather than by codepoint covers the rest of the 881-emoji
/// catalogue without anyone having to notice them one at a time.
library;

import 'dart:convert';

/// Returns re-encoded Lottie bytes with the `tm` + `sr` conflict removed, or
/// `null` when the file needs no change (or cannot be understood).
List<int>? normalizeNotoLottieBytes(List<int> bytes) {
  try {
    final decoded = json.decode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    final root = Map<String, Object?>.from(decoded);
    if (!_neutraliseTimeStretch(root)) return null;
    return utf8.encode(json.encode(root));
  } catch (_) {
    // Leave the file exactly as it was — see DIRECTION OF FAILURE above.
    return null;
  }
}

/// Walks the root layers and every asset's layers, clearing `sr` on any layer
/// that also carries `tm`. Returns true when something actually changed.
bool _neutraliseTimeStretch(Map<String, Object?> root) {
  var changed = false;

  bool visitLayers(Object? layers) {
    if (layers is! List) return false;
    var touched = false;
    for (final layer in layers) {
      if (layer is! Map) continue;
      if (!layer.containsKey('tm')) continue;
      final stretch = layer['sr'];
      if (stretch is! num || stretch == 1) continue;
      layer['sr'] = 1;
      touched = true;
    }
    return touched;
  }

  if (visitLayers(root['layers'])) changed = true;
  final assets = root['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      if (visitLayers(asset['layers'])) changed = true;
    }
  }
  return changed;
}
