// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'wave1_l10n.dart';
import 'widgets/framed_avatar.dart';
import 'widgets/frosted_top_bar.dart';

/// P2 of in-chat search: a full-screen list of every [ChatSearchHit] for the
/// active query. Each row shows the author's avatar + name, the message text
/// with the query substring highlighted (same look as the in-bubble wash), and
/// a right-aligned timestamp. Tapping a row pops the screen returning that
/// hit's index so the chat can scroll/flash it via `_gotoSearchHit`.
///
/// Fully additive + fail-soft: sender resolution is best-effort (local
/// contacts only); an unresolved author falls back to a trimmed profile-id
/// label. Nothing here can throw into the chat screen.
class SearchResultsListScreen extends StatefulWidget {
  const SearchResultsListScreen({
    super.key,
    required this.controller,
    required this.hits,
    required this.query,
  });

  final AppController controller;
  final List<ChatSearchHit> hits;
  final String query;

  @override
  State<SearchResultsListScreen> createState() =>
      _SearchResultsListScreenState();
}

class _SearchResultsListScreenState extends State<SearchResultsListScreen> {
  /// profileId → resolved Contact (best-effort, local). Built once on open.
  Map<String, Contact> _contacts = const <String, Contact>{};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await widget.controller.listContacts();
      if (!mounted) return;
      final map = <String, Contact>{};
      for (final c in list) {
        map[c.profileId] = c;
      }
      setState(() => _contacts = map);
    } catch (_) {
      // Best-effort: an empty map just means name/avatar fall back to the
      // profile-id label. Search results stay fully usable.
    }
  }

  // ── Sender resolution ────────────────────────────────────────────────────
  String _selfLabel() => wave1Text(
    context,
    ru: 'Вы',
    en: 'You',
    uk: 'Ви',
    es: 'Tú',
    pt: 'Você',
    ptBr: 'Você',
    fr: 'Vous',
    de: 'Du',
  );

  String _shortId(String? pid) {
    final p = (pid ?? '').trim();
    if (p.isEmpty) return '?';
    return p.length <= 12 ? p : '${p.substring(0, 12)}…';
  }

  String _senderName(ChatSearchHit hit) {
    if (hit.isOutgoing) {
      final nick = widget.controller.myNickname.trim();
      return nick.isNotEmpty ? nick : _selfLabel();
    }
    final c = _contacts[hit.senderProfileId];
    final name = c?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _shortId(hit.senderProfileId);
  }

  String? _senderAvatarPath(ChatSearchHit hit) {
    if (hit.isOutgoing) {
      final p = widget.controller.myAvatarPath?.trim();
      return (p != null && p.isNotEmpty) ? p : null;
    }
    final p = _contacts[hit.senderProfileId]?.avatarPath?.trim();
    return (p != null && p.isNotEmpty) ? p : null;
  }

  String? _senderFrameId(ChatSearchHit hit) {
    if (hit.isOutgoing) return null;
    final f = _contacts[hit.senderProfileId]?.frameId?.trim();
    return (f != null && f.isNotEmpty) ? f : null;
  }

  String _avatarSeed(ChatSearchHit hit) {
    if (hit.isOutgoing) {
      final me = widget.controller.profileId;
      return me.trim().isNotEmpty ? me.trim() : 'me';
    }
    final pid = (hit.senderProfileId ?? '').trim();
    return pid.isNotEmpty ? pid : _senderName(hit);
  }

  // ── Timestamp ────────────────────────────────────────────────────────────
  String _timeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diff == 0) return '$hh:$mm';
    if (diff == 1) {
      return wave1Text(
        context,
        ru: 'Вчера',
        en: 'Yesterday',
        uk: 'Учора',
        es: 'Ayer',
        pt: 'Ontem',
        ptBr: 'Ontem',
        fr: 'Hier',
        de: 'Gestern',
      );
    }
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d.$mo.${dt.year}';
  }

  // ── Highlighted message text ─────────────────────────────────────────────
  /// Single-line preview of [hit.text] with every occurrence of the query
  /// painted with a translucent wash (same treatment as the in-bubble
  /// highlight). Fail-soft: a bad query degrades to plain text.
  Widget _highlightedText(ChatSearchHit hit, TextStyle baseStyle) {
    final text = hit.text;
    final q = widget.query.trim();
    final cs = Theme.of(context).colorScheme;
    if (q.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    final hlStyle = baseStyle.copyWith(
      background: Paint()..color = cs.onSurface.withValues(alpha: 0.22),
      fontWeight: FontWeight.w600,
    );
    final spans = <TextSpan>[];
    try {
      final lower = text.toLowerCase();
      final qLower = q.toLowerCase();
      var cursor = 0;
      while (true) {
        final idx = lower.indexOf(qLower, cursor);
        if (idx < 0) break;
        if (idx > cursor) {
          spans.add(TextSpan(text: text.substring(cursor, idx)));
        }
        spans.add(
          TextSpan(text: text.substring(idx, idx + q.length), style: hlStyle),
        );
        cursor = idx + q.length;
      }
      if (cursor < text.length) {
        spans.add(TextSpan(text: text.substring(cursor)));
      } else if (cursor == 0) {
        spans.add(TextSpan(text: text));
      }
    } catch (_) {
      spans
        ..clear()
        ..add(TextSpan(text: text));
    }
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Title ────────────────────────────────────────────────────────────────
  String _resultsTitle(int n) {
    final tag = wave1LocaleTagFromContext(context);
    switch (tag) {
      case 'ru':
        return '$n ${_pluralRu(n, 'результат', 'результата', 'результатов')}';
      case 'uk':
        return '$n ${_pluralRu(n, 'результат', 'результати', 'результатів')}';
      case 'es':
        return n == 1 ? '$n resultado' : '$n resultados';
      case 'pt':
      case 'pt_BR':
        return n == 1 ? '$n resultado' : '$n resultados';
      case 'fr':
        return n == 1 ? '$n résultat' : '$n résultats';
      case 'de':
        return n == 1 ? '$n Ergebnis' : '$n Ergebnisse';
      default:
        return n == 1 ? '$n result' : '$n results';
    }
  }

  String _pluralRu(int n, String one, String few, String many) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hits = widget.hits;
    return Scaffold(
      appBar: frostedAppBar(
        title: Text(
          _resultsTitle(hits.length),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              wave1Text(
                context,
                ru: 'В чате',
                en: 'In chat',
                uk: 'У чаті',
                es: 'En el chat',
                pt: 'No chat',
                ptBr: 'No chat',
                fr: 'Dans le chat',
                de: 'Im Chat',
              ),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: hits.isEmpty
          ? Center(
              child: Text(
                wave1Text(
                  context,
                  ru: 'Нет совпадений',
                  en: 'No matches',
                  uk: 'Немає збігів',
                  es: 'Sin coincidencias',
                  pt: 'Sem correspondências',
                  ptBr: 'Sem correspondências',
                  fr: 'Aucun résultat',
                  de: 'Keine Treffer',
                ),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: hits.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: cs.onSurface.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, i) => _buildRow(context, hits[i], i),
            ),
    );
  }

  Widget _buildRow(BuildContext context, ChatSearchHit hit, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = _senderName(hit);
    final bodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    return InkWell(
      onTap: () => Navigator.of(context).pop(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Список — без движения, как и лента чатов: см. `chats_screen`.
            TickerMode(
              enabled: false,
              child: FramedAvatar(
              size: 44,
              avatarPath: _senderAvatarPath(hit),
              frameId: _senderFrameId(hit),
              fallbackSeed: _avatarSeed(hit),
              fallbackName: name,
              fallbackId: hit.senderProfileId,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(hit.createdAtMs),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _highlightedText(hit, bodyStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
