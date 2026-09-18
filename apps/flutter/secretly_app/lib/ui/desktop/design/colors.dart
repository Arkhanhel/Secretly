// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

class DColorSet {
  const DColorSet({
    required this.bg,
    required this.sidebar,
    required this.titleBar,
    required this.hoverBar,
    required this.accentSoft,
    required this.chatList,
    required this.detailsPanel,
    required this.railIconIdle,
    required this.thread,
    required this.threadGlow,
    required this.threadEdge,
    required this.elevated,
    required this.hover,
    required this.pressed,
    required this.selected,
    required this.borderHairline,
    required this.borderSubtle,
    required this.borderMenu,
    required this.borderDivider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textFaint,
    required this.accentPrimary,
    required this.accentPrimaryAlt,
    required this.success,
    required this.voice,
    required this.mintSoft,
    required this.warning,
    required this.danger,
    required this.bubbleSelfStart,
    required this.bubbleSelfEnd,
    this.bubbleSelfMid,
    required this.bubblePeer,
    required this.unreadDot,
    required this.unreadRoom,
    required this.unreadChannel,
    required this.unreadRail,
    required this.avatarNeutral,
    required this.avatarNeutralInk,
    required this.deliveryIndicator,
    required this.mentionBg,
    required this.scrim,
  });

  final Color bg;
  final Color sidebar;

  /// Шапка окна — своя поверхность `#121A24` (в макете 4 вхождения).
  ///
  /// 🔴 Она красилась `elevated` — тоном ВСПЛЫВАЮЩИХ карточек. По отдельности
  /// разница в один шаг, но шапка идёт вдоль всего верха окна, и на этой
  /// длине «почти тот» тон читается как чужая полоса, приклеенная сверху.
  final Color titleBar;

  /// Плавающая строка действий над сообщением — своя поверхность `#222C3A`.
  ///
  /// Она НЕ всплывающая карточка: та лежит на своём фоне поверх окна, а эта
  /// надвинута на пузырь и читается на нём. Тон всплывашек (`elevated`) на
  /// пузыре терялся — строка выглядела частью сообщения, а не над ним.
  final Color hoverBar;

  /// Светлый акцент для подписей НА акцентной плёнке — `#9AC5FA`.
  ///
  /// Сам `accentPrimary` на своей же заливке в 8 % почти сливается с ней:
  /// это цвет для сплошного, а не для текста поверх собственной тени. В
  /// макете такие подписи всегда светлее заливки на пару ступеней.
  final Color accentSoft;
  final Color chatList;

  /// Правая панель подробностей — своя поверхность `#0E141C`.
  ///
  /// Она красилась тоном СПИСКА ЧАТОВ. По отдельности разница в один шаг, но
  /// окно устроено как три вертикальные полосы, и когда крайние две одного
  /// тона, переписка между ними читается ямой, а не главным столбцом.
  final Color detailsPanel;

  /// Значок НЕвыбранного раздела на рейке — `#8697AB`.
  ///
  /// Он красился общим вторым тоном текста (`textSecondary`, #93A1B3). Тот
  /// подобран для ПОДПИСЕЙ на тёмной панели, а рейка темнее всего окна: на
  /// ней тот же цвет выходит ярче, чем нужно, и невыбранные разделы спорят с
  /// выбранным.
  final Color railIconIdle;
  final Color thread;

  /// Отблеск холста переписки — светлый угол радиального градиента.
  ///
  /// В макете поле переписки не залито одним цветом: это радиальный градиент
  /// «130% 100% at 12% 0%» от [threadGlow] через [thread] к [threadEdge].
  /// Свет падает из левого верхнего угла — оттуда же, откуда приходит взгляд, —
  /// и нижний правый угол, где лежат свои последние сообщения, оказывается
  /// самым тёмным. Пузыри на нём читаются, не набирая ни грамма контраста.
  final Color threadGlow;

