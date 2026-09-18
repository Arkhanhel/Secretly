// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import 'dart:io';

/// Есть ли в этой копии репозитория настоящие художественные файлы.
///
/// Иконки, обои, звуки и оформление профиля в публичную выкладку не входят:
/// их лицензии разрешают использование внутри приложения, но не
/// распространение файлами (см. `NOTICE`). Скрипт выкладки кладёт вместо них
/// заглушки — прозрачный PNG 1×1, пустой JSON — и помечает такие каталоги
/// файлом `PLACEHOLDER.md`.
///
/// Тесту, который проверяет сам файл — размер картинки, длительность звука,
/// содержимое анимации, — в такой копии проверять нечего. Он должен не падать,
/// а честно пропускаться с объяснением: иначе публичный CI горит красным по
/// причине, которую снаружи не разобрать, и выглядит это как сломанный проект,
/// а не как сознательно не опубликованные ассеты.
///
/// В рабочем репозитории заглушек нет, флаг ложный, и все такие тесты
/// выполняются как обычно — защита никуда не девается.
///
/// Применение:
/// ```dart
/// test('обои нужного размера', () { ... },
///     skip: artAssetsArePlaceholders ? artAssetsSkipReason : null);
/// ```
// Переменная верхнего уровня в Dart и так вычисляется лениво при первом
// обращении, поэтому `late` здесь не нужен — анализатор на него ругается.
final bool artAssetsArePlaceholders = _detectPlaceholders();

/// Причина пропуска. Отдельной константой, чтобы во всех тестах она читалась
/// одинаково и человек, увидевший «skipped» в CI, сразу понял, в чём дело.
const String artAssetsSkipReason =
    'art assets are not part of the public repository — their licences allow '
    'use inside the application but not redistribution as files (see NOTICE). '
    'This test checks the asset files themselves, so there is nothing to check '
    'in this copy. It runs in full in the development repository.';

bool _detectPlaceholders() {
  final assets = Directory('assets');
  if (!assets.existsSync()) return true;
  try {
    return assets
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .any((f) => f.uri.pathSegments.last == 'PLACEHOLDER.md');
  } on FileSystemException {
    // Не смогли прочитать — считаем, что ассеты на месте, и пусть тест
    // упадёт честно, а не пропустится по недосмотру.
    return false;
  }
}
