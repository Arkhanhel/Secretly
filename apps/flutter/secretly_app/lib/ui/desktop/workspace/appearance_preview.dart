// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Живой предпросмотр переписки справа от «Внешнего вида» (макет владельца,
/// 29.09.2026).
///
/// 🔴 ПРЕДПРОСМОТР — ЭТО НАСТОЯЩАЯ ЛЕНТА ПЕРЕПИСКИ, А НЕ ЕЁ РИСУНОК (30.09.2026,
/// владелец: «превью фонов чатов и т. д. не те, что у нас на самом деле»).
/// Первая версия рисовала шапку, поле ввода и чип даты сама, по макету, — и
/// выглядела как макет, а не как Secretly: шапка плоской полосой вместо
/// стеклянного островка, другое поле ввода, другой вид «печатает». Теперь здесь
/// стоит сам [ChatThreadPanel] — тот же, что в окне переписки, с демонстрационной
/// перепиской. Всё, что меняют настройки, он показывает так же, как в чате:
/// обои и их анимацию, затемнение, волну, форму и плотность пузырей, цвета
/// имён и индикаторов, размер текста.
///
/// Можно написать сообщение — придёт ответ; «Входящее» — ответ сразу;
/// «Переоткрыть» — открыть переписку заново и увидеть анимацию обоев.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat_wallpapers.dart';
import '../chat/chat_thread_panel.dart';
import '../chat/message_bubble.dart';
import '../design/tokens.dart';
import 'settings_kit.dart';
import 'settings_style.dart';

class DesktopAppearancePreview extends StatefulWidget {
  const DesktopAppearancePreview({
    super.key,
    required this.wallpaperId,
    required this.animMode,
    required this.conduct,
    required this.nicknamePresetId,
  });

  final String wallpaperId;
  final ChatWallpaperAnimMode animMode;
  final bool conduct;
  final String nicknamePresetId;

  @override
  State<DesktopAppearancePreview> createState() =>
      _DesktopAppearancePreviewState();
}

class _DesktopAppearancePreviewState extends State<DesktopAppearancePreview> {
  final math.Random _random = math.Random();
  final List<Timer> _timers = <Timer>[];
  List<MessageData>? _messages;
  String? _typing;
  int _opened = 0;
  int _seq = 0;

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  String _authorName(AppLocalizations l10n, int i) => switch (i) {
    1 => l10n.desktopAppearancePreviewMax,
    2 => l10n.desktopAppearancePreviewLiza,
    _ => l10n.desktopAppearancePreviewAnna,
  };

  String _time(int ms) => DateFormat.Hm(
    Localizations.localeOf(context).toString(),
  ).format(DateTime.fromMillisecondsSinceEpoch(ms));

  MessageData _peer(AppLocalizations l10n, int author, String text, int ms) {
    final id = 'appearance-preview-${_seq++}';
    return MessageData(
      id: id,
      payloadId: id,
      authorName: _authorName(l10n, author),
      // Ключ цвета — как у настоящих отправителей: по нему считаются цвет
      // имени и заглушка портрета.
      authorSeed: 'appearance-preview-$author',
      authorProfileId: 'appearance-preview-$author',
      text: text,
      time: _time(ms),
      timestampMs: ms,
      isTextMessage: true,
    );
  }

  MessageData _own(
    AppLocalizations l10n,
    String text,
    int ms, {
    DeliveryStatus delivery = DeliveryStatus.read,
  }) {
    final id = 'appearance-preview-${_seq++}';
    return MessageData(
      id: id,
      payloadId: id,
      authorName: '',
      text: text,
      time: _time(ms),
      timestampMs: ms,
      isSelf: true,
      delivery: delivery,
      isTextMessage: true,
    );
  }

  /// Переписка «несколько минут назад»: время и дата в ленте — сегодняшние.
  List<MessageData> _initial(AppLocalizations l10n) {
    final now = DateTime.now().millisecondsSinceEpoch;
    int ago(int minutes) => now - minutes * 60 * 1000;
    return <MessageData>[
      _peer(l10n, 0, l10n.desktopAppearancePreviewMsg1, ago(6)),
      _peer(l10n, 1, l10n.desktopAppearancePreviewMsg2, ago(5)),
      _own(l10n, l10n.desktopAppearancePreviewMsg3, ago(4)),
      _peer(l10n, 2, l10n.desktopAppearancePreviewMsg4, ago(3)),
      _peer(l10n, 0, l10n.desktopAppearancePreviewMsg5, ago(2)),
    ];
  }

