// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Перенос настроек в резервную копию — ЧЁРНЫМ списком, а не белым.
///
/// 🔴 ПОЧЕМУ НЕ БЕЛЫМ (07.08.2026, полевая жалоба «не восстанавливаются многие
/// настройки»). Копия несла СЕМЬ значений, перечисленных вручную, при 77 ключах
/// настроек в приложении. То есть терялось около семидесяти: язык, тема, все
/// уведомления, обои чатов, звонки, стиль ника, цвета индикаторов.
///
/// Дело не в том, что кто-то поленился дописать. Дело в направлении отказа:
/// при белом списке **новая настройка по умолчанию НЕ попадает в копию**, и
/// никто об этом не узнаёт до чужого восстановления. При чёрном — попадает, и
/// забыть можно только осознанно, дописав ключ в исключения.
///
/// ЧТО ИСКЛЮЧЕНО И ПОЧЕМУ. Не «секреты» — payload и так зашифрован паролем
/// человека и восстанавливается на его же устройство. Исключено то, что
/// привязано к КОНКРЕТНОЙ установке и на другом устройстве означает ложь:
///
///  * `relay_next_seq` — курсор ящика на реле. Самый опасный: перенос чужого
///    курсора заставит клиента считать прочитанным то, чего он не получал.
///  * `device_id` — личность устройства, её переносит ключ восстановления.
///  * `pending_*` — очереди незавершённых действий этой установки.
///  * `last_*_at_ms` — когда ЭТА установка last публиковала ключи и профиль.
///  * `install_sentinel`, `demo_*` — разовые метки первого запуска.
///  * `notif_dedup_msg_ids` — защита от повторов, локальная по построению.
library;

/// Ключи, которые НИКОГДА не едут в копию. Сравнение точное, плюс префиксы
/// ниже — чтобы новая `pending_что_то_v1` исключалась сама.
const Set<String> kSafeBackupPrefsDenyExact = <String>{
  'device_id',
  'relay_next_seq',
  'support_badge_seq_v1',
  'install_sentinel_v1',
  'notif_dedup_msg_ids_v1',
  'desktop_link_requests_v1',
  'demo_purged_v1',
  'demo_seeded_v1',
  'demo_seed_version_v1',
};

/// Префиксы, исключаемые целиком. Смысл тот же: свойство установки, а не выбор
/// человека. Держать их префиксами, а не списком, — единственный способ не
/// проспать новый ключ того же рода.
const List<String> kSafeBackupPrefsDenyPrefixes = <String>[
  'pending_',
  'last_keys_publish',
  'last_meta_publish',
  'last_meta_refresh',
];

bool safeBackupPrefIsPortable(String key) {
  final k = key.trim();
  if (k.isEmpty) return false;
  if (kSafeBackupPrefsDenyExact.contains(k)) return false;
  for (final prefix in kSafeBackupPrefsDenyPrefixes) {
    if (k.startsWith(prefix)) return false;
  }
  return true;
}

/// Значение настройки в переносимом виде.
///
/// Тип пишется рядом со значением НАМЕРЕННО: JSON не различает 1 и 1.0, а
/// `SharedPreferences` различает — положить double там, где приложение ждёт
/// int, значит уронить чтение настройки на восстановленном устройстве.
Map<String, Object?>? encodeSafeBackupPrefValue(Object? value) {
  if (value is bool) return <String, Object?>{'t': 'b', 'v': value};
  if (value is int) return <String, Object?>{'t': 'i', 'v': value};
  if (value is double) return <String, Object?>{'t': 'd', 'v': value};
  if (value is String) return <String, Object?>{'t': 's', 'v': value};
  if (value is List<String>) {
    return <String, Object?>{'t': 'sl', 'v': List<String>.from(value)};
  }
  // Неизвестный тип не переносим: молча привести его к строке значит подсунуть
  // приложению мусор вместо настройки.
  return null;
}

/// Обратное преобразование. Возвращает `null` для всего, что не разобралось, —
/// такая настройка просто остаётся со значением по умолчанию, и это лучше, чем
/// записать в неё испорченное.
Object? decodeSafeBackupPrefValue(Object? encoded) {
  if (encoded is! Map) return null;
  final type = encoded['t'];
  final value = encoded['v'];
  switch (type) {
    case 'b':
      return value is bool ? value : null;
    case 'i':
      return value is int ? value : (value is num ? value.toInt() : null);
    case 'd':
      return value is num ? value.toDouble() : null;
    case 's':
      return value is String ? value : null;
    case 'sl':
      if (value is! List) return null;
      return value.whereType<String>().toList(growable: false);
    default:
      return null;
  }
}

/// Собирает переносимые настройки из «сырой» карты ключ → значение.
Map<String, Object?> collectSafeBackupPrefs(Map<String, Object?> all) {
  final out = <String, Object?>{};
  for (final entry in all.entries) {
    if (!safeBackupPrefIsPortable(entry.key)) continue;
    final encoded = encodeSafeBackupPrefValue(entry.value);
    if (encoded == null) continue;
    out[entry.key] = encoded;
  }
  return out;
}

/// Разбирает блок настроек из копии в карту ключ → значение.
///
/// 🔴 Чёрный список применяется И ЗДЕСЬ, на приёме. Копия могла быть снята
/// сборкой, где ключ ещё не считался опасным, — а восстановление обязано
/// защищать нынешнее устройство по нынешним правилам, а не по правилам той
/// сборки, что делала копию.
Map<String, Object?> decodeSafeBackupPrefs(Map<String, Object?> encoded) {
  final out = <String, Object?>{};
  for (final entry in encoded.entries) {
    if (!safeBackupPrefIsPortable(entry.key)) continue;
    final value = decodeSafeBackupPrefValue(entry.value);
    if (value == null) continue;
    out[entry.key] = value;
  }
  return out;
}
