// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/e2e_payload_v1.dart';

class ChatMentionCandidate {
  const ChatMentionCandidate({
    required this.token,
    required this.type,
    this.profileId,
  }) : assert(
         type != MsgMentionV1.profileType ||
             (profileId != null && profileId != ''),
         'profile mentions require profileId',
       );

  final String token;
  final String type;
  final String? profileId;

  MsgMentionV1 toMention({required int start, required int end}) {
    return MsgMentionV1(
      type: type,
      start: start,
      end: end,
      profileId: profileId,
    );
  }
}

class ChatMessageLink {
  const ChatMessageLink({
    required this.start,
    required this.end,
    required this.text,
    required this.uri,
  });

  final int start;
  final int end;
  final String text;
  final Uri uri;
}

final RegExp _chatMessageUrlPattern = RegExp(
  r'(?:https?:\/\/|www\.)[^\s<>"\[\]]+',
  caseSensitive: false,
);

bool isChatMentionBoundaryCharacter(String char) {
  return char.trim().isEmpty || '.,!?;:()[]{}<>/\\|'.contains(char);
}

List<MsgMentionV1> sanitizeChatMessageMentions({
  required String text,
  required List<MsgMentionV1> mentions,
}) {
  if (text.isEmpty || mentions.isEmpty) {
    return const <MsgMentionV1>[];
  }

  final sorted = List<MsgMentionV1>.from(mentions)
    ..sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) return startCompare;
      return a.end.compareTo(b.end);
    });

  final out = <MsgMentionV1>[];
  var occupiedUntil = -1;
  for (final mention in sorted) {
    if (mention.start < 0 ||
        mention.end <= mention.start ||
        mention.end > text.length ||
        mention.start < occupiedUntil) {
      continue;
    }
    if (!_isMentionBoundaryBefore(text, mention.start) ||
        !_isMentionBoundaryAfter(text, mention.end)) {
      continue;
    }
    final slice = text.substring(mention.start, mention.end);
    if (!slice.startsWith('@') || slice.trim().isEmpty) {
      continue;
    }
    out.add(mention);
    occupiedUntil = mention.end;
  }
  return out;
}

List<MsgMentionV1> resolveChatMessageMentions({
  required String text,
  required List<ChatMentionCandidate> candidates,
}) {
  if (text.isEmpty || !text.contains('@') || candidates.isEmpty) {
    return const <MsgMentionV1>[];
  }

  final loweredText = text.toLowerCase();
  final matches = <_ResolvedChatMentionMatch>[];
  for (final candidate in candidates) {
    final token = candidate.token.trim();
    if (token.isEmpty) {
      continue;
    }
    final loweredToken = token.toLowerCase();
    var searchFrom = 0;
    while (searchFrom < loweredText.length) {
      final start = loweredText.indexOf(loweredToken, searchFrom);
      if (start < 0) break;
      final end = start + token.length;
      if (_isMentionBoundaryBefore(text, start) &&
          _isMentionBoundaryAfter(text, end)) {
        matches.add(
          _ResolvedChatMentionMatch(
            candidate: candidate,
            start: start,
            end: end,
          ),
        );
      }
      searchFrom = end;
    }
  }

  matches.sort((a, b) {
    final startCompare = a.start.compareTo(b.start);
    if (startCompare != 0) return startCompare;
    final lengthCompare = (b.end - b.start).compareTo(a.end - a.start);
    if (lengthCompare != 0) return lengthCompare;
    return a.candidate.token.compareTo(b.candidate.token);
  });

  final out = <MsgMentionV1>[];
  var occupiedUntil = -1;
  for (final match in matches) {
    if (match.start < occupiedUntil) {
      continue;
    }
    out.add(match.candidate.toMention(start: match.start, end: match.end));
    occupiedUntil = match.end;
  }
  return out;
}

bool chatMentionTargetsViewer({
  required MsgMentionV1 mention,
  required String selfProfileId,
  required bool currentUserCanReceiveAdminMentions,
}) {
  if (mention.isAll) {
    return true;
  }
  if (mention.isAdmins) {
    return currentUserCanReceiveAdminMentions;
  }
  final selfId = selfProfileId.trim();
  if (selfId.isEmpty || !mention.isProfile) {
    return false;
  }
  return mention.profileId == selfId;
}

