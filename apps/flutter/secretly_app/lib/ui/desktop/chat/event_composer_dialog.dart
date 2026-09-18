// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ОКНО СОЗДАНИЯ СОБЫТИЯ НА КОМПЬЮТЕРЕ.
///
/// 🔴 Событие можно было только получить с телефона: в меню вложений пункта
/// не было вовсе. Здесь оно собирается: название, дата и время, место и
/// описание. Дата выбирается системными окнами — теми же, что у «отправить
/// позже».
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_text_field.dart';
import 'event_card.dart' show DesktopEventCard;

class DesktopEventDraft {
  const DesktopEventDraft({
    required this.title,
    required this.startMs,
    required this.description,
    required this.location,
  });

  final String title;
  final int startMs;
  final String description;
  final String location;

  bool get isValid => title.trim().isNotEmpty && startMs > 0;
}

/// Спрашивает событие. `null` — отменили или ввели неполное.
Future<DesktopEventDraft?> showDesktopEventComposer(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final draft = ValueNotifier<DesktopEventDraft>(
    const DesktopEventDraft(
      title: '',
      startMs: 0,
      description: '',
      location: '',
    ),
  );
  final result = await DesktopDialog.show<DesktopEventDraft>(
    context,
    title: l10n.desktopEventNewTitle,
    size: DDialogSize.medium,
    body: _EventComposerBody(draft: draft),
    primary: DDialogAction(
      label: l10n.desktopPollCreateAction,
      onPressed: () {
        final value = draft.value;
        // Неполное событие не отправляем и окно не закрываем: подсказка под
        // полями объясняет, чего не хватает.
        if (!value.isValid) return;
        Navigator.of(context).maybePop(value);
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
  draft.dispose();
  return result;
}

class _EventComposerBody extends StatefulWidget {
  const _EventComposerBody({required this.draft});

  final ValueNotifier<DesktopEventDraft> draft;

  @override
  State<_EventComposerBody> createState() => _EventComposerBodyState();
}

class _EventComposerBodyState extends State<_EventComposerBody> {
  late final TextEditingController _title = TextEditingController()
    ..addListener(_publish);
  late final TextEditingController _description = TextEditingController()
    ..addListener(_publish);
  late final TextEditingController _location = TextEditingController()
    ..addListener(_publish);
  DateTime? _startAt;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _publish() {
    widget.draft.value = DesktopEventDraft(
      title: _title.text,
      startMs: _startAt?.millisecondsSinceEpoch ?? 0,
      description: _description.text,
      location: _location.text,
    );
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt ?? now.add(const Duration(hours: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _startAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _publish();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final at = _startAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopTextField(
          controller: _title,
          hintText: l10n.desktopEventTitleHint,
          autofocus: true,
        ),
        const SizedBox(height: DSpace.s),
        Row(
          children: [
            TextButton(
              onPressed: () => unawaitedPick(_pickWhen()),
              child: Text(l10n.desktopEventPickWhen),
            ),
            const SizedBox(width: DSpace.xs),
            if (at != null)
              Text(
                DesktopEventCard.formatStart(at.millisecondsSinceEpoch),
                style: DType.caption,
              ),
          ],
        ),
        const SizedBox(height: DSpace.xs),
        DesktopTextField(
          controller: _location,
          hintText: l10n.desktopEventLocationHint,
        ),
        const SizedBox(height: DSpace.xs),
        DesktopTextField(
          controller: _description,
          hintText: l10n.desktopEventDescriptionHint,
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: DSpace.xs),
        Text(l10n.desktopEventNeedTitleAndDate, style: DType.tiny),
      ],
    );
  }
}

/// Мелкая обёртка: нажатие кнопки ничего не ждёт.
void unawaitedPick(Future<void> future) {
  future.ignore();
}
