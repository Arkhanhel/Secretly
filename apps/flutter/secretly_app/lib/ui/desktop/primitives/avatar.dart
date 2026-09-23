// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../premium/cosmetics_catalog.dart' show frameById;
import '../../../l10n/app_localizations.dart';
import '../../widgets/avatar_initials.dart';
import '../../widgets/shared_palette.dart';
import '../design/tokens.dart';
import '../services/desktop_ui_prefs.dart';

/// The single pixel size every animated avatar frame is rendered at on desktop.
///
/// Chosen as the largest size actually used (the details/profile avatar), so
/// every other placement downscales rather than upscales and no ring ever
/// looks soft. See the call site for why one size matters so much.
const double kDesktopFrameCanonicalPx = 96;

/// Форма портрета: она же — тип разговора.
///
/// 🔴 ФОРМА НЕСЁТ СМЫСЛ, А НЕ ВКУС.
///
/// В списке из сорока строк тип разговора надо понимать боковым зрением, не
/// читая. Значок «#» перед названием для этого не годится: он стоит в строке
/// текста, его надо найти глазами. Форма портрета срабатывает раньше чтения —
/// и это единственное, что отличает «написать человеку» от «написать в
/// комнату», где сообщение увидят двадцать человек. Цена ошибки здесь
/// несимметрична, поэтому и отличие сделано грубым.
///
/// 🔴 Цвет при этом ОБЩИЙ. Градиент считается из имени функцией, общей с
/// телефоном; заведи десктоп отдельную палитру для комнат — и одна и та же
/// комната стала бы зелёной на столе и синей в кармане. Люди узнают свои чаты
/// по цветному пятну, и расхождение между устройствами ломает именно это.
/// Различает форма, цвет остаётся общим.
enum AvatarShape {
  /// Человек. Круг.
  round,

  /// Комната, группа, канал. Скруглённый квадрат.
  room,
}