  /// Дальний край холста переписки — самый тёмный угол того же градиента.
  final Color threadEdge;
  final Color elevated;
  final Color hover;
  final Color pressed;
  final Color selected;
  /// 🔴 СТУПЕНИ ГРАНИЦ СВЕРЕНЫ С ИСХОДНИКОМ МАКЕТА (15.09.2026).
  ///
  /// Сколько раз какая прозрачность стоит на границе в макете:
  /// .07 — 49 раз (обводка контролов, главная ступень), .05 — 33 раза
  /// (разделители панелей и линии у подписей), .12 — рамка меню, .06 — низ
  /// шапки окна.
  ///
  /// У нас их было ДВЕ: 0x0F (≈5.9 %) и 0x1A (≈10.2 %). Самая частая .07
  /// выражалась через 5.9 %, а разделитель панели — через 10.2 %, то есть
  /// ВДВОЕ ярче нужного: тонкая черта, которая должна лишь намекать на край,
  /// рисовалась заметнее обводки кнопки рядом.
  ///
  /// Волосяная линия: разделители панелей, черта у подписи раздела.
  final Color borderHairline;

  /// Главная ступень макета (.07): обводка контролов — поля, кнопки, чипы.
  final Color borderSubtle;

  /// Рамка меню (.12): единственная граница, которая обязана быть видна
  /// сама по себе — меню всплывает поверх чужого содержимого.
  final Color borderMenu;

  final Color borderDivider;
  final Color textPrimary;
  final Color textSecondary;

  /// Третий тон: время в строке списка, приглушённые значки служебных кнопок.
  ///
  /// 🔴 В макете тонов текста ПЯТЬ, а не три. Отметка времени и «плюс» в поле
  /// ввода написаны не тем же цветом, что имя собеседника, и не тем, что
  /// выключенная строка меню: между ними есть свой шаг. Когда трёх тонов не
  /// хватало, всё лишнее сваливалось в [textDisabled] — и служебная подпись
  /// начинала выглядеть отключённой.
  final Color textTertiary;
  final Color textDisabled;

  /// Самый слабый тон: значки-крошки — булавка у заголовка раздела, замок под
  /// полем ввода, «птичка» раскрытия. Они должны находиться взглядом, когда их
  /// ищут, и не попадаться на глаза, когда не ищут.
  final Color textFaint;
  final Color accentPrimary;
  final Color accentPrimaryAlt;
  final Color success;

  /// 🔴 ЗЕЛЁНЫХ В МАКЕТЕ ДВА, И ОНИ ЗНАЧАТ РАЗНОЕ.
  ///
  /// `#22C55E` легенда макета называет прямо: «голос». Им отмечено СОСТОЯНИЕ
  /// ЧЕЛОВЕКА — точка «в сети», признак «говорит», кнопка «Принять»
  /// (20 вхождений). Мятный `#34D399` — это оформление СОЗВОНА и галочки:
  /// значок демонстрации экрана, рамка сцены, чипы (37 вхождений).
  ///
  /// У нас был один зелёный на оба смысла, и точка присутствия получала тот
  /// же цвет, что значок демонстрации экрана.
  final Color voice;

  /// Светлая мята `#6EE7B7` — ею в макете набраны ЦИФРЫ на мятной плёнке
  /// (таймер созвона). Сам `success` (#34D399) на своей же плёнке .14
  /// читается вяло: заливка и буквы слишком близки по светлоте.
  final Color mintSoft;
  final Color warning;
  final Color danger;
  final Color bubbleSelfStart;
  final Color bubbleSelfEnd;

  /// Optional middle stop of the outgoing-bubble gradient.
  ///
  /// The shared bubble presets are three-stop (top / mid / bottom); desktop
  /// carried only two, so a preset picked on the phone rendered here as a
  /// flatter approximation of itself. Null means "two-stop gradient", which is
  /// what the presets without a mid actually want.
  final Color? bubbleSelfMid;
  final Color bubblePeer;
  /// Счётчик непрочитанного у ОБЫЧНОГО чата — ГОЛУБОЙ.
  ///
  /// 🔴 Цвет счётчика называет ТИП разговора. В списке из тридцати строк тип
  /// видно боковым зрением по цвету пятна, и «двенадцать непрочитанных» в
  /// личной переписке и в шумной комнате — разные новости.
  ///
  /// 15.09.2026, указание владельца: личная переписка — ГОЛУБОЙ (как в
  /// макете, там все строки списка #4C8DF6), комната — ФИОЛЕТОВЫЙ. Раньше
  /// личная была красной, а комната голубой.
  ///
  /// Красный остался ровно там, где он и значит другое, — см. [unreadRail].
  final Color unreadDot;

  /// Счётчик непрочитанного у КОМНАТЫ — фиолетовый.
  final Color unreadRoom;

