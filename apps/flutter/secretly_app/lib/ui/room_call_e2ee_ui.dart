// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Интерфейс сквозного шифрования групповых созвонов (ТЗ E2EE созвонов, §8).
///
/// Пока у устройства доля зашифрованных созвонов 0, отсюда не показывается
/// ничего: ни окон перед входом, ни знаков — выпущенный интерфейс созвона
/// остаётся прежним. Значок шифрования появляется только в зашифрованном
/// созвоне.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rooms/call_e2ee/call_e2ee_protocol.dart';
import '../rooms/call_e2ee/room_call_e2ee_status.dart';
import '../rooms/call_e2ee/room_call_join_plan.dart';
import '../rooms/room_call_media_controller.dart';

/// С чем входить в созвон и написать ли в чат «обновитесь».
class RoomCallJoinDecision {
  const RoomCallJoinDecision({
    required this.contract,
    this.notifyMembers = false,
  });

  final String contract;
  final bool notifyMembers;
}

typedef RoomCallCreatorChoiceAsk =
    Future<({bool encrypted, bool notify})?> Function(String names);
typedef RoomCallOpenJoinAsk = Future<bool> Function();
typedef RoomCallBlockedNotice = void Function(String message);

/// Решение перед входом в созвон комнаты. Окна — у вызывающего: у телефона
/// свои, у ПК свои; логика одна. `null` — не входить.
Future<RoomCallJoinDecision?> decideRoomCallJoin({
  required Future<RoomCallJoinPlan> Function() loadPlan,
  required Future<String?> Function(String profileId) displayName,
  required AppLocalizations l10n,
  required RoomCallCreatorChoiceAsk askCreatorChoice,
  required RoomCallOpenJoinAsk askOpenJoin,
  required RoomCallBlockedNotice notifyBlocked,
}) async {
  final plan = await loadPlan();
  switch (plan.block) {
    case RoomCallJoinBlock.platformUnsupported:
      notifyBlocked(l10n.roomCallE2eeUnsupported);
      return null;
    case RoomCallJoinBlock.e2eeRequired:
      notifyBlocked(l10n.roomCallOpenBanner);
      return null;
    case RoomCallJoinBlock.groupCallsDisabled:
      notifyBlocked(l10n.roomCallE2eeUnsupported);
      return null;
    case null:
      break;
  }
  if (plan.needsOpenJoinConsent) {
    final ok = await askOpenJoin();
    return ok
        ? const RoomCallJoinDecision(contract: kRoomMediaContractV1)
        : null;
  }
  if (plan.needsCreatorChoice && plan.offerOpenAlternative) {
    final names = await _memberNames(displayName, plan.membersWithoutE2ee);
    final choice = await askCreatorChoice(names);
    if (choice == null) return null;
    return RoomCallJoinDecision(
      contract: choice.encrypted
          ? kRoomMediaContractE2eeV1
          : kRoomMediaContractV1,
      notifyMembers: choice.encrypted && choice.notify,
    );
  }
  return RoomCallJoinDecision(contract: plan.contract);
}

Future<String> _memberNames(
  Future<String?> Function(String profileId) displayName,
  List<String> profileIds,
) async {
  const shown = 5;
  final names = <String>[];
  for (final id in profileIds.take(shown)) {
    String? name;
    try {
      name = await displayName(id);
    } catch (_) {
      name = null;
    }
    final clean = (name ?? '').trim();
    names.add(
      clean.isNotEmpty ? clean : id.substring(0, id.length.clamp(0, 8)),
    );
  }
  final rest = profileIds.length - names.length;
  return rest > 0 ? '${names.join(', ')} +$rest' : names.join(', ');
}

// ── Окна телефона ─────────────────────────────────────────────────────────

/// Окно у создателя (§8.3): начать зашифрованный или открытый созвон.
Future<({bool encrypted, bool notify})?> showRoomCallCreatorChoiceDialog(
  BuildContext context,
  String names,
) {
  final l10n = AppLocalizations.of(context)!;
  var notify = true;
  return showDialog<({bool encrypted, bool notify})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.roomCallStartChoiceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.roomCallStartChoiceBody(names)),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: notify,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.roomCallStartChoiceNotify),
              onChanged: (v) => setState(() => notify = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop((encrypted: false, notify: false)),
            child: Text(l10n.roomCallStartOpen),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop((encrypted: true, notify: notify)),
            child: Text(l10n.roomCallStartEncrypted),
          ),
        ],
      ),
    ),
  );
}

/// Окно перед входом в открытый созвон, пока идёт раскатка шифрования.
Future<bool> showRoomCallOpenJoinDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.roomCallJoinOpenTitle),
      content: Text(l10n.roomCallJoinOpenBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.roomCallJoinOpenAction),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ── Знак шифрования в шапке ──────────────────────────────────────────────

