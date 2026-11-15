// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'art_assets_availability.dart';

// 🔴 СТОРОЖ ПЕРЕЧНЯ УКРАШЕНИЙ, НАМЕРЕННО НЕЗАВИСИМЫЙ ОТ ГЕНЕРАТОРА (Э7).
//
// Перечень `assets/on_demand_manifest.json` собирает
// `tools/build_on_demand_assets.py`, и у него есть режим `--check`. Но
// проверка генератором своего же вывода подтверждает лишь то, что генератор
// повторяем: ровно так 12.10.2026 проверка облегчённой сборки сверялась с тем
// же списком, из которого собиралась, и пропустила две библиотеки.
//
// Здесь перечень читается как данные и сверяется с файлами на диске другим
// кодом. Расхождение означает украшение, которое НЕ загрузится никогда:
// отпечаток не совпадёт, и приложение честно откажется его показать.

const String _manifestPath = 'assets/on_demand_manifest.json';

/// Каталоги, украшения которых уезжают из облегчённой сборки.
const List<String> _dirs = <String>[
  'assets/app_ui/icons/png',
  'assets/Background',
];

/// Остаётся в пакете: нужен до первой сети.
const List<String> _keptInBundle = <String>[
  'assets/app_ui/icons/png/premium_logo.png',
];

const List<String> _skipNames = <String>['.DS_Store'];

void main() {
  test('🔴 перечень украшений сходится с файлами', () {
    final file = File(_manifestPath);
    expect(file.existsSync(), isTrue, reason: 'нет $_manifestPath');
    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, Object?>>());
    final doc = (decoded as Map).cast<String, Object?>();
    expect(doc['v'], 1);
    final assets = (doc['assets'] as Map).cast<String, Object?>();
    expect(assets, isNotEmpty);

    for (final entry in assets.entries) {
      final path = entry.key;
      final meta = (entry.value as Map).cast<String, Object?>();
      final target = File(path);
      expect(
        target.existsSync(),
        isTrue,
        reason: 'в перечне есть $path, а файла нет',
      );
      final bytes = target.readAsBytesSync();
      expect(
        meta['bytes'],
        bytes.length,
        reason: 'размер в перечне не совпал: $path',
      );
      expect(
        meta['sha256'],
        sha256.convert(bytes).toString(),
        reason: 'отпечаток в перечне не совпал: $path',
      );
      expect(
        _keptInBundle.contains(path),
        isFalse,
        reason: '$path обязан остаться в пакете, его нельзя брать по сети',
      );
    }
  },
      skip: artAssetsArePlaceholders ? artAssetsSkipReason : null,
    );

  test('🔴 ни один файл украшений не забыт в перечне', () {
    final assets = ((jsonDecode(File(_manifestPath).readAsStringSync())
                as Map)['assets']
            as Map)
        .cast<String, Object?>();
    final missing = <String>[];
    for (final dir in _dirs) {
      final directory = Directory(dir);
      expect(directory.existsSync(), isTrue, reason: 'нет каталога $dir');
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path;
        final name = path.split('/').last;
        if (_skipNames.contains(name)) continue;
        if (_keptInBundle.contains(path)) continue;
        if (!assets.containsKey(path)) missing.add(path);
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'файлы есть, а в перечне их нет — облегчённая сборка их потеряет: '
          '${missing.take(5).join(', ')}',
    );
  },
      skip: artAssetsArePlaceholders ? artAssetsSkipReason : null,
    );

  test('перечень мал: он едет в каждой сборке', () {
    final bytes = File(_manifestPath).lengthSync();
    expect(
      bytes,
      lessThan(512 * 1024),
      reason: 'перечень вырос — украшений стало слишком много для одного файла',
    );
  });
}
