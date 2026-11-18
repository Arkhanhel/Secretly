// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'secretly_snackbar.dart';

/// Стиль Apple на iPhone (решение владельца 17.11.2026): системный шрифт и
/// короткие уведомления капсулой сверху, как iOS показывает подключение
/// AirPods. Android и компьютер не меняются.
///
/// Оба переключателя — мгновенный откат: `false` возвращает прежний вид.

/// Системный шрифт Apple (SF) вместо Inter во всём приложении на iPhone.
///
/// Шрифт не вкладывается в приложение: iOS отдаёт свой. Вкладывать SF в
/// сборки для Android и Windows лицензия Apple не разрешает — поэтому только
/// iPhone.
const bool kAppleSystemFont = true;

/// Короткие уведомления («Скопировано», «Не удалось отправить») — капсулой у
/// верхнего края, а не плашкой под шапкой.
const bool kAppleTopToasts = true;

bool get appleSystemFontEnabled =>
    kAppleSystemFont && defaultTargetPlatform == TargetPlatform.iOS;

bool get appleTopToastsEnabled =>
    kAppleTopToasts && defaultTargetPlatform == TargetPlatform.iOS;

/// Окна подтверждения и окна с полем ввода — как у iPhone: по центру,
/// заголовок по центру, кнопки во всю ширину с тонкими разделителями
/// (`apple_controls.dart`, `SecretlyAlertDialog`).
const bool kAppleDialogs = true;

/// Переключатели и крутилки загрузки — системные Apple
/// (`apple_controls.dart`, `SecretlySwitch`, `SecretlySpinner`).
const bool kAppleControls = true;

bool get appleDialogsEnabled =>
    kAppleDialogs && defaultTargetPlatform == TargetPlatform.iOS;

bool get appleControlsEnabled =>
    kAppleControls && defaultTargetPlatform == TargetPlatform.iOS;

/// Почтальон уведомлений для iPhone.
///
/// Приложение показывает уведомления примерно в двухстах местах, и почти все
/// зовут `ScaffoldMessenger.of(context).showSnackBar(...)`. Переделывать
/// каждое не нужно: этот почтальон подменяет любое уведомление на «якорь»,
/// а сама капсула рисуется одна, поверх всех экранов ([AppleToastHost]).
///
/// Очередь, время показа, «закрыть», `closed`, кнопка действия — всё
/// остаётся штатным: показом по-прежнему управляет [ScaffoldMessengerState].
/// Меняется только то, где и как уведомление нарисовано.
class AppleToastMessenger extends ScaffoldMessenger {
  const AppleToastMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _AppleToastMessengerState();
}

class _AppleToastMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    return super.showSnackBar(
      AppleToastSnackBar.wrap(snackBar),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}

/// Уведомление-«якорь»: на своём месте внизу экрана оно нулевого размера,
/// прозрачное и пропускает нажатия. Видимая капсула — в [AppleToastHost].
class AppleToastSnackBar extends SnackBar {
  AppleToastSnackBar._(this.source)
    : super(
        key: source.key,
        content: _AppleToastAnchor(source: source),
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        hitTestBehavior: HitTestBehavior.deferToChild,
        // Время показа и «не закрывать само» — как у исходного уведомления.
        duration: source.duration,
        persist: source.persist,
        onVisible: source.onVisible,
        dismissDirection: DismissDirection.none,
        clipBehavior: Clip.none,
      );

  /// Исходное уведомление: текст, кнопка действия, крестик.
  final SnackBar source;

  static SnackBar wrap(SnackBar snackBar) => snackBar is AppleToastSnackBar
      ? snackBar
      : AppleToastSnackBar._(snackBar);
}

/// Что сейчас показывает капсула. Один на всё приложение.
@visibleForTesting
final ValueNotifier<AppleToastEntry?> appleToastCurrent =
    ValueNotifier<AppleToastEntry?>(null);

@immutable
class AppleToastEntry {
  const AppleToastEntry({
    required this.source,
    required this.animation,
    required this.messenger,
  });

  final SnackBar source;

  /// Появление и уход: та же анимация, что у штатного уведомления, — капсула
  /// уходит ровно тогда, когда уведомление закрывается.
  final Animation<double> animation;
  final ScaffoldMessengerState? messenger;

  @override
  bool operator ==(Object other) =>
      other is AppleToastEntry &&
      identical(other.source, source) &&
      identical(other.animation, animation) &&
      identical(other.messenger, messenger);

