// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Мост аватара» (макет «Peer Profile Transition», 22.11.2026).
///
/// Аватар из строки списка чатов или из шапки чата перелетает в профиль
/// собеседника или комнаты и обратно. Здесь всё, что для этого нужно:
///
/// * [AvatarBridgeHero] — Hero с одним общим полётом: та же картинка, что в
///   списке (без повторного декодирования), круг плавно становится формой
///   цели, рамка гаснет за первые 30 %, в середине пути аватар чуть
///   приподнимается (1 + 0,06·sin πt) с мягкой тенью, путь — дуга
///   (x = t, y = t^0,8 туда и t^1,25 обратно). Полёт идёт по самому
///   переходу страницы (пружина маршрута, палец при свайпе), а не по своей
///   кривой — аватар и страница не расходятся.
/// * [pushAvatarBridge] — открытие профиля: лёгкий отклик, заранее
///   декодированное фото нужного размера; на iPhone — прежний родной сдвиг
///   ([SecretlyPageRoute]), на Android — [AvatarBridgeRoute].
/// * [AvatarBridgeRoute] (только Android) — страница раскрывается кругом из
///   нажатого аватара, нижняя уменьшается до 0,94 и темнеет на 0,3,
///   содержимое проявляется с 25 % до 75 % пути; одна пружина (300/33/1)
///   ведёт и страницу, и аватар. Предиктивный «назад» (Android 14+): пока
///   палец тянет, страница — превью (масштаб 1 − 0,1·p, углы 28·p, сдвиг
///   10·p); отпустил после 35 % — круг схлопывается в аватар.
/// * [AvatarBridgeEntrance] — «переход закончился»: тяжёлое содержимое
///   профиля (живая обложка, рамка, размытие островов, галерея) ждёт его.
///
/// 🔴 Рубильник — [kAvatarBridgeTransition]. `false` возвращает прежнее
/// поведение целиком: обычный Hero, [SecretlyPageRoute] на обеих
/// платформах, профиль без затравки из списка.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../storage/file_exists_cache.dart';
import '../premium/cosmetics_catalog.dart' show frameById;
import '../widgets/app_background.dart';
import '../widgets/avatar_initials.dart';
import '../widgets/covered_route_media_freeze.dart';
import 'page_transitions.dart';

/// 🔴 Рубильник «моста аватара». `false` — ровно прежнее поведение.
const bool kAvatarBridgeTransition = true;

/// Порог предиктивного «назад»: отпустил дальше — страница закрывается.
const double kAvatarBridgeBackCommit = 0.35;

/// Метка аватара строки списка чатов (та же, что была и раньше).
String avatarBridgeListTag(String convoId) => 'avatar-$convoId';

/// Метка аватара в шапке чата. Своя, не как у строки списка: иначе при
/// открытии самого чата из списка аватар полетел бы в шапку.
String avatarBridgeChatHeaderTag(String convoId) =>
    'chat-header-avatar-$convoId';

/// Метка, под которой аватар страницы «стоит в стороне»: пока профиль
/// прокручен и аватар летит в остров шапки, Hero несёт летящий аватар, а
/// аватар в странице — эту, ни с кем не совпадающую.
@immutable
class AvatarBridgeParkedTag {
  const AvatarBridgeParkedTag(this.tag);
  final Object tag;

  @override
  bool operator ==(Object other) =>
      other is AvatarBridgeParkedTag && other.tag == tag;

  @override
  int get hashCode => Object.hash(AvatarBridgeParkedTag, tag);

  @override
  String toString() => 'parked($tag)';
}

/// Что видит полёт на одном конце: фото (тем же ключом картинки, что и
/// виджет на месте), форма, рамка, заглушка.
@immutable
class AvatarBridgeSpec {
  const AvatarBridgeSpec({
    required this.seed,
    this.imagePath,
    this.decodeWidth,
    this.decodeHeight,
    this.cornerFraction = 0.5,
    this.photoInset = 0,
    this.frameId,
    this.name,
    this.fallbackId,
    this.labelFraction = 0.38,
    this.favoritesAsset,
  });

