// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЛИЦО ПРИЛОЖЕНИЯ: ИКОНКА, ПРАВООБЛАДАТЕЛЬ, ОСТАТКИ ШАБЛОНА.
//
// 🔴 ЧТО СЛУЧИЛОСЬ. В `macos/Runner/Assets.xcassets` до 23.09.2026 лежали
// СТАНДАРТНЫЕ иконки Flutter — синяя галка из `flutter create`. Их никто не
// заменил, и выпуск 1.8.51 — заверенный, выложенный на свой сервер обновлений —
// показывал в Dock, в Finder и в образе диска чужой логотип.
//
// Проскочило это потому, что иконку никто не проверяет: она не влияет ни на
// сборку, ни на тесты, а глазами её видят уже после выкладки.
//
// 🔴 ПОЧЕМУ ФОРМА, А НЕ ПРОСТО «КАРТИНКА НЕ ТА». У iOS и macOS РАЗНАЯ иконка:
// телефонная — квадрат во всё поле, маску накладывает система. macOS не
// накладывает ничего. Скопировать телефонную значит получить единственный
// острый угол в Dock. Поэтому проверяются оба свойства: углы прозрачны (форма
// macOS соблюдена) и середина тёмная (марка наша, а не светлая шаблонная).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final dir = Directory('macos/Runner/Assets.xcassets/AppIcon.appiconset');

  test('набор иконок macOS на месте — все семь размеров', () {
    if (!dir.existsSync()) return; // в опубликованном дереве файла может не быть
    for (final s in [16, 32, 64, 128, 256, 512, 1024]) {
      final f = File('${dir.path}/app_icon_$s.png');
      expect(f.existsSync(), isTrue, reason: 'нет app_icon_$s.png');
      final im = img.decodePng(f.readAsBytesSync())!;
      expect(im.width, s, reason: 'app_icon_$s.png не $s точек шириной');
      expect(im.height, s);
    }
  });

  test('🔴 иконка НАША: углы прозрачны, середина тёмная', () {
    final f = File('${dir.path}/app_icon_1024.png');
    if (!f.existsSync()) return;
    final im = img.decodePng(f.readAsBytesSync())!;

    // Угол. У шаблонной иконки Flutter там светлая подложка со скруглением
    // другой формы, у скопированной телефонной — непрозрачный чёрный квадрат.
    final corner = im.getPixel(6, 6);
    expect(
      corner.a,
      lessThan(32),
      reason: 'угол непрозрачен — это квадрат, а не форма macOS',
    );

    // Тело иконки. Наша марка — белый знак на ЧЁРНОМ, как на iOS и на Android;
    // шаблонная Flutter — синяя на светлом.
    //
    // 🔴 Берём СРЕДНЮЮ яркость тела, а не одну точку: ровно в середине у нашей
    // марки белая буква, и проверка по центральному пикселю отвергала бы
    // правильную иконку.
    var sum = 0.0;
    var n = 0;
    for (var y = 180; y < 844; y += 8) {
      for (var x = 180; x < 844; x += 8) {
        final c = im.getPixel(x, y);
        if (c.a < 200) continue;
        sum += c.r * 0.299 + c.g * 0.587 + c.b * 0.114;
        n++;
      }
    }
    expect(n, greaterThan(1000), reason: 'тело иконки прозрачно — иконки нет');
    expect(
      sum / n,
      lessThan(90),
      reason: 'тело светлое — похоже на шаблонную иконку Flutter',
    );
  });

  test('иконка строится СКРИПТОМ, а не приносится неизвестно откуда', () {
    // Для репозитория, который читают аудиторы, происхождение картинки — часть
    // происхождения сборки.
    expect(File('tool/make_macos_icons.py').existsSync(), isTrue);
  });

  test('🔴 правообладатель — лицо, а не обломок идентификатора', () {
    // Та же беда, что с иконкой, и найдена там же: `flutter create` подставляет
    // в копирайт обратное доменное имя («com.secretly»), и это уехало в
    // заверенный выпуск 1.8.51 — в «Свойствах» пакета стояло, что права
    // принадлежат сущности, которой не существует.
    //
    // Имя сверяется с заголовками SPDX: на вопрос «кому принадлежит этот код»
    // проект не может отвечать в двух местах по-разному.
    const holder = 'Yurii Arkhanhelskyi';

    final mac = File('macos/Runner/Configs/AppInfo.xcconfig');
    if (mac.existsSync()) {
      final s = mac.readAsStringSync();
      expect(s, contains('PRODUCT_COPYRIGHT'));
      expect(
        s.contains('com.secretly. All rights'),
        isFalse,
        reason: 'в копирайте macOS вернулась подстановка flutter create',
      );
      expect(s, contains(holder));
    }

    final win = File('windows/runner/Runner.rc');
    if (win.existsSync()) {
      final s = win.readAsStringSync();
      expect(
        s.contains('"com.secretly"'),
        isFalse,
        reason: 'в свойствах Windows вернулась подстановка flutter create',
      );
      expect(s, contains(holder));
    }

    // И то же имя стоит в заголовке исходника — источник истины один.
    final src = File('lib/main_desktop.dart');
    if (src.existsSync()) {
      expect(src.readAsStringSync(), contains(holder));
    }
  });

  test('🔴 остатков шаблона «flutter create» не осталось', () {
    // Иконка и правообладатель были не единственными. Такие подстановки
    // объединяет одно: на сборку они не влияют, в тестах не участвуют — и
    // живут ровно до того дня, когда их увидит посторонний. Репозиторий
    // читают аудиторы, поэтому здесь проверка, а не «вроде поправили».
    const junk = <String>[
      'A new Flutter project',
      'com.example',
      'Your Company',
    ];
    for (final rel in const [
      'web/index.html',
      'web/manifest.json',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'windows/runner/Runner.rc',
    ]) {
      final f = File(rel);
      if (!f.existsSync()) continue;
      final s = f.readAsStringSync();
      for (final j in junk) {
        expect(
          s.contains(j),
          isFalse,
          reason: '$rel: вернулась подстановка «$j»',
        );
      }
    }
  });
}
