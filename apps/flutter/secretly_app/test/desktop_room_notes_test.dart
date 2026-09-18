// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ◆ «Заметки» — третья вкладка панели созвона из макета.
//
// Пункт стоял открытым дольше остальных, и справедливо: это не мелочь
// оформления, а НОВАЯ СУЩНОСТЬ. Ни у одного текста в приложении нет вида
// «только для меня»: всё, что человек пишет, — сообщение, а у сообщения есть
// получатель, ключ и очередь отправки.
//
// Два решения, которые этот пункт закрывают, и оба стерегутся здесь.
//
// 1. ЗАМЕТКА ЛИЧНАЯ. Её не шифруют для собеседника, не кладут в очередь и не
//    показывают в переписке. Вкладка в окне ОБЩЕГО разговора обязана сказать
//    это словами, иначе кто-нибудь напишет туда «буду через 10 минут».
//
// 2. И ПРИ ЭТОМ НЕ ОТКРЫТЫМ ТЕКСТОМ. Проще всего было положить её в обычные
//    настройки окна, рядом с выбором камеры. Но заметка с созвона — запись
//    того же разговора, и держать её открыто рядом с зашифрованной историей
//    значило бы обойти собственное обещание с чёрного хода.
//
// Цена для телефона — ноль: методы добавочные, таблица заводится ленивым
// `IF NOT EXISTS`, версия схемы не двигается (её подъём был бы дверью в одну
// сторону: откатившийся телефон увидел бы версию из будущего).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/desktop/chat/details/room_notes_pane.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('хранение', () {
    test('◆ заметка переживает запись и чтение', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(await db.desktopRoomNote('room-1'), '');
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: 'Адрес: Пушкина 3, в четверг',
          updatedAtMs: 1000,
        );
        expect(
          await db.desktopRoomNote('room-1'),
          'Адрес: Пушкина 3, в четверг',
        );
      } finally {
        await db.close();
      }
    });

    test('заметки разных разговоров не смешиваются', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: 'первая',
          updatedAtMs: 1,
        );
        await db.setDesktopRoomNote(
          convoId: 'room-2',
          body: 'вторая',
          updatedAtMs: 2,
        );
        expect(await db.desktopRoomNote('room-1'), 'первая');
        expect(await db.desktopRoomNote('room-2'), 'вторая');
        expect(await db.desktopRoomNote('room-3'), '');
      } finally {
        await db.close();
      }
    });

    test('повторная запись заменяет, а не плодит строки', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: 'черновик',
          updatedAtMs: 1,
        );
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: 'набело',
          updatedAtMs: 2,
        );
        expect(await db.desktopRoomNote('room-1'), 'набело');
        final rows = await db.rawQueryForTesting(
          'SELECT COUNT(*) AS n FROM desktop_room_notes',
        );
        expect(rows.first['n'], 1);
      } finally {
        await db.close();
      }
    });

    test('🔴 «стёр всё» УДАЛЯЕТ запись, а не хранит пустоту', () async {
      // Иначе за каждой отменённой заметкой оставалась бы строка в базе —
      // список разговоров, по которым «что-то записывали», без содержимого.
      final db = await AppDb.openForTesting();
      try {
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: 'временно',
          updatedAtMs: 1,
        );
        await db.setDesktopRoomNote(
          convoId: 'room-1',
          body: '   ',
          updatedAtMs: 2,
        );
        expect(await db.desktopRoomNote('room-1'), '');
        final rows = await db.rawQueryForTesting(
          'SELECT COUNT(*) AS n FROM desktop_room_notes',
        );
        expect(rows.first['n'], 0);
      } finally {
        await db.close();
      }
    });

    test('пустой идентификатор не заводит записей', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.setDesktopRoomNote(convoId: '  ', body: 'x', updatedAtMs: 1);
        expect(await db.desktopRoomNote(''), '');
      } finally {
        await db.close();
      }
    });
  });

  group('🔴 цена для телефона', () {
    final src = File('lib/storage/app_db.dart').readAsStringSync();

    test('таблица заводится ленивым IF NOT EXISTS', () {
      expect(
        src.contains('CREATE TABLE IF NOT EXISTS desktop_room_notes'),
        isTrue,
      );
      expect(src.contains('Future<void> _ensureDesktopRoomNotes()'), isTrue);
    });

    test('🔴 в цепочке миграций ветки для заметок НЕТ', () {
      // Самое дорогое место проекта: у человека, чья база не открылась, нет
      // истории и вернуть её нечем. Ветка ради заметок — несоразмерный риск.
      final chain = src.substring(
        src.indexOf('static Future<void> runMigrationsForTest('),
        src.indexOf('static Future<void> _createSchema('),
      );
      expect(chain.contains('desktop_room_notes'), isFalse);
      // Создание таблицы ровно одно во всём файле, и оно — внутри ленивого
      // помощника, а не в общей схеме: телефон её не заводит вовсе.
      const create = 'CREATE TABLE IF NOT EXISTS desktop_room_notes';
      expect(create.allMatches(src).length, 1);
      final lazyStart = src.indexOf('Future<void> _ensureDesktopRoomNotes()');
      final lazyEnd = src.indexOf('_desktopNotesReady = true', lazyStart);
      expect(lazyStart, greaterThan(0));
      expect(src.indexOf(create), greaterThan(lazyStart));
      expect(src.indexOf(create), lessThan(lazyEnd));
    });

    test('ни один мобильный экран заметок не вызывает', () {
      for (final f in [
        'lib/ui/chat_screen.dart',
        'lib/ui/settings_screen.dart',
        'lib/main.dart',
      ]) {
        final body = File(f).readAsStringSync();
        expect(
          body.contains('localConvoNote') ||
              body.contains('desktopRoomNote'),
          isFalse,
          reason: '$f не должен знать о десктопных заметках',
        );
      }
    });
  });

  group('где заметка видна', () {
    test('◆ третья вкладка панели созвона', () {
      final src = File(
        'lib/ui/desktop/calls/room_call_window.dart',
      ).readAsStringSync();
      expect(
        src.contains("'Участники · \${participants.length}', 'Чат', 'Заметки'"),
        isTrue,
      );
      expect(src.contains('RoomNotesPane('), isTrue);
    });

    test('🔴 и в «Инфо» комнаты — иначе её не прочитать после звонка', () {
      // Окно созвона живёт ровно столько, сколько идёт разговор. Заметка,
      // видная только во время звонка, бесполезна тогда, когда за ней
      // приходят — через час, перечитать адрес.
      final src = File(
        'lib/ui/desktop/chat/details/room_details_view.dart',
      ).readAsStringSync();
      expect(src.contains('RoomNotesPane('), isTrue);
      expect(src.contains("title: 'ЗАМЕТКИ'"), isTrue);
    });

    test('🔴 панель не тянется в общий код напрямую', () {
      // Шов между окном и общим кодом только сужается: новый файл его не
      // расширяет. Ратчет `desktop_controller_seam_ratchet_test` считает
      // именно импорты — здесь их нет вовсе, панель знает два колбэка.
      final src = File(
        'lib/ui/desktop/chat/details/room_notes_pane.dart',
      ).readAsStringSync();
      expect(src.contains('app_controller.dart'), isFalse);
      expect(src.contains('desktop_app_view_model.dart'), isFalse);
      expect(src.contains('required this.load'), isTrue);
      expect(src.contains('required this.save'), isTrue);
    });

    test('🔴 сказано словами, что заметка не общая', () {
      final src = File(
        'lib/ui/desktop/chat/details/room_notes_pane.dart',
      ).readAsStringSync();
      expect(src.contains('Видно только вам'), isTrue);
      expect(src.contains('Не отправляется, не попадает в переписку'), isTrue);
      // И про резервную копию — тоже правда, а не умолчание.
      expect(src.contains('не входит в резервную копию'), isTrue);
    });

    test('🔴 последняя фраза дописывается при закрытии окна', () {
      // Окно созвона закрывается вместе с разговором, и дописывают почти
      // всегда в последнюю секунду.
      final src = File(
        'lib/ui/desktop/chat/details/room_notes_pane.dart',
      ).readAsStringSync();
      final i = src.indexOf('void dispose()');
      final body = src.substring(i, (i + 300).clamp(0, src.length));
      expect(body.contains('_flush()'), isTrue);
    });
  });

  group('панель заметок', () {
    Widget host({
      required String convoId,
      required Future<String> Function(String) load,
      required Future<void> Function(String, String) save,
      bool expand = false,
    }) => MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: SizedBox(
            width: 330,
            height: 400,
            child: RoomNotesPane(
              convoId: convoId,
              load: load,
              save: save,
              expand: expand,
            ),
          ),
        ),
      ),
    );

    test('🔴 в резервную копию заметки не попадают, и это не забывчивость', () {
      // Копия собирается по явному списку таблиц. Добавить туда заметки
      // нельзя дёшево: восстановление на ТЕЛЕФОНЕ полезло бы в таблицу,
      // которой у него нет, — рисковать восстановлением истории ради
      // заметок нельзя. Значит, об этом надо сказать человеку.
      final contract = File(
        'lib/storage/safe_backup_snapshot_contract.dart',
      ).readAsStringSync();
      expect(contract.contains('desktop_room_notes'), isFalse);
    });

    testWidgets('◆ показывает то, что уже записано', (t) async {
      await t.pumpWidget(
        host(
          convoId: 'room-1',
          load: (_) async => 'Пушкина 3',
          save: (_, __) async {},
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Пушкина 3'), findsOneWidget);
      expect(find.textContaining('Видно только вам'), findsOneWidget);
    });

    testWidgets('🔴 набор сохраняется после паузы, а не на каждую букву', (
      t,
    ) async {
      final writes = <String>[];
      await t.pumpWidget(
        host(
          convoId: 'room-1',
          load: (_) async => '',
          save: (id, body) async => writes.add('$id:$body'),
        ),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(EditableText), 'ку');
      await t.pump(const Duration(milliseconds: 200));
      expect(writes, isEmpty, reason: 'пауза ещё не вышла');

      await t.pump(const Duration(milliseconds: 700));
      expect(writes, ['room-1:ку']);
    });

    testWidgets('🔴 последняя фраза дописывается при закрытии', (t) async {
      final writes = <String>[];
      await t.pumpWidget(
        host(
          convoId: 'room-1',
          load: (_) async => '',
          save: (id, body) async => writes.add('$id:$body'),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText), 'успеть');

      // Окно созвона закрывается вместе с разговором — снимаем панель до
      // того, как выйдет пауза набора.
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      expect(writes, ['room-1:успеть']);
    });

    testWidgets('смена комнаты дописывает ПРЕЖНЮЮ заметку', (t) async {
      final writes = <String>[];
      Future<String> load(String id) async => id == 'room-1' ? '' : 'вторая';
      await t.pumpWidget(
        host(
          convoId: 'room-1',
          load: load,
          save: (id, body) async => writes.add('$id:$body'),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText), 'первая');

      await t.pumpWidget(
        host(
          convoId: 'room-2',
          load: load,
          save: (id, body) async => writes.add('$id:$body'),
        ),
      );
      await t.pumpAndSettle();
      expect(writes.first, 'room-1:первая');
      expect(find.text('вторая'), findsOneWidget);
    });

    testWidgets('без разговора панели нет вовсе', (t) async {
      await t.pumpWidget(
        host(convoId: '', load: (_) async => 'x', save: (_, __) async {}),
      );
      await t.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
    });
  });
}
