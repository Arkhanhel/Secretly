// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/resilient_http_client.dart';
import 'package:secretly_app/transport/transport_core.dart';
import 'package:secretly_app/transport/transport_paths.dart';

// Э1: живой тест шва Dart ↔ Rust ↔ настоящий сервер. Пропускается, пока не
// задан путь к библиотеке хоста.
//
// 🔴 На macOS 27 dylib, которую выдаёт `cargo build` (cdylib), dyld не
// грузит: «mis-aligned LINKEDIT string pool». Боевой путь другой — Xcode
// линкует статическую библиотеку, — поэтому и здесь dylib делается из `.a`
// системным clang:
//   cd third_party/secretly_transport_ffi/rust && cargo build --release
//   clang -dynamiclib -arch arm64 -Wl,-force_load,target/release/libseylock.a \
//     -o /tmp/libseylock.dylib -liconv -lresolv \
//     -framework CoreFoundation -framework Security
//   SECRETLY_TRANSPORT_DYLIB=/tmp/libseylock.dylib \
//     flutter test test/transport_live_ffi_test.dart
// Проверяет: загрузку FFI, запуск прокси, переписывание запроса на loopback,
// ответ настоящего сервера с заголовком пути, переход с мёртвого адреса.

void main() {
  final dylib = Platform.environment['SECRETLY_TRANSPORT_DYLIB'] ?? '';
  final keys = Uri.parse('https://keys.secretlyapp.com');
  final relay = Uri.parse('https://relay.secretlyapp.com');

  tearDown(() {
    TransportPaths.instance?.stop();
    TransportPaths.instance = null;
  });

  test(
    '🔴 прямой путь через библиотеку: /health обоих серверов',
    () async {
      final core = TransportCore.loadFrom(dylib);
      expect(core.version, isNotEmpty);
      final paths = TransportPaths(
        core: core,
        keysBase: keys,
        relayBase: relay,
        bootstrapListJson: TransportPaths.bootstrapListJson(
          keysBase: keys,
          relayBase: relay,
          ipByHost: const <String, String>{},
        ),
      );
      expect(paths.start(), isTrue);
      TransportPaths.instance = paths;
      final client = createResilientHttpClient();
      for (final base in <Uri>[keys, relay]) {
        final resp = await client
            .get(base.resolve('/health'))
            .timeout(const Duration(seconds: 15));
        expect(resp.statusCode, 200, reason: '$base ${resp.body}');
        expect(resp.headers[TransportPaths.headerPath], 'direct');
      }
      expect(paths.status()?.currentKind, 'direct');
      client.close();
    },
    skip: dylib.isEmpty ? 'SECRETLY_TRANSPORT_DYLIB не задан' : false,
  );

  test(
    '🔴 мёртвый адрес первым → ответ приходит прямым путём',
    () async {
      final core = TransportCore.loadFrom(dylib);
      // Список: только «запасной адрес» (мёртвый, TEST-NET) и прямой путь.
      const list = '{"v":1,"issued_at_ms":1,"expires_at_ms":4102444800000,'
          '"logical":{"keys":"https://keys.secretlyapp.com","relay":"https://relay.secretlyapp.com"},'
          '"paths":[{"kind":"ip","ip":"192.0.2.1"},{"kind":"direct"}]}';
      final paths = TransportPaths(
        core: core,
        keysBase: keys,
        relayBase: relay,
        bootstrapListJson: list,
      );
      expect(paths.start(), isTrue);
      TransportPaths.instance = paths;
      final client = createResilientHttpClient();
      final sw = Stopwatch()..start();
      final resp = await client
          .get(relay.resolve('/health'))
          .timeout(const Duration(seconds: 30));
      expect(resp.statusCode, 200, reason: resp.body);
      expect(resp.headers[TransportPaths.headerPath], 'direct');
      expect(sw.elapsed.inSeconds, lessThan(15), reason: 'мёртвый путь — 6 с и дальше');
      expect(paths.status()?.currentKind, 'direct');
      // Память: мёртвый индекс 0 помечен, следующий запрос идёт сразу прямым.
      final memory = paths.snapshotMemoryJson() ?? '';
      expect(memory.contains('"failed_at_ms"'), isTrue);
      client.close();
    },
    skip: dylib.isEmpty ? 'SECRETLY_TRANSPORT_DYLIB не задан' : false,
  );
}
