// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 🔴 ПАРОЛЬ «ВХОД В ПРИЛОЖЕНИЕ» НА КОМПЬЮТЕРЕ НЕ СПРАШИВАЛСЯ (17.09.2026).
//
// Настройки компьютера включали общий замок приложения, а проверял его только
// телефонный `main.dart`. Теперь компьютер рисует тот же экран блокировки и
// запирает замки, когда окно скрыто: у спрятанного в трей окна жизненный цикл
// не меняется, поэтому «фон» сообщается по видимости окна.

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('приложение компьютера', () {
    final app = _read('lib/ui/desktop/app/desktop_production_app.dart');

    test('🔴 экран блокировки рисуется по общему замку', () {
      expect(
        app.contains(
          'if (_appScopeLocked) AppSecurityLockOverlay(controller: _controller),',
        ),
        isTrue,
      );
      final getter = app.substring(
        app.indexOf('  bool get _appScopeLocked {'),
        app.indexOf('  Widget? _buildActiveCallOverlay() {'),
      );
      expect(
        getter.contains('security.isLocked(SecurityLockScope.app)'),
        isTrue,
      );
      // Входящий звонок можно принять — как на телефоне.
      expect(getter.contains('call.isActive || call.isRinging'), isTrue);
    });

    test('🔴 скрытое окно — это фон для замков', () {
      final handler = app.substring(
        app.indexOf('  void _onWindowVisibilityChanged() {'),
        app.indexOf('  @override\n  void onWindowFocus()'),
      );
      expect(
        handler.contains(
          'visible ? AppLifecycleState.resumed : AppLifecycleState.hidden',
        ),
        isTrue,
      );
      expect(handler.contains('security.onAppLifecycleStateChanged('), isTrue);
    });

    test('смена замка перерисовывает корень', () {
      expect(
        app.contains('_securitySub = _controller.security.changed.listen('),
        isTrue,
      );
      expect(app.contains('_securitySub?.cancel();'), isTrue);
    });
  });

  test('список чатов прячет «Личные», когда замок снова заперт', () {
    final section = _read('lib/ui/desktop/app/desktop_chats_section.dart');
    final handler = section.substring(
      section.indexOf('  void _onSecurityChanged() {'),
      section.indexOf('  @override\n  void dispose()', section.indexOf('  void _onSecurityChanged() {')),
    );
    expect(
      handler.contains('security.isLocked(SecurityLockScope.personal)'),
      isTrue,
    );
    expect(handler.contains('_personalUnlocked = false;'), isTrue);
  });

  test('подписи не обещают общий с телефоном замок', () {
    final settings = _read('lib/ui/desktop/workspace/settings_workspace.dart');
    expect(settings.contains('Настройка общая с '), isFalse);
    final overlay = _read('lib/ui/desktop/app/desktop_lock_overlay.dart');
    expect(overlay.contains('она общая'), isFalse);
  });
}
