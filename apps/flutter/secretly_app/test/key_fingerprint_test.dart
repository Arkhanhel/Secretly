// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Обложка «Отпечаток ключа»: узор из SHA-256 ключа личности.
// `SECRETLY_SHOTS=папка` — снимок нескольких ключей в обеих темах.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/profile/key_fingerprint.dart';
import 'package:secretly_app/ui/profile/pattern_cover.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

List<int> _key(String s) => crypto.sha256.convert(utf8.encode(s)).bytes;

Widget _cover(
  List<int>? key,
  Brightness b,
  PatternCoverInput input, {
  double t = 3,
}) {
  final bg = b == Brightness.dark
      ? const Color(0xFF151E27)
      : const Color(0xFFF1F4F7);
  return SizedBox(
    width: 195,
    height: 230,
    child: FittedBox(
      child: SizedBox(
        width: 390,
        height: 460,
        child: PatternCoverBackdrop(
          tint: patternCoverTint(const Color(0xFF7C6CF3), b),
          background: bg,
          avatarCenterY: input.avatarCenterY,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: PatternCoverPainter(
                  style: PatternCoverStyle.fingerprint,
                  input: input,
                  bands: List<double>.filled(
                    6,
                    PatternCoverBands.target(input),
                  ),
                  time: t,
                  ink: patternCoverInk(b),
                  inkStrength: patternCoverInkStrength(b),
                  keyBytes: key,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.52),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('один ключ — одна раскладка; другой ключ — другая', () {
    final a = KeyFingerprintLayout.build(_key('alice'));
    final a2 = KeyFingerprintLayout.build(_key('alice'));
    final b = KeyFingerprintLayout.build(_key('bob'));
    expect(a.arcs, a2.arcs);
    expect(a.dots, a2.dots);
    expect(a.arcs, isNot(equals(b.arcs)));
    // Кэш отдаёт ту же раскладку и не строит её заново на каждый кадр.
    final c1 = KeyFingerprintLayout.of(_key('alice'));
    final c2 = KeyFingerprintLayout.of(List<int>.of(_key('alice')));
    expect(identical(c1, c2), isTrue);
    expect(c1.arcs, a.arcs);
    // Без ключа — превью, тоже стабильное.
    expect(
      identical(KeyFingerprintLayout.of(null), KeyFingerprintLayout.of(null)),
      isTrue,
    );
    expect(
      KeyFingerprintLayout.of(const []).arcs,
      KeyFingerprintLayout.of(null).arcs,
    );
  });

  test('раскладка по макету: кольца, пропуски, длины, точки', () {
    for (final seed in ['alice', 'bob', 'carol', 'dave']) {
      final l = KeyFingerprintLayout.build(_key(seed));
      expect(l.dots, hasLength(56));
      for (final d in l.dots) {
        expect(d.size, inInclusiveRange(0.8, 2.6));
      }
      final perRing = [0, 0, 0];
      for (final a in l.arcs) {
        perRing[a.ring]++;
        final (r, n, w, al) = KeyFingerprintLayout.rings[a.ring];
        expect(a.radius, r);
        expect(a.width, w);
        expect(a.alpha, al);
        expect(a.band, a.ring * 2);
        final sector = math.pi * 2 / n;
        expect(a.sweep, inInclusiveRange(0.3 * sector, 0.9 * sector + 1e-9));
        expect(a.speed, (a.ring.isOdd ? -1 : 1) * 0.012);
        // Начало — ровно на границе своего сектора.
        final i = a.start / sector;
        expect((i - i.round()).abs(), lessThan(1e-9));
      }
      expect(perRing[0], lessThanOrEqualTo(24));
      expect(perRing[1], lessThanOrEqualTo(32));
      expect(perRing[2], lessThanOrEqualTo(40));
      // Пропусков (байт < 0,18) — примерно каждый шестой, не все и не ни одного.
      expect(l.arcs.length, inInclusiveRange(48, 95));
    }
  });

  test('🔴 формула закреплена: известный ключ даёт известный узор', () {
    // Люди сравнивают узоры на разных телефонах и сборках — менять формулу
    // нельзя. Если этот тест упал, узоры у всех разошлись.
    final l = KeyFingerprintLayout.build(_key('secretly'));
    final sig = crypto.sha256
        .convert(
          utf8.encode(
            [
              for (final a in l.arcs)
                '${a.ring}:${a.start.toStringAsFixed(6)}:'
                    '${a.sweep.toStringAsFixed(6)}',
              for (final d in l.dots) d.size.toStringAsFixed(6),
            ].join('|'),
          ),
        )
        .toString();
    expect(sig, _kGoldenSignature);
  });

  test('ключ из base64: SHA-256 открытого ключа; мусор — null', () {
    final pub = List<int>.generate(32, (i) => i);
    expect(
      fingerprintKeyFromPublicKeyB64(base64Encode(pub)),
      crypto.sha256.convert(pub).bytes,
    );
    expect(fingerprintKeyFromPublicKeyB64(null), isNull);
    expect(fingerprintKeyFromPublicKeyB64('  '), isNull);
    expect(fingerprintKeyFromPublicKeyB64('%%%'), isNull);
  });

  test('в каталоге первой, бесплатная; старый id не ломается', () {
    expect(kKeyFingerprintCoverId, 'pattern_fingerprint');
    expect(kPatternProfileCovers.first.id, kKeyFingerprintCoverId);
    expect(kPatternProfileCovers.first.nameRu, 'Отпечаток ключа');
    expect(kPatternProfileCovers.first.nameEn, 'Key fingerprint');
    expect(kFreeProfileCoverIds, contains(kKeyFingerprintCoverId));
    expect(coverById(kKeyFingerprintCoverId), isNotNull);
    expect(isKeyFingerprintCover('pattern_fingerprint'), isTrue);
    expect(isKeyFingerprintCover('pattern_orbits'), isFalse);
    expect(isKeyFingerprintCover(null), isFalse);
  });

  test('рисовальщик: другой ключ — перерисовать', () {
    PatternCoverPainter p(List<int>? k) => PatternCoverPainter(
      style: PatternCoverStyle.fingerprint,
      input: const PatternCoverInput(),
      bands: List<double>.filled(6, 1),
      time: 1,
      ink: Colors.white,
      keyBytes: k,
    );
    expect(p(_key('a')).shouldRepaint(p(_key('a'))), isFalse);
    expect(p(_key('a')).shouldRepaint(p(_key('b'))), isTrue);
    expect(p(null).shouldRepaint(p(_key('a'))), isTrue);
  });

  testWidgets('область ключа: байты доходят, без области — превью', (t) async {
    List<int>? seen;
    List<int>? fallback;
    await t.pumpWidget(
      Column(
        textDirection: TextDirection.ltr,
        children: [
          PatternCoverKey(
            keyBytes: _key('alice'),
            child: Builder(
              builder: (c) {
                seen = PatternCoverKey.maybeOf(c);
                return const SizedBox();
              },
            ),
          ),
          Builder(
            builder: (c) {
              fallback = PatternCoverKey.of(c);
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    expect(seen, _key('alice'));
    expect(fallback, KeyFingerprintLayout.previewSeed);
  });

  testWidgets('подсказка по касанию — снэкбар с текстом владельца', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Localizations.override(
            context: c,
            locale: const Locale('ru'),
            child: const Scaffold(
              body: KeyFingerprintTapHint(
                child: SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(KeyFingerprintTapHint));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('ключа шифрования'), findsOneWidget);
    expect(t.takeException(), isNull);
    // Выключенная — касание проходит насквозь.
    await t.pumpWidget(
      const MaterialApp(
        home: KeyFingerprintTapHint(enabled: false, child: SizedBox()),
      ),
    );
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('рисуется в обеих темах, во все моменты (снимок)', (t) async {
    t.view.physicalSize = const Size(1000, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final keys = <List<int>?>[null, _key('alice'), _key('bob'), _key('carol')];
    const rest = PatternCoverInput(avatarCenterY: 111, fadeY: 260);
    Widget grid({double time = 3, PatternCoverInput input = rest}) =>
        MaterialApp(
          home: SingleChildScrollView(
            child: RepaintBoundary(
              key: _shotKey,
              child: Wrap(
                children: [
                  for (final b in Brightness.values)
                    for (final k in keys) _cover(k, b, input, t: time),
                ],
              ),
            ),
          ),
        );
    for (final time in [0.0, 1.5, 60.0, 3600.0]) {
      await t.pumpWidget(grid(time: time));
      expect(t.takeException(), isNull, reason: 't=$time');
    }
    for (final input in const [
      PatternCoverInput(pull: 200, avatarCenterY: 180, fadeY: 400),
      PatternCoverInput(collapse: 0.7, avatarCenterY: 40, fadeY: 200),
      PatternCoverInput(expanded: 0.5),
    ]) {
      await t.pumpWidget(grid(input: input));
      expect(t.takeException(), isNull);
    }
    final dir = _shots;
    if (dir != null && dir.isNotEmpty) {
      await t.pumpWidget(grid());
      await t.runAsync(() async {
        final rb =
            _shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dir/key_fingerprint_covers.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}

/// Подпись раскладки ключа `sha256('secretly')` — см. тест «формула
/// закреплена».
const String _kGoldenSignature =
    '97e76a532f4a3e7b54b70b044f0e6324c2cd6545ad37790371b526c7b83525c4';
