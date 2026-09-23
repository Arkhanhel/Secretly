// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../premium/live_covers.dart' show CoverAvatarGeometry;
import '../../../premium/live_frames.dart';
import '../../../premium/cosmetics_catalog.dart' show frameById;
import '../../primitives/context_menu.dart';
import '../../primitives/desktop_tooltip.dart';
import '../../primitives/hover_listener.dart';
import '../../primitives/verified_badge.dart';
import '../../design/tokens.dart';

/// Верх панели подробностей: обложка, аватар, имя, значки, присутствие.
///
/// 🔴 ОБЛОЖКА — ЭТО ФОН, А НЕ ПОЛОСА НАД АВАТАРОМ.
///
/// Раньше обложка рисовалась карточкой в 120 точек НАД аватаром, с отступами
/// по бокам. Получалась «сплюснутая к верху» плашка, к которой аватар и имя не
/// имели отношения: три отдельных предмета, поставленных друг под друга.
///
/// Обложка человека — это фон его карточки, ровно как в любом профиле: она
/// лежит ПОД аватаром и именем и уходит за края панели. Поэтому здесь [Stack],
/// где обложка растянута под всё содержимое ([Positioned.fill]), а не занимает
/// свою высоту сверху.
///
/// Высоту задаёт содержимое, а не число в коде: [Stack] меряется по колонке с
/// аватаром и именем, обложка подстраивается. Поэтому блок не ломается ни от
/// длинного имени в две строки, ни от отсутствия присутствия у комнаты.
///
/// **Затухание обязательно.** Без него имя ложится прямо на картинку и
/// перестаёт читаться на светлых обложках. Переход идёт от прозрачного вверху
/// к цвету панели внизу — так обложка «растворяется» в панели, а не обрывается
/// линией.
class DetailsHeadline extends StatelessWidget {
  const DetailsHeadline({
    super.key,
    required this.name,
    required this.avatar,
    this.cover,
    this.presence,
    this.presenceIsOnline = false,
    this.emojiStatus,
    this.premiumBadge = false,
    this.verified = false,
    this.frameId,
    this.onClose,
    this.onShare,
    this.shareTooltip,
    this.coverFront,
    this.onEdit,
    this.onChangeCover,
    this.menuSections = const <List<CtxMenuItem>>[],
    this.idLine,
    this.trailing,
    this.avatarDiameter,
  });

  final String name;

  /// Диаметр портрета. Нужен только сценам обложки, построенным ВОКРУГ фото:
  /// без него луна всходит мимо лица, а прожектор светит в пустоту. `null` —
  /// сцена берёт своё значение по умолчанию.
  final double? avatarDiameter;

  /// Готовый аватар — вместе с обработчиком нажатия и рамкой. Панель
  /// подробностей строит его сама, потому что у контакта и комнаты разные
  /// размеры, украшения и поведение по нажатию.
  final Widget avatar;

  /// Обложка профиля или комнаты. `null` — блок просто без фона.
  final Widget? cover;

  final String? presence;
  final bool presenceIsOnline;
  final String? emojiStatus;
  final bool premiumBadge;

  /// Коды безопасности с этим человеком сверены.
  final bool verified;

  /// Косметическая рамка аватара: её имя выносится отдельным значком.
  final String? frameId;

  /// Закрыть панель. `null` — кнопки закрытия нет.
  final VoidCallback? onClose;

  /// Поделиться (ссылка-приглашение, визитка). `null` — кнопки нет.
  final VoidCallback? onShare;

  /// Что именно делает «поделиться» — подпись должна называть действие, а не
  /// намерение: у комнаты это ссылка-приглашение, у человека — его ID.
  /// `null` — подпись по умолчанию («Поделиться») на языке окна.
  final String? shareTooltip;

