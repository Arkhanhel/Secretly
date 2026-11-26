// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Премиум-наборы стикеров (24.11.2026, макеты «Premium Stickers» и
/// «Pixel Stickers»).
///
/// Владелец: «эмодзи пак только для премиум пользователей, обычно его
/// использовать не могут, но они его видят в чате, если присылает кто-то из
/// премиум». Как в Telegram:
/// - наборы встроены в приложение (Lottie JSON, 512×512) — получатель видит
///   стикер без скачивания, даже без Premium;
/// - отправить может только Premium (`GatedFeature.premiumStickers`);
///   проверка и в панели, и в контроллере;
/// - в панели значок каждого набора (первый стикер + звёздочка) закреплён в
///   верхней строке слева от лупы; без Premium касание открывает окно
///   набора с кнопкой покупки.
///
/// Старые сборки не знают этих наборов: у них стикер показывается
/// подсказкой-эмодзи (`emoji_hint`), как любой неизвестный стикер.
library;

import 'sticker_catalog.dart';

/// Выключатель. `false` — наборов нет нигде (ни в панели, ни в поиске
/// стикера по событию); полученный стикер — подсказкой-эмодзи.
///
/// 🔴 Включается вместе с файлами анимаций в `assets/stickers/premium_safe/`
/// и `assets/stickers/premium_pixel/` (и их строками в pubspec.yaml) — тест
/// `premium_sticker_packs_test.dart` проверяет, что каждый файл на месте.
const bool kPremiumStickerPacks = true;

/// Выключатель бесплатного набора «Детки».
const bool kKidsStickerPack = true;

const String kPremiumSafePackId = 'secretly_premium_safe';
const String kPremiumPixelPackId = 'secretly_premium_pixel';
const int kPremiumPackVersion = 1;

/// Каталог ассетов набора: `assets/stickers/<папка>/<ключ>.tgs` (gzip от
/// Lottie JSON, как в Telegram: 3–36 КБ вместо 30–860 КБ).
const String kPremiumStickerAssetsDir = 'assets/stickers';

const String kKidsStickerPackId = 'secretly_kids';

bool isPremiumStickerPackId(String packId) =>
    packId == kPremiumSafePackId || packId == kPremiumPixelPackId;

/// Наборы дизайнера, встроенные в приложение (премиум и бесплатные).
bool isDesignerStickerPackId(String packId) =>
    isPremiumStickerPackId(packId) || packId == kKidsStickerPackId;

/// Частота кадров отрисовки: «Pixel» нарисован 12 кадрами в секунду
/// (одинаковые кадры склеены) — рисовать его 60 раз в секунду незачем,
/// в 5 раз меньше работы. Остальные — как в файле (60).
int? stickerPackFrameRate(String packId) =>
    packId == kPremiumPixelPackId ? 12 : null;

/// (ключ, эмодзи-подсказка, подпись, слова для поиска).
typedef _Spec = (String, String, String, List<String>);

/// «Секретный сейф» — 20 стикеров, 60 к/с.
const List<_Spec> _safe = [
  ('diamond', '💎', 'Diamond', ['бриллиант', 'diamond', 'gem', 'алмаз', 'бриллиант', 'діамант']),
  ('crown', '👑', 'Crown', ['корона', 'crown', 'king', 'корона', 'король']),
  ('rocket', '🚀', 'Rocket', ['ракета', 'rocket', 'launch', 'ракета', 'взлёт']),
  ('money', '💸', 'Money', ['улетели', 'money', 'cash', 'деньги', 'гроші', 'купюра']),
  ('heal', '❤️‍🩹', 'Heal', ['склеили', 'heart', 'heal', 'сердце', 'серце', 'мир']),
  ('zap', '⚡', 'Zap', ['разряд', 'zap', 'lightning', 'молния', 'блискавка', 'энергия']),
  ('trophy', '🏆', 'Trophy', ['победа', 'trophy', 'win', 'кубок', 'победа', 'перемога']),
  ('gift', '🎁', 'Gift', ['сюрприз', 'gift', 'present', 'подарок', 'подарунок']),
  ('key', '🔑', 'Key', ['ключ', 'key', 'love', 'ключ', 'любовь']),
  ('idea', '💡', 'Idea', ['идея', 'idea', 'bulb', 'идея', 'ідея', 'лампа']),
  ('hourglass', '⏳', 'Hourglass', ['таймер', 'wait', 'time', 'часы', 'жду', 'чекаю']),
  ('vanish', '💨', 'Vanish', ['исчезло', 'vanish', 'disappear', 'исчезнуть', 'зникнути']),
  ('safe', '🔐', 'Safe', ['сейф', 'safe', 'secret', 'сейф', 'секрет']),
  ('alarm', '⏰', 'Alarm', ['подъём!', 'alarm', 'wake', 'будильник', 'подъём']),
  ('coffee', '☕', 'Coffee', ['кофе', 'coffee', 'morning', 'кофе', 'кава', 'утро']),
  ('moon', '🌙', 'Moon', ['спокойной ночи', 'sleep', 'night', 'спать', 'ночь', 'ніч']),
  ('search', '🔍', 'Search', ['ищу', 'search', 'look', 'поиск', 'пошук', 'ищу']),
  ('popper', '🎉', 'Popper', ['хлопушка', 'party', 'congrats', 'праздник', 'ура', 'свято']),
  ('rain', '🌧️', 'Rain', ['пасмурно', 'sad', 'rain', 'грусть', 'дождь', 'сумно']),
  ('sun', '😎', 'Sun', ['жара', 'cool', 'sun', 'солнце', 'круто', 'сонце']),
];