  /// Счётчик непрочитанного у КАНАЛА — светло-фиолетовый.
  ///
  /// Рядом с комнатой он читается «то же семейство, но другое»: канал и есть
  /// комната, в которой пишут немногие.
  final Color unreadChannel;

  /// 🔴 КРАСНЫЙ СИГНАЛ «ТУТ ТЕБЯ ЖДУТ» — фильтры, плитки разделов и черта
  /// непрочитанного в ленте.
  ///
  /// Счётчик в строке списка и счётчик в фильтре считают РАЗНОЕ. В строке
  /// число — это сколько СООБЩЕНИЙ не прочитано в ЭТОМ разговоре. В фильтре
  /// над списком и на плитке раздела — сколько РАЗГОВОРОВ ждут ответа.
  /// Одинаковый цвет у двух разных величин складывался в обман: «19» в
  /// фильтре читалось как девятнадцать сообщений.
  ///
  /// Цвет здесь НЕ зависит от типа разговора: фильтр «Непрочитанные» и плитка
  /// «Чаты» собирают разговоры всех типов сразу, и красить их по типу нечем.
  ///
  /// Черта «Новые сообщения» в ленте — тот же сигнал и тот же красный: она
  /// говорит ровно «отсюда тебя ждут». Это НЕ `danger`: тот про опасное
  /// действие («Удалить», «Заблокировать»), и смешивать «тебя ждут» с «сейчас
  /// что-то потеряешь» нельзя, даже если оттенок совпадает.
  final Color unreadRail;

  /// Нейтральная заглушка портрета: заливка и цвет букв.
  ///
  /// 🔴 БОЛЬШЕ НЕ ИСПОЛЬЗУЕТСЯ ЗАГЛУШКАМИ (15.09.2026). В макете цветом были
  /// отмечены только комнаты, и люди рисовались этим нейтральным тоном.
  /// Владелец решил иначе: на телефоне человек без фотографии уже цветной, и
  /// один и тот же собеседник выходил на двух устройствах разным. Теперь
  /// цветные все, разница между устройствами — в ЯРКОСТИ (см. `Avatar`).
  ///
  /// Токены оставлены: ими красятся места, где портрета вообще нет, —
  /// например пустая плитка «добавить» на рейке. Удалять их значит завести
  /// нейтральный серый заново, но уже хексом на месте.
  final Color avatarNeutral;
  final Color avatarNeutralInk;

  /// Colour of the delivery ticks. Separate from [accentPrimary] because the
  /// «Цвета индикаторов» preset can pin it independently of the theme accent.
  final Color deliveryIndicator;
  final Color mentionBg;
  final Color scrim;

  bool get isDark => bg.computeLuminance() < 0.5;

