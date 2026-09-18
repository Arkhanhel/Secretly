// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// КАРТОЧКА ОПРОСА В ЛЕНТЕ КОМПЬЮТЕРА.
///
/// 🔴 Раньше опрос с телефона приходил на компьютер строкой «📊 Опрос: …»:
/// вариантов не видно, проголосовать нечем, итог неизвестен. Голосование —
/// это разговор, и в переписке ему место рядом с сообщениями.
///
/// Подсчёт голосов сюда приходит готовым (`DesktopPollView`), виджет только
/// показывает и сообщает о нажатии.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import 'desktop_poll_tally.dart';

class DesktopPollCard extends StatelessWidget {
  const DesktopPollCard({
    super.key,
    required this.poll,
    required this.foreground,
    required this.foregroundSoft,
    this.onVote,
    this.onClose,
  });

  final DesktopPollView poll;
  final Color foreground;
  final Color foregroundSoft;

  /// Нажали вариант. `null` — голосовать нельзя (чужая лента, нет связи).
  final ValueChanged<int>? onVote;

  /// Нажали «Завершить опрос». Показывается только создателю.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canVote = !poll.closed && onVote != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                poll.anonymous
                    ? l10n.desktopPollAnonymous
                    : l10n.desktopPollTitle,
                style: DType.tiny.copyWith(
                  color: foregroundSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (poll.closed)
              Text(
                l10n.desktopPollClosed,
                style: DType.tiny.copyWith(
                  color: foregroundSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          poll.question,
          style: DType.bodyStrong.copyWith(color: foreground),
        ),
        if (poll.multiple && !poll.hasVoted) ...[
          const SizedBox(height: 2),
          Text(
            l10n.desktopPollMultipleHint,
            style: DType.tiny.copyWith(color: foregroundSoft),
          ),
        ],
        const SizedBox(height: 6),
        for (var i = 0; i < poll.options.length; i++)
          _option(context, i, canVote: canVote),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.desktopPollVoters(poll.totalVoters),
                style: DType.tiny.copyWith(color: foregroundSoft),
              ),
            ),
            if (poll.isCreator && !poll.closed && onClose != null)
              _CloseButton(label: l10n.desktopPollCloseAction, onTap: onClose!),
          ],
        ),
      ],
    );
  }

  Widget _option(BuildContext context, int index, {required bool canVote}) {
    final picked = poll.myOptionIndices.contains(index);
    final mark = poll.multiple
        ? (picked
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded)
        : (picked
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mark,
                size: 16,
                color: picked ? foreground : foregroundSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.options[index],
                  style: DType.body.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${poll.votesPerOption[index]}',
                style: DType.tiny.copyWith(color: foregroundSoft),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: poll.share(index),
              minHeight: 3,
              backgroundColor: foregroundSoft.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(
                foreground.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
    if (!canVote) return row;
    return InkWell(
      onTap: () => onVote?.call(index),
      borderRadius: BorderRadius.circular(DRadii.sm),
      child: row,
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: DType.tiny),
    );
  }
}