List<ChatMessageLink> extractChatMessageLinks(String text) {
  if (text.isEmpty) return const <ChatMessageLink>[];
  final out = <ChatMessageLink>[];
  for (final match in _chatMessageUrlPattern.allMatches(text)) {
    final raw = match.group(0) ?? '';
    final trimmed = _trimTrailingUrlPunctuation(raw);
    if (trimmed.isEmpty) continue;
    final uri = _parseChatMessageLinkUri(trimmed);
    if (uri == null) continue;
    out.add(
      ChatMessageLink(
        start: match.start,
        end: match.start + trimmed.length,
        text: trimmed,
        uri: uri,
      ),
    );
  }
  return out;
}

ChatMessageLink? firstChatMessageLink(String text) {
  final links = extractChatMessageLinks(text);
  return links.isEmpty ? null : links.first;
}

List<InlineSpan> buildChatMessageTextSpans({
  required BuildContext context,
  required String text,
  required List<MsgMentionV1> mentions,
  required TextStyle baseStyle,
  required bool isOutgoing,
  required String selfProfileId,
  required bool currentUserCanReceiveAdminMentions,
  ValueChanged<String>? onProfileMentionTap,
  ValueChanged<Uri>? onLinkTap,
  // In-chat search highlight (Telegram-style). When [highlightQuery] is a
  // non-empty string, every case-insensitive occurrence inside the PLAIN-TEXT
  // runs of the message gets [highlightStyle] painted over it. Mentions, links,
  // inline-formatted spans and spoilers are NEVER touched (a match overlapping
  // one of those is simply not highlighted). No-op when null/empty so the normal
  // render path is byte-for-byte unchanged.
  String? highlightQuery,
  TextStyle? highlightStyle,
}) {
  // Pre-lower the query once; null it out entirely when highlighting is off so
  // the hot plain-text path skips all extra work.
  final hlQuery = (highlightQuery != null && highlightQuery.isNotEmpty)
      ? highlightQuery
      : null;
  final hlStyle = hlQuery == null ? null : highlightStyle;
  final normalized = sanitizeChatMessageMentions(
    text: text,
    mentions: mentions,
  );
  if (normalized.isEmpty) {
    return _buildChatPlainTextSpans(
      context: context,
      text: text,
      baseStyle: baseStyle,
      isOutgoing: isOutgoing,
      onLinkTap: onLinkTap,
      highlightQuery: hlQuery,
      highlightStyle: hlStyle,
    );
  }

  final cs = Theme.of(context).colorScheme;
  // Telegram-style: every mention — whether @profile, @all, @here or @admins —
  // renders as the SAME rounded chip: an accent-tinted pill with accent-coloured
  // bold text. On outgoing (accent-gradient) bubbles the chip uses a white tint
  // + white text for contrast; on incoming bubbles it takes the app accent
  // («цвет иконок»). There is intentionally NO visual difference between mention
  // kinds — they must all look identical inside the bubble.
  final mentionTextColor = isOutgoing ? Colors.white : cs.primary;
  final mentionChipBg = isOutgoing
      ? Colors.white.withValues(alpha: 0.22)
      : cs.primary.withValues(alpha: 0.14);

  final out = <InlineSpan>[];
  var cursor = 0;
  for (final mention in normalized) {
    if (cursor < mention.start) {
      out.addAll(
        _buildChatPlainTextSpans(
          context: context,
          text: text.substring(cursor, mention.start),
          baseStyle: baseStyle,
          isOutgoing: isOutgoing,
          onLinkTap: onLinkTap,
          highlightQuery: hlQuery,
          highlightStyle: hlStyle,
        ),
      );
    }
    final mentionText = text.substring(mention.start, mention.end);
    final mentionStyle = baseStyle.copyWith(
      color: mentionTextColor,
      fontWeight: FontWeight.w700,
    );
    final canTap = mention.isProfile &&
        mention.profileId != null &&
        onProfileMentionTap != null;
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _MentionChip(
          text: mentionText,
          style: mentionStyle,
          background: mentionChipBg,
          onTap: canTap ? () => onProfileMentionTap(mention.profileId!) : null,
        ),
      ),
    );
    cursor = mention.end;
  }

  if (cursor < text.length) {
    out.addAll(
      _buildChatPlainTextSpans(
        context: context,
        text: text.substring(cursor),
        baseStyle: baseStyle,
        isOutgoing: isOutgoing,
        onLinkTap: onLinkTap,
        highlightQuery: hlQuery,
        highlightStyle: hlStyle,
      ),
    );
  }
  return out;
}

