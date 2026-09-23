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

  test('🔴 починка ffmpeg в выпуске НЕ переподписывает всё приложение', () {
    // 23.09.2026 выпуск 1.8.53 вернулся от Apple со статусом Invalid. Починка
    // зависимостей заканчивалась `codesign --deep`, и он переподписывал
    // помощников Sparkle (Updater, Autoupdate, Downloader, Installer): те
    // теряли hardened runtime и получали отладочное право get-task-allow.
    // Выпуску эта переподпись не нужна — он подписывает всё сам следом.
    if (!f.existsSync()) return;
    final s = f.readAsStringSync();
    final fix = s.indexOf('desktop_fix_ffmpeg_deps.sh');
    expect(fix, greaterThan(0));
    final around = s.substring((fix - 200).clamp(0, s.length), fix);
    expect(
      around.contains('SECRETLY_FFMPEG_FIX_NO_RESIGN=1'),
      isTrue,
      reason: 'выпуск снова разрешил глубокую переподпись',
    );
    final fixer = File('tools/desktop_fix_ffmpeg_deps.sh');
    if (fixer.existsSync()) {
      final t = fixer.readAsStringSync();
      final gate = t.indexOf('SECRETLY_FFMPEG_FIX_NO_RESIGN');
      // Ищем саму команду, а не упоминание в пояснении выше.
      final deep = t.indexOf('codesign --force --deep');
      expect(gate, greaterThan(0), reason: 'починка не знает о запрете');
      expect(gate, lessThan(deep), reason: 'запрет стоит после --deep');
    }
  });

  test('🔴 помощники Sparkle подписываются ПЕРВЫМИ и своим сертификатом', () {
    // 23.09.2026, вторая попытка заверения 1.8.53: «не подписано действующим
    // Developer ID» и «нет метки времени» по Installer, Downloader, Autoupdate
    // и Updater. Цикл подписи ищет библиотеки и фреймворки, а подпись
    // фреймворка целиком вложенные программы не переподписывает.
    if (!f.existsSync()) return;
    final s = f.readAsStringSync();
    final helpers = s.indexOf(r'"$sparkle_b/XPCServices/Installer.xpc"');
    final loop = s.indexOf(r"\( -name '*.dylib'");
    expect(helpers, greaterThan(0), reason: 'помощников Sparkle никто не подписывает');
    expect(loop, greaterThan(0));
    expect(helpers, lessThan(loop), reason: 'помощники должны идти ДО фреймворка');
    for (final h in const ['Downloader.xpc', 'Autoupdate', 'Updater.app']) {
      expect(s.contains(h), isTrue, reason: '$h выпал из списка');
    }
  });

  test('🔴 точка входа компьютера существует и строит своё окно', () {
    // Ловушка наоборот: если файл переименуют, скрипт будет ссылаться в пустоту
    // и сборка упадёт — но лучше узнать об этом здесь.
    final entry = File('lib/main_desktop.dart');
    expect(entry.existsSync(), isTrue);
    expect(entry.readAsStringSync(), contains('DesktopProductionApp'));
  });
}
