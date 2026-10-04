// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Кодер H.264 для FFmpeg — по лицензии той сборки FFmpeg, что едет в
/// приложении.
///
/// 🔴 LGPL НА ТЕЛЕФОНАХ (04.10.2026, поручение владельца). Приложения в
/// App Store и Google Play везут LGPL-сборку FFmpegKit: GPL-компоненты (x264)
/// несовместимы с условиями магазинов, а наше исключение для магазинов чужой
/// код не покрывает. В LGPL-сборке нет libx264 — видео на телефоне кодирует
/// система: Android — `h264_mediacodec`, iOS — `h264_videotoolbox` (заодно
/// патентные отчисления за H.264 платит производитель системы). Компьютеры
/// раздаются с сайта с GPL-сборкой и кодируют, как раньше, libx264.
///
/// Кодер системы управляется битрейтом, а не `-crf`: у каждого места свой
/// [kbps], подобранный под размер картинки. Не сработал основной кодер —
/// пробуется запасной: на iOS программный `libopenh264` (тоже H.264), на
/// Android — `mpeg4` (MPEG-4 Part 2; iPhone играет его только до 640×480,
/// поэтому там, где картинка крупнее, запасной вариант отключают).
library;

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

/// На какой площадке кодируем.
enum H264Platform { android, ios, desktop }

abstract final class H264Encoder {
  /// Подмена площадки для тестов (CI гоняет их на Linux).
  @visibleForTesting
  static H264Platform? debugPlatform;

  static H264Platform get platform =>
      debugPlatform ??
      (Platform.isAndroid
          ? H264Platform.android
          : Platform.isIOS
          ? H264Platform.ios
          : H264Platform.desktop);

  /// Аргументы видеокодера по порядку: основной, затем запасной.
  ///
  /// [crf] — качество libx264 на компьютере, [kbps] — битрейт кодера
  /// системы на телефоне. [fallback] — пробовать ли запасной кодер.
  static List<String> variants({
    required int crf,
    required int kbps,
    bool fallback = true,
  }) {
    switch (platform) {
      case H264Platform.android:
        return <String>[
          '-c:v h264_mediacodec -b:v ${kbps}k -pix_fmt yuv420p',
          if (fallback) '-c:v mpeg4 -q:v 5 -pix_fmt yuv420p',
        ];
      case H264Platform.ios:
        return <String>[
          '-c:v h264_videotoolbox -b:v ${kbps}k -allow_sw 1 -pix_fmt yuv420p',
          if (fallback) '-c:v libopenh264 -b:v ${kbps}k -pix_fmt yuv420p',
        ];
      case H264Platform.desktop:
        return <String>['-c:v libx264 -preset veryfast -crf $crf -pix_fmt yuv420p'];
    }
  }

  /// Выполнить команду [build] с каждым вариантом кодера по очереди — до
  /// первого успеха. Возвращает последнюю сессию (успешную или последнюю
  /// неудачную), чтобы вызывающий проверил её, как раньше.
  static Future<FFmpegSession> execute(
    String Function(String videoArgs) build, {
    required int crf,
    required int kbps,
    bool fallback = true,
  }) async {
    final all = variants(crf: crf, kbps: kbps, fallback: fallback);
    FFmpegSession? session;
    for (final args in all) {
      session = await FFmpegKit.execute(build(args));
      if (ReturnCode.isSuccess(await session.getReturnCode())) return session;
    }
    return session!;
  }
}
