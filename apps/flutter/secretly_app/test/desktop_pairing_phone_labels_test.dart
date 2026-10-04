// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОДСКАЗКА НА ЭКРАНЕ QR-ВХОДА НАЗЫВАЕТ КНОПКИ ТЕЛЕФОНА ТАК, КАК ИХ ЗОВЁТ
// ТЕЛЕФОН (01.10.2026).
//
// 🔴 Было: «Link a device», «Vincular dispositivo», «Associer un appareil»,
// «Ligar dispositivo», «Réglages», «Definições» — а на телефоне «Connect
// device», «Conectar dispositivo», «Connecter un appareil», «Paramètres»,
// «Configurações». Человек с компьютером в руке искал на телефоне кнопку,
// которой нет. Теперь подписи берутся из тех же ключей, что рисует телефон.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_onboarding_screen.dart';

void main() {
  test('на всех восьми языках — подписи телефона дословно', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final text = desktopPairingHowToText(l10n);
      expect(text, contains(l10n.settingsTitle), reason: '$locale');
      expect(text, contains(l10n.devicesSection), reason: '$locale');
      expect(text, contains(l10n.devicesConnectDevice), reason: '$locale');
      for (final wrong in const [
        'Link a device',
        'Vincular dispositivo',
        'Associer un appareil',
        'Ligar dispositivo',
        'Réglages',
        'Definições',
      ]) {
        expect(text, isNot(contains(wrong)), reason: '$locale: «$wrong»');
      }
    }
  });

  test('телефон и правда так подписывает путь к кнопке', () {
    // Кнопка сканирования на телефоне для ru/en подписана прямо в коде, для
    // остальных — ключом `devicesConnectDevice`. Ключ обязан совпадать с
    // подписью в коде, иначе подсказка компьютера снова разойдётся.
    final phone = File('lib/ui/devices_auth_screen.dart').readAsStringSync();
    expect(phone, contains("ru: 'Подключить устройство',"));
    expect(phone, contains("en: 'Connect device',"));
    expect(phone, contains("case 'Connect device':"));
    expect(phone, contains('return l10n.devicesConnectDevice;'));
    Map<String, dynamic> arb(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(arb('ru')['devicesConnectDevice'], 'Подключить устройство');
    expect(arb('en')['devicesConnectDevice'], 'Connect device');
    // Плитка «Устройства» — в корне настроек, вкладка — `settingsTitle`.
    final settings = File('lib/ui/settings_screen.dart').readAsStringSync();
    expect(settings, contains('title: l10n.devicesSection,'));
    final shell = File('lib/ui/app_shell.dart').readAsStringSync();
    expect(shell, contains('label: l10n.settingsTitle,'));
    // Экран QR-входа берёт подсказку отсюда, а не своим переводом.
    final screen = File(
      'lib/ui/desktop/onboarding/desktop_onboarding_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('desktopPairingHowToText(_l10n)'));
  });
}
