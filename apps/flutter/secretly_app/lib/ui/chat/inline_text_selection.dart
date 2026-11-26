// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Выделение части текста прямо в пузыре: слово под пальцем, ручки, меню.
///
/// Касания самого пузыря в режиме выделения сообщений перекрыты (ссылки,
/// реакции и цитата не должны срабатывать), поэтому слово выбирает чат —
/// [InlineTextSelectionState.selectWordAt]; ручки, лупа и меню системные и
/// живут поверх экрана, им перекрытие не мешает.
class InlineTextSelection extends StatefulWidget {
  const InlineTextSelection({
    super.key,
    required this.child,
    required this.menu,
    required this.onCleared,
  });

  final Widget child;

  /// Кнопки меню для выделенного текста.
  final List<ContextMenuButtonItem> Function(InlineTextSelectionState selection)
  menu;

  /// Выделение сняли (пусто после непустого).
  final VoidCallback onCleared;

  @override
  State<InlineTextSelection> createState() => InlineTextSelectionState();
}

/// Слово ВНУТРИ уже выделенного: строка такое событие пропускает («палец и так
/// на выделении»), поэтому прежнее снимаем сами. Снаружи это одно изменение —
/// ручки и меню не пропадают.
class _WordSelectionDelegate extends StaticSelectionContainerDelegate {
  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    for (final s in selectables) {
      dispatchSelectionEventToChild(s, const ClearSelectionEvent());
    }
    return super.handleSelectWord(event);
  }
}

class InlineTextSelectionState extends State<InlineTextSelection> {
  final GlobalKey<SelectionAreaState> _area = GlobalKey<SelectionAreaState>();
  final _WordSelectionDelegate _delegate = _WordSelectionDelegate();
  bool _hadContent = false;
  bool _selecting = false;
  bool _gotContent = false;

  /// Что выделено сейчас — всегда из самих строк, а не из последнего
  /// уведомления: после выбора слова уведомление ещё от «всего текста».
  String get selectedText => _delegate.getSelectedContent()?.plainText ?? '';

  SelectableRegionState? get _region => _area.currentState?.selectableRegion;

  /// Всё; `false` — строки ещё не зарегистрировались в области (пузырь стал
  /// выделяемым в этом же кадре).
  bool _selectAllNow() {
    final region = _region;
    if (region == null) return false;
    _selecting = true;
    _gotContent = false;
    // Причина «меню» — так область сама показывает ручки и меню.
    region.selectAll(SelectionChangedCause.toolbar);
    _selecting = false;
    return _gotContent;
  }

  void selectAll() => _whenReady(null);

  /// Слово под [globalPosition]; мимо слов — весь текст.
  void selectWordAt(Offset globalPosition) => _whenReady(globalPosition);

  void _whenReady(Offset? word, [int tries = 6]) {
    if (!_selectAllNow()) {
      if (tries <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _whenReady(word, tries - 1);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    if (word == null) return;
    _delegate.dispatchSelectionEvent(
      SelectWordSelectionEvent(globalPosition: word),
    );
    if (selectedText.trim().isEmpty || !_overText(word)) _selectAllNow();
  }

  /// Точка на строках (а не на полях вокруг).
  bool _overText(Offset global) {
    for (final s in _delegate.selectables) {
      final m = s.getTransformTo(null);
      for (final r in s.boundingBoxes) {
        if (MatrixUtils.transformRect(m, r).contains(global)) return true;
      }
    }
    return false;
  }

  void hideMenu() => _region?.hideToolbar();

  void _onChanged(SelectedContent? content) {
    if (_selecting) {
      // «Выделить всё» сперва снимает прежнее — это не отмена.
      if ((content?.plainText ?? '').isNotEmpty) {
        _hadContent = true;
        _gotContent = true;
      }
      return;
    }
    if ((content?.plainText ?? '').isNotEmpty) {
      _hadContent = true;
    } else if (_hadContent) {
      _hadContent = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCleared();
      });
    }
  }

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    key: _area,
    onSelectionChanged: _onChanged,
    contextMenuBuilder: (menuContext, region) =>
        AdaptiveTextSelectionToolbar.buttonItems(
          anchors: region.contextMenuAnchors,
          buttonItems: widget.menu(this),
        ),
    child: SelectionContainer(delegate: _delegate, child: widget.child),
  );
}