  /// Returns a copy of this set with the provided overrides applied. Lets
  /// callers derive theme-preset-tinted variants without redefining all 24
  /// surface colors. Pass `null` for fields you don't want to override —
  /// the original value is kept.
  DColorSet copyWith({
    Color? bg,
    Color? sidebar,
    Color? titleBar,
    Color? hoverBar,
    Color? accentSoft,
    Color? chatList,
    Color? detailsPanel,
    Color? railIconIdle,
    Color? thread,
    Color? threadGlow,
    Color? threadEdge,
    Color? elevated,
    Color? hover,
    Color? pressed,
    Color? selected,
    Color? borderHairline,
    Color? borderSubtle,
    Color? borderMenu,
    Color? borderDivider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textFaint,
    Color? accentPrimary,
    Color? accentPrimaryAlt,
    Color? success,
    Color? voice,
    Color? mintSoft,
    Color? warning,
    Color? danger,
    Color? bubbleSelfStart,
    Color? bubbleSelfEnd,
    Color? bubbleSelfMid,
    Color? bubblePeer,
    Color? unreadDot,
    Color? unreadRoom,
    Color? unreadChannel,
    Color? unreadRail,
    Color? avatarNeutral,
    Color? avatarNeutralInk,
    Color? deliveryIndicator,
    Color? mentionBg,
    Color? scrim,
  }) {
    return DColorSet(
      bg: bg ?? this.bg,
      sidebar: sidebar ?? this.sidebar,
      titleBar: titleBar ?? this.titleBar,
      hoverBar: hoverBar ?? this.hoverBar,
      accentSoft: accentSoft ?? this.accentSoft,
      chatList: chatList ?? this.chatList,
      detailsPanel: detailsPanel ?? this.detailsPanel,
      railIconIdle: railIconIdle ?? this.railIconIdle,
      thread: thread ?? this.thread,
      threadGlow: threadGlow ?? this.threadGlow,
      threadEdge: threadEdge ?? this.threadEdge,
      elevated: elevated ?? this.elevated,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      selected: selected ?? this.selected,
      borderHairline: borderHairline ?? this.borderHairline,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderMenu: borderMenu ?? this.borderMenu,
      borderDivider: borderDivider ?? this.borderDivider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textFaint: textFaint ?? this.textFaint,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentPrimaryAlt: accentPrimaryAlt ?? this.accentPrimaryAlt,
      success: success ?? this.success,
      voice: voice ?? this.voice,
      mintSoft: mintSoft ?? this.mintSoft,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      bubbleSelfStart: bubbleSelfStart ?? this.bubbleSelfStart,
      bubbleSelfEnd: bubbleSelfEnd ?? this.bubbleSelfEnd,
      bubbleSelfMid: bubbleSelfMid ?? this.bubbleSelfMid,
      bubblePeer: bubblePeer ?? this.bubblePeer,
      unreadDot: unreadDot ?? this.unreadDot,
      unreadRoom: unreadRoom ?? this.unreadRoom,
      unreadChannel: unreadChannel ?? this.unreadChannel,
      unreadRail: unreadRail ?? this.unreadRail,
      avatarNeutral: avatarNeutral ?? this.avatarNeutral,
      avatarNeutralInk: avatarNeutralInk ?? this.avatarNeutralInk,
      deliveryIndicator: deliveryIndicator ?? this.deliveryIndicator,
      mentionBg: mentionBg ?? this.mentionBg,
      scrim: scrim ?? this.scrim,
    );
  }
}

