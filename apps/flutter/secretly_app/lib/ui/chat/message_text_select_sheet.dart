// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Выделение части текста сообщения (21.11.2026, владелец: «зажимаю на смс —
/// оно выделяется, потом ещё раз зажимаю — и уже выделяю текст, нужное
/// копирую»).
///
/// Первое долгое касание выделяет сообщение (как было), второе на уже
/// выделенном — открывает этот лист: текст целиком, выделяется пальцем
/// (системные ручки и меню «Скопировать»), внизу «Скопировать выделенное»
/// и «Скопировать всё». Пузырь в ленте не трогаем — его жесты (касание,
/// двойное касание, свайп ответа) остаются прежними.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_screen_l10n.dart';
import '../motion/app_dialogs.dart';

/// Открыть лист выделения. Возвращает скопированный текст или `null`.
Future<String?> showMessageTextSelectSheet(
  BuildContext context, {
  required String text,
  String? author,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: appSheetAnimationStyle,
    builder: (_) => MessageTextSelectSheet(text: text, author: author),
  );
}

class MessageTextSelectSheet extends StatefulWidget {
  const MessageTextSelectSheet({super.key, required this.text, this.author});

  final String text;
  final String? author;

  @override
  State<MessageTextSelectSheet> createState() => _MessageTextSelectSheetState();
}

class _MessageTextSelectSheetState extends State<MessageTextSelectSheet> {
  TextSelection _selection = const TextSelection.collapsed(offset: 0);

  String get _selected {
    final s = _selection;
    if (!s.isValid || s.isCollapsed) return '';
    final start = s.start.clamp(0, widget.text.length);
    final end = s.end.clamp(0, widget.text.length);
    return widget.text.substring(start, end);
  }

  Future<void> _copy(String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    final hasSelection = _selected.isNotEmpty;
    final author = widget.author?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            chatText(
              context,
              ru: 'Выделите нужный текст',
              en: 'Select the text you need',
              uk: 'Виділіть потрібний текст',
              es: 'Selecciona el texto',
              pt: 'Selecione o texto',
              fr: 'Sélectionnez le texte',
              de: 'Text auswählen',
            ),
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (author.isNotEmpty) ...[
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    SelectableText(
                      widget.text,
                      key: const ValueKey('message-text-select'),
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        color: cs.onSurface,
                      ),
                      onSelectionChanged: (selection, _) =>
                          setState(() => _selection = selection),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  key: const ValueKey('message-text-copy-selected'),
                  onPressed: hasSelection ? () => _copy(_selected) : null,
                  child: Text(
                    chatText(
                      context,
                      ru: 'Скопировать выделенное',
                      en: 'Copy selection',
                      uk: 'Скопіювати виділене',
                      es: 'Copiar selección',
                      pt: 'Copiar seleção',
                      fr: 'Copier la sélection',
                      de: 'Auswahl kopieren',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('message-text-copy-all'),
                  onPressed: () => _copy(widget.text),
                  child: Text(
                    chatText(
                      context,
                      ru: 'Скопировать всё',
                      en: 'Copy all',
                      uk: 'Скопіювати все',
                      es: 'Copiar todo',
                      pt: 'Copiar tudo',
                      fr: 'Tout copier',
                      de: 'Alles kopieren',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
