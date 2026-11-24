// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Лаги клавиатуры (разбор 20.11.2026, запись кадров Xiaomi): отступ
/// клавиатуры (`viewInsets`, а на Android и `padding.bottom`) меняется в
/// КАЖДОМ кадре её появления. MediaQuery один на всё приложение, поэтому
/// перестраивались и страницы ПОД открытым чатом — оболочка с вкладками,
/// список чатов, контакты, настройки, — хотя их не видно.
///
/// [CoveredRouteMediaFreeze] стоит в корне страницы. Пока страницу целиком
/// закрывает другая — Flutter сам убирает такую страницу «за кулисы» и
/// выключает ей анимации (`TickerMode`), — отступы клавиатуры для неё
/// замирают на значении в момент закрытия; остальное (размер, шрифт,
/// поворот) идёт как обычно. Как только начинается возврат — свайп назад или
/// «Назад», — страница выходит из-за кулис, заморозка снимается, и она
/// получает живые значения ещё до того, как её станет видно.
///
/// Окна, меню и листы прозрачны — страница под ними остаётся на сцене и
/// живой, как раньше.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Выключатель на случай отката.
const bool kFreezeCoveredRouteMedia = true;

/// Снимок MediaQuery БЕЗ подписки на него. Для обработчиков (открыть меню,
/// показать лист): обычный `MediaQuery.of(context)` в обработчике навсегда
/// подписывает весь экран на MediaQuery, и тот начинает перестраиваться в
/// каждом кадре клавиатуры.
MediaQueryData mediaQueryNow(BuildContext context) =>
    context.getInheritedWidgetOfExactType<MediaQuery>()?.data ??
    MediaQueryData.fromView(View.of(context));

class CoveredRouteMediaFreeze extends StatefulWidget {
  const CoveredRouteMediaFreeze({super.key, required this.child});

  final Widget child;

  @override
  State<CoveredRouteMediaFreeze> createState() =>
      _CoveredRouteMediaFreezeState();
}

class _CoveredRouteMediaFreezeState extends State<CoveredRouteMediaFreeze> {
  ValueListenable<TickerModeData>? _tickerMode;
  bool _covered = false;
  MediaQueryData? _frozen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (!identical(tickerMode, _tickerMode)) {
      _tickerMode?.removeListener(_onTickerMode);
      _tickerMode = tickerMode..addListener(_onTickerMode);
      _covered = _isCovered;
      if (!_covered) _frozen = null;
    }
  }

  bool get _isCovered =>
      kFreezeCoveredRouteMedia && !(_tickerMode?.value.enabled ?? true);

  void _onTickerMode() {
    final covered = _isCovered;
    if (covered == _covered || !mounted) return;
    setState(() {
      _covered = covered;
      if (!covered) _frozen = null;
    });
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = MediaQuery.of(context);
    var data = live;
    if (_covered) {
      final frozen = _frozen ??= live;
      data = live.copyWith(
        viewInsets: frozen.viewInsets,
        padding: frozen.padding,
        systemGestureInsets: frozen.systemGestureInsets,
      );
    }
    // Дерево одной формы всегда: MediaQuery есть и без заморозки (с теми же
    // данными, что выше), иначе включение/снятие пересоздавало бы страницу.
    return MediaQuery(data: data, child: widget.child);
  }
}
