// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ОДИН ЧЕЛОВЕК — ДВА ВИДА: экран на сцене и лицо в ленте одновременно.
//
// ЧТО БЫЛО. `buildParticipantVideoView` отдавал ОДИН вид на участника и всегда
// предпочитал демонстрацию камере (`screenShareTrack ?? cameraTrack`). У того,
// кто показывает экран, камера была недостижима В ПРИНЦИПЕ: плитка в ленте
// показала бы второй раз тот же экран, а не лицо. Лента из макета, где человек
// занимает сцену показом и держит рядом своё лицо, физически не собиралась.
//
// 🔴 ПРАВКА ДОБАВОЧНАЯ. Умолчание `auto` повторяет прежнее поведение знак в
// знак, и мобильный экран созвона вызывает метод БЕЗ нового параметра — он
// выпущен, и трогать его нельзя.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';

void main() {
  final src = File(
    'lib/rooms/room_call_media_controller.dart',
  ).readAsStringSync();

  test('виды названы и умолчание — прежнее поведение', () {
    expect(RoomCallVideoKind.values.length, 3);
    expect(
      src.contains('RoomCallVideoKind kind = RoomCallVideoKind.auto'),
      isTrue,
    );
  });

  test('🔴 мобильный экран созвона зовёт метод БЕЗ нового параметра', () {
    // Значит его поведение не меняется ни на строку.
    final mobile = File('lib/ui/room_call_screen.dart').readAsStringSync();
    expect(mobile.contains('buildParticipantVideoView('), isTrue);
    expect(mobile.contains('kind:'), isFalse);
  });

  test('«авто» по-прежнему предпочитает экран камере', () {
    expect(
      src.contains(
        'RoomCallVideoKind.auto =>\n        binding?.screenShareTrack ?? binding?.cameraTrack',
      ),
      isTrue,
    );
  });

  test('«экран» и «камера» берут ровно свою дорожку', () {
    expect(
      src.contains('RoomCallVideoKind.screenShare => binding?.screenShareTrack'),
      isTrue,
    );
    expect(src.contains('RoomCallVideoKind.camera => binding?.cameraTrack'), isTrue);
  });

  test('🔴 вид входит в ключ отрисовщика', () {
    // Иначе сцена и плитка одного человека делили бы один отрисовщик, и
    // второй вид переиспользовал бы дорожку первого — на плитке показывался
    // бы экран вместо лица.
    expect(src.contains(r'${kind.name}'), isTrue);
  });

  test('у местного превью дорожка одна — чужой вид не подсовываем', () {
    // Просят экран, а идёт камера — честнее отдать пусто.
    expect(
      src.contains(
        'if (kind == RoomCallVideoKind.screenShare && !showingScreen) return null;',
      ),
      isTrue,
    );
    expect(
      src.contains(
        'if (kind == RoomCallVideoKind.camera && showingScreen) return null;',
      ),
      isTrue,
    );
  });

  group('окно созвона', () {
    final win = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();

    test('сцена просит ИМЕННО то, что выбрала', () {
      expect(
        win.contains(
          'kind: pick.screenShare\n                ? RoomCallVideoKind.screenShare\n                : RoomCallVideoKind.camera,',
        ),
        isTrue,
      );
    });

    test('плитка всегда просит ЛИЦО', () {
      expect(win.contains('kind: RoomCallVideoKind.camera,'), isTrue);
    });

    test('🔴 повтором считается кадр, а не участник', () {
      // На сцене идёт ЭКРАН — лицо этого человека в ленте не повтор, а второй
      // его вид. Повтором было бы лицо, когда на сцене тоже лицо.
      expect(win.contains('final faceOnStage = onStage && !pick.screenShare;'), isTrue);
      expect(win.contains('(!faceOnStage && hasCamera && media != null)'), isTrue);
    });
  });
}
