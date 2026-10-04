// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПРЕДЕЛ КОМНАТ — ОКНОМ ПК, А НЕ ТЕЛЕФОННОЙ ВИТРИНОЙ.
///
/// 🔴 (30.09.2026) Экраны создания комнаты и входа по приглашению на ПК —
/// телефонные (см. `showDesktopScreenWindow`). Упёршись в предел бесплатного
/// тарифа, они открывали внутри окна ПК телефонную страницу покупки, которой
/// на ПК не воспользоваться: подписка оформляется в приложении на телефоне.
///
/// Теперь ПК проверяет предел ЗАРАНЕЕ — тем же правилом и из того же
/// источника, что и телефон (`canCreateGroupNow` / `canJoinGroupNow`), — и
/// объясняет его своим окном. Само правило не меняется: `createGroup` и
/// `joinRoomViaInvite` остаются последней преградой.
library;

import 'package:flutter/material.dart';

import '../../../app/app_controller.dart' show AppController, RoomInviteTarget;
import '../../../entitlements/entitlement_models.dart';
import '../../../entitlements/feature_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';

/// Можно ли создать ещё одну комнату. Нельзя — объясняет своим окном.
Future<bool> desktopMayCreateRoom(
  BuildContext context,
  AppController controller,
) async {
  if (await controller.canCreateGroupNow()) return true;
  if (!context.mounted) return false;
  await showDesktopRoomLimitDialog(
    context,
    state: controller.entitlementStateNow,
    joining: false,
  );
  return false;
}

/// Можно ли вступить в комнату приглашения. Нельзя — объясняет своим окном.
///
/// Уже состоящего в этой комнате предел не касается: экран входа просто
/// откроет её. Узнаём это по тому же описанию, что читает экран входа; не
/// узнали (нет связи) — считаем, что не состоит.
Future<bool> desktopMayJoinRoom(
  BuildContext context,
  AppController controller,
  RoomInviteTarget target,
) async {
  if (await controller.canJoinGroupNow()) return true;
  try {
    final preview = await controller.resolveRoomInviteTarget(target);
    if (preview.isAlreadyMember) return true;
  } catch (_) {}
  if (!context.mounted) return false;
  await showDesktopRoomLimitDialog(
    context,
    state: controller.entitlementStateNow,
    joining: true,
  );
  return false;
}

/// Объясняет предел комнат: сколько можно и — на бесплатном тарифе — где
/// взять больше. [joining] — вступление по приглашению, иначе создание.
Future<void> showDesktopRoomLimitDialog(
  BuildContext context, {
  required EntitlementState state,
  required bool joining,
}) {
  final l10n = AppLocalizations.of(context)!;
  final c = DColors.of(context);
  final style = DType.body.copyWith(color: c.textSecondary);
  final limit = joining
      ? FeatureGate.joinedGroupsLimit(state)
      : FeatureGate.ownedGroupsLimit(state);
  return DesktopDialog.show<void>(
    context,
    title: l10n.desktopRoomLimitTitle,
    size: DDialogSize.small,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          joining
              ? l10n.desktopRoomLimitJoin(limit)
              : l10n.desktopRoomLimitCreate(limit),
          style: style,
        ),
        // Premium поднимает предел; у кого он уже есть — предлагать нечего.
        if (!state.tier.isPaid) ...[
          const SizedBox(height: DSpace.s),
          Text(l10n.desktopRoomLimitPremium, style: style),
        ],
      ],
    ),
    primary: DDialogAction(
      label: l10n.ok,
      onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
    ),
  );
}
