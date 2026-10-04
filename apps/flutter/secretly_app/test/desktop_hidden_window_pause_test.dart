// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СПРЯТАННОЕ ОКНО НЕ ПЕРЕЧИТЫВАЕТ БАЗУ (01.10.2026).
//
// Окно в трее продолжало на каждый тик контроллера перечитывать список чатов
// с превью и открытую переписку с расшифровкой — для экрана, которого никто не
// видит. Модель окна теперь слушает видимость и ставит пересчёт на паузу;
// снятие паузы — один догоняющий проход (сам механизм проверяет
// `desktop_selector_test.dart`).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('модель окна стоит на паузе, пока окно спрятано', () {
    final visible = ValueNotifier<bool>(true);
    final vm = DesktopAppViewModel(
      controller: AppController(),
      windowVisible: visible,
    );
    addTearDown(() {
      vm.dispose();
      visible.dispose();
    });

    expect(vm.isPaused, isFalse);
    visible.value = false;
    expect(vm.isPaused, isTrue);
    visible.value = true;
    expect(vm.isPaused, isFalse);
  });

  test('окно, спрятанное ещё до модели, ставит паузу сразу', () {
    final visible = ValueNotifier<bool>(false);
    final vm = DesktopAppViewModel(
      controller: AppController(),
      windowVisible: visible,
    );
    addTearDown(() {
      vm.dispose();
      visible.dispose();
    });

    expect(vm.isPaused, isTrue);
  });

  test('после dispose модель видимость больше не слушает', () {
    final visible = _CountingNotifier(true);
    DesktopAppViewModel(
      controller: AppController(),
      windowVisible: visible,
    ).dispose();
    addTearDown(visible.dispose);

    expect(visible.listeners, 0);
    // Снятая подписка: переключение не трогает закрытый пересчёт.
    visible.value = false;
  });

  test('без источника видимости модель на паузу не встаёт', () {
    final vm = DesktopAppViewModel(controller: AppController());
    addTearDown(vm.dispose);
    expect(vm.isPaused, isFalse);
  });
}

/// Считает подписчиков: `hasListeners` у `ValueNotifier` защищён.
class _CountingNotifier extends ValueNotifier<bool> {
  _CountingNotifier(super.value);

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}