/// Тёмная палитра — «Секретли-контроль» (макет владельца, 13.09.2026).
///
/// Что изменилось и почему. Прежняя палитра была НЕЙТРАЛЬНО-СЕРОЙ (`#1A1B1E`):
/// безопасный выбор, но на большом экране серое поле читается как пустое, и
/// переписка не отделяется от хрома. Новая — холодная сине-чёрная, и разделение
/// в ней делает не рамка, а СВЕТ: рейка самая тёмная, список светлее,
/// переписка ещё светлее и с отблеском сверху. Глаз находит главное без единой
/// линии.
///
/// Акцент переехал с индиго (`#6366F1`) на пару синий → фиолетовый
/// (`#4C8DF6` → `#7C5CE0`). Синий у людей означает «действие», фиолетовый —
/// «своё», и свои пузыри как раз лежат на переходе между ними.
///
/// 🔴 ПАРА СВЕРЕНА С ИСХОДНИКОМ (14.09.2026). Здесь была записана как канон
/// пара `#3E8BF5 → #7C4DE0` — на шаг темнее настоящей. Записанная неверно,
/// она расползлась по производным: выделение строки, плашка упоминания, знак
/// доставки и пузыри светлой темы считались от неё. По отдельности разница в
/// один шаг тона незаметна, вместе она и давала «почти тот, но не тот»
/// интерфейс, о котором сказал владелец.
///
/// 🔴 Значения менялись ТОЛЬКО здесь. Разметка читает токены, поэтому смена
/// палитры не трогает ни один экран — это и позволило обновить вид без
/// переписывания. См. docs/ТЗ_ОБНОВЛЕНИЕ_ВИЗУАЛА_ДЕСКТОПА_2026-09-13.md.
const DColorSet kDColorsDark = DColorSet(
  // 🔴 Цвета ниже сверены с ИСХОДНИКОМ макета (14.09.2026), а не с видом на
  // снимке. Раньше часть значений была взята с глаз и отличалась на один-два
  // шага тона — по отдельности незаметно, вместе давало «почти тот, но не тот»
  // интерфейс, о чём владелец и сказал.
  //
  // #07090C — цвет СТРАНИЦЫ, на которой лежит артборд; само окно в макете
  // #0B1016.
  bg: Color(0xFF0B1016),
  sidebar: Color(0xFF080C12),
  titleBar: Color(0xFF121A24),
  hoverBar: Color(0xFF222C3A),
  accentSoft: Color(0xFF9AC5FA),
  chatList: Color(0xFF0E141C),
  detailsPanel: Color(0xFF0E141C),
  railIconIdle: Color(0xFF8697AB),
  thread: Color(0xFF0D131B),
  threadGlow: Color(0xFF16202C),
  threadEdge: Color(0xFF0A0E14),
  // Поле ввода, всплывашки и карточки в макете — #131C26.
  elevated: Color(0xFF131C26),
  // · НАВЕДЕНИЕ — .07 ИЗ МАКЕТА (49 вхождений, единая величина на всё окно).
  //
  // Было ≈5.1 % — тише макета, и при нажатии сразу 10.2 %: наведение едва
  // читалось, а нажатие било вдвое. Обе ступени были сдвинуты вниз, и шаг
  // между ними — вдвое.
  //
  // Нажатие оставлено на .10 намеренно: состояния «нажато» в макете нет
  // вовсе — это картинка, а не приложение. Но подняв наведение до .07, шаг
  // до нажатия стал мягким, а не двукратным.
  hover: Color(0x12FFFFFF),
  pressed: Color(0x1AFFFFFF),
  // rgba(76,141,246,.15) из макета — считается ОТ акцента, а не рядом с ним.
  selected: Color(0x264C8DF6),
  borderHairline: Color(0x0DFFFFFF),
  borderSubtle: Color(0x12FFFFFF),
  borderMenu: Color(0x1FFFFFFF),
  borderDivider: Color(0x1AFFFFFF),
  textPrimary: Color(0xFFE9EFF7),
  textSecondary: Color(0xFF93A1B3),
  textTertiary: Color(0xFF7E8DA0),
  textDisabled: Color(0xFF6B7A8D),
  textFaint: Color(0xFF4B5A6E),
  accentPrimary: Color(0xFF4C8DF6),
  accentPrimaryAlt: Color(0xFF7C5CE0),
  // Мята созвона: демонстрация экрана, рамка сцены, галочки.
  success: Color(0xFF34D399),
  // «Голос» из легенды макета: присутствие, речь, приём звонка.
  voice: Color(0xFF22C55E),
  mintSoft: Color(0xFF6EE7B7),
  warning: Color(0xFFF59E0B),
  danger: Color(0xFFF43F5E),
  // Свой пузырь в макете — тот же градиент, что у активной плитки рейки.
  bubbleSelfStart: Color(0xFF4C8DF6),
  bubbleSelfEnd: Color(0xFF7C5CE0),
  bubblePeer: Color(0xFF1B2430),
  // 🔴 ТРИ ЦВЕТА НЕПРОЧИТАННОГО, И КАЖДЫЙ НАЗЫВАЕТ СВОЁ (указание владельца
  // от 15.09.2026).
  //
  // Голубой — личная переписка, фиолетовый — комната, светло-фиолетовый —
  // канал. Красный остаётся ТОЛЬКО за рейкой и полосой фильтров, и там он
  // считает не сообщения, а РАЗГОВОРЫ, которые ждут ответа.
  //
  // (Прежний комментарий здесь утверждал «счётчик — красный» ещё долго после
  // того, как значения стали голубым и фиолетовым.)
  unreadDot: Color(0xFF4C8DF6),
  unreadRoom: Color(0xFF7C5CE0),
  unreadChannel: Color(0xFFA78BFA),
  unreadRail: Color(0xFFF43F5E),
  avatarNeutral: Color(0xFF2B3646),
  avatarNeutralInk: Color(0xFFC8D4E2),
  // #6FA8F7 — синий значок и синий текст макета (встречается 28 раз).
  deliveryIndicator: Color(0xFF6FA8F7),
  mentionBg: Color(0x2D7C5CE0),
  scrim: Color(0x8C000000),
);

