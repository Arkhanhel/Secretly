// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// FFmpeg на телефонах — LGPL (04.10.2026, поручение владельца).
//
// 🔴 ЗАЧЕМ. Приложения в App Store и Google Play везли GPL-сборку FFmpeg с
// x264: условия магазинов с GPL несовместимы, а наше исключение для магазинов
// чужой код не покрывает. Телефоны теперь везут LGPL-сборку, а видео кодирует
// система. Компьютеры раздаются с сайта и остаются на GPL-сборке с libx264.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/legal/ffmpeg_mobile_license.dart';
import 'package:secretly_app/media/h264_encoder.dart';

void main() {
  tearDown(() => H264Encoder.debugPlatform = null);

  group('кодер по площадке', () {
    test('Android — системный MediaCodec, запасной MPEG-4', () {
      H264Encoder.debugPlatform = H264Platform.android;
      final v = H264Encoder.variants(crf: 23, kbps: 1200);
      expect(v.first, contains('-c:v h264_mediacodec'));
      expect(v.first, contains('-b:v 1200k'));
      expect(v.last, contains('-c:v mpeg4'));
      expect(v.join(' '), isNot(contains('libx264')));
      // Без запасного — только системный (сжатие перед отправкой).
      expect(H264Encoder.variants(crf: 25, kbps: 4000, fallback: false), [
        '-c:v h264_mediacodec -b:v 4000k -pix_fmt yuv420p',
      ]);
    });

    test('iOS — VideoToolbox, запасной OpenH264 (тоже H.264)', () {
      H264Encoder.debugPlatform = H264Platform.ios;
      final v = H264Encoder.variants(crf: 23, kbps: 6000);
      expect(v.first, contains('-c:v h264_videotoolbox'));
      expect(v.first, contains('-allow_sw 1'));
      expect(v.last, contains('-c:v libopenh264'));
      expect(v.join(' '), isNot(contains('libx264')));
    });

    test('компьютер — libx264, как раньше', () {
      H264Encoder.debugPlatform = H264Platform.desktop;
      expect(H264Encoder.variants(crf: 28, kbps: 900), [
        '-c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p',
      ]);
    });
  });

  test('🔴 в коде приложения libx264 называет только помощник кодера', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('h264_encoder.dart')) continue;
      if (f.readAsStringSync().contains('-c:v libx264')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  group('сборка FFmpeg', () {
    const plugin = 'third_party/ffmpeg_kit_flutter_new';

    test('pubspec берёт свою копию плагина', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('path: $plugin'));
    });

    test('Android — LGPL-артефакт ffmpeg-kit-full', () {
      final gradle = File('$plugin/android/build.gradle').readAsStringSync();
      expect(gradle, contains('com.antonkarpenko:ffmpeg-kit-full:2.1.0'));
      expect(gradle, isNot(contains('ffmpeg-kit-full-gpl')));
    });

    test('iOS — LGPL-архив, сверка по SHA-256', () {
      final setup = File('$plugin/scripts/setup_ios.sh').readAsStringSync();
      expect(setup, contains('/8.0.0-full/ffmpeg-kit-ios-full-8.0.0.zip'));
      expect(setup, isNot(contains('full-gpl')));
      expect(setup, contains('shasum -a 256 -c'));
    });

    test('macOS (компьютер) остаётся на GPL-сборке', () {
      final setup = File('$plugin/scripts/setup_macos.sh').readAsStringSync();
      expect(setup, contains('full-gpl'));
    });
  });

  group('экран лицензий', () {
    test('телефон заявляет FFmpeg под LGPL-3.0 с текстом лицензии', () async {
      LicenseRegistry.reset();
      registerMobileFfmpegLicense(onMobile: true);
      final entries = await LicenseRegistry.licenses.toList();
      final ffmpeg = entries.where((e) => e.packages.contains('FFmpeg'));
      expect(ffmpeg, hasLength(1));
      final text = ffmpeg.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('LGPL-3.0'));
      expect(text, contains('GNU LESSER GENERAL PUBLIC LICENSE'));
      LicenseRegistry.reset();
    });

    test('не на телефоне — ничего не заявляет', () async {
      LicenseRegistry.reset();
      registerMobileFfmpegLicense(onMobile: false);
      expect(await LicenseRegistry.licenses.toList(), isEmpty);
    });

    test('main.dart вызывает запись на телефоне', () {
      expect(
        File('lib/main.dart').readAsStringSync(),
        contains('registerMobileFfmpegLicense();'),
      );
    });
  });
}
