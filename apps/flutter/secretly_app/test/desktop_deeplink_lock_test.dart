// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ССЫЛКИ И ЗАПЕРТОЕ ОКНО, ССЫЛКА НА ПРОФИЛЬ БЕЗ СПРОСА (30.09.2026).
//
// Ссылку `secretly://profile/…` может открыть любая веб-страница, а общий
// путь молча принимал запрос переписки от этого профиля и отправлял ему
// отметки «доставлено» и «прочитано» — даже у запертого приложения. Окно
// входа в комнату по ссылке открывалось поверх замка.
//
// Корень целиком в тесте не поднять (окно ОС, контроллер), поэтому здесь
// сторожится порядок шагов в нём, а переводы — во всех восьми языках.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final app = File(
    'lib/ui/desktop/app/desktop_production_app.dart',
  ).readAsStringSync();

  String body(String start) {
    final from = app.indexOf(start);
    expect(from, greaterThanOrEqualTo(0), reason: start);
    return app.substring(from, app.indexOf('\n  }\n', from));
  }

  test('🔴 под замком ссылка ждёт — и не исполняется ни одна', () {
    final handler = body('  void _handleDeepLink(Uri uri) {');
    final hold = handler.indexOf('if (_anyLockEngaged) {');
    expect(hold, greaterThan(0));
    expect(handler.indexOf('_pendingDeepLink = uri;', hold), greaterThan(hold));
    for (final action in const [
      '_openRoomInviteFromLink(invite)',
      '_openProfileFromLink(profileId)',
      '_openConvoOrReport(convoId)',
    ]) {
      expect(handler.indexOf(action), greaterThan(hold), reason: action);
    }
  });

  test('после разблокировки отложенная ссылка исполняется', () {
    final after = body('  void _afterLockChange() {');
    expect(after.contains('final pending = _pendingDeepLink;'), isTrue);
    expect(after.contains('_handleDeepLink(pending)'), isTrue);
  });

  test('🔴 ссылка на профиль — сначала вопрос, запрос — не принимается', () {
    final open = body('  Future<void> _openProfileFromLink(String profileId)');
    final ask = open.indexOf('await _confirmProfileLink(');
    expect(ask, greaterThan(0));
    expect(open.indexOf("c.convoId == 'req:\$pid'"), greaterThan(0));
    expect(
      open.indexOf('_openConvoOrReport(request.convoId)'),
      greaterThan(ask),
    );
    expect(open.indexOf('_openProfileChatByDeepLink(pid)'), greaterThan(ask));
    // Ссылка больше не зовёт общий путь напрямую.
    expect(
      body(
        '  void _handleDeepLink(Uri uri) {',
      ).contains('_openProfileChatByDeepLink('),
      isFalse,
    );
  });

  test('вопрос переведён на все восемь языков', () {
    const keys = [
      'desktopProfileLinkTitle',
      'desktopProfileLinkBody',
      'desktopProfileLinkBodyUnknown',
      'desktopProfileLinkOpen',
    ];
    for (final loc in const [
      'en',
      'ru',
      'uk',
      'de',
      'es',
      'fr',
      'pt',
      'pt_BR',
    ]) {
      final arb =
          jsonDecode(File('lib/l10n/app_$loc.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in keys) {
        expect((arb[key] as String?)?.trim(), isNotEmpty, reason: '$loc $key');
      }
      final body = arb['desktopProfileLinkBody'] as String;
      expect(body.contains('{name}') && body.contains('{id}'), isTrue);
      expect(
        (arb['desktopProfileLinkBodyUnknown'] as String).contains('{id}'),
        isTrue,
      );
    }
  });
}
