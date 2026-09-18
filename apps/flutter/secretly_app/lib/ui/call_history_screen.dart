// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../calls/call_event.dart';
import '../calls/call_failure.dart';
import '../calls/call_journal.dart';
import '../calls/call_manager.dart';
import '../calls/call_state.dart';
import 'animations/animations.dart';
import 'call_error_text.dart';
import 'chat_screen.dart';
import 'call_history_l10n.dart';
import 'diagnostics_screen.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_top_bar.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({
    super.key,
    required this.controller,
    this.convoId,
    this.peerProfileId,
    this.title,
    this.avatarPath,
  });

  final AppController controller;
  final String? convoId;
  final String? peerProfileId;
  final String? title;
  final String? avatarPath;

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

enum _CallHistoryFilter { all, missed, video }

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  _CallHistoryFilter _filter = _CallHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    unawaited(_acknowledgeVisibleMissedCalls());
  }

  bool get _isScoped =>
      (widget.convoId != null && widget.convoId!.trim().isNotEmpty) ||
      (widget.peerProfileId != null && widget.peerProfileId!.trim().isNotEmpty);

  bool get _isRu => callHistoryLocaleIsRussian(context);

  String _label({required String ru, required String en}) {
    return callHistoryText(context, ru: ru, en: en);
  }

  Future<void> _acknowledgeVisibleMissedCalls() async {
    final convoId = (widget.convoId ?? '').trim();
    if (convoId.isNotEmpty) {
      await widget.controller.acknowledgeMissedCalls(convoId: convoId);
      return;
    }
    if (!_isScoped) {
      await widget.controller.acknowledgeMissedCalls();
    }
  }

  Future<void> _openChat(CallJournalEntry entry) async {
    final navigator = Navigator.of(context);
    await widget.controller.acknowledgeMissedCalls(convoId: entry.convoId);
    final title = _displayPeerName(entry);
    if (!mounted) return;
    await navigator.push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: entry.convoId,
          title: title,
          peerProfileIdForSend: entry.peerProfileId,
        ),
      ),
    );
  }

  Future<void> _redial(CallJournalEntry entry) async {
    final l10n = context.l10n;
    final cm = CallManager.instance;
    if (cm == null) {
      _showMessage(
        callErrorText(l10n, CallFailure(CallFailureCode.serviceUnavailable)),
      );
      return;
    }
    if (cm.state.value.isActive) {
      _showMessage(
        callErrorText(l10n, CallFailure(CallFailureCode.alreadyInProgress)),
      );
      return;
    }
    try {
      await cm.startCall(
        peerProfileId: entry.peerProfileId,
        peerName: _displayPeerName(entry),
        peerAvatarPath: entry.peerAvatarPath,
        video: entry.isVideoLike,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(callErrorText(l10n, e));
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(text)));
  }

  bool _matchesFilter(CallJournalEntry entry) {
    switch (_filter) {
      case _CallHistoryFilter.all:
        return true;
      case _CallHistoryFilter.missed:
        return entry.result == CallRecordResult.missed;
      case _CallHistoryFilter.video:
        return entry.isVideoLike;
    }
  }

  String _displayPeerName(CallJournalEntry entry) {
    final explicit = (entry.peerDisplayName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    if ((widget.title ?? '').trim().isNotEmpty) return widget.title!.trim();
    final peer = entry.peerProfileId.trim();
    if (peer.isNotEmpty) return peer;
    final convo = entry.convoId.trim();
    return convo.isNotEmpty
        ? convo
        : _label(ru: 'Неизвестный контакт', en: 'Unknown contact');
  }

  String _screenTitle() {
    final scopedTitle = (widget.title ?? '').trim();
    if (_isScoped && scopedTitle.isNotEmpty) return scopedTitle;
    return _label(ru: 'Звонки', en: 'Calls');
  }

  String _filterLabel(_CallHistoryFilter filter) {
    switch (filter) {
      case _CallHistoryFilter.all:
        return _label(ru: 'Все', en: 'All');
      case _CallHistoryFilter.missed:
        return _label(ru: 'Пропущенные', en: 'Missed');
      case _CallHistoryFilter.video:
        return _label(ru: 'Видео', en: 'Video');
    }
  }

  String _sectionLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return _label(ru: 'Сегодня', en: 'Today');
    if (diff == 1) return _label(ru: 'Вчера', en: 'Yesterday');
    final month = _monthLabel(dt.month);
    return '${dt.day} $month';
  }

  String _monthLabel(int month) {
    return callHistoryMonthLabel(context, month);
  }

  String _timeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dateTimeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day.$month.$year ${_timeLabel(ms)}';
  }

  CallQualitySummary? _qualitySummary(CallJournalEntry entry) {
    return CallQualitySummary.decode(entry.qualitySummaryJson);
  }

  String _persistedFailureLabel(CallFailureCode code) {
    switch (code) {
      case CallFailureCode.iceConfigUnavailable:
      case CallFailureCode.permissionDenied:
      case CallFailureCode.invalidRemoteOffer:
      case CallFailureCode.invalidRemoteAnswer:
      case CallFailureCode.localOfferUnavailable:
      case CallFailureCode.signalingConflict:
      case CallFailureCode.connectionInterrupted:
        return callErrorText(context.l10n, CallFailure(code));
      case CallFailureCode.serviceUnavailable:
      case CallFailureCode.alreadyInProgress:
      case CallFailureCode.generic:
        return _label(ru: 'Ошибка соединения', en: 'Connection error');
    }
  }

  String _endReasonLabel(CallJournalEntry entry) {
    final endReason = entry.endReasonValue;
    if (endReason == CallEndReason.error && entry.failureCode != null) {
      return _persistedFailureLabel(entry.failureCode!);
    }

    switch (endReason) {
      case CallEndReason.localHangup:
      case CallEndReason.remoteHangup:
        return _label(ru: 'Звонок завершён', en: 'Call ended');
      case CallEndReason.remoteSuperseded:
        return _label(
          ru: 'Попытка заменена новой',
          en: 'Superseded by newer attempt',
        );
      case CallEndReason.remoteDecline:
        return _label(ru: 'Вызов отклонён', en: 'Call declined');
      case CallEndReason.localDecline:
        return _label(ru: 'Вы отклонили', en: 'You declined');
      case CallEndReason.timeout:
        return _label(ru: 'Нет ответа', en: 'No answer');
      case CallEndReason.error:
        return _label(ru: 'Ошибка соединения', en: 'Connection error');
      case null:
        return _label(ru: 'Звонок завершён', en: 'Call ended');
    }
  }

  String? _qualityLabel(CallQualitySummary? quality) {
    final level = (quality?.qualityLevel ?? '').trim().toLowerCase();
    switch (level) {
      case 'excellent':
        return _label(ru: 'Качество: отличное', en: 'Quality: excellent');
      case 'good':
        return _label(ru: 'Качество: хорошее', en: 'Quality: good');
      case 'fair':
        return _label(ru: 'Качество: среднее', en: 'Quality: fair');
      case 'poor':
        return _label(ru: 'Качество: плохое', en: 'Quality: poor');
      default:
        return null;
    }
  }

  String _detailSummary(CallJournalEntry entry) {
    final parts = <String>[];
    if (entry.result != CallRecordResult.completed || entry.durationMs <= 0) {
      parts.add(_endReasonLabel(entry));
    }
    final qualityText = _qualityLabel(_qualitySummary(entry));
    if (qualityText != null) {
      parts.add(qualityText);
    }
    return parts.join(' · ');
  }

  bool _isTroubleshootingCandidate(CallJournalEntry entry) {
    final quality = _qualitySummary(entry);
    final qualityLevel = (quality?.qualityLevel ?? '').trim().toLowerCase();
    if (entry.failureCode != null ||
        entry.endReasonValue == CallEndReason.error ||
        entry.result == CallRecordResult.failed) {
      return true;
    }
    if (entry.endReasonValue == CallEndReason.timeout &&
        entry.direction == CallRecordDirection.outgoing) {
      return true;
    }
    if (qualityLevel == 'poor' || qualityLevel == 'fair') {
      return true;
    }
    return (quality?.rttMs ?? 0) >= 800 ||
        (quality?.jitterMs ?? 0) >= 120 ||
        (quality?.packetLossPct ?? 0) >= 4;
  }

  Future<void> _openDiagnostics() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      SecretlyPageRoute(
        builder: (_) => DiagnosticsScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _showDetails(CallJournalEntry entry) {
    final quality = _qualitySummary(entry);
    final qualityText = _qualityLabel(quality);
    final canTroubleshoot = _isTroubleshootingCandidate(entry);
    final metrics = <String>[];
    if (quality?.rttMs != null) {
      metrics.add('RTT ${quality!.rttMs!.round()} ms');
    }
    if (quality?.jitterMs != null) {
      metrics.add(
        '${_label(ru: 'Джиттер', en: 'Jitter')} ${quality!.jitterMs!.round()} ms',
      );
    }
    if (quality?.packetLossPct != null) {
      metrics.add(
        '${_label(ru: 'Потери', en: 'Loss')} ${quality!.packetLossPct!.toStringAsFixed(1)}%',
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final detailRows = <(String, String)>[
          (
            _label(ru: 'Тип', en: 'Type'),
            callRecordResultLabel(
              entry.result,
              l10n: context.l10n,
              isRu: _isRu,
              direction: entry.direction,
              isVideo: entry.isVideoLike,
            ),
          ),
          (_label(ru: 'Причина', en: 'Reason'), _endReasonLabel(entry)),
          (
            _label(ru: 'Начало', en: 'Started'),
            _dateTimeLabel(entry.startedAtMs),
          ),
          (
            _label(ru: 'Завершение', en: 'Ended'),
            _dateTimeLabel(entry.endedAtMs),
          ),
        ];
        if (entry.didConnect && entry.durationMs > 0) {
          detailRows.insert(2, (
            _label(ru: 'Длительность', en: 'Duration'),
            formatCallDurationShort(entry.durationMs),
          ));
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(context, entry),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayPeerName(entry),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            callRecordResultLabel(
                              entry.result,
                              l10n: context.l10n,
                              isRu: _isRu,
                              direction: entry.direction,
                              isVideo: entry.isVideoLike,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...detailRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 104,
                          child: Text(
                            row.$1,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        Expanded(child: Text(row.$2)),
                      ],
                    ),
                  ),
                ),
                if (qualityText != null || metrics.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _label(ru: 'Качество', en: 'Quality'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (qualityText != null)
                    Text(
                      qualityText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (metrics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metrics.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                if (canTroubleshoot) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        unawaited(_openDiagnostics());
                      },
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: Text(
                        _label(
                          ru: 'Открыть диагностику звонков',
                          en: 'Open call diagnostics',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(_openChat(entry));
                        },
                        child: Text(_label(ru: 'Открыть чат', en: 'Open chat')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(_redial(entry));
                        },
                        child: Text(_label(ru: 'Перезвонить', en: 'Call back')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(CallJournalEntry entry) {
    final preview = buildCallEventPreviewText(
      l10n: context.l10n,
      isRu: _isRu,
      result: entry.result,
      direction: entry.direction,
      isVideo: entry.isVideoLike,
      durationMs: entry.durationMs,
    );
    if (_isScoped) {
      final when = _timeLabel(entry.endedAtMs);
      final detail = _detailSummary(entry);
      if (detail.isEmpty) return '$preview · $when';
      return '$preview · $when\n$detail';
    }
    final detail = _detailSummary(entry);
    if (detail.isEmpty) return preview;
    return '$preview\n$detail';
  }

  IconData _directionIcon(CallJournalEntry entry) {
    if (entry.result == CallRecordResult.missed) {
      return AppIcons.callEnd;
    }
    if (entry.isVideoLike) return AppIcons.video;
    return entry.direction == CallRecordDirection.outgoing
        ? AppIcons.callAlt
        : AppIcons.call;
  }

  Color _accentColor(BuildContext context, CallJournalEntry entry) {
    final cs = Theme.of(context).colorScheme;
    switch (entry.result) {
      case CallRecordResult.completed:
        return cs.primary;
      case CallRecordResult.missed:
      case CallRecordResult.failed:
        return cs.error;
      case CallRecordResult.declined:
      case CallRecordResult.busy:
      case CallRecordResult.canceled:
        return cs.tertiary;
      case CallRecordResult.ongoing:
        return Colors.green;
    }
  }

  Widget _buildAvatar(BuildContext context, CallJournalEntry entry) {
    final avatarPath = (entry.peerAvatarPath ?? widget.avatarPath ?? '').trim();
    final hasAvatar = avatarPath.isNotEmpty && File(avatarPath).existsSync();
    final seed = entry.peerProfileId.isNotEmpty
        ? entry.peerProfileId
        : entry.convoId;
    final title = _displayPeerName(entry);
    final cs = Theme.of(context).colorScheme;

    Widget avatar;
    if (hasAvatar) {
      avatar = CircleAvatar(backgroundImage: FileImage(File(avatarPath)));
    } else {
      avatar = AvatarInitials.fallbackBubble(
        context: context,
        radius: 20,
        seed: seed,
        displayName: title,
        fallbackId: seed,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                _directionIcon(entry),
                size: 14,
                color: _accentColor(context, entry),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeHeader(List<CallJournalEntry> entries) {
    if (!_isScoped) return const SizedBox.shrink();
    final latest = entries.isNotEmpty ? entries.first : null;
    final name = (widget.title ?? latest?.peerDisplayName ?? '').trim();
    final displayName = name.isEmpty
        ? _label(ru: 'История звонков', en: 'Call history')
        : name;
    final total = entries.length;
    final missed = entries
        .where((entry) => entry.result == CallRecordResult.missed)
        .length;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildAvatar(
                context,
                latest ??
                    CallJournalEntry(
                      callId: '',
                      callAttemptId: '',
                      convoId: widget.convoId ?? widget.peerProfileId ?? '',
                      peerProfileId: widget.peerProfileId ?? '',
                      direction: CallRecordDirection.outgoing,
                      scope: CallRecordScope.oneToOne,
                      mediaType: CallRecordMediaType.audio,
                      result: CallRecordResult.completed,
                      startedAtMs: 0,
                      connectedAtMs: null,
                      endedAtMs: 0,
                      durationMs: 0,
                      endReason: null,
                      peerDisplayName: widget.title,
                      peerAvatarPath: widget.avatarPath,
                      didConnect: false,
                      hadVideo: false,
                      hadScreenShare: false,
                      qualitySummaryJson: null,
                      createdLocalEventId: null,
                      syncedChatEventId: null,
                      acknowledgedAtMs: null,
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      callHistoryTotalMissedText(
                        context,
                        total: total,
                        missed: missed,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(_screenTitle())),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return FutureBuilder<List<CallJournalEntry>>(
            future: widget.controller.listCallJournalEntries(
              convoId: widget.convoId,
              limit: 200,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const ShimmerSettingsList(itemCount: 8);
              }

              final entries = (snapshot.data ?? const <CallJournalEntry>[])
                  .where((entry) => _matchesFilter(entry))
                  .toList(growable: false);

              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.call,
                          size: 42,
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.72),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == _CallHistoryFilter.all
                              ? _label(
                                  ru: 'История звонков пока пуста',
                                  en: 'No call history yet',
                                )
                              : _label(
                                  ru: 'Нет записей для выбранного фильтра',
                                  en: 'No entries for the selected filter',
                                ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final children = <Widget>[
                if (_isScoped) _buildScopeHeader(entries),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _CallHistoryFilter.values
                        .map(
                          (filter) => ChoiceChip(
                            label: Text(_filterLabel(filter)),
                            selected: _filter == filter,
                            onSelected: (_) {
                              setState(() {
                                _filter = filter;
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ];

              String? lastSection;
              for (final entry in entries) {
                final section = _sectionLabel(
                  DateTime.fromMillisecondsSinceEpoch(entry.endedAtMs),
                );
                if (section != lastSection) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        section,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                  lastSection = section;
                }
                children.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openChat(entry),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            children: [
                              _buildAvatar(context, entry),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isScoped
                                          ? callRecordResultLabel(
                                              entry.result,
                                              l10n: context.l10n,
                                              isRu: _isRu,
                                              direction: entry.direction,
                                              isVideo: entry.isVideoLike,
                                            )
                                          : _displayPeerName(entry),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _subtitle(entry),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _timeLabel(entry.endedAtMs),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: IconButton.filledTonal(
                                      tooltip: _label(
                                        ru: 'Детали',
                                        en: 'Details',
                                      ),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                      ),
                                      onPressed: () => _showDetails(entry),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: IconButton.filledTonal(
                                      tooltip: _label(
                                        ru: 'Перезвонить',
                                        en: 'Call back',
                                      ),
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        entry.isVideoLike
                                            ? AppIcons.video
                                            : AppIcons.call,
                                        size: 18,
                                      ),
                                      onPressed: () => _redial(entry),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return ListView(children: children);
            },
          );
        },
      ),
    );
  }
}