  /// Аватар списка или шапки — [FramedAvatar] размера [size]: фото ужато
  /// под кольцо рамки (0,86·S) и декодировано под свой круг.
  factory AvatarBridgeSpec.framed(
    BuildContext context, {
    required double size,
    required String seed,
    String? path,
    String? frameId,
    String? name,
    String? fallbackId,
    String? favoritesAsset,
  }) {
    final hasFrame = favoritesAsset == null && frameById(frameId) != null;
    final inset = hasFrame ? 0.07 : 0.0;
    final d = size - size * inset * 2;
    final px = (d * MediaQuery.devicePixelRatioOf(context)).round();
    final p = path?.trim() ?? '';
    final ok =
        favoritesAsset == null && p.isNotEmpty && FileExistsCache.exists(p);
    return AvatarBridgeSpec(
      seed: seed,
      imagePath: ok ? p : null,
      decodeWidth: px,
      decodeHeight: px,
      photoInset: inset,
      frameId: hasFrame ? frameId : null,
      name: name,
      fallbackId: fallbackId,
      favoritesAsset: favoritesAsset,
    );
  }

  /// Существующий файл фото или `null` (заглушка).
  final String? imagePath;

  /// Размер декодирования в пикселях — как у `Image.file(cacheWidth:)` на
  /// месте; тогда ключ картинки совпадает и кадр берётся из кэша.
  final int? decodeWidth;
  final int? decodeHeight;

  /// Радиус углов как доля короткой стороны: 0,5 — круг, 0 — прямоугольник.
  final double cornerFraction;

  /// Отступ фото от края (доля стороны) — место под кольцо рамки.
  final double photoInset;

  /// Рамка списка; в полёте гаснет за первые 30 %.
  final String? frameId;

  final String seed;
  final String? name;
  final String? fallbackId;

  /// Высота букв заглушки как доля стороны фото.
  final double labelFraction;

  /// «Избранное»: зелёная плашка с блокнотом вместо фото.
  final String? favoritesAsset;

  ImageProvider? get provider {
    final p = imagePath;
    if (p == null || p.isEmpty) return null;
    return ResizeImage.resizeIfNeeded(
      decodeWidth,
      decodeHeight,
      FileImage(File(p)),
    );
  }
}

/// Сторона моста: откуда открывают (строка списка, шапка чата) или куда
/// (страница профиля).
enum AvatarBridgeSide { source, destination }

// ── Где сейчас стоят аватары-источники (центр круга на Android) ──────────

final Map<Object, List<_AvatarBridgeHeroState>> _origins =
    <Object, List<_AvatarBridgeHeroState>>{};

/// Аватары-цели (страницы профиля) по меткам: при возврате путь аватара
/// идёт по ходу закрывающейся страницы, даже если страница под ней (корень
/// приложения) не получает его «вторичной» анимацией.
final Map<Object, List<_AvatarBridgeHeroState>> _destinations =
    <Object, List<_AvatarBridgeHeroState>>{};

/// Ход перехода страницы профиля с меткой [tag], если он сейчас идёт.
Animation<double>? _destinationProgress(Object tag) {
  final list = _destinations[tag];
  if (list == null) return null;
  for (final s in list.reversed) {
    final a = s._route?.animation;
    if (s.mounted && a != null && a.status.isAnimating) return a;
  }
  return null;
}

/// Прямоугольник аватара-источника с меткой [tag] на экране. Сначала — с
/// текущей страницы; [exclude] — маршрут, который сейчас закрывается.
Rect? avatarBridgeOriginRect(Object tag, {Route<dynamic>? exclude}) {
  final list = _origins[tag];
  if (list == null || list.isEmpty) return null;
  Rect? fallback;
  for (final s in list.reversed) {
    if (!s.mounted) continue;
    final route = s._route;
    if (exclude != null && identical(route, exclude)) continue;
    final box = s.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    if (route == null || route.isCurrent) return rect;
    fallback ??= rect;
  }
  return fallback;
}

