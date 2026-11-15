// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ui/space_gate_screen.dart';
import 'app_security_manager.dart';
import 'profile_space.dart';
import 'profile_space_wipe.dart';
import 'secure_secrets.dart';

/// Чем закончился ввод кода на шлюзе или в замке приложения.
enum SpaceGateOutcome {
  /// Настоящий пароль или биометрия.
  real,

  /// Код принуждения.
  duress,

  /// Исчерпан предел неверных попыток со стиранием.
  wipeAll,
}

/// Шлюз пространства профиля (Э2 «код принуждения»).
///
/// Запускается ПЕРВЫМ в `main()`, до любого `SharedPreferences.getInstance()`:
/// пока код принуждения не настроен, он молча входит в `main` и ничего не
/// показывает. Если настроен — показывает экран PIN вместо приложения и по
/// введённому коду выбирает пространство. Биометрия всегда ведёт в `main`:
/// под принуждением человек вводит код, а не прикладывает палец.
class SpaceGate {
  SpaceGate._();

  /// Какое пространство открывать по исходу.
  static ProfileSpace spaceFor(SpaceGateOutcome outcome) => switch (outcome) {
    SpaceGateOutcome.real => ProfileSpace.main,
    SpaceGateOutcome.duress => ProfileSpace.alt,
    SpaceGateOutcome.wipeAll => ProfileSpace.main,
  };

  static Future<ProfileSpace> resolveAtStartup() async {
    String? duressRaw;
    try {
      duressRaw = await SecureSecrets.create().getAppLockSecret(
        AppSecurityManager.duressStorageId,
      );
    } on SecureSecretUnreadable {
      // Код принуждения не читается — открываем настоящий профиль, как и без
      // кода. Сам код не трогаем: следующий запуск прочитает его снова.
      duressRaw = null;
    }
    if (duressRaw == null || duressRaw.isEmpty) {
      await _enterQuietly(ProfileSpace.main);
      return ProfileSpace.main;
    }
    final manager = AppSecurityManager();
    try {
      await manager.init();
      final config = manager.scopeConfig(SecurityLockScope.app);
      if (!config.isEnabled ||
          config.method != SecurityLockMethod.password) {
        // Замка нет, а код принуждения остался: он бесполезен и опасен —
        // любой ввод открывал бы обманку. Снимаем.
        await manager.clearDuressPassword();
        await _enterQuietly(ProfileSpace.main, resetPrefs: true);
        return ProfileSpace.main;
      }
      await manager.lockNow(SecurityLockScope.app);
      final completer = Completer<SpaceGateDecision>();
      runApp(
        SpaceGateApp(
          manager: manager,
          onDecided: (decision) {
            if (!completer.isCompleted) completer.complete(decision);
          },
        ),
      );
      final decision = await completer.future;
      final space = await applyDecision(decision, security: manager);
      if (decision.outcome == SpaceGateOutcome.real) {
        AppSecurityManager.startupUnlockedScopes.add(SecurityLockScope.app);
      }
      await ProfileSpaceRuntime.store(space);
      await ProfileSpaceRuntime.enter(space, resetPrefs: true);
      return space;
    } finally {
      await manager.dispose();
    }
  }

  /// Выполняет стирание, которого требует исход, и возвращает пространство.
  /// Текущий изолят обязан находиться в `main` (шлюз или замок приложения —
  /// в обманке замка нет).
  static Future<ProfileSpace> applyDecision(
    SpaceGateDecision decision, {
    required AppSecurityManager security,
  }) async {
    switch (decision.outcome) {
      case SpaceGateOutcome.real:
        return ProfileSpace.main;
      case SpaceGateOutcome.duress:
        if (decision.wipeMain) {
          await ProfileSpaceWipe.wipe(ProfileSpace.main);
        }
        return ProfileSpace.alt;
      case SpaceGateOutcome.wipeAll:
        await ProfileSpaceWipe.wipe(ProfileSpace.alt);
        await ProfileSpaceWipe.wipe(ProfileSpace.main);
        await security.disableLock(SecurityLockScope.app);
        return ProfileSpace.main;
    }
  }

  /// Событие замка из работающего приложения: стирает, что просили, и
  /// переводит изолят в нужное пространство. Вызывающий пересоздаёт
  /// контроллер.
  static Future<ProfileSpace> applyEmergency(
    AppLockEmergency event, {
    required AppSecurityManager security,
  }) async {
    final decision = switch (event.kind) {
      AppLockEmergencyKind.duress => SpaceGateDecision(
        SpaceGateOutcome.duress,
        wipeMain: event.wipeMain,
      ),
      AppLockEmergencyKind.wipeAll => const SpaceGateDecision(
        SpaceGateOutcome.wipeAll,
      ),
    };
    final space = await applyDecision(decision, security: security);
    await ProfileSpaceRuntime.store(space);
    await ProfileSpaceRuntime.enter(space, resetPrefs: true);
    return space;
  }

  static Future<void> _enterQuietly(
    ProfileSpace space, {
    bool resetPrefs = false,
  }) async {
    await ProfileSpaceRuntime.store(space);
    await ProfileSpaceRuntime.enter(space, resetPrefs: resetPrefs);
  }
}

class SpaceGateDecision {
  const SpaceGateDecision(this.outcome, {this.wipeMain = false});
  final SpaceGateOutcome outcome;
  final bool wipeMain;
}
