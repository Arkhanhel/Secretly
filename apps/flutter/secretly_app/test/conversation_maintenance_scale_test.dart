// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

/// ПОТОЛОК В ДВЕСТИ БЕСЕД (найдено 02.09.2026, аудит масштабирования).
///
/// Список бесед и фоновое обслуживание брали по двести строк. Для списка это
/// означало, что двести первая беседа просто не появлялась в перечне: данные
/// на месте, чат открывается по ссылке, но найти его нельзя.
///
/// 🔴 Для обслуживания последствие тяжелее и не про скорость. Обслуживание
/// отвечает за автоудаление, и предел молча отключал его для всего, что не
/// попало в первые двести бесед: человек включил «удалять через неделю», а
/// сообщения оставались лежать. Выпадали самые старые по времени последнего
/// события — ровно те, где автоудаление нужнее всего.
///
/// Вторая часть правки — цена обхода. Обслуживание запрашивало каждую беседу
/// отдельным `convoGet` ради единственного поля со сроком автоудаления, хотя
/// строкой выше `convoList` уже вернул все поля всех бесед. Двести запросов
/// раз в минуту за данными, которые лежат в руках.
///
/// Проверяется копия ветвления из `_applyRetentionForConvoRows`.
class _RetentionHarness {
  int convoGetCalls = 0;
  int pruneCalls = 0;
  int roomSweepCalls = 0;
  final List<String> pruned = <String>[];

  /// Новый путь: работает по готовым строкам.
  void applyForRows(List<Map<String, Object?>> rows) {
    final seen = <String>{};
    for (final row in rows) {
      final convoId = (row['convo_id'] as String?)?.trim() ?? '';
      if (convoId.isEmpty || !seen.add(convoId)) continue;
      final secs = (row['auto_delete_seconds'] as num?)?.toInt();
      if (secs != null && secs > 0) {
        pruneCalls++;
        pruned.add(convoId);
      }
      if (convoId.startsWith('group:')) {
        roomSweepCalls++;
      }
    }
  }

  /// Прежний путь: по идентификаторам, с запросом на каждый.
  void applyForIds(List<String> convoIds, Map<String, int?> autoDeleteByConvo) {
    for (final convoId in convoIds) {
      convoGetCalls++;
      final secs = autoDeleteByConvo[convoId];
      if (secs != null && secs > 0) {
        pruneCalls++;
        pruned.add(convoId);
      }
      if (convoId.startsWith('group:')) {
        roomSweepCalls++;
      }
    }
  }
}

List<Map<String, Object?>> _rows(int count, {int autoDeleteEvery = 10}) {
  return List.generate(count, (i) {
    final isGroup = i % 25 == 0;
    return <String, Object?>{
      'convo_id': isGroup ? 'group:g$i' : 'p$i',
      'auto_delete_seconds': i % autoDeleteEvery == 0 ? 604800 : null,
    };
  });
}

void main() {
  group('обслуживание бесед при большом их числе', () {
    test('🔴 обход по строкам не делает ни одного запроса за сроком', () {
      final h = _RetentionHarness();
      h.applyForRows(_rows(200));
      expect(
        h.convoGetCalls,
        0,
        reason: 'срок автоудаления уже есть в строке, полученной списком — '
            'прежний путь делал по запросу на беседу, двести раз в минуту',
      );
    });

    test('прежний путь для сравнения: запрос на каждую беседу', () {
      final h = _RetentionHarness();
      final rows = _rows(200);
      final ids = rows
          .map((r) => r['convo_id'] as String)
          .toList(growable: false);
      final byId = <String, int?>{
        for (final r in rows)
          r['convo_id'] as String: (r['auto_delete_seconds'] as num?)?.toInt(),
      };
      h.applyForIds(ids, byId);
      expect(h.convoGetCalls, 200);
    });

    test('удаляет ровно там, где автоудаление включено', () {
      final h = _RetentionHarness();
      h.applyForRows(_rows(100, autoDeleteEvery: 10));
      expect(
        h.pruneCalls,
        10,
        reason: 'беседы с выключенным автоудалением обходятся бесплатно',
      );
    });

    test('обход комнат вызывается только для комнат', () {
      final h = _RetentionHarness();
      h.applyForRows(_rows(100));
      expect(
        h.roomSweepCalls,
        4,
        reason: 'для личной беседы этот обход и раньше возвращал пустоту, '
            'просто после лишнего ветвления',
      );
    });

    test('🔴 беседа за прежним потолком двухсот тоже убирается', () {
      final h = _RetentionHarness();
      final rows = <Map<String, Object?>>[
        ..._rows(200, autoDeleteEvery: 100000), // двести без автоудаления
        <String, Object?>{'convo_id': 'p-old', 'auto_delete_seconds': 604800},
      ];
      h.applyForRows(rows);
      expect(
        h.pruned,
        contains('p-old'),
        reason: 'до правки эта беседа не попадала в первые двести строк, и '
            'её сообщения оставались лежать вопреки настройке приватности',
      );
    });

    test('повторы идентификаторов обрабатываются один раз', () {
      final h = _RetentionHarness();
      h.applyForRows(<Map<String, Object?>>[
        {'convo_id': 'p1', 'auto_delete_seconds': 100},
        {'convo_id': 'p1', 'auto_delete_seconds': 100},
      ]);
      expect(h.pruneCalls, 1);
    });

    test('пустые и битые строки не роняют проход', () {
      final h = _RetentionHarness();
      h.applyForRows(<Map<String, Object?>>[
        {'convo_id': '', 'auto_delete_seconds': 100},
        {'convo_id': null, 'auto_delete_seconds': 100},
        {'convo_id': '  ', 'auto_delete_seconds': 100},
        {'convo_id': 'p1', 'auto_delete_seconds': 0},
        {'convo_id': 'p2', 'auto_delete_seconds': null},
      ]);
      expect(
        h.pruneCalls,
        0,
        reason: 'нулевой и отсутствующий срок означают «автоудаление '
            'выключено», а не «удалять немедленно»',
      );
    });
  });
}
