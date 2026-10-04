// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ПАРОЛЬ «ЛИЧНЫХ» ОБХОДИЛСЯ (30.09.2026).
//
// Пароль спрашивала только полоса категорий. Нажатие на уведомление, ссылка
// `secretly://room/…`, плитка закреплённого чата на рейке, стрелки «назад» и
// «вперёд» открывали личный чат без вопросов; «Комнаты» показывали личные
// комнаты всегда; уход из «Личных» оставлял личный чат открытым.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/security/app_security_manager.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Biometrics implements BiometricAuthenticator {
  @override
  Future<SecurityBiometricStatus> getStatus() async =>
      const SecurityBiometricStatus(
        isSupported: true,
        canCheckBiometrics: true,
        supportsDeviceCredentials: true,
        availableTypes: <String>{'fingerprint'},
      );

  @override
  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  }) async => true;
}

class _Controller extends AppController {
  _Controller(this._personal, this._security);

  final Set<String> _personal;
  final AppSecurityManager _security;

  @override
  bool isPersonalChat(String convoId) => _personal.contains(convoId.trim());

  @override
  AppSecurityManager get security => _security;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSecurityManager> manager({required bool personalLock}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (personalLock) 'security_lock_enabled_v1_personal': true,
      if (personalLock) 'security_lock_method_v1_personal': 'biometric',
    });
    final m = AppSecurityManager(biometricAuthenticator: _Biometrics());
    await m.init();
    return m;
  }

  group('одно правило на все входы', () {
    test('🔴 запертые «Личные»: личная переписка скрыта', () async {
      final c = _Controller({'P-1'}, await manager(personalLock: true));
      expect(desktopPersonalChatHidden(c, 'P-1'), isTrue);
      expect(desktopPersonalChatHidden(c, 'P-2'), isFalse);
    });

    test('после пароля — открыта, после запирания — снова скрыта', () async {
      final m = await manager(personalLock: true);
      final c = _Controller({'group:r1'}, m);
      expect(
        await m.authenticateWithBiometrics(
          scope: SecurityLockScope.personal,
          reason: 'test',
        ),
        isTrue,
      );
      expect(desktopPersonalChatHidden(c, 'group:r1'), isFalse);
      await m.lockNow(SecurityLockScope.personal);
      expect(desktopPersonalChatHidden(c, 'group:r1'), isTrue);
    });

    test('без пароля «Личных» прятать нечего', () async {
      final c = _Controller({'P-1'}, await manager(personalLock: false));
      expect(desktopPersonalChatHidden(c, 'P-1'), isFalse);
    });
  });

  group('проводка', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    String body(String src, String start) {
      final from = src.indexOf(start);
      expect(from, greaterThanOrEqualTo(0), reason: start);
      return src.substring(from, src.indexOf('\n  }\n', from));
    }

    test('🔴 уведомление, ссылка, рейка: пароль — до выбора переписки', () {
      final open = body(app, '  Future<bool> _openConvoByIdFromDeepLink(');
      final ask = open.indexOf('desktopUnlockPersonalChat(');
      expect(ask, greaterThan(0));
      expect(open.indexOf('_chatsSelection.select(match)'), greaterThan(ask));
      expect(open.indexOf('_roomsSelection.select(match)'), greaterThan(ask));
    });

    test('🔴 стрелки истории: пароль — до выбора переписки', () {
      final history = body(app, '  void _applyHistoryEntry(');
      final ask = history.indexOf('desktopPersonalChatHidden(');
      expect(ask, greaterThan(0));
      expect(history.indexOf('store.select(entry.convo)'), greaterThan(ask));
    });

    test('🔴 рейка не показывает и не считает «Личные» под паролем', () {
      final rail = body(app, '  Future<RailSnapshot> _loadRailSnapshot()');
      expect(
        rail.contains(
          'if (hidePersonal && _controller.isPersonalChat(c.convoId)) continue;',
        ),
        isTrue,
      );
    });

    test('выбор извне идёт через тот же вход', () {
      final external = body(section, '  void _onExternalSelection() {');
      expect(external.contains('unawaited(_openPersonal(wanted));'), isTrue);
    });

    test('🔴 «Комнаты» и открытая переписка фильтруются по «Личным»', () {
      expect(
        section.contains(
          '? _conversations.where(_personalAllowed).toList(growable: false)',
        ),
        isTrue,
      );
      expect(
        section.contains(
          'if (selected != null && !_personalAllowed(selected)) selected = null;',
        ),
        isTrue,
      );
      final visible = body(section, '  bool get _personalVisible {');
      expect(
        visible.contains('security.isLocked(SecurityLockScope.personal)'),
        isTrue,
      );
    });

    test('🔴 запирание и уход из «Личных» закрывают личный чат', () {
      expect(
        body(
          section,
          '  void _onSecurityChanged() {',
        ).contains('_dropHiddenSelection();'),
        isTrue,
      );
      expect(
        body(
          section,
          '  Future<void> _selectCategory(String id) async {',
        ).contains('_dropHiddenSelection();'),
        isTrue,
      );
    });
  });
}
