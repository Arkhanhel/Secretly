// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/gestures.dart';
import 'desktop_link_router.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// URLs (http/https/bare www.) inside message text.
final RegExp _kUrlRegex = RegExp(
  r'((?:https?://|www\.)[^\s]+)',
  caseSensitive: false,
);

const String _kTrailingPunctuation = '.,!?;:)]}>»"\'';

/// Renders message text with tappable hyperlinks. Plain text stays untouched;
/// matched URLs become underlined link spans that open in the default browser
/// via url_launcher. Tap recognizers are rebuilt only when the text changes and
/// disposed on teardown.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<_Segment> _segments = const [];

  @override
  void initState() {
    super.initState();
    _segments = _segment(widget.text);
  }

  @override
  void didUpdateWidget(LinkifiedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _segments = _segment(widget.text);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<_Segment> _segment(String text) {
    final out = <_Segment>[];
    var last = 0;
    for (final m in _kUrlRegex.allMatches(text)) {
      if (m.start > last) {
        out.add(_Segment(text.substring(last, m.start), null));
      }
      var url = m.group(0)!;
      var trailing = '';
      while (url.isNotEmpty &&
          _kTrailingPunctuation.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      out.add(_Segment(url, url));
      if (trailing.isNotEmpty) out.add(_Segment(trailing, null));
      last = m.end;
    }
    if (last < text.length) out.add(_Segment(text.substring(last), null));
    return out;
  }

  Future<void> _open(String raw) async {
    var u = raw;
    if (u.toLowerCase().startsWith('www.')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    try {
      // Приглашение в комнату и другие свои ссылки открываем внутри окна.
      if (DesktopLinkRouter.handle(uri)) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.length == 1 && _segments.first.url == null) {
      return Text(widget.text, style: widget.style);
    }
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    for (final seg in _segments) {
      if (seg.url == null) {
        spans.add(TextSpan(text: seg.text));
      } else {
        final rec = TapGestureRecognizer()..onTap = () => _open(seg.url!);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: seg.text,
          recognizer: rec,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ));
      }
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

class _Segment {
  const _Segment(this.text, this.url);
  final String text;

  /// Non-null when this segment is a tappable URL.
  final String? url;
}
