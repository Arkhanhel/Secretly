// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Play, отзыв 7.11.2026 (Redmi A5): «не дало закончить настройку аккаунта».
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 первый запуск телефона ждёт создания профиля до минуты', () {
    expect(
      AppController.firstRunKeysSetupTimeout(hasProfile: false, desktop: false),
      const Duration(seconds: 60),
    );
  });

  test('профиль уже есть или это ПК — запуск не замедляется (10 с)', () {
    expect(
      AppController.firstRunKeysSetupTimeout(hasProfile: true, desktop: false),
      const Duration(seconds: 10),
    );
    expect(
      AppController.firstRunKeysSetupTimeout(hasProfile: false, desktop: true),
      const Duration(seconds: 10),
    );
  });

  test('без профиля — «профиль не готов» (страница копии не держит)', () {
    expect(AppController().hasServerProfile, isFalse);
  });
}
