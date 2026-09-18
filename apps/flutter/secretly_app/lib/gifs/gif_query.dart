// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Разбор поискового запроса к GIPHY.
///
/// 🔴 ЗАЧЕМ ОТДЕЛЬНЫМ ФАЙЛОМ. Жалоба владельца: «поиск работает только на
/// английском». Причина не в интерфейсе. GIPHY индексирует теги почти целиком
/// по-английски, а мы отправляли слово как есть и без указания языка. Русский
/// запрос уходил в пустоту, и человек видел «GIF не найдены» — то есть ложь:
/// гифки есть, спросили не на том языке.
///
/// Здесь живёт РЕШЕНИЕ (что и в каком порядке спрашивать), а не ввод-вывод.
/// Именно решение дороже всего ошибиться, и проверять надо его — не запрос.
library;

/// Одна попытка запроса: слово плюс язык, на котором его спрашиваем.
///
/// Язык привязан к попытке, а не к запросу человека: русское слово мы спросим с
/// `lang: 'ru'`, а его английский перевод — с `lang: 'en'`. Один язык на весь
/// план был бы ошибкой — перевод спросили бы по-русски.
class GifQueryAttempt {
  const GifQueryAttempt({required this.term, required this.lang});

  final String term;
  final String lang;

  @override
  bool operator ==(Object other) =>
      other is GifQueryAttempt && other.term == term && other.lang == lang;

  @override
  int get hashCode => Object.hash(term, lang);

  @override
  String toString() => 'GifQueryAttempt($term, $lang)';
}

/// Есть ли в строке кириллица.
bool gifQueryLooksCyrillic(String raw) {
  for (final code in raw.codeUnits) {
    // Основной кириллический блок плюс «ё»/«Ё».
    if (code >= 0x0400 && code <= 0x04FF) return true;
  }
  return false;
}

