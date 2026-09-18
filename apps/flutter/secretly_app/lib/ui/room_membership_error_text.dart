// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

import '../rooms/room_membership_failure.dart';
import 'room_l10n_bridge.dart';

/// Человеческий текст отказа при действии с участником комнаты.
///
/// 🔴 ПОЧЕМУ ЭТО ОТДЕЛЬНЫЙ ФАЙЛ (13.09.2026). Текст жил приватной функцией
/// внутри мобильного `room_details_screen.dart`, и десктоп, получив управление
/// участниками, не мог его позвать. Написать рядом второй набор тех же фраз
/// значило бы завести второй перевод на восемь языков и второй тон: первая же
/// правка развела бы их, и человек на компьютере и на телефоне получал бы
/// разные объяснения одного и того же отказа.
///
/// Пара к [tryRoomPolicyErrorText] — тот отвечает за правила комнаты («писать
/// могут только админы»), этот за действия с участниками («владельца нельзя
/// удалить»).
///
/// Возвращает null, если ошибка не про участников: вызывающий идёт дальше по
/// своей цепочке разборщиков.
String? tryRoomMembershipErrorText(BuildContext context, Object error) {
  if (error is! RoomMembershipFailure) {
    return null;
  }
  switch (error.code) {
    case RoomMembershipFailureCode.ownerOnly:
      return roomText(
        context,
        ru: 'Только владелец комнаты может сделать это.',
        en: 'Only the room owner can do that.',
      );
    case RoomMembershipFailureCode.ownerTransferRequired:
      return roomText(
        context,
        ru: 'Сначала передайте владение комнатой другому активному участнику.',
        en: 'Transfer room ownership to another active member before leaving.',
      );
    case RoomMembershipFailureCode.ownerTransferTargetInvalid:
      return roomText(
        context,
        ru: 'Выберите активного участника как нового владельца комнаты.',
        en: 'Choose an active room member as the next owner.',
      );
    case RoomMembershipFailureCode.memberBanned:
      return roomText(
        context,
        ru: 'Этот участник заблокирован. Сначала снимите бан, затем можно снова добавить его.',
        en: 'This member is banned. Unban them before allowing them back.',
      );
    case RoomMembershipFailureCode.cannotRemoveOwner:
      return roomText(
        context,
        ru: 'Владельца комнаты нельзя удалить.',
        en: 'The room owner cannot be removed.',
      );
    case RoomMembershipFailureCode.cannotBanOwner:
      return roomText(
        context,
        ru: 'Владельца комнаты нельзя заблокировать.',
        en: 'The room owner cannot be banned.',
      );
    case RoomMembershipFailureCode.generic:
      return roomText(
        context,
        ru: 'Сейчас это действие с участником комнаты недоступно.',
        en: 'This room membership action is unavailable right now.',
      );
  }
}
