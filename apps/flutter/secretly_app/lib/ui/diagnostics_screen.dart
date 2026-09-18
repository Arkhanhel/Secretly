// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../diagnostics/identity_journal.dart';
import '../security/keychain_migration.dart';
import '../transport/server_clock.dart';
import 'diagnostics_unlock.dart';
import 'settings_screen_l10n.dart';
import '../calls/call_manager.dart';
import '../app/app_controller.dart';
import '../ratchet/session_manager_v3.dart' show kPrekeyUntilConfirmedSend;
import '../calls/call_event.dart';
import '../calls/call_failure.dart';
import '../calls/call_journal.dart';
import '../calls/call_state.dart';
import '../sync/peer_history_service.dart';
import '../transport/service_health_status.dart';
import 'paywall_screen.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';

class _MessageDiagnosticsData {
  const _MessageDiagnosticsData({
    required this.outboxCounts,
    required this.pendingReceiptCount,
    required this.actionableSnapshots,
    required this.traceStateLog,
    required this.traceAttemptLog,
    required this.safetyNumberNotices,
    required this.outboxFailedSummary,
    required this.accountIdentityReadiness,
    required this.fullScreenIntent,
  });

  final Map<String, int> outboxCounts;
  final int pendingReceiptCount;
  final List<Map<String, Object?>> actionableSnapshots;
  final List<Map<String, Object?>> traceStateLog;
  final List<Map<String, Object?>> traceAttemptLog;

  /// Замер, гатящий слой 2 номера безопасности (см. AppController).
  final String safetyNumberNotices;

  /// Разбор конечного состояния `failed`: потеря или мусор в таблице.
  final String outboxFailedSummary;

  /// Гейт Ш-3 модели Signal: доля контактов со слоем 2 и счётчики сертификатов.
  final String accountIdentityReadiness;

  /// Может ли уведомление поднять экран звонка само (Android 14+).
  final String fullScreenIntent;
}

class _CallDiagnosticsData {
  const _CallDiagnosticsData({
    required this.recentEntries,
    required this.actionableEntries,
  });

  final List<CallJournalEntry> recentEntries;
  final List<CallJournalEntry> actionableEntries;
}

class _DiagnosticsData {
  const _DiagnosticsData({
    required this.message,
    required this.calls,
    required this.identityJournal,
    required this.roomKeys,
    required this.keychainScope,
  });

  final _MessageDiagnosticsData message;
  final _CallDiagnosticsData calls;

  /// Why this install's identity ever changed. Carried in the report the user
  /// sends, because an identity loss otherwise leaves no trace anyone can read
  /// — the gap that made the 2026-07-30 investigation inconclusive.
  final String identityJournal;

  /// SEC-02: где лежат секреты этого устройства и не осталось ли записей,
  /// которые ещё переезжают на новое устройство через резервную копию Apple.
  ///
  /// 🔴 Это ПРОВЕРКА, а не отчёт о запуске. «Перенесено» доказывало бы лишь,
  /// что код отработал; остаток же виден перечислением по старому атрибуту —
  /// ноль означает, что переносить больше нечего.
  final String keychainScope;

  /// Per-room sender-key state (F-ROOMSK-6). `owed > 0` means the room still
  /// sends over the pairwise fanout — the question a field tester actually has.
  final String roomKeys;
}

String _healthCompatibilityLabel(ServiceHealthStatus status) {
  switch (status.compatibilityState) {
    case ServiceCompatibilityState.unknown:
      return 'unknown';
    case ServiceCompatibilityState.supported:
      return 'supported';
    case ServiceCompatibilityState.clientTooOld:
      return 'client_too_old';
    case ServiceCompatibilityState.clientTooNew:
      return 'client_too_new';
  }
}