/// Single, canonical avatar widget. Replaces 15 in-tree implementations.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.image,
    this.size = 36,
    this.showStatus = false,
    this.statusColor,
    this.online = false,
    this.muted = false,
    this.verified = false,
    this.selected = false,
    this.unreadCount = 0,
    this.gradient,
    this.onTap,
    this.frameId,
    this.allowAnimatedFrame = false,
    this.shape = AvatarShape.round,
    this.ringColor,
    this.seed,
    this.background,
  });

  /// Фон, на котором лежит портрет, если это не фон окна.
  ///
  /// Заливка заглушки — оттенок поверх фона. Сцена созвона чёрная в любой
  /// теме, и заливка от светлого фона окна легла бы на неё бледным пятном.
  /// `null` — фон окна.
  final Color? background;

  /// По чему считать оттенок заглушки. `null` — по имени.
  ///
  /// 🔴 ТЕЛЕФОН СЧИТАЕТ ПО `profileId`, А ДЕСКТОП СЧИТАЛ ПО ИМЕНИ — и один и
  /// тот же человек выходил на двух устройствах РАЗНОГО цвета. А стоило
  /// переименовать собеседника, как на компьютере он менял оттенок, хотя на
  /// телефоне оставался прежним.
  ///
  /// Умолчание — имя: у мест, где устойчивого ключа нет (поиск по подсказкам,
  /// демо-данные), поведение прежнее.
  final String? seed;

  /// Цвет выреза вокруг значков-накладок (точка присутствия, «без звука»).
  ///
  /// 🔴 ЭТО ЦВЕТ ФОНА ПОД ПОРТРЕТОМ, А НЕ УКРАШЕНИЕ.
  ///
  /// Вырез существует, чтобы зелёная точка не слипалась с краем портрета, и
  /// работает он ровно тогда, когда совпадает с тем, что лежит ПОД ним. Раньше
  /// здесь был зашит `c.chatList` — цвет одной-единственной поверхности. На
  /// рейке (темнее), на выделенной строке (светлее), в шапке переписки, в
  /// правой панели и в окне созвона тот же портрет обводил точку кольцом
  /// чужого цвета, и это кольцо было видно.
  ///
  /// `null` — прежнее поведение, цвет списка чатов: он верен для самого
  /// частого места и не заставляет переписывать все вызовы разом.
  final Color? ringColor;

  /// Круг для человека, скруглённый квадрат для комнаты. По умолчанию круг:
  /// большинство мест показывают людей, а комната, нарисованная кругом, —
  /// это просто прежний вид, тогда как человек в квадрате читается как ошибка.
  final AvatarShape shape;

  /// Whether this placement may run the ANIMATED premium ring.
  ///
  /// Off by default, and deliberately opt-in per placement. Each animated ring
  /// is its own 30fps repaint, so the cost scales with how many are on screen —
  /// which is why a dense chat list is the wrong place for it and a header or
  /// profile card, where there is exactly one, is the right one.
  final bool allowAnimatedFrame;

  final String name;
  final ImageProvider? image;
  final double size;

  /// Premium avatar frame id (peer/self cosmetic). When it resolves to a known
  /// frame, an animated ring is overlaid around the avatar; null / unknown →
  /// no frame. Peer frames render regardless of the local user's entitlement.
  final String? frameId;
  final bool showStatus;
  final Color? statusColor;
  final bool online;
  final bool muted;
  final bool verified;
  final bool selected;
  final int unreadCount;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  /// Builds a file-backed [ImageProvider] for an avatar path, or null when the
  /// path is empty / missing on disk. Centralises the null/exists guard used by
  /// every desktop surface that renders a real profile photo.
  static ImageProvider? fileImage(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return FileImage(f);
    } catch (_) {
      return null;
    }
  }

  /// 🔴 БУКВЫ БЕРЁТ ОБЩИЙ СЧЁТЧИК — ТОТ ЖЕ, ЧТО НА ТЕЛЕФОНЕ.
  ///
  /// Здесь была своя выборка, и она резала строку ПО КОДОВЫМ ЕДИНИЦАМ:
  /// `parts[1][0]` и `substring(0, 2)`. Для «Игорь 🎯» это половина суррогатной
  /// пары — строка, которая не является правильным UTF-16. `Text` на такой
  /// падает: «Invalid argument(s): string is not well-formed UTF-16», и на его
  /// месте появляется КРАСНЫЙ прямоугольник `ErrorWidget`.
  ///
  /// Это вторая половина жалобы владельца 16.09.2026 про «моргает экран
  /// красным»: список чатов с эмодзи в имени ронял заглушку портрета на каждой
  /// перерисовке. Ловушка в `main_desktop.dart` назвала это дословно
  /// (`while building a TextSpan`) ещё до того, как окно успели открыть.
  ///
  /// [AvatarInitials.label] считает по видимым знакам (`characters`), а не по
  /// кодовым единицам, — и заодно снимает расхождение с телефоном: у одного и
  /// того же человека заглушка теперь буква в букву одинаковая.
  String get _initials => AvatarInitials.label(displayName: name);

  /// Deterministic gradient based on name hash. Used when no image + no
  /// explicit gradient. Delegates to the shared palette
  /// ([kSharedAvatarGradients]) so mobile and desktop stay in lock-step —
  /// the same person always hashes to the same gradient on every device.
  List<Color> _gradientFromName() {
    if (gradient != null) return gradient!;
    // Ключ тот же, что у телефона, — `profileId` / `convoId`, когда он есть.
    final key = (seed ?? '').trim();
    return sharedAvatarGradientColors(key.isEmpty ? name : key);
  }

  bool get _isRoom => shape == AvatarShape.room;

  /// Насколько портрет утоплен внутрь кольца рамки, долей размера.
  ///
  /// 🔴 У квадрата посадка ГЛУБЖЕ, и это арифметика, а не вкус.
  ///
  /// Кольцо круглое: его внутренний край идёт по окружности радиусом
  /// `0,43 × size` (те же 7 % посадки, что у круглого портрета). У скруглённого
  /// квадрата со стороной `a` и радиусом угла `0,33a` самая дальняя от центра
  /// точка отстоит на
  ///
  ///     √2 × (0,5a − 0,33a) + 0,33a ≈ 0,57a
  ///
  /// Чтобы угол не вылез за кольцо, нужно `0,57a ≤ 0,43 × size`, то есть
  /// `a ≤ 0,754 × size`. Отсюда посадка с каждой стороны — `(1 − 0,754) / 2`.
  ///
  /// Круглому портрету столько не нужно: его край и есть та же окружность.
  double get _frameInset => _isRoom ? 0.123 : 0.07;

  /// Скругление угла у комнаты — ДОЛЯ размера, а не число точек.
  ///
  /// В макете это 42×42 с радиусом 14, то есть ровно треть. Аватар живёт в
  /// шести размерах (32 в поиске, 40 в звонках, 46 в списке, 88 в шапке, 96 в
  /// подробностях): фиксированные 14 точек на 32-м выглядели бы почти
  /// квадратом, а на 96-м — почти кругом.
  static const double _kRoomRadiusRatio = 0.33;

  /// Скругление портрета комнаты при заданном размере. Открыто наружу: этим
  /// же радиусом обрезают обложку и превью, чтобы углы совпадали.
  static double roomRadius(double size) => size * _kRoomRadiusRatio;

  /// Насколько наложение (точка «в сети», значок «без звука») отодвинуто от
  /// угла портрета.
  ///
  /// 🔴 У круга и квадрата край в углу проходит по-разному: у круга он
  /// отступает внутрь примерно на 15 % размера, у квадрата угол и есть край.
  /// Общая константа поэтому невозможна — на квадрате точка уезжала бы за
  /// угол, на круге залезала бы внутрь портрета.
  double get _overlayInset => _isRoom ? -1 : 0;

  /// Доля размера, которую занимают буквы заглушки. См. разбор в [build].
  static double _inkRatio(double size) {
    const small = 22.0, large = 48.0;
    const ratioSmall = 0.385, ratioLarge = 0.312;
    final t = ((size - small) / (large - small)).clamp(0.0, 1.0);
    return ratioSmall + (ratioLarge - ratioSmall) * t;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final radius = size / 2;
    // 🔴 РАЗМЕР И ВЕС ИНИЦИАЛОВ — ИЗ МАКЕТА (14.09.2026).
    //
    // Доля НЕ постоянная. Все заглушки макета, выписанные подряд, дают такой
    // ряд: 22→8,5 · 24→9 · 26→9,5 · 32→11 · 40→14 · 42→13,5 · 44→14 · 48→15.
    // То есть у крупных портретов буквы занимают примерно 0,31 размера, у
    // мелких — 0,39. Это не небрежность художника, а то, как работает глаз:
    // в кружке 22 точки буквы при 0,32 выходят в семь точек и превращаются в
    // серую крошку, а в кружке 48 те же 0,32 дают пятнадцать — уже надпись.
    //
    // Поэтому доля идёт линейно от 0,385 на 22 точках до 0,312 на 48 и
    // зажимается по краям. Одна постоянная (0,32), стоявшая здесь раньше,
    // ошибалась на мелких портретах на пятую часть кегля — а мелкие портреты
    // это как раз рейка, плашка созвона и лица участников.
    final fontSize = size * _inkRatio(size);
    final innerGradient = _gradientFromName();
    final borderRadius = _isRoom
        ? BorderRadius.circular(roomRadius(size))
        : null;

    // 🔴 ЗАГЛУШКА ПОРТРЕТА — ПРИГЛУШЁННАЯ ЗАЛИВКА И ЦВЕТНЫЕ БУКВЫ
    // (14.09.2026, макет владельца).
    //
    // Было: яркий градиент во всю плитку и БЕЛЫЕ буквы поверх. В списке из
    // тридцати чатов это давало радугу, в которой тонуло всё остальное —
    // непрочитанное, «в сети», выбранная строка. Портрет без фотографии
    // кричал громче, чем портрет с фотографией.
    //
    // В макете тот же кружок — тёмная заливка своего оттенка, а цвет живёт в
    // БУКВАХ. Личность при этом не теряется: оттенок берётся из той же общей
    // палитры по тому же хэшу имени, что и на телефоне, — один человек всегда
    // одного цвета на обоих устройствах.
    // 🔴 ЦВЕТ У ВСЕХ — И У ЛЮДЕЙ ТОЖЕ (15.09.2026, указание владельца).
    //
    // До этого цветными были только комнаты, а люди — серыми с серыми буквами:
    // так читался макет, где у всех людей заливка нейтральная. Владелец решил
    // иначе, и довод у него сильный: на телефоне человек БЕЗ фотографии уже
    // цветной, и один и тот же собеседник выходил на двух устройствах разным —
    // на телефоне синий, на компьютере серый.
    //
    // Разница между устройствами остаётся, но теперь она про ЯРКОСТЬ, а не про
    // наличие цвета: на телефоне яркая заливка и белые буквы, на компьютере
    // приглушённая заливка и цветные буквы. Причина прежняя — в списке из
    // тридцати строк тридцать ярких кружков дают радугу, в которой тонет всё
    // остальное: непрочитанное, «в сети», выбранная строка.
    //
    // Оттенок берётся из ОБЩЕЙ с телефоном палитры по тому же ключу — см.
    // [seed]. Один человек одного цвета на столе и в кармане.
    //
    // 🔴 С 17.09.2026 и телефон рисует заглушку так же — поэтому сама формула
    // живёт в общем [sharedAvatarInkFor], а не здесь. В тёмной теме она прежняя
    // (0,15 и светлота 0,66 — по заливкам макета: зелёная комната там #12302A
    // с буквами #5BD6A8, янтарная — #2E2418 с #F0B460). В светлой буквы
    // темнее: прежняя светлота 0,66 на светлой заливке почти не читалась.
    final avatarInk = sharedAvatarInkFor(
      innerGradient,
      background: background ?? c.bg,
    );
    final Color fill = avatarInk.fill;
    final Color ink = avatarInk.ink;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: _isRoom ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: borderRadius,
        color: image == null ? fill : null,
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
        // 🔴 ВЫДЕЛЕНИЕ — КОЛЬЦО СНАРУЖИ, А НЕ ОБВОДКА ВНУТРЬ.
        //
        // `Border.all` уводил кольцо ВНУТРЬ портрета: две точки лица
        // съедались, а на тёмном фоне край акцента сливался с содержимым —
        // в макете между ними стоит ещё одно кольцо цвета подложки.
        // [DShadows.focusRing] и есть это двухступенчатое кольцо.
        boxShadow: selected ? DShadows.focusRing(c) : null,
      ),
      child: image == null
          // 🔴 Инициалы ВСЛУХ НЕ ЧИТАЮТСЯ. «ЮА» экранный диктор произносит по
          // буквам — и произносит прямо перед настоящим именем, которое в
          // списке и в шапке всегда стоит рядом. Это не подпись, а шум перед
          // подписью: заглушка портрета несёт ровно ноль сведений сверх имени.
          ? ExcludeSemantics(
              child: Center(
              child: Text(
                _initials,
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: fontSize,
                  // Вес тоже из макета и тоже зависит от размера: рабочий
                  // 42-й набран 700, а мелкие 22–26 и крупные 44+ — 800.
                  // Жирное начертание в мелком кружке спасает читаемость, в
                  // крупном держит вес рядом с фотографией, а на среднем
                  // делает заглушку тяжелее соседей.
                  fontWeight: (size <= 30 || size >= 44)
                      ? FontWeight.w800
                      : FontWeight.w700,
                  color: ink,
                  // · ТРЕКИНГА НЕТ (макет): в нём 26 объявлений
                  // letter-spacing, и НИ ОДНОГО на инициалах. Отрицательные
                  // 0.2 сдвигали вторую букву к первой — на двух заглавных
                  // это видно, и «ИК» читалось теснее, чем «MC».
                  letterSpacing: 0,
                ),
              ),
            ))
          : null,
    );

    // Overlays (status dot, mute, verified, unread).
    final dot = (showStatus || online) && !muted;
    final hasOverlays = dot || muted || verified || unreadCount > 0;
    final ring = ringColor ?? c.chatList;
    // Толщина выреза в макете растёт вместе с портретом: 2 у мелких (плашка
    // созвона), 2,5 у строки списка, 3 у портрета 88 в правой панели.
    // Постоянные две точки на портрете 88 выглядели волоском.
    final double ringWidth = size >= 64 ? 3 : (size >= 32 ? 2.5 : 2);

    if (hasOverlays) {
      avatar = SizedBox(
        width: size + (verified ? 4 : 0),
        height: size + (verified ? 4 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: avatar),
            if (dot)
              Positioned(
                right: _overlayInset,
                bottom: _overlayInset,
                child: Container(
                  width: size * 0.30,
                  height: size * 0.30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor ?? c.voice,
                    border: Border.all(color: ring, width: ringWidth),
                  ),
                ),
              ),
            if (muted)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.36,
                  height: size * 0.36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.elevated,
                    border: Border.all(color: ring, width: ringWidth),
                  ),
                  child: Icon(
                    Icons.notifications_off_rounded,
                    size: size * 0.18,
                    color: c.textSecondary,
                  ),
                ),
              ),
            if (verified)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accentPrimary,
                    border: Border.all(color: ring, width: ringWidth),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: _UnreadBadge(count: unreadCount, color: c.unreadDot),
              ),
          ],
        ),
      );
    }

    // Premium frame ring (peer / self cosmetic). Insets the avatar so the ring
    // sits around it; the frame fills the full box on top.
    //
    // Two independent reasons to skip the animated ring, both honoured:
    //   • the window is off screen (TickerMode disabled at the app root), and
    //   • the user turned «Анимация рамок и статусов» off (D-5).
    // Not building the overlay is what matters, rather than muting it: the
    // shared frame atlas is ref-counted and driven by a BARE Ticker, which —
    // unlike an AnimationController from a TickerProvider — never consults
    // TickerMode. Releasing the reference is the only thing that stops it.
    // 🔴 РАМКИ ЕСТЬ И У КОМНАТ.
    //
    // 13.09 я сначала запретил их на квадратном портрете, рассудив, что рамка
    // это личное украшение. Рассуждение было неверным: `RoomSettings` несёт
    // `frameId` — комнатные рамки существуют в модели и покупаются так же.
    // Владелец подтвердил это прямо.
    //
    // Настоящая трудность не в праве, а в геометрии: кольцо круглое, и
    // скруглённый квадрат углами вылезает за него. Решается посадкой —
    // см. `_frameInset`.
    final animateFrames =
        TickerMode.valuesOf(context).enabled &&
        DesktopUiPrefs.animatePeerCosmetics.value &&
        allowAnimatedFrame;
    final frame = animateFrames ? frameById(frameId) : null;
    if (frame != null) {
      final inset = size * _frameInset;
      avatar = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Padding(padding: EdgeInsets.all(inset), child: avatar),
            // Always render the ring at ONE canonical size and scale the
            // result, instead of asking for the avatar's own size.
            //
            // The shared frame atlas keys its blur/gradient-heavy 30fps pass on
            // (kind, pixel-size, accent). Mobile shows avatars at essentially
            // one size, so it runs one loop; desktop shows 36, 40, 88 and 96
            // simultaneously (list, thread header, details, profile), which ran
            // up to four independent loops at once. Measured cost of that:
            // ~23% of a core sitting idle, against 1.5-2.9% with frames off.
            //
            // Downscaling a ready texture is a GPU blit and costs nothing, so
            // one canonical loop serves every size on screen.
            // 🔴 СВОЙ СЛОЙ У КОЛЬЦА — ОБЯЗАТЕЛЕН.
            //
            // Кольцо перерисовывается на каждом тике общего атласа. Без
            // собственного слоя эта перерисовка пачкает слой РОДИТЕЛЯ, то есть
            // всю переписку: в нативном профиле видно, как растровый поток
            // заново рисует текст всех пузырей — из-за одного значка в шапке.
            //
            // Замер 12.09.2026, один процесс, одна сессия:
            //
            //     без чата                            1,9 %
            //     чат с анимированным украшением     43,7 %
            //     чат без украшений                   5,9 %
            //
            // Граница не отменяет кадры — их по-прежнему заказывает тикер
            // атласа, — но ограничивает перерисовку самим кольцом. Дальше
            // остаётся только постоянная плата за кадр.
            //
            // `RepaintBoundary` стоит ВНУТРИ `FittedBox`, а не снаружи:
            // масштабирование готового слоя — это композиция, она дешёвая, а
            // вот пересчёт содержимого под каждый размер вернул бы ровно ту
            // многоконтурную историю, ради которой ниже и введён канонический
            // размер.
            Positioned.fill(
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: kDesktopFrameCanonicalPx,
                      height: kDesktopFrameCanonicalPx,
                      child: frame.builder(kDesktopFrameCanonicalPx),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap != null) {
      // Отклик на нажатие обрезается ПО ФОРМЕ портрета: круглая волна на
      // квадратном аватаре вылезает за углы и читается как чужой элемент.
      final ShapeBorder border = _isRoom
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(roomRadius(size)),
            )
          : const CircleBorder();
      avatar = Material(
        color: Colors.transparent,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(customBorder: border, onTap: onTap, child: avatar),
      );
      // Нажимаемый портрет — кнопка, и без имени диктор объявил бы просто
      // «кнопка». Имя уже есть в [name], новых строк это не требует.
      avatar = Semantics(button: true, label: name, child: avatar);
    }
    // Suppress unused radius warning in case of future use.
    radius.toString();
    return avatar;
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final txt = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DRadii.pill),
        border: Border.all(color: DColors.of(context).chatList, width: 2),
      ),
      alignment: Alignment.center,
      // 🔴 Вслух — «три непрочитанных», а не голое «три». В обходе значок
      // читается сразу после превью, и без слова число сливается с временем и
      // прочим: «Максим, 11:16, привет, три» не говорит, что именно три.
      // Склонение берётся у той же строки, что и в заголовке окна.
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: AppLocalizations.of(context)?.desktopThreadUnreadCount(count),
        child: Text(
          txt,
          style: const TextStyle(
            fontFamily: DType.family,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
