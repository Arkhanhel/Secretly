// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Запуск при входе в систему.
//
// 🔴 ЭТО НЕ УДОБСТВО, А УСЛОВИЕ ДОСТАВКИ. Окно живёт в трее, и сообщения
// приходят, пока приложение ЗАПУЩЕНО. Не запущенное не получает ничего — и
// человек узнаёт о разговоре тогда, когда сам вспомнит открыть Secretly. На
// телефоне за доставку отвечает система; на компьютере — мы.
//
// Проверяется главное свойство: состояние живёт В СИСТЕМЕ, а не у нас.
// Человек может отменить автозапуск в «Объектах входа», и переключатель обязан
// это показать, а не спорить со своим сохранённым «включено».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_login_item_service.dart';

void main() {
  final svc = DesktopLoginItemService.instance;

  setUp(() {
    svc.available.value = false;
    svc.enabled.value = false;
    svc.needsApproval.value = false;
    svc.lastError = null;
  });
  tearDown(() => DesktopLoginItemService.debugProbe = null);

  test('система не умеет — переключателя нет', () async {
    DesktopLoginItemService.debugProbe =
        (m, on) async => {'available': false, 'enabled': false};
    await svc.refresh();
    expect(svc.available.value, isFalse);
  });

  test('включение доходит до системы и подтверждается ЕЮ', () async {
    var stored = false;
    DesktopLoginItemService.debugProbe = (m, on) async {
      if (m == 'setEnabled') stored = on ?? false;
      return {'available': true, 'enabled': stored};
    };
    await svc.refresh();
    expect(await svc.setEnabled(true), isTrue);
    expect(svc.enabled.value, isTrue);
    expect(await svc.setEnabled(false), isTrue);
    expect(svc.enabled.value, isFalse);
  });

  test('🔴 система сказала «нет» — показываем ЕЁ ответ, а не желаемое',
      () async {
    // Иначе переключатель встанет в «включено», автозапуска не будет, и
    // человек будет уверен, что сообщения придут.
    DesktopLoginItemService.debugProbe = (m, on) async {
      if (m == 'setEnabled') throw PlatformExceptionStub('отказано');
      return {'available': true, 'enabled': false};
    };
    await svc.refresh();
    expect(await svc.setEnabled(true), isFalse);
    expect(svc.enabled.value, isFalse);
    expect(svc.lastError, isNotNull);
  });

  test('🔴 выключено снаружи — переключатель это показывает', () async {
    // Человек отменил объект входа в системных настройках. Наше сохранённое
    // «включено» разошлось бы с правдой в первый же такой раз.
    DesktopLoginItemService.debugProbe = (m, on) async =>
        {'available': true, 'enabled': false, 'needsApproval': true};
    await svc.refresh();
    expect(svc.enabled.value, isFalse);
    expect(svc.needsApproval.value, isTrue);
  });

  test('🔴 своего состояния не храним', () {
    // Сторож: никакого SharedPreferences в этой службе. Своё сохранённое
    // значение неизбежно разойдётся с системой.
    final src = File(
      'lib/ui/desktop/services/desktop_login_item_service.dart',
    ).readAsStringSync();
    expect(src.contains('SharedPreferences'), isFalse);
  });

  test('строка в настройках появляется ТОЛЬКО когда система умеет', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(src.contains('if (!available) return const SizedBox.shrink();'),
        isTrue);
    expect(src.contains('desktopGeneralLaunchAtLogin'), isTrue);
  });
}

/// Подделка под исключение платформенного канала: настоящий класс тянет
/// зависимость на привязку Flutter, которой в чистом тесте нет.
class PlatformExceptionStub implements Exception {
  PlatformExceptionStub(this.message);
  final String message;
  @override
  String toString() => message;
}
