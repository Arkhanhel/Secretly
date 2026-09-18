// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/security/safe_backup_prefs.dart';

// Перенос настроек в копию (07.08.2026).
//
// Полевая жалоба: «после восстановления не восстанавливаются многие настройки».
// Копия несла СЕМЬ значений при 77 ключах в приложении. Причина не в лени, а в
// направлении отказа: при белом списке новая настройка по умолчанию НЕ попадает
// в копию и никто об этом не узнаёт.
//
// Здесь закрепляется само направление: переносится всё, кроме явно исключённого.

void main() {
  group('что переносится, а что нет', () {
    test('настройки человека переносятся', () {
      for (final key in const [
        'app_locale_v1',
        'dark_mode_v1',
        'notif_private_messages_v1',
        'default_chat_wallpaper_v1',
        'calls_enabled_v1',
        'indicator_color_preset_id_v1',
      ]) {
        expect(safeBackupPrefIsPortable(key), isTrue, reason: key);
      }
    });

    test('состояние ЭТОЙ установки не переносится', () {
      // 🔴 `relay_next_seq` самый опасный: чужой курсор ящика заставит клиента
      // считать полученным то, чего он не получал.
      for (final key in const [
        'relay_next_seq',
        'device_id',
        'install_sentinel_v1',
        'notif_dedup_msg_ids_v1',
        'support_badge_seq_v1',
      ]) {
        expect(safeBackupPrefIsPortable(key), isFalse, reason: key);
      }
    });

    test('новый ключ того же рода исключается САМ, по префиксу', () {
      // Ради этого исключения заданы префиксами, а не списком: иначе следующая
      // `pending_*` тихо поехала бы в копию.
      expect(safeBackupPrefIsPortable('pending_something_new_v2'), isFalse);
      expect(safeBackupPrefIsPortable('last_keys_publish_whatever'), isFalse);
      // Граница именно такая: исключается семейство `pending_*`, а не любое
      // слово, начинающееся на «pending». Настройка вроде `pending_review_ui_v1`
      // была бы состоянием установки и тоже отсеклась бы — это и требуется.
      expect(safeBackupPrefIsPortable('pendingsomething'), isTrue);
    });
  });

  group('типы значений', () {
    test('каждый тип переживает круг без подмены', () {
      final raw = <String, Object?>{
        'b': true,
        'i': 42,
        'd': 1.5,
        's': 'текст',
        'sl': <String>['a', 'b'],
      };
      final decoded = decodeSafeBackupPrefs(collectSafeBackupPrefs(raw));

      expect(decoded['b'], isA<bool>());
      expect(decoded['i'], isA<int>());
      expect(decoded['d'], isA<double>());
      expect(decoded['s'], 'текст');
      expect(decoded['sl'], <String>['a', 'b']);
    });

    test('целое НЕ превращается в дробное', () {
      // JSON не различает 1 и 1.0, а SharedPreferences различает: положить
      // double туда, где приложение ждёт int, значит уронить чтение настройки.
      final decoded = decodeSafeBackupPrefs(
        collectSafeBackupPrefs(<String, Object?>{'x': 1}),
      );
      expect(decoded['x'], 1);
      expect(decoded['x'], isA<int>());
      expect(decoded['x'], isNot(isA<double>()));
    });

    test('неизвестный тип не переносится вовсе', () {
      final collected = collectSafeBackupPrefs(<String, Object?>{
        'weird': DateTime.now(),
      });
      expect(collected, isEmpty, reason: 'лучше значение по умолчанию, чем мусор');
    });

    test('испорченная запись не роняет разбор и не подставляется', () {
      final decoded = decodeSafeBackupPrefs(<String, Object?>{
        'ok': <String, Object?>{'t': 's', 'v': 'цел'},
        'broken_type': <String, Object?>{'t': 'zzz', 'v': 1},
        'broken_shape': 'не карта',
        'mismatch': <String, Object?>{'t': 'b', 'v': 'не булево'},
      });
      expect(decoded, <String, Object?>{'ok': 'цел'});
    });
  });

  test('чёрный список применяется И НА ПРИЁМЕ', () {
    // Копия могла быть снята сборкой, где ключ ещё не считался опасным.
    // Восстановление обязано защищать нынешнее устройство по нынешним правилам.
    final decoded = decodeSafeBackupPrefs(<String, Object?>{
      'relay_next_seq': <String, Object?>{'t': 'i', 'v': 999},
      'app_locale_v1': <String, Object?>{'t': 's', 'v': 'ru'},
    });
    expect(decoded.containsKey('relay_next_seq'), isFalse);
    expect(decoded['app_locale_v1'], 'ru');
  });
}
