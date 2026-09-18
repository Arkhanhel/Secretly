// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../calls/call_event.dart';
import '../../../calls/call_manager.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';
import '../shell/desktop_shell.dart' show DesktopShellApi;
import '../shell/list_thread_split.dart';
import 'desktop_app_view_model.dart';
import 'desktop_selector.dart';

/// Ширина левой панели раздела звонков. Совпадает с исходной шириной списка
/// чатов: разделы отличаются содержимым, а не тем, где проходит граница.
const double _kListWidth = 320;

/// E11: the «Звонки» section — real call history from the journal, with
/// tap-to-recall for 1:1 entries. Replaces the placeholder.
class DesktopCallsSection extends StatefulWidget {
  const DesktopCallsSection({super.key, required this.vm, this.shellApi});

  final DesktopAppViewModel vm;

  /// Ширина левой колонки и ручка её края — общие с чатами: левая панель во
  /// всех разделах одна, как в телеграме. `null` — колонка прежней ширины и
  /// не тянется (тесты, отдельные экраны).
  final DesktopShellApi? shellApi;

  @override
  State<DesktopCallsSection> createState() => _DesktopCallsSectionState();
}

class _DesktopCallsSectionState extends State<DesktopCallsSection> {
  /// The journal, loaded once per settled burst of controller ticks and
  /// republished only when it actually differs.
  ///
  /// This used to be a `StreamBuilder(stream: controller.changed)` wrapped
  /// around a `FutureBuilder`. `changed` fires constantly on a paired client
  /// (outbox pump, presence heartbeats, receipts), and each tick built a NEW
  /// future — so the section re-queried 200 rows and, because a fresh future
  /// starts with `data == null` in the waiting state, replaced the list with a
  /// spinner every time. Mobile hit the same shape in the nav badges and fixed
  /// it the same way (`app_shell.dart`, `_navBadgesFuture`).
  late final DesktopSelector<List<CallJournalEntry>> _journal;

  /// Выбранная запись журнала.
  ///
  /// 🔴 До 13.09 нажатие на строку СРАЗУ НАБИРАЛО НОМЕР. Список истории —
  /// последнее место, где одиночный щелчок должен звонить: по нему ходят
  /// глазами, а промах стоит звонка чужому человеку, который об этом узнает.
  ///
  /// Теперь строка выбирает запись, а звонок — отдельная кнопка справа.
  /// Заодно раздел стал устроен как остальные: слева список, справа то, что
  /// выбрано.
  CallJournalEntry? _selected;

  @override
  void initState() {
    super.initState();
    _journal = widget.vm.callJournal();
    // Clear the missed-call badge when the user opens the section.
    unawaited(widget.vm.acknowledgeMissedCalls());
  }

  @override
  void dispose() {
    _journal.dispose();
    super.dispose();
  }

  Future<void> _recall(CallJournalEntry e) async {
    final cm = CallManager.instance;
    if (cm == null) return;
    // Групповой перезвон — это вход в комнату, и делается он не отсюда.
    if (e.scope != CallRecordScope.oneToOne) return;
    if (e.peerProfileId.isEmpty) return;
    try {
      await cm.startCall(
        peerProfileId: e.peerProfileId,
        peerName: (e.peerDisplayName ?? '').isNotEmpty
            ? e.peerDisplayName!
            : e.peerProfileId,
        peerAvatarPath: e.peerAvatarPath,
        video: e.hadVideo,
      );
    } catch (_) {
      // best-effort; surfaced by the call UI on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final api = widget.shellApi;
    if (api != null) {
      return ListThreadSplit.fromApi(
        api,
        list: _listPanel(c),
        thread: _detail(c),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _kListWidth, child: _listPanel(c)),
        Container(width: 1, color: c.borderSubtle),
        Expanded(child: _detail(c)),
      ],
    );
  }

  /// Левая колонка свёрнута в столбик портретов — как список чатов
  /// (`ChatListPanel.compact`).
  bool get _compact => widget.shellApi?.listCompact ?? false;

