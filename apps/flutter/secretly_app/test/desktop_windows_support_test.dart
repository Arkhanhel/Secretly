// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОДДЕРЖКА WINDOWS: ЗВУК, ВИДЕО, УВЕДОМЛЕНИЯ.
//
// 🔴 Компьютерная версия собирается под Windows, но три вещи там не работали
// вовсе, потому что пакеты этой системы не поддерживают:
//   • голосовые и музыка — `just_audio`;
//   • видео в ленте — `video_player`;
//   • уведомления — `flutter_local_notifications` 17-й версии.
//
// Подняли не версии (пакеты общие с выпущенной мобильной сборкой — её нельзя
// трогать), а добавили реализации ТОЛЬКО под Windows. Звук и видео
// подключаются сами, уведомления идут своим путём.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Файл сборочного задания лежит по-разному: в рабочем дереве — в
/// `docs/public/github/`, в публичной выкладке он же разложен в `.github/`.
/// Ищем в обоих местах, иначе проверка ломается ровно там, ради чего её и
/// писали — в публичной копии.
File? _ciWorkflow() {
  for (final path in const [
    '../../../docs/public/github/workflows/ci.yml',
    '../../../.github/workflows/ci.yml',
  ]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  return null;
}

void main() {
  test('🔴 пакеты для Windows объявлены', () {
    final pubspec = _read('pubspec.yaml');
    for (final dep in const [
      'just_audio_windows', // звук: реализация нативная, регистрируется сама
      'video_player_win', // видео: объявлено как реализация video_player
      'local_notifier', // уведомления Windows
    ]) {
      expect(pubspec.contains('$dep:'), isTrue, reason: dep);
    }
  });

  test('🔴 мобильную сборку это не утяжеляет', () {
    // Пакеты объявлены под Windows (у local_notifier ещё macOS и Linux), а
    // мобильных платформ у них нет — иначе выпущенная версия потолстела бы.
    final lock = _read('pubspec.lock');
    for (final dep in const [
      'just_audio_windows',
      'video_player_win',
      'local_notifier',
    ]) {
      expect(lock.contains('  $dep:'), isTrue, reason: '$dep нет в pubspec.lock');
    }
  });

  group('уведомления', () {
    final service = _read('lib/ui/desktop/services/desktop_notification_service.dart');

    test('🔴 на Windows не зовут пакет, который её не поддерживает', () {
      final guard = service.indexOf('if (_usesLocalNotifier) {');
      final init = service.indexOf('_plugin.initialize(');
      expect(guard, greaterThan(0));
      expect(init, greaterThan(0));
      expect(
        guard < init,
        isTrue,
        reason: 'initialize 17-й версии на Windows падает, и служба считала бы '
            'себя неготовой — то есть ни одного уведомления',
      );
    });

    test('показ идёт одной дорогой для обеих систем', () {
      // `_plugin.show(` должен остаться ровно один — внутри `_present`.
      final shows = RegExp(r'_plugin\.show\(').allMatches(service).length;
      expect(shows, 1, reason: 'показ расползся мимо общей дороги');
      expect(service.contains('LocalNotification('), isTrue);
    });

    test('нажатие по уведомлению Windows ведёт в переписку', () {
      final at = service.indexOf('LocalNotification(');
      final tail = service.substring(at, at + 400);
      expect(tail.contains('onClick'), isTrue);
      expect(tail.contains('_tapController.add(payload)'), isTrue);
    });

    test('🔴 беззвучный режим соблюдается и там', () {
      final at = service.indexOf('LocalNotification(');
      expect(service.substring(at, at + 200).contains('silent: !_soundEnabled'), isTrue);
    });
  });

  test(
    'сборка под Windows проверяется на CI',
    () {
      final ci = _ciWorkflow()!.readAsStringSync();
      expect(ci.contains('runs-on: windows-latest'), isTrue);
      expect(ci.contains('flutter build windows --release'), isTrue);
    },
    skip: _ciWorkflow() == null
        ? 'файла сборочного задания нет в этой копии дерева'
        : null,
  );
}
