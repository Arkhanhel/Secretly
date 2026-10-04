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
  // 🔴 Выпуск macOS собирает ОДИН скрипт — корневой (30.09.2026). Прежний
  // `tools/desktop_release_macos.sh` только отсылает к нему. В опубликованном
  // дереве корневого скрипта может не быть — тогда его проверки молчат.
  final release = File('../../../tools/macos_build_desktop_release.sh');
  final legacy = File('tools/desktop_release_macos.sh');

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
    for (final f in [File('macos/Runner/Info.plist'), legacy, release]) {
      if (!f.existsSync()) continue;
      final s = f.readAsStringSync();
      expect(s.contains('BEGIN PRIVATE KEY'), isFalse, reason: f.path);
      expect(s.contains('SUPrivateEDKey'), isFalse, reason: f.path);
    }
  });

  test('🔴 прежний скрипт выпуска НЕ собирает, а отсылает к корневому', () {
    // Два пути выпуска — это вопрос «каким из них собрана эта версия», на
    // который после выкладки нет ответа. Прежний отстал на три исправления.
    final s = legacy.readAsStringSync();
    expect(s.contains('flutter build'), isFalse);
    final run = Process.runSync('bash', [legacy.path]);
    expect(run.exitCode, isNot(0), reason: 'должен вернуть ошибку');
    expect(
      '${run.stderr}',
      contains('tools/macos_build_desktop_release.sh'),
    );
  });

  test('🔴 адрес обновлений — СВОЙ, не чужая площадка', () {
    // Как у Signal (updates.signal.org), Telegram и Element. Проверка
    // обновлений идёт с каждой установленной копии и несёт адрес человека:
    // отдать этот поток третьей стороне значит сообщить ей, у кого стоит
    // Secretly и когда он включает компьютер.
    final m = RegExp(
      r'<key>SUFeedURL</key>.*?<string>([^<]*)</string>',
      dotAll: true,
    ).firstMatch(plist);
    expect(m, isNotNull);
    final url = (m!.group(1) ?? '').trim();
    expect(url.startsWith('https://'), isTrue, reason: 'только по HTTPS');
    expect(url.endsWith('/appcast.xml'), isTrue);
    for (final foreign in const [
      'github.com',
      'githubusercontent.com',
      's3.amazonaws.com',
      'dropbox.com',
    ]) {
      expect(url.contains(foreign), isFalse, reason: 'чужая площадка: $foreign');
    }
    expect(url.contains('secretlyapp.com'), isTrue);
  });

  test('раздача обновлений описана в настройке прокси', () {
    // 🔴 ФАЙЛА ЗДЕСЬ МОЖЕТ НЕ БЫТЬ, И ЭТО НЕ ПОЛОМКА.
    //
    // `server/proxy/` сознательно не публикуется: через настройку прокси
    // уходила бы карта сервера — ровно то, что README обещает не
    // раскрывать. В опубликованном дереве этот тест проверять нечего, и
    // падать ему здесь не за что: он охраняет НАШУ настройку, а не код.
    final caddy = File('../../../server/proxy/caddy/Caddyfile');
    if (!caddy.existsSync()) return;
    final text = caddy.readAsStringSync();
    expect(text.contains('SECRETLY_UPDATES_DOMAIN'), isTrue);
    // Перечень файлов в каталоге сам по себе сообщает, какие версии были.
    expect(text.contains('respond 404'), isTrue);
    // «Этот адрес спросил про обновления» = «у этого человека стоит Secretly».
    expect(text.contains('output discard'), isTrue);
  });

  test('🔴 имя образа несёт версию — иначе вечный кэш отдаёт старое', () {
    // Образы раздаются с `immutable` на год: содержимое версии не меняется
    // никогда. При постоянном имени тот же адрес указывал бы на РАЗНОЕ
    // содержимое от выпуска к выпуску, и промежуточные узлы весь год отдавали
    // бы старый образ — человек видел бы «обновление есть», скачивал прежнюю
    // версию, и подпись в перечне на неё не сошлась бы.
    if (!release.existsSync()) return;
    expect(
      release.readAsStringSync(),
      contains(r'secretly-macos-$build_name-$build_number-'),
    );
  });

  test('🔴 номер версии берётся из флагов, а не из pubspec', () {
    // В pubspec версия сознательно отстаёт. По номеру в перечне установленные
    // копии решают, есть ли обновление: старый номер — либо никому не
    // предложим, либо предложим «обновиться» на то, что уже стоит.
    if (!release.existsSync()) return;
    final s = release.readAsStringSync();
    expect(s, contains(r'--build-name "$build_name"'));
    expect(s, contains(r'--build-number "$build_number"'));
    expect(s, contains(r'SECRETLY_APP_BUILD_NUMBER=$build_number'));
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