  /// Левая панель раздела: заголовок и журнал.
  Widget _listPanel(DColorSet c) {
    final compact = _compact;
    return Container(
      color: c.chatList,
      child: Column(
        children: [
          if (compact) _compactHeader(c) else _header(c),
          Expanded(
            child: ValueListenableBuilder<List<CallJournalEntry>>(
              valueListenable: _journal,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  // An empty list before the first load means "still reading",
                  // not "no calls" — saying the latter would be a lie for the
                  // duration of the query.
                  if (!_journal.hasLoaded) {
                    return Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                        ),
                      ),
                    );
                  }
                  // В столбике подписи не помещаются — пустой журнал там просто
                  // пуст, а объясняет его развёрнутая колонка.
                  return compact ? const SizedBox.shrink() : _empty(c);
                }
                // Отступ по бокам — под скруглённые строки, как в списке
                // чатов: одно правило на все левые панели.
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    compact ? DSpace.p5 : DSpace.s,
                    DSpace.xs,
                    compact ? DSpace.p5 : DSpace.s,
                    DSpace.xs,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return _CallRow(
                      entry: e,
                      compact: compact,
                      selected: identical(e, _selected),
                      onTap: () => setState(() => _selected = e),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Шапка столбика: вместо слова «Звонки» — знак раздела той же высоты,
  /// чтобы строки не прыгали при сворачивании.
  Widget _compactHeader(DColorSet c) {
    return SizedBox(
      height: 52,
      child: Center(
        child: Icon(
          FluentIcons.call_24_regular,
          size: 20,
          color: c.textSecondary,
        ),
      ),
    );
  }

  Widget _header(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.m,
        DSpace.m,
        DSpace.s,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Звонки',
          style: DType.title.copyWith(color: c.textPrimary),
        ),
      ),
    );
  }

