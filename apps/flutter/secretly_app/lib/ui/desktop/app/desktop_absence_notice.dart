// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../services/desktop_absence.dart';

/// One-time notice that this desktop was offline long enough to have missed
/// messages — see [DesktopAbsence] for the two server windows behind it.
///
/// Deliberately NOT folded into the sync indicator (now `ChatListFooter`):
/// that pill is small
/// and carries transient phases (connecting / syncing) that resolve on their
/// own within seconds. This is the opposite kind of message — a fact about the
/// past that will not resolve, needs a sentence to state honestly, and has to
/// be acknowledged rather than waited out.
class DesktopAbsenceNotice extends StatelessWidget {
  const DesktopAbsenceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: DesktopAbsence.awayDays,
      builder: (context, days, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: days == null
              ? const SizedBox(width: double.infinity, height: 0)
              : _Notice(days: days),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.days});

  final int days;

  /// Past the fanout window the loss is categorically worse: senders stopped
  /// encrypting to this device at all, rather than merely having their mail
  /// expire. Saying the same sentence for both would understate one case and
  /// overstate the other.
  bool get _pastFanoutWindow => days >= DesktopAbsence.fanoutWindowDays;

  String get _body {
    if (_pastFanoutWindow) {
      return 'Этот компьютер не выходил на связь $days ${_dayWord(days)}. '
          'За это время отправители перестали шифровать сообщения для него, '
          'и часть переписки сюда не придёт. Она цела на телефоне — '
          'откройте там нужные чаты, и свежая история подтянется.';
    }
    return 'Этот компьютер не выходил на связь $days ${_dayWord(days)}. '
        'Сообщения хранятся на сервере неделю, поэтому часть из них могла '
        'не сохраниться для него. На телефоне они целы.';
  }

  static String _dayWord(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    switch (n % 10) {
      case 1:
        return 'день';
      case 2:
      case 3:
      case 4:
        return 'дня';
      default:
        return 'дней';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final accent = _pastFanoutWindow ? c.danger : c.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        DSpace.l,
        DSpace.m,
        DSpace.m,
        DSpace.m,
      ),
      decoration: BoxDecoration(
        color: c.elevated,
        border: Border(
          bottom: BorderSide(color: c.borderSubtle),
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              FluentIcons.warning_24_regular,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: DSpace.m),
          Expanded(
            child: Text(
              _body,
              style: DType.caption.copyWith(color: c.textPrimary, height: 1.45),
            ),
          ),
          const SizedBox(width: DSpace.m),
          // A plain, obvious dismissal. The notice is about something the user
          // cannot act on here, so the only honest control is "I have read it".
          IconButton(
            tooltip: 'Понятно',
            icon: Icon(
              FluentIcons.dismiss_24_regular,
              size: 16,
              color: c.textSecondary,
            ),
            onPressed: DesktopAbsence.dismiss,
          ),
        ],
      ),
    );
  }
}
