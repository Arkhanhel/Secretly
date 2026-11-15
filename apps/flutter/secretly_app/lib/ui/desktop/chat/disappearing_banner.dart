// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/radii.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Плашка исчезающих сообщений под шапкой переписки (ТЗ 22.10.2026, §2.4):
/// у собеседника или на моём устройстве старая версия, и там сообщения не
/// исчезнут. Островок той же формы, что «Идёт обсуждение» и закреплённое, —
/// жёлтый по смыслу «осторожно».
///
/// Текст готовит вызывающий (`disappearingSupportWarning`): плашка о
/// протоколе ничего не знает.
class DesktopDisappearingBanner extends StatelessWidget {
  const DesktopDisappearingBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DRadii.lg),
            color: c.warning.withValues(alpha: 0.12),
            border: Border.all(color: c.warning.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.m,
              vertical: DSpace.s + 2,
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.warning_20_regular,
                  size: 18,
                  color: c.warning,
                ),
                const SizedBox(width: DSpace.s),
                Expanded(
                  child: Text(
                    message,
                    style: DType.caption.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Значок срока в подвале пузыря (ТЗ 22.10.2026): таймер, а когда до
/// удаления меньше часа — обратный отсчёт «мм:сс», как у Signal. Пока
/// отсчёт не начался (входящее не прочитано), — только значок.
///
/// Тикает сам и только в последний час: остальные пузыри не перестраиваются.
class DesktopDisappearMark extends StatefulWidget {
  const DesktopDisappearMark({
    super.key,
    required this.expiresAtMs,
    required this.color,
  });

  final int? expiresAtMs;
  final Color color;

  @override
  State<DesktopDisappearMark> createState() => _DesktopDisappearMarkState();
}

class _DesktopDisappearMarkState extends State<DesktopDisappearMark> {
  static const int _countdownWindowMs = 60 * 60 * 1000;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant DesktopDisappearMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAtMs != widget.expiresAtMs) _arm();
  }

  void _arm() {
    _ticker?.cancel();
    _ticker = null;
    final at = widget.expiresAtMs;
    if (at == null) return;
    final left = at - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return;
    if (left <= _countdownWindowMs) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if ((widget.expiresAtMs ?? 0) <= DateTime.now().millisecondsSinceEpoch) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else {
      // Войти в последний час — и начать тикать.
      _ticker = Timer(Duration(milliseconds: left - _countdownWindowMs), () {
        if (mounted) setState(_arm);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.expiresAtMs;
    String? countdown;
    if (at != null) {
      final left = at - DateTime.now().millisecondsSinceEpoch;
      if (left > 0 && left <= _countdownWindowMs) {
        final total = (left / 1000).ceil();
        final mm = (total ~/ 60).toString().padLeft(2, '0');
        final ss = (total % 60).toString().padLeft(2, '0');
        countdown = '$mm:$ss';
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.timer_16_regular, size: 11, color: widget.color),
        if (countdown != null) ...[
          const SizedBox(width: 2),
          Text(
            countdown,
            style: DType.tiny.copyWith(
              color: widget.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
