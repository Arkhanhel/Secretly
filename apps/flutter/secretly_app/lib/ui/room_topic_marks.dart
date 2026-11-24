// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart' show Color, IconData;

import '../app/message_command_utils.dart' show RoomTopicRef;
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// Знак темы — ЭТО САМА РЕШЁТКА, заменённая на другую (указание владельца
/// 15.09.2026).
///
/// ◆ ФОРМАТ ТЕМЫ: знак, потом название. По умолчанию знак — «#», и он говорит
/// «это ветка внутри комнаты». Выбрать другой знак значит ЗАМЕНИТЬ решётку, а
/// не приписать что-то рядом с ней: две пометки подряд («📞 # созвон») читались
/// бы как два разных признака, хотя признак один.
///
/// ◆ ЗНАЧКИ — ИЗ НАБОРА ДЕСКТОПНОГО ДИЗАЙНА (Fluent), а не системные
/// материаловские. Один и тот же рисунок на телефоне и на компьютере: у темы
/// один вид, куда бы на неё ни смотрели. Эмодзи для этого не годится —
/// у каждой системы он свой, а половина на старых устройствах не рисуется.
///
/// 🔴 ВСЕ ЗНАКИ — ОДНОГО НАЧЕРТАНИЯ (`regular`), И ЭТО НЕ ВКУСОВЩИНА.
///
/// Первая редакция брала «важным» знакам заливку (`filled`), и на живом окне
/// вместо телефона нарисовалось сердце: заливка — ОТДЕЛЬНЫЙ ШРИФТ семейства, и
/// подставился он не тот. Одно начертание на весь набор снимает этот класс
/// ошибок целиком и заодно роднит знаки с решёткой, которая тоже `regular`, —
/// ровно как в десктопном дизайне, где всё окно набрано одним весом.
///
/// 🔴 ЦВЕТ — ЭТО СМЫСЛ, А НЕ УКРАШЕНИЕ. Серый — умолчание: знак помогает
/// узнать ветку боковым зрением и не спорит с именем. Цветные — только там,
/// где цвет что-то ОБЕЩАЕТ: зелёный у звонка (сюда заходят голосом), красный
/// у «срочного», янтарный у объявлений. Если покрасить всё, цвет перестаёт
/// значить что-либо.
class RoomTopicMark {
  const RoomTopicMark({
    required this.id,
    required this.icon,
    required this.labelRu,
    this.color,
  });

  /// Идентификатор, который уезжает в рассылку и ложится в базу.
  final String id;

  final IconData icon;

  /// Подпись в выборе знака.
  final String labelRu;

  /// `null` — серый, цветом подписи темы. Иначе — свой цвет.
  final Color? color;

  bool get isTinted => color != null;
}

/// Решётка — знак по умолчанию. Не входит в [kRoomTopicMarks]: её не
/// «выбирают», к ней возвращаются.
const IconData kRoomTopicHashIcon = AdaptiveIconData(FluentIcons.number_symbol_24_regular, CupertinoIcons.number);

/// Зелёный, красный и янтарный — те же, что у десктопной палитры
/// (`success` / `danger` / `warning`), чтобы знак не спорил с окном.
const Color _kMarkGreen = Color(0xFF34D399);
const Color _kMarkRed = Color(0xFFF43F5E);
const Color _kMarkAmber = Color(0xFFF59E0B);
const Color _kMarkViolet = Color(0xFFA78BFA);

