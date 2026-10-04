// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// 🔴 ЭМОДЗИ НА WINDOWS — NOTO, КАК НА ТЕЛЕФОНЕ (30.09.2026, Э1).
///
/// Владелец: эмодзи на Windows «как из аськи». Своего шрифта эмодзи в сборке
/// не было, и Windows подставляла Segoe UI Emoji — плоский, а на Windows 10
/// ещё и с чёрным контуром. Телефон рисует Noto (Android) и Apple (iOS),
/// macOS — Apple Color Emoji, как iPhone. Не совпадала только Windows.
///
/// Правка — только Windows:
///   * файл [kDesktopEmojiFontFileName] едет ТОЛЬКО в сборку Windows
///     (`windows/fonts` → `data\`, правило в `windows/CMakeLists.txt`).
///     Ассетом pubspec он НЕ заявлен: телефон и macOS байт-в-байт прежние;
///   * `main_desktop.dart` грузит его до `runApp` под именем
///     [kDesktopEmojiFontFamily] (`DesktopEmojiFontLoader`);
///   * текст ПК получает это имя в `fontFamilyFallback` в трёх местах: в
///     стилях `DType`, в теме (`desktopMaterialTheme`) и в стиле по умолчанию
///     над навигатором обоих `MaterialApp` ПК (главное окно и отдельные окна
///     ОС — звонки, уведомления).
///
/// 🔴 ПОЧЕМУ ОДНОЙ ТЕМЫ МАЛО. Движок наследует запасные шрифты ВМЕСТЕ с
/// семейством: если у вложенного куска текста (`TextSpan`) своё семейство,
/// его список ЗАМЕНЯЕТ список родителя целиком. У нас почти каждый стиль —
/// `DType` с явным Manrope, а пузырь сообщения — это вложенные куски
/// (разметка, упоминания, ссылки). С запасным шрифтом только в теме эмодзи в
/// пузыре снова уходили бы в Segoe. Проверено замером, а не рассуждением:
/// `test/desktop_emoji_font_windows_test.dart`, «правило движка».
///
/// 🔴 ПОЧЕМУ ПЕРЕД NOTO СТОИТ MANROPE. Если первого семейства стиля на
/// машине нет (у просмотра текстовых файлов — `monospace`, на Windows такого
/// семейства нет), движок берёт ПЕРВЫЙ найденный шрифт списка как основной.
/// Будь это Noto — пробелы и цифры (в Noto они есть, шириной с эмодзи)
/// разъехались бы на весь текст. Manrope вшит в сборку и есть всегда, поэтому
/// основным шрифтом Noto не станет никогда: ему достаётся только то, чего нет
/// в тексте.
///
/// На macOS запасного шрифта нет вовсе: стили — ровно прежние объекты, Apple
/// Color Emoji подставляет сама система.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Имя, под которым файл Noto регистрируется в движке.
///
/// 🔴 НЕ «Noto Color Emoji» и не «NotoColorEmoji». Оба имени стоят в
/// телефонных списках `fontFamilyFallback` (`kEmojiFontFallback` в
/// `chat_screen.dart`, список статуса в `noto_status_emoji.dart`). Шрифт под
/// таким именем перехватил бы эмодзи и там — а на iPhone этот формат (цветные
/// картинки CBDT) не рисуется вовсе: вместо смайликов были бы пустые места.
/// Своё имя ни с чьим списком не совпадёт.
const String kDesktopEmojiFontFamily = 'SecretlyEmoji';

/// Файл в `data\` рядом с `Secretly.exe`; кладёт его `windows/CMakeLists.txt`.
///
/// Вариант `WindowsCompatible` — сборка Noto для Windows: те же цветные
/// картинки (таблицы CBDT/CBLC), плюс пустые служебные таблицы `glyf`/`loca`,
/// которых ждёт DirectWrite. Откуда взят и чем проверен — в
/// `assets/fonts/LICENSES.md`.
const String kDesktopEmojiFontFileName = 'NotoColorEmoji_WindowsCompatible.ttf';

/// Где нужен наш шрифт эмодзи — решается здесь, одним местом.
abstract final class DesktopEmojiFont {
  /// Подмена ОС для тестов: `true` — «это Windows», `false` — «не Windows»,
  /// `null` — настоящая ОС.
  ///
  /// 🔴 Без подмены ветка Windows не проверялась бы нигде: тесты идут на
  /// macOS и Linux, где ранний выход по ОС молча проглотил бы любую ошибку в
  /// ней. Тест обязан вернуть `null` после себя.
  @visibleForTesting
  static bool? debugWindowsOverride;

  static final bool _hostIsWindows = !kIsWeb && Platform.isWindows;

  /// Нужен ли тексту ПК наш шрифт эмодзи. Только Windows.
  static bool get enabled => debugWindowsOverride ?? _hostIsWindows;
}
