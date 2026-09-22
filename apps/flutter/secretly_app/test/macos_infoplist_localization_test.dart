// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Описания доступа к камере и микрофону — на всех восьми языках.
//
// 🔴 ЗАЧЕМ. Это единственный текст приложения, который показывает СИСТЕМА, и
// показывает в момент, когда у неё спрашивают разрешение. До 21.09.2026 все
// семь описаний были только по-русски: на испанском Mac система спрашивала
// доступ к микрофону ПО-РУССКИ. Разрешение — момент доверия, и просить его на
// чужом языке хуже, чем не просить.
//
// 🔴 И ВТОРАЯ ЛОВУШКА, НА КОТОРУЮ Я НАСТУПИЛ В ТОТ ЖЕ ДЕНЬ. Файлы `.strings`,
// записанные в UTF-8, Xcode при копировании в бандл принял за MacRoman:
// кириллица превратилась в «8A?>;L7C5B». Сборка при этом прошла без единого
// предупреждения. Классическая кодировка `.strings` — UTF-16 С МЕТКОЙ порядка
// байтов, её Xcode опознаёт и не гадает. Поэтому кодировка здесь проверяется
// наравне с содержимым: перевод, которого не видно, ничем не лучше
// отсутствующего.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Языки окна. `pt-BR` — с дефисом: так каталоги называет macOS, тогда как
/// Flutter тот же язык зовёт `pt_BR`.
const _langs = ['en', 'ru', 'uk', 'de', 'es', 'fr', 'pt', 'pt-BR'];

/// Читает `.strings` в UTF-16 и достаёт пары ключ-значение.
Map<String, String> _readStrings(File f) {
  final bytes = f.readAsBytesSync();
  expect(
    bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE,
    isTrue,
    reason: '${f.path}: нет метки UTF-16 LE. Xcode примет такой файл за '
        'MacRoman и молча испортит кириллицу — см. заголовок файла',
  );
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    units.add(bytes[i] | (bytes[i + 1] << 8));
  }
  final text = String.fromCharCodes(units);
  final out = <String, String>{};
  final re = RegExp(r'"([^"]+)"\s*=\s*"([^"]*)";');
  for (final m in re.allMatches(text)) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

void main() {
  final plist = File('macos/Runner/Info.plist').readAsStringSync();
  // Ключи, которые реально показывает система у ЭТОГО приложения. Берём из
  // Info.plist, а не списком в тесте: добавят восьмой доступ — тест
  // потребует перевести и его, сам, без напоминания.
  final keys = RegExp(r'<key>(NS\w*UsageDescription)</key>')
      .allMatches(plist)
      .map((m) => m.group(1)!)
      .toSet();

  test('в Info.plist есть описания доступа', () {
    expect(keys, isNotEmpty);
    expect(keys, contains('NSMicrophoneUsageDescription'));
    expect(keys, contains('NSCameraUsageDescription'));
  });

  for (final lang in _langs) {
    test('🔴 $lang: все описания доступа переведены', () {
      final f = File('macos/Runner/$lang.lproj/InfoPlist.strings');
      expect(f.existsSync(), isTrue, reason: 'нет ${f.path}');
      final m = _readStrings(f);
      for (final k in keys) {
        expect(m[k]?.trim(), isNotEmpty, reason: '$lang: пропущен $k');
      }
      // Пустой перевод система покажет пустым окном запроса — это хуже
      // чужого языка: человек не узнает даже, зачем у него просят доступ.
      expect(m.keys.toSet(), containsAll(keys));
    });
  }

  test('🔴 переводы РАЗНЫЕ, а не скопированы с русского', () {
    // Восемь одинаковых файлов — самый вероятный способ «перевести» второпях,
    // и он неотличим от настоящего перевода по числу файлов.
    final camera = <String, String>{
      for (final l in _langs)
        l: _readStrings(File('macos/Runner/$l.lproj/InfoPlist.strings'))[
                'NSCameraUsageDescription'] ??
            '',
    };
    expect(camera.values.toSet().length, _langs.length,
        reason: 'совпали: ${camera.entries.where((e) => camera.values.where((v) => v == e.value).length > 1).map((e) => e.key).toList()}');
  });

  test('каталоги локализаций зарегистрированы в проекте Xcode', () {
    // Файл на диске, не прописанный в проекте, в бандл не попадёт — и
    // проверка выше останется зелёной, а система снова спросит по-русски.
    final pbx = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    for (final lang in _langs) {
      expect(pbx.contains('$lang.lproj/InfoPlist.strings'), isTrue,
          reason: '$lang не прописан в project.pbxproj');
    }
    expect(pbx.contains('InfoPlist.strings in Resources'), isTrue,
        reason: 'группа не добавлена в фазу Resources — файлы не скопируются');
  });
}
