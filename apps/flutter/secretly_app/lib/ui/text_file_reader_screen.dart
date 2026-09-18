// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons/app_icons.dart';

/// Full-screen in-app reader for PLAIN-TEXT attachments (.txt, .log, .json,
/// .csv, .md …).
///
/// Text needs no rendering engine at all, so unlike PDF this costs nothing in
/// size or attack surface — we simply decode the bytes and lay them out. Kept in
/// the same chrome as the PDF reader and the photo gallery: black canvas, a tap
/// toggles the blurred islands, bottom island shares.
///
/// Two guards keep a hostile or accidental file from hurting the app: only the
/// first [_maxBytes] are read (a multi-hundred-MB log would otherwise be pulled
/// into memory whole), and invalid UTF-8 is replaced rather than thrown on, so a
/// binary file mislabelled as text degrades to mojibake instead of an error.
class TextFileReaderScreen extends StatefulWidget {
  const TextFileReaderScreen({
    super.key,
    required this.file,
    required this.title,
    required this.onShare,
  });

  final File file;
  final String title;
  final Future<void> Function() onShare;

  /// Extensions we open in-app. Deliberately conservative: formats that are
  /// genuinely plain text, where showing raw content is useful rather than
  /// confusing.
  static const Set<String> textExtensions = {
    'txt',
    'log',
    'json',
    'csv',
    'md',
    'yaml',
    'yml',
    'xml',
    'ini',
    'conf',
    'srt',
  };

  static bool canOpen({required String path, required String mime}) {
    final lower = path.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : '';
    if (textExtensions.contains(ext)) return true;
    final m = mime.toLowerCase();
    return m.startsWith('text/') ||
        m == 'application/json' ||
        m == 'application/xml';
  }

  @override
  State<TextFileReaderScreen> createState() => _TextFileReaderScreenState();
}

class _TextFileReaderScreenState extends State<TextFileReaderScreen> {
  static const int _maxBytes = 2 * 1024 * 1024; // 2 MB of text is ~40k lines

  bool _chromeVisible = true;
  String? _content;
  bool _truncated = false;
  bool _failed = false;
  double _fontSize = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final length = await widget.file.length();
      final raw = length > _maxBytes
          ? await widget.file.openRead(0, _maxBytes).fold<List<int>>(
              <int>[],
              (acc, chunk) => acc..addAll(chunk),
            )
          : await widget.file.readAsBytes();
      // allowMalformed: a file that is not really UTF-8 still shows, instead of
      // throwing and leaving the user with nothing.
      final text = const Utf8Decoder(allowMalformed: true).convert(raw);
      if (!mounted) return;
      setState(() {
        _content = text;
        _truncated = length > _maxBytes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  String _label(BuildContext context, {required String ru, required String en}) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return code == 'ru' || code == 'uk' ? ru : en;
  }

  Widget _glassPanel({required Widget child}) {
    final radius = BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            child: _failed
                ? Center(
                    child: Text(
                      _label(
                        context,
                        ru: 'Не удалось прочитать файл',
                        en: 'Could not read this file',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : content == null
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 86,
                      16,
                      MediaQuery.of(context).padding.bottom + 86,
                    ),
                    child: SelectableText(
                      _truncated
                          ? '$content\n\n… ${_label(context, ru: 'файл показан частично', en: 'file shown partially')}'
                          : content,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _fontSize,
                        height: 1.42,
                        fontFamily: 'monospace',
                        fontFamilyFallback: const ['Roboto'],
                      ),
                    ),
                  ),
          ),
          _topIsland(context),
          _bottomIsland(context),
        ],
      ),
    );
  }

  Widget _topIsland(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: _chromeVisible ? Offset.zero : const Offset(0, -0.16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _chromeVisible ? 1 : 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _glassPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            AppIcons.arrowBack,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomIsland(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: _chromeVisible ? Offset.zero : const Offset(0, 0.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _chromeVisible ? 1 : 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _glassPanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: _label(
                            context,
                            ru: 'Мельче',
                            en: 'Smaller',
                          ),
                          onPressed: () => setState(
                            () => _fontSize = (_fontSize - 1).clamp(10, 28),
                          ),
                          icon: const Icon(
                            Icons.text_decrease_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: _label(context, ru: 'Крупнее', en: 'Larger'),
                          onPressed: () => setState(
                            () => _fontSize = (_fontSize + 1).clamp(10, 28),
                          ),
                          icon: const Icon(
                            Icons.text_increase_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: _label(
                            context,
                            ru: 'Копировать',
                            en: 'Copy',
                          ),
                          onPressed: () async {
                            final text = _content;
                            if (text == null) return;
                            await Clipboard.setData(ClipboardData(text: text));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(milliseconds: 900),
                                content: Text(
                                  _label(
                                    context,
                                    ru: 'Скопировано',
                                    en: 'Copied',
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: _label(
                            context,
                            ru: 'Поделиться',
                            en: 'Share',
                          ),
                          onPressed: () => widget.onShare(),
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