/// Знак шифрования созвона на телефоне.
///
/// 🔴 ОТДЕЛЬНОЙ СТРОКИ БОЛЬШЕ НЕТ (06.10.2026, по просьбе владельца). Плашка
/// под шапкой занимала целую строку экрана ради одной мысли. Теперь это
/// значок во второй строке шапки рядом с таймером, а полный текст
/// открывается нажатием на шапку ([showRoomCallE2eeDetails]). Словами в
/// шапке говорит только отказ: при нём нас никто не слышит.
///
/// - Зашифрованный созвон: зелёный замок; жёлтый — если в созвоне есть
///   неизвестные участники, которых не слышно; серый — пока подключаемся;
///   красный — отказ.
/// - Открытый созвон: красный открытый замок (`showOpenWarning`) — в любом
///   открытом созвоне, с 14.11.2026 и без раскатки.
class RoomCallE2eeMark {
  const RoomCallE2eeMark({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    this.alert = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  /// Отказ: шапка называет его словами, а не одним значком.
  final bool alert;
}

const _kMarkGreen = Color(0xFF30A46C);
const _kMarkAmber = Color(0xFFFFB84D);
const _kMarkGrey = Color(0xFF8E8E93);
const _kMarkRed = Color(0xFFE5484D);

RoomCallE2eeMark? roomCallE2eeMark(
  RoomCallE2eeStatus? status, {
  required bool showOpenWarning,
  required AppLocalizations l10n,
}) {
  if (status == null) {
    return showOpenWarning
        ? RoomCallE2eeMark(
            icon: Icons.lock_open_rounded,
            color: _kMarkRed,
            title: l10n.roomCallOpenBanner,
          )
        : null;
  }
  final unknown = status.unknownParticipants > 0
      ? l10n.roomCallE2eeUnknownParticipants(status.unknownParticipants)
      : null;
  return switch (status.own) {
    RoomCallE2eeOwnState.encrypting => RoomCallE2eeMark(
      icon: Icons.lock_rounded,
      color: unknown == null ? _kMarkGreen : _kMarkAmber,
      title: l10n.roomCallE2eeOn,
      detail: unknown ?? l10n.roomCallE2eeOnHint,
    ),
    RoomCallE2eeOwnState.connecting => RoomCallE2eeMark(
      icon: Icons.lock_clock_rounded,
      color: _kMarkGrey,
      title: l10n.roomCallE2eeConnecting,
      detail: unknown,
    ),
    RoomCallE2eeOwnState.failed => RoomCallE2eeMark(
      icon: Icons.no_encryption_gmailerrorred_rounded,
      color: _kMarkRed,
      title: status.errorCode == 'platform_unsupported'
          ? l10n.roomCallE2eeUnsupported
          : l10n.roomCallE2eeFailed,
      alert: true,
    ),
  };
}

/// Строит шапку по текущему знаку и перестраивает её при смене состояния.
class RoomCallE2eeMarkBuilder extends StatelessWidget {
  const RoomCallE2eeMarkBuilder({
    super.key,
    required this.mediaController,
    required this.showOpenWarning,
    required this.builder,
  });

  final RoomCallMediaController? mediaController;
  final bool showOpenWarning;
  final Widget Function(BuildContext context, RoomCallE2eeMark? mark) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final source = mediaController;
    if (source is! RoomCallE2eeStatusSource) {
      return builder(
        context,
        roomCallE2eeMark(null, showOpenWarning: showOpenWarning, l10n: l10n),
      );
    }
    return ValueListenableBuilder<RoomCallE2eeStatus?>(
      valueListenable: (source as RoomCallE2eeStatusSource).e2eeStatus,
      builder: (context, status, _) => builder(
        context,
        roomCallE2eeMark(status, showOpenWarning: showOpenWarning, l10n: l10n),
      ),
    );
  }
}

/// Полный текст знака — по нажатию на шапку созвона.
Future<void> showRoomCallE2eeDetails(
  BuildContext context,
  RoomCallE2eeMark mark,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(mark.icon, size: 22, color: mark.color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mark.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (mark.detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      mark.detail!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Подпись на плитке собеседника в зашифрованном созвоне: «Ждём ключ» или
/// «Не удаётся расшифровать». `null` — нечего сказать.
String? roomCallE2eePeerCaption(
  RoomCallE2eeStatus? status,
  String deviceId,
  AppLocalizations l10n,
) {
  if (status == null) return null;
  return switch (status.peersByDeviceId[deviceId.trim()]) {
    RoomCallE2eePeerState.waitingKey => l10n.roomCallE2eeWaitingKey,
    RoomCallE2eePeerState.failing => l10n.roomCallE2eeFailing,
    _ => null,
  };
}
