// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/radii.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/desktop_dialog.dart';

/// One shortcut row: what it does, and the keys that do it.
class _Shortcut {
  const _Shortcut(this.keys, this.label);
  final String keys;
  final String label;
}

/// Таблица горячих клавиш — ОДНА на всё окно.
///
/// 🔴 Список существовал и был доступен ровно одной комбинацией — Cmd+/. То
/// есть увидеть его мог только тот, кто её уже знает: справка, спрятанная за
/// тем, что она объясняет. Теперь та же таблица рисуется и в отдельном разделе
/// настроек, куда приходят глазами.
///
/// Таблица написана руками, а не выведена из карты сочетаний: выведенный
/// список называл бы намерения, а смысл — объяснить, что клавиша ДЕЛАЕТ. Цена
/// — обновлять вместе с картой; она видна в обзоре.
Map<String, List<_Shortcut>> _shortcutGroups() {
  // macOS says ⌘; Windows and Linux say Ctrl. Showing the wrong one is a small
  // lie that makes the whole panel feel unfinished.
  final mod = Platform.isMacOS ? '⌘' : 'Ctrl';
  final alt = Platform.isMacOS ? '⌥' : 'Alt';
  return <String, List<_Shortcut>>{
    'Навигация': [
      _Shortcut('$mod 1 … 4', 'Чаты · Комнаты · Звонки · Контакты'),
      _Shortcut('$mod K', 'Поиск по чатам и сообщениям'),
      _Shortcut('$alt ↑ / ↓', 'Предыдущий / следующий чат'),
    ],
    'В переписке': [
      _Shortcut('$mod F', 'Найти в этой переписке'),
      _Shortcut('Enter', 'Отправить (настраивается)'),
      _Shortcut('Shift Enter', 'Перенос строки'),
      _Shortcut('$mod V', 'Вставить изображение из буфера'),
    ],
    'Приложение': [
      _Shortcut('$mod ,', 'Настройки'),
      _Shortcut('$mod /', 'Эта справка'),
      _Shortcut('Esc', 'Закрыть окно или поиск'),
      _Shortcut('$mod W', 'Свернуть в трей'),
    ],
  };
}

/// Сам список — без окна вокруг. Его рисует и диалог Cmd+/, и раздел настроек.
class ShortcutsList extends StatelessWidget {
  const ShortcutsList({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final groups = _shortcutGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, DSpace.m, 2, DSpace.s),
            child: Text(
              entry.key.toUpperCase(),
              style: DType.meta.copyWith(color: c.textDisabled),
            ),
          ),
          for (final s in entry.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.label,
                      style: DType.body.copyWith(color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: DSpace.m),
                  _KeyCap(keys: s.keys, colors: c),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Keyboard reference, opened with Cmd+/ — the near-universal binding for it.
///
/// Shortcuts that nobody can discover are shortcuts nobody uses. The desktop
/// had accumulated a useful set (sections, spotlight, find, chat cycling) with
/// no way to learn them short of reading the source.
///
/// The list is written by hand rather than generated from the shortcut map on
/// purpose: a generated list would name intents, not actions, and the point is
/// to explain what each key DOES. The cost is that this must be updated
/// alongside the map — cheap, and visible in review.
Future<void> showShortcutsHelp(BuildContext context) {
  return DesktopDialog.show<void>(
    context,
    title: 'Горячие клавиши',
    size: DDialogSize.medium,
    body: const SizedBox(
      height: 420,
      child: SingleChildScrollView(child: ShortcutsList()),
    ),
    secondary: DDialogAction(
      label: 'Закрыть',
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// Keys drawn as caps rather than plain text, so they read as something you
/// press instead of something you read.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.keys, required this.colors});

  final String keys;
  final DColorSet colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final part in keys.split(' '))
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.elevated,
                borderRadius: BorderRadius.circular(DRadii.sm),
                border: Border.all(color: c.borderSubtle),
              ),
              child: Text(
                part,
                style: TextStyle(
                  fontFamily: DType.family,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
