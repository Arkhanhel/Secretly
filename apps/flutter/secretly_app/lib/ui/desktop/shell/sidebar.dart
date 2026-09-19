// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../chat/chat_list_panel.dart' show ChatKind, unreadColorFor;
import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';

enum DesktopSection { chats, rooms, calls, contacts }

/// Ширина рейки значков — 66 точек из макета.
///
/// 🔴 Одна константа на три места. Ширина была зашита числом 80 в самой рейке,
/// в расчёте раскладки правой панели и в заглушке, которая стоит вместо рейки,
/// пока не собран склад. Три числа расходятся молча: заглушка на 80 и рейка на
/// 66 дают дёрганье окна на старте, а расчёт раскладки на 80 отдаёт правой
/// панели на 14 точек меньше, чем есть.
const double kRailWidth = 66;

/// Шаг плиток рейки — 50 точек (44 плитка + 6 зазор из макета).
const double kRailStep = 50;

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.active,
    required this.onSelect,
    this.supportUnread = 0,
    this.supportAwaiting = false,
    this.onOpenSettings,
    this.onOpenProfile,
    this.unreadByTab = const <DesktopSection, int>{},
    this.connectionStatus = ConnectionStatus.connected,
    this.width = kRailWidth,
    this.spaces = const <RailSpace>[],
    this.activeSpaceConvoId,
    this.onOpenSpace,
    this.onAddFavourite,
    this.selfName = '',
    this.selfAvatarPath,
    this.selfFrameId,
  });

  /// Закреплённые комнаты. Пусто — раздела на рейке нет вовсе.
  final List<RailSpace> spaces;

  /// Какая из них открыта сейчас.
  final String? activeSpaceConvoId;

  final ValueChanged<String>? onOpenSpace;

  /// Положить переписку в избранное — плитка «+» под списком.
  final VoidCallback? onAddFavourite;

  /// Своё имя и портрет — для кнопки профиля внизу рейки.
  final String selfName;
  final String? selfAvatarPath;

  /// Премиальная рамка МОЕГО портрета.
  ///
  /// 🔴 Рамку видели все, кроме меня: у собеседников она рисуется и в списке,
  /// и в шапке, и в правой панели, а на собственной кнопке внизу рейки её не
  /// было. Украшение, которого не видно владельцу, — это украшение, за
  /// которое он платит вслепую.
  final String? selfFrameId;

  final DesktopSection active;
  final ValueChanged<DesktopSection> onSelect;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenProfile;
  final Map<DesktopSection, int> unreadByTab;

  /// Ответы поддержки: число, а при пустом числе — точка «обращение в работе».
  final int supportUnread;
  final bool supportAwaiting;
  final ConnectionStatus connectionStatus;
  final double width;

  /// · СОСТАВ И ПОРЯДОК РАЗДЕЛОВ — РЕШЕНИЕ, А НЕ НЕДОДЕЛКА (15.09.2026).
  ///
  /// В макете рейка из четырёх плиток: forum → call → group → bookmark, то
  /// есть чаты, звонки, люди, сохранённое. Здесь их тоже четыре, но другие:
  /// чаты, КОМНАТЫ, звонки, люди.
  ///
  /// Два расхождения, и у каждого своя причина.
  ///
  /// 1. «Сохранённого» нет, потому что сохранять НЕКУДА: положить сообщение
  ///    к себе нельзя ни из меню сообщения, ни откуда-либо ещё, и хранилища
  ///    таких сообщений в проекте не существует. Плитка открывала бы пустоту.
  ///    Макетный bookmark при этом в окне есть — в другом виде: закреплённые
  ///    переписки стоят плитками ниже разделов.
  ///
  /// 2. «Комнаты» отдельным разделом — потому что у них отдельный склад
  ///    выбора и отдельный список. Убрать раздел значит слить комнаты с
  ///    чатами в один список и переселить `_roomsSelection`: это перестройка
  ///    навигации, а не порядок плиток, и решать её владельцу.
  ///
  /// ПОРЯДОК ОСТАВЛЕН СВОЙ, И ЭТО ТОЖЕ РЕШЕНИЕ. ТЗ предлагало «минимум»
  /// переставить на чаты → звонки → люди → комнаты, чтобы первые три позиции
  /// совпали с макетом. Не переставлено: в макете четвёртой плиткой стоит
  /// сохранённое, а не комнаты, и «совпадение первых трёх» получилось бы
  /// приписыванием нашего самого живого раздела в хвост чужого порядка.
  ///
  /// Здешние четыре стоят по смыслу: сверху два места, где идут РАЗГОВОРЫ
  /// (чаты и комнаты), под ними два справочника, куда заходят изредка
  /// (журнал звонков и люди). Перестановка сдвинула бы заодно все Cmd 1..4,
  /// то есть сменила бы привычку ради чужой раскладки.
  ///
  /// Обратная правка — одна строка: порядок в [_items] и подписи Cmd, плюс
  /// привязки в `desktop_shell.dart`.
  static const _items = <_TabSpec>[
    _TabSpec(
      DesktopSection.chats,
      FluentIcons.chat_24_regular,
      FluentIcons.chat_24_filled,
      'Чаты',
      'Cmd 1',
    ),
    _TabSpec(
      DesktopSection.rooms,
      FluentIcons.people_24_regular,
      FluentIcons.people_24_filled,
      'Комнаты',
      'Cmd 2',
      unreadKind: ChatKind.group,
    ),
    _TabSpec(
      DesktopSection.calls,
      FluentIcons.call_24_regular,
      FluentIcons.call_24_filled,
      'Звонки',
      'Cmd 3',
    ),
    _TabSpec(
      DesktopSection.contacts,
      FluentIcons.person_24_regular,
      FluentIcons.person_24_filled,
      'Контакты',
      'Cmd 4',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.sidebar,
        // 🔴 Правая граница из макета. Рейка и список чатов — два разных
        // тёмных поля, и без черты между ними край рейки читается только по
        // разнице в один-два шага тона: на плохом мониторе его не видно
        // вовсе, и плитки висят в воздухе.
        border: Border(right: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (final t in _items)
            _SidebarTab(
              spec: t,
              active: active == t.id,
              unread: unreadByTab[t.id] ?? 0,
              onTap: () => onSelect(t.id),
            ),
          if (spaces.isNotEmpty || onAddFavourite != null) ...[
            // Черта отделяет разделы приложения от избранных переписок: выше
            // «куда пойти», ниже «к кому». Без неё плитки читаются как ещё
            // четыре раздела.
            // Разделитель 24×1 из макета, отступы 7. Был 28 точек тоном
            // обводки контролов — длиннее и тише, чем в макете, то есть
            // читался краем чего-то, а не чертой между двумя смыслами.
            Container(
              width: 24,
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 7),
              color: Colors.white.withValues(alpha: 0.09),
            ),
            for (final sp in spaces)
              _SpaceTile(
                space: sp,
                active: sp.convoId == activeSpaceConvoId,
                onTap: () => onOpenSpace?.call(sp.convoId),
              ),
            // 🔴 «+» ИЗ МАКЕТА — единственный способ ПОЛОЖИТЬ сюда переписку,
            // не зная заранее, что это делается закреплением из меню чата.
            // Пунктирная рамка и есть приглашение: пустое место, которое можно
            // занять.
            if (onAddFavourite != null) _AddFavouriteTile(onTap: onAddFavourite!),
          ],
          const Spacer(),
          _SidebarBottom(
            icon: FluentIcons.settings_24_regular,
            tooltip: 'Настройки   Cmd ,',
            onTap: onOpenSettings,
            badgeCount: supportUnread,
            badgeDot: supportAwaiting,
          ),
          // · СОСТОЯНИЕ СВЯЗИ ПЕРЕЕХАЛО НА СВОЙ ПОРТРЕТ (макет).
          //
          // Отдельная точка 8×8 висела над «Настройками» сама по себе: она
          // ничему не принадлежала, и что именно она означает, догадаться
          // было нельзя — только навести и прочитать подсказку. В макете
          // такой точки нет вовсе, а на своём портрете есть точка 12×12.
          //
          // 🔴 НО ЗНАЧЕНИЕ ОСТАЁТСЯ ПРЕЖНИМ — состояние СОЕДИНЕНИЯ, а не
          // константа «я в сети». Это единственное место, где десктоп вообще
          // говорит «нет соединения», и убрать его молча нельзя: подсказка
          // переехала на портрет вместе с точкой.
          _ProfileTile(
            name: selfName,
            avatarPath: selfAvatarPath,
            frameId: selfFrameId,
            connectionStatus: connectionStatus,
            onTap: onOpenProfile,
          ),
          const SizedBox(height: DSpace.m),
        ],
      ),
    );
  }
}

