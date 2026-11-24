// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Знак «важного пользователя» (21.11.2026): кому он выдан.
///
/// Выдаёт только оператор на сервере (`POST /v1/badges/admin/set`), клиент
/// видит его полем `elite_badge` в ответе `GET /v1/profile/{id}/meta` — и
/// для чужих профилей, и для своего. Здесь — запомненное: профиль → вид
/// знака ("h2"), чтобы список чатов и профиль рисовали знак сразу, без
/// ожидания сети. Хранится на телефоне (SharedPreferences), без сервера.
///
/// Старый сервер поля не присылает — тогда ничего не меняем (не стираем).
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EliteBadges {
  EliteBadges._();

  static final EliteBadges instance = EliteBadges._();

  static const String _prefsKey = 'elite_badges_v1';

  /// profileId → вид знака.
  final ValueNotifier<Map<String, String>> badges =
      ValueNotifier<Map<String, String>>(const {});

  bool _loaded = false;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
      final map = <String, String>{...badges.value};
      for (final row in raw) {
        final i = row.indexOf('=');
        if (i <= 0) continue;
        map.putIfAbsent(row.substring(0, i), () => row.substring(i + 1));
      }
      badges.value = Map.unmodifiable(map);
    } catch (_) {
      // Нет хранилища — знак придёт со следующим ответом сервера.
    } finally {
      _loaded = true;
    }
  }

  String? badgeOf(String? profileId) {
    final id = profileId?.trim() ?? '';
    if (id.isEmpty) return null;
    return badges.value[id];
  }

  /// Человек из команды Secretly: у профиля есть знак, выданный оператором
  /// (23.11.2026: так открываются закрытые обложки команды —
  /// `kStaffProfileCovers`). Сейчас знак есть только у владельцев и
  /// разработчиков; если оператор выдаст его кому-то ещё, тому откроются и
  /// обложки — тогда нужен отдельный признак с сервера.
  bool isTeam(String? profileId) => badgeOf(profileId) != null;

  /// Ответ сервера о профиле. [present] — было ли поле в ответе вообще
  /// (старый сервер его не шлёт: тогда не трогаем).
  void record(String profileId, String? badge, {required bool present}) {
    if (!present) return;
    final id = profileId.trim();
    if (id.isEmpty) return;
    final value = badge?.trim().toLowerCase() ?? '';
    final current = badges.value[id];
    if ((current ?? '') == value) return;
    final map = <String, String>{...badges.value};
    if (value.isEmpty) {
      map.remove(id);
    } else {
      map[id] = value;
    }
    badges.value = Map.unmodifiable(map);
    _save();
  }

  Future<void> _saving = Future<void>.value();

  /// Записи — строго по очереди и всегда последнего состояния: ответы
  /// `getInstance()` приходят не в порядке вызова, и ранняя запись иначе
  /// затирала бы позднюю (поймал тест).
  void _save() {
    _saving = _saving.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rows = [
          for (final e in badges.value.entries) '${e.key}=${e.value}',
        ];
        await prefs.setStringList(_prefsKey, rows);
      } catch (_) {}
    });
  }

  @visibleForTesting
  Future<void> flushForTest() => _saving;

  @visibleForTesting
  void resetForTest() {
    badges.value = const {};
    _loaded = false;
    _loading = null;
    _saving = Future<void>.value();
  }
}
