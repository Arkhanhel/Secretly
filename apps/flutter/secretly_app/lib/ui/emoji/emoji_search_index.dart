// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Слова для поиска эмодзи.
///
/// 🔴 ЗАЧЕМ ЭТОТ ФАЙЛ. Поиск эмодзи в подборщике сравнивал набранное с
/// ШЕСТНАДЦАТЕРИЧНЫМ кодом символа: у 😀 это `1f600`. То есть найти эмодзи можно
/// было, только набрав `1f600` или вставив сам символ — все 881 не искались НИ НА
/// ОДНОМ языке. Дефект выглядел языковым («по-русски не находит»), поэтому и
/// выжил: по-английски тоже не находило, и это списывалось на «слабый поиск», а
/// не на «поиска нет».
///
/// Слова здесь — ОСНОВЫ, а не полные названия: сравнение двустороннее по началу
/// строки, поэтому «улыб» находится и по «у», и по «улыбка», и по «улыбаться».
/// Держать все формы русского слова было бы бессмысленно.
///
/// Покрытие двухслойное. Частые символы имеют свои слова; всем остальным
/// достаются слова КАТЕГОРИИ, поэтому «животное» или «символ» находят и то, для
/// чего отдельных слов не написано. Без второго слоя дефект остался бы для
/// большей части каталога.
library;

import 'noto_emoji_catalog.dart';

/// Символ без тона кожи и без вариационного селектора.
///
/// 🔴 БЕЗ ЭТОГО ТОНЫ НЕ ИСКАЛИСЬ БЫ. В каталоге 👍 лежит шестью записями —
/// базовой и пятью с тоном. Писать слова каждой значило бы утроить словарь;
/// вместо этого тон снимается перед поиском, и 👍🏽 наследует слова 👍.
String emojiSearchBase(String emoji) {
  final out = StringBuffer();
  for (final rune in emoji.runes) {
    // Тона кожи: U+1F3FB..U+1F3FF.
    if (rune >= 0x1F3FB && rune <= 0x1F3FF) continue;
    if (rune == 0xFE0F) continue;
    out.writeCharCode(rune);
  }
  final result = out.toString();
  return result.isEmpty ? emoji : result;
}

/// Приводит набранное к виду, в котором сравниваем.
String normalizeEmojiQuery(String raw) =>
    raw.trim().toLowerCase().replaceAll('ё', 'е');

/// Подходит ли символ под запрос.
///
/// [query] уже должен быть пропущен через [normalizeEmojiQuery] — иначе на
/// каждый символ каталога пришлась бы своя нормализация запроса.
bool emojiMatchesQuery(String emoji, String query) {
  if (query.isEmpty) return true;
  if (emoji == query) return true;
  final base = emojiSearchBase(emoji);
  if (base == query) return true;

  bool hits(List<String> words) {
    for (final word in words) {
      // Набранное как начало слова: «улыб» → «улыбка».
      if (word.startsWith(query)) return true;
      // Слово как начало набранного: «улыбаться» → «улыб». Русский склоняет и
      // спрягает, а держать все формы в словаре бессмысленно.
      //
      // 🔴 ТОЛЬКО ДЛЯ ОСНОВ ОТ ТРЁХ БУКВ. «ок» и «да» — настоящие слова, но в
      // эту сторону они превратили бы «окно» и «давай» в 👌 и ✅.
      if (word.length >= 3 && query.startsWith(word)) return true;
    }
    return false;
  }

  final own = kEmojiSearchWords[base];
  if (own != null && hits(own)) return true;

  final slug = kNotoCategories[emoji] ?? kNotoCategories[base];
  if (slug != null) {
    final shared = kEmojiCategorySearchWords[slug];
    if (shared != null && hits(shared)) return true;
  }
  return false;
}

/// Отбирает символы под запрос, сохраняя исходный порядок каталога.
List<String> filterEmojiByQuery(Iterable<String> emoji, String rawQuery) {
  final query = normalizeEmojiQuery(rawQuery);
  if (query.isEmpty) return emoji.toList(growable: false);
  return emoji
      .where((e) => emojiMatchesQuery(e, query))
      .toList(growable: false);
}