/// Комната, закреплённая на рейке.
///
/// 🔴 ЭТО ЗАКРЕПЛЁННЫЕ КОМНАТЫ, А НЕ НОВАЯ СУЩНОСТЬ.
///
/// В макете на рейке стоят плитки «SC» и «RD» — и там же, в списке чатов,
/// лежат комнаты «Secretly Core» и «Release Radar» с ТЕМИ ЖЕ градиентами.
/// То есть рейка макета — это быстрый доступ к своим главным комнатам, а не
/// отдельные «пространства» с собственной моделью.
///
/// Читать макет вторым способом было бы дороже на порядок: пространства это
/// разделение всего содержимого приложения по контекстам, своя модель, свой
/// синхрон с телефоном. Закрепление же уже есть и работает — и на телефоне
/// тоже. Плитка появляется, когда комнату закрепляют, и исчезает, когда
/// открепляют; ничего нового изобретать не пришлось.
class RailSpace {
  const RailSpace({
    required this.convoId,
    required this.title,
    required this.unread,
    this.avatarPath,
    this.isRoom = true,
  });

  final String convoId;
  final String title;
  final int unread;
  final String? avatarPath;

  /// Комната или человек. Форма портрета = тип разговора — то же правило, что
  /// в списке: в избранное теперь можно вынести и переписку с человеком, и
  /// круглый портрет среди квадратных обязан остаться круглым.
  final bool isRoom;
}