/// «Pixel» — 12 стикеров, сетка 32×32, 12 к/с.
const List<_Spec> _pixel = [
  ('heart', '❤️', 'Heart', ['жизнь +1', 'heart', 'love', 'сердце', 'серце', '+1']),
  ('coin', '🪙', 'Coin', ['монетка', 'coin', 'money', 'монета', 'монетка']),
  ('potion', '🧪', 'Potion', ['зелье', 'potion', 'magic', 'зелье', 'зілля']),
  ('chest', '🧰', 'Chest', ['сундук', 'chest', 'loot', 'сундук', 'скриня', 'клад']),
  ('slime', '🟢', 'Slime', ['слизень', 'slime', 'jump', 'слизень', 'прыжок']),
  ('ghost', '👻', 'Ghost', ['бу!', 'ghost', 'boo', 'призрак', 'привид', 'бу']),
  ('fire', '🔥', 'Fire', ['костёр', 'fire', 'campfire', 'костёр', 'огонь', 'вогонь']),
  ('cat', '🐱', 'Cat', ['котик', 'cat', 'meow', 'кот', 'кіт', 'мяу']),
  ('ufo', '🛸', 'UFO', ['нло', 'ufo', 'alien', 'нло', 'пришелец']),
  ('lvlup', '🆙', 'Level up', ['новый уровень', 'level', 'up', 'уровень', 'рівень', 'lvl']),
  ('bomb', '💣', 'Bomb', ['бабах', 'bomb', 'boom', 'бомба', 'взрыв']),
  ('star', '⭐', 'Star', ['звёздочка', 'star', 'bonus', 'звезда', 'зірка', 'бонус']),
];

/// «Детки» (Эски-малыши) — 12 стикеров, бесплатно для всех.
const List<_Spec> _kids = [
  ('k_wave', '👋', 'Hi', ['привет', 'hi', 'hello', 'wave', 'привіт']),
  ('k_giggle', '🤭', 'Giggle', ['хи-хи', 'giggle', 'laugh', 'хихи', 'смех', 'сміх']),
  ('k_hug', '🤗', 'Hug', ['обнимашки', 'hug', 'обнять', 'обійми']),
  ('k_cry', '😭', 'Cry', ['плачу', 'cry', 'sad', 'грусть']),
  ('k_hmph', '😤', 'Hmph', ['хмф!', 'hmph', 'angry', 'обида', 'злюсь']),
  ('k_star', '🤩', 'Wow', ['ого!', 'wow', 'star', 'ого', 'вау']),
  ('k_curious', '🤔', 'Curious', ['интересно', 'hmm', 'curious', 'цікаво']),
  ('k_cool', '😎', 'Cool', ['крутой', 'cool', 'круто', 'крутий']),
  ('k_sleep', '😴', 'Sleep', ['баю-бай', 'sleep', 'night', 'спать', 'сон']),
  ('k_balloon', '🎈', 'Balloon', ['шарик', 'balloon', 'кулька']),
  ('k_love', '😍', 'Love', ['влюблён', 'love', 'люблю', 'кохаю']),
  ('k_party', '🥳', 'Party', ['ура!', 'party', 'yay', 'ура', 'праздник', 'свято']),
];

SecretlyStickerPack _pack({
  required String id,
  required String dir,
  required String title,
  required List<_Spec> specs,
  bool premium = true,
}) {
  return SecretlyStickerPack(
    id: id,
    version: kPremiumPackVersion,
    title: title,
    iconStickerId: specs.first.$1,
    premium: premium,
    iconEmojiHint: specs.first.$2,
    stickers: [
      for (final s in specs)
        SecretlyStickerDescriptor(
          packId: id,
          packVersion: kPremiumPackVersion,
          stickerId: s.$1,
          assetPath: '$kPremiumStickerAssetsDir/$dir/${s.$1}.tgs',
          format: SecretlyStickerFormat.lottie,
          animated: true,
          emojiHint: s.$2,
          label: s.$3,
          keywords: s.$4,
        ),
    ],
  );
}

/// Оба набора по порядку: «Секретный сейф», «Pixel». Названия — английские
/// по умолчанию; в интерфейсе берутся из перевода ([premiumPackTitle]).
final List<SecretlyStickerPack> premiumStickerPacks = List.unmodifiable([
  _pack(
    id: kPremiumSafePackId,
    dir: 'premium_safe',
    title: 'Secret Safe',
    specs: _safe,
  ),
  _pack(
    id: kPremiumPixelPackId,
    dir: 'premium_pixel',
    title: 'Pixel',
    specs: _pixel,
  ),
]);

/// «Детки» — бесплатный встроенный набор для всех (владелец 24.11.2026:
/// «идут как бесплатный пак для всех пользователей, даже без премиум»).
final SecretlyStickerPack kidsStickerPack = _pack(
  id: kKidsStickerPackId,
  dir: 'kids',
  title: 'Kids',
  specs: _kids,
  premium: false,
);

/// Отправка стикера премиум-набора без Premium. Экран ловит её и открывает
/// страницу покупки вместо сообщения об ошибке.
class PremiumStickerLockedException implements Exception {
  const PremiumStickerLockedException(this.packId);

  final String packId;

  @override
  String toString() => 'PremiumStickerLockedException($packId)';
}
