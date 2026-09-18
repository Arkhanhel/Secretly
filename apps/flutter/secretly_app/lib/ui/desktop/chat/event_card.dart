// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// КАРТОЧКА СОБЫТИЯ В ЛЕНТЕ КОМПЬЮТЕРА.
///
/// 🔴 Событие с телефона приходило строкой «📅 Название»: ни времени, ни
/// места, ни ответов «иду / не иду». Ответить было нечем.
///
/// Дата показывается числами (`17.09 · 19:00`): так карточка одинаково
/// читается на всех восьми языках и не зависит от словесных форм.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import 'desktop_event_tally.dart';

class DesktopEventCard extends StatelessWidget {
  const DesktopEventCard({
    super.key,
    required this.event,
    required this.foreground,
    required this.foregroundSoft,
    this.onRsvp,
  });

  final DesktopEventView event;
  final Color foreground;
  final Color foregroundSoft;

  /// Ответили на приглашение. `null` — отвечать нельзя (личный чат).
  final ValueChanged<String>? onRsvp;

  static String formatStart(int startMs) {
    if (startMs <= 0) return '';
    final at = DateTime.fromMillisecondsSinceEpoch(startMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}.${two(at.month)} · ${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final when = formatStart(event.startMs);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.desktopEventTitle,
          style: DType.tiny.copyWith(
            color: foregroundSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(event.title, style: DType.bodyStrong.copyWith(color: foreground)),
        if (when.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(when, style: DType.caption.copyWith(color: foreground)),
        ],
        if (event.location.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            event.location,
            style: DType.tiny.copyWith(color: foregroundSoft),
          ),
        ],
        if (event.description.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            event.description,
            style: DType.body.copyWith(color: foreground),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _choice(l10n.desktopEventGoing, DesktopEventRsvp.going),
            _choice(l10n.desktopEventMaybe, DesktopEventRsvp.maybe),
            _choice(l10n.desktopEventNo, DesktopEventRsvp.no),
          ],
        ),
      ],
    );
  }

  Widget _choice(String label, String status) {
    final picked = event.myStatus == status;
    final count = event.countFor(status);
    final text = count > 0 ? '$label · $count' : label;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: picked
            ? foreground.withValues(alpha: 0.18)
            : foregroundSoft.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DRadii.pill),
      ),
      child: Text(
        text,
        style: DType.tiny.copyWith(
          color: picked ? foreground : foregroundSoft,
          fontWeight: picked ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
    if (onRsvp == null) return body;
    return InkWell(
      onTap: () => onRsvp!(status),
      borderRadius: BorderRadius.circular(DRadii.pill),
      child: body,
    );
  }
}