/// A single mention rendered as a rounded accent-tinted pill. Used identically
/// for every mention kind (@profile / @all / @here / @admins) so they all look
/// the same inside the bubble. Tappable only when a profile-mention tap handler
/// is supplied.
class _MentionChip extends StatelessWidget {
  const _MentionChip({
    required this.text,
    required this.style,
    required this.background,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: style),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: chip,
    );
  }
}

// Inline formatting markers (Telegram-compatible). Longest markers first so
// ``` wins over `, etc.
class _FormatMarker {
  const _FormatMarker(this.open, this.close, this.kind);
  final String open;
  final String close;
  final String kind; // bold | italic | strike | code | spoiler
}

const List<_FormatMarker> _chatFormatMarkers = <_FormatMarker>[
  _FormatMarker('```', '```', 'code'),
  _FormatMarker('**', '**', 'bold'),
  _FormatMarker('__', '__', 'italic'),
  _FormatMarker('~~', '~~', 'strike'),
  _FormatMarker('||', '||', 'spoiler'),
  _FormatMarker('`', '`', 'code'),
];

/// True when [text] contains at least one recognised formatting marker. Used to
/// skip the (cheap) parser entirely for the common unformatted case.
bool chatTextHasFormatting(String text) {
  return text.contains('**') ||
      text.contains('__') ||
      text.contains('~~') ||
      text.contains('||') ||
      text.contains('`');
}

/// Removes formatting markers, leaving the inner text. Used for chat-list
/// previews / notifications so they don't show raw `**` etc.
String stripChatFormattingMarkers(String text) {
  if (!chatTextHasFormatting(text)) return text;
  var out = text;
  for (final marker in _chatFormatMarkers) {
    // Replace `<open>inner<close>` → `inner` (non-greedy, single line).
    final escapedOpen = RegExp.escape(marker.open);
    final escapedClose = RegExp.escape(marker.close);
    out = out.replaceAllMapped(
      RegExp('$escapedOpen(.+?)$escapedClose', dotAll: true),
      (m) => m.group(1) ?? '',
    );
  }
  return out;
}

List<InlineSpan> _buildChatPlainTextSpans({
  required BuildContext context,
  required String text,
  required TextStyle baseStyle,
  required bool isOutgoing,
  ValueChanged<Uri>? onLinkTap,
  String? highlightQuery,
  TextStyle? highlightStyle,
}) {
  if (text.isEmpty) return const <InlineSpan>[];
  if (!chatTextHasFormatting(text)) {
    return _buildLinkAwareSpans(
      context: context,
      text: text,
      baseStyle: baseStyle,
      isOutgoing: isOutgoing,
      onLinkTap: onLinkTap,
      highlightQuery: highlightQuery,
      highlightStyle: highlightStyle,
    );
  }

  // Split on the earliest valid formatting marker; recurse into plain runs for
  // link detection. Inner formatted spans are not nested further (Telegram
  // parity for the common cases) — except spoilers which render their inner
  // text plainly under the dots.
  final out = <InlineSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    int bestOpen = -1;
    _FormatMarker? bestMarker;
    int bestClose = -1;
    for (final marker in _chatFormatMarkers) {
      final openIdx = text.indexOf(marker.open, cursor);
      if (openIdx < 0) continue;
      final innerStart = openIdx + marker.open.length;
      final closeIdx = text.indexOf(marker.close, innerStart);
      if (closeIdx < 0 || closeIdx <= innerStart) continue;
      final isEarlier = bestOpen < 0 || openIdx < bestOpen;
      final isLongerTie =
          openIdx == bestOpen &&
          marker.open.length > (bestMarker?.open.length ?? 0);
      if (isEarlier || isLongerTie) {
        bestOpen = openIdx;
        bestMarker = marker;
        bestClose = closeIdx;
      }
    }
    if (bestMarker == null) {
      out.addAll(
        _buildLinkAwareSpans(
          context: context,
          text: text.substring(cursor),
          baseStyle: baseStyle,
          isOutgoing: isOutgoing,
          onLinkTap: onLinkTap,
          highlightQuery: highlightQuery,
          highlightStyle: highlightStyle,
        ),
      );
      break;
    }
    if (cursor < bestOpen) {
      out.addAll(
        _buildLinkAwareSpans(
          context: context,
          text: text.substring(cursor, bestOpen),
          baseStyle: baseStyle,
          isOutgoing: isOutgoing,
          onLinkTap: onLinkTap,
          highlightQuery: highlightQuery,
          highlightStyle: highlightStyle,
        ),
      );
    }
    final innerStart = bestOpen + bestMarker.open.length;
    final inner = text.substring(innerStart, bestClose);
    out.add(
      _buildFormattedSpan(
        context: context,
        kind: bestMarker.kind,
        inner: inner,
        baseStyle: baseStyle,
        isOutgoing: isOutgoing,
      ),
    );
    cursor = bestClose + bestMarker.close.length;
  }
  return out;
}

