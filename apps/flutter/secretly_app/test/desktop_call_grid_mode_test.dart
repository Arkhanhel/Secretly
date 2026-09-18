// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ◆ Режим сетки в созвоне: все камеры разом вместо одной большой.
//
// Одна сцена отвечает на вопрос «кто сейчас говорит». Сетка — на другой: «как
// они все выглядят». В разговоре вчетвером второй вопрос важнее, и без сетки
// трое из четверых были видны только плитками в ленте сбоку.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final win = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  test('◆ переключатель есть и меняет подпись', () {
    expect(win.contains('bool _gridMode = false;'), isTrue);
    expect(win.contains("label: _gridMode ? 'Один' : 'Сетка'"), isTrue);
    expect(win.contains('onTap: () => setState(() => _gridMode = !_gridMode)'), isTrue);
  });

  test('🔴 переключателя НЕТ, когда переключать нечего', () {
    // На одного человека с камерой сетка из одной плитки — это та же сцена,
    // только меньше.
    expect(win.contains('if (_joined.length > 1) ...['), isTrue);
  });

  test('сетка — три колонки, плитки 16/10, радиус 10', () {
    expect(win.contains('crossAxisCount: 3'), isTrue);
    expect(win.contains('childAspectRatio: 16 / 10'), isTrue);
    expect(win.contains('borderRadius: BorderRadius.circular(DRadii.md)'), isTrue);
  });

  test('🔴 предел тот же, что у сетки портретов, и остаток назван', () {
    // На двенадцати участниках плитки становятся меньше значка и перестают
    // что-либо показывать. «+N» не прячет людей, а называет, сколько их ещё.
    expect(win.contains('participants.take(_kStageFacesMax)'), isTrue);
    expect(win.contains('class _GridOverflowTile'), isTrue);
    expect(win.contains("'+\$count'"), isTrue);
  });

  test('🔴 в сетку идёт КАМЕРА, а не показ экрана', () {
    // Показ крупный по своей природе, и плитка 16/10 делает из него
    // нечитаемый прямоугольник.
    final i = win.indexOf('return _StageGrid(');
    final body = win.substring(i - 400, (i + 900).clamp(0, win.length));
    expect(body.contains('kind: RoomCallVideoKind.camera'), isTrue);
  });

  test('камеры нет — портрет, а не чёрный прямоугольник', () {
    // Видно, кто здесь, даже когда смотреть не на что.
    final i = win.indexOf('class _GridTile');
    final body = win.substring(i, (i + 2600).clamp(0, win.length));
    expect(body.contains('if (video != null)'), isTrue);
    expect(body.contains('Avatar('), isTrue);
  });

  test('говорящий в рамке, а не подписью', () {
    // На плитке 16/10 подписи места нет.
    expect(win.contains('border: speaking'), isTrue);
    expect(win.contains('Border.all(color: c.success, width: 1.5)'), isTrue);
  });

  test('🔴 в сетке показатели дорожки не меряем', () {
    // Опрос статистики привязан к чужому показу на сцене; в сетке показа нет,
    // и таймер обязан остановиться, а не крутиться вхолостую.
    final i = win.indexOf('if (_gridMode && media != null');
    final body = win.substring(i, (i + 400).clamp(0, win.length));
    expect(body.contains('_syncStatsTimer(null);'), isTrue);
  });
}
