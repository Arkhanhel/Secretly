// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../app/desktop_sync_status.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';

/// Подвал панели списка: состояние связи слева, вход в архив справа.
///
/// 🔴 «СИНХРОНИЗИРОВАНО» НЕ ПОКАЗЫВАЛОСЬ НИКОГДА.
///
/// Состояние связи жило только в полосе поверх всей секции, и в спокойном
/// состоянии эта полоса рисовала пустую строку с прозрачностью ноль. То есть
/// приложение сообщало о связи ровно тогда, когда с ней что-то не так, и
/// молчало, когда всё хорошо. Для мессенджера это неверная сделка: «дошло ли
/// моё сообщение» — вопрос, который задают в спокойном состоянии.
///
/// В макете внизу панели стоит зелёная пилюля «Синхронизировано». Здесь она и
/// живёт — и в остальных состояниях говорит то же самое другими словами и
/// другим цветом, а не исчезает.
class ChatListFooter extends StatelessWidget {
  const ChatListFooter({
    super.key,
    required this.sync,
    this.onOpenArchive,
    this.archiveActive = false,
    this.compact = false,
  });

  /// Список свёрнут в столбик портретов: вместо надписи — одна точка
  /// состояния, а сама надпись уходит в подсказку.
  final bool compact;

  /// Источник состояния. `null` — подвал показывает только архив (тесты,
  /// снимки, вызовы без оболочки).
  final DesktopSyncStatusController? sync;

  /// Открыть архив. `null` — архив пуст, кнопки нет: кнопка, ведущая в пустое
  /// место, врёт о том, что там что-то есть.
  final VoidCallback? onOpenArchive;

  /// Архив сейчас открыт — кнопка подсвечена.
  final bool archiveActive;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DSpace.xs : DSpace.m,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (compact)
            _SyncPill(sync: sync, compact: true)
          else
            Expanded(child: _SyncPill(sync: sync)),
          if (compact && sync != null && onOpenArchive != null)
            const SizedBox(width: DSpace.xs),
          if (onOpenArchive != null)
            DesktopIconButton(
              icon: FluentIcons.archive_24_regular,
              tooltip: 'Архив',
              size: 28,
              iconSize: 16,
              color: archiveActive ? c.accentPrimary : null,
              onPressed: onOpenArchive,
            ),
        ],
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.sync, this.compact = false});

  final DesktopSyncStatusController? sync;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = sync;
    if (s == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: s,
      builder: (ctx, _) => _pill(ctx, s.value.phase),
    );
  }

  Widget _pill(BuildContext context, DesktopSyncPhase phase) {
    final c = DColors.of(context);
    final (Color tone, String label) = switch (phase) {
      DesktopSyncPhase.online => (c.success, 'Синхронизировано'),
      DesktopSyncPhase.syncing => (c.accentPrimary, 'Синхронизация…'),
      DesktopSyncPhase.connecting => (c.textSecondary, 'Подключение…'),
      DesktopSyncPhase.reconnecting => (c.warning, 'Переподключение…'),
    };
    if (compact) {
      return DesktopTooltip(
        message: label,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: DType.tiny.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                // Буквы светлее пятна: на плёнке в 12 % тот же цвет, что у
                // точки, читается тускло.
                color: _lighten(tone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(hsl.lightness < 0.72 ? 0.72 : hsl.lightness)
        .toColor();
  }
}
