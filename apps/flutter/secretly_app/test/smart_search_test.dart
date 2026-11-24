// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Общий поиск главного экрана: раскладка, транслит, инициалы, опечатка,
// порядок и подсветка.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/search/smart_search.dart';

const _now = 1763600000000;

SmartSearchItem _chat(
  String id,
  String title, {
  SmartSearchKind kind = SmartSearchKind.chat,
  String? handle,
  int ageDays = 30,
  int unread = 0,
  bool pinned = false,
}) => SmartSearchItem(
  id: id,
  kind: kind,
  title: title,
  handle: handle,
  lastActivityMs: _now - ageDays * 86400000,
  unread: unread,
  pinned: pinned,
);

final _items = <SmartSearchItem>[
  _chat('mira', 'Мира Орлова'),
  _chat('alexey', 'Алексей Ким', handle: 'alexkim'),
  _chat('mama', 'Мама'),
  _chat('oleg', 'Олег Миронов'),
  _chat('ivan', 'Ivan Petrov'),
  _chat('design', 'Дизайн-ревью', kind: SmartSearchKind.room),
  _chat('family', 'Семья', kind: SmartSearchKind.room),
  _chat('fedor', 'Фёдор', kind: SmartSearchKind.contact),
  _chat('sergey', 'Сергей', kind: SmartSearchKind.contact),
  _chat('cafe', 'Café Crème', kind: SmartSearchKind.room),
];

List<String> _ids(String q, {SmartSearchKind? boost}) => SmartSearch.run(
  _items,
  q,
  boostKind: boost,
  nowMs: _now,
).map((h) => h.item.id).toList();

void main() {
  test('пустой запрос — пусто', () {
    expect(_ids(''), isEmpty);
    expect(_ids('   '), isEmpty);
  });

  test('начало названия и начала слов в любом порядке', () {
    expect(_ids('мир').first, 'mira');
    expect(_ids('орл мир').first, 'mira');
    expect(_ids('ким'), contains('alexey'));
  });

  test('инициалы', () {
    expect(_ids('мо').first, 'mira');
    expect(_ids('ак'), contains('alexey'));
  });

  test('забытая раскладка', () {
    // «vfvf» на латинской раскладке — это «мама».
    expect(_ids('vfvf').first, 'mama');
    // «шмфт» на русской — это «ivan».
    expect(_ids('шмфт').first, 'ivan');
  });

  test('транслит в обе стороны', () {
    expect(_ids('ivan').first, 'ivan');
    expect(_ids('иван').first, 'ivan');
    expect(_ids('mira'), contains('mira'));
    expect(_ids('sergey'), contains('sergey'));
  });

  test('ё/е, й/и и акценты', () {
    expect(_ids('федор'), contains('fedor'));
    expect(_ids('сирган'), isNot(contains('sergey'))); // две ошибки — мимо
    expect(_ids('сергеи'), contains('sergey'));
    expect(_ids('cafe creme').first, 'cafe');
  });

  test('одна опечатка в слове от 4 букв', () {
    expect(_ids('олек'), contains('oleg'));
    expect(_ids('мамф'), contains('mama'));
    // Короткое слово с опечаткой не ищется — слишком много мусора.
    expect(_ids('мф'), isNot(contains('mama')));
  });

  test('ник', () {
    expect(_ids('@alexkim').first, 'alexey');
    expect(_ids('alexk').first, 'alexey');
  });

  test('живость при равном совпадении: непрочитанное и свежее выше', () {
    final items = [
      _chat('old', 'Анна Старая', ageDays: 200),
      _chat('fresh', 'Анна Новая', ageDays: 0, unread: 3),
    ];
    final hits = SmartSearch.run(items, 'анна', nowMs: _now);
    expect(hits.map((h) => h.item.id).toList(), ['fresh', 'old']);
  });

  test('качество совпадения важнее живости', () {
    final items = [
      _chat('sub', 'Наша мама', ageDays: 0, unread: 9, pinned: true),
      _chat('exact', 'Мама', ageDays: 400),
    ];
    final hits = SmartSearch.run(items, 'мама', nowMs: _now);
    expect(hits.first.item.id, 'exact');
  });

  test('недавно открытое из поиска поднимается', () {
    final items = [_chat('a', 'Анна А'), _chat('b', 'Анна Б')];
    final hits = SmartSearch.run(
      items,
      'анна',
      recentIds: const ['b'],
      nowMs: _now,
    );
    expect(hits.first.item.id, 'b');
  });

  test('раздел, откуда начат поиск, выше при равенстве', () {
    final items = [
      _chat('c', 'Работа', kind: SmartSearchKind.chat),
      _chat('r', 'Работа', kind: SmartSearchKind.room),
    ];
    final hits = SmartSearch.run(
      items,
      'работа',
      boostKind: SmartSearchKind.room,
      nowMs: _now,
    );
    expect(hits.first.item.id, 'r');
  });

  test('подсветка — в исходном названии', () {
    final hit = SmartSearch.run(_items, 'орл', nowMs: _now).first;
    expect(hit.item.id, 'mira');
    expect('Мира Орлова'.substring(hit.highlightStart!, hit.highlightEnd!),
        'Орл');
    // Через раскладку подсвечивать нечего.
    final viaLayout = SmartSearch.run(_items, 'vfvf', nowMs: _now).first;
    expect(viaLayout.highlightStart, isNull);
  });

  test('нормализация', () {
    expect(SmartSearch.normalize('  @Ёлка—Палка!! '), 'елка палка');
    expect(SmartSearch.normalize('Straße'), 'strasse');
    expect(SmartSearch.swapLayout('ghbdtn'), 'привет');
    expect(SmartSearch.swapLayout('руддщ'), 'hello');
    expect(SmartSearch.translitToLatin('щука'), 'schuka');
  });
}
