// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart';

import '../../../../app/app_controller.dart';

/// Чем кончилась попытка получить ссылку-приглашение.
class RoomInviteShareResult {
  const RoomInviteShareResult._(this.url, this.error);

  /// Ссылка готова и уже лежит в буфере обмена.
  const RoomInviteShareResult.copied(String url) : this._(url, null);

  /// Комната отказала — текст уже человеческий.
  const RoomInviteShareResult.failed(String error) : this._(null, error);

  final String? url;
  final String? error;

  bool get ok => url != null;
}

/// Взять годную ссылку-приглашение (или завести новую) и положить в буфер.
///
/// 🔴 ОДНА РЕАЛИЗАЦИЯ НА ВСЕ ТОЧКИ ВХОДА.
///
/// Приглашение живёт в двух местах: в панели подробностей комнаты и — по
/// макету — в окне созвона, где оно нужнее всего («позови ещё кого-нибудь,
/// пока говорим»). Порядок действий здесь неочевидный и легко разъезжается:
/// сначала ищем УЖЕ ГОДНУЮ ссылку (не отозванную, не просроченную, не
/// исчерпавшую число использований) и только потом заводим новую — иначе
/// каждое нажатие плодило бы ссылку, а их количество у комнаты ограничено
/// правилами.
///
/// Важно и второе: новая ссылка наследует `joinApprovalRequired` комнаты. Не
/// унаследовать его значит тихо открыть комнату, которую владелец закрыл на
/// подтверждение.
Future<RoomInviteShareResult> copyRoomInviteLink({
  required AppController controller,
  required String groupId,
  required bool requiresApproval,
  List<RoomInviteLink> known = const <RoomInviteLink>[],
  int? nowMs,
  String Function(Object error)? describeError,
}) async {
  var link = bestRoomInviteLink(known, nowMs: nowMs);
  if (link == null) {
    try {
      link = await controller.createRoomInviteLink(
        groupId,
        requiresApproval: requiresApproval,
      );
    } catch (e) {
      return RoomInviteShareResult.failed(
        describeError?.call(e) ?? e.toString(),
      );
    }
  }
  final url = buildRoomInviteShareLink(
    slug: link.slug,
    createdByProfileId: link.createdByProfileId,
    groupIdHint: link.groupId,
  );
  await Clipboard.setData(ClipboardData(text: url));
  return RoomInviteShareResult.copied(url);
}

/// Первая ссылка, которой ещё можно воспользоваться.
///
/// Отозванная, просроченная и исчерпавшая лимит использований — это три
/// РАЗНЫЕ причины непригодности, и пропустить любую значит дать человеку
/// ссылку, по которой никто не войдёт.
RoomInviteLink? bestRoomInviteLink(
  List<RoomInviteLink> links, {
  int? nowMs,
}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  for (final link in links) {
    if (link.revoked) continue;
    final exp = link.expiresAtMs;
    if (exp != null && exp > 0 && exp <= now) continue;
    final maxUses = link.maxUses;
    if (maxUses != null && maxUses > 0 && link.useCount >= maxUses) continue;
    return link;
  }
  return null;
}