/// Набор знаков. Порядок — порядок в выборе: сначала цветные «важные», потом
/// серые по темам жизни комнаты.
const List<RoomTopicMark> kRoomTopicMarks = <RoomTopicMark>[
  // ── Цветные: цвет обещает, что внутри ──────────────────────────────────
  RoomTopicMark(
    id: 'call',
    icon: AdaptiveIconData(FluentIcons.call_24_regular, CupertinoIcons.phone),
    labelRu: 'Созвон',
    color: _kMarkGreen,
  ),
  RoomTopicMark(
    id: 'video',
    icon: AdaptiveIconData(FluentIcons.video_24_regular, CupertinoIcons.video_camera),
    labelRu: 'Конференция',
    color: _kMarkGreen,
  ),
  RoomTopicMark(
    id: 'alert',
    icon: AdaptiveIconData(FluentIcons.alert_urgent_24_regular, CupertinoIcons.bell),
    labelRu: 'Срочное',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'warning',
    icon: AdaptiveIconData(FluentIcons.warning_24_regular, CupertinoIcons.exclamationmark_triangle),
    labelRu: 'Внимание',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'bug',
    icon: AdaptiveIconData(FluentIcons.bug_24_regular, CupertinoIcons.ant),
    labelRu: 'Ошибки',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'announce',
    icon: AdaptiveIconData(FluentIcons.megaphone_loud_24_regular, CupertinoIcons.speaker_3),
    labelRu: 'Объявления',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'star',
    icon: AdaptiveIconData(FluentIcons.star_24_regular, CupertinoIcons.star),
    labelRu: 'Главное',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'fire',
    icon: AdaptiveIconData(FluentIcons.fire_24_regular, CupertinoIcons.flame),
    labelRu: 'Горячее',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'private',
    icon: AdaptiveIconData(FluentIcons.lock_closed_24_regular, CupertinoIcons.lock),
    labelRu: 'Только свои',
    color: _kMarkViolet,
  ),

  // ── Серые: узнавание боковым зрением, без обещаний ─────────────────────
  RoomTopicMark(
    id: 'chat',
    icon: AdaptiveIconData(FluentIcons.chat_24_regular, CupertinoIcons.chat_bubble),
    labelRu: 'Разговоры',
  ),
  RoomTopicMark(
    id: 'idea',
    icon: AdaptiveIconData(FluentIcons.lightbulb_24_regular, CupertinoIcons.lightbulb),
    labelRu: 'Идеи',
  ),
  RoomTopicMark(
    id: 'task',
    icon: AdaptiveIconData(FluentIcons.clipboard_task_24_regular, CupertinoIcons.checkmark_rectangle),
    labelRu: 'Задачи',
  ),
  RoomTopicMark(
    id: 'done',
    icon: AdaptiveIconData(FluentIcons.checkmark_circle_24_regular, CupertinoIcons.checkmark_circle),
    labelRu: 'Готово',
  ),
  RoomTopicMark(
    id: 'plan',
    icon: AdaptiveIconData(FluentIcons.calendar_ltr_24_regular, CupertinoIcons.calendar),
    labelRu: 'Планы',
  ),
  RoomTopicMark(
    id: 'doc',
    icon: AdaptiveIconData(FluentIcons.document_24_regular, CupertinoIcons.doc),
    labelRu: 'Документы',
  ),
  RoomTopicMark(
    id: 'book',
    icon: AdaptiveIconData(FluentIcons.book_24_regular, CupertinoIcons.book),
    labelRu: 'Записи',
  ),
  RoomTopicMark(id: 'code', icon: AdaptiveIconData(FluentIcons.code_24_regular, CupertinoIcons.chevron_left_slash_chevron_right), labelRu: 'Код'),
  RoomTopicMark(
    id: 'design',
    icon: AdaptiveIconData(FluentIcons.color_24_regular, CupertinoIcons.paintbrush),
    labelRu: 'Дизайн',
  ),
  RoomTopicMark(
    id: 'media',
    icon: AdaptiveIconData(FluentIcons.image_24_regular, CupertinoIcons.photo),
    labelRu: 'Картинки',
  ),
  RoomTopicMark(
    id: 'camera',
    icon: AdaptiveIconData(FluentIcons.camera_24_regular, CupertinoIcons.camera),
    labelRu: 'Съёмка',
  ),
  RoomTopicMark(
    id: 'music',
    icon: AdaptiveIconData(FluentIcons.music_note_2_24_regular, CupertinoIcons.music_note_2),
    labelRu: 'Музыка',
  ),
  RoomTopicMark(
    id: 'voice',
    icon: AdaptiveIconData(FluentIcons.mic_24_regular, CupertinoIcons.mic),
    labelRu: 'Голосовые',
  ),
  RoomTopicMark(
    id: 'game',
    icon: AdaptiveIconData(FluentIcons.games_24_regular, CupertinoIcons.gamecontroller),
    labelRu: 'Игры',
  ),
  RoomTopicMark(
    id: 'money',
    icon: AdaptiveIconData(FluentIcons.money_24_regular, CupertinoIcons.money_dollar_circle),
    labelRu: 'Деньги',
  ),
  RoomTopicMark(
    id: 'chart',
    icon: AdaptiveIconData(FluentIcons.data_trending_24_regular, CupertinoIcons.chart_bar),
    labelRu: 'Цифры',
  ),
  RoomTopicMark(
    id: 'work',
    icon: AdaptiveIconData(FluentIcons.briefcase_24_regular, CupertinoIcons.briefcase),
    labelRu: 'Работа',
  ),
  RoomTopicMark(
    id: 'target',
    icon: AdaptiveIconData(FluentIcons.target_24_regular, CupertinoIcons.scope),
    labelRu: 'Цели',
  ),
  RoomTopicMark(
    id: 'link',
    icon: AdaptiveIconData(FluentIcons.link_24_regular, CupertinoIcons.link),
    labelRu: 'Ссылки',
  ),
  RoomTopicMark(id: 'pin', icon: AdaptiveIconData(FluentIcons.pin_24_regular, CupertinoIcons.pin), labelRu: 'Важное'),
  RoomTopicMark(
    id: 'question',
    icon: AdaptiveIconData(FluentIcons.question_circle_24_regular, CupertinoIcons.question_circle),
    labelRu: 'Вопросы',
  ),
  RoomTopicMark(
    id: 'people',
    icon: AdaptiveIconData(FluentIcons.people_24_regular, CupertinoIcons.person_2),
    labelRu: 'Люди',
  ),
  RoomTopicMark(
    id: 'coffee',
    icon: AdaptiveIconData(FluentIcons.drink_coffee_24_regular, CupertinoIcons.cart),
    labelRu: 'Разное',
  ),
  RoomTopicMark(id: 'food', icon: AdaptiveIconData(FluentIcons.food_24_regular, CupertinoIcons.cart), labelRu: 'Еда'),
  RoomTopicMark(
    id: 'travel',
    icon: AdaptiveIconData(FluentIcons.airplane_24_regular, CupertinoIcons.airplane),
    labelRu: 'Поездки',
  ),
  RoomTopicMark(
    id: 'sport',
    icon: AdaptiveIconData(FluentIcons.dumbbell_24_regular, CupertinoIcons.sportscourt),
    labelRu: 'Спорт',
  ),
  RoomTopicMark(
    id: 'heart',
    icon: AdaptiveIconData(FluentIcons.heart_24_regular, CupertinoIcons.heart),
    labelRu: 'Личное',
  ),
  RoomTopicMark(
    id: 'rocket',
    icon: AdaptiveIconData(FluentIcons.rocket_24_regular, CupertinoIcons.rocket),
    labelRu: 'Запуск',
  ),
  RoomTopicMark(
    id: 'shield',
    icon: AdaptiveIconData(FluentIcons.shield_24_regular, CupertinoIcons.shield),
    labelRu: 'Безопасность',
  ),
  RoomTopicMark(
    id: 'globe',
    icon: AdaptiveIconData(FluentIcons.globe_24_regular, CupertinoIcons.globe),
    labelRu: 'Снаружи',
  ),
  RoomTopicMark(
    id: 'archive',
    icon: AdaptiveIconData(FluentIcons.archive_24_regular, CupertinoIcons.archivebox),
    labelRu: 'Архив',
  ),
];

