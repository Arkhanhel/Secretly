// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПРОСМОТР ДОКУМЕНТА ВНУТРИ ОКНА: PDF СТРАНИЦАМИ И ПРОСТОЙ ТЕКСТ.
///
/// 🔴 ЗАЧЕМ. Полученный файл открывался ЧУЖОЙ программой: расшифрованный
/// документ уходил другому приложению, попадал в его список недавних и в его
/// кэш. Для переписки со сквозным шифрованием это самое слабое место пути.
/// Что можем показать сами — показываем сами, не выпуская файл наружу.
///
/// Кнопки «Открыть в программе» и «Сохранить как…» остаются: человек вправе
/// решить иначе, просто теперь это его решение, а не единственный путь.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import 'desktop_pdf_bridge.dart';
import 'document_viewer_kind.dart';

class DesktopDocumentViewer extends StatefulWidget {
  const DesktopDocumentViewer({
    super.key,
    required this.file,
    required this.title,
    required this.kind,
    this.onOpenExternally,
    this.onSaveAs,
  });

  final File file;
  final String title;
  final DesktopViewerKind kind;
  final Future<void> Function()? onOpenExternally;
  final Future<void> Function()? onSaveAs;

  static Future<void> show({
    required BuildContext context,
    required File file,
    required String title,
    required DesktopViewerKind kind,
    Future<void> Function()? onOpenExternally,
    Future<void> Function()? onSaveAs,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) => DesktopDocumentViewer(
        file: file,
        title: title,
        kind: kind,
        onOpenExternally: onOpenExternally,
        onSaveAs: onSaveAs,
      ),
    );
  }

  @override
  State<DesktopDocumentViewer> createState() => _DesktopDocumentViewerState();
}

class _DesktopDocumentViewerState extends State<DesktopDocumentViewer> {
  int _pageCount = 0;
  int _page = 0;
  bool _loading = true;
  bool _failed = false;
  String _text = '';

  /// Отрисованные страницы: листание туда-обратно не должно рисовать заново.
  final Map<int, Uint8List> _rendered = <int, Uint8List>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.kind == DesktopViewerKind.text) {
      try {
        final bytes = await widget.file.readAsBytes();
        // Читаем «как получится»: файл прислал другой человек, и один
        // неверный байт не повод показать пустоту.
        _text = _decodeText(bytes);
        if (!mounted) return;
        setState(() => _loading = false);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    final pages = await DesktopPdfBridge.pageCount(widget.file.path);
    if (!mounted) return;
    if (pages == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _pageCount = pages;
      _loading = false;
    });
    unawaited(_ensurePage(0));
  }

  static String _decodeText(Uint8List bytes) {
    final cut = bytes.length > kDesktopTextViewerMaxBytes
        ? bytes.sublist(0, kDesktopTextViewerMaxBytes)
        : bytes;
    return const Utf8Decoder(allowMalformed: true).convert(cut);
  }

  Future<void> _ensurePage(int index) async {
    if (index < 0 || index >= _pageCount || _rendered.containsKey(index)) {
      return;
    }
    final png = await DesktopPdfBridge.renderPage(
      path: widget.file.path,
      page: index,
      maxWidth: 1400,
    );
    if (!mounted || png == null) return;
    setState(() => _rendered[index] = png);
  }

  void _goto(int index) {
    if (index < 0 || index >= _pageCount) return;
    setState(() => _page = index);
    unawaited(_ensurePage(index));
    unawaited(_ensurePage(index + 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: Column(
        children: [
          _header(c, l10n),
          Expanded(child: _body(c, l10n)),
          if (widget.kind == DesktopViewerKind.pdf && _pageCount > 1)
            _pager(c, l10n),
        ],
      ),
    );
  }

  Widget _header(DColorSet c, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.m, DSpace.s, DSpace.s, DSpace.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: DType.bodyStrong.copyWith(color: Colors.white),
            ),
          ),
          if (widget.onSaveAs != null)
            TextButton(
              onPressed: () => unawaited(widget.onSaveAs!()),
              child: Text(l10n.desktopViewerSaveAs),
            ),
          if (widget.onOpenExternally != null)
            TextButton(
              onPressed: () => unawaited(widget.onOpenExternally!()),
              child: Text(l10n.desktopViewerOpenExternally),
            ),
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _body(DColorSet c, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_failed) {
      return Center(
        child: Text(
          l10n.desktopViewerFailed,
          style: DType.body.copyWith(color: Colors.white70),
        ),
      );
    }
    if (widget.kind == DesktopViewerKind.text) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(DSpace.l),
        child: SelectableText(
          _text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.45,
            color: Colors.white,
          ),
        ),
      );
    }
    final png = _rendered[_page];
    if (png == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DSpace.m),
          child: Image.memory(png, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _pager(DColorSet c, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l10n.desktopViewerPagePrev,
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
            onPressed: _page > 0 ? () => _goto(_page - 1) : null,
          ),
          Text(
            l10n.desktopViewerPage(_page + 1, _pageCount),
            style: DType.caption.copyWith(color: Colors.white70),
          ),
          IconButton(
            tooltip: l10n.desktopViewerPageNext,
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
            onPressed: _page + 1 < _pageCount ? () => _goto(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}