  /// Сменить обложку — кнопка ПОВЕРХ самой обложки, как в макете.
  ///
  /// 🔴 Обложку меняли только из ряда действий ниже, и связи между кнопкой и
  /// картинкой не было никакой: человек видит обложку, хочет её поменять — и
  /// ищет, где. `null` — кнопки нет (чужой профиль её и не должен иметь).
  ///
  /// Показывается только когда обложка ЕСТЬ: на пустом месте «сменить» нечего,
  /// там работает «Обложка» в ряду действий.
  /// Передний слой обложки — рисуется ПОВЕРХ портрета.
  ///
  /// 🔴 ЧТОБЫ ПОРТРЕТ ОКАЗАЛСЯ ВНУТРИ СЦЕНЫ, А НЕ НА НЕЙ. У чёрной дыры ближний
  /// край диска должен проходить ПЕРЕД лицом — тогда портрет читается как
  /// находящийся в горизонте событий, а не наклеенный сверху. На телефоне это
  /// сделано давно (`coverFrontWidgetFor`, `profile_screen.dart`), на
  /// компьютере обложка рисовалась одним слоем, и портрет лежал поверх всего.
  ///
  /// `null` для обложек без переднего слоя — тогда ничего и не рисуется.
  final Widget? coverFront;

  /// «Редактировать» — плиткой в верхнем ряду, СЛЕВА от обложки.
  ///
  /// 🔴 Раньше это была кнопка с подписью рядом с именем. Она стояла в потоке
  /// содержимого и отодвигала портрет вниз, а главное — читалась как часть
  /// имени, хотя относится ко всему профилю. В верхнем ряду уже лежат кнопки
  /// про панель и обложку; правка профиля — из того же разряда.
  final VoidCallback? onEdit;

  final VoidCallback? onChangeCover;

  /// Разделы меню «Дополнительно». Пустой список — кнопки нет.
  final List<List<CtxMenuItem>> menuSections;

  /// ◆ МОНО-СТРОКА ИДЕНТИФИКАТОРА ПОД ИМЕНЕМ (макет). `null` — строки нет.
  ///
  /// В макете под именем стоит не присутствие, а то, ЧТО ЭТО ЗА ЧЕЛОВЕК. Своё
  /// присутствие и так очевидно, а свой идентификатор — единственное, чем
  /// человек делится, чтобы с ним связались, и искать его в «Информации» ниже
  /// приходилось каждый раз.
  ///
  /// Чужим профилям не передаётся: там под именем полезнее присутствие.
  final String? idLine;

  /// ◆ Кнопка справа от имени — «Редактировать». `null` — кнопки нет.
  ///
  /// Правка шла нажатием по строкам «Имя» и «О себе» ниже, и узнать об этом
  /// было нельзя: строки выглядели фактами, а не полями.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final frame = frameById(frameId);
    final status = (emojiStatus ?? '').trim();
    final presenceText = (presence ?? '').trim();
    final hasActions =
        onClose != null ||
        onShare != null ||
        onEdit != null ||
        onChangeCover != null ||
        menuSections.isNotEmpty;