/// · СВЕТЛАЯ ТЕМА — ПРОИЗВОДНАЯ, А НЕ ОТДЕЛЬНЫЙ МАКЕТ.
///
/// В файле макета все четыре артборда тёмные; ни одного светлого значения в
/// нём нет. Сверять этот набор не с чем — и это не расхождение, которое
/// когда-нибудь закроют, а свойство исходника.
///
/// Поэтому правило такое: светлый набор выводится из тёмного тем же порядком
/// и правится ВМЕСТЕ с ним, а не отдельным заходом. Три приёма вывода:
///
///   1. Цвет, который на белом слепит или проваливает контраст подписи, берём
///      на шаг темнее: акцент #4C8DF6 → #2563EB, зелёные — до #059669.
///   2. Всё, что в тёмной задано прозрачностью по белому (наведение, границы,
///      выделение), в светлой задаётся той же долей по ЧЁРНОМУ.
///   3. Производные цвета (пузырь, выделение, подсветка упоминания) выводятся
///      от СВОЕГО акцента, а не копируются из тёмной: скопированный пузырь
///      выдавал белые буквы на слишком светлом синем.
///
/// За этим следит `desktop_light_palette_test.dart`: наборы обязаны иметь
/// одни и те же поля, и ни одно значение не должно совпадать буквально —
/// буквальное совпадение означает, что поле просто забыли вывести.
const DColorSet kDColorsLight = DColorSet(
  bg: Color(0xFFF6F7FA),
  sidebar: Color(0xFFEDEEF2),
  titleBar: Color(0xFFF2F3F7),
  hoverBar: Color(0xFFFFFFFF),
  accentSoft: Color(0xFF2B6CD4),
  chatList: Color(0xFFFFFFFF),
  detailsPanel: Color(0xFFFAFBFD),
  railIconIdle: Color(0xFF6B7A8D),
  thread: Color(0xFFFFFFFF),
  // Светлая тема берёт тот же приём наоборот: свет из левого верхнего угла
  // означает «чуть белее белого», дальний угол — лёгкую тень страницы.
  threadGlow: Color(0xFFFFFFFF),
  threadEdge: Color(0xFFF2F4F8),
  elevated: Color(0xFFFFFFFF),
  hover: Color(0x0F000000),
  pressed: Color(0x14000000),
  // Та же доля, что в тёмной, но от СВОЕГО акцента: иначе выделение
  // строки светлой темы осталось бы от старой пары.
  selected: Color(0x1F2563EB),
  borderHairline: Color(0x0D000000),
  borderSubtle: Color(0x14000000),
  borderMenu: Color(0x24000000),
  borderDivider: Color(0x1F000000),
  textPrimary: Color(0xFF14151A),
  textSecondary: Color(0xFF5A5E66),
  textTertiary: Color(0xFF767B84),
  textDisabled: Color(0xFFA0A4AB),
  textFaint: Color(0xFFB6BBC3),
  // Светлая тема идёт за тёмной по тону, но берёт цвета на шаг темнее: на белом
  // фоне тот же синий слепит и проваливает контраст текста на кнопках.
  accentPrimary: Color(0xFF2563EB),
  accentPrimaryAlt: Color(0xFF6D35CF),
  // Светлая тема берёт оба зелёных на шаг темнее — на белом листе мята и
  // травяной слепят одинаково.
  success: Color(0xFF059669),
  voice: Color(0xFF16A34A),
  // На белом листе светлая мята не читается — берём тот же тон, что success.
  mintSoft: Color(0xFF059669),
  warning: Color(0xFFD97706),
  danger: Color(0xFFDC2626),
  // Пузырь светлой темы берёт ЕЁ акцент, а не тёмный: на белом листе белые
  // буквы на #4C8DF6 стоят на грани читаемости, на #2563EB — уверенно.
  bubbleSelfStart: Color(0xFF2563EB),
  bubbleSelfEnd: Color(0xFF6D35CF),
  bubblePeer: Color(0xFFEDEEF2),
  unreadDot: Color(0xFF2563EB),
  unreadRoom: Color(0xFF7C3AED),
  unreadChannel: Color(0xFF8B5CF6),
  unreadRail: Color(0xFFDC2626),
  avatarNeutral: Color(0xFFDCE1E8),
  avatarNeutralInk: Color(0xFF4A5462),
  deliveryIndicator: Color(0xFF2563EB),
  mentionBg: Color(0x1F6D35CF),
  scrim: Color(0x59000000),
);

/// Inherited accessor for the current color set + brightness.
class DColors extends InheritedWidget {
  const DColors({
    super.key,
    required this.colors,
    required super.child,
  });

  final DColorSet colors;

  static DColorSet of(BuildContext context) {
    final inh = context.dependOnInheritedWidgetOfExactType<DColors>();
    if (inh != null) return inh.colors;
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? kDColorsDark : kDColorsLight;
  }

  @override
  bool updateShouldNotify(covariant DColors oldWidget) =>
      oldWidget.colors != colors;
}