/// Всё, что рейка показывает, одним снимком.
///
/// 🔴 Снимок существует, чтобы рейка НЕ ИМПОРТИРОВАЛА контроллер.
///
/// Десктоп ходит к приложению через один шов, и сторожевой тест считает каждый
/// виджет, который тянет контроллер напрямую. Причина не в чистоте: виджет с
/// контроллером на руках дотягивается до любого его метода и заводит свою
/// подписку — так десктоп однажды набрал восемнадцать подписок и 23 % процессора
/// на холостом ходу.
///
/// Своё имя и портрет лежат ЗДЕСЬ, а не приходят отдельными параметрами: иначе
/// они обновлялись бы только при перерисовке корня, а корень намеренно не
/// перерисовывается на тике контроллера. В снимке они обновляются вместе со
/// всем остальным.
class RailSnapshot {
  const RailSnapshot({
    this.directUnread = 0,
    this.roomUnread = 0,
    this.spaces = const <RailSpace>[],
    this.selfName = '',
    this.selfAvatarPath,
    this.selfFrameId,
    this.supportUnread = 0,
    this.supportAwaiting = false,
  });

  final int directUnread;
  final int roomUnread;
  final List<RailSpace> spaces;
  final String selfName;
  final String? selfAvatarPath;

  /// Премиальная рамка МОЕГО портрета.
  ///
  /// 🔴 Рамку видели все, кроме меня: у собеседников она рисуется и в списке,
  /// и в шапке, и в правой панели, а на собственной кнопке внизу рейки её не
  /// было. Украшение, которого не видно владельцу, — это украшение, за
  /// которое он платит вслепую.
  final String? selfFrameId;

  /// Непрочитанные ответы поддержки и «обращение в работе».
  ///
  /// 🔴 ЗАЧЕМ НА РЕЙКЕ. Ответ приходит в настройки — туда, куда никто не
  /// заглядывает без повода. На телефоне о нём говорит точка у входа в
  /// настройки, на компьютере не говорило ничто: человек писал в поддержку и
  /// не узнавал, что ему ответили.
  final int supportUnread;
  final bool supportAwaiting;

  /// Подпись включает РОВНО то, что видно на рейке. Всё остальное в переписках
  /// может меняться сколько угодно — рейки это не касается.
  String get signature {
    final buffer = StringBuffer()
      ..write(directUnread)
      ..write('/')
      ..write(roomUnread)
      ..write('/')
      ..write(selfName)
      ..write('/')
      ..write(selfAvatarPath ?? '')
      ..write('/')
      ..write(selfFrameId ?? '')
      ..write('/')
      ..write(supportUnread)
      ..write('/')
      ..write(supportAwaiting);
    for (final sp in spaces) {
      buffer
        ..write('|')
        ..write(sp.convoId)
        ..write(':')
        ..write(sp.unread)
        ..write(':')
        ..write(sp.title)
        ..write(':')
        ..write(sp.avatarPath ?? '')
        ..write(sp.isRoom);
    }
    return buffer.toString();
  }
}

enum ConnectionStatus { connected, connecting, offline }

