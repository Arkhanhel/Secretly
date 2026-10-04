// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// АВТОЗАПУСК НА WINDOWS — КЛЮЧ `Run` ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ.
///
/// 🔴 ЗАЧЕМ (28.09.2026). Автозапуск на ПК — условие доставки: не запущенное
/// приложение не получает ничего. На macOS он был давно (`SMAppService`), на
/// Windows переключателя не было вовсе.
///
/// Как у всех приложений на пользователя: значение `Secretly` в
/// `HKCU\…\CurrentVersion\Run` с путём к программе и `--autostart`. Права
/// администратора не нужны, установщик ставит программу в профиль человека.
///
/// Выключить автозапуск человек может и снаружи — в «Диспетчере задач →
/// Автозагрузка». Windows пишет это в `…\Explorer\StartupApproved\Run`
/// (первый байт с младшим битом 1 — выключено). Такое выключение мы НЕ
/// перебиваем: переключатель показывает «выключено в диспетчере задач».
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:win32_registry/win32_registry.dart';

const String kWindowsRunKeyPath =
    r'Software\Microsoft\Windows\CurrentVersion\Run';
const String kWindowsStartupApprovedPath =
    r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
const String kWindowsRunValueName = 'Secretly';

/// Аргумент, с которым Windows запускает нас при входе.
const String kDesktopAutostartArg = '--autostart';

/// «Запускать свёрнутым»: окно не показывается, приложение ждёт в трее.
/// Его читает и раннер (flutter_window.cpp) — чтобы окно не мелькнуло.
const String kDesktopMinimizedArg = '--minimized';

/// Строка запуска: путь в кавычках (в нём бывают пробелы) и признаки.
String windowsAutostartCommand(String exe, {bool minimized = false}) =>
    '"$exe" $kDesktopAutostartArg${minimized ? ' $kDesktopMinimizedArg' : ''}';

/// Указывает ли запись `Run` на ЭТУ программу. Чистая функция.
bool windowsRunEntryPointsTo(String? entry, String exe) {
  if (entry == null) return false;
  return entry.toLowerCase().contains(exe.toLowerCase());
}

/// Выключил ли человек автозапуск в «Диспетчере задач». Чистая функция.
bool windowsStartupApprovedDisabled(Uint8List? data) {
  if (data == null || data.isEmpty) return false;
  return (data.first & 0x01) == 0x01;
}

Uint8List? _startupApproved() {
  RegistryKey? key;
  try {
    key = Registry.openPath(
      RegistryHive.currentUser,
      path: kWindowsStartupApprovedPath,
    );
    final value = key.getValue(kWindowsRunValueName);
    return value is BinaryValue ? value.value : null;
  } catch (_) {
    return null;
  } finally {
    key?.close();
  }
}

/// То же, что отдаёт мост macOS: `available`, `enabled`, `needsApproval`.
Map<String, dynamic> windowsLoginItemStatus() {
  final exe = Platform.resolvedExecutable;
  RegistryKey? key;
  try {
    key = Registry.openPath(RegistryHive.currentUser, path: kWindowsRunKeyPath);
    final ours = windowsRunEntryPointsTo(
      key.getStringValue(kWindowsRunValueName),
      exe,
    );
    final disabled = windowsStartupApprovedDisabled(_startupApproved());
    return <String, dynamic>{
      'available': true,
      'enabled': ours && !disabled,
      'needsApproval': ours && disabled,
    };
  } catch (_) {
    return <String, dynamic>{
      'available': true,
      'enabled': false,
      'needsApproval': false,
    };
  } finally {
    key?.close();
  }
}

/// Включить или выключить. Возвращает новое состояние.
///
/// [minimized] — «Запускать свёрнутым»: при повторной записи с новым
/// значением запись просто переписывается.
Map<String, dynamic> windowsLoginItemSetEnabled(
  bool on, {
  bool minimized = true,
}) {
  RegistryKey? key;
  try {
    key = Registry.openPath(
      RegistryHive.currentUser,
      path: kWindowsRunKeyPath,
      desiredAccessRights: AccessRights.allAccess,
    );
    if (on) {
      key.createValue(
        RegistryValue.string(
          kWindowsRunValueName,
          windowsAutostartCommand(
            Platform.resolvedExecutable,
            minimized: minimized,
          ),
        ),
      );
    } else {
      try {
        key.deleteValue(kWindowsRunValueName);
      } catch (_) {
        // Значения и так нет — выключено.
      }
    }
  } finally {
    key?.close();
  }
  return windowsLoginItemStatus();
}
