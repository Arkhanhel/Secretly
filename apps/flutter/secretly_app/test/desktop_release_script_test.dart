// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ВЫПУСКНОЙ СКРИПТ macOS: ЧТО В НЁМ НЕЛЬЗЯ ПОТЕРЯТЬ.
//
// 23.09.2026 чистая сборка выпускным скриптом дала приложение, которое:
//   1) показывало ТЕЛЕФОННОЕ окно — нижняя полоса вкладок вместо боковой
//      рейки, ни одного компьютерного экрана;
//   2) не открывалось вовсе на машине без Homebrew.
//
// Обе беды одного рода: выпуск зависел не от скрипта, а от того, что осталось
// в каталоге сборки от прошлых запусков. Пока там лежали результаты отладочной
// сборки (она и точку входа задаёт, и библиотеки чинит), выпуск получался
// правильным. Стоило почистить каталог — и он сломался, причём молча: образ
// собирается, подписывается и заверяется как ни в чём не бывало.
//
// Проверка читает сам скрипт. Запускать сборку в тесте нельзя — она идёт
// минуты и требует Xcode, — но потеря двух строк ловится и так.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = File('../../../tools/macos_build_desktop_release.sh');

  test('🔴 выпуск собирает КОМПЬЮТЕРНУЮ точку входа', () {
    if (!f.existsSync()) return; // в опубликованном дереве скрипта нет
    final s = f.readAsStringSync();
    expect(
      s.contains('--target=lib/main_desktop.dart'),
      isTrue,
      reason: 'без этого выпуск уйдёт с телефонным окном',
    );
  });

  test('🔴 выпуск делает образ самодостаточным', () {
    if (!f.existsSync()) return;
    final s = f.readAsStringSync();
    final fix = s.indexOf('desktop_fix_ffmpeg_deps.sh');
    expect(fix, greaterThan(0), reason: 'починку зависимостей не зовут');
    // ДО подписи: починка меняет библиотеки и ставит временную подпись,
    // настоящая должна лечь поверх, иначе проверка увидит чужое содержимое.
    final sign = s.indexOf('── Подпись ──');
    expect(sign, greaterThan(0));
    expect(fix, lessThan(sign), reason: 'починка после подписи ломает подпись');
  });

  test('🔴 точка входа компьютера существует и строит своё окно', () {
    // Ловушка наоборот: если файл переименуют, скрипт будет ссылаться в пустоту
    // и сборка упадёт — но лучше узнать об этом здесь.
    final entry = File('lib/main_desktop.dart');
    expect(entry.existsSync(), isTrue);
    expect(entry.readAsStringSync(), contains('DesktopProductionApp'));
  });
}