/// Приводит запрос к виду, по которому ищем в словаре.
String _normalize(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ');

/// План попыток для запроса человека.
///
/// Пустой запрос — пустой план: это «популярное», у него нет слова.
///
/// 🔴 ПОЧЕМУ АНГЛИЙСКИЙ ПЕРЕВОД ИДЁТ ПЕРВЫМ. Английский корпус GIPHY на порядки
/// богаче русского. Спросить сначала по-русски значит с большой вероятностью
/// получить пустоту и сделать второй запрос — то есть замедлить поиск ради
/// результата, который почти всегда хуже. Русское слово остаётся вторым шансом:
/// если английский ничего не дал, спрашиваем как написал человек.
///
/// Слов вне словаря это не касается: для них первым идёт сам запрос (вдруг тег
/// есть), а вторым — латиница по звучанию, потому что часть тегов GIPHY
/// записана транслитом.
///
/// Длина плана не больше двух: третья попытка стоит человеку ещё одного
/// ожидания, а шансов добавляет мало.
List<GifQueryAttempt> gifQueryPlan(String raw) {
  final q = _normalize(raw);
  if (q.isEmpty) return const <GifQueryAttempt>[];

  if (!gifQueryLooksCyrillic(q)) {
    return <GifQueryAttempt>[GifQueryAttempt(term: q, lang: 'en')];
  }

  final attempts = <GifQueryAttempt>[];
  void add(String term, String lang) {
    final t = term.trim();
    if (t.isEmpty) return;
    final attempt = GifQueryAttempt(term: t, lang: lang);
    if (attempts.contains(attempt)) return;
    if (attempts.length >= 2) return;
    attempts.add(attempt);
  }

  final english = gifEnglishTermFor(q);
  if (english != null) {
    add(english, 'en');
    add(q, 'ru');
  } else {
    add(q, 'ru');
    add(gifTransliterate(q), 'en');
  }
  return List<GifQueryAttempt>.unmodifiable(attempts);
}

/// Русское слово → английский тег GIPHY, или `null`, если не знаем.
///
/// Словарь намеренно короткий и рукописный: это самые частые поводы искать
/// гифку, а не попытка перевести язык. Чего здесь нет — доберёт транслитерация.
String? gifEnglishTermFor(String raw) {
  final q = _normalize(raw);
  if (q.isEmpty) return null;

  // Целая фраза важнее отдельных слов: «день рождения» это не «день».
  final whole = _gifRuToEn[q];
  if (whole != null) return whole;

  final words = q.split(' ').where((w) => w.isNotEmpty).toList();

  // Точное совпадение слова.
  for (final word in words) {
    final hit = _gifRuToEn[word];
    if (hit != null) return hit;
  }

  // Основа слова: «любовь», «люблю», «любимая» — все про love. Русский склоняет
  // и спрягает, а держать все формы в словаре бессмысленно.
  for (final word in words) {
    for (final entry in _gifRuStems.entries) {
      if (word.startsWith(entry.key)) return entry.value;
    }
  }
  return null;
}

/// Кириллица → латиница по звучанию.
///
/// Нужна не для красоты: часть тегов GIPHY записана транслитом («privet»,
/// «kot»), и для слова вне словаря это единственный оставшийся шанс.
String gifTransliterate(String raw) {
  final q = _normalize(raw);
  final out = StringBuffer();
  for (final ch in q.split('')) {
    out.write(_translit[ch] ?? ch);
  }
  return out.toString().trim();
}

const Map<String, String> _gifRuToEn = <String, String>{
  // Приветствия и вежливость
  'привет': 'hello',
  'здравствуй': 'hello',
  'здравствуйте': 'hello',
  'пока': 'bye',
  'до свидания': 'goodbye',
  'спасибо': 'thank you',
  'благодарю': 'thank you',
  'пожалуйста': 'please',
  'извини': 'sorry',
  'извините': 'sorry',
  'прости': 'sorry',
  'простите': 'sorry',
  'доброе утро': 'good morning',
  'добрый вечер': 'good evening',
  'добрый день': 'good day',
  'спокойной ночи': 'good night',
  'с днем рождения': 'happy birthday',
  'день рождения': 'birthday',
  'новый год': 'new year',
  'рождество': 'christmas',
  'с новым годом': 'happy new year',
  'поздравляю': 'congratulations',

  // Согласие и отказ
  'да': 'yes',
  'нет': 'no',
  'ок': 'ok',
  'окей': 'ok',
  'ладно': 'ok',
  'конечно': 'of course',
  'не знаю': 'shrug',
  'без понятия': 'shrug',

  // Чувства
  'смех': 'laugh',
  'смешно': 'funny',
  'ржу': 'laughing',
  'хаха': 'laughing',
  'грусть': 'sad',
  'грустно': 'sad',
  'плачу': 'crying',
  'слезы': 'crying',
  'радость': 'happy',
  'счастье': 'happy',
  'восторг': 'excited',
  'вау': 'wow',
  'шок': 'shocked',
  'ужас': 'horror',
  'страшно': 'scared',
  'злость': 'angry',
  'бешу': 'angry',
  'обида': 'upset',
  'скучно': 'bored',
  'устал': 'tired',
  'сон': 'sleep',
  'спать': 'sleepy',
  'стыдно': 'awkward',
  'неловко': 'awkward',
  'сарказм': 'sarcastic',
  'думаю': 'thinking',
  'сомневаюсь': 'suspicious',
  'закатываю глаза': 'eye roll',
  'рукалицо': 'facepalm',

  // Действия
  'обнимашки': 'hug',
  'поцелуй': 'kiss',
  'танец': 'dance',
  'танцы': 'dance',
  'танцую': 'dancing',
  'аплодисменты': 'applause',
  'браво': 'applause',
  'ура': 'yay',
  'лайк': 'thumbs up',
  'палец вверх': 'thumbs up',
  'жду': 'waiting',
  'бегу': 'running',
  'работаю': 'working',
  'учусь': 'studying',
  'иду': 'walking',

  // Предметы и темы
  'кот': 'cat',
  'кошка': 'cat',
  'котик': 'kitten',
  'собака': 'dog',
  'пес': 'dog',
  'собачка': 'puppy',
  'сердце': 'heart',
  'цветы': 'flowers',
  'огонь': 'fire',
  'деньги': 'money',
  'работа': 'work',
  'еда': 'food',
  'пицца': 'pizza',
  'кофе': 'coffee',
  'чай': 'tea',
  'пиво': 'beer',
  'торт': 'cake',
  'спорт': 'sport',
  'футбол': 'football',
  'игры': 'gaming',
  'кино': 'movie',
  'музыка': 'music',
  'машина': 'car',
  'дождь': 'rain',
  'снег': 'snow',
  'зима': 'winter',
  'лето': 'summer',
  'море': 'sea',
  'праздник': 'party',
  'вечеринка': 'party',
  'победа': 'winning',
  'провал': 'fail',
  'фейл': 'fail',
  'мем': 'meme',
  'аниме': 'anime',
  'мультик': 'cartoon',
  'друзья': 'friends',
  'семья': 'family',
  'ребенок': 'baby',
};

/// Основы слов: проверяются через `startsWith`, поэтому порядок здесь важен —
/// более длинная основа должна стоять раньше более короткой с тем же началом.
const Map<String, String> _gifRuStems = <String, String>{
  'поздравл': 'congratulations',
  'обнима': 'hug',
  'обним': 'hug',
  'целу': 'kiss',
  'танц': 'dance',
  'смеш': 'funny',
  'смея': 'laughing',
  'смех': 'laugh',
  'груст': 'sad',
  'плак': 'crying',
  'плач': 'crying',
  'любл': 'love',
  'люб': 'love',
  'серд': 'heart',
  'зло': 'angry',
  'уста': 'tired',
  'спать': 'sleepy',
  'сон': 'sleep',
  'дума': 'thinking',
  'работ': 'work',
  'денег': 'money',
  'деньг': 'money',
  'котен': 'kitten',
  'кот': 'cat',
  'кош': 'cat',
  'собак': 'dog',
  'счаст': 'happy',
  'радост': 'happy',
  'удив': 'surprised',
  'испуг': 'scared',
  'страх': 'scared',
  'привет': 'hello',
  'спасиб': 'thank you',
  'извин': 'sorry',
  'прост': 'sorry',
  'празд': 'party',
  'побед': 'winning',
};

const Map<String, String> _translit = <String, String>{
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ж': 'zh',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'kh',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'sch',
  'ъ': '',
  'ы': 'y',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};
