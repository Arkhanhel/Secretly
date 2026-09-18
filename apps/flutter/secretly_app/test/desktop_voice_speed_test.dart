// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Переключатель скорости «1×» у голосового.
//
// Голосовые на компьютере слушают за работой, и минутное сообщение на
// полутора скоростях — это сорок секунд, а не минута.
//
// 🔴 ПРАВКА В ОБЩЕМ КОДЕ — УРОВНЯ 1: поле `speed` добавлено в состояние плеера
// с прежним умолчанием, метод `setSharedAudioSpeed` добавочный. Мобильные
// экраны ни поля, ни метода не знают — их вид не меняется ни на точку.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
  final bubble = File(
    'lib/ui/desktop/chat/message_bubble.dart',
  ).readAsStringSync();

  test('умолчание прежнее — обычная скорость', () {
    expect(const SharedAudioPlaybackState().speed, 1.0);
  });

  test('🔴 мобильные экраны о скорости не знают', () {
    for (final path in const [
      'lib/ui/chat_screen.dart',
      'lib/ui/chats_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('setSharedAudioSpeed'), isFalse, reason: path);
      // Именно поле состояния плеера: «.speed» само по себе совпадает с
      // `speedBytesPerSec` — скоростью передачи файла, к звуку не имеющей
      // отношения.
      expect(src.contains('sharedAudio.speed'), isFalse, reason: path);
      expect(src.contains('playback.speed'), isFalse, reason: path);
    }
  });

  test('скорость зажата: речь за границами перестаёт быть речью', () {
    expect(ctrl.contains('speed.clamp(0.5, 3.0)'), isTrue);
  });

  test('🔴 движок отказал — подпись НЕ врёт', () {
    // Иначе кнопка показывала бы «2×» при обычном воспроизведении.
    final i = ctrl.indexOf('Future<void> setSharedAudioSpeed(');
    final body = ctrl.substring(i, (i + 900).clamp(0, ctrl.length));
    expect(body.contains('} catch (_) {\n      // Движок отказал'), isTrue);
    expect(body.indexOf('return;') < body.indexOf('copyWith('), isTrue);
  });

  test('· круг из трёх ступеней, а не ползунок', () {
    // Скорость выбирают на слух и одним нажатием; ползунок в пузыре требовал
    // бы прицеливания мышью.
    expect(bubble.contains('double _nextVoiceSpeed(double current)'), isTrue);
    expect(bubble.contains('if (current < 1.25) return 1.5;'), isTrue);
    expect(bubble.contains('if (current < 1.75) return 2.0;'), isTrue);
    expect(bubble.contains('return 1.0;'), isTrue);
  });

  test('🔴 переключатель только у ЗВУЧАЩЕЙ записи', () {
    // У молчащей менять нечего, а кнопка рядом с каждым голосовым в ленте —
    // это тридцать кнопок, из которых работает одна.
    expect(
      bubble.contains('if (isActive && widget.onSetVoiceSpeed != null)'),
      isTrue,
    );
  });

  test('подпись без лишнего нуля', () {
    expect(bubble.contains("? '\${speed.toInt()}×'"), isTrue);
    expect(bubble.contains("speed.toStringAsFixed(1)"), isTrue);
  });
}