    // 🔴 Ширину задаём ЯВНО, а не надеемся на родителя.
    //
    // В варианте с обложкой блок лежит в [Stack]. Стопка отдаёт
    // непозиционированному ребёнку свободные ограничения и прижимает его к
    // левому верхнему углу. Колонка с `MainAxisSize.min` схлопывается по самому
    // широкому ребёнку — и аватар с именем оказываются у левого края панели,
    // хотя ВНУТРИ колонки они честно по центру.
    //
    // `width: double.infinity` заставляет блок занять всю ширину панели. Тогда
    // и центрирование колонки, и `WrapAlignment.center` у значков начинают
    // означать «по центру панели», а не «по центру схлопнутого столбика».
    final content = SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          // Под кнопками на обложке: они лежат поверх этого же блока, и без
          // запаса портрет уезжал бы им под низ на узкой панели.
          // 🔴 ПОРТРЕТ НИЖЕ ВЕРХНЕГО РЯДА, А НЕ ВПРИТЫК К НЕМУ.
          //
          // Запас считался так, чтобы портрет лишь НЕ НАЕЗЖАЛ на кнопки — то
          // есть по нижнему допустимому краю. Выглядело, будто портрет
          // подпирает их снизу, а на обложке он ещё и накрывал её верхнюю
          // часть, ради которой обложку и выбирают.
          // 🔴 С ОБЛОЖКОЙ ПОРТРЕТ ОПУСКАЕТСЯ К СЕРЕДИНЕ СЦЕНЫ.
          //
          // У чёрной дыры смысл именно в этом: портрет должен попасть В ДЫРУ, а
          // не висеть над ней. Запас считался от кнопок («лишь бы не наезжал»),
          // и портрет оказывался выше центра сцены.
          top: hasActions
              ? (cover != null ? DSpace.xl3 * 2 + DSpace.s : DSpace.xl2)
              : (cover != null ? DSpace.xl2 : DSpace.l),
          left: DSpace.l,
          right: DSpace.l,
          bottom: DSpace.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(height: DSpace.m),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: DType.display.copyWith(color: c.textPrimary),
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(status, style: const TextStyle(fontSize: 20)),
                ],
                // Галочка = ПРОВЕРЕННЫЙ КОНТАКТ. Платный тариф ниже, чипом
                // PRO: знак «личность подтверждена» за подписку — ложное
                // обещание безопасности.
                if (verified) ...[
                  const SizedBox(width: 6),
                  const DesktopVerifiedBadge(size: 18),
                ],
              ],
            ),
            if (presenceText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                presenceText,
                textAlign: TextAlign.center,
                style: DType.caption.copyWith(
                  color: presenceIsOnline ? c.voice : c.textSecondary,
                ),
              ),
            ],
            if ((idLine ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              // Моноширинным: это не слово, а КОД, и его переписывают на слух
              // или сверяют знак за знаком.
              Text(
                idLine!.trim(),
                textAlign: TextAlign.center,
                style: DType.mono.copyWith(
                  fontSize: 11.5,
                  color: c.textTertiary,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: DSpace.s),
              trailing!,
            ],
            if (premiumBadge || frame != null) ...[
              const SizedBox(height: DSpace.s),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                alignment: WrapAlignment.center,
                children: [
                  if (premiumBadge)
                    _Badge(
                      label: 'PRO',
                      icon: Icons.workspace_premium_rounded,
                      color: c.accentPrimaryAlt,
                    ),
                  if (frame != null)
                    // 🔴 `Builder` здесь не украшение: он даёт контекст НИЖЕ
                    // держателя нажатия, который обёрнут вокруг всей шапки.
                    // Без него значок искал бы область выше себя и не нашёл.
                    Builder(
                      builder: (ctx) {
                        final press = LiveFramePressScope.controllerOf(ctx);
                        final active = LiveFramePressScope.of(ctx);
                        final action = liveFrameActionLabel(ctx, frame.id);
                        return _Badge(
                          // Имя рамки — подпись окна, а окно переведено на
                          // восемь языков; `nameRu` держал здесь русский.
                          label: l10n.desktopDetailsFrame(
                            frame.nameLocalized(ctx),
                          ),
                          icon: Icons.bolt_rounded,
                          color: c.warning,
                          active: active,
                          // Действие есть только у живых рамок: у остальных
                          // двадцати нажимать нечего, и значок остаётся
                          // подписью, как был.
                          tooltip: action,
                          onTap: action == null || press == null
                              ? null
                              : () => press.value = !press.value,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // 🔴 ДЕЙСТВИЯ ПАНЕЛИ ЛЕЖАТ НА ОБЛОЖКЕ, А НЕ В ОТДЕЛЬНОЙ СТРОКЕ НАД НЕЙ.
    //
    // Над обложкой стояла строка-шапка в 56 точек с крестиком, ИМЕНЕМ,
    // подписью присутствия и «⋮». Имя и присутствие при этом уже написаны
    // под портретом двумя строками ниже, а третий раз — в шапке самой
    // переписки. Панель начиналась с повтора и отдавала ему высоту экрана,
    // хотя человек открыл её ради того, что НИЖЕ.
    //
    // Теперь три кнопки лежат поверх обложки, как в макете: закрыть слева,
    // «поделиться» и «дополнительно» справа. Имя выводится один раз.
    //
    // [DetailsHeader] жив и нужен — по нему построен свой профиль
    // (`self_profile_view.dart`), где шапка несёт другую задачу.
    final actions = hasActions
        ? Positioned(
            top: DSpace.s,
            left: DSpace.s,
            right: DSpace.s,
            child: Row(
              children: [
                if (onClose != null)
                  _CoverAction(
                    icon: FluentIcons.dismiss_24_regular,
                    tooltip: l10n.desktopDetailsHide,
                    onPressed: onClose!,
                    onCover: cover != null,
                  ),
                const Spacer(),
                // 🔴 «СМЕНИТЬ ОБЛОЖКУ» — ПЛИТКОЙ В ОДНОМ РЯДУ, А НЕ ПОДПИСЬЮ
                // НА ОБЛОЖКЕ, КАК В МАКЕТЕ.
                //
                // В макете обложка — полоса своей высоты, и у неё есть
                // свободный нижний угол под кнопку с подписью. У нас обложка
                // это ФОН всего блока (решение 13.09), и свободного угла нет
                // ни одного: снизу чипы «PRO» и «Рамка», по центру портрет.
                // Проверено живьём — подпись накрывала сперва чипы, потом
                // портрет.
                //
                // Поэтому та же плитка 28×28, что у соседей, а слова — в
                // подсказке. Ряд от этого не теряет смысла: все четыре кнопки
                // здесь про саму обложку и про панель.
                if (onEdit != null) ...[
                  _CoverAction(
                    icon: FluentIcons.edit_24_regular,
                    tooltip: l10n.desktopProfileEdit,
                    onPressed: onEdit!,
                    onCover: cover != null,
                  ),
                  const SizedBox(width: 5),
                ],
                if (onChangeCover != null) ...[
                  _CoverAction(
                    icon: FluentIcons.image_24_regular,
                    tooltip: l10n.desktopDetailsChangeCover,
                    onPressed: onChangeCover!,
                    onCover: cover != null,
                  ),
                  const SizedBox(width: 5),
                ],
                if (onShare != null)
                  _CoverAction(
                    icon: FluentIcons.share_24_regular,
                    tooltip: shareTooltip ?? l10n.desktopDetailsShare,
                    onPressed: onShare!,
                    onCover: cover != null,
                  ),
                if (onShare != null && menuSections.isNotEmpty)
                  const SizedBox(width: 5),
                if (menuSections.isNotEmpty)
                  _CoverMenuAction(sections: menuSections, onCover: cover != null),
              ],
            ),
          )
        : null;

    // Живую рамку будит значок с её названием. Держатель кладёт нажатие НАД
    // всей шапкой: портрет и значок стоят в разных её ветках, и общий предок —
    // единственное место, откуда о нажатии узнают оба.
    Widget wrap(Widget body) => isLiveFrameId(frameId)
        ? LiveFramePressHost(frameId: frameId, child: body)
        : body;

    if (cover == null) {
      if (actions == null) return wrap(content);
      return wrap(Stack(children: [content, actions]));
    }

    return wrap(Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🔴 Геометрия портрета — от НАСТОЯЩЕГО размера шапки, а не от
                // догадки: высота здесь зависит от содержимого (ник, эмодзи,
                // значки), и посчитать её заранее нельзя.
                if (avatarDiameter != null)
                  LayoutBuilder(
                    builder: (ctx, bc) => CoverAvatarGeometry(
                      center: Offset(
                        0.5,
                        (DSpace.xl3 * 2 + DSpace.s + avatarDiameter! / 2) /
                            bc.maxHeight,
                      ),
                      radius: avatarDiameter! / 2 / bc.maxWidth,
                      child: cover!,
                    ),
                  )
                else
                  cover!,
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.chatList.withValues(alpha: 0.0),
                        c.chatList.withValues(alpha: 0.55),
                        c.chatList,
                      ],
                      stops: const [0.0, 0.62, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        content,
        // 🔴 ПЕРЕДНИЙ СЛОЙ — МЕЖДУ СОДЕРЖИМЫМ И КНОПКАМИ.
        //
        // Выше портрета, чтобы край диска прошёл перед лицом; ниже верхнего
        // ряда, чтобы не закрыть кнопки. `IgnorePointer` — слой прозрачный и
        // нажатия по портрету должен пропускать насквозь.
        if (coverFront != null)
          Positioned.fill(
            child: IgnorePointer(child: ClipRect(child: coverFront!)),
          ),
        if (actions != null) actions,
      ],
    ));
  }
}

/// Кнопка-плитка поверх обложки: 28×28, радиус 9 — размеры из макета.
///
/// Заливка зависит от того, есть ли под кнопкой картинка: на обложке это
/// тёмная плёнка (иначе значок теряется на светлом снимке), на пустой панели —
/// обычная приподнятая поверхность, потому что чёрный квадрат посреди панели
/// выглядел бы дырой.
class _CoverAction extends StatelessWidget {
  const _CoverAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.onCover,
    this.anchorKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool onCover;
  final Key? anchorKey;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final tile = HoverListener(
      onTap: onPressed,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onCover
              ? Colors.black.withValues(alpha: hovered ? 0.55 : 0.4)
              : (hovered ? c.hover : c.elevated),
          borderRadius: BorderRadius.circular(9),
          border: onCover ? null : Border.all(color: c.borderSubtle),
        ),
        child: Icon(
          icon,
          size: 17,
          color: onCover ? Colors.white : c.textPrimary,
        ),
      ),
    );
    return DesktopTooltip(
      message: tooltip,
      child: anchorKey == null ? tile : KeyedSubtree(key: anchorKey!, child: tile),
    );
  }
}

