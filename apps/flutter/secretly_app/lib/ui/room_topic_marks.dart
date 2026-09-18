// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart' show Color, IconData;

import '../app/message_command_utils.dart' show RoomTopicRef;

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
const IconData kRoomTopicHashIcon = FluentIcons.number_symbol_24_regular;

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
    icon: FluentIcons.call_24_regular,
    labelRu: 'Созвон',
    color: _kMarkGreen,
  ),
  RoomTopicMark(
    id: 'video',
    icon: FluentIcons.video_24_regular,
    labelRu: 'Конференция',
    color: _kMarkGreen,
  ),
  RoomTopicMark(
    id: 'alert',
    icon: FluentIcons.alert_urgent_24_regular,
    labelRu: 'Срочное',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'warning',
    icon: FluentIcons.warning_24_regular,
    labelRu: 'Внимание',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'bug',
    icon: FluentIcons.bug_24_regular,
    labelRu: 'Ошибки',
    color: _kMarkRed,
  ),
  RoomTopicMark(
    id: 'announce',
    icon: FluentIcons.megaphone_loud_24_regular,
    labelRu: 'Объявления',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'star',
    icon: FluentIcons.star_24_regular,
    labelRu: 'Главное',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'fire',
    icon: FluentIcons.fire_24_regular,
    labelRu: 'Горячее',
    color: _kMarkAmber,
  ),
  RoomTopicMark(
    id: 'private',
    icon: FluentIcons.lock_closed_24_regular,
    labelRu: 'Только свои',
    color: _kMarkViolet,
  ),

  // ── Серые: узнавание боковым зрением, без обещаний ─────────────────────
  RoomTopicMark(
    id: 'chat',
    icon: FluentIcons.chat_24_regular,
    labelRu: 'Разговоры',
  ),
  RoomTopicMark(
    id: 'idea',
    icon: FluentIcons.lightbulb_24_regular,
    labelRu: 'Идеи',
  ),
  RoomTopicMark(
    id: 'task',
    icon: FluentIcons.clipboard_task_24_regular,
    labelRu: 'Задачи',
  ),
  RoomTopicMark(
    id: 'done',
    icon: FluentIcons.checkmark_circle_24_regular,
    labelRu: 'Готово',
  ),
  RoomTopicMark(
    id: 'plan',
    icon: FluentIcons.calendar_ltr_24_regular,
    labelRu: 'Планы',
  ),
  RoomTopicMark(
    id: 'doc',
    icon: FluentIcons.document_24_regular,
    labelRu: 'Документы',
  ),
  RoomTopicMark(
    id: 'book',
    icon: FluentIcons.book_24_regular,
    labelRu: 'Записи',
  ),
  RoomTopicMark(id: 'code', icon: FluentIcons.code_24_regular, labelRu: 'Код'),
  RoomTopicMark(
    id: 'design',
    icon: FluentIcons.color_24_regular,
    labelRu: 'Дизайн',
  ),
  RoomTopicMark(
    id: 'media',
    icon: FluentIcons.image_24_regular,
    labelRu: 'Картинки',
  ),
  RoomTopicMark(
    id: 'camera',
    icon: FluentIcons.camera_24_regular,
    labelRu: 'Съёмка',
  ),
  RoomTopicMark(
    id: 'music',
    icon: FluentIcons.music_note_2_24_regular,
    labelRu: 'Музыка',
  ),
  RoomTopicMark(
    id: 'voice',
    icon: FluentIcons.mic_24_regular,
    labelRu: 'Голосовые',
  ),
  RoomTopicMark(
    id: 'game',
    icon: FluentIcons.games_24_regular,
    labelRu: 'Игры',
  ),
  RoomTopicMark(
    id: 'money',
    icon: FluentIcons.money_24_regular,
    labelRu: 'Деньги',
  ),
  RoomTopicMark(
    id: 'chart',
    icon: FluentIcons.data_trending_24_regular,
    labelRu: 'Цифры',
  ),
  RoomTopicMark(
    id: 'work',
    icon: FluentIcons.briefcase_24_regular,
    labelRu: 'Работа',
  ),
  RoomTopicMark(
    id: 'target',
    icon: FluentIcons.target_24_regular,
    labelRu: 'Цели',
  ),
  RoomTopicMark(
    id: 'link',
    icon: FluentIcons.link_24_regular,
    labelRu: 'Ссылки',
  ),
  RoomTopicMark(id: 'pin', icon: FluentIcons.pin_24_regular, labelRu: 'Важное'),
  RoomTopicMark(
    id: 'question',
    icon: FluentIcons.question_circle_24_regular,
    labelRu: 'Вопросы',
  ),
  RoomTopicMark(
    id: 'people',
    icon: FluentIcons.people_24_regular,
    labelRu: 'Люди',
  ),
  RoomTopicMark(
    id: 'coffee',
    icon: FluentIcons.drink_coffee_24_regular,
    labelRu: 'Разное',
  ),
  RoomTopicMark(id: 'food', icon: FluentIcons.food_24_regular, labelRu: 'Еда'),
  RoomTopicMark(
    id: 'travel',
    icon: FluentIcons.airplane_24_regular,
    labelRu: 'Поездки',
  ),
  RoomTopicMark(
    id: 'sport',
    icon: FluentIcons.dumbbell_24_regular,
    labelRu: 'Спорт',
  ),
  RoomTopicMark(
    id: 'heart',
    icon: FluentIcons.heart_24_regular,
    labelRu: 'Личное',
  ),
  RoomTopicMark(
    id: 'rocket',
    icon: FluentIcons.rocket_24_regular,
    labelRu: 'Запуск',
  ),
  RoomTopicMark(
    id: 'shield',
    icon: FluentIcons.shield_24_regular,
    labelRu: 'Безопасность',
  ),
  RoomTopicMark(
    id: 'globe',
    icon: FluentIcons.globe_24_regular,
    labelRu: 'Снаружи',
  ),
  RoomTopicMark(
    id: 'archive',
    icon: FluentIcons.archive_24_regular,
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
