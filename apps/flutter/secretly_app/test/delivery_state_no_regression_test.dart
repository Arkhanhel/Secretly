// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';

/// ИНДИКАТОР НЕ ХОДИТ НАЗАД (полевая жалоба 02.09.2026: «галочка сменилась на
/// часики снова, потом опять на галочку»).
///
/// Сообщение 1:1 разлетается по ВСЕМ устройствам собеседника — их бывает до
/// восьми, — и каждая копия ведёт свою строку очереди с общим событием.
/// Правило «побеждает первый успех» уже применялось к подтверждению реле,
/// поэтому галочка появлялась по первой принятой копии. Но копия для второго
/// устройства продолжала попытки и откатывала событие обратно в
/// «отправляется»: часы поверх уже показанной галочки, затем снова галочка,
/// и так столько раз, сколько у собеседника устройств.
///
/// Прежняя редакция `canPromote` заканчивалась `return true` — то есть
/// разрешала ЛЮБОЙ переход, не описанный явно, включая любой откат.
void main() {
  const inFlight = <String>[
    MessageLocalState.pending,
    MessageLocalState.sending,
    MessageLocalState.retry,
  ];

  group('индикатор доставки не откатывается назад', () {
    test('🔴 из «отправлено» нельзя вернуться в часы', () {
      for (final back in inFlight) {
        expect(
          MessageLocalState.canPromote(
            from: MessageLocalState.sent,
            to: back,
          ),
          isFalse,
          reason: 'ровно этот откат и показывал часы поверх галочки: '
              'копия для второго устройства шла на повтор уже после того, '
              'как первая была принята реле (переход в "$back")',
        );
      }
    });

    test('из «доставлено» нельзя вернуться в часы', () {
      for (final back in inFlight) {
        expect(
          MessageLocalState.canPromote(
            from: MessageLocalState.delivered,
            to: back,
          ),
          isFalse,
        );
      }
    });

    test('из «прочитано» нельзя вернуться ни в часы, ни в галочку', () {
      for (final back in [...inFlight, MessageLocalState.sent]) {
        expect(
          MessageLocalState.canPromote(
            from: MessageLocalState.read,
            to: back,
          ),
          isFalse,
        );
      }
    });

    test('из «доставлено» нельзя откатиться в «отправлено»', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.delivered,
          to: MessageLocalState.sent,
        ),
        isFalse,
        reason: 'подтверждение копии для второго устройства приходит ПОСЛЕ '
            'квитанции от первого — оно не должно гасить белую галочку',
      );
    });
  });

  group('прогресс вперёд по-прежнему разрешён', () {
    test('обычный путь сообщения проходит целиком', () {
      const path = <String>[
        MessageLocalState.pending,
        MessageLocalState.sending,
        MessageLocalState.sent,
        MessageLocalState.delivered,
        MessageLocalState.read,
      ];
      for (var i = 0; i + 1 < path.length; i++) {
        expect(
          MessageLocalState.canPromote(from: path[i], to: path[i + 1]),
          isTrue,
          reason: 'переход ${path[i]} → ${path[i + 1]} обязан работать',
        );
      }
    });

    test('первое присвоение состояния разрешено', () {
      expect(
        MessageLocalState.canPromote(from: '', to: MessageLocalState.pending),
        isTrue,
        reason: 'у нового события состояния ещё нет',
      );
    });

    test('повтор той же ступени безвреден', () {
      for (final state in [
        MessageLocalState.sent,
        MessageLocalState.delivered,
        MessageLocalState.read,
      ]) {
        expect(
          MessageLocalState.canPromote(from: state, to: state),
          isTrue,
        );
      }
    });

    test('ручной повтор после провала возвращает сообщение в отправку', () {
      for (final again in inFlight) {
        expect(
          MessageLocalState.canPromote(
            from: MessageLocalState.failed,
            to: again,
          ),
          isTrue,
          reason: 'иначе кнопка «повторить» перестала бы работать',
        );
      }
    });
  });

  group('квитанция сильнее локального предположения о провале', () {
    test('🔴 «доставлено» применяется поверх «не отправлено»', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.failed,
          to: MessageLocalState.delivered,
        ),
        isTrue,
        reason: 'квитанция — доказательство, что конверт у собеседника; '
            'локальная пометка о провале рядом с ней всего лишь наше '
            'предположение, и оно проиграло',
      );
    });

    test('«прочитано» применяется поверх «не отправлено»', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.failed,
          to: MessageLocalState.read,
        ),
        isTrue,
      );
    });
  });

  group('провал объявляется только пока получение не подтверждено', () {
    test('🔴 доставленное сообщение нельзя объявить неотправленным', () {
      for (final confirmed in [
        MessageLocalState.delivered,
        MessageLocalState.read,
      ]) {
        expect(
          MessageLocalState.canPromote(
            from: confirmed,
            to: MessageLocalState.failed,
          ),
          isFalse,
          reason: 'собеседник его уже получил — красная галочка была бы '
              'прямой ложью',
        );
      }
    });

    test('пока конверт в пути, провал показать можно', () {
      for (final state in [...inFlight, MessageLocalState.sent]) {
        expect(
          MessageLocalState.canPromote(
            from: state,
            to: MessageLocalState.failed,
          ),
          isTrue,
        );
      }
    });
  });
}