/// Знак по идентификатору. `null` — знака нет (значит решётка) или он из
/// будущей версии.
///
/// Неизвестный идентификатор НЕ ошибка: набор со временем пополнится, и
/// устройство постарше должно показать тему с решёткой, а не потерять её.
RoomTopicMark? resolveRoomTopicMark(String? id) {
  final key = (id ?? '').trim();
  if (key.isEmpty) return null;
  for (final mark in kRoomTopicMarks) {
    if (mark.id == key) return mark;
  }
  return null;
}

/// Значок, который рисуется перед названием темы: выбранный знак или решётка.
IconData roomTopicIcon(RoomTopicRef topic) => roomTopicIconFor(topic.mark);

/// Цвет этого значка. `null` — серый, цветом подписи.
Color? roomTopicIconColor(RoomTopicRef topic) => roomTopicIconColorFor(topic.mark);

/// То же по голому идентификатору знака — для «Основы», у которой нет записи
/// в списке тем.
IconData roomTopicIconFor(String? mark) =>
    resolveRoomTopicMark(mark)?.icon ?? kRoomTopicHashIcon;

Color? roomTopicIconColorFor(String? mark) => resolveRoomTopicMark(mark)?.color;

/// Имя общего потока комнаты.
///
/// ◆ «ОСНОВА», А НЕ «ОБЩИЙ» (указание владельца 15.09.2026). «Общий» звучит
/// как «остальное, что никуда не подошло»; на деле это главный поток комнаты,
/// от которого ветки и отходят. И раз это такая же ветка — у неё такая же
/// решётка и такой же сменный значок.
const String kRoomBaseTopicTitleRu = 'Основа';
const String kRoomBaseTopicTitleEn = 'Base';

/// Имя темы со знаком «#» — для тех мест, где значок не нарисовать (заголовок
/// окна, текст сообщения).
String roomTopicDisplayTitle(RoomTopicRef topic) =>
    '#${normalizeRoomTopicTitle(topic.title)}';

/// Название без ведущих «#» и лишних пробелов.
///
/// Решётку рисует сам значок, поэтому в названии её не хранят: иначе «#релиз»
/// превратился бы в «##релиз», а после смены знака решётка осталась бы висеть
/// в имени.
String normalizeRoomTopicTitle(String raw) {
  var title = raw.trim();
  while (title.startsWith('#')) {
    title = title.substring(1).trimLeft();
  }
  return title;
}
