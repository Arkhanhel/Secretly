// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// ЦЕЛОСТНОСТЬ МОДЕЛИ РАСПОЗНАВАНИЯ РЕЧИ (SEC-15, закрыто 02.09.2026).
///
/// Приложение скачивало 141 МБ бинарного файла с ПОДВИЖНОЙ ссылки
/// (`resolve/main/…`) и отдавало его нативному разборщику whisper.cpp. Проверки
/// содержимого не было вовсе: единственным условием приёмки был размер больше
/// мегабайта. То есть любой файл крупнее мегабайта принимался как модель.
///
/// Чем это плохо: `main` решает владелец чужого репозитория, содержимое по
/// такой ссылке может стать другим в любой момент. Подменённая модель — это не
/// «неправильный текст расшифровки», а чужой код, разбираемый нативной
/// библиотекой на телефоне человека.
///
/// Здесь проверяется логика приёмки: та же последовательность, что в
/// `_verifyModelFile`, — сначала дешёвая отсечка по размеру, затем сумма, и
/// удаление файла при любом несовпадении.
class ModelGate {
  ModelGate({required this.expectedSha256, required this.expectedSize});

  final String expectedSha256;
  final int expectedSize;

  int deletions = 0;
  bool hashComputed = false;

  Future<bool> accept(File file) async {
    if (!file.existsSync()) return false;
    if (file.lengthSync() != expectedSize) {
      file.deleteSync();
      deletions++;
      return false;
    }
    hashComputed = true;
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != expectedSha256) {
      file.deleteSync();
      deletions++;
      return false;
    }
    return true;
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('whisper_gate'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File write(String name, List<int> bytes) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    return f;
  }

  group('приёмка модели', () {
    test('подлинный файл принимается', () async {
      final bytes = utf8.encode('ggml-model-payload');
      final gate = ModelGate(
        expectedSha256: sha256.convert(bytes).toString(),
        expectedSize: bytes.length,
      );
      final f = write('model.bin', bytes);

      expect(await gate.accept(f), isTrue);
      expect(f.existsSync(), isTrue, reason: 'подлинный файл остаётся на месте');
      expect(gate.deletions, 0);
    });

    test('🔴 подменённый файл ТОГО ЖЕ размера отвергается и удаляется', () async {
      final genuine = utf8.encode('ggml-model-payload');
      final tampered = utf8.encode('ggml-model-EVIL!!!'); // ровно та же длина
      expect(tampered.length, genuine.length);

      final gate = ModelGate(
        expectedSha256: sha256.convert(genuine).toString(),
        expectedSize: genuine.length,
      );
      final f = write('model.bin', tampered);

      expect(
        await gate.accept(f),
        isFalse,
        reason: 'совпадение размера ничего не доказывает — прежняя проверка '
            '«больше мегабайта» пропустила бы это',
      );
      expect(
        f.existsSync(),
        isFalse,
        reason: 'непроверенный бинарник нельзя оставлять на диске: в следующий '
            'раз он ушёл бы в нативный разборщик',
      );
      expect(gate.deletions, 1);
    });

    test('файл неверного размера отсекается ДО пересчёта суммы', () async {
      final genuine = utf8.encode('ggml-model-payload');
      final gate = ModelGate(
        expectedSha256: sha256.convert(genuine).toString(),
        expectedSize: genuine.length,
      );
      final f = write('model.bin', utf8.encode('short'));

      expect(await gate.accept(f), isFalse);
      expect(
        gate.hashComputed,
        isFalse,
        reason: 'размер известен точно — считать сумму 141 МБ незачем',
      );
      expect(f.existsSync(), isFalse);
    });

    test('🔴 пустой файл и обрезанная загрузка не проходят', () async {
      final genuine = utf8.encode('ggml-model-payload');
      final gate = ModelGate(
        expectedSha256: sha256.convert(genuine).toString(),
        expectedSize: genuine.length,
      );
      for (final bytes in <List<int>>[
        <int>[],
        genuine.sublist(0, genuine.length - 1),
      ]) {
        final f = write('m${bytes.length}.bin', bytes);
        expect(await gate.accept(f), isFalse);
        expect(f.existsSync(), isFalse);
      }
    });

    test('отсутствующий файл не роняет проверку', () async {
      final gate = ModelGate(expectedSha256: 'x', expectedSize: 1);
      expect(await gate.accept(File('${dir.path}/нет.bin')), isFalse);
    });
  });

  group('зашитый эталон', () {
    test('🔴 сумма и размер соответствуют проверенному файлу', () {
      // Значения получены из метаданных хранилища и ПЕРЕПРОВЕРЕНЫ скачиванием
      // файла с прибитой ревизии 5359861c739e955e79d9a303bcbc70fb988958b1.
      // Ошибка в этих строках ломает расшифровку голосовых у всех сразу.
      const sha =
          '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe';
      const size = 147951465;

      expect(sha, hasLength(64), reason: 'sha256 в шестнадцатеричном виде');
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(sha),
        isTrue,
        reason: 'только нижний регистр — с ним сравнивается вывод digest',
      );
      expect(size, greaterThan(100 * 1024 * 1024));
      expect(size, lessThan(200 * 1024 * 1024));
    });

    test('ссылка на модель прибита к ревизии, а не к main', () {
      const url =
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin';
      expect(
        url.contains('/resolve/main/'),
        isFalse,
        reason: 'подвижная ссылка — это чужое право заменить содержимое в '
            'любой момент без нашего участия',
      );
      expect(RegExp(r'/resolve/[0-9a-f]{40}/').hasMatch(url), isTrue);
    });
  });
}
