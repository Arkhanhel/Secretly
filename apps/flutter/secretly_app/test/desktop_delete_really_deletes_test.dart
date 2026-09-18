// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 УДАЛИЛ — ЗНАЧИТ УДАЛИЛ, А НЕ СПРЯТАЛ.
//
// ЖАЛОБА ВЛАДЕЛЬЦА 16.09.2026: «очистка и удаление должно реально удалить
// смс / собеседника / группу, а не просто исчезнуть, а потом внезапно взяться
// откуда-то после синхронизации».
//
// ЧТО ПРОИСХОДИЛО. Удаление чата на компьютере делало ровно одно: стирало
// строки в здешней базе. Но при запуске окно просит у телефона окно недавней
// переписки, и приёмник чанка (`_applyPeerHistoryChunk`) кладёт события
// обратно — он для того и написан. Сам чат в списке прятала метка сноса
// (`DesktopDeletedChats`), а СООБЩЕНИЯ возвращались в базу: их видно в поиске
// и в галерее, и они всплывали целиком, стоило собеседнику написать строку —
// потому что одна новая строка снимает метку, как и задумано.
//
// ЧТО ИСПРАВЛЕНО. Приёмник уже умеет отказывать — по отсечке очистки
// (`_shouldDropConversationEventByClearCutoff`). Удаление теперь ставит эту
// отсечку ПЕРЕД сносом: всё, что было, назад не поедет, а новое — поедет.
//
// И ОБЕ КНОПКИ «УДАЛИТЬ» ДЕЛАЮТ ОДНО И ТО ЖЕ. В карточке собеседника удаление
// было слабее: ни отсечки, ни метки сноса. Две кнопки с одним названием не
// имеют права расходиться в том, что именно они удаляют.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Тело метода от его начала до закрывающей скобки того же отступа.
String _methodBody(String src, String signature) {
  // `expect` здесь звать нельзя: тела считаются при СБОРКЕ набора, вне теста,
  // и matcher падает `OutsideTestException` вместо внятного сообщения.
  final start = src.indexOf(signature);
  if (start < 0) throw StateError('не нашли $signature');
  final end = src.indexOf('\n  }', start);
  if (end <= start) throw StateError('не нашли конец $signature');
  return src.substring(start, end);
}

void main() {
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();
  final contactCard = File(
    'lib/ui/desktop/chat/details/contact_details_view.dart',
  ).readAsStringSync();
  final controller = File('lib/app/app_controller.dart').readAsStringSync();

  group('🔴 удаление из списка чатов', () {
    final body = _methodBody(section, 'Future<void> _deleteChat(String id) async {');

    test('ставит отсечку до сноса', () {
      expect(body.contains('clearChatHistory(convoId: id)'), isTrue);
      expect(
        body.indexOf('clearChatHistory(convoId: id)'),
        lessThan(body.indexOf('deleteChat(convoId: id)')),
        reason: 'отсечка считается по ещё живому чату',
      );
    });

    test('помнит снос, чтобы строка чата не воскресла', () {
      expect(body.contains('DesktopDeletedChats.remember(id)'), isTrue);
    });
  });

  group('🔴 удаление из карточки собеседника делает ТО ЖЕ САМОЕ', () {
    final body = _methodBody(contactCard, 'Future<void> _deleteChat() async {');

    test('отсечка', () {
      expect(body.contains('clearChatHistory(convoId: _convoId)'), isTrue);
      expect(
        body.indexOf('clearChatHistory(convoId: _convoId)'),
        lessThan(body.indexOf('deleteChat(convoId: _convoId)')),
      );
    });

    test('метка сноса', () {
      expect(body.contains('DesktopDeletedChats.remember(_convoId)'), isTrue);
    });
  });

  test('🔴 приёмник истории от телефона ОТКАЗЫВАЕТ по этой отсечке', () {
    // Без этой ветки вся правка выше бессмысленна: отсечка ставится, а чанк
    // всё равно кладёт события обратно.
    final start = controller.indexOf('Future<void> _applyPeerHistoryChunk({');
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 6000);
    expect(
      body.contains('_shouldDropConversationEventByClearCutoff('),
      isTrue,
    );
  });

  test('отсечка переживает перезапуск — она в настройках, а не в памяти', () {
    final start = controller.indexOf(
      'Future<void> _applyConversationHistoryClear({',
    );
    expect(start, greaterThan(0));
    final body = controller.substring(start, start + 1400);
    expect(body.contains('prefs.setInt(key, effectiveCutoffCreatedAtMs)'), isTrue);
    // И берётся БОЛЬШАЯ из двух: повторная очистка не имеет права сдвинуть
    // отсечку назад и вернуть то, что уже вычистили.
    expect(body.contains('> existingCutoffCreatedAtMs'), isTrue);
  });
}
