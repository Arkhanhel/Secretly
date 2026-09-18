// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ЧЕРНОВИКИ НА КОМПЬЮТЕРЕ — В ЗАШИФРОВАННОЙ БАЗЕ.
//
// 🔴 Черновик — это неотправленное сообщение, и он лежал в настройках
// приложения ОТКРЫТЫМ ТЕКСТОМ, хотя сама переписка — в зашифрованной базе.
// Теперь хранилище подключает оболочка окна (пишет через контроллер в ту же
// базу), а открытая копия стирается при первом же запуске с этой правкой.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'desktop_drafts_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DesktopDraftStore.detachStorageForTesting);

  test('ключ хранилища тот же, что был в настройках', () {
    expect(DesktopDraftStore.storageKey, _key);
  });

  test('🔴 старый черновик переезжает в базу, открытая копия стирается',
      () async {
    SharedPreferences.setMockInitialValues({
      _key: '{"friend-1":"недописанное"}',
    });
    DesktopDraftStore.detachStorageForTesting();
    await DesktopDraftStore.load();
    expect(DesktopDraftStore.get('friend-1'), 'недописанное');

    final written = <String>[];
    await DesktopDraftStore.attachStorage(
      read: () async => null,
      write: (json) async => written.add(json),
    );

    expect(written, hasLength(1), reason: 'перенос в базу не состоялся');
    expect(written.single.contains('недописанное'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_key),
      isNull,
      reason: 'открытая копия обязана исчезнуть',
    );
    expect(DesktopDraftStore.get('friend-1'), 'недописанное');
  });

  test('черновик из базы важнее старой копии', () async {
    SharedPreferences.setMockInitialValues({
      _key: '{"friend-1":"старое"}',
    });
    DesktopDraftStore.detachStorageForTesting();
    await DesktopDraftStore.load();

    final written = <String>[];
    await DesktopDraftStore.attachStorage(
      read: () async => '{"friend-1":"новое","group:r":"в комнату"}',
      write: (json) async => written.add(json),
    );

    expect(DesktopDraftStore.get('friend-1'), 'новое');
    expect(DesktopDraftStore.get('group:r'), 'в комнату');
    expect(written, isEmpty, reason: 'переносить было нечего');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), isNull);
  });

  test('🔴 набранный текст уходит в базу, а не в настройки', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopDraftStore.detachStorageForTesting();
    final written = <String>[];
    await DesktopDraftStore.attachStorage(
      read: () async => null,
      write: (json) async => written.add(json),
    );

    DesktopDraftStore.set('friend-2', 'привет');
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(written, isNotEmpty);
    expect(written.last.contains('привет'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_key),
      isNull,
      reason: 'в настройках открытого текста быть не должно',
    );
  });

  test('очистка черновика доезжает до базы', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopDraftStore.detachStorageForTesting();
    final written = <String>[];
    await DesktopDraftStore.attachStorage(
      read: () async => '{"friend-3":"было"}',
      write: (json) async => written.add(json),
    );
    expect(DesktopDraftStore.has('friend-3'), isTrue);

    DesktopDraftStore.clear('friend-3');
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(written.last, '', reason: 'пустое хранилище = стереть ключ');
    expect(DesktopDraftStore.has('friend-3'), isFalse);
  });

  test('без подключённой базы в настройки больше не пишем', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopDraftStore.detachStorageForTesting();

    DesktopDraftStore.set('friend-4', 'до подключения базы');
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), isNull);
    expect(
      DesktopDraftStore.get('friend-4'),
      'до подключения базы',
      reason: 'в памяти черновик остаётся — его сохранит подключение',
    );
  });
}
