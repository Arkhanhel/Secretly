// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ИКОНКА WINDOWS (29.09.2026, владелец: «Иконка приложения почему-то
// зелёная и квадратная! Должна быть закруглённая!»).
//
// `app_icon.ico` был одним кадром 256 без прозрачности на бирюзе #073A3D —
// его делал старый генератор из `1.png`. Панель задач, «Пуск», установщик и
// «Приложения» показывали бирюзовый квадрат, значки трея — тот же квадрат.
// Теперь всё строит `tools/make_windows_icons.py`: чёрная подложка-сквиркл,
// прозрачные углы, белый знак, все размеры, которые берёт Windows.
//
// Проверяется то, что видно глазами: форма (угол прозрачен), подложка
// (чёрная, а не бирюза), знак (белый) и набор кадров. Мелкие кадры обязательны:
// Windows не уменьшает 256 до 16, а берёт готовый кадр ближайшего размера.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'art_assets_availability.dart';

const _appIcon = 'windows/runner/resources/app_icon.ico';
const _tray = 'assets/desktop/tray';
const _installer = 'windows/installer';

/// Кадры ICO по стороне. Каталог разбирается руками: так видно, что файл —
/// настоящий ICO, а не PNG под чужим расширением, и что кадры лежат в файле.
Map<int, img.Image> _frames(String path) {
  final bytes = File(path).readAsBytesSync();
  final head = ByteData.sublistView(bytes);
  expect(head.getUint16(0, Endian.little), 0, reason: '$path: не ICO');
  expect(head.getUint16(2, Endian.little), 1, reason: '$path: не ICO');
  final count = head.getUint16(4, Endian.little);
  expect(count, greaterThan(0), reason: '$path: в файле нет кадров');

  final decoder = img.IcoDecoder()..startDecode(bytes);
  final frames = <int, img.Image>{};
  for (var i = 0; i < count; i++) {
    final entry = 6 + i * 16;
    final side = bytes[entry] == 0 ? 256 : bytes[entry];
    final length = head.getUint32(entry + 8, Endian.little);
    final offset = head.getUint32(entry + 12, Endian.little);
    expect(
      offset + length,
      lessThanOrEqualTo(bytes.length),
      reason: '$path: кадр $side за концом файла',
    );
    final frame = decoder.decodeFrame(i);
    expect(frame, isNotNull, reason: '$path: кадр $side не читается');
    expect(frame!.width, side, reason: '$path: кадр $side');
    expect(frame.height, side, reason: '$path: кадр $side не квадратный');
    frames[side] = frame;
  }
  return frames;
}

bool _white(img.Pixel p) => p.a > 250 && p.r > 220 && p.g > 220 && p.b > 220;
bool _red(img.Pixel p) => p.a > 250 && p.r > 200 && p.g < 110 && p.b < 110;

/// Есть ли в доле кадра [x0, x1) × [y0, y1) пиксель, прошедший [test].
bool _any(
  img.Image im,
  bool Function(img.Pixel) test, {
  double x0 = 0,
  double y0 = 0,
  double x1 = 1,
  double y1 = 1,
}) {
  for (var y = (im.height * y0).floor(); y < (im.height * y1).ceil(); y++) {
    for (var x = (im.width * x0).floor(); x < (im.width * x1).ceil(); x++) {
      if (test(im.getPixel(x, y))) return true;
    }
  }
  return false;
}

/// Форма и цвет: угол прозрачен, у левого края — чёрная подложка.
void _expectBlackRoundedPlate(img.Image im, String what) {
  expect(
    im.getPixel(0, 0).a,
    0,
    reason: '$what: угол непрозрачен — снова квадрат вместо скругления',
  );
  final plate = im.getPixel((im.width * 0.12).floor(), im.height ~/ 2);
  expect(plate.a, greaterThan(250), reason: '$what: у края нет подложки');
  expect(
    plate.g,
    lessThan(40),
    reason: '$what: подложка не чёрная (у бирюзы #073A3D зелёный — 58)',
  );
  expect(plate.r, lessThan(40), reason: '$what: подложка не чёрная');
  expect(plate.b, lessThan(40), reason: '$what: подложка не чёрная');
}

