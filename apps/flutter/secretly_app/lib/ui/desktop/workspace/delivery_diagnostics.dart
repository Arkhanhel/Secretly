// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../transport/server_clock.dart';
import '../design/tokens.dart';
import 'workspace_layout.dart';

/// Сводка для поддержки и её подписи — отдельно от отрисовки.
///
/// 🔴 Вынесено, чтобы проверять БЕЗ окна: главное свойство сводки — что в ней
/// нет ничего личного, и такую проверку нельзя ставить в зависимость от того,
/// отрисовалась ли карточка.
class DesktopDeliveryDiagnosticsReport {
  const DesktopDeliveryDiagnosticsReport._();

  /// Расхождение часов словами. Секунды до минуты, дальше минуты, дальше часы:
  /// «сбиты на 93 000 мс» не говорит человеку ничего.
  static String formatSkew(int ms) {
    final abs = ms.abs();
    if (abs < 60 * 1000) return '${(abs / 1000).round()} s';
    if (abs < 60 * 60 * 1000) return '${(abs / 60000).round()} min';
    return '${(abs / 3600000).round()} h';
  }

  /// Одна строка на число, без имён и текстов.
  ///
  /// 🔴 НИЧЕГО ЛИЧНОГО. Сюда не попадают ни собеседники, ни содержимое — только
  /// счётчики и расхождение часов. Человек отправляет это нам, не читая; значит
  /// внутри не должно быть ничего, о чём он мог бы пожалеть.
  static String build(Map<String, int> health, int offsetMs) => <String>[
    'outbox_pending=${health['outbox_pending'] ?? 0}',
    'quarantined=${health['quarantined'] ?? 0}',
    'nacked=${health['nacked'] ?? 0}',
    'receipts_queued=${health['receipts_queued'] ?? 0}',
    'clock_offset_ms=$offsetMs',
  ].join('\n');
}

/// Диагностика доставки на компьютере.
///
/// 🔴 ЗАЧЕМ ОНА ЗДЕСЬ. Когда сообщения не идут, человеку не на что смотреть и
/// нечего прислать в поддержку: экран переписки молчит одинаково и когда всё
/// отправлено, и когда очередь стоит. На телефоне такой экран есть
/// (`delivery_reliability_screen.dart`), на компьютере не было.
///
/// 🔴 ПОЧЕМУ НЕ ПЕРЕНЕСЛИ ТЕЛЕФОННЫЙ ЭКРАН ЦЕЛИКОМ. Он почти весь про причины,
/// которых на компьютере НЕТ: экономия батареи, Data Saver, автозапуск на MIUI,
/// «Фоновое обновление» у iOS. Перенести их значило бы показать человеку список
/// проверок, ни одна из которых к его машине не относится, — это хуже, чем не
/// показывать ничего: он потратит время и решит, что дело не в нас.
///
/// Здесь оставлено то, что на компьютере ПРАВДА ломает доставку:
///   · очереди — сколько сейчас ждёт отправки, застряло на входе, висит в
///     подтверждениях (числа общие с телефоном, `deliveryHealthCounters`);
///   · часы — сбитые часы заставляют сервер отвечать отказом, и это уже
///     случалось в поле;
///   · запуск при входе и разрешение на уведомления живут своими строками в
///     разделах «Основные» и «Уведомления» — дублировать их сюда значило бы
///     завести второе место, где то же самое можно переключить.
class DesktopDeliveryDiagnostics extends StatefulWidget {
  const DesktopDeliveryDiagnostics({
    super.key,
    required this.healthLoader,
    this.clockOffsetMs,
    this.onCopy,
  });

  /// Даёт `deliveryHealthCounters()`. Отдельным параметром — чтобы карточку
  /// можно было проверить без базы.
  final Future<Map<String, int>> Function() healthLoader;

  /// Расхождение часов. `null` — берём у [ServerClock].
  final int? clockOffsetMs;

  /// Куда сложить сводку. `null` — в буфер обмена.
  final void Function(String text)? onCopy;

  @override
  State<DesktopDeliveryDiagnostics> createState() =>
      _DesktopDeliveryDiagnosticsState();
}

class _DesktopDeliveryDiagnosticsState
    extends State<DesktopDeliveryDiagnostics> {
  Map<String, int>? _health;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await widget.healthLoader();
      if (!mounted) return;
      setState(() => _health = h);
    } catch (_) {
      if (!mounted) return;
      // Диагностика, которая сама падает, бесполезна вдвойне: показываем нули,
      // а не пустоту, чтобы человек видел — считать пробовали.
      setState(() => _health = const <String, int>{});
    }
  }

  int get _offsetMs => widget.clockOffsetMs ?? ServerClock.instance.offsetMs;

  Future<void> _copy(String text) async {
    final sink = widget.onCopy;
    if (sink != null) {
      sink(text);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final h = _health;
    if (h == null) {
      return WorkspaceCard(
        title: l10n.desktopDiagTitle,
        description: l10n.desktopDiagHint,
        child: const Padding(
          padding: EdgeInsets.all(DSpace.l),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final outbox = h['outbox_pending'] ?? 0;
    final stuck = h['quarantined'] ?? 0;
    final receipts = h['receipts_queued'] ?? 0;
    final quiet = outbox == 0 && stuck == 0 && receipts == 0;
    final offset = _offsetMs;

    return WorkspaceCard(
      title: l10n.desktopDiagTitle,
      description: l10n.desktopDiagHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceRow(
            label: l10n.desktopDiagOutbox,
            description: quiet ? l10n.desktopDiagNothingStuck : null,
            icon: Icons.outbox_outlined,
            trailing: _Count(value: outbox, danger: outbox > 0),
          ),
          WorkspaceRow(
            label: l10n.desktopDiagStuck,
            icon: Icons.inbox_outlined,
            trailing: _Count(value: stuck, danger: stuck > 0),
          ),
          WorkspaceRow(
            label: l10n.desktopDiagReceipts,
            icon: Icons.done_all_outlined,
            trailing: _Count(value: receipts, danger: false),
          ),
          WorkspaceRow(
            label: offset == 0
                ? l10n.desktopDiagClockOk
                : l10n.desktopDiagClockSkew(DesktopDeliveryDiagnosticsReport.formatSkew(offset)),
            icon: Icons.schedule_outlined,
            dangerous: offset != 0,
          ),
          WorkspaceRow(
            label: _copied ? l10n.copied : l10n.desktopDiagCopy,
            icon: Icons.copy_outlined,
            onTap: () => _copy(DesktopDeliveryDiagnosticsReport.build(h, offset)),
          ),
          if (_copied)
            Padding(
              padding: const EdgeInsets.fromLTRB(DSpace.l, 0, DSpace.l, DSpace.m),
              child: Text(
                l10n.desktopDiagHint,
                style: DType.label.copyWith(color: c.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.danger});

  final int value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Text(
      '$value',
      style: DType.body.copyWith(
        color: danger ? c.danger : c.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