InlineSpan _buildFormattedSpan({
  required BuildContext context,
  required String kind,
  required String inner,
  required TextStyle baseStyle,
  required bool isOutgoing,
}) {
  switch (kind) {
    case 'bold':
      return TextSpan(
        text: inner,
        style: baseStyle.copyWith(fontWeight: FontWeight.w700),
      );
    case 'italic':
      return TextSpan(
        text: inner,
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      );
    case 'strike':
      return TextSpan(
        text: inner,
        style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
      );
    case 'code':
      return TextSpan(
        text: inner,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const <String>['Menlo', 'Courier', 'monospace'],
          backgroundColor: (isOutgoing ? Colors.white : Colors.black)
              .withValues(alpha: isOutgoing ? 0.16 : 0.06),
          letterSpacing: 0,
        ),
      );
    case 'spoiler':
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _SpoilerText(
          text: inner,
          style: baseStyle,
          isOutgoing: isOutgoing,
        ),
      );
    default:
      return TextSpan(text: inner, style: baseStyle);
  }
}

List<InlineSpan> _buildLinkAwareSpans({
  required BuildContext context,
  required String text,
  required TextStyle baseStyle,
  required bool isOutgoing,
  ValueChanged<Uri>? onLinkTap,
  String? highlightQuery,
  TextStyle? highlightStyle,
}) {
  if (text.isEmpty) return const <InlineSpan>[];
  final links = onLinkTap == null
      ? const <ChatMessageLink>[]
      : extractChatMessageLinks(text);
  if (links.isEmpty) {
    final out = <InlineSpan>[];
    _appendHighlightedPlainSpans(
      out,
      text: text,
      highlightQuery: highlightQuery,
      highlightStyle: highlightStyle,
    );
    return out;
  }
  final linkTap = onLinkTap;
  if (linkTap == null) {
    final out = <InlineSpan>[];
    _appendHighlightedPlainSpans(
      out,
      text: text,
      highlightQuery: highlightQuery,
      highlightStyle: highlightStyle,
    );
    return out;
  }

  final cs = Theme.of(context).colorScheme;
  final linkColor = isOutgoing ? Colors.white : cs.primary;
  final linkStyle = baseStyle.copyWith(
    color: linkColor,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationColor: linkColor.withValues(alpha: 0.8),
  );

  final out = <InlineSpan>[];
  var cursor = 0;
  for (final link in links) {
    final start = link.start;
    final end = link.end;
    if (start < cursor || start < 0 || end > text.length) continue;
    if (cursor < start) {
      _appendHighlightedPlainSpans(
        out,
        text: text.substring(cursor, start),
        highlightQuery: highlightQuery,
        highlightStyle: highlightStyle,
      );
    }
    // Links render as their own WidgetSpan and are intentionally NOT
    // search-highlighted (a match inside a URL is skipped, per spec).
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => linkTap(link.uri),
          child: Text(link.text, style: linkStyle),
        ),
      ),
    );
    cursor = end;
  }
  if (cursor < text.length) {
    _appendHighlightedPlainSpans(
      out,
      text: text.substring(cursor),
      highlightQuery: highlightQuery,
      highlightStyle: highlightStyle,
    );
  }
  return out;
}