  @override
  int get hashCode => Object.hash(
    identityHashCode(source),
    identityHashCode(animation),
    identityHashCode(messenger),
  );
}

/// Уведомление показывается на КАЖДОМ корневом `Scaffold` (так устроен
/// `ScaffoldMessenger`: при переходе между экранами оно не пропадает), то есть
/// якорей бывает несколько. Капсулу ведёт один — тот, чей экран сейчас
/// наверху; если наверху окно без своего экрана, — последний появившийся.
final List<_AppleToastAnchorState> _anchors = <_AppleToastAnchorState>[];
bool _republishScheduled = false;

void _scheduleRepublish() {
  if (_republishScheduled) return;
  _republishScheduled = true;
  // Не во время построения и не при разборе дерева: менять общее значение
  // там нельзя, поэтому — сразу после кадра.
  SchedulerBinding.instance.addPostFrameCallback((_) {
    _republishScheduled = false;
    _republish();
  });
  SchedulerBinding.instance.ensureVisualUpdate();
}

void _republish() {
  _AppleToastAnchorState? best;
  for (final anchor in _anchors.reversed) {
    if (!anchor.mounted) continue;
    if (anchor._routeIsCurrent) {
      best = anchor;
      break;
    }
    best ??= anchor;
  }
  appleToastCurrent.value = best?._entry;
}

class _AppleToastAnchor extends StatefulWidget {
  const _AppleToastAnchor({required this.source});

  final SnackBar source;

  @override
  State<_AppleToastAnchor> createState() => _AppleToastAnchorState();
}

class _AppleToastAnchorState extends State<_AppleToastAnchor> {
  AppleToastEntry? _entry;
  bool _routeIsCurrent = true;

  @override
  void initState() {
    super.initState();
    _anchors.add(this);
  }

  @override
  void dispose() {
    _anchors.remove(this);
    _scheduleRepublish();
    super.dispose();
  }

  /// Анимация штатного уведомления — ближайшее `FadeTransition` выше якоря
  /// (оно внутри самого `SnackBar`). Дальше своего `Scaffold` не ищем, чтобы
  /// не взять чужое, например переход между экранами.
  Animation<double> _snackAnimation() {
    if (MediaQuery.accessibleNavigationOf(context)) {
      return kAlwaysCompleteAnimation;
    }
    Animation<double>? found;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is FadeTransition) {
        found = widget.opacity;
        return false;
      }
      return widget is! Scaffold;
    });
    return found ?? kAlwaysCompleteAnimation;
  }

  @override
  Widget build(BuildContext context) {
    final entry = AppleToastEntry(
      source: widget.source,
      animation: _snackAnimation(),
      messenger: ScaffoldMessenger.maybeOf(context),
    );
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (entry != _entry || current != _routeIsCurrent) {
      _entry = entry;
      _routeIsCurrent = current;
      _scheduleRepublish();
    }
    return const SizedBox.shrink();
  }
}

/// Капсула уведомлений поверх всех экранов. Ставится один раз, в корне
/// приложения, НИЖЕ заслонки блокировки — чтобы текст уведомления не было
/// видно поверх неё.
class AppleToastHost extends StatefulWidget {
  const AppleToastHost({super.key});

  @override
  State<AppleToastHost> createState() => _AppleToastHostState();
}

