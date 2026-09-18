// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПЕРЕСЫЛКА СЕБЕ: ТОТ ЖЕ ФАЙЛ, БЕЗ НОВОЙ ЗАЛИВКИ.
//
// 🔴 Своим устройствам можно отдать тот же зашифрованный файл: оба конца мои.
// Чужому получателю нельзя — сервер увидел бы один файл в двух переписках,
// то есть узнал бы, что его переслали из A в B.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/chat/forward_blob_reuse.dart';

const _me = 'me-1';

final _attachment = AttachmentEventV1(
  eventId: 'a1',
  blobId: 'blob-1',
  fileKeyB64: 'a2V5',
  mime: 'application/pdf',
  sizeBytes: 100,
);

void main() {
  AttachmentEventV1? reuse({
    bool toGroup = false,
    String? target = _me,
    String me = _me,
  }) => desktopReusableBlobForForward(
    source: _attachment,
    toGroup: toGroup,
    targetProfileId: target,
    myProfileId: me,
  );

  test('себе — отдаём тот же файл', () {
    expect(reuse(), same(_attachment));
  });

  test('🔴 другому человеку — заливаем заново', () {
    expect(reuse(target: 'igor-1'), isNull);
  });

  test('🔴 в комнату — заливаем заново', () {
    expect(reuse(toGroup: true), isNull);
  });

  test('без известного профиля не рискуем', () {
    expect(reuse(target: null), isNull);
    expect(reuse(target: '   '), isNull);
    expect(reuse(me: ''), isNull);
  });

  test('без разобранного конверта заливаем заново', () {
    expect(
      desktopReusableBlobForForward(
        source: null,
        toGroup: false,
        targetProfileId: _me,
        myProfileId: _me,
      ),
      isNull,
    );
  });

  test('проводка: пересылка на компьютере пользуется правилом', () {
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(section.contains('desktopReusableBlobForForward('), isTrue);
    expect(section.contains('reuseBlobFrom:'), isTrue);
  });
}
