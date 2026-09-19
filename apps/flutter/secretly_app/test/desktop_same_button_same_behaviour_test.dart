// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ОДНА КНОПКА — ОДНО ПОВЕДЕНИЕ, ГДЕ БЫ ОНА НИ СТОЯЛА.
//
// Указание владельца 16.09.2026: «проверь остальное и почини что найдёшь».
//
// В окне нашлось три места, где кнопка с ОДНОЙ подписью делала разное в
// зависимости от того, откуда её нажали. Это худший вид расхождения: человек
// учится на одном месте, применяет в другом и получает не то, чему научился, —
// причём молча, без единого признака, что возможностей было две.
//
//   • «Переслать» и «Сохранить» в меню сообщения показывались только у текста,
//     хотя на телефоне пересылаются и снимки, и наклейки (починено раньше).
//   • «Очистить историю» в меню СПИСКА предлагала стереть переписку и у
//     собеседника, а та же кнопка в КАРТОЧКЕ собеседника — нет.
//
// Диалог подтверждения теперь общий, и оба места зовут его.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();
  final card = File(
    'lib/ui/desktop/chat/details/contact_details_view.dart',
  ).readAsStringSync();
  final dialog = File(
    'lib/ui/desktop/chat/clear_history_dialog.dart',
  ).readAsStringSync();

  test('🔴 диалог ОБЩИЙ, а не свой у каждого места', () {
    expect(dialog.contains('Future<({bool alsoForPeer})?> confirmClearWithPeer('), isTrue);
    // Приватной копии в разделе чатов больше нет.
    expect(section.contains('_confirmWithPeerClear('), isFalse);
    expect(section.contains('confirmClearWithPeer('), isTrue);
    expect(card.contains('confirmClearWithPeer('), isTrue);
  });

  test('🔴 «очистить у собеседника» доступно И из карточки', () {
    final i = card.indexOf('Future<void> _clearHistory()');
    expect(i, greaterThan(0));
    final body = card.substring(i, i + 1800);
    expect(body.contains('clearChatHistoryEverywhere('), isTrue);
    expect(body.contains('desktopChatsHistoryClearedBoth'), isTrue);
  });

  test('🔴 себе самому чистить «у собеседника» не предлагают', () {
    final i = card.indexOf('Future<void> _clearHistory()');
    final body = card.substring(i, i + 1800);
    expect(body.contains('peer != myPid'), isTrue);
  });

  test('в комнате галочки нет — чистить «у собеседника» некого', () {
    final room = File(
      'lib/ui/desktop/chat/details/room_details_view.dart',
    ).readAsStringSync();
    expect(room.contains('clearChatHistoryEverywhere('), isFalse);
  });

  test('предупреждение о необратимости на месте', () {
    expect(dialog.contains('l10n.desktopClearForPeerHint'), isTrue);
    final ru = File('lib/l10n/app_ru.arb').readAsStringSync();
    expect(ru.contains('Отменить это нельзя'), isTrue);
    expect(
      ru.contains('и на его устройстве, и на всех'),
      isTrue,
      reason: 'человек должен понимать, что стирает не только у себя',
    );
  });
}
