// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПОСЛЕДНИЙ ЧАСТИЧНЫЙ КРАСНЫЙ: панель участников.
//
// Группы по присутствию были сделаны раньше, а «В СОЗВОНЕ» с признаками
// микрофона и показа — нет, с объяснением «признаки живут в состоянии LiveKit
// и существуют только внутри идущего созвона».
//
// Объяснение оказалось НЕВЕРНЫМ. `muted`, `deafened`, `screenShareEnabled` и
// `joinState` лежат в `CachedRoomCall` — снимке, который видит ВСЯ комната, а
// не только подключившиеся к медиа. Из LiveKit приходит только «говорит», и
// его в списке по-прежнему нет.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/ui/desktop/chat/details/room_details_view.dart',
  ).readAsStringSync();

  test('🔴 группа «В СОЗВОНЕ» есть и стоит первой', () {
    // Она про то, что происходит СЕЙЧАС: остальные группы про состояние.
    final call = src.indexOf('label: l10n.desktopRoomInCall');
    final online = src.indexOf('label: l10n.desktopRoomOnline');
    final offline = src.indexOf('label: l10n.desktopRoomOffline');
    expect(call, greaterThan(0));
    expect(call, lessThan(online));
    expect(online, lessThan(offline));
  });

  test('снимок созвона — ТОТ ЖЕ, что у плашки и окна созвона', () {
    expect(src.contains('widget.controller.getCachedRoomCall(gid)'), isTrue);
    expect(src.contains("debugName: 'roomDetailsCall'"), isTrue);
    // И снимается вместе с панелью.
    expect(src.contains('_callSel.removeListener(_onRoom);'), isTrue);
    expect(src.contains('_callSel.dispose();'), isTrue);
  });

  test('в созвоне считаем только ВОШЕДШИХ', () {
    expect(src.contains('if (!p.isJoined) continue;'), isTrue);
    // Один профиль может сидеть с двух устройств — значок рисуем один.
    expect(src.contains('out.putIfAbsent(p.profileId, () => p);'), isTrue);
  });

  test('🔴 признаки ТОЛЬКО у тех, кто в созвоне', () {
    // Серый перечёркнутый микрофон у того, кто в созвоне не участвует,
    // читался бы как «он там и молчит».
    expect(src.contains('if (call != null) ...['), isTrue);
    expect(src.contains('final CachedRoomCallParticipant? call;'), isTrue);
  });

  test('«не слышит» важнее «микрофон выключен»', () {
    // Выключенный себе звук значит, что человек не слышит НИЧЕГО, и состояние
    // его микрофона в этот момент ничего не решает.
    final i = src.indexOf('call!.deafened\n                      ? FluentIcons.speaker_off_24_filled');
    expect(i, greaterThan(0));
  });

  test('«показывает экран» важнее подписи роли', () {
    // Роль постоянна, а показ идёт прямо сейчас.
    expect(src.contains("if (call?.screenShareEnabled ?? false)"), isTrue);
    expect(src.contains('l10n.desktopCallSharingShort'), isTrue);
  });

  test('строка в созвоне подсвечена зелёной плёнкой', () {
    expect(
      src.contains("c.success.withValues(alpha: hovered ? 0.14 : 0.08)"),
      isTrue,
    );
  });

  test('🔴 «отошёл» и «говорит» по-прежнему НЕ рисуем', () {
    // Поля «отошёл» в модели нет вовсе, а «говорит» приходит из LiveKit и
    // существует только внутри идущего созвона.
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('отошёл'), isFalse);
    expect(code.contains('speaking'), isFalse);
  });

  // 🔴 ВТОРАЯ ПОЛОВИНА ПУНКТА: колонка должна вести себя ПОСТОЯННОЙ.
  //
  // В макете справа постоянная колонка, у нас выдвижной ящик, который
  // закрывался на КАЖДОМ переходе между разделами. Тот, кто держит состав
  // комнаты открытым, открывал его заново после каждого захода в «Звонки».
  group('панель остаётся там, где её оставили', () {
    final shell = File(
      'lib/ui/desktop/shell/desktop_shell.dart',
    ).readAsStringSync();

    test('🔴 смена раздела больше не захлопывает панель', () {
      expect(shell.contains('_detailsOpen = false; // collapse on switch'), isFalse);
      expect(
        shell.contains('_detailsOpen = _sectionHasDetails(s) && _detailsWanted;'),
        isTrue,
      );
    });

    // 🔴 НАЙДЕНО ЖИВЬЁМ. Первая редакция только «не захлопывала» панель — и в
    // «Звонках» оставалась висеть карточка чата, из которого человек ушёл.
    // Признак «хочу видеть» обязан сохраняться, а сама панель — исчезать там,
    // где ей нечего показать.
    test('🔴 в разделе без панели её НЕТ, даже когда её хотят', () {
      final i = shell.indexOf('void _selectSection(');
      final body = shell.substring(i, (i + 1600).clamp(0, shell.length));
      expect(body.contains('_sectionHasDetails(s) && _detailsWanted'), isTrue);
    });

    test('признак переживает раздел, где панели нет вовсе', () {
      expect(shell.contains('bool _detailsWanted = false;'), isTrue);
      expect(shell.contains('_detailsWanted = _detailsOpen;'), isTrue);
    });

    test('и переживает перезапуск окна', () {
      expect(shell.contains("_kDetailsOpenKey = 'desktop_pane_details_open_v1'"), isTrue);
      expect(shell.contains('prefs.setBool(_kDetailsOpenKey, _detailsWanted)'), isTrue);
      expect(shell.contains('prefs.getBool(_kDetailsOpenKey) ?? false'), isTrue);
    });

    test('в разделе без панели открытой она не станет', () {
      expect(
        shell.contains('if (open && _sectionHasDetails(_section)) _detailsOpen = true;'),
        isTrue,
      );
    });
  });
}