  /// Правая часть: карточка выбранного звонка.
  Widget _detail(DColorSet c) {
    final e = _selected;
    if (e == null) {
      return Container(
        color: c.thread,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.call_24_regular, size: 36, color: c.textDisabled),
            const SizedBox(height: DSpace.m),
            Text(
              'Выберите звонок слева',
              style: DType.bodyStrong.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DSpace.xs),
            Text(
              'Здесь появятся подробности и кнопка перезвонить',
              style: DType.caption.copyWith(color: c.textDisabled),
            ),
          ],
        ),
      );
    }
    return _CallDetailCard(entry: e, onRecall: _recall);
  }

  Widget _empty(DColorSet c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.call_24_regular, size: 40, color: c.textDisabled),
          const SizedBox(height: DSpace.m),
          Text(
            'Звонков пока нет',
            style: DType.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            'История появится после первого звонка',
            style: DType.caption.copyWith(color: c.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// Карточка выбранного звонка.
///
/// 🔴 Звонок здесь — ОТДЕЛЬНАЯ КНОПКА, а не последствие щелчка по строке.
/// Раньше нажатие на строку журнала сразу набирало номер: список истории
/// просматривают глазами, и промах стоил звонка чужому человеку, который об
/// этом узнает. Необратимое действие обязано требовать прицельного нажатия.
class _CallDetailCard extends StatelessWidget {
  const _CallDetailCard({required this.entry, required this.onRecall});

  final CallJournalEntry entry;
  final ValueChanged<CallJournalEntry> onRecall;

  bool get _isRoom => entry.scope != CallRecordScope.oneToOne;

  String get _title => (entry.peerDisplayName ?? '').isNotEmpty
      ? entry.peerDisplayName!
      : (entry.peerProfileId.isNotEmpty ? entry.peerProfileId : 'Звонок');

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final missed =
        entry.result == CallRecordResult.missed ||
        entry.result == CallRecordResult.declined ||
        entry.result == CallRecordResult.canceled;
    final outgoing = entry.direction == CallRecordDirection.outgoing;
    final canRecall =
        entry.scope == CallRecordScope.oneToOne &&
        entry.peerProfileId.isNotEmpty;

    return Container(
      color: c.thread,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(DSpace.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(
            name: _title,
            image: Avatar.fileImage(entry.peerAvatarPath),
            size: 96,
            shape: _isRoom ? AvatarShape.room : AvatarShape.round,
          ),
          const SizedBox(height: DSpace.l),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: DType.display.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            [
              outgoing ? 'Исходящий' : 'Входящий',
              _isRoom ? 'групповой' : (entry.hadVideo ? 'видео' : 'аудио'),
              if (missed) 'пропущен',
              if (entry.didConnect && entry.durationMs > 0)
                _fmtDuration(entry.durationMs),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: DType.body.copyWith(
              color: missed ? c.danger : c.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _fmtWhen(entry.startedAtMs),
            style: DType.caption.copyWith(color: c.textDisabled),
          ),
          if (canRecall) ...[
            const SizedBox(height: DSpace.xl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RecallButton(
                  icon: FluentIcons.call_24_regular,
                  label: 'Позвонить',
                  onTap: () => onRecall(entry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecallButton extends StatelessWidget {
  const _RecallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
        decoration: BoxDecoration(
          color: c.success.withValues(
            alpha: pressed ? 0.30 : (hovered ? 0.22 : 0.14),
          ),
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(color: c.success.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c.success),
            const SizedBox(width: 6),
            Text(
              label,
              style: DType.label.copyWith(
                color: c.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.entry,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final CallJournalEntry entry;
  final bool selected;
  final VoidCallback onTap;

  /// Столбик портретов: направление звонка — значком на портрете, всё
  /// остальное — в подсказке.
  final bool compact;

  bool get _isMissed =>
      entry.result == CallRecordResult.missed ||
      entry.result == CallRecordResult.declined ||
      entry.result == CallRecordResult.canceled;

  bool get _isOutgoing => entry.direction == CallRecordDirection.outgoing;

  String get _title => (entry.peerDisplayName ?? '').isNotEmpty
      ? entry.peerDisplayName!
      : (entry.peerProfileId.isNotEmpty ? entry.peerProfileId : 'Звонок');

  String _subtitle() {
    final dir = _isOutgoing ? 'Исходящий' : 'Входящий';
    final isMultiParty =
        entry.scope == CallRecordScope.group ||
        entry.scope == CallRecordScope.room;
    final kind = isMultiParty
        ? 'групповой'
        : (entry.hadVideo ? 'видео' : 'аудио');
    final missed = _isMissed ? ' · пропущен' : '';
    final dur = (entry.didConnect && entry.durationMs > 0)
        ? ' · ${_fmtDuration(entry.durationMs)}'
        : '';
    return '$dir · $kind$missed$dur';
  }

  Widget _compactRow(DColorSet c, Widget avatar, IconData icon, Color tone) {
    return DesktopTooltip(
      message: '$_title\n${_subtitle()} · ${_fmtWhen(entry.startedAtMs)}',
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          height: 58,
          margin: const EdgeInsets.symmetric(vertical: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? c.accentPrimary.withValues(alpha: 0.20)
                : (pressed
                      ? c.pressed
                      : (hovered ? c.hover : Colors.transparent)),
            borderRadius: BorderRadius.circular(DRadii.md),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              // Направление и пропуск — значком на портрете: без подписи
              // пропущенный звонок иначе не отличить от состоявшегося.
              Positioned(
                right: -4,
                bottom: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.chatList,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: tone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final color = _isMissed ? c.danger : c.textSecondary;
    final icon = _isOutgoing
        ? FluentIcons.call_outbound_24_regular
        : (_isMissed
              ? FluentIcons.call_missed_24_regular
              : FluentIcons.call_inbound_24_regular);
    final isRoom = entry.scope != CallRecordScope.oneToOne;
    final avatar = Avatar(
      name: _title,
      size: 40,
      shape: isRoom ? AvatarShape.room : AvatarShape.round,
    );

    if (compact) return _compactRow(c, avatar, icon, color);

    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    c.accentPrimary.withValues(alpha: 0.20),
                    c.accentPrimaryAlt.withValues(alpha: 0.16),
                  ],
                )
              : null,
          color: selected
              ? null
              : (pressed
                    ? c.pressed
                    : (hovered ? c.hover : Colors.transparent)),
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(
            color: selected
                ? c.accentPrimary.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.s + 2,
          vertical: DSpace.s,
        ),
        child: Row(
          children: [
            // Групповой звонок — это комната, и портрет у него комнатный:
            // форма означает тип разговора во всём окне одинаково.
            avatar,
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: DType.bodyStrong.copyWith(
                      color: _isMissed ? c.danger : c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _subtitle(),
                          style: DType.caption.copyWith(color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: DSpace.m),
            Text(
              _fmtWhen(entry.startedAtMs),
              style: DType.caption.copyWith(color: c.textDisabled),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDuration(int ms) {
  final total = (ms / 1000).floor();
  final mm = (total ~/ 60).toString().padLeft(2, '0');
  final ss = (total % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String _fmtWhen(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  final sameDay =
      d.year == now.year && d.month == now.month && d.day == now.day;
  if (sameDay) return '$hh:$min';
  final dd = d.day.toString().padLeft(2, '0');
  final mo = d.month.toString().padLeft(2, '0');
  return '$dd.$mo $hh:$min';
}
