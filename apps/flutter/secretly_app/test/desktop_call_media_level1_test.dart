// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Три добавочные возможности медиа-движка (уровень 1 по
// docs/ВМЕШАТЕЛЬСТВО_В_МОБИЛЬНУЮ): камеры, показатели дорожки, громкость.
//
// 🔴 ДОБАВОЧНЫЕ — ЗНАЧИТ У ВСЕХ ТРЁХ ЕСТЬ ТЕЛО ПО УМОЛЧАНИЮ. Движок, который
// чего-то не умеет, продолжает работать без правок; мобильный экран созвона их
// просто не зовёт и не меняется ни на строку.
//
// «Не знаю» возвращается ПУСТОТОЙ: пустой список камер значит «выбирать не из
// чего», `null` у показателей — «мерить нечем», ноль у громкости — «тихо».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';

void main() {
  final media = File(
    'lib/rooms/room_call_media_controller.dart',
  ).readAsStringSync();
  final win = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  group('движок', () {
    test('🔴 у добавочного есть тело по умолчанию', () {
      expect(
        media.contains(
          'Future<List<RoomCallVideoDevice>> videoInputs() async =>\n      const <RoomCallVideoDevice>[];',
        ),
        isTrue,
      );
      expect(media.contains('double participantAudioLevel(String deviceId) => 0;'), isTrue);
    });

    test('🔴 мобильный экран созвона добавочного не зовёт', () {
      final mobile = File('lib/ui/room_call_screen.dart').readAsStringSync();
      for (final api in const [
        'videoInputs(',
        'selectVideoInput(',
        'videoStats(',
        'participantAudioLevel(',
      ]) {
        expect(mobile.contains(api), isFalse, reason: 'телефон зовёт $api');
      }
    });

    test('камеру переключаем У ДОРОЖКИ, а не «выбранное устройство»', () {
      // Второе влияет только на камеры, которые откроются ПОТОМ, а нужна та,
      // что уже идёт в созвон.
      expect(media.contains('await track.switchCamera(want);'), isTrue);
    });

    test('показатели — только у ПРИНИМАЕМОЙ дорожки', () {
      // Свою мы отдаём, и «сколько дошло» к ней неприменимо.
      expect(media.contains('if (track is! lk.RemoteVideoTrack) return null;'), isTrue);
    });

    test('пустые показатели — это «мерить нечем», а не нули', () {
      const empty = RoomCallVideoStats();
      expect(empty.isEmpty, isTrue);
      expect(const RoomCallVideoStats(height: 1080).isEmpty, isFalse);
      expect(media.contains('return out.isEmpty ? null : out;'), isTrue);
    });

    test('громкость зажата в 0…1 и не пропускает NaN', () {
      expect(media.contains('level.isFinite ? level.clamp(0.0, 1.0) : 0'), isTrue);
    });

    test('местное превью камеры перечисляет, а мерить не берётся', () {
      final i = media.indexOf('class _LocalPreviewRoomCallMediaController');
      final body = media.substring(i, (i + 9000).clamp(0, media.length));
      expect(body.contains("_enumerate('videoinput', 'Камера')"), isTrue);
      expect(body.contains('double participantAudioLevel(String deviceId) => 0;'), isTrue);
    });
  });

  group('окно созвона', () {
    test('🔴 камеры спрашиваются один раз, а не каждую отрисовку', () {
      // Перечисление устройств — обращение к системе, из `build` его звать
      // значит дёргать её шестьдесят раз в секунду.
      expect(win.contains('unawaited(_refreshCameras());'), isTrue);
      expect(win.contains('Future<void> _refreshCameras() async {'), isTrue);
    });

    test('шеврона нет, когда выбирать не из чего', () {
      expect(win.contains('onExpand: _cameras.length > 1 ? _pickCamera : null'), isTrue);
      expect(win.contains('if (media == null || _cameras.length < 2) return;'), isTrue);
    });

    test('🔴 показатели меряем только у ЧУЖОГО показа', () {
      expect(
        win.contains('pick.screenShare && !found.isSelf ? pick.deviceId : null'),
        isTrue,
      );
      expect(win.contains('stats: pick.screenShare && !found.isSelf ? _stageStats : null'), isTrue);
    });

    test('опрос останавливается вместе с окном', () {
      expect(win.contains('_statsTimer?.cancel();\n    super.dispose();'), isTrue);
    });

    test('🔴 в чипе только измеренное', () {
      // Движок может отдать высоту без частоты — тогда в чипе одна половина,
      // а не выдуманная вторая.
      expect(win.contains('if (h != null && h > 0) parts.add('), isTrue);
      expect(win.contains('if (fps != null && fps > 0) parts.add('), isTrue);
    });

    test('полоски громкости нет у молчащего и у «не слышит»', () {
      // Пустая шкала рядом с выключенным микрофоном — шум, а не сведения.
      expect(
        win.contains('if (!muted && !deafened && level > 0.02)'),
        isTrue,
      );
    });
  });
}