class _AppleToastHostState extends State<AppleToastHost>
    with SingleTickerProviderStateMixin {
  /// Своя анимация капсулы. Анимация штатного уведомления для неё не
  /// годится: в Material 3 его появление укладывается в 50 мс — капсула
  /// мигала бы, а не выезжала. От штатного берётся только сигнал «уходим».
  // Создаётся сразу в initState: ленивое создание срабатывало впервые в
  // dispose (капсула ни разу не показывалась) и падало на разобранном дереве.
  late final AnimationController _show;
  AppleToastEntry? _shown;
  Animation<double>? _watched;

  @override
  void initState() {
    super.initState();
    _show = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 200),
    );
    appleToastCurrent.addListener(_changed);
  }

  @override
  void dispose() {
    appleToastCurrent.removeListener(_changed);
    _watched?.removeStatusListener(_onSnackStatus);
    _show.dispose();
    super.dispose();
  }

  void _changed() {
    final entry = appleToastCurrent.value;
    if (entry != null && !identical(entry.source, _shown?.source)) {
      // Лёгкий отклик, как у системных уведомлений iOS.
      HapticFeedback.lightImpact();
      _show.forward(from: 0);
    }
    if (!identical(entry?.animation, _watched)) {
      _watched?.removeStatusListener(_onSnackStatus);
      _watched = entry?.animation;
      _watched?.addStatusListener(_onSnackStatus);
    }
    _shown = entry;
    if (entry == null) _show.value = 0;
    if (mounted) setState(() {});
  }

  /// Штатное уведомление начало закрываться (время вышло, «Повторить»,
  /// закрыто кодом) — капсула уезжает вверх быстрее, чем оно исчезнет.
  void _onSnackStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) _show.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _shown;
    if (entry == null) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final still = media.disableAnimations;
    // Уведомление с кнопкой само не уходит — оно встаёт ниже шапки, чтобы
    // шапка экрана оставалась доступной, пока человек решает.
    final top = media.padding.top + (entry.source.action != null ? 62 : 6);
    return Positioned.fill(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedBuilder(
              animation: _show,
              builder: (context, child) {
                final v = _show.value;
                final opacity = Curves.easeOut.transform(
                  (v * 1.6).clamp(0.0, 1.0),
                );
                if (still) return Opacity(opacity: opacity, child: child);
                // Выезд с лёгким пружинным доводом, как у баннеров iOS.
                final slide = Curves.easeOutBack.transform(v);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, -(1 - slide) * 34),
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * Curves.easeOutCubic.transform(v),
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: _SwipeUpToDismiss(
                key: ObjectKey(entry.source),
                onDismiss: () => entry.messenger?.removeCurrentSnackBar(
                  reason: SnackBarClosedReason.swipe,
                ),
                child: AppleToastCapsule(
                  source: entry.source,
                  messenger: entry.messenger,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Смахнуть капсулу вверх — закрыть.
class _SwipeUpToDismiss extends StatefulWidget {
  const _SwipeUpToDismiss({
    super.key,
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_SwipeUpToDismiss> createState() => _SwipeUpToDismissState();
}

class _SwipeUpToDismissState extends State<_SwipeUpToDismiss> {
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragUpdate: (d) =>
          setState(() => _dy = (_dy + d.delta.dy).clamp(-80.0, 12.0)),
      onVerticalDragEnd: (d) {
        final velocity = d.primaryVelocity ?? 0;
        if (_dy < -24 || velocity < -300) {
          widget.onDismiss();
        } else {
          setState(() => _dy = 0);
        }
      },
      onVerticalDragCancel: () => setState(() => _dy = 0),
      child: Transform.translate(offset: Offset(0, _dy), child: widget.child),
    );
  }
}

/// Сама капсула: матовое стекло, текст по центру, у кнопки действия — цвет
/// акцента.
/// Уже нажатые кнопки действий — по самому уведомлению.
final Expando<bool> _actionFired = Expando<bool>('appleToastActionFired');

class AppleToastCapsule extends StatelessWidget {
  const AppleToastCapsule({super.key, required this.source, this.messenger});

  final SnackBar source;
  final ScaffoldMessengerState? messenger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = dark ? const Color(0xD92C2C2E) : const Color(0xE6FFFFFF);
    final border = dark ? const Color(0x24FFFFFF) : const Color(0x14000000);
    final textColor = dark ? Colors.white : const Color(0xFF111111);
    final action = source.action;
    final content = unwrapSecretlySnackBarContent(source.content);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.2,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: textColor, size: 20),
              child: content,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              // Один раз: пока капсула уезжает, второе нажатие не должно
              // повторить действие (дважды отправить GIF).
              if (_actionFired[source] ?? false) return;
              _actionFired[source] = true;
              action.onPressed();
              messenger?.hideCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: action.textColor ?? scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(44, 36),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(action.label),
          ),
        ],
        if (source.showCloseIcon ?? false) ...[
          const SizedBox(width: 2),
          // Без всплывающей подсказки: капсула лежит вне `Overlay` экрана,
          // и подсказке некуда было бы встать. Подпись — для диктора.
          Semantics(
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            child: IconButton(
              onPressed: () => messenger?.hideCurrentSnackBar(
                reason: SnackBarClosedReason.dismiss,
              ),
              icon: const Icon(Icons.close_rounded),
              iconSize: 18,
              color: textColor.withValues(alpha: 0.6),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );

    // Капсула живёт поверх всех экранов, вне их `Scaffold`: без прозрачного
    // `Material` у текста нет основы оформления, и Flutter рисует его с
    // жёлтым двойным подчёркиванием (поймано на снимках 17.11.2026).
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.36 : 0.14),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      action != null || (source.showCloseIcon ?? false)
                          ? 8
                          : 20,
                      12,
                    ),
                    child: row,
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
