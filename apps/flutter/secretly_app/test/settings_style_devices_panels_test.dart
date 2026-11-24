// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 23.11.2026 (владелец): «Чаты» в настройках → «Стиль»; плашки на страницах
// «Устройства» и «Стиль» — как во всех настройках.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  test('«Стиль» на восьми языках', () {
    const want = {
      'en': 'Style',
      'ru': 'Стиль',
      'uk': 'Стиль',
      'es': 'Estilo',
      'pt': 'Estilo',
      'pt_BR': 'Estilo',
      'fr': 'Style',
      'de': 'Stil',
    };
    for (final e in want.entries) {
      final arb =
          jsonDecode(_src('lib/l10n/app_${e.key}.arb')) as Map<String, dynamic>;
      expect(arb['settingsStyleSection'], e.value, reason: e.key);
    }
  });

  test('строка настроек и страница называются «Стиль»', () {
    final s = _src('lib/ui/settings_screen.dart');
    final i = s.indexOf("id: 'chats',");
    expect(s.substring(i, i + 400).contains('settingsStyleSection'), isTrue);
    expect(
      _src('lib/ui/chat_appearance_screen.dart')
          .contains('title: Text(l.settingsStyleSection)'),
      isTrue,
    );
  });

  test('🔴 «Стиль»: панели по общему правилу и на Android', () {
    final s = _src('lib/ui/chat_appearance_screen.dart');
    final i = s.indexOf('class _Panel extends StatelessWidget');
    expect(s.substring(i, i + 900).contains('if (panelCardsEnabled)'), isTrue);
    expect(s.contains('if (i > 0 && !_isAndroid) divider'), isTrue);
  });

  test('🔴 «Устройства» (телефон): панели настроек, без Card', () {
    final s = _src('lib/ui/devices_auth_screen.dart');
    final a = s.indexOf('List<Widget> _buildMobileContent(');
    final b = s.indexOf('List<Widget> _buildDesktopContent(');
    final mobile = s.substring(a, b);
    expect(RegExp(r'(?<![A-Za-z_])Card\(').hasMatch(mobile), isFalse);
    expect(mobile.contains('SettingsPanel('), isTrue);
    expect(mobile.contains('settingsRowsGroup('), isTrue);
    final c = s.indexOf('class _MobileDevicesCard');
    final card = s.substring(c);
    expect(card.contains('AppleGlassPanel('), isTrue);
    expect(card.contains('AppleRowIcon('), isTrue);
  });
}