/// Appends [text] to [out] as plain `TextSpan`s, splitting on every
/// case-insensitive occurrence of [highlightQuery] and giving those occurrences
/// [highlightStyle]. When highlighting is off (null/empty query or null style)
/// this degrades to a single `TextSpan(text: text)` — byte-for-byte identical to
/// the pre-search render path. Fail-soft: any unexpected error falls back to the
/// unhighlighted span so a bad query can never crash a bubble.
void _appendHighlightedPlainSpans(
  List<InlineSpan> out, {
  required String text,
  required String? highlightQuery,
  required TextStyle? highlightStyle,
}) {
  if (text.isEmpty) return;
  final q = highlightQuery;
  final style = highlightStyle;
  if (q == null || q.isEmpty || style == null) {
    out.add(TextSpan(text: text));
    return;
  }
  try {
    final lower = text.toLowerCase();
    final qLower = q.toLowerCase();
    var cursor = 0;
    while (true) {
      final idx = lower.indexOf(qLower, cursor);
      if (idx < 0) break;
      if (idx > cursor) {
        out.add(TextSpan(text: text.substring(cursor, idx)));
      }
      out.add(
        TextSpan(text: text.substring(idx, idx + q.length), style: style),
      );
      cursor = idx + q.length;
    }
    if (cursor < text.length) {
      out.add(TextSpan(text: text.substring(cursor)));
    } else if (cursor == 0) {
      // No occurrence found at all → emit the whole run unstyled.
      out.add(TextSpan(text: text));
    }
  } catch (_) {
    out.add(TextSpan(text: text));
  }
}

/// Telegram-style spoiler: the text is covered by a field of twinkling dots and
/// revealed on tap (tap again to hide).
class _SpoilerText extends StatefulWidget {
  const _SpoilerText({
    required this.text,
    required this.style,
    required this.isOutgoing,
  });

  final String text;
  final TextStyle style;
  final bool isOutgoing;

  @override
  State<_SpoilerText> createState() => _SpoilerTextState();
}

class _SpoilerTextState extends State<_SpoilerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isOutgoing
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    if (_revealed) {
      return GestureDetector(
        onTap: () => setState(() => _revealed = false),
        child: Text(widget.text, style: widget.style),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _revealed = true),
      child: Stack(
        children: <Widget>[
          // Invisible text reserves the exact size of the hidden content.
          Text(
            widget.text,
            style: widget.style.copyWith(color: Colors.transparent),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SpoilerDotsPainter(
                      progress: _controller.value,
                      color: dotColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpoilerDotsPainter extends CustomPainter {
  _SpoilerDotsPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // Soft backing so the covered block reads as a solid redaction.
    final bg = Paint()..color = color.withValues(alpha: 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      bg,
    );
    final rng = math.Random(1469);
    final count = ((size.width * size.height) / 22)
        .clamp(10, 320)
        .toInt();
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final phase = rng.nextDouble() * math.pi * 2;
      final twinkle =
          0.35 + 0.5 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + phase));
      paint.color = color.withValues(alpha: twinkle.clamp(0.0, 0.85));
      canvas.drawCircle(Offset(x, y), 0.95, paint);
    }
  }

  @override
  bool shouldRepaint(_SpoilerDotsPainter old) =>
      old.progress != progress || old.color != color;
}

String _trimTrailingUrlPunctuation(String value) {
  var end = value.length;
  while (end > 0 && '.,!?;:)]}'.contains(value[end - 1])) {
    end--;
  }
  return value.substring(0, end);
}

Uri? _parseChatMessageLinkUri(String value) {
  final normalized = value.toLowerCase().startsWith('www.')
      ? 'https://$value'
      : value;
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.trim().isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  return uri;
}

bool _isMentionBoundaryBefore(String text, int index) {
  if (index <= 0) return true;
  return isChatMentionBoundaryCharacter(
    String.fromCharCode(text.codeUnitAt(index - 1)),
  );
}

bool _isMentionBoundaryAfter(String text, int end) {
  if (end >= text.length) return true;
  return isChatMentionBoundaryCharacter(
    String.fromCharCode(text.codeUnitAt(end)),
  );
}

class _ResolvedChatMentionMatch {
  const _ResolvedChatMentionMatch({
    required this.candidate,
    required this.start,
    required this.end,
  });

  final ChatMentionCandidate candidate;
  final int start;
  final int end;
}
