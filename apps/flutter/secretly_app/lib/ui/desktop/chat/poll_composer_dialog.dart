// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ОКНО СОЗДАНИЯ ОПРОСА НА КОМПЬЮТЕРЕ.
///
/// 🔴 Пункт «Опрос» в меню вложений был заготовлен, но никуда не вёл: опрос
/// можно было только получить с телефона. Здесь он собирается: вопрос,
/// варианты и две настройки — несколько ответов и анонимность.
///
/// Телефон для этого открывает нижний лист; на компьютере лист неуместен —
/// берём обычное окно, как у «Новой папки».
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_switch.dart';
import '../primitives/desktop_text_field.dart';

/// Сколько вариантов можно задать. Меньше двух — это не опрос; больше
/// десяти в ленте уже не читается.
const int kDesktopPollMinOptions = 2;
const int kDesktopPollMaxOptions = 10;

class DesktopPollDraft {
  const DesktopPollDraft({
    required this.question,
    required this.options,
    required this.multiple,
    required this.anonymous,
  });

  final String question;
  final List<String> options;
  final bool multiple;
  final bool anonymous;

  /// Варианты без пустых строк и повторов пробелов.
  List<String> get cleanOptions => options
      .map((o) => o.trim())
      .where((o) => o.isNotEmpty)
      .toList(growable: false);

  bool get isValid =>
      question.trim().isNotEmpty &&
      cleanOptions.length >= kDesktopPollMinOptions;
}

/// Спрашивает опрос. `null` — отменили или ввели неполное.
Future<DesktopPollDraft?> showDesktopPollComposer(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final draft = ValueNotifier<DesktopPollDraft>(
    const DesktopPollDraft(
      question: '',
      options: <String>['', ''],
      multiple: false,
      anonymous: false,
    ),
  );
  final result = await DesktopDialog.show<DesktopPollDraft>(
    context,
    title: l10n.desktopPollNewTitle,
    size: DDialogSize.medium,
    body: _PollComposerBody(draft: draft),
    primary: DDialogAction(
      label: l10n.desktopPollCreateAction,
      onPressed: () {
        final value = draft.value;
        // Неполный опрос не отправляем и окно не закрываем: подсказка под
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

class _PollComposerBody extends StatefulWidget {
  const _PollComposerBody({required this.draft});

  final ValueNotifier<DesktopPollDraft> draft;

  @override
  State<_PollComposerBody> createState() => _PollComposerBodyState();
}

class _PollComposerBodyState extends State<_PollComposerBody> {
  late final TextEditingController _question = TextEditingController()
    ..addListener(_publish);
  final List<TextEditingController> _options = <TextEditingController>[];
  bool _multiple = false;
  bool _anonymous = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < kDesktopPollMinOptions; i++) {
      _addOption(publish: false);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption({bool publish = true}) {
    final c = TextEditingController()..addListener(_publish);
    _options.add(c);
    if (publish) setState(_publish);
  }

  void _publish() {
    widget.draft.value = DesktopPollDraft(
      question: _question.text,
      options: _options.map((c) => c.text).toList(growable: false),
      multiple: _multiple,
      anonymous: _anonymous,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopTextField(
          controller: _question,
          hintText: l10n.desktopPollQuestionHint,
          autofocus: true,
        ),
        const SizedBox(height: DSpace.s),
        for (var i = 0; i < _options.length; i++) ...[
          DesktopTextField(
            controller: _options[i],
            hintText: l10n.desktopPollOptionHint(i + 1),
          ),
          const SizedBox(height: DSpace.xs),
        ],
        if (_options.length < kDesktopPollMaxOptions)
          TextButton(
            onPressed: _addOption,
            child: Text(l10n.desktopPollAddOption),
          ),
        const SizedBox(height: DSpace.s),
        Row(
          children: [
            Expanded(child: Text(l10n.desktopPollMultipleLabel)),
            DesktopSwitch(
              value: _multiple,
              onChanged: (v) => setState(() {
                _multiple = v;
                _publish();
              }),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text(l10n.desktopPollAnonymousLabel)),
            DesktopSwitch(
              value: _anonymous,
              onChanged: (v) => setState(() {
                _anonymous = v;
                _publish();
              }),
            ),
          ],
        ),
        const SizedBox(height: DSpace.xs),
        Text(l10n.desktopPollNeedTwo, style: DType.tiny),
      ],
    );
  }
}
