// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Редактор фото поверх просмотра медиа — макет «Просмотр медиа», раздел
/// «Редактор» (прототип `MediaViewerPhone.dc.html`, блок EDITOR).
///
/// Раскладка от настоящего экрана, а не от 390×844 прототипа: строка шапки —
/// на `viewPadding.top + 6` (высота 48), рабочая зона — от шапки + 6 до
/// панели инструментов, панель — 164 px над строкой вкладок, вкладки — 54 px
/// над нижним безопасным отступом (не меньше 8).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n.dart';
import '../media_edits.dart';
import '../media_sheet.dart';
import '../media_viewer_tokens.dart';
import 'media_editor_adjust.dart';
import 'media_editor_crop.dart';
import 'media_editor_draw.dart';
import 'media_editor_model.dart';
import 'media_editor_widgets.dart';

export 'media_editor_model.dart' show MediaEditorTab;

/// Full-screen editor over the viewer. Returns the edited result (cleaned:
/// empty texts removed) on «Готово», null on «Отмена»/back.
Future<MediaEdits?> openMediaEditor(
  BuildContext context, {
  required ImageProvider image,
  required double sourceAspect,
  required MediaEdits initial,
  MediaEditorTab initialTab = MediaEditorTab.crop,
  bool Function()? hapticsEnabled,
}) {
  return Navigator.of(context).push<MediaEdits?>(
    PageRouteBuilder<MediaEdits?>(
      opaque: false,
      // Поверх, а не новая страница: на iPhone чат под ним не сдвигается
      // влево (видно при смахивании фото вниз).
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => MediaEditorScreen(
        image: image,
        sourceAspect: sourceAspect,
        initial: initial,
        initialTab: initialTab,
        hapticsEnabled: hapticsEnabled,
      ),
      transitionsBuilder: (context, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// Ключ рабочей зоны (для тестов и наведения).
const ValueKey<String> kMediaEditorWorkAreaKey = ValueKey<String>(
  'mediaEditorWorkArea',
);

class MediaEditorScreen extends StatefulWidget {
  const MediaEditorScreen({
    super.key,
    required this.image,
    required this.sourceAspect,
    required this.initial,
    this.initialTab = MediaEditorTab.crop,
    this.hapticsEnabled,
  });

  final ImageProvider image;
  final double sourceAspect;
  final MediaEdits initial;
  final MediaEditorTab initialTab;
  final bool Function()? hapticsEnabled;

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  late final MediaEditorModel _model = MediaEditorModel(
    aspect: widget.sourceAspect > 0 && widget.sourceAspect.isFinite
        ? widget.sourceAspect
        : 1,
    initial: widget.initial,
    tab: widget.initialTab,
    hapticsEnabled: widget.hapticsEnabled,
  );
  final TextEditingController _textCtl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  String? _shownTextId;
  bool _closing = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModel);
  }

  @override
  void dispose() {
    _model.removeListener(_onModel);
    _model.dispose();
    _textCtl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  /// Поле ввода следует за текстом, который правится.
  void _onModel() {
    final id = _model.textEditId;
    if (id == _shownTextId) return;
    _shownTextId = id;
    if (id != null) {
      final text = _model.editingText?.text ?? '';
      _textCtl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } else if (_textFocus.hasFocus) {
      _textFocus.unfocus();
    }
  }

  void _done() {
    if (_closing) return;
    _closing = true;
    _model.finishText();
    _model.haptic(MediaEditorHaptic.medium);
    Navigator.of(context).pop<MediaEdits?>(_model.e.cleaned());
  }

  Future<void> _cancel() async {
    if (_closing || _sheetOpen) return;
    if (!_model.changed) {
      _closing = true;
      Navigator.of(context).pop<MediaEdits?>(null);
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    _sheetOpen = true;
    final ok = await showMediaViewerSheet<bool>(
      context: context,
      tokens: MediaViewerTokens.of(context),
      title: l10n.meDiscardTitle,
      subtitle: l10n.meDiscardBody,
      options: [
        MediaSheetOption<bool>(
          label: l10n.meDiscardAction,
          value: true,
          danger: true,
        ),
      ],
    );
    _sheetOpen = false;
    if (ok == true && mounted && !_closing) {
      _closing = true;
      Navigator.of(context).pop<MediaEdits?>(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = MediaViewerTokens.of(context);
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final top = mq.viewPadding.top + 6;
    final workTop = top + 48 + 6;
    final tabBottom = size.height - math.max(mq.viewPadding.bottom, 8.0);
    final tabTop = tabBottom - 54;
    final panelTop = tabTop - 164;
    final workH = math.max(1.0, panelTop - workTop);
    final kb = mq.viewInsets.bottom;
    final area = Size(size.width, workH);
    return PopScope<MediaEdits?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Material(
          color: t.editorBg,
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              final m = _model;
              final editing = m.textEditId != null;
              return Stack(
                children: [
                  Positioned(
                    top: top,
                    left: 8,
                    right: 8,
                    height: 48,
                    child: _Header(
                      model: m,
                      tokens: t,
                      onCancel: _cancel,
                      onDone: _done,
                    ),
                  ),
                  Positioned(
                    top: workTop,
                    left: 0,
                    width: size.width,
                    height: workH,
                    child: KeyedSubtree(
                      key: kMediaEditorWorkAreaKey,
                      child: ClipRect(
                        child: m.tab == MediaEditorTab.crop
                            ? MediaEditorCropArea(
                                model: m,
                                image: widget.image,
                                area: area,
                              )
                            : MediaEditorCanvasArea(
                                model: m,
                                image: widget.image,
                                area: area,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: panelTop,
                    left: 0,
                    right: 0,
                    height: 164,
                    child: switch (m.tab) {
                      MediaEditorTab.crop => MediaEditorCropPanel(model: m),
                      MediaEditorTab.draw => MediaEditorDrawPanel(model: m),
                      MediaEditorTab.adjust => MediaEditorAdjustPanel(model: m),
                    },
                  ),
                  Positioned(
                    top: tabTop,
                    left: 0,
                    right: 0,
                    height: 54,
                    child: _TabBar(model: m, tokens: t),
                  ),
                  if (editing)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: kb > 0 ? null : panelTop,
                      bottom: kb,
                      child: _TextPanel(
                        key: ValueKey<String?>(m.textEditId),
                        model: m,
                        tokens: t,
                        controller: _textCtl,
                        focusNode: _textFocus,
                        keyboardOpen: kb > 0,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.model,
    required this.tokens,
    required this.onCancel,
    required this.onDone,
  });

  final MediaEditorModel model;
  final MediaViewerTokens tokens;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = tokens;
    final l10n = context.l10n;
    Widget icon(IconData i, String tip, bool on, VoidCallback f) =>
        EditorTapTarget(
          tooltip: tip,
          enabled: on,
          onTap: f,
          child: Opacity(
            opacity: on ? 1 : .3,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(i, size: 24, color: t.editorInk),
            ),
          ),
        );
    return Row(
      children: [
        EditorTapTarget(
          onTap: onCancel,
          label: l10n.cancel,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              l10n.cancel,
              style: TextStyle(fontSize: 16, color: t.editorInk),
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon(MediaEditorIcons.undo, l10n.meUndo, m.canUndo, m.undo),
              const SizedBox(width: 4),
              icon(MediaEditorIcons.redo, l10n.meRedo, m.canRedo, m.redo),
            ],
          ),
        ),
        EditorTapTarget(
          onTap: onDone,
          label: l10n.meDone,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              l10n.meDone,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.onAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.model, required this.tokens});

  final MediaEditorModel model;
  final MediaViewerTokens tokens;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = tokens;
    final l10n = context.l10n;
    final tabs = <(MediaEditorTab, IconData, String)>[
      (MediaEditorTab.crop, MediaEditorIcons.tabCrop, l10n.meTabCrop),
      (MediaEditorTab.draw, MediaEditorIcons.tabDraw, l10n.meTabDraw),
      (MediaEditorTab.adjust, MediaEditorIcons.tabAdjust, l10n.meTabAdjust),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, (id, icon, label)) in tabs.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Flexible(
            child: Semantics(
              button: true,
              selected: m.tab == id,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => m.selectTab(id),
                child: SizedBox(
                  width: 104,
                  height: 54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: m.tab == id ? t.accent : t.editorSub,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: m.tab == id ? t.accent : t.editorSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Поле правки текста над клавиатурой: ввод, подложка, «Готово», цвета.
class _TextPanel extends StatelessWidget {
  const _TextPanel({
    super.key,
    required this.model,
    required this.tokens,
    required this.controller,
    required this.focusNode,
    required this.keyboardOpen,
  });

  final MediaEditorModel model;
  final MediaViewerTokens tokens;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final t = tokens;
    final l10n = context.l10n;
    final bg = m.editingText?.background ?? false;
    final panel = Container(
      color: t.editorBg,
      padding: EdgeInsets.fromLTRB(12, 12, 12, keyboardOpen ? 12 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: t.chip,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onChanged: m.updateText,
                    onSubmitted: (_) => m.finishText(),
                    cursorColor: t.accent,
                    style: TextStyle(fontSize: 16, color: t.editorInk),
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.meTextPlaceholder,
                      hintStyle: TextStyle(fontSize: 16, color: t.editorSub),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              EditorTapTarget(
                tooltip: l10n.meTextBackground,
                selected: bg,
                onTap: m.toggleTextBackground,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg ? t.chipOn : t.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MediaEditorIcons.textBackground,
                    size: 22,
                    color: bg ? t.chipOnInk : t.editorInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              EditorTapTarget(
                onTap: m.finishText,
                label: l10n.meDone,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    l10n.meDone,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final c in kMediaDrawPalette)
                  EditorSwatch(
                    color: c,
                    selected: m.color == c,
                    diameter: 30,
                    tokens: t,
                    onTap: () => m.selectColor(c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.meTextHelp,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.editorSub),
          ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: panel,
    );
  }
}