String? _healthReleaseLabel(ServiceHealthStatus status) {
  return status.releaseMetadataLabel;
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  AppController get controller => widget.controller;

  bool _developerActionsVisible = false;

  bool _isRu(BuildContext context) {
    return wave1LocaleIsRussian(context);
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    return wave1Text(context, ru: ru, en: en);
  }

  String _relativeTimeLabel(BuildContext context, DateTime at) {
    final localeTag = wave1LocaleTagFromContext(context);
    final rawDiff = DateTime.now().difference(at);
    final future = rawDiff.isNegative;
    final diff = rawDiff.abs();
    if (diff.inSeconds < 45) {
      return future
          ? wave1Text(
              context,
              ru: 'скоро',
              en: 'soon',
              uk: 'скоро',
              es: 'pronto',
              pt: 'em breve',
              fr: 'bientot',
              de: 'bald',
            )
          : wave1Text(
              context,
              ru: 'только что',
              en: 'just now',
              uk: 'щойно',
              es: 'ahora mismo',
              pt: 'agora mesmo',
              fr: 'a l instant',
              de: 'gerade eben',
            );
    }

    String unit(
      int value,
      String ruOne,
      String ruFew,
      String ruMany,
      String en,
    ) {
      if (localeTag != 'ru') {
        if (localeTag == 'uk') {
          final mod10 = value % 10;
          final mod100 = value % 100;
          final forms = switch (en) {
            'day' => ('день', 'дні', 'днів'),
            'hour' => ('годину', 'години', 'годин'),
            'minute' => ('хвилину', 'хвилини', 'хвилин'),
            _ => ('секунду', 'секунди', 'секунд'),
          };
          final word = mod10 == 1 && mod100 != 11
              ? forms.$1
              : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
              ? forms.$2
              : forms.$3;
          return '$value $word';
        }
        if (localeTag == 'es') {
          final word = switch (en) {
            'day' => value == 1 ? 'dia' : 'dias',
            'hour' => value == 1 ? 'hora' : 'horas',
            'minute' => value == 1 ? 'minuto' : 'minutos',
            _ => value == 1 ? 'segundo' : 'segundos',
          };
          return '$value $word';
        }
        if (localeTag == 'pt' || localeTag == 'pt_BR') {
          final word = switch (en) {
            'day' => value == 1 ? 'dia' : 'dias',
            'hour' => value == 1 ? 'hora' : 'horas',
            'minute' => value == 1 ? 'minuto' : 'minutos',
            _ => value == 1 ? 'segundo' : 'segundos',
          };
          return '$value $word';
        }
        if (localeTag == 'fr') {
          final word = switch (en) {
            'day' => value == 1 ? 'jour' : 'jours',
            'hour' => value == 1 ? 'heure' : 'heures',
            'minute' => value == 1 ? 'minute' : 'minutes',
            _ => value == 1 ? 'seconde' : 'secondes',
          };
          return '$value $word';
        }
        if (localeTag == 'de') {
          final word = switch (en) {
            'day' => value == 1 ? 'Tag' : 'Tage',
            'hour' => value == 1 ? 'Stunde' : 'Stunden',
            'minute' => value == 1 ? 'Minute' : 'Minuten',
            _ => value == 1 ? 'Sekunde' : 'Sekunden',
          };
          return '$value $word';
        }
        return '$value $en${value == 1 ? '' : 's'}';
      }
      final mod10 = value % 10;
      final mod100 = value % 100;
      final word = mod10 == 1 && mod100 != 11
          ? ruOne
          : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
          ? ruFew
          : ruMany;
      return '$value $word';
    }

    final value = diff.inDays >= 1
        ? unit(diff.inDays, 'день', 'дня', 'дней', 'day')
        : diff.inHours >= 1
        ? unit(diff.inHours, 'час', 'часа', 'часов', 'hour')
        : diff.inMinutes >= 1
        ? unit(diff.inMinutes, 'минуту', 'минуты', 'минут', 'minute')
        : unit(diff.inSeconds, 'секунду', 'секунды', 'секунд', 'second');
    if (future) {
      return wave1Text(
        context,
        ru: 'через $value',
        en: 'in $value',
        uk: 'через $value',
        es: 'en $value',
        pt: 'em $value',
        fr: 'dans $value',
        de: 'in $value',
      );
    }
    return wave1Text(
      context,
      ru: '$value назад',
      en: '$value ago',
      uk: '$value тому',
      es: 'hace $value',
      pt: 'ha $value',
      ptBr: 'ha $value',
      fr: 'il y a $value',
      de: 'vor $value',
    );
  }

  String _fmtMs(BuildContext context, int ms) {
    if (ms <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${_relativeTimeLabel(context, dt)} · ${dt.toIso8601String()}';
  }

  void _unlockDeveloperActions(BuildContext context) {
    if (_developerActionsVisible) return;
    setState(() {
      _developerActionsVisible = true;
    });
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SecretlySnackBar(
        content: Text(
          _label(
            context,
            ru: 'Действия разработчика открыты',
            en: 'Developer actions unlocked',
          ),
        ),
      ),
    );
  }

  String _durationLabel(int durationMs) {
    if (durationMs <= 0) return '—';
    return formatCallDurationShort(durationMs);
  }

  Future<_MessageDiagnosticsData> _loadMessageDiagnostics() async {
    final safetyNumberNotices = await controller.safetyNumberNoticeSummary();
    final outboxFailedSummary = await controller.outboxFailedSummary();
    final accountIdentityReadiness =
        await controller.accountIdentityReadinessSummary();
    final fsi = await CallManager.instance?.canUseFullScreenIntent();
    final fullScreenIntent = fsi == null
        ? 'full_screen_intent: (нет менеджера звонков)'
        : !fsi.supported
        ? 'full_screen_intent: не требуется на этой версии Android'
        : fsi.granted
        ? 'full_screen_intent: РАЗРЕШЕНО — экран звонка поднимется сам'
        : 'full_screen_intent: 🔴 ЗАПРЕЩЕНО — экран звонка из фона НЕ поднимется';
    final counts = await controller.outboxStateCounts();
    final pendingReceiptCount = await controller.pendingReceiptCount();
    final snapshots = await controller.listMessageDiagSnapshots(
      limit: 8,
      actionableOnly: true,
    );
    final first = snapshots.isNotEmpty ? snapshots.first : null;
    final localEventId = first?['local_event_id'] as String?;
    final correlationId = first?['correlation_id'] as String?;
    final stateLog = await controller.listMessageStateLog(
      localEventId: localEventId,
      correlationId: correlationId,
      limit: 10,
    );
    final attemptLog = await controller.listMessageAttemptLog(
      localEventId: localEventId,
      correlationId: correlationId,
      limit: 10,
    );
    return _MessageDiagnosticsData(
      safetyNumberNotices: safetyNumberNotices,
      outboxFailedSummary: outboxFailedSummary,
      accountIdentityReadiness: accountIdentityReadiness,
      fullScreenIntent: fullScreenIntent,
      outboxCounts: counts,
      pendingReceiptCount: pendingReceiptCount,
      actionableSnapshots: snapshots,
      traceStateLog: stateLog,
      traceAttemptLog: attemptLog,
    );
  }

  Future<_CallDiagnosticsData> _loadCallDiagnostics() async {
    final entries = await controller.listCallJournalEntries(limit: 24);
    final actionable = entries.where(_isActionableCall).take(8).toList();
    return _CallDiagnosticsData(
      recentEntries: entries,
      actionableEntries: actionable,
    );
  }

  /// SEC-02: сколько секретов ещё лежит с атрибутом, допускающим перенос на
  /// другое устройство через резервную копию Apple.
  Future<String> _loadKeychainScope() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      // Android: атрибута доступности нет, резервные копии приложения выключены
      // манифестом — переносить нечего.
      return 'хранилище ключей: Android, перенос не требуется';
    }
    try {
      // 🔴 ТАЙМАУТ ОБЯЗАТЕЛЕН. Обращение к хранилищу ключей идёт через
      // платформенный канал, и тот может не ответить никогда: в тестовой среде
      // канала нет вовсе, а на устройстве Keychain способен подвиснуть под
      // блокировкой. Без ограничения экран диагностики просто не достраивается
      // — именно так три теста экрана и зависли, пока это не поймал полный
      // прогон.
      final left = await KeychainAccessibilityMigration()
          .remainingLegacyCount()
          .timeout(const Duration(seconds: 2));
      return left == 0
          ? 'хранилище ключей: только это устройство (переносить нечего)'
          : 'хранилище ключей: ОСТАЛОСЬ ПЕРЕНЕСТИ $left';
    } catch (_) {
      return 'хранилище ключей: проверить не удалось';
    }
  }

  Future<_DiagnosticsData> _loadDiagnostics() async {
    final message = await _loadMessageDiagnostics();
    final calls = await _loadCallDiagnostics();
    final identityJournal = await IdentityJournal.summarize();
    final roomKeys = await controller.roomSenderKeyDiagnosticsReport();
    final keychainScope = await _loadKeychainScope();
    return _DiagnosticsData(
      message: message,
      calls: calls,
      identityJournal: identityJournal,
      roomKeys: roomKeys,
      keychainScope: keychainScope,
    );
  }

  String _stringField(Map<String, Object?> row, String key) {
    final value = row[key];
    return (value == null ? '' : value.toString()).trim();
  }

  String _displayPeerName(CallJournalEntry entry) {
    final explicit = (entry.peerDisplayName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final peer = entry.peerProfileId.trim();
    if (peer.isNotEmpty) return peer;
    final convo = entry.convoId.trim();
    return convo.isNotEmpty ? convo : 'Unknown contact';
  }

  CallQualitySummary? _qualitySummary(CallJournalEntry entry) {
    return CallQualitySummary.decode(entry.qualitySummaryJson);
  }

  bool _isActionableCall(CallJournalEntry entry) {
    final quality = _qualitySummary(entry);
    final qualityLevel = (quality?.qualityLevel ?? '').trim().toLowerCase();
    final rttMs = quality?.rttMs ?? 0;
    final jitterMs = quality?.jitterMs ?? 0;
    final packetLossPct = quality?.packetLossPct ?? 0;
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
    return rttMs >= 800 || jitterMs >= 120 || packetLossPct >= 4;
  }

  String _callFailureDebugLabel(CallFailureCode code) {
    switch (code) {
      case CallFailureCode.iceConfigUnavailable:
        return 'Secure call ICE/TURN configuration was unavailable';
      case CallFailureCode.permissionDenied:
        return 'Local microphone or camera permission was blocked';
      case CallFailureCode.invalidRemoteOffer:
        return 'Remote offer validation failed';
      case CallFailureCode.invalidRemoteAnswer:
        return 'Remote answer validation failed';
      case CallFailureCode.localOfferUnavailable:
        return 'Local offer generation failed';
      case CallFailureCode.signalingConflict:
        return 'Call signaling entered a conflicting state';
      case CallFailureCode.connectionInterrupted:
        return 'The call ended because the media connection was interrupted';
      case CallFailureCode.serviceUnavailable:
      case CallFailureCode.alreadyInProgress:
      case CallFailureCode.generic:
        return 'The call ended because of a connection error';
    }
  }

  String _callEndReasonLabel(CallJournalEntry entry) {
    final endReason = entry.endReasonValue;
    if (endReason == CallEndReason.error && entry.failureCode != null) {
      return _callFailureDebugLabel(entry.failureCode!);
    }

    switch (endReason) {
      case CallEndReason.remoteDecline:
        return 'Recipient declined the call';
      case CallEndReason.localDecline:
        return 'Call was declined on this device';
      case CallEndReason.remoteSuperseded:
        return 'This call attempt was replaced by a newer authoritative attempt';
      case CallEndReason.timeout:
        return 'The call timed out before connection';
      case CallEndReason.error:
        return 'The call ended because of a connection error';
      case CallEndReason.remoteHangup:
      case CallEndReason.localHangup:
      case null:
        return 'The call ended normally';
    }
  }

  String? _callQualityLabel(CallJournalEntry entry) {
    final level = (_qualitySummary(entry)?.qualityLevel ?? '')
        .trim()
        .toLowerCase();
    switch (level) {
      case 'excellent':
        return 'Quality: excellent';
      case 'good':
        return 'Quality: good';
      case 'fair':
        return 'Quality: fair';
      case 'poor':
        return 'Quality: poor';
      default:
        return null;
    }
  }

  String _callIssueSummary(CallJournalEntry entry) {
    final quality = _qualitySummary(entry);
    final qualityLevel = (quality?.qualityLevel ?? '').trim().toLowerCase();
    switch (entry.failureCode) {
      case CallFailureCode.iceConfigUnavailable:
        return 'Call setup failed before media negotiation. Check TURN/ICE config delivery from backend services.';
      case CallFailureCode.permissionDenied:
        return 'Media capture was blocked locally. Verify microphone/camera permissions on the device.';
      case CallFailureCode.invalidRemoteOffer:
      case CallFailureCode.invalidRemoteAnswer:
        return 'Remote signaling payload was invalid. Inspect SDP integrity and relay ordering.';
      case CallFailureCode.localOfferUnavailable:
        return 'Local SDP generation failed. Inspect peer-connection initialization and media setup.';
      case CallFailureCode.signalingConflict:
        return 'Negotiation hit a signaling-state conflict. Inspect duplicate offers/answers and rollback paths.';
      case CallFailureCode.connectionInterrupted:
        return 'Media transport dropped after setup. Check TURN reachability, disposed WebRTC handles, and network stability.';
      case CallFailureCode.serviceUnavailable:
      case CallFailureCode.alreadyInProgress:
      case CallFailureCode.generic:
      case null:
        break;
    }
    if (entry.endReasonValue == CallEndReason.error ||
        entry.result == CallRecordResult.failed) {
      return 'Connection failure. Check relay/TURN reachability and local network stability.';
    }
    if (entry.endReasonValue == CallEndReason.timeout) {
      return 'Invite timed out. Check whether the peer was online and whether signaling reached the recipient.';
    }
    if (qualityLevel == 'poor') {
      return 'Severe media degradation detected. Expect voice/video drops and reconnection pressure.';
    }
    if (qualityLevel == 'fair') {
      return 'Moderate media degradation detected. Quality dipped below release target.';
    }
    return 'Review network path and signaling timing for this call.';
  }

  String _callMetricsSummary(CallJournalEntry entry) {
    final quality = _qualitySummary(entry);
    final parts = <String>[];
    if (quality?.rttMs != null) {
      parts.add('RTT ${quality!.rttMs!.round()} ms');
    }
    if (quality?.jitterMs != null) {
      parts.add('Jitter ${quality!.jitterMs!.round()} ms');
    }
    if (quality?.packetLossPct != null) {
      parts.add('Loss ${quality!.packetLossPct!.toStringAsFixed(1)}%');
    }
    final qualityLabel = _callQualityLabel(entry);
    if (qualityLabel != null) {
      parts.insert(0, qualityLabel);
    }
    return parts.isEmpty ? 'No media metrics captured' : parts.join(' · ');
  }

  Widget _callDiagCard(BuildContext context, CallJournalEntry entry) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayPeerName(entry),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${callRecordResultLabel(entry.result, l10n: context.l10n, isRu: _isRu(context), direction: entry.direction, isVideo: entry.isVideoLike)} · ${_fmtMs(context, entry.endedAtMs)}',
            ),
            const SizedBox(height: 4),
            Text(_callEndReasonLabel(entry), style: subtitleStyle),
            const SizedBox(height: 4),
            Text(_callMetricsSummary(entry), style: subtitleStyle),
            const SizedBox(height: 6),
            Text(_callIssueSummary(entry), style: subtitleStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  label: Text('Duration ${_durationLabel(entry.durationMs)}'),
                ),
                if (entry.createdLocalEventId != null &&
                    entry.createdLocalEventId!.trim().isNotEmpty)
                  Chip(
                    label: Text('event ${entry.createdLocalEventId!.trim()}'),
                  ),
                if (entry.callAttemptId.trim().isNotEmpty)
                  Chip(label: Text('attempt ${entry.callAttemptId.trim()}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _messageDiagCard(BuildContext context, Map<String, Object?> row) {
    final localEventId = _stringField(row, 'local_event_id');
    final messageState = _stringField(row, 'message_state');
    final outboxSummary = _stringField(row, 'outbox_state_summary');
    final lastErrorCode = _stringField(row, 'last_error_code');
    final updatedAtMs = (row['updated_at_ms'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              localEventId,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text('message_state: ${messageState.isEmpty ? '—' : messageState}'),
            Text('outbox: ${outboxSummary.isEmpty ? '—' : outboxSummary}'),
            Text('last_error: ${lastErrorCode.isEmpty ? '—' : lastErrorCode}'),
            Text('updated: ${_fmtMs(context, updatedAtMs)}'),
          ],
        ),
      ),
    );
  }

  Widget _traceList(
    BuildContext context, {
    required String title,
    required List<Map<String, Object?>> rows,
    required String Function(Map<String, Object?> row) label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('—', style: Theme.of(context).textTheme.bodySmall)
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(
                label(row),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonal(
          onPressed: () async {
            await controller.forceOutboxPump();
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
            messenger.showSnackBar(
              SecretlySnackBar(
                content: Text(
                  _label(
                    context,
                    ru: 'Отправка очереди запущена',
                    en: 'Outbox pump triggered',
                  ),
                ),
              ),
            );
          },
          child: Text(
            _label(
              context,
              ru: 'Запустить отправку очереди',
              en: 'Force outbox pump',
            ),
          ),
        ),
        FilledButton.tonal(
          onPressed: () async {
            final recovered = await controller
                .recoverStuckOutgoingForDiagnostics();
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
            messenger.showSnackBar(
              SecretlySnackBar(
                content: Text(
                  _label(
                    context,
                    ru: 'Восстановлено зависших отправок: $recovered',
                    en: 'Recovered stuck sends: $recovered',
                  ),
                ),
              ),
            );
          },
          child: Text(
            _label(
              context,
              ru: 'Починить зависшие отправки',
              en: 'Recover stuck sends',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyDiagnosticsReport(
    BuildContext context,
    _DiagnosticsData? data,
  ) async {
    final report = _buildDiagnosticsReport(context, data);
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SecretlySnackBar(
        content: Text(
          _label(
            context,
            ru: 'Отчёт диагностики скопирован',
            en: 'Diagnostics report copied',
          ),
        ),
      ),
    );
  }

  String _buildDiagnosticsReport(BuildContext context, _DiagnosticsData? data) {
    final saved = controller.savedServerBinding;
    final current = controller.currentServerBinding;
    final messageData = data?.message;
    final callData = data?.calls;
    final counts = messageData?.outboxCounts ?? const <String, int>{};
    final push = controller.pushRegistrationDiagnostics;
    final relayAck = controller.relayAckDiagnostics;
    final receiptFlush = controller.receiptFlushDiagnostics;
    final buffer = StringBuffer()
      ..writeln('Secretly diagnostics')
      ..writeln('generated_at: ${DateTime.now().toLocal().toIso8601String()}')
      ..writeln('profile_id: ${controller.profileId}')
      ..writeln('device_id: ${controller.deviceId}')
      ..writeln('keys: ${controller.keysBaseUrl}')
      ..writeln('relay_http: ${controller.relayHttpBaseUrl}')
      ..writeln('relay_ws: ${controller.relayWsUrl}')
      ..writeln('build_marker: ${controller.buildMarker}')
      // Runtime proof of a compile-time flag. `bool.fromEnvironment` only
      // substitutes in a CONST context — a mistake that silently ships the
      // DEFAULT and cost this project three builds (401/402/403). Reading it
      // back from the running app is the only way to know which behaviour is
      // actually installed.
      // Split deliberately (2026-07-31): SEND is the rollout flag, RECEIVE is
      // on by default. A field report of "room messages stopped" is answered by
      // these two lines — the ONE thing that mattered on 1.7.4+416 was that a
      // peer's send flag differed from ours while its receive was gated too.
      ..writeln('room_sender_key_send: ${AppController.roomSenderKeySendEnabled}')
      ..writeln(
        'room_sender_key_receive: ${AppController.roomSenderKeyReceiveEnabled}',
      )
      ..writeln(
        'room_convergence: ${AppController.roomConvergenceBackstopEnabled}',
      )
      // Э-4 (docs/TZ_PREKEY_UNTIL_CONFIRMED_2026-08-01.md): the same rule as
      // the two lines above, for the same reason. This is a rollout flag —
      // turning it on changes what PEERS receive — so "which behaviour is
      // actually installed on this phone" has to be answerable without a
      // rebuild. Receive is ungated and always on, so there is nothing to
      // report for it: a build that can read a repeat always reads one.
      ..writeln('prekey_until_confirmed_send: $kPrekeyUntilConfirmedSend')
      // 🔴 ЗАМЕР ЗАПУСКА (03.08.2026). Жалоба «после часа простоя вход занимает
      // 12-15 секунд» была непроверяемой: приложение не измеряло собственный
      // старт вообще. Здесь фазы `init()` длиннее 20 мс и общий итог — чтобы
      // ответить «что именно держит», не снимая logcat.
      ..writeln('startup: ${controller.startupTrace}')
      ..writeln(data?.roomKeys ?? 'room_keys: (loading)')
      ..writeln(
        'server_binding_saved: ${(saved != null && saved.isNotEmpty) ? saved : '—'}',
      )
      ..writeln('server_binding_current: $current')
      ..writeln('keys_online: ${controller.keysOnline}')
      ..writeln('relay_online: ${controller.relayOnline}')
      ..writeln(
        'relay_ws: ${controller.relayWsLifecycleSummary.isEmpty ? 'соединение ни разу не поднималось' : controller.relayWsLifecycleSummary}',
      )
      ..writeln('push_status: ${push.statusCode}')
      ..writeln(
        'push_platform: ${push.platform.isEmpty ? 'unknown' : push.platform}',
      )
      ..writeln('push_current_token_present: ${push.currentTokenPresent}')
      ..writeln('push_runtime_token_present: ${push.runtimeTokenPresent}')
      ..writeln(
        'push_last_sync_attempt: ${_fmtMs(context, push.lastSyncAttemptAtMs)}',
      )
      ..writeln(
        'push_last_sync_success: ${_fmtMs(context, push.lastSyncSuccessAtMs)}',
      )
      ..writeln('pending: ${counts['pending'] ?? 0}')
      ..writeln('sending: ${counts['sending'] ?? 0}')
      ..writeln('retry: ${counts['retry'] ?? 0}')
      ..writeln('failed: ${counts['failed'] ?? 0}')
      ..writeln('pending_receipts: ${messageData?.pendingReceiptCount ?? 0}')
      // Замер, гатящий слой 2 номера безопасности: сколько раз человеку
      // показали «номер изменился». Порог из ТЗ — единицы против десятков.
      ..writeln(messageData?.safetyNumberNotices ?? 'safety_number_notices: —')
      // `failed` не уйдёт никогда — но содержимое могло уехать другим
      // конвертом. Один счётчик этого не различает, разбор различает.
      ..writeln(messageData?.outboxFailedSummary ?? 'outbox_failed: —')
      // Гейт Ш-3: без этой доли включать решение по сертификату нельзя.
      ..writeln(messageData?.accountIdentityReadiness ?? 'account_identity: —')
      // Без этого разрешения экран звонка НЕ поднимется из фона на Android 14+,
      // и вырождение происходит молча.
      ..writeln(messageData?.fullScreenIntent ?? 'full_screen_intent: —')
      // Шаг ② плана из docs/AUDIT_SESSION_RESET_SURFACE_2026-08-23.md: сколько
      // сбросов сессии заказано за запуск и КЕМ. Решение сокращать поверхность
      // принимается по этой строке, а не по здравому смыслу: часть точек
      // закрывает реальные июльские шрамы, и убирать их вслепую нельзя.
      ..writeln(
        'session_resets: ${_formatResetCauses(controller.sessionResetCauseCounts)}',
      )
      ..writeln('receipt_flush_failures: ${receiptFlush['failure_count'] ?? 0}')
      // 🔴 Одного счётчика мало: «5 отказов» без текста ошибки не отличить от
      // «5 обрывов сети», и разбираться приходится наугад. Текст уже собирался
      // рядом и просто не выводился.
      ..writeln(
        'relay_ack_failures: ${relayAck['failure_count'] ?? 0}'
        '${((relayAck['last_failure'] as String?) ?? '').trim().isEmpty ? '' : ' · последняя: ${relayAck['last_failure']}'}',
      );

    final messages =
        messageData?.actionableSnapshots ?? const <Map<String, Object?>>[];
    if (messages.isNotEmpty) {
      buffer.writeln('\nactionable_messages:');
      for (final row in messages) {
        buffer.writeln(
          '- ${_stringField(row, 'local_event_id')} state=${_stringField(row, 'message_state')} outbox=${_stringField(row, 'outbox_state_summary')} error=${_stringField(row, 'last_error_code')} updated=${_fmtMs(context, (row['updated_at_ms'] as num?)?.toInt() ?? 0)}',
        );
      }
    }

    final calls = callData?.actionableEntries ?? const <CallJournalEntry>[];
    if (calls.isNotEmpty) {
      buffer.writeln('\nactionable_calls:');
      for (final entry in calls) {
        buffer.writeln(
          '- ${_displayPeerName(entry)} result=${entry.result.name} ended=${_fmtMs(context, entry.endedAtMs)} reason=${_callEndReasonLabel(entry)} metrics=${_callMetricsSummary(entry)}',
        );
      }
    }

    final journal = data?.identityJournal;
    if (journal != null && journal.isNotEmpty) {
      buffer.writeln('\n$journal');
    }

    final keychainScope = data?.keychainScope;
    if (keychainScope != null && keychainScope.isNotEmpty) {
      buffer.writeln('\n$keychainScope');
    }

    // Расхождение часов закрывает человеку отправку целиком: подписанные
    // запросы к серверу ключей перестают приниматься. Пусть будет видно.
    buffer.writeln(ServerClock.instance.describe());
    return buffer.toString().trimRight();
  }

  Widget _diagnosticsIntroCard(BuildContext context, _DiagnosticsData? data) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return GestureDetector(
      onLongPress: () => _unlockDeveloperActions(context),
      child: Card(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(
                            context,
                            ru: 'Для поддержки',
                            en: 'For support',
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _label(
                            context,
                            ru: 'Это технический экран диагностики. Коды, очереди и предупреждения ниже не означают, что аккаунт сломан. Если нужна помощь, скопируйте отчёт целиком и отправьте его в поддержку.',
                            en: 'This is a technical diagnostics screen. Codes, queues, and warnings below do not necessarily mean the account is broken. If you need help, copy the full report and send it to support.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _copyDiagnosticsReport(context, data),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: Text(
                    _label(context, ru: 'Скопировать отчёт', en: 'Copy report'),
                  ),
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
    final l10n = context.l10n;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.diagnostics)),
      body: StreamBuilder<void>(
        stream: controller.changed,
        builder: (context, _) {
          final saved = controller.savedServerBinding;
          final current = controller.currentServerBinding;

          return FutureBuilder<_DiagnosticsData>(
            future: _loadDiagnostics(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final messageData = data?.message;
              final callData = data?.calls;
              final counts = messageData?.outboxCounts ?? const <String, int>{};
              final actionable =
                  messageData?.actionableSnapshots ??
                  const <Map<String, Object?>>[];
              final pushDiagnostics = controller.pushRegistrationDiagnostics;
              final relayAckDiagnostics = controller.relayAckDiagnostics;
              final receiptFlushDiagnostics =
                  controller.receiptFlushDiagnostics;
              final actionableCalls =
                  callData?.actionableEntries ?? const <CallJournalEntry>[];
              final recentCalls =
                  callData?.recentEntries ?? const <CallJournalEntry>[];
              final failedCalls = recentCalls
                  .where((entry) => entry.result == CallRecordResult.failed)
                  .length;
              final timeoutCalls = recentCalls
                  .where(
                    (entry) => entry.endReasonValue == CallEndReason.timeout,
                  )
                  .length;
              final degradedCalls = recentCalls.where((entry) {
                final level = (_qualitySummary(entry)?.qualityLevel ?? '')
                    .trim()
                    .toLowerCase();
                return level == 'poor' || level == 'fair';
              }).length;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 16,
                  16,
                  16,
                ),
                children: [
                  _diagnosticsIntroCard(context, data),
                  const SizedBox(height: 16),

                  // Debug-only paywall preview (for store screenshots). Compiled
                  // out of release builds via kDebugMode — never user-visible.
                  if (kDebugMode) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in PaywallTrigger.values)
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PaywallScreen(trigger: t),
                              ),
                            ),
                            child: Text('Paywall: ${t.name}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  _sectionTitle(context, l10n.diagIdentity),
                  const SizedBox(height: 8),
                  _kv('profile_id', controller.profileId),
                  _kv('device_id', controller.deviceId),
                  const SizedBox(height: 16),

                  _sectionTitle(context, l10n.diagEndpoints),
                  const SizedBox(height: 8),
                  _kv('keys', controller.keysBaseUrl.toString()),
                  _kv('relay_http', controller.relayHttpBaseUrl.toString()),
                  _kv('relay_ws', controller.relayWsUrl.toString()),
                  _kv('build_marker', controller.buildMarker),
                  _kv(
                    'client_protocol_version',
                    controller.clientProtocolVersion.toString(),
                  ),
                  if (controller.keysHealthStatus != null) ...[
                    _kv(
                      'keys_protocol_window',
                      '${controller.keysHealthStatus!.protocolWindowLabel} (server=${controller.keysHealthStatus!.serverProtocolVersion})',
                    ),
                    if (_healthReleaseLabel(controller.keysHealthStatus!) !=
                        null)
                      _kv(
                        'keys_release',
                        _healthReleaseLabel(controller.keysHealthStatus!)!,
                      ),
                    if (controller.keysHealthStatus!.serviceStartedAtMs != null)
                      _kv(
                        'keys_started_at',
                        _fmtMs(
                          context,
                          controller.keysHealthStatus!.serviceStartedAtMs!,
                        ),
                      ),
                    _kv(
                      'keys_compatibility',
                      _healthCompatibilityLabel(controller.keysHealthStatus!),
                    ),
                    if (controller.keysHealthStatus!.compatibilityMessage !=
                            null &&
                        controller.keysHealthStatus!.compatibilityMessage!
                            .trim()
                            .isNotEmpty)
                      _kv(
                        'keys_compatibility_message',
                        controller.keysHealthStatus!.compatibilityMessage!,
                      ),
                  ],
                  if (controller.relayHealthStatus != null) ...[
                    _kv(
                      'relay_protocol_window',
                      '${controller.relayHealthStatus!.protocolWindowLabel} (server=${controller.relayHealthStatus!.serverProtocolVersion})',
                    ),
                    if (_healthReleaseLabel(controller.relayHealthStatus!) !=
                        null)
                      _kv(
                        'relay_release',
                        _healthReleaseLabel(controller.relayHealthStatus!)!,
                      ),
                    if (controller.relayHealthStatus!.serviceStartedAtMs !=
                        null)
                      _kv(
                        'relay_started_at',
                        _fmtMs(
                          context,
                          controller.relayHealthStatus!.serviceStartedAtMs!,
                        ),
                      ),
                    _kv(
                      'relay_compatibility',
                      _healthCompatibilityLabel(controller.relayHealthStatus!),
                    ),
                    if (controller.relayHealthStatus!.compatibilityMessage !=
                            null &&
                        controller.relayHealthStatus!.compatibilityMessage!
                            .trim()
                            .isNotEmpty)
                      _kv(
                        'relay_compatibility_message',
                        controller.relayHealthStatus!.compatibilityMessage!,
                      ),
                  ],
                  const SizedBox(height: 16),

                  _sectionTitle(context, l10n.diagServerBinding),
                  const SizedBox(height: 8),
                  _kv(
                    'saved',
                    (saved != null && saved.isNotEmpty) ? saved : '—',
                  ),
                  _kv('current', current),
                  if (controller.serverBindingMismatch) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.diagMismatch,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  _sectionTitle(context, l10n.diagStatus),
                  const SizedBox(height: 8),
                  _kv('keys_online', controller.keysOnline ? 'true' : 'false'),
                  _kv(
                    'relay_online',
                    controller.relayOnline ? 'true' : 'false',
                  ),
                  if (controller.startupWarning != null &&
                      controller.startupWarning!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _kv('startup_warning', controller.startupWarning!),
                  ],
                  const SizedBox(height: 16),

                  _sectionTitle(context, 'push_registration'),
                  const SizedBox(height: 8),
                  _kv('push_status', pushDiagnostics.statusCode),
                  _kv(
                    'push_platform',
                    pushDiagnostics.platform.isEmpty
                        ? 'unknown'
                        : pushDiagnostics.platform,
                  ),
                  _kv(
                    'push_firebase_ready',
                    pushDiagnostics.firebaseReady ? 'true' : 'false',
                  ),
                  _kv(
                    'push_native_diagnostics_available',
                    pushDiagnostics.nativePushDiagnosticsAvailable
                        ? 'true'
                        : 'false',
                  ),
                  _kv(
                    'push_current_token_present',
                    pushDiagnostics.currentTokenPresent ? 'true' : 'false',
                  ),
                  _kv(
                    'push_runtime_token_present',
                    pushDiagnostics.runtimeTokenPresent ? 'true' : 'false',
                  ),
                  _kv(
                    'push_last_synced_token_present',
                    pushDiagnostics.lastSyncedTokenPresent ? 'true' : 'false',
                  ),
                  _kv(
                    'push_sync_in_flight',
                    pushDiagnostics.syncInFlight ? 'true' : 'false',
                  ),
                  _kv(
                    'push_firebase_init_at',
                    _fmtMs(context, pushDiagnostics.lastFirebaseInitAtMs),
                  ),
                  if (pushDiagnostics.platform == 'ios')
                    _kv(
                      'push_apns_registration_requested_at',
                      _fmtMs(
                        context,
                        pushDiagnostics.lastApnsRegisterRequestedAtMs,
                      ),
                    ),
                  if (pushDiagnostics.platform == 'ios')
                    _kv(
                      'push_apns_token_at',
                      _fmtMs(context, pushDiagnostics.lastApnsTokenAtMs),
                    ),
                  _kv(
                    'push_permission_checked_at',
                    _fmtMs(context, pushDiagnostics.lastPermissionAtMs),
                  ),
                  _kv(
                    'push_token_fetched_at',
                    _fmtMs(context, pushDiagnostics.lastTokenFetchAtMs),
                  ),
                  _kv(
                    'push_last_sync_attempt',
                    _fmtMs(context, pushDiagnostics.lastSyncAttemptAtMs),
                  ),
                  _kv(
                    'push_last_sync_success',
                    _fmtMs(context, pushDiagnostics.lastSyncSuccessAtMs),
                  ),
                  if (pushDiagnostics.permissionStatus != null &&
                      pushDiagnostics.permissionStatus!.trim().isNotEmpty)
                    _kv(
                      'push_permission_status',
                      pushDiagnostics.permissionStatus!,
                    ),
                  if (pushDiagnostics.platform == 'ios' &&
                      pushDiagnostics.iosFirebaseConfigured != null)
                    _kv(
                      'push_ios_firebase_configured',
                      pushDiagnostics.iosFirebaseConfigured! ? 'true' : 'false',
                    ),
                  if (pushDiagnostics.platform == 'ios' &&
                      pushDiagnostics.apnsTokenPresent != null)
                    _kv(
                      'push_apns_token_present',
                      pushDiagnostics.apnsTokenPresent! ? 'true' : 'false',
                    ),
                  if (pushDiagnostics.firebaseInitError != null &&
                      pushDiagnostics.firebaseInitError!.trim().isNotEmpty)
                    _kv(
                      'push_firebase_init_error',
                      pushDiagnostics.firebaseInitError!,
                    ),
                  if (pushDiagnostics.permissionError != null &&
                      pushDiagnostics.permissionError!.trim().isNotEmpty)
                    _kv(
                      'push_permission_error',
                      pushDiagnostics.permissionError!,
                    ),
                  if (pushDiagnostics.lastTokenFetchError != null &&
                      pushDiagnostics.lastTokenFetchError!.trim().isNotEmpty)
                    _kv(
                      'push_token_fetch_error',
                      pushDiagnostics.lastTokenFetchError!,
                    ),
                  if (pushDiagnostics.lastApnsRegisterError != null &&
                      pushDiagnostics.lastApnsRegisterError!.trim().isNotEmpty)
                    _kv(
                      'push_apns_register_error',
                      pushDiagnostics.lastApnsRegisterError!,
                    ),
                  if (pushDiagnostics.nativePushDiagnosticsError != null &&
                      pushDiagnostics.nativePushDiagnosticsError!
                          .trim()
                          .isNotEmpty)
                    _kv(
                      'push_native_diagnostics_error',
                      pushDiagnostics.nativePushDiagnosticsError!,
                    ),
                  if (pushDiagnostics.lastSyncError != null &&
                      pushDiagnostics.lastSyncError!.trim().isNotEmpty)
                    _kv('push_last_sync_error', pushDiagnostics.lastSyncError!),
                  const SizedBox(height: 16),

                  if (_developerActionsVisible) ...[
                    _sectionTitle(context, 'message_actions'),
                    const SizedBox(height: 8),
                    _actionButtons(context),
                    const SizedBox(height: 16),
                  ],

                  _sectionTitle(context, 'message_queue'),
                  const SizedBox(height: 8),
                  _kv('pending', (counts['pending'] ?? 0).toString()),
                  _kv('sending', (counts['sending'] ?? 0).toString()),
                  _kv('retry', (counts['retry'] ?? 0).toString()),
                  _kv('sent', (counts['sent'] ?? 0).toString()),
                  _kv('failed', (counts['failed'] ?? 0).toString()),
                  _kv(
                    'pending_receipts',
                    (messageData?.pendingReceiptCount ?? 0).toString(),
                  ),
                  _kv(
                    'receipt_flush_in_flight',
                    '${receiptFlushDiagnostics['in_flight'] ?? false}',
                  ),
                  _kv(
                    'receipt_flush_queued',
                    '${receiptFlushDiagnostics['queued'] ?? false}',
                  ),
                  _kv(
                    'receipt_flush_failures',
                    '${receiptFlushDiagnostics['failure_count'] ?? 0}',
                  ),
                  _kv(
                    'receipt_flush_last_failure_at',
                    _fmtMs(
                      context,
                      (receiptFlushDiagnostics['last_failure_at_ms'] as num?)
                              ?.toInt() ??
                          0,
                    ),
                  ),
                  if ('${receiptFlushDiagnostics['last_failure'] ?? ''}'
                      .trim()
                      .isNotEmpty)
                    _kv(
                      'receipt_flush_last_failure',
                      '${receiptFlushDiagnostics['last_failure']}'.trim(),
                    ),
                  _kv(
                    'relay_ack_failures',
                    '${relayAckDiagnostics['failure_count'] ?? 0}',
                  ),
                  _kv(
                    'relay_ack_last_failure_at',
                    _fmtMs(
                      context,
                      (relayAckDiagnostics['last_failure_at_ms'] as num?)
                              ?.toInt() ??
                          0,
                    ),
                  ),
                  if ('${relayAckDiagnostics['last_failure'] ?? ''}'
                      .trim()
                      .isNotEmpty)
                    _kv(
                      'relay_ack_last_failure',
                      '${relayAckDiagnostics['last_failure']}'.trim(),
                    ),
                  const SizedBox(height: 16),

                  _sectionTitle(context, 'actionable_message_diagnostics'),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (actionable.isEmpty)
                    Text('—', style: Theme.of(context).textTheme.bodySmall)
                  else
                    ...actionable.map((row) => _messageDiagCard(context, row)),
                  const SizedBox(height: 16),

                  _sectionTitle(context, 'call_diagnostics'),
                  const SizedBox(height: 8),
                  _kv('recent_calls', recentCalls.length.toString()),
                  _kv('failed_calls', failedCalls.toString()),
                  _kv('timeout_calls', timeoutCalls.toString()),
                  _kv('degraded_quality', degradedCalls.toString()),
                  const SizedBox(height: 16),

                  _sectionTitle(context, 'actionable_call_diagnostics'),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (actionableCalls.isEmpty)
                    Text('—', style: Theme.of(context).textTheme.bodySmall)
                  else
                    ...actionableCalls.map(
                      (entry) => _callDiagCard(context, entry),
                    ),
                  const SizedBox(height: 16),

                  _traceList(
                    context,
                    title: 'message_state_trace',
                    rows:
                        messageData?.traceStateLog ??
                        const <Map<String, Object?>>[],
                    label: (row) =>
                        '${_fmtMs(context, (row['created_at_ms'] as num?)?.toInt() ?? 0)}  ${_stringField(row, 'previous_state')} -> ${_stringField(row, 'new_state')}  reason=${_stringField(row, 'reason_code').isEmpty ? '—' : _stringField(row, 'reason_code')}',
                  ),
                  const SizedBox(height: 16),

                  _traceList(
                    context,
                    title: 'message_attempt_trace',
                    rows:
                        messageData?.traceAttemptLog ??
                        const <Map<String, Object?>>[],
                    label: (row) =>
                        '${_fmtMs(context, (row['started_at_ms'] as num?)?.toInt() ?? 0)}  transport=${_stringField(row, 'transport').isEmpty ? '—' : _stringField(row, 'transport')}  result=${_stringField(row, 'result').isEmpty ? '—' : _stringField(row, 'result')}  error=${_stringField(row, 'error_code').isEmpty ? '—' : _stringField(row, 'error_code')}',
                  ),
                  const SizedBox(height: 16),

                  // PR7: peer-to-device history sync metrics. All counters
                  // reset on process restart; durable «last sync at»
                  // timestamp is read from PeerHistoryService.
                  _sectionTitle(context, 'peer_history_sync'),
                  const SizedBox(height: 8),
                  _kv(
                    'backfilled_events_controller',
                    controller.peerHistoryBackfilledCount.toString(),
                  ),
                  _kv(
                    'groups_hydrated',
                    controller.peerHistoryGroupsHydrated.toString(),
                  ),
                  _kv(
                    'last_chunk_at',
                    _fmtMs(context, controller.peerHistoryLastChunkAtMs),
                  ),
                  _kv(
                    'service_backfilled_events',
                    PeerHistoryService.instance.backfilledCount.toString(),
                  ),
                  _kv(
                    'service_requests_completed',
                    PeerHistoryService.instance.requestsCompleted.toString(),
                  ),
                  _kv(
                    'service_requests_rejected',
                    PeerHistoryService.instance.requestsRejected.toString(),
                  ),
                  _kv(
                    'service_last_run_at',
                    _fmtMs(context, PeerHistoryService.instance.lastRunAtMs),
                  ),
                  const SizedBox(height: 16),

                  _sectionTitle(context, l10n.diagTimestamps),
                  const SizedBox(height: 8),
                  _kv(
                    'last_keys_publish',
                    _fmtMs(context, controller.lastKeysPublishAtMs),
                  ),
                  _kv(
                    'last_meta_publish',
                    _fmtMs(context, controller.lastMetaPublishAtMs),
                  ),
                  _kv(
                    'last_meta_refresh',
                    _fmtMs(context, controller.lastMetaRefreshAtMs),
                  ),
                  const SizedBox(height: 16),

                  _sectionTitle(context, l10n.diagTips),
                  const SizedBox(height: 8),
                  Text(l10n.diagTipsBody),
                  const SizedBox(height: 24),

                  // 🔴 ПУТЬ НАЗАД (16.08.2026). Раздел открывается пятью
                  // нажатиями по строке версии, и без этой кнопки открывший
                  // случайно не смог бы вернуть как было: жест умеет только
                  // включать. Односторонняя настройка — это ловушка.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await DiagnosticsUnlock.setUnlocked(false);
                        navigator.pop();
                      },
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: Text(
                        settingsScreenLabel(
                          context,
                          ru: 'Скрыть диагностику',
                          en: 'Hide diagnostics',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settingsScreenLabel(
                      context,
                      ru: 'Снова открыть: пять нажатий по строке версии внизу '
                          'настроек.',
                      en: 'To show it again: tap the version line at the '
                          'bottom of Settings five times.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(fontFamily: 'monospace')),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

/// «peer_nack=3 · decrypt_failed=1» либо «нет» — компактно, по убыванию.
String _formatResetCauses(Map<String, int> counts) {
  if (counts.isEmpty) return 'нет';
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => '${e.key}=${e.value}').join(' · ');
}
