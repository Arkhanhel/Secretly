// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 ПЕРЕСЫЛКА СЕБЕ БЕЗ ПОВТОРНОЙ ЗАЛИВКИ.
///
/// Владелец: «оно ведь уже загружено, почему грузится по новой?». Своим
/// устройствам отдаём тот же blob и тот же ключ. Чужим — нет: сервер увидел бы
/// один blob в двух чатах, то есть узнал бы, что файл переслан из A в B.
///
/// Самое опасное здесь — СРОК ЖИЗНИ. Blob живёт на сервере семь дней; отдать
/// просроченный идентификатор значит вручить получателю ссылку в пустоту:
/// файл у него появится и не скачается никогда.
void main() {
  const nowMs = 1_800_000_000_000;
  const hour = 60 * 60 * 1000;

  bool canReuse({
    String blobId = 'blob-1',
    String fileKeyB64 = 'a2V5',
    required int expiresAtMs,
  }) => AppController.canReuseBlobForForward(
    blobId: blobId,
    fileKeyB64: fileKeyB64,
    expiresAtMs: expiresAtMs,
    nowMs: nowMs,
  );

  test('🔴 живой blob переиспользуется', () {
    expect(canReuse(expiresAtMs: nowMs + 3 * 24 * hour), isTrue);
  });

  test('🔴 ПРОСРОЧЕННЫЙ blob НЕ переиспользуется — иначе ссылка в пустоту', () {
    expect(canReuse(expiresAtMs: nowMs - 1), isFalse);
  });

  test('🔴 blob, которому осталось меньше часа, НЕ переиспользуется', () {
    // Получатель может открыть чат не сразу — запас обязателен.
    expect(canReuse(expiresAtMs: nowMs + 20 * 60 * 1000), isFalse);
    expect(canReuse(expiresAtMs: nowMs + hour), isTrue, reason: 'ровно час — уже можно');
  });

  test('🔴 локальный blob не переиспользуется — на сервере его нет', () {
    // `local:…` заводится для отправки самому себе на ОДНОМ устройстве.
    expect(
      canReuse(blobId: 'local:abc', expiresAtMs: nowMs + 10 * 24 * hour),
      isFalse,
    );
  });

  test('без срока жизни не переиспользуется', () {
    expect(canReuse(expiresAtMs: 0), isFalse);
  });

  test('вложение без ключа не переиспользуется', () {
    expect(canReuse(fileKeyB64: '', expiresAtMs: nowMs + 3 * 24 * hour), isFalse);
    expect(canReuse(fileKeyB64: '   ', expiresAtMs: nowMs + 3 * 24 * hour), isFalse);
  });

  test('пустой идентификатор не переиспользуется', () {
    expect(canReuse(blobId: '  ', expiresAtMs: nowMs + 3 * 24 * hour), isFalse);
  });
}
