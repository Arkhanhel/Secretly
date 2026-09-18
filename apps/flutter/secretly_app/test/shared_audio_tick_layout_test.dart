// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen.dart';

/// П-7 (01.09.2026): проигрывание аудио вызывало setState всего экрана пять раз
/// в секунду, перестраивая двадцать-сорок строк ленты ради одного пузыря.
/// Позиция уехала на точечный тик, но три поля обязаны остаться на полном
/// setState, потому что двигают РАЗМЕТКУ:
///
///  * наличие трека решает, есть ли у AppBar `bottom`, какова высота шапки и
///    сливается ли панель «сейчас играет» с закреплённым сообщением;
///  * смена трека переносит активное состояние на другой пузырь;
///  * пауза меняет иконку и в панели, и в пузыре.
///
/// Ошибка в эту сторону стоит лишнего перестроения; в обратную — застывшей
/// полосы прогресса или контента, не сдвинувшегося под выросшей шапкой.
void main() {
  group('позиция не трогает разметку', () {
    test('изменилась только позиция — полный ребилд не нужен', () {
      expect(
        sharedAudioChangeNeedsLayout(
          previousTrackId: 'track-1',
          previousPlaying: true,
          previousHasTrack: true,
          trackId: 'track-1',
          playing: true,
          hasTrack: true,
        ),
        isFalse,
        reason: 'это 99,9 % событий плеера — они обязаны быть дешёвыми',
      );
    });
  });

  group('разметку меняют ровно три вещи', () {
    test('появился трек — у AppBar появляется bottom', () {
      expect(
        sharedAudioChangeNeedsLayout(
          previousTrackId: null,
          previousPlaying: false,
          previousHasTrack: false,
          trackId: 'track-1',
          playing: true,
          hasTrack: true,
        ),
        isTrue,
      );
    });

    test('трек исчез — шапка возвращает прежнюю высоту', () {
      expect(
        sharedAudioChangeNeedsLayout(
          previousTrackId: 'track-1',
          previousPlaying: true,
          previousHasTrack: true,
          trackId: null,
          playing: false,
          hasTrack: false,
        ),
        isTrue,
      );
    });

    test('сменился трек — активное состояние переезжает на другой пузырь', () {
      expect(
        sharedAudioChangeNeedsLayout(
          previousTrackId: 'track-1',
          previousPlaying: true,
          previousHasTrack: true,
          trackId: 'track-2',
          playing: true,
          hasTrack: true,
        ),
        isTrue,
        reason: 'иначе предыдущий пузырь останется с залитой полосой '
            'и иконкой «пауза», хотя играет уже другое',
      );
    });

    test('пауза — меняются иконки в панели и в пузыре', () {
      expect(
        sharedAudioChangeNeedsLayout(
          previousTrackId: 'track-1',
          previousPlaying: true,
          previousHasTrack: true,
          trackId: 'track-1',
          playing: false,
          hasTrack: true,
        ),
        isTrue,
      );
    });
  });

  test('первое событие после открытия чата всегда структурное', () {
    // Начальный снимок — пустой: null / false / false. Что бы ни пришло
    // первым, оно обязано пройти через полный setState, иначе панель
    // «сейчас играет» не смонтируется вовсе.
    expect(
      sharedAudioChangeNeedsLayout(
        previousTrackId: null,
        previousPlaying: false,
        previousHasTrack: false,
        trackId: 'track-1',
        playing: false,
        hasTrack: true,
      ),
      isTrue,
    );
  });
}
