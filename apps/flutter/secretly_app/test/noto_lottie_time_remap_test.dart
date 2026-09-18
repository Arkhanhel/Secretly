// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:secretly_app/ui/emoji/noto_lottie_normalize.dart';

/// 🔴 THE VANISHING REACTION (field report 2026-08-02: "😁 disappears at some
/// stage, though it doesn't on the Noto site").
///
/// The fixture below is not invented — it reproduces the exact construction of
/// the real `1f601` animation, with its real numbers:
///
///   root       fr = 60, op = 163
///   layer 1    precomp, ip = 122.5, op = 163, st = 49, sr = 0.6, tm 0 → 2.944s
///   layer 2    precomp, ip = 0,     op = 122.5
///   precomp    artwork covering internal frames 0 … 187.5
///
/// `tm` says which second of the precomp to show; `sr` scales the layer's own
/// playback. After Effects and lottie-web let `tm` win. `lottie` for Flutter
/// divides by `sr` regardless, inflating the remapped window from 122.5…176.6
/// to 204…294 — past the end of the artwork, so nothing is drawn.
///
/// These tests RENDER the composition and count pixels. Reasoning about frame
/// arithmetic is how the defect was found; pixels are how it is proven.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Real `1f601` geometry, with a plain opaque square as the artwork so that
  /// "is anything on screen" is a pixel count rather than a judgement call.
  List<int> fixtureBytes({required double timeStretch}) {
    final root = <String, Object?>{
      'v': '5.5.7',
      'fr': 60,
      'ip': 0,
      'op': 163,
      'w': 100,
      'h': 100,
      'assets': <Object?>[
        <String, Object?>{
          'id': 'comp_0',
          'layers': <Object?>[
            <String, Object?>{
              'ddd': 0,
              'ind': 1,
              'ty': 1, // solid
              'nm': 'art',
              'sc': '#ff0000',
              'sw': 100,
              'sh': 100,
              'ks': _identityTransform(),
              'ao': 0,
              'ip': 0,
              'op': 187.5, // the artwork ends here — the whole point
              'st': 0,
              'bm': 0,
            },
          ],
        },
      ],
      'layers': <Object?>[
        <String, Object?>{
          'ddd': 0,
          'ind': 1,
          'ty': 0,
          'nm': 'Grin',
          'refId': 'comp_0',
          'tm': <String, Object?>{
            'a': 1,
            'k': <Object?>[
              {
                't': 49,
                's': [0.0],
                'i': {
                  'x': [0.5],
                  'y': [0.5],
                },
                'o': {
                  'x': [0.5],
                  'y': [0.5],
                },
              },
              {
                't': 155.001,
                's': [2.944],
              },
              {
                't': 162.5,
                's': [2.944],
              },
            ],
          },
          'sr': timeStretch,
          'w': 100,
          'h': 100,
          'ks': _identityTransform(),
          'ao': 0,
          'ip': 122.5,
          'op': 163,
          'st': 49,
          'bm': 0,
        },
        <String, Object?>{
          'ddd': 0,
          'ind': 2,
          'ty': 0,
          'nm': 'Grin',
          'refId': 'comp_0',
          'w': 100,
          'h': 100,
          'ks': _identityTransform(),
          'ao': 0,
          'ip': 0,
          'op': 122.5,
          'st': 0,
          'bm': 0,
        },
      ],
    };
    return utf8.encode(json.encode(root));
  }

  /// Renders one frame and returns how many pixels are not fully transparent.
  Future<int> opaquePixelsAt(List<int> bytes, double progress) async {
    final composition = await LottieComposition.fromBytes(
      Uint8List.fromList(bytes),
    );
    final drawable = LottieDrawable(composition)..setProgress(progress);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    drawable.draw(canvas, const Rect.fromLTWH(0, 0, 100, 100), fit: BoxFit.fill);
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    if (data == null) return 0;
    final pixels = data.buffer.asUint8List();
    var visible = 0;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 0) visible++;
    }
    return visible;
  }

  /// 🔴 The defect itself. Without the fix the emoji is GONE for the whole last
  /// quarter of its animation — about 700 ms of the 2833 ms pop, which is why
  /// it reads as "it disappears at some stage" and not as a flicker.
  test('🔴 tm + sr blanks the animation over its final quarter', () async {
    final broken = fixtureBytes(timeStretch: 0.6);
    // Before the second instance takes over, the first one is drawing.
    expect(await opaquePixelsAt(broken, 0.70), greaterThan(0),
        reason: 'первая половина обязана рисоваться');
    for (final progress in <double>[0.78, 0.85, 0.92, 1.0]) {
      expect(await opaquePixelsAt(broken, progress), 0,
          reason: 'на прогрессе $progress ожидается ПУСТОЙ кадр (дефект)');
    }
  });

  /// 🔴 The cure, measured the same way: every sampled frame draws.
  test('🔴 normalising sr keeps every frame visible', () async {
    final healed = normalizeNotoLottieBytes(fixtureBytes(timeStretch: 0.6));
    expect(healed, isNotNull, reason: 'файл обязан быть распознан и исправлен');
    for (final progress in <double>[0.0, 0.5, 0.70, 0.78, 0.85, 0.92, 1.0]) {
      expect(await opaquePixelsAt(healed!, progress), greaterThan(0),
          reason: 'на прогрессе $progress эмодзи обязан быть виден');
    }
  });

  /// The normaliser must be a no-op on the animations that are already fine —
  /// otherwise it rewrites 881 cached files for nothing on every launch.
  test('files without the conflict are left alone', () {
    expect(normalizeNotoLottieBytes(fixtureBytes(timeStretch: 1)), isNull);
    // A time stretch WITHOUT remapping is legitimate (this is how 🔥 is built)
    // and must survive untouched.
    final fireLike = utf8.encode(json.encode(<String, Object?>{
      'v': '5.5.7',
      'fr': 60,
      'ip': 0,
      'op': 65,
      'w': 100,
      'h': 100,
      'layers': <Object?>[
        <String, Object?>{'ind': 1, 'ty': 0, 'sr': 0.555, 'ip': 0, 'op': 65.49},
      ],
    }));
    expect(normalizeNotoLottieBytes(fireLike), isNull);
  });

  /// 🔴 DIRECTION OF FAILURE. A corrupt or surprising file must return "no
  /// change" so the caller keeps the original bytes — never throw, never hand
  /// back something worse than what shipped.
  test('🔴 damaged input changes nothing instead of failing', () {
    expect(normalizeNotoLottieBytes(utf8.encode('not json at all')), isNull);
    expect(normalizeNotoLottieBytes(utf8.encode('[1,2,3]')), isNull);
    expect(normalizeNotoLottieBytes(const <int>[0xff, 0xfe, 0x00]), isNull);
    expect(
      normalizeNotoLottieBytes(utf8.encode(json.encode({
        'layers': [
          {'tm': null, 'sr': 'нечисло'},
        ],
        'assets': 'не список',
      }))),
      isNull,
    );
  });

  /// The same conflict inside a nested precomposition must be healed too — the
  /// rule is structural, not a list of codepoints.
  test('the conflict is healed inside assets as well', () {
    final nested = utf8.encode(json.encode(<String, Object?>{
      'v': '5.5.7',
      'fr': 60,
      'ip': 0,
      'op': 100,
      'assets': <Object?>[
        <String, Object?>{
          'id': 'comp_0',
          'layers': <Object?>[
            <String, Object?>{
              'ind': 1,
              'ty': 0,
              'sr': 0.5,
              'tm': {'a': 0, 'k': 1.0},
            },
          ],
        },
      ],
      'layers': <Object?>[],
    }));
    final healed = normalizeNotoLottieBytes(nested);
    expect(healed, isNotNull);
    final decoded = json.decode(utf8.decode(healed!)) as Map<String, Object?>;
    final assets = decoded['assets']! as List<Object?>;
    final layer = ((assets.first as Map)['layers'] as List).first as Map;
    expect(layer['sr'], 1);
    expect(layer['tm'], isNotNull, reason: 'перекладка времени обязана остаться');
  });
}

Map<String, Object?> _identityTransform() => <String, Object?>{
      'o': {'a': 0, 'k': 100},
      'r': {'a': 0, 'k': 0},
      'p': {
        'a': 0,
        'k': [50.0, 50.0, 0],
      },
      'a': {
        'a': 0,
        'k': [50.0, 50.0, 0],
      },
      's': {
        'a': 0,
        'k': [100.0, 100.0, 100],
      },
    };
