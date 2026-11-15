// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Что сделать перед входом в созвон комнаты (ТЗ E2EE созвонов, §7.3, §8.3).
///
/// Пока доля зашифрованных созвонов у устройства 0 (блок `calls`), план
/// всегда «входить как раньше»: ни окон, ни плашек — интерфейс не меняется.
library;

import 'call_e2ee_protocol.dart';

/// Почему войти нельзя.
enum RoomCallJoinBlock {
  /// Созвон зашифрованный (или настал флаг-день), а платформа не умеет.
  platformUnsupported,

  /// Флаг-день: открытый созвон больше не открывается.
  e2eeRequired,

  /// Аварийный выключатель групповых созвонов.
  groupCallsDisabled,
}

class RoomCallJoinPlan {
  const RoomCallJoinPlan({
    required this.contract,
    required this.existingCall,
    this.needsOpenJoinConsent = false,
    this.membersWithoutE2ee = const <String>[],
    this.offerOpenAlternative = false,
    this.block,
  });

  /// С каким контрактом входить.
  final String contract;

  /// Созвон уже идёт (иначе он создаётся этим входом).
  final bool existingCall;

  /// Идёт открытый созвон, а у устройства раскатка шифрования активна:
  /// войти можно, но только после окна «без шифрования» (§8.1).
  final bool needsOpenJoinConsent;

  /// Профили членов комнаты без устройства новой версии (для окна выбора).
  final List<String> membersWithoutE2ee;

  /// Можно предложить начать без шифрования (до флаг-дня).
  final bool offerOpenAlternative;

  final RoomCallJoinBlock? block;

  bool get blocked => block != null;

  bool get isE2ee => contract == kRoomMediaContractE2eeV1;

  /// Окно выбора у создателя (§8.3): новый зашифрованный созвон, а кто-то
  /// из членов комнаты в него не войдёт.
  bool get needsCreatorChoice =>
      !existingCall && isE2ee && membersWithoutE2ee.isNotEmpty;
}
