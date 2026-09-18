// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Сцена созвона гасла, когда никто не говорил.
//
// 🔴 ЧТО БЫЛО. Условие показа камеры было буквально таким: `speaking ||
// участников ровно один`. Втроём, с включёнными у всех камерами, в первую же
// паузу разговора ни одна камера не проходила проверку — и сцена уходила в
// сетку неподвижных портретов. Стоило кому-то заговорить, картинка
// возвращалась. Она мигала в такт речи.
//
// Памяти о том, кто говорил последним, в состоянии не было вообще, так что
// даже «оставить того, кто только что держал слово» было нечем.
//
// Порядок выбора проверяется здесь — без камер, комнаты и второго человека:
// живьём такой созвон не собрать в одиночку.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/calls/call_stage_pick.dart';

void main() {
  group('порядок выбора картинки', () {
    test('демонстрация экрана важнее любого лица', () {
      final pick = pickStageVideo(
        screenShares: const ['d-screen'],
        cameras: const ['d-a', 'd-b'],
        speaking: const {'d-a'},
        lastSpeaker: 'd-b',
      );
      expect(pick?.deviceId, 'd-screen');
      expect(pick?.screenShare, isTrue);
    });

    test('без демонстрации — тот, кто говорит', () {
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const ['d-a', 'd-b'],
        speaking: const {'d-b'},
      );
      expect(pick?.deviceId, 'd-b');
      expect(pick?.screenShare, isFalse);
    });

    test('🔴 В ПАУЗЕ сцена держит последнего говорившего', () {
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const ['d-a', 'd-b', 'd-c'],
        speaking: const {},
        lastSpeaker: 'd-c',
      );
      expect(
        pick?.deviceId,
        'd-c',
        reason: 'ровно тот случай, в котором сцена и гасла',
      );
    });

    test('🔴 никто ещё не говорил — любая живая камера, а не сетка лиц', () {
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const ['d-a', 'd-b'],
        speaking: const {},
      );
      expect(pick?.deviceId, 'd-a');
    });

    test('у последнего говорившего выключилась камера — берём другую', () {
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const ['d-a'],
        speaking: const {},
        lastSpeaker: 'd-ушёл',
      );
      expect(pick?.deviceId, 'd-a');
    });

    test('камер нет вовсе — сетка портретов', () {
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const [],
        speaking: const {'d-a'},
        lastSpeaker: 'd-a',
      );
      expect(pick, isNull);
    });

    test('один в созвоне со своей камерой — она и на сцене', () {
      // Прежнее поведение (`участников ровно один`) сохранено, но теперь как
      // частный случай общего правила, а не как отдельная проверка.
      final pick = pickStageVideo(
        screenShares: const [],
        cameras: const ['d-self'],
        speaking: const {},
      );
      expect(pick?.deviceId, 'd-self');
    });
  });

  group('память сцены', () {
    test('🔴 тишина НЕ стирает память', () {
      final next = nextLastSpeaker(
        speaking: const {},
        cameras: const ['d-a'],
        previous: 'd-a',
      );
      expect(
        next,
        'd-a',
        reason: 'в этом весь смысл: пауза не должна гасить сцену',
      );
    });

    test('говорящий на сцене остаётся, пока не замолчит', () {
      // Иначе при двух говорящих картинка прыгала бы между ними на каждом
      // кадре.
      final next = nextLastSpeaker(
        speaking: const {'d-a', 'd-b'},
        cameras: const ['d-b', 'd-a'],
        previous: 'd-a',
      );
      expect(next, 'd-a');
    });

    test('замолчал — переходим к тому, кто говорит', () {
      final next = nextLastSpeaker(
        speaking: const {'d-b'},
        cameras: const ['d-a', 'd-b'],
        previous: 'd-a',
      );
      expect(next, 'd-b');
    });

    test('говорит тот, у кого камеры нет — память не меняется', () {
      final next = nextLastSpeaker(
        speaking: const {'d-voice-only'},
        cameras: const ['d-a'],
        previous: 'd-a',
      );
      expect(next, 'd-a');
    });
  });
}
