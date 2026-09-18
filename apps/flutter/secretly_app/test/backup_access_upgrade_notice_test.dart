// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';

/// ЗАМЕР ПРОДА (01.09.2026): 75,8 % устройств уже на сборках, умеющих опору
/// токена доступа к архиву (SEC-01, Э-1), а несут её лишь 18,7 % архивов.
///
/// Причина разрыва: опора выводится из пароля В МОМЕНТ сохранения, поэтому
/// обновление приложения её не создаёт — нужно пересохранить копию. Владелец
/// об этом узнать не может: снаружи защищённый и незащищённый архив выглядят
/// одинаково (сервер намеренно отвечает одинаково, отдавая обманную соль).
///
/// Отсюда подсказка на экране копии, и отсюда же её единственное правило:
/// она обязана молчать везде, кроме случая «копия на сервере есть, опоры нет».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<AppController> controllerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = AppController();
    await c.loadSafeBackupPrefsForTesting();
    return c;
  }

  test('серверной копии нет — подсказка молчит', () async {
    final c = await controllerWith(<String, Object>{});
    expect(c.hasServerBackupCopy, isFalse);
    expect(
      c.serverBackupNeedsAccessUpgrade,
      isFalse,
      reason: 'предлагать пересохранить то, чего нет, — это шум',
    );
  });

  test('копия есть, опоры нет — подсказка показывается', () async {
    final c = await controllerWith(<String, Object>{
      'safe_backup_last_server_saved_at_ms_v1':
          DateTime.now().millisecondsSinceEpoch,
    });
    expect(c.hasServerBackupCopy, isTrue);
    expect(
      c.serverBackupNeedsAccessUpgrade,
      isTrue,
      reason: 'это ровно те 139 архивов из замера, которые отдаются '
          'по одному идентификатору профиля',
    );
  });

  test('копия пересохранена с опорой — подсказка исчезает', () async {
    final c = await controllerWith(<String, Object>{
      'safe_backup_last_server_saved_at_ms_v1':
          DateTime.now().millisecondsSinceEpoch,
      'safe_backup_server_access_bound_v1': true,
    });
    expect(c.serverBackupNeedsAccessUpgrade, isFalse);
  });

  test('опора записана как false — подсказка возвращается', () async {
    // Флаг пишется фактическим результатом отправки, а не намерением: если
    // опора почему-то не ушла, человек обязан увидеть подсказку снова.
    final c = await controllerWith(<String, Object>{
      'safe_backup_last_server_saved_at_ms_v1':
          DateTime.now().millisecondsSinceEpoch,
      'safe_backup_server_access_bound_v1': false,
    });
    expect(c.serverBackupNeedsAccessUpgrade, isTrue);
  });

  test('подсказка не подменяет собой статус защиты', () async {
    // Копия без опоры — всё ещё копия: история защищена, и заголовок обязан
    // говорить именно это. Подсказка добавляет рубеж, а не отменяет факт.
    final c = await controllerWith(<String, Object>{
      'safe_backup_auto_enabled_v1': true,
      'safe_backup_last_server_saved_at_ms_v1':
          DateTime.now().millisecondsSinceEpoch,
    });
    expect(c.serverBackupNeedsAccessUpgrade, isTrue);
    expect(c.safeBackupLastAnySuccessAtMs, greaterThan(0));
    expect(c.safeBackupHealth, isNot(SafeBackupHealth.pending));
  });
}