/// Слова конкретных символов. Ключ — символ без тона и без селектора.
const Map<String, List<String>> kEmojiSearchWords =
    <String, List<String>>{
  '😀': <String>['улыб', 'смайл', 'smile', 'happy', 'рад'],
  '😃': <String>['улыб', 'рот', 'smile', 'grin'],
  '😄': <String>['улыб', 'глаз', 'смеш', 'smile', 'laugh'],
  '😁': <String>['улыб', 'зуб', 'grin', 'beam'],
  '😆': <String>['смех', 'смеш', 'жмур', 'laugh', 'squint'],
  '😅': <String>['смех', 'смеш', 'пот', 'laugh', 'sweat', 'обошл'],
  '😂': <String>['смех', 'смеш', 'слез', 'ржу', 'laugh', 'lol', 'tears'],
  '🤣': <String>['ржу', 'смех', 'смеш', 'катаюсь', 'rofl', 'laugh'],
  '😭': <String>['плач', 'плак', 'рыда', 'слез', 'cry', 'sob'],
  '😉': <String>['подмиг', 'wink'],
  '😗': <String>['поцелуй', 'kiss'],
  '😙': <String>['поцелуй', 'kiss', 'улыб'],
  '😚': <String>['поцелуй', 'kiss', 'закрыт'],
  '😘': <String>['поцелуй', 'целу', 'kiss', 'love'],
  '🥰': <String>['любов', 'влюбл', 'сердц', 'love', 'heart', 'смайл'],
  '😍': <String>['влюбл', 'любов', 'восторг', 'love', 'heart', 'eyes'],
  '🤩': <String>['восторг', 'звезд', 'star', 'wow', 'excited'],
  '🥳': <String>['праздн', 'вечерин', 'party', 'birthday', 'день рожден'],
  '🙃': <String>['вверх', 'ноги', 'наоборот', 'upside'],
  '🙂': <String>['улыб', 'слег', 'smile', 'slight'],
  '🥲': <String>['слез', 'улыб', 'tear', 'смех'],
  '🥹': <String>['слез', 'держ', 'tear', 'emotional'],
  '😊': <String>['улыб', 'мил', 'smile', 'blush', 'румян'],
  '☺': <String>['улыб', 'smile', 'relaxed'],
  '😌': <String>['спокой', 'облегч', 'relief', 'calm'],
  '😏': <String>['ухмыл', 'smirk', 'хитр'],
  '🤤': <String>['слюн', 'drool', 'вкусн'],
  '😋': <String>['вкусн', 'язык', 'yum', 'tasty'],
  '😛': <String>['язык', 'tongue', 'дразн'],
  '😝': <String>['язык', 'дразн', 'tongue', 'жмур'],
  '😜': <String>['язык', 'подмиг', 'дразн', 'tongue', 'wink'],
  '🤪': <String>['сумасшед', 'безум', 'crazy', 'zany', 'дурач'],
  '😔': <String>['груст', 'печал', 'sad', 'pensive'],
  '🥺': <String>['умол', 'прош', 'щеноч', 'pleading', 'puppy'],
  '😬': <String>['неловк', 'зуб', 'grimace', 'awkward'],
  '😑': <String>['безразл', 'expressionless', 'пуст'],
  '😐': <String>['нейтрал', 'neutral', 'ровн'],
  '😶': <String>['молч', 'без рта', 'speechless', 'silent'],
  '🤐': <String>['молч', 'рот', 'zipper', 'замок'],
  '🫡': <String>['салют', 'честь', 'salute'],
  '🤔': <String>['подум', 'дума', 'размышл', 'think', 'hmm'],
  '🤫': <String>['тише', 'тихо', 'shush', 'quiet', 'секрет'],
  '🫢': <String>['ахнул', 'рука', 'рот', 'gasp', 'испуг'],
  '🤭': <String>['хих', 'смущ', 'giggle', 'рука', 'рот'],
  '🥱': <String>['зева', 'сон', 'устал', 'yawn', 'tired'],
  '🤗': <String>['обним', 'объят', 'hug', 'обнимашк'],
  '🫣': <String>['подгляд', 'стыдн', 'peek', 'страшн'],
  '😱': <String>['ужас', 'крик', 'страх', 'scream', 'fear', 'шок'],
  '🤨': <String>['бров', 'сомнен', 'skeptic', 'eyebrow'],
  '🧐': <String>['монокл', 'изуча', 'monocle', 'inspect'],
  '😒': <String>['недовол', 'unamused', 'презр'],
  '🙄': <String>['глаз', 'закат', 'eye roll', 'раздраж'],
  '😤': <String>['пар', 'возмущ', 'triumph', 'huff'],
  '😠': <String>['злой', 'зло', 'сердит', 'angry', 'mad'],
  '😡': <String>['зло', 'ярост', 'красн', 'angry', 'rage', 'беси'],
  '🤬': <String>['ругат', 'мат', 'swear', 'cursing', 'зло'],
  '😞': <String>['разочаров', 'груст', 'disappoint', 'sad'],
  '😓': <String>['пот', 'устал', 'downcast', 'sweat'],
  '😟': <String>['беспоко', 'worried', 'волну'],
  '😥': <String>['облегч', 'груст', 'sad', 'relieved'],
  '😢': <String>['плач', 'плак', 'слез', 'груст', 'cry', 'sad'],
  '☹': <String>['груст', 'frown', 'sad'],
  '🙁': <String>['груст', 'frown', 'недовол'],
  '🫤': <String>['неопред', 'diagonal', 'сомнен'],
  '😕': <String>['растер', 'confused', 'озадач'],
  '😰': <String>['страх', 'пот', 'anxious', 'нервн'],
  '😨': <String>['испуг', 'страх', 'fear', 'боюс'],
  '😧': <String>['мучен', 'anguished', 'ужас'],
  '😦': <String>['охнул', 'frown', 'рот'],
  '😮': <String>['охнул', 'удивл', 'рот', 'surprise', 'wow'],
  '😯': <String>['удивл', 'hushed', 'охнул'],
  '😲': <String>['изумл', 'шок', 'astonished', 'wow'],
  '😳': <String>['смущ', 'красн', 'flushed', 'стыд'],
  '🤯': <String>['взрыв', 'мозг', 'шок', 'mind blown', 'офиг'],
  '😖': <String>['мучен', 'confounded', 'терп'],
  '😣': <String>['терп', 'persever', 'мучен'],
  '😩': <String>['измуч', 'устал', 'weary', 'стон'],
  '😫': <String>['устал', 'стон', 'tired', 'измот'],
  '😵': <String>['голов', 'крест', 'dizzy', 'плох'],
  '🥴': <String>['пьян', 'woozy', 'плыв'],
  '🥵': <String>['жар', 'пот', 'hot', 'жарко'],
  '🥶': <String>['холод', 'мерзн', 'cold', 'замерз'],
  '🤢': <String>['тошн', 'nauseated', 'против'],
  '🤮': <String>['рвот', 'тошн', 'vomit', 'блев'],
  '😴': <String>['спит', 'сон', 'sleep', 'храп'],
  '😪': <String>['сон', 'сплю', 'sleepy', 'устал'],
  '🤧': <String>['чих', 'sneeze', 'болен'],
  '🤒': <String>['болен', 'температ', 'sick', 'thermometer'],
  '🤕': <String>['ранен', 'бинт', 'injured', 'bandage'],
  '😷': <String>['маск', 'болен', 'mask', 'sick'],
  '🤥': <String>['вран', 'нос', 'lying', 'pinocchio'],
  '😇': <String>['ангел', 'нимб', 'angel', 'halo'],
  '🤠': <String>['ковбой', 'cowboy', 'шляп'],
  '🤑': <String>['деньг', 'money', 'богат'],
  '🤓': <String>['ботан', 'очк', 'nerd', 'geek'],
  '😎': <String>['крут', 'очк', 'cool', 'sunglasses'],
  '🥸': <String>['маскир', 'усы', 'disguise'],
  '🤡': <String>['клоун', 'clown'],
  '💩': <String>['кака', 'говн', 'poop', 'shit'],
  '😈': <String>['черт', 'дьявол', 'devil', 'хитр'],
  '👿': <String>['черт', 'зло', 'imp', 'devil'],
  '👻': <String>['призрак', 'привид', 'ghost'],
  '💀': <String>['череп', 'смерт', 'skull', 'death'],
  '🤖': <String>['робот', 'robot', 'бот'],
  '👽': <String>['инопланет', 'alien', 'нло'],
  '👾': <String>['монстр', 'игр', 'alien', 'monster'],
  '👍': <String>['лайк', 'палец', 'вверх', 'нрав', 'thumbs up', 'like', 'одобр', 'класс'],
  '👎': <String>['дизлайк', 'палец', 'вниз', 'thumbs down', 'dislike', 'плох'],
  '👏': <String>['хлоп', 'аплодис', 'апплодис', 'clap', 'браво'],
  '🙌': <String>['ура', 'рук', 'вверх', 'raised hands', 'hooray'],
  '👐': <String>['открыт', 'рук', 'open hands'],
  '🤲': <String>['ладон', 'прос', 'palms'],
  '🙏': <String>['молюс', 'спасиб', 'пожалуйст', 'pray', 'please', 'thanks'],
  '🤝': <String>['рукопожат', 'сделк', 'handshake', 'договор'],
  '✌': <String>['мир', 'виктор', 'victory', 'peace'],
  '🤞': <String>['удач', 'скрещ', 'fingers crossed', 'luck'],
  '🤟': <String>['любл', 'love you', 'рок'],
  '🤘': <String>['рок', 'рог', 'rock', 'metal'],
  '👌': <String>['ок', 'отличн', 'ok', 'perfect'],
  '🤌': <String>['щипот', 'итал', 'pinched', 'жест'],
  '🤏': <String>['чуть', 'мал', 'pinch', 'немног'],
  '👈': <String>['влев', 'указ', 'point left'],
  '👉': <String>['вправ', 'указ', 'point right'],
  '👆': <String>['вверх', 'указ', 'point up'],
  '👇': <String>['вниз', 'указ', 'point down'],
  '☝': <String>['вверх', 'один', 'index up'],
  '✋': <String>['стоп', 'ладон', 'рук', 'stop', 'hand'],
  '🖐': <String>['ладон', 'пальц', 'hand'],
  '🖖': <String>['вулкан', 'vulcan', 'spock'],
  '👋': <String>['привет', 'пока', 'маш', 'wave', 'hello', 'bye'],
  '🤙': <String>['звони', 'call me', 'шак'],
  '💪': <String>['сил', 'мышц', 'муск', 'strong', 'muscle', 'качал'],
  '✊': <String>['кулак', 'fist', 'сил'],
  '👊': <String>['кулак', 'удар', 'punch', 'fist'],
  '🤛': <String>['кулак', 'влев', 'fist'],
  '🤜': <String>['кулак', 'вправ', 'fist'],
  '🫶': <String>['сердц', 'рук', 'heart hands', 'любов'],
  '🫂': <String>['обним', 'объят', 'люд', 'hug', 'people'],
  '👀': <String>['глаз', 'смотр', 'eyes', 'look'],
  '👁': <String>['глаз', 'eye', 'смотр'],
  '🧠': <String>['мозг', 'brain', 'разум'],
  '🫀': <String>['сердц', 'орган', 'heart', 'анатом'],
  '🦴': <String>['кост', 'bone'],
  '💋': <String>['поцелуй', 'губ', 'kiss', 'lips'],
  '🫦': <String>['губ', 'куса', 'lips', 'bite'],
  '👣': <String>['след', 'ног', 'footprints'],
  '🦵': <String>['ног', 'leg'],
  '🦶': <String>['ступн', 'ног', 'foot'],
  '👃': <String>['нос', 'nose'],
  '👂': <String>['ухо', 'слух', 'слуш', 'ear'],
  '🗣': <String>['говор', 'крич', 'speaking', 'shout'],
  '❤': <String>['сердц', 'любов', 'красн', 'heart', 'love'],
  '🧡': <String>['сердц', 'оранж', 'heart', 'orange'],
  '💛': <String>['сердц', 'желт', 'heart', 'yellow'],
  '💚': <String>['сердц', 'зелен', 'heart', 'green'],
  '💙': <String>['сердц', 'син', 'heart', 'blue'],
  '💜': <String>['сердц', 'фиолет', 'heart', 'purple'],
  '🖤': <String>['сердц', 'черн', 'heart', 'black'],
  '🤍': <String>['сердц', 'бел', 'heart', 'white'],
  '🤎': <String>['сердц', 'коричн', 'heart', 'brown'],
  '💘': <String>['сердц', 'стрел', 'любов', 'cupid'],
  '💝': <String>['сердц', 'подар', 'лент', 'heart gift'],
  '💖': <String>['сердц', 'блест', 'sparkling heart'],
  '💗': <String>['сердц', 'рост', 'growing heart'],
  '💓': <String>['сердц', 'бьет', 'beating heart'],
  '💞': <String>['сердц', 'два', 'revolving hearts'],
  '💕': <String>['сердц', 'два', 'любов', 'two hearts'],
  '💔': <String>['сердц', 'разбит', 'broken heart', 'расстал'],
  '💌': <String>['письм', 'любов', 'love letter'],
  '💯': <String>['сто', '100', 'отличн', 'hundred', 'точн'],
  '💥': <String>['взрыв', 'бум', 'boom', 'explosion'],
  '🔥': <String>['огон', 'пожар', 'fire', 'круто', 'горит'],
  '✨': <String>['блест', 'искр', 'sparkles', 'магия'],
  '⭐': <String>['звезд', 'star'],
  '🌟': <String>['звезд', 'блест', 'glowing star'],
  '⚡': <String>['молни', 'ток', 'lightning', 'энерг'],
  '🎉': <String>['праздн', 'хлопуш', 'party', 'поздрав', 'ура'],
  '🎊': <String>['праздн', 'конфет', 'confetti', 'поздрав'],
  '❗': <String>['восклиц', 'важн', 'exclamation'],
  '❓': <String>['вопрос', 'question'],
  '❌': <String>['крест', 'нет', 'отмен', 'cross', 'no'],
  '✅': <String>['галоч', 'да', 'готов', 'check', 'done'],
  '💬': <String>['сообщ', 'чат', 'речь', 'message', 'chat'],
  '🗯': <String>['крик', 'возмущ', 'anger bubble'],
  '😺': <String>['кот', 'кош', 'улыб', 'cat'],
  '😸': <String>['кот', 'улыб', 'cat grin'],
  '😹': <String>['кот', 'смех', 'слез', 'cat tears'],
  '😻': <String>['кот', 'любов', 'сердц', 'cat love'],
  '😼': <String>['кот', 'ухмыл', 'cat smirk'],
  '😽': <String>['кот', 'поцелуй', 'cat kiss'],
  '🙀': <String>['кот', 'ужас', 'cat scream'],
  '😿': <String>['кот', 'плач', 'cat cry'],
  '😾': <String>['кот', 'зло', 'cat pout'],
  '🐕': <String>['собак', 'пес', 'dog'],
  '🐩': <String>['пудел', 'собак', 'poodle'],
  '🦮': <String>['собак', 'поводыр', 'guide dog'],
  '🐺': <String>['волк', 'wolf'],
  '🦊': <String>['лис', 'fox'],
  '🐻': <String>['медвед', 'bear'],
  '🐼': <String>['панд', 'panda'],
  '🦁': <String>['лев', 'lion'],
  '🐮': <String>['коров', 'cow'],
  '🐸': <String>['жаб', 'лягуш', 'frog'],
  '🙈': <String>['обезь', 'глаз', 'see no evil', 'стыд'],
  '🙉': <String>['обезь', 'уши', 'слыш', 'hear no evil'],
  '🙊': <String>['обезь', 'рот', 'speak no evil', 'молч'],
  '🐤': <String>['птенц', 'цыпл', 'chick'],
  '🐦': <String>['птиц', 'bird'],
  '🦅': <String>['орел', 'eagle'],
  '🦉': <String>['сов', 'owl'],
  '🐧': <String>['пингвин', 'penguin'],
  '🦄': <String>['единорог', 'unicorn'],
  '🐝': <String>['пчел', 'bee'],
  '🦋': <String>['бабоч', 'butterfly'],
  '🐞': <String>['коров', 'жук', 'ladybug'],
  '🐌': <String>['улит', 'snail', 'медлен'],
  '🕷': <String>['паук', 'spider'],
  '🐍': <String>['зме', 'snake'],
  '🐢': <String>['черепах', 'turtle'],
  '🐬': <String>['дельфин', 'dolphin'],
  '🐳': <String>['кит', 'whale'],
  '🐟': <String>['рыб', 'fish'],
  '🦈': <String>['акул', 'shark'],
  '🐙': <String>['спрут', 'октоп', 'octopus'],
  '🐾': <String>['лап', 'след', 'paws'],
  '🍎': <String>['яблок', 'apple'],
  '🍓': <String>['земляник', 'клубник', 'strawberry'],
  '🍒': <String>['вишн', 'череш', 'cherry'],
  '🍉': <String>['арбуз', 'watermelon'],
  '🍊': <String>['апельсин', 'мандарин', 'orange'],
  '🍋': <String>['лимон', 'lemon'],
  '🍇': <String>['виноград', 'grapes'],
  '🍍': <String>['ананас', 'pineapple'],
  '🥭': <String>['манго', 'mango'],
  '🥕': <String>['морков', 'carrot'],
  '🌽': <String>['кукуруз', 'corn'],
  '🥑': <String>['авокадо', 'avocado'],
  '🍞': <String>['хлеб', 'bread'],
  '🧀': <String>['сыр', 'cheese'],
  '🍔': <String>['бургер', 'гамбург', 'burger'],
  '🍕': <String>['пицц', 'pizza'],
  '🌭': <String>['хот', 'дог', 'hot dog'],
  '🌮': <String>['так', 'taco'],
  '🍜': <String>['лапш', 'суп', 'noodles', 'ramen'],
  '🍝': <String>['паст', 'спагет', 'pasta'],
  '🍗': <String>['куриц', 'нож', 'chicken'],
  '🥓': <String>['бекон', 'bacon'],
  '🍳': <String>['яйц', 'яичниц', 'egg', 'breakfast'],
  '🥞': <String>['блин', 'панкейк', 'pancakes'],
  '🍩': <String>['пончик', 'donut'],
  '🍪': <String>['печен', 'cookie'],
  '🎂': <String>['торт', 'день рожден', 'cake', 'birthday'],
  '🍦': <String>['морожен', 'ice cream'],
  '🍿': <String>['попкорн', 'popcorn', 'кино'],
  '☕': <String>['кофе', 'чай', 'coffee', 'кружк'],
  '🍵': <String>['чай', 'tea', 'зелен'],
  '🍻': <String>['пив', 'кружк', 'beers', 'ура'],
  '🍷': <String>['вин', 'wine', 'бокал'],
  '🥂': <String>['шампан', 'бокал', 'champagne', 'празд'],
  '🍾': <String>['шампан', 'бутыл', 'champagne', 'празд'],
  '💧': <String>['вод', 'капл', 'water', 'drop'],
  '🚗': <String>['машин', 'авто', 'car'],
  '🚕': <String>['такси', 'taxi'],
  '🚌': <String>['автобус', 'bus'],
  '🚲': <String>['велосип', 'bike', 'bicycle'],
  '🏍': <String>['мотоцикл', 'motorcycle'],
  '✈': <String>['самолет', 'airplane', 'лет'],
  '🚀': <String>['ракет', 'rocket', 'старт'],
  '🚂': <String>['поезд', 'train'],
  '⛵': <String>['парус', 'лодк', 'sailboat'],
  '🏠': <String>['дом', 'house', 'home'],
  '🌍': <String>['земл', 'мир', 'планет', 'earth', 'world'],
  '⛅': <String>['облак', 'cloud', 'пасмур'],
  '☁': <String>['облак', 'cloud'],
  '🌧': <String>['дожд', 'rain'],
  '❄': <String>['снеж', 'снег', 'snowflake', 'холод', 'зим'],
  '☃': <String>['снегов', 'snowman', 'зим'],
  '🌈': <String>['радуг', 'rainbow'],
  '🌊': <String>['волн', 'мор', 'wave', 'ocean'],
  '🌸': <String>['цвет', 'сакур', 'blossom', 'flower'],
  '🌹': <String>['роз', 'цвет', 'rose', 'flower'],
  '💐': <String>['букет', 'цвет', 'bouquet'],
  '🍀': <String>['клевер', 'удач', 'clover', 'luck'],
  '⚽': <String>['футбол', 'мяч', 'football', 'soccer'],
  '🏀': <String>['баскет', 'мяч', 'basketball'],
  '🎾': <String>['теннис', 'tennis'],
  '🏆': <String>['кубок', 'побед', 'trophy', 'win'],
  '🥇': <String>['золот', 'перв', 'медал', 'gold', 'first'],
  '🎲': <String>['куб', 'игр', 'dice'],
  '🎯': <String>['цел', 'мишен', 'target', 'точн'],
  '🎸': <String>['гитар', 'guitar', 'музык'],
  '🎶': <String>['нот', 'музык', 'music', 'песн'],
  '🎁': <String>['подар', 'gift', 'present'],
  '🎈': <String>['шар', 'balloon', 'празд'],
  '📷': <String>['фото', 'камер', 'photo', 'camera'],
  '🎬': <String>['кино', 'фильм', 'movie', 'clapper'],
  '📺': <String>['телевиз', 'tv'],
  '💻': <String>['ноутбук', 'компьют', 'laptop', 'работ'],
  '⏰': <String>['будильн', 'час', 'врем', 'alarm', 'clock'],
  '⌛': <String>['песоч', 'час', 'врем', 'hourglass'],
  '💡': <String>['лампоч', 'иде', 'idea', 'bulb'],
  '🔒': <String>['замок', 'закрыт', 'lock', 'защит'],
  '💸': <String>['деньг', 'трат', 'money', 'flying'],
  '💎': <String>['алмаз', 'брилл', 'diamond'],
  '🎓': <String>['выпуск', 'учеб', 'graduation', 'диплом'],
  '👑': <String>['корон', 'crown', 'король'],
  '💍': <String>['кольц', 'ring', 'свадьб'],
  '📚': <String>['книг', 'учеб', 'books', 'read'],
  '✏': <String>['карандаш', 'писа', 'pencil', 'write'],
  '✂': <String>['ножниц', 'рез', 'scissors'],
  '🔔': <String>['колокол', 'звон', 'bell', 'увед'],
  '📣': <String>['громкогов', 'объявл', 'megaphone'],
  '⚙': <String>['шестерн', 'настрой', 'gear', 'settings'],
  '🛒': <String>['корзин', 'покуп', 'cart', 'shopping'],
  '🏁': <String>['финиш', 'флаг', 'finish', 'flag'],
  '🚩': <String>['флаг', 'flag', 'метк'],
};

/// Слова, общие для всей категории — второй слой покрытия.
const Map<String, List<String>> kEmojiCategorySearchWords =
    <String, List<String>>{
  'smileys_and_emotions': <String>['смайл', 'лицо', 'эмоц', 'смайлик', 'face', 'smiley', 'emotion'],
  'people': <String>['люд', 'жест', 'рук', 'тело', 'people', 'hand', 'body', 'gesture'],
  'animals_and_nature': <String>['животн', 'природ', 'зверь', 'animal', 'nature'],
  'food_and_drink': <String>['еда', 'напит', 'food', 'drink', 'вкус'],
  'travel_and_places': <String>['путешеств', 'мест', 'транспорт', 'travel', 'place'],
  'activities_and_events': <String>['активн', 'спорт', 'игр', 'activity', 'sport', 'event'],
  'objects': <String>['предмет', 'вещ', 'object', 'thing'],
  'symbols': <String>['символ', 'знак', 'symbol', 'sign'],
  'flags': <String>['флаг', 'flag', 'стран'],
};
