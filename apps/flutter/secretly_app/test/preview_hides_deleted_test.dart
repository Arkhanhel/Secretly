// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart';

/// 🔴 УДАЛЁННОЕ У ВСЕХ НЕ ИМЕЕТ ПРАВА ЖИТЬ В СПИСКЕ ЧАТОВ.
///
/// ПОЛЕ 16.08.2026. Собеседник написал три сообщения и удалил их у всех. Лента
/// чата отработала правильно — их не стало. А в списке чатов текст последнего
/// («Ты правки внес?») продолжал висеть с временем 18:19. Владелец увидел
/// сообщение, зашёл прочитать — и не нашёл его. Выглядело как потеря смс.
///
/// Причина — асимметрия двух путей чтения ОДНОЙ таблицы:
///
///   лента:        собирает метки `__secretly_delete__` и пропускает удалённое;
///   предпросмотр: прятал саму МЕТКУ, но не знал, что она что-то отменяет.
///
/// Журнал устройства подтвердил: после трёх сообщений пришли 19 конвертов
/// одинакового размера и без единого уведомления — это и были метки удаления.
void main() {
  group('разбор метки удаления', () {
    test('🔴 метка называет удалённые сообщения', () {
      final cmd = buildDeleteForAllCommand(const ['p-1', 'p-2']);
      expect(cmd.startsWith(kDeleteForAllCommandPrefix), isTrue);
      expect(parseDeleteForAllCommand(cmd), ['p-1', 'p-2']);
    });

    test('обычный текст меткой не является', () {
      expect(parseDeleteForAllCommand('Ты правки внес?'), isEmpty);
    });

    test('пустая метка никого не удаляет', () {
      expect(parseDeleteForAllCommand(kDeleteForAllCommandPrefix), isEmpty);
    });
  });

  timelineRowIdRule();

  group('правило предпросмотра', () {
    // Правило, которое теперь применяют ОБА пути предпросмотра: строка
    // пропускается, если её payload_event_id назван в метке удаления.
    bool isDeleted(String? payloadEventId, Set<String> deleted) {
      if (deleted.isEmpty) return false;
      final pid = (payloadEventId ?? '').trim();
      if (pid.isEmpty) return false;
      return deleted.contains(pid);
    }

    test('🔴 удалённое сообщение пропускается', () {
      expect(isDeleted('p-1', {'p-1'}), isTrue);
    });

    test('🔴 живое сообщение остаётся — иначе очистим список чатов', () {
      expect(isDeleted('p-2', {'p-1'}), isFalse);
    });

    test('строка без идентификатора не считается удалённой', () {
      // Пустой идентификатор не должен совпасть «со всем сразу».
      expect(isDeleted(null, {'p-1'}), isFalse);
      expect(isDeleted('', {'p-1'}), isFalse);
      expect(isDeleted('   ', {'p-1'}), isFalse);
    });

    test('без меток удаления не меняется ничего', () {
      expect(isDeleted('p-1', <String>{}), isFalse);
    });
  });
}

/// 🔴 ОДНО ПРАВИЛО ОПОЗНАНИЯ СТРОКИ ЛЕНТЫ — И ДЕДУП, И КЛЮЧ ВИДЖЕТА.
///
/// Раньше оно было написано в десяти местах как `payloadEventId ?? eventId`.
/// `??` ловит только null — пустая строка проходила как полноценный
/// идентификатор, и ВСЕ такие строки получали ключ ''. Два следствия:
/// дедуп схлопывал их в одну (сообщения исчезали с экрана, оставаясь в базе),
/// а `GlobalKey` дублировался — отказ построения ВСЕГО списка, после которого
/// чат становится неработающим блоком ошибки.
void timelineRowIdRule() {
  // Правило (копия `_ChatScreenState.timelineRowId`) — здесь проверяются его
  // границы; в самом экране оно теперь одно на оба применения.
  String rowId(String? payloadEventId, String eventId) {
    final pid = (payloadEventId ?? '').trim();
    return pid.isEmpty ? eventId : pid;
  }

  group('опознание строки ленты', () {
    test('обычный случай — берём payloadEventId', () {
      expect(rowId('p-1', 'e-1'), 'p-1');
    });

    test('🔴 null падает на eventId', () {
      expect(rowId(null, 'e-1'), 'e-1');
    });

    test('🔴 ПУСТАЯ строка падает на eventId — иначе строки схлопнутся', () {
      expect(rowId('', 'e-1'), 'e-1');
      expect(rowId('   ', 'e-2'), 'e-2');
    });

    test('🔴 две строки без payload-идентификатора РАЗЛИЧИМЫ', () {
      final a = rowId('', 'e-1');
      final b = rowId('', 'e-2');
      expect(a, isNot(b), reason: 'иначе одна из них исчезнет с экрана');
    });
  });
}