class _TabSpec {
  const _TabSpec(
    this.id,
    this.iconRegular,
    this.iconFilled,
    this.label,
    this.shortcut, {
    this.unreadKind = ChatKind.direct,
  });
  final DesktopSection id;
  final IconData iconRegular;
  final IconData iconFilled;
  final String label;
  final String shortcut;

  /// Чей счётчик висит на плитке — от этого зависит его цвет.
  final ChatKind unreadKind;
}

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({
    required this.spec,
    required this.active,
    required this.unread,
    required this.onTap,
  });
  final _TabSpec spec;
  final bool active;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: '${spec.label}   ${spec.shortcut}',
      preferBelow: false,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) {
          // 🔴 Выбранный раздел — ЗАЛИТАЯ ПЛИТКА **И** ПОЛОСКА У КРАЯ.
          //
          // Раньше здесь стояло «или-или»: полоска отмечает раздел, но не
          // называет его выбранным, поэтому выбрали заливку. Сверка с
          // исходником показала, что в артборде 1a у активного раздела есть
          // И то, И другое — заливка градиентом со свечением и белая полоска
          // 4×18 у левого края рейки.
          //
          // Они не спорят, а отвечают на разные вопросы: заливка — «этот
          // раздел выбран», полоска у САМОГО края — «выбранное вот на этой
          // высоте», её видно боковым зрением, не наводя взгляд на колонку.
          return SizedBox(
            height: kRailStep,
            width: kRailWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: DMotion.fast,
                  width: kRailTileSize,
                  height: kRailTileSize,
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.accentPrimary, c.accentPrimaryAlt],
                          )
                        : null,
                    color: active
                        ? null
                        : (pressed
                              ? c.pressed
                              : (hovered ? c.hover : Colors.transparent)),
                    borderRadius: BorderRadius.circular(kRailTileRadius),
                    // Свечение активной плитки из макета
                    // (0 10px 24px rgba(76,141,246,.3)) — тем же приёмом, что
                    // у своего пузыря: выбранное отделяется светом, а не
                    // рамкой.
                    boxShadow: active ? DShadows.glowRailActive(c) : null,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      duration: DMotion.fast,
                      scale: pressed ? 0.92 : (hovered ? 1.06 : 1.0),
                      child: Icon(
                        active ? spec.iconFilled : spec.iconRegular,
                        // Выбранный значок на точку крупнее (макет): вес ему
                        // даёт не только заливка под ним.
                        size: active ? 22 : 21,
                        // Невыбранный — своим тоном рейки, а не общим вторым
                        // тоном текста: рейка темнее всего окна, и #93A1B3 на
                        // ней выходил ярче, чем нужно. См. `railIconIdle`.
                        color: active ? Colors.white : c.railIconIdle,
                      ),
                    ),
                  ),
                ),
                // Полоска у левого края рейки: 4×18, скруглена только
                // справа — она вырастает из края окна, а не висит отдельно.
                if (active)
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 4,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                if (unread > 0)
                  Positioned(
                    // · Бейдж ВЫЛЕТАЕТ за угол плитки (макет), а не сидит на
                    // ней: на плитке он накрывает значок раздела, ради
                    // которого плитка и существует.
                    right: (kRailWidth - kRailTileSize) / 2 - 5,
                    top: (kRailStep - kRailTileSize) / 2 - 4,
                    child: _UnreadBadge(
                      count: unread,
                      kind: spec.unreadKind,
                      rail: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Плитка «+»: положить переписку в избранное.
///
/// Пунктирная рамка взята из макета дословно (1,5 точки, rgba(255,255,255,.16))
/// и работает как приглашение: сплошная плитка читалась бы как ещё одна
/// переписка, которой тут нет.
class _AddFavouriteTile extends StatelessWidget {
  const _AddFavouriteTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: 'В избранное',
      preferBelow: false,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => SizedBox(
          height: kRailStep,
          width: kRailWidth,
          child: Center(
            child: AnimatedScale(
              duration: DMotion.fast,
              scale: pressed ? 0.92 : (hovered ? 1.06 : 1.0),
              child: CustomPaint(
                painter: _DashedTilePainter(
                  color: hovered ? c.textSecondary : c.borderDivider,
                  radius: kRailTileRadius,
                ),
                child: SizedBox(
                  width: kRailTileSize,
                  height: kRailTileSize,
                  child: Icon(
                    FluentIcons.add_24_regular,
                    size: 20,
                    color: hovered ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пунктирная рамка скруглённого квадрата.
///
/// Своя, потому что у Flutter пунктира для рамки нет вовсе: `Border` умеет
/// только сплошную.
class _DashedTilePainter extends CustomPainter {
  const _DashedTilePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedTilePainter old) =>
      old.color != color || old.radius != radius;
}

/// Размер плитки рейки и её скругление — из макета (44 × 44, радиус 15).
///
/// Одни и те же у раздела, у закреплённой комнаты и у кнопок внизу: рейка
/// должна читаться одной колонкой, а не набором разных кнопок.
///
/// 🔴 До 15.09.2026 это утверждение было НЕПРАВДОЙ: кнопки внизу были 48×48
/// радиусом 10, то есть крупнее и угловатее всех плиток над ними. Комментарий
/// описывал замысел, а не код.
const double kRailTileSize = 44;
const double kRailTileRadius = 15;

/// Избранная переписка на рейке.
///
/// Портрет по тому же правилу, что и везде: форма = тип разговора. Комната —
/// скруглённый квадрат, человек — круг.
class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    required this.space,
    required this.active,
    required this.onTap,
  });

  final RailSpace space;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: space.title,
      preferBelow: false,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => SizedBox(
          height: kRailStep,
          width: kRailWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // · НАВЕДЕНИЕ СЖИМАЕТ РАДИУС, А НЕ УВЕЛИЧИВАЕТ ПЛИТКУ (макет).
              //
              // Плитка росла до 1.06 — то есть портрет собеседника под
              // курсором становился крупнее соседних, и колонка «дышала» при
              // каждом проносе мыши. В макете под курсором меняется ТОЛЬКО
              // форма: 15 → 12, квадрат чуть острее. Движение есть, а размер
              // на месте.
              //
              // Нажатие сжимает по-прежнему: это отклик на само действие, а
              // не подсветка при проносе.
              AnimatedScale(
                duration: DMotion.fast,
                scale: pressed ? 0.92 : 1.0,
                child: AnimatedContainer(
                  duration: DMotion.fast,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      (hovered ? 12 : kRailTileRadius) + 2,
                    ),
                    // Обводка вместо заливки: плитка это портрет комнаты, и
                    // подложка под ним спорила бы с его собственным цветом.
                    border: Border.all(
                      color: active ? c.accentPrimary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Avatar(
                    name: space.title,
                    // Оттенок по переписке, а не по имени: тот же ключ, что у
                    // строки в списке и у телефона.
                    seed: space.convoId,
                    image: Avatar.fileImage(space.avatarPath),
                    size: kRailTileSize - 4,
                    shape: space.isRoom
                        ? AvatarShape.room
                        : AvatarShape.round,
                  ),
                ),
              ),
              if (space.unread > 0)
                Positioned(
                  // Бейдж вылетает за угол плитки — как у разделов.
                  right: (kRailWidth - kRailTileSize) / 2 - 5,
                  top: (kRailStep - kRailTileSize) / 2 - 4,
                  child: _UnreadBadge(
                    count: space.unread,
                    kind: space.isRoom ? ChatKind.group : ChatKind.direct,
                    // Красный, как и у плиток разделов: рейка говорит одним
                    // цветом. Число здесь при этом про СООБЩЕНИЯ — см.
                    // [_UnreadBadge.rail].
                    rail: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Свой портрет внизу рейки вместо безликого значка человека.
///
/// Рейка — единственное место окна, которое видно всегда, и собственный
/// портрет здесь отвечает на вопрос «под кем я вошёл». У человека с
/// несколькими профилями это не праздный вопрос.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.avatarPath,
    required this.frameId,
    required this.connectionStatus,
    required this.onTap,
  });

  final String name;
  final String? avatarPath;
  final String? frameId;

  /// Состояние связи — точкой на портрете. Это ЕДИНСТВЕННОЕ место, где
  /// десктоп говорит «нет соединения», поэтому цвет здесь настоящий, а не
  /// зелёная константа «я в сети».
  final ConnectionStatus connectionStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final (dotColor, statusLabel) = switch (connectionStatus) {
      ConnectionStatus.connected => (c.success, 'Подключено'),
      ConnectionStatus.connecting => (c.warning, 'Подключение…'),
      ConnectionStatus.offline => (c.danger, 'Нет соединения'),
    };
    return DesktopTooltip(
      message: 'Профиль   Cmd P   ·   $statusLabel',
      preferBelow: false,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => SizedBox(
          height: kRailStep,
          width: kRailWidth,
          child: Center(
            child: AnimatedScale(
              duration: DMotion.fast,
              scale: pressed ? 0.92 : (hovered ? 1.06 : 1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Avatar(
                    name: name.isEmpty ? '?' : name,
                    image: Avatar.fileImage(avatarPath),
                    frameId: frameId,
                    allowAnimatedFrame: true,
                    // 38 из макета: на две точки крупнее плиток разделов —
                    // свой портрет в рейке единственный, кто изображает
                    // ЧЕЛОВЕКА, и ровно на эти две точки он и выделяется.
                    size: 38,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        // Обводка цветом рейки: без неё точка на светлом
                        // краю портрета теряется.
                        border: Border.all(color: c.sidebar, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.kind,
    this.rail = false,
  });
  final int count;

  /// Тип разговора здесь НЕ красит ничего — рейка вся красная, см. [rail].
  /// Поле осталось, чтобы счётчик умел покраситься по типу, если его
  /// когда-нибудь поставят вне рейки.
  final ChatKind kind;

  /// 🔴 НА РЕЙКЕ ВСЁ КРАСНОЕ, НО ЧИСЛА ЗНАЧАТ РАЗНОЕ.
  ///
  /// Цвет на рейке один — красный: это её собственный язык, и в макете все её
  /// бейджи красные (или сиренево-розовые, когда есть упоминания). Голубое и
  /// фиолетовое живут в СПИСКЕ, где рядом стоит имя и видно, чей это
  /// разговор; на рейке рядом ничего нет, и три цвета там читались бы как три
  /// вида тревоги.
  ///
  /// А считают числа разное, и это не путаница:
  ///
  /// * у плитки РАЗДЕЛА — сколько РАЗГОВОРОВ ждут ответа. Плитка «Чаты» — не
  ///   разговор, а вход в список; сумма сообщений по всем чатам там ничего не
  ///   сообщает («347» бывает у любого, кто неделю не заходил).
  /// * у ЗАКРЕПЛЁННОЙ переписки — сколько в ней непрочитанных сообщений.
  ///   Плитка И ЕСТЬ разговор, и «сколько разговоров ждёт» дало бы вечную
  ///   единицу.
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    // Обводка цветом рейки в 2.5 точки — из макета: бейдж вылетает за угол
    // плитки, и без неё он сливается с тем, поверх чего лежит.
    //
    // 🔴 ГРАДИЕНТА «ЕСТЬ УПОМИНАНИЯ» ЗДЕСЬ НЕТ НАМЕРЕННО. В макете бейдж с
    // упоминаниями залит переходом #7C5CE0 → #EC4899, но в `RailSpace` и
    // `RailSnapshot` лежит одно число — сколько непрочитано, — и отличить
    // «звали лично» от «просто много» нечем. Крашеный по догадке бейдж
    // обещал бы личное обращение там, где его может не быть.
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rail ? c.unreadRail : unreadColorFor(kind, c),
        borderRadius: BorderRadius.circular(DRadii.md),
        border: Border.all(color: c.sidebar, width: 2.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: DType.family,
          fontSize: 10,
          height: 1.0,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SidebarBottom extends StatelessWidget {
  const _SidebarBottom({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badgeCount = 0,
    this.badgeDot = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Число ответов; 0 — числа нет.
  final int badgeCount;

  /// Точка без числа: «обращение в работе, ответа ещё нет». Показывается
  /// только когда числа нет — иначе две отметки налезли бы друг на друга.
  final bool badgeDot;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: tooltip,
      preferBelow: false,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) {
          // · ТА ЖЕ ПЛИТКА, ЧТО У РАЗДЕЛА (макет): 44×44, радиус 15, значок 21.
          //
          // Была 48×48 радиусом 10 со значком 22 — то есть крупнее и угловатее
          // всех плиток над ней. В колонке, где всё остальное одного размера,
          // это читалось как «кнопка из другого набора», и низ рейки выглядел
          // приклеенным.
          return AnimatedContainer(
            duration: DMotion.fast,
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: kRailTileSize,
            height: kRailTileSize,
            decoration: BoxDecoration(
              color: hovered ? c.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(kRailTileRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 21, color: c.railIconIdle)),
                if (badgeCount > 0)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: _UnreadBadge(
                      count: badgeCount,
                      kind: ChatKind.direct,
                      rail: true,
                    ),
                  )
                else if (badgeDot)
                  Positioned(
                    right: 0,
                    top: 1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: c.unreadRail,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.sidebar, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

