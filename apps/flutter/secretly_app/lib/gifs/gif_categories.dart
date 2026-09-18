// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Категории гифок — эмодзи-иконки над поиском для быстрого выбора.
///
/// 🔴 ПОЧЕМУ ЗАПРОС ВСЕГДА АНГЛИЙСКИЙ. Иконка не переводится: человек нажимает
/// 😂, а не слово. Значит и спрашивать надо там, где корпус богаче — в
/// английском индексе GIPHY. Русская подпись нужна только для доступности
/// (экранный диктор) и подсказки, но не для запроса.
library;

/// Одна категория: иконка, запрос к GIPHY и подписи.
class GifCategory {
  const GifCategory({
    required this.emoji,
    required this.query,
    required this.ru,
    required this.en,
  });

  /// Иконка — эмодзи, как просил владелец.
  final String emoji;

  /// Запрос к GIPHY. Английский намеренно (см. заголовок файла).
  final String query;

  final String ru;
  final String en;

  String label(bool isRu) => isRu ? ru : en;
}

/// Порядок намеренный: первым идёт то, что нажимают чаще всего.
///
/// Список короткий сознательно. Полоса на двадцать иконок превращается в
/// бесконечную прокрутку, в которой человек ищет иконку дольше, чем набрал бы
/// слово, — и смысл быстрого выбора теряется.
const List<GifCategory> kGifCategories = <GifCategory>[
  GifCategory(emoji: '😂', query: 'laugh', ru: 'Смех', en: 'Laugh'),
  GifCategory(emoji: '❤️', query: 'love', ru: 'Любовь', en: 'Love'),
  GifCategory(emoji: '👍', query: 'thumbs up', ru: 'Одобрение', en: 'Approval'),
  GifCategory(emoji: '👋', query: 'hello', ru: 'Привет', en: 'Hello'),
  GifCategory(emoji: '🤗', query: 'hug', ru: 'Обнимашки', en: 'Hug'),
  GifCategory(emoji: '😭', query: 'crying', ru: 'Слёзы', en: 'Crying'),
  GifCategory(emoji: '😍', query: 'excited', ru: 'Восторг', en: 'Excited'),
  GifCategory(emoji: '🤔', query: 'thinking', ru: 'Раздумья', en: 'Thinking'),
  GifCategory(emoji: '😴', query: 'sleepy', ru: 'Сон', en: 'Sleepy'),
  GifCategory(emoji: '😡', query: 'angry', ru: 'Злость', en: 'Angry'),
  GifCategory(emoji: '🤯', query: 'shocked', ru: 'Шок', en: 'Shocked'),
  GifCategory(emoji: '💃', query: 'dance', ru: 'Танцы', en: 'Dance'),
  GifCategory(emoji: '🎉', query: 'party', ru: 'Праздник', en: 'Party'),
  GifCategory(emoji: '🐱', query: 'cat', ru: 'Кошки', en: 'Cats'),
  GifCategory(emoji: '🐶', query: 'dog', ru: 'Собаки', en: 'Dogs'),
  GifCategory(emoji: '🔥', query: 'fire', ru: 'Огонь', en: 'Fire'),
  GifCategory(emoji: '🍕', query: 'food', ru: 'Еда', en: 'Food'),
  GifCategory(emoji: '⚽', query: 'sport', ru: 'Спорт', en: 'Sport'),
];
