// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Выбор «открытый / закрытый» для своего набора стикеров
/// (docs/TZ_STICKER_PACKS_2026-11-14.md §2.2).
///
/// 🔴 Под каждым вариантом — одна честная фраза. Для закрытого она прямо
/// говорит, что присланное остаётся у собеседника: обещать «никто не
/// сохранит» значило бы обмануть, и первый же снимок экрана это вскроет.
library;

import 'package:flutter/material.dart';

import '../../stickers/sticker_share_mode.dart';
import '../l10n.dart';

class StickerPackAccessPicker extends StatelessWidget {
  const StickerPackAccessPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.showExistingNote = false,
    this.foreground = Colors.white,
  });

  /// Только [StickerShareMode.sentOnly] (открытый) или
  /// [StickerShareMode.personal] (закрытый). Публикации здесь нет.
  final StickerShareMode value;
  final ValueChanged<StickerShareMode>? onChanged;

  /// Набор уже существует: при выборе «закрытый» сказать, что у добавивших
  /// он останется.
  final bool showExistingNote;

  /// Цвет текста: белый в тёмных листах телефона, цвет темы — в остальных.
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final closed = value == StickerShareMode.personal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stickerPackAccessTitle,
          style: TextStyle(
            color: foreground.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _option(
          key: const ValueKey('sticker-pack-access-open'),
          icon: Icons.group_rounded,
          title: l10n.stickerPackAccessOpen,
          hint: l10n.stickerPackAccessOpenHint,
          selected: !closed,
          onTap: onChanged == null
              ? null
              : () => onChanged!(StickerShareMode.sentOnly),
        ),
        const SizedBox(height: 6),
        _option(
          key: const ValueKey('sticker-pack-access-closed'),
          icon: Icons.lock_rounded,
          title: l10n.stickerPackAccessClosed,
          hint: closed && showExistingNote
              ? '${l10n.stickerPackAccessClosedHint} '
                    '${l10n.stickerPackClosedExistingNote}'
              : l10n.stickerPackAccessClosedHint,
          selected: closed,
          onTap: onChanged == null
              ? null
              : () => onChanged!(StickerShareMode.personal),
        ),
      ],
    );
  }

  Widget _option({
    required Key key,
    required IconData icon,
    required String title,
    required String hint,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    const accent = Color(0xFF4DA3FF);
    return Semantics(
      key: key,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : foreground.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : foreground.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? accent : foreground.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
