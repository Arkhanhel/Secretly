// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Выпуск обновлений: ключ на месте, перечень версий подписан.
//
// 🔴 ПОДПИСЬ ПАКЕТА — НЕ ТО ЖЕ, ЧТО ПОДПИСЬ ПРИЛОЖЕНИЯ. Developer ID и
// заверение отвечают на вопрос «можно ли это запустить». Подпись EdDSA
// отвечает на другой — «мы ли это прислали». Обновление, подменённое по
// дороге, обязано быть отвергнуто ДО установки, и проверяет это сам Sparkle
// открытым ключом, который едет вместе с приложением.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final plist = File('macos/Runner/Info.plist').readAsStringSync();
  final script = File('tools/desktop_release_macos.sh').readAsStringSync();

  test('🔴 открытый ключ проверки обновлений есть и не пустой', () {
    final m = RegExp(
      r'<key>SUPublicEDKey</key>.*?<string>([^<]*)</string>',
      dotAll: true,
    ).firstMatch(plist);
    expect(m, isNotNull, reason: 'без него обновления проверять нечем');
    final key = (m!.group(1) ?? '').trim();
    expect(key, isNotEmpty);
    // Ed25519 в base64 — 32 байта, 44 знака с выравниванием.
    expect(key.length, 44, reason: 'не похоже на ключ Ed25519: «$key»');
    expect(RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(key), isTrue);
  });

  test('🔴 закрытого ключа в дереве исходников НЕТ', () {
    // Он создаётся один раз `generate_keys` и живёт в ключнице выпускающего.
    // Попади он сюда — любой, у кого есть репозиторий, смог бы выпустить
    // «обновление» Secretly.
    for (final f in const [
      'macos/Runner/Info.plist',
      'tools/desktop_release_macos.sh',
    ]) {
      final s = File(f).readAsStringSync();
      expect(s.contains('BEGIN PRIVATE KEY'), isFalse, reason: f);
      expect(s.contains('SUPrivateEDKey'), isFalse, reason: f);
    }
  });

  test('перечень версий собирается только с адресом публикации', () {
    // Перечень, указывающий на адрес, которого никто не обслуживает, сообщил
    // бы каждой установленной копии, что обновление есть, — и не смог бы его
    // отдать.
    expect(script.contains(r'if [ -n "${SECRETLY_UPDATE_BASE_URL:-}" ]; then'),
        isTrue);
    expect(script.contains('generate_appcast'), isTrue);
    expect(script.contains('--download-url-prefix'), isTrue);
  });

  test('🔴 перечень без подписи — это ОТКАЗ сборки, а не предупреждение', () {
    // Иначе узнаем мы об этом от людей, у которых «проверка обновлений ничего
    // не делает».
    expect(script.contains("grep -q 'edSignature'"), isTrue);
    expect(
      script.contains('error: appcast.xml carries no edSignature'),
      isTrue,
    );
  });

  test('обновлятор не поднимается, пока не задан адрес перечня', () {
    // Пока `SUFeedURL` не прописан, проверка обновлений выключена целиком, и
    // пункта меню нет: обновлятор, которому некуда ходить, показывал бы
    // человеку ошибку вместо ответа.
    final bridge =
        File('macos/Runner/SparkleBridge.swift').readAsStringSync();
    expect(bridge.contains('guard feedUrl != nil'), isTrue);
    expect(bridge.contains('guard publicKey != nil'), isTrue);
  });
}