void main() {
  final skip = artAssetsArePlaceholders ? artAssetsSkipReason : null;

  group('иконка программы (app_icon.ico)', () {
    test('кадры на все масштабы: 16, 20, 24, 32, 48 и 256', () {
      expect(
        _frames(_appIcon).keys,
        containsAll(<int>[16, 20, 24, 32, 48, 256]),
      );
    });

    test('🔴 256: скруглённая чёрная подложка и белый знак', () {
      final im = _frames(_appIcon)[256]!;
      _expectBlackRoundedPlate(im, 'app_icon 256');
      expect(
        _any(im, _white, x0: 0.35, y0: 0.35, x1: 0.65, y1: 0.65),
        isTrue,
        reason: 'в середине нет белого знака',
      );
    });

    test('мелкие кадры тоже скруглённые и со знаком', () {
      final frames = _frames(_appIcon);
      for (final side in const [16, 24, 32]) {
        final im = frames[side]!;
        expect(im.getPixel(0, 0).a, 0, reason: 'угол кадра $side непрозрачен');
        expect(
          _any(im, _white, x0: 0.3, y0: 0.3, x1: 0.7, y1: 0.7),
          isTrue,
          reason: 'в кадре $side знак не читается',
        );
      }
    });
  }, skip: skip);

  group('значки трея', () {
    test('в каждом значке одни и те же кадры, среди них 16, 20, 24, 32', () {
      final normal = _frames('$_tray/tray.ico').keys.toSet();
      expect(normal, containsAll(<int>[16, 20, 24, 32]));
      for (final name in const ['tray_unread.ico', 'tray_muted.ico']) {
        expect(_frames('$_tray/$name').keys.toSet(), normal, reason: name);
      }
    });

    test('🔴 обычный: скруглённая чёрная подложка и белый знак', () {
      final im = _frames('$_tray/tray.ico')[32]!;
      _expectBlackRoundedPlate(im, 'tray 32');
      expect(_any(im, _white, x0: 0.3, y0: 0.3, x1: 0.7, y1: 0.7), isTrue);
      expect(_any(im, _red), isFalse, reason: 'красная точка без повода');
    });

    test('непрочитанное: красная точка в правом верхнем углу', () {
      final frames = _frames('$_tray/tray_unread.ico');
      for (final side in const [16, 32]) {
        final im = frames[side]!;
        expect(im.getPixel(0, 0).a, 0, reason: 'угол кадра $side');
        expect(
          _any(im, _red, x0: 0.5, y1: 0.5),
          isTrue,
          reason: 'в кадре $side нет точки справа сверху',
        );
        expect(
          _any(im, _red, x1: 0.5),
          isFalse,
          reason: 'в кадре $side красное слева — точка не на месте',
        );
      }
    });

    test('без звука: знак серый, белого нет', () {
      final im = _frames('$_tray/tray_muted.ico')[32]!;
      _expectBlackRoundedPlate(im, 'tray_muted 32');
      expect(
        _any(im, _white),
        isFalse,
        reason: 'значок «без звука» не отличить от обычного',
      );
      expect(
        _any(
          im,
          (p) => p.a > 250 && p.r > 100 && p.r < 180,
          x0: 0.3,
          y0: 0.3,
          x1: 0.7,
          y1: 0.7,
        ),
        isTrue,
        reason: 'серого знака нет',
      );
    });
  }, skip: skip);

  group('картинка в шапке установщика', () {
    test('файлы из secretly.iss на месте, квадратные, углы прозрачны', () {
      final iss = File('$_installer/secretly.iss').readAsStringSync();
      final line = RegExp(
        r'^WizardSmallImageFile=([^\r\n]+)',
        multiLine: true,
      ).firstMatch(iss);
      expect(line, isNotNull, reason: 'в сценарии нет WizardSmallImageFile');
      final names = line!.group(1)!.split(',').map((s) => s.trim()).toList();
      expect(names, isNotEmpty);

      // Строка стоит под #if FileExists — в публичной выкладке картинок нет.
      // Проверяемый файл должен быть из списка, иначе переименование молча
      // вернёт встроенную картинку Inno Setup.
      final guard = RegExp(
        r'#if FileExists\(AddBackslash\(SourcePath\) \+ "([^"]+)"\)',
      ).firstMatch(iss);
      expect(guard, isNotNull, reason: 'нет проверки наличия картинок');
      expect(names, contains(guard!.group(1)));

      for (final name in names) {
        final file = File('$_installer/$name');
        expect(file.existsSync(), isTrue, reason: 'нет $name');
        final im = img.decodePng(file.readAsBytesSync());
        expect(im, isNotNull, reason: '$name не PNG');
        final side = int.parse(
          RegExp(r'(\d+)\.png$').firstMatch(name)!.group(1)!,
        );
        expect(im!.width, side, reason: name);
        expect(im.height, side, reason: name);
        expect(im.getPixel(0, 0).a, 0, reason: '$name: угол непрозрачен');
      }
    });
  }, skip: skip);
}