  void _later(Duration d, VoidCallback fn) {
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      if (mounted) fn();
    });
    _timers.add(t);
  }

  void _trim(List<MessageData> list) {
    // Держим предпросмотр коротким: ленте незачем копить сотни сообщений.
    while (list.length > 14) {
      list.removeAt(0);
    }
  }

  void _send(DesktopComposerSubmission submission) {
    final l10n = AppLocalizations.of(context)!;
    final text = submission.text.trim().isEmpty
        ? l10n.desktopAppearancePreviewOwnDefault
        : submission.text.trim();
    final own = _own(
      l10n,
      text,
      DateTime.now().millisecondsSinceEpoch,
      delivery: DeliveryStatus.sent,
    );
    setState(() {
      _messages = [..._messages!, own];
      _trim(_messages!);
    });
    _later(const Duration(milliseconds: 900), () {
      setState(() {
        _messages = [
          for (final m in _messages!)
            if (m.id == own.id)
              MessageData(
                id: m.id,
                payloadId: m.payloadId,
                authorName: m.authorName,
                text: m.text,
                time: m.time,
                timestampMs: m.timestampMs,
                isSelf: true,
                delivery: DeliveryStatus.read,
                isTextMessage: true,
              )
            else
              m,
        ];
        _typing = l10n.desktopAppearancePreviewTyping(
          l10n.desktopAppearancePreviewMax,
        );
      });
    });
    _later(const Duration(milliseconds: 2300), _incoming);
  }

  void _incoming() {
    final l10n = AppLocalizations.of(context)!;
    final replies = <String>[
      l10n.desktopAppearancePreviewReply1,
      l10n.desktopAppearancePreviewReply2,
      l10n.desktopAppearancePreviewReply3,
      l10n.desktopAppearancePreviewReply4,
      l10n.desktopAppearancePreviewReply5,
    ];
    setState(() {
      _typing = null;
      _messages = [
        ..._messages!,
        _peer(
          l10n,
          _random.nextInt(3),
          replies[_random.nextInt(replies.length)],
          DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      _trim(_messages!);
    });
  }

  bool get _live => decodeAnimatedChatWallpaperStyle(widget.wallpaperId) != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    _messages ??= _initial(l10n);
    // При крупном тексте кнопки шапки — одними значками, подписи в подсказке.
    final compactButtons = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF23A55A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x3323A55A), spreadRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.desktopAppearancePreview.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.48,
                      color: p.muted,
                    ),
                  ),
                ),
                if (_live) ...[
                  SettingsSoftButton(
                    small: true,
                    iconOnly: compactButtons,
                    icon: FluentIcons.arrow_counterclockwise_24_regular,
                    label: l10n.desktopAppearancePreviewReplay,
                    tooltip: l10n.desktopAppearancePreviewReplayHint,
                    onTap: () => setState(() => _opened++),
                  ),
                  const SizedBox(width: 6),
                ],
                SettingsSoftButton(
                  small: true,
                  iconOnly: compactButtons,
                  icon: FluentIcons.arrow_download_24_regular,
                  label: l10n.desktopAppearancePreviewIncoming,
                  tooltip: l10n.desktopAppearancePreviewIncomingHint,
                  onTap: _incoming,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: p.border, spreadRadius: 1),
                  const BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 32,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // Внутри — палитра ОКНА, а не серая гамма настроек: это кусок
                // настоящей переписки и выглядеть обязан как она.
                child: DColors(
                  colors: app,
                  child: KeyedSubtree(
                    // «Переоткрыть» — новая лента: обои проигрывают анимацию
                    // открытия, черта непрочитанного встаёт на своё место.
                    key: ValueKey<int>(_opened),
                    child: ChatThreadPanel(
                      header: ChatHeader(
                        name: l10n.desktopAppearancePreviewChat,
                        status: l10n.desktopAppearancePreviewMembers,
                      ),
                      isDirect: false,
                      messages: _messages!,
                      unreadCount: 2,
                      typingLabel: _typing,
                      onSend: _send,
                      wallpaperId: widget.wallpaperId,
                      wallpaperAnimMode: widget.animMode,
                      wallpaperConduct: widget.conduct,
                      nicknameStylePresetId: widget.nicknamePresetId,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