/// «Дополнительно» на обложке: та же плитка, но со своим якорем под меню.
class _CoverMenuAction extends StatefulWidget {
  const _CoverMenuAction({required this.sections, required this.onCover});

  final List<List<CtxMenuItem>> sections;
  final bool onCover;

  @override
  State<_CoverMenuAction> createState() => _CoverMenuActionState();
}

class _CoverMenuActionState extends State<_CoverMenuAction> {
  final GlobalKey _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CoverAction(
      icon: FluentIcons.more_vertical_24_regular,
      tooltip: l10n.desktopDetailsMore,
      onCover: widget.onCover,
      anchorKey: _anchor,
      onPressed: _open,
    );
  }

  Future<void> _open() async {
    final rb = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final origin = rb.localToGlobal(Offset.zero);
    // Якорь — правый нижний угол плитки; дальше меню само не выходит за экран.
    final pos = origin.translate(rb.size.width, rb.size.height + 4);
    if (!mounted) return;
    await ContextMenu.show(context, globalPosition: pos, sections: widget.sections);
  }
}

/// Значок под именем: «PRO», «Рамка «Аврора»».
///
/// 🔴 ОБВОДКИ БОЛЬШЕ НЕТ (14.09.2026, по исходнику макета). Здесь стояла
/// заливка .14 ПЛЮС обводка .32 — и объяснялось это тем, что значок должен
/// читаться поверх обложки. В макете обводки нет ни у одного чипа: читаемость
/// там держит светлый цвет БУКВ, а не рамка вокруг них. Рамка же добавляла
/// третью линию рядом с именем и превращала спокойную подпись в наклейку —
/// ровно в то, чего опасался прежний комментарий.
///
/// Цвет приходит снаружи и должен быть СВЕТЛЫМ (#C4B5FD у PRO, #FCD34D у
/// рамки): на тёмной плашке тёмно-сиреневый акцент кнопок не читался.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// `null` — значок остаётся подписью и не отзывается на мышь.
  final VoidCallback? onTap;

  /// Что произойдёт по нажатию — «Погладить», «Дедлайн!», «Пауза».
  final String? tooltip;

  /// Персонаж сейчас разбужен: заливка гуще, чтобы состояние было видно, а не
  /// угадывалось по самой рамке.
  final bool active;

  @override
  Widget build(BuildContext context) {
    // 🔴 Буквы СВЕТЛЕЕ заливки, и светлеют они здесь, а не в вызове.
    //
    // В макете чип PRO написан #C4B5FD на сиреневой плёнке, а «Рамка» —
    // #FCD34D на янтарной. Снаружи приходят акценты интерфейса (#7C5CE0,
    // #F59E0B) — те же цвета, но на две ступени темнее: ими залиты кнопки на
    // светлом фоне, и на тёмной плёнке чипа они тонули.
    //
    // Осветление живёт в одном месте, чтобы два чипа не разъехались, и идёт
    // по светлоте, а не подмешиванием белого: подмешивание обесцвечивает, и
    // сиреневый становился серым.
    final hsl = HSLColor.fromColor(color);
    final ink = hsl
        .withLightness(hsl.lightness < 0.7 ? 0.78 : hsl.lightness)
        .toColor();
    Widget chip(bool hovered) => Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: active ? 0.34 : (hovered ? 0.24 : 0.16),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: DType.tiny.copyWith(
              fontSize: 10.5,
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip(false);
    final button = Semantics(
      container: true,
      button: true,
      toggled: active,
      label: tooltip == null ? label : '$label. $tooltip',
      child: ExcludeSemantics(
        child: HoverListener(
          onTap: onTap,
          cursor: SystemMouseCursors.click,
          builder: (ctx, hovered, pressed) => chip(hovered || pressed),
        ),
      ),
    );
    final hint = tooltip;
    return hint == null
        ? button
        : DesktopTooltip(message: hint, child: button);
  }
}
