// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПОРТРЕТ ДЕКОДИРУЕТСЯ ПОД РАЗМЕР НА ЭКРАНЕ (01.10.2026).
//
// Фото профиля в тысячи точек рисуется кружком в 36, а декодировалось
// целиком — мегабайты на каждую строку списка в кэше картинок.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';

void main() {
  test('файл декодируется под размер × плотность, с шагом 32', () {
    final out = desktopAvatarImage(FileImage(File('/tmp/a.jpg')), 36, 2);
    expect(out, isA<ResizeImage>());
    final resized = out as ResizeImage;
    expect(resized.width, 96, reason: '36 × 2 = 72 → вверх до 96');
    expect(resized.height, isNull, reason: 'высота — по пропорциям фото');
  });

  test('соседние размеры делят один декод', () {
    final a = desktopAvatarImage(FileImage(File('/tmp/a.jpg')), 36, 2);
    final b = desktopAvatarImage(FileImage(File('/tmp/a.jpg')), 40, 2);
    expect((a as ResizeImage).width, (b as ResizeImage).width);
  });

  test('байты из памяти ужимаются так же', () {
    final out = desktopAvatarImage(MemoryImage(Uint8List(4)), 12, 1);
    expect(out, isA<ResizeImage>());
    expect((out as ResizeImage).width, 32);
  });

  test('прочие источники не трогаются', () {
    const asset = AssetImage('assets/x.png');
    expect(identical(desktopAvatarImage(asset, 36, 2), asset), isTrue);
  });

  test('потолок кэша картинок задан во входе ПК', () {
    final main = File('lib/main_desktop.dart').readAsStringSync();
    expect(
      main.contains('imageCache.maximumSizeBytes = 150 * 1024 * 1024'),
      isTrue,
    );
  });
}
