// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'wave1_l10n.dart';
import 'widgets/secretly_glass_sheet.dart';

/// P3 of in-chat search: an island-styled bottom sheet with a 3-column wheel
/// picker (Day | Month | Year). Day and month wheels loop; the day count is
/// recomputed whenever month/year changes so e.g. February never shows day 30.
/// Each detent change fires a short ratchet/tick sound (fire-and-forget,
/// fail-silent).
///
/// Returns the chosen [DateTime] (midnight of the picked day) or `null` when
/// cancelled / dismissed. Fully additive + fail-soft.
Future<DateTime?> showSearchDateCarousel(
  BuildContext context, {
  required DateTime initialDate,
  required int earliestYear,
}) {
  final now = DateTime.now();
  final maxYear = now.year;
  // Year range: from the earliest hit's year (clamped) up to the current year.
  final minYear = earliestYear.clamp(1970, maxYear);
  final safeInitial = DateTime(
    initialDate.year.clamp(minYear, maxYear),
    initialDate.month.clamp(1, 12),
    initialDate.day.clamp(1, 28), // re-clamped to real month length below
  );

  return showModalBottomSheet<DateTime>(
    context: context,
    enableDrag: true,
    isDismissible: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SecretlyGlassSheetSurface(
            borderRadius: BorderRadius.circular(30),
            child: _SearchDateCarousel(
              minYear: minYear,
              maxYear: maxYear,
              initialDate: DateTime(
                safeInitial.year,
                safeInitial.month,
                initialDate.day.clamp(
                  1,
                  _daysInMonth(safeInitial.year, safeInitial.month),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

int _daysInMonth(int year, int month) {
  // Day 0 of the next month == last day of [month]; DateTime handles Dec→Jan
  // rollover and leap years for us.
  return DateTime(year, month + 1, 0).day;
}

class _SearchDateCarousel extends StatefulWidget {
  const _SearchDateCarousel({
    required this.minYear,
    required this.maxYear,
    required this.initialDate,
  });

  final int minYear;
  final int maxYear;
  final DateTime initialDate;

  @override
  State<_SearchDateCarousel> createState() => _SearchDateCarouselState();
}

class _SearchDateCarouselState extends State<_SearchDateCarousel> {
  late int _year;
  late int _month; // 1..12
  late int _day; // 1..daysInMonth

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  AudioPlayer? _tickPlayer;

  static const double _itemExtent = 38;

  List<int> get _years => <int>[
    for (var y = widget.maxYear; y >= widget.minYear; y--) y,
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _day = widget.initialDate.day;

    final yearIndex = _years.indexOf(_year);
    _yearCtrl = FixedExtentScrollController(
      initialItem: yearIndex < 0 ? 0 : yearIndex,
    );
    // Day & month wheels loop, so the controller item is the raw 0-based slot.
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    _tickPlayer?.dispose();
    super.dispose();
  }

  /// Soft mechanical ratchet on each wheel detent. Best-effort — any
  /// load/playback failure is swallowed so scrolling never breaks.
  void _playTick() {
    try {
      final prev = _tickPlayer;
      final player = AudioPlayer();
      _tickPlayer = player;
      prev?.dispose();
      player.setAsset('assets/app_ui/sounds/inchat/switch_click.mp3').then((_) {
        player.play();
      }).catchError((_) {});
    } catch (_) {
      // non-essential
    }
  }

  /// After a month/year change the selected day may exceed the new month's
  /// length (e.g. 31 → February). Clamp it and animate the day wheel back.
  void _clampDayToMonth() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      // Defer the wheel correction so we don't mutate during a scroll callback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_dayCtrl.hasClients) {
          _dayCtrl.animateToItem(
            _day - 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _monthLabel(int month) {
    const ru = <String>[
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    const en = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const uk = <String>[
      'Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
      'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень',
    ];
    const es = <String>[
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    const pt = <String>[
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    const fr = <String>[
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    const de = <String>[
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    final idx = (month - 1).clamp(0, 11);
    final tag = wave1LocaleTagFromContext(context);
    final table = switch (tag) {
      'ru' => ru,
      'uk' => uk,
      'es' => es,
      'pt' => pt,
      'pt_BR' => pt,
      'fr' => fr,
      'de' => de,
      _ => en,
    };
    return table[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = cs.onSurface;
    final daysInMonth = _daysInMonth(_year, _month);

    final selectionDeco = BoxDecoration(
      color: fg.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 2),
          const Center(child: SecretlyGlassSheetHandle()),
          const SizedBox(height: 12),
          Text(
            wave1Text(
              context,
              ru: 'Перейти к дате',
              en: 'Jump to date',
              uk: 'Перейти до дати',
              es: 'Ir a la fecha',
              pt: 'Ir para a data',
              ptBr: 'Ir para a data',
              fr: 'Aller à la date',
              de: 'Zum Datum springen',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _itemExtent * 5,
            child: Stack(
              children: <Widget>[
                // Centered selection band behind all three wheels.
                Center(
                  child: Container(
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: selectionDeco,
                  ),
                ),
                Row(
                  children: <Widget>[
                    // ── Day (loops) ──
                    Expanded(
                      flex: 3,
                      child: CupertinoPicker(
                        scrollController: _dayCtrl,
                        itemExtent: _itemExtent,
                        looping: true,
                        squeeze: 1.1,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (raw) {
                          // Looping → raw index can grow unbounded; fold it.
                          final d = (raw % daysInMonth + daysInMonth) %
                                  daysInMonth +
                              1;
                          setState(() => _day = d);
                          _playTick();
                        },
                        children: <Widget>[
                          for (var d = 1; d <= daysInMonth; d++)
                            Center(
                              child: Text(
                                '$d',
                                style: TextStyle(fontSize: 19, color: fg),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ── Month (loops) ──
                    Expanded(
                      flex: 5,
                      child: CupertinoPicker(
                        scrollController: _monthCtrl,
                        itemExtent: _itemExtent,
                        looping: true,
                        squeeze: 1.1,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (raw) {
                          final m = (raw % 12 + 12) % 12 + 1;
                          setState(() {
                            _month = m;
                            _clampDayToMonth();
                          });
                          _playTick();
                        },
                        children: <Widget>[
                          for (var m = 1; m <= 12; m++)
                            Center(
                              child: Text(
                                _monthLabel(m),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 18, color: fg),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ── Year (bounded) ──
                    Expanded(
                      flex: 4,
                      child: CupertinoPicker(
                        scrollController: _yearCtrl,
                        itemExtent: _itemExtent,
                        squeeze: 1.1,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) {
                          final years = _years;
                          if (i < 0 || i >= years.length) return;
                          setState(() {
                            _year = years[i];
                            _clampDayToMonth();
                          });
                          _playTick();
                        },
                        children: <Widget>[
                          for (final y in _years)
                            Center(
                              child: Text(
                                '$y',
                                style: TextStyle(fontSize: 19, color: fg),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    wave1Text(
                      context,
                      ru: 'Отмена',
                      en: 'Cancel',
                      uk: 'Скасувати',
                      es: 'Cancelar',
                      pt: 'Cancelar',
                      ptBr: 'Cancelar',
                      fr: 'Annuler',
                      de: 'Abbrechen',
                    ),
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final maxDay = _daysInMonth(_year, _month);
                    final d = _day.clamp(1, maxDay);
                    Navigator.of(context).pop(DateTime(_year, _month, d));
                  },
                  child: Text(
                    wave1Text(
                      context,
                      ru: 'Перейти к дате',
                      en: 'Go to date',
                      uk: 'Перейти до дати',
                      es: 'Ir a la fecha',
                      pt: 'Ir para a data',
                      ptBr: 'Ir para a data',
                      fr: 'Aller à la date',
                      de: 'Zum Datum',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
