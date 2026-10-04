// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПОДПИСИ БОКОВОЙ КОЛОНКИ НАСТРОЕК ВЛЕЗАЮТ ЦЕЛИКОМ — В ВОСЬМИ ЯЗЫКАХ.
//
// Макет владельца (29.09.2026) даёт колонке 232 точки. У нас 248: самая
// длинная подпись раздела — украинское «Видалити обліковий запис», и
// обрезанный многоточием «Удалить аккаунт» — ровно та строка, которую нельзя
// оставлять недочитанной. Меряем НАСТОЯЩИМ шрифтом окна (Manrope), а не
// квадратным шрифтом проверок: иначе мерка ничего бы не значила.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/tokens.dart';

/// Числа раскладки колонки (`workspace_layout.dart`, `settings_workspace.dart`).
const double _sidebar = 248;
const double _listPad = 8; // ListView: поля 8 слева и справа
const double _rowPad = 8; // строка раздела: поля 8 слева и справа
const double _glyph = 19;
const double _gap = 10;
const double _groupPad = 8; // заголовок группы: поля 8 слева и справа

const List<String> _sectionKeys = <String>[
  'desktopSettingsGeneralLabel',
  'desktopSettingsAppearanceLabel',
  'desktopSettingsShortcutsLabel',
  'desktopSettingsPowerLabel',
  'desktopSettingsNotificationsLabel',
  'desktopSettingsCallsLabel',
  'desktopSettingsMediaLabel',
  'desktopSettingsPrivacyLabel',
  'desktopSettingsSecurityLabel',
  'desktopSettingsBackupLabel',
  'desktopSettingsBlockedLabel',
  'desktopSettingsDevicesLabel',
  'desktopSettingsAccountLabel',
  'desktopSettingsStorageLabel',
  'desktopSettingsSupportLabel',
  'desktopSettingsAboutLabel',
  'desktopSettingsDangerLabel',
];

const List<String> _groupKeys = <String>[
  'desktopSettingsGroupApp',
  'desktopSettingsGroupPrivacy',
  'desktopSettingsGroupAccount',
];

Future<void> _loadManrope() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    if (entry['family'] != DType.family) continue;
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

double _width(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

void main() {
  testWidgets('🔴 ни одна подпись колонки не обрезается', (t) async {
    await t.runAsync(_loadManrope);
    const rowRoom = _sidebar - _listPad * 2 - _rowPad * 2 - _glyph - _gap;
    const groupRoom = _sidebar - _listPad * 2 - _groupPad * 2;
    final tooLong = <String>[];
    for (final lang in ['en', 'ru', 'uk', 'de', 'es', 'fr', 'pt', 'pt_BR']) {
      final arb = json.decode(
        File('lib/l10n/app_$lang.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final k in _sectionKeys) {
        final v = arb[k] as String;
        // Выбранная строка — 600, это самый широкий её вид.
        final w = _width(
          v,
          const TextStyle(
            fontFamily: DType.family,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
        if (w > rowRoom) tooLong.add('$lang/$k «$v» ${w.round()} > $rowRoom');
      }
      for (final k in _groupKeys) {
        final v = (arb[k] as String).toUpperCase();
        final w = _width(
          v,
          const TextStyle(
            fontFamily: DType.family,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.44,
          ),
        );
        if (w > groupRoom) {
          tooLong.add('$lang/$k «$v» ${w.round()} > $groupRoom');
        }
      }
    }
    expect(tooLong, isEmpty, reason: tooLong.join('\n'));
  });

  test('ширина колонки в разметке та же, что в мерке', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(src.contains('sidebarWidth: 248,'), isTrue);
  });
}