/// Hero «моста». Источнику и цели — один и тот же виджет со своей [side].
class AvatarBridgeHero extends StatefulWidget {
  const AvatarBridgeHero({
    super.key,
    required this.tag,
    required this.spec,
    required this.side,
    required this.child,
  });

  final Object tag;
  final AvatarBridgeSpec spec;
  final AvatarBridgeSide side;
  final Widget child;

  @override
  State<AvatarBridgeHero> createState() => _AvatarBridgeHeroState();
}

class _AvatarBridgeHeroState extends State<AvatarBridgeHero> {
  ModalRoute<dynamic>? _route;

  bool get _isSource => widget.side == AvatarBridgeSide.source;

  @override
  void initState() {
    super.initState();
    _register(widget.tag);
  }

  @override
  void didUpdateWidget(AvatarBridgeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag || oldWidget.side != widget.side) {
      _unregister(oldWidget.tag, oldWidget.side);
      _register(widget.tag);
    }
  }

  @override
  void dispose() {
    _unregister(widget.tag);
    super.dispose();
  }

  Map<Object, List<_AvatarBridgeHeroState>> _registry(AvatarBridgeSide side) =>
      side == AvatarBridgeSide.source ? _origins : _destinations;

  void _register(Object tag) {
    if (!kAvatarBridgeTransition) return;
    (_registry(widget.side)[tag] ??= <_AvatarBridgeHeroState>[]).add(this);
  }

  void _unregister(Object tag, [AvatarBridgeSide? side]) {
    final registry = _registry(side ?? widget.side);
    final list = registry[tag];
    if (list == null) return;
    list.remove(this);
    if (list.isEmpty) registry.remove(tag);
  }

  @override
  Widget build(BuildContext context) {
    if (!kAvatarBridgeTransition) {
      return Hero(tag: widget.tag, child: widget.child);
    }
    final route = _route = ModalRoute.of(context);
    final colors = AvatarInitials.colors(context, seed: widget.spec.seed);
    final isDest = !_isSource;
    final tag = widget.tag;
    final secondary = route?.secondaryAnimation;
    // Цель (страница профиля) летит по своему переходу; источник (при
    // возврате) — по переходу закрывающейся страницы с той же меткой.
    Animation<double>? progress() => isDest
        ? route?.animation
        : (_destinationProgress(tag) ??
              (secondary != null && secondary.status.isAnimating
                  ? secondary
                  : null));
    return Hero(
      tag: widget.tag,
      transitionOnUserGestures: true,
      createRectTween: (begin, end) => _AvatarBridgeRectTween(
        begin: begin,
        end: end,
        yExponent: isDest ? 0.8 : 1.25,
        progress: progress,
        fromSecondary: !isDest,
      ),
      flightShuttleBuilder: _avatarBridgeShuttle,
      child: _AvatarBridgePayload(
        spec: widget.spec,
        side: widget.side,
        fill: colors.fill,
        ink: colors.ink,
        routeAnimation: route?.animation,
        child: widget.child,
      ),
    );
  }
}

/// Данные для полёта, спрятанные в `Hero.child` (сам рисует только [child]).
class _AvatarBridgePayload extends StatelessWidget {
  const _AvatarBridgePayload({
    required this.spec,
    required this.side,
    required this.fill,
    required this.ink,
    required this.routeAnimation,
    required this.child,
  });

