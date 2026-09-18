// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/native_network_path.dart';

// 🔴 N-2 (17.09.2026): канал `secretly/network_path` слушали двое — приложение
// (переподключение релея при смене сети) и менеджер звонков. Каждый заводил
// свой `receiveBroadcastStream()`, а обработчик у имени канала один: второй
// забирал все события, отписка любого глушила источник.

Map<String, Object?> _path(String signature) => <String, Object?>{
  'available': true,
  'transports': const <String>['wifi'],
  'signature': signature,
};

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  ({int Function() listens, int Function() cancels, void Function(Object?) emit})
  mockPlatform() {
    var listens = 0;
    var cancels = 0;
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(
      NativeNetworkPath.channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          listens++;
          sink = events;
        },
        onCancel: (_) => cancels++,
      ),
    );
    addTearDown(
      () => messenger.setMockStreamHandler(NativeNetworkPath.channel, null),
    );
    return (
      listens: () => listens,
      cancels: () => cancels,
      emit: (event) => sink!.success(event),
    );
  }

  setUp(NativeNetworkPath.resetForTesting);
  tearDown(NativeNetworkPath.resetForTesting);

  test('так было: второй отдельный поток отнимает события у первого', () async {
    final platform = mockPlatform();
    final app = <Object?>[];
    final calls = <Object?>[];
    final appSub = NativeNetworkPath.channel.receiveBroadcastStream().listen(
      app.add,
    );
    await _settle();
    final callsSub = NativeNetworkPath.channel.receiveBroadcastStream().listen(
      calls.add,
    );
    await _settle();
    platform.emit(_path('wifi-a'));
    await _settle();
    expect(app, isEmpty, reason: 'обработчик у имени канала один');
    expect(calls, hasLength(1));
    await callsSub.cancel();
    await appSub.cancel();
  });

  test('🔴 общий поток: события получают оба', () async {
    final platform = mockPlatform();
    final app = <Object?>[];
    final calls = <Object?>[];
    final appSub = NativeNetworkPath.events.listen(app.add);
    final callsSub = NativeNetworkPath.events.listen(calls.add);
    await _settle();
    platform.emit(_path('wifi-a'));
    platform.emit(_path('wifi-b'));
    await _settle();
    expect(app, hasLength(2));
    expect(calls, hasLength(2));
    expect(platform.listens(), 1, reason: 'платформа слушается один раз');
    await callsSub.cancel();
    await appSub.cancel();
  });

  test('🔴 отписка менеджера звонков не глушит приложение', () async {
    final platform = mockPlatform();
    final app = <Object?>[];
    final appSub = NativeNetworkPath.events.listen(app.add);
    final callsSub = NativeNetworkPath.events.listen((_) {});
    await _settle();
    await callsSub.cancel();
    platform.emit(_path('wifi-b'));
    await _settle();
    expect(app, hasLength(1));
    expect(platform.cancels(), 0);

    await appSub.cancel();
    await _settle();
    expect(platform.cancels(), 1, reason: 'последний ушёл — источник стоп');

    // Перезапуск менеджера звонков после выхода всех подписчиков.
    final again = <Object?>[];
    final againSub = NativeNetworkPath.events.listen(again.add);
    await _settle();
    platform.emit(_path('lte'));
    await _settle();
    expect(again, hasLength(1));
    expect(platform.listens(), 2);
    await againSub.cancel();
  });

  test('🔴 поздний подписчик сразу получает последний снимок сети', () async {
    // Менеджер звонков подписывается после приложения. Без снимка первая смена
    // Wi-Fi → Wi-Fi во время звонка не считалась сменой (подпись пути пуста).
    final platform = mockPlatform();
    final app = <Object?>[];
    final calls = <Object?>[];
    final appSub = NativeNetworkPath.events.listen(app.add);
    await _settle();
    platform.emit(_path('wifi-a'));
    await _settle();
    final callsSub = NativeNetworkPath.events.listen(calls.add);
    await _settle();
    expect(calls, [_path('wifi-a')]);
    platform.emit(_path('wifi-b'));
    await _settle();
    expect(calls, [_path('wifi-a'), _path('wifi-b')]);
    expect(app, [_path('wifi-a'), _path('wifi-b')], reason: 'приложению повтора нет');
    expect(platform.listens(), 1);
    await callsSub.cancel();
    await appSub.cancel();
  });

  test('имя канала знает только общий поток', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('transport/native_network_path.dart')) continue;
      if (entity.readAsStringSync().contains("'secretly/network_path'")) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