  final AvatarBridgeSpec spec;
  final AvatarBridgeSide side;
  final Color fill;
  final Color ink;
  final Animation<double>? routeAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

// ── Путь полёта ──────────────────────────────────────────────────────────

/// Обратная к `Curves.fastOutSlowIn`, которой Hero искривляет свой ход: если
/// своего хода перехода не нашлось, полёт всё равно идёт по ходу маршрута.
double _invFastOutSlowIn(double y) {
  if (y <= 0) return 0;
  if (y >= 1) return 1;
  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 20; i++) {
    final mid = (lo + hi) / 2;
    if (Curves.fastOutSlowIn.transform(mid) < y) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

class _AvatarBridgeRectTween extends RectTween {
  _AvatarBridgeRectTween({
    super.begin,
    super.end,
    required this.yExponent,
    required this.progress,
    required this.fromSecondary,
  });

  final double yExponent;
  final Animation<double>? Function() progress;
  final bool fromSecondary;

  /// Доля пути от [begin] к [end] — по самому переходу страницы.
  double fraction(double t) {
    final a = progress();
    if (a != null && a.status.isAnimating) {
      final v = a.value.clamp(0.0, 1.0);
      return fromSecondary ? 1 - v : v;
    }
    return _invFastOutSlowIn(t.clamp(0.0, 1.0));
  }

  @override
  Rect? transform(double t) {
    final b = begin;
    final e = end;
    if (b == null || e == null) return super.transform(t);
    final f = fraction(t);
    if (f <= 0) return b;
    if (f >= 1) return e;
    final fy = math.pow(f, yExponent).toDouble();
    return Rect.fromCenter(
      center: Offset(
        lerpDouble(b.center.dx, e.center.dx, f)!,
        lerpDouble(b.center.dy, e.center.dy, fy)!,
      ),
      width: lerpDouble(b.width, e.width, f)!,
      height: lerpDouble(b.height, e.height, f)!,
    );
  }
}

// ── Летящий аватар ───────────────────────────────────────────────────────

Widget _avatarBridgeShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = toHeroContext.widget as Hero;
  final from = (fromHeroContext.widget as Hero).child;
  final to = toHero.child;
  // Вторая сторона — не мост (например, прежний просмотр фото): обычный
  // полёт виджета цели, как у Hero по умолчанию.
  if (from is! _AvatarBridgePayload ||
      to is! _AvatarBridgePayload ||
      from.side == to.side) {
    return toHero.child;
  }
  final source = from.side == AvatarBridgeSide.source ? from : to;
  final dest = identical(source, from) ? to : from;
  // 🔴 23.11.2026: полёт идёт в Overlay, над страницами, где нет Material.
  // Без него у инициалов отладочный стиль текста — жёлтое двойное
  // подчёркивание и запасной шрифт («буквы меняли форму»). Прозрачный
  // Material даёт тот же шрифт темы, что у аватара в списке и в профиле.
  return Material(
    type: MaterialType.transparency,
    child: _AvatarBridgeShuttle(
      animation: animation,
      source: source,
      dest: dest,
    ),
  );
}

class _AvatarBridgeShuttle extends StatelessWidget {
  const _AvatarBridgeShuttle({
    required this.animation,
    required this.source,
    required this.dest,
  });

  /// Ход Hero (0 — у источника, 1 — у цели, в обе стороны).
  final Animation<double> animation;
  final _AvatarBridgePayload source;
  final _AvatarBridgePayload dest;

  /// Доля пути у цели — по переходу страницы профиля.
  double _progress() {
    final a = dest.routeAnimation;
    if (a != null && a.status.isAnimating) return a.value.clamp(0.0, 1.0);
    return animation.value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final big = dest.spec.provider;
    final small = source.spec.provider;
    final frame = frameById(source.spec.frameId);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final p = _progress();
        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth.isFinite ? box.maxWidth : 0.0;
            final h = box.maxHeight.isFinite ? box.maxHeight : 0.0;
            final shortest = math.min(w, h);
            final inset =
                lerpDouble(source.spec.photoInset, dest.spec.photoInset, p)! *
                shortest;
            final inner = math.max(0.0, shortest - inset * 2);
            final corner =
                lerpDouble(
                  source.spec.cornerFraction,
                  dest.spec.cornerFraction,
                  p,
                )! *
                inner;
            final lift = math.sin(math.pi * p);
            final radius = BorderRadius.circular(corner);
            final content = _content(context, p, inner, big, small);
            Widget photo = ClipRRect(borderRadius: radius, child: content);
            if (lift > 0.01) {
              photo = DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.26 * lift),
                      blurRadius: 18 * lift,
                      offset: Offset(0, 6 * lift),
                    ),
                  ],
                ),
                child: photo,
              );
            }
            final frameOpacity = (1 - p / 0.3).clamp(0.0, 1.0);
            return Transform.scale(
              scale: 1 + 0.06 * lift,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Padding(padding: EdgeInsets.all(inset), child: photo),
                  if (frame != null && frameOpacity > 0)
                    Center(
                      child: SizedBox.square(
                        dimension: shortest,
                        child: Opacity(
                          opacity: frameOpacity,
                          child: TickerMode(
                            enabled: false,
                            child: frame.builder(shortest),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    double p,
    double inner,
    ImageProvider? big,
    ImageProvider? small,
  ) {
    final fav = dest.spec.favoritesAsset ?? source.spec.favoritesAsset;
    if (fav != null) {
      return ColoredBox(
        color: const Color(0xFF0D5F38),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.7,
            heightFactor: 0.7,
            child: SvgPicture.asset(
              fav,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );
    }
    final fallback = _fallback(p, inner);
    if (big == null && small == null) return fallback;
    Widget image(ImageProvider provider, Widget onError) => Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => onError,
    );
    final under = small == null ? fallback : image(small, fallback);
    if (big == null) return under;
    // Фото цели обычно уже в кэше (заранее декодировано до перехода); пока
    // нет — под ним то же фото, что в списке, без пустого кадра.
    return Image(
      image: big,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, sync) =>
          (frame == null && !sync) ? under : child,
      errorBuilder: (_, _, _) => under,
    );
  }

  Widget _fallback(double p, double inner) {
    final spec = dest.spec;
    final label = AvatarInitials.label(
      displayName: spec.name ?? source.spec.name,
      fallbackId: spec.fallbackId ?? source.spec.fallbackId,
    );
    final fontSize =
        lerpDouble(source.spec.labelFraction, spec.labelFraction, p)! * inner;
    return ColoredBox(
      color: Color.lerp(source.fill, dest.fill, p)!,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.lerp(source.ink, dest.ink, p),
            fontSize: math.max(1.0, fontSize),
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Открытие профиля ─────────────────────────────────────────────────────

void _lightHaptic() {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    HapticFeedback.lightImpact().catchError((Object _) {});
  } catch (_) {}
}

/// Заранее декодирует фото цели под её размер, чтобы первый кадр полёта
/// не ждал диска. [decodeSide] — сторона фото на странице в точках;
/// `null` — страница показывает фото без уменьшения.
void _precache(BuildContext context, String? path, double? decodeSide) {
  final p = path?.trim() ?? '';
  if (p.isEmpty || !FileExistsCache.exists(p)) return;
  final px = decodeSide == null
      ? null
      : (decodeSide * MediaQuery.devicePixelRatioOf(context)).round().clamp(
          1,
          4096,
        );
  final provider = ResizeImage.resizeIfNeeded(px, px, FileImage(File(p)));
  precacheImage(
    provider,
    context,
    onError: (_, _) {},
  ).catchError((Object _) {});
}

/// Открывает профиль собеседника или комнаты «мостом» из аватара [heroTag].
///
/// iPhone и компьютер — прежний [SecretlyPageRoute] (родной сдвиг и свайп),
/// Android — [AvatarBridgeRoute]. Выключенный [kAvatarBridgeTransition] —
/// ровно прежний push.
Future<T?> pushAvatarBridge<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
  Object? heroTag,
  String? precachePath,
  double? precacheDecodeSide,
  bool Function()? hapticsEnabled,
}) {
  final navigator = Navigator.of(context);
  if (!kAvatarBridgeTransition) {
    return navigator.push<T>(SecretlyPageRoute<T>(builder: builder));
  }
  if (hapticsEnabled?.call() ?? true) _lightHaptic();
  _precache(context, precachePath, precacheDecodeSide);
  if (defaultTargetPlatform != TargetPlatform.android) {
    return navigator.push<T>(SecretlyPageRoute<T>(builder: builder));
  }
  return navigator.push<T>(
    AvatarBridgeRoute<T>(
      builder: builder,
      heroTag: heroTag,
      origin: heroTag == null ? null : avatarBridgeOriginRect(heroTag),
      hapticsEnabled: hapticsEnabled,
    ),
  );
}

// ── «Переход закончился» ─────────────────────────────────────────────────

final ValueNotifier<bool> _alwaysSettled = ValueNotifier<bool>(true);

/// Строит [builder] с `settled == false`, пока страница въезжает «мостом» на
/// Android, и `true` после (и всегда — на iPhone, на компьютере, без
/// рубильника). Однажды закончившись, переход больше не «идёт»: при
/// закрытии содержимое не прячется.
class AvatarBridgeEntrance extends StatefulWidget {
  const AvatarBridgeEntrance({super.key, required this.builder, this.child});

  final Widget Function(BuildContext context, bool settled, Widget? child)
  builder;
  final Widget? child;

  @override
  State<AvatarBridgeEntrance> createState() => _AvatarBridgeEntranceState();
}

class _AvatarBridgeEntranceState extends State<AvatarBridgeEntrance> {
  ValueListenable<bool> _settled = _alwaysSettled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _settled = kAvatarBridgeTransition && route is AvatarBridgeRoute
        ? route._settled
        : _alwaysSettled;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _settled,
    builder: widget.builder,
    child: widget.child,
  );
}

// ── Android: раскрытие кругом ────────────────────────────────────────────

class _AvatarBridgeSpringController extends AnimationController {
  _AvatarBridgeSpringController({
    super.duration,
    super.reverseDuration,
    super.debugLabel,
    required super.vsync,
  });

  static const Tolerance _tolerance = Tolerance(
    distance: 0.001,
    velocity: 0.01,
  );

  TickerFuture _springTo(double target) {
    final v = isAnimating ? velocity : 0.0;
    final start = value;
    stop();
    final sim = SpringSimulation(
      AvatarBridgeRoute.spring,
      start,
      target,
      v,
      tolerance: _tolerance,
    );
    final back = target < start || (target == start && target == lowerBound);
    return back ? animateBackWith(sim) : animateWith(sim);
  }

  @override
  TickerFuture forward({double? from}) {
    if (from != null) value = from;
    return _springTo(upperBound);
  }

  @override
  TickerFuture reverse({double? from}) {
    if (from != null) value = from;
    return _springTo(lowerBound);
  }

  @override
  TickerFuture animateTo(
    double target, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) => _springTo(target);

  @override
  TickerFuture animateBack(
    double target, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) => _springTo(target);
}

class _AvatarBridgeBackObserver with WidgetsBindingObserver {
  _AvatarBridgeBackObserver(this.route);

  final AvatarBridgeRoute<dynamic> route;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      route._startBack(
        backEvent.progress,
        backEvent.swipeEdge,
        backEvent.isButtonEvent,
      );

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      route.handleUpdateBackGestureProgress(progress: backEvent.progress);

  @override
  void handleCommitBackGesture() => route.handleCommitBackGesture();

  @override
  void handleCancelBackGesture() => route.handleCancelBackGesture();
}

/// Профиль на Android: раскрытие кругом из аватара и предиктивный «назад».
class AvatarBridgeRoute<T> extends PageRoute<T> {
  AvatarBridgeRoute({
    required this.builder,
    this.heroTag,
    Rect? origin,
    this.hapticsEnabled,
    super.settings,
  }) : _origin = origin;

  /// Одна пружина на страницу и аватар (≈420 мс).
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 33,
  );

  final WidgetBuilder builder;
  final Object? heroTag;
  final bool Function()? hapticsEnabled;

  Rect? _origin;

  /// Аватар, из которого раскрывается круг (экранные координаты).
  Rect? get origin => _origin;

  final ValueNotifier<bool> _settled = ValueNotifier<bool>(false);

  /// Превью предиктивного «назад», 0…1.
  final ValueNotifier<double> backPreview = ValueNotifier<double>(0);
  SwipeEdge _backEdge = SwipeEdge.left;
  bool _backActive = false;
  double _backRaw = 0;
  final Stopwatch _backClock = Stopwatch();
  AnimationController? _backSpring;
  _AvatarBridgeBackObserver? _observer;

  /// Идёт ли сейчас превью «назад».
  bool get isBackPreviewActive => _backActive;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  AnimationController createAnimationController() =>
      _AvatarBridgeSpringController(
        duration: transitionDuration,
        reverseDuration: reverseTransitionDuration,
        debugLabel: debugLabel,
        vsync: navigator!,
      );

  @override
  void install() {
    super.install();
    animation!.addStatusListener(_onStatus);
    _onStatus(animation!.status);
    _backSpring = AnimationController.unbounded(vsync: navigator!)
      ..addListener(() {
        backPreview.value = _backSpring!.value.clamp(0.0, 1.0);
      });
    WidgetsBinding.instance.addObserver(
      _observer = _AvatarBridgeBackObserver(this),
    );
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && !_settled.value) _settled.value = true;
  }

  @override
  void dispose() {
    animation?.removeStatusListener(_onStatus);
    final o = _observer;
    if (o != null) WidgetsBinding.instance.removeObserver(o);
    _backSpring?.dispose();
    backPreview.dispose();
    _settled.dispose();
    super.dispose();
  }

  @override
  bool didPop(T? result) {
    // Круг схлопывается туда, где аватар стоит сейчас (строка могла
    // переехать, пока профиль был открыт).
    final tag = heroTag;
    if (tag != null) {
      final r = avatarBridgeOriginRect(tag, exclude: this);
      if (r != null) _origin = r;
    }
    return super.didPop(result);
  }

  // ── Предиктивный «назад» ──
  // Пока палец тянет, страница — превью; ход маршрута не трогаем, иначе
  // круг начал бы схлопываться под пальцем. Закрытие — обычным pop.

  @override
  void handleStartBackGesture({double progress = 0.0}) {
    _startBack(progress, SwipeEdge.left, false);
  }

  bool _startBack(double progress, SwipeEdge edge, bool isButtonEvent) {
    if (isButtonEvent || !isCurrent || !popGestureEnabled) return false;
    _backActive = true;
    _backEdge = edge;
    _backClock
      ..reset()
      ..start();
    _backSpring?.stop();
    _setBack(progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    if (!_backActive || !isCurrent) return;
    _setBack(progress);
  }

  void _setBack(double raw) {
    _backRaw = raw.clamp(0.0, 1.0);
    backPreview.value = _backRaw;
  }

  @override
  void handleCommitBackGesture() {
    if (!_backActive) return;
    _backActive = false;
    // Короткий бросок — «назад» и без 35 %, как привыкли на Android.
    final flick = _backClock.elapsedMilliseconds < 250;
    if (_backRaw < kAvatarBridgeBackCommit && !flick) {
      _settleBack();
      return;
    }
    if (!isCurrent) return;
    if (hapticsEnabled?.call() ?? true) _lightHaptic();
    navigator?.pop();
  }

  @override
  void handleCancelBackGesture() {
    if (!_backActive) return;
    _backActive = false;
    _settleBack();
  }

  void _settleBack() {
    final c = _backSpring;
    if (c == null) {
      backPreview.value = 0;
      return;
    }
    c.value = backPreview.value;
    c.animateWith(SpringSimulation(spring, backPreview.value, 0, 0));
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: CoveredRouteMediaFreeze(
      child: AppGradientBackdrop(child: builder(context)),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _AvatarBridgeTransition(route: this, animation: animation, child: child);

  /// Нижняя страница: −6 % и затемнение 0,3 (при превью «назад» — вполовину
  /// меньше).
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _coveredTransition;

  Widget? _coveredTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _AvatarBridgeCovered(
    animation: secondaryAnimation,
    backPreview: backPreview,
    child: child,
  );
}

class _AvatarBridgeCovered extends StatelessWidget {
  const _AvatarBridgeCovered({
    required this.animation,
    required this.backPreview,
    required this.child,
  });

  final Animation<double> animation;
  final ValueListenable<double> backPreview;
  final Widget? child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([animation, backPreview]),
    child: child,
    builder: (context, child) {
      final s = animation.value.clamp(0.0, 1.0) * (1 - 0.5 * backPreview.value);
      return Transform.scale(
        scale: 1 - 0.06 * s,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3 * s),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Круг, раскрывающийся из [center] радиусом [radius].
class AvatarBridgeCircleClipper extends CustomClipper<Path> {
  const AvatarBridgeCircleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(AvatarBridgeCircleClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}

/// Геометрия раскрытия: центр — аватар-источник, радиус растёт от его круга
/// до дальнего угла экрана.
({Offset center, double radius, double maxRadius}) avatarBridgeReveal({
  required Size size,
  required Rect? origin,
  required double progress,
  double topInset = 0,
}) {
  final center =
      origin?.center ?? Offset(size.width / 2, topInset + kToolbarHeight + 64);
  double far(Offset corner) => (corner - center).distance;
  final maxRadius = [
    far(Offset.zero),
    far(Offset(size.width, 0)),
    far(Offset(0, size.height)),
    far(Offset(size.width, size.height)),
  ].reduce(math.max);
  final r0 = (origin?.shortestSide ?? 0) * 0.4;
  return (
    center: center,
    radius: lerpDouble(r0, maxRadius, progress.clamp(0.0, 1.0))!,
    maxRadius: maxRadius,
  );
}

class _AvatarBridgeTransition extends StatelessWidget {
  const _AvatarBridgeTransition({
    required this.route,
    required this.animation,
    required this.child,
  });

  final AvatarBridgeRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scrim = AppBackground.scrimColorOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([animation, route.backPreview]),
      child: child,
      builder: (context, child) {
        final p = animation.value.clamp(0.0, 1.0);
        final q = route.backPreview.value;
        final reveal = avatarBridgeReveal(
          size: mq.size,
          origin: route.origin,
          progress: p,
          topInset: mq.padding.top,
        );
        final clipped = reveal.radius < reveal.maxRadius;
        // Содержимое проявляется с 25 % до 75 % пути — плашкой цвета
        // страницы поверх, без слоя прозрачности всей страницы.
        final cover = 1 - ((p - 0.25) / 0.5).clamp(0.0, 1.0);
        final edgeSign = route._backEdge == SwipeEdge.left ? 1.0 : -1.0;
        return ClipPath(
          clipBehavior: clipped ? Clip.antiAlias : Clip.none,
          clipper: AvatarBridgeCircleClipper(
            center: reveal.center,
            radius: reveal.radius,
          ),
          child: Transform.translate(
            offset: Offset(10 * q * edgeSign, 0),
            child: Transform.scale(
              scale: 1 - 0.1 * q,
              child: ClipRRect(
                clipBehavior: q > 0 ? Clip.antiAlias : Clip.none,
                borderRadius: BorderRadius.circular(28 * q),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    color: scrim.withValues(alpha: scrim.a * cover),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
