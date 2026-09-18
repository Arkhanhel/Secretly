// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/stickers/sticker_pack_invite.dart';
import 'package:secretly_app/stickers/sticker_pack_invite_builder.dart';
import 'package:secretly_app/stickers/sticker_share_mode.dart';

// Сборка приглашения в набор — решающая часть Ш-2 (08.08.2026).
//
// Здесь проверяются не байты формата (это соседний файл), а РЕШЕНИЯ: уезжает ли
// личный набор, что делать с частично выгруженными стикерами, и говорим ли мы
// человеку правду о том, сколько уехало.

StickerInviteCandidate ready(String id) => StickerInviteCandidate(
  stickerId: id,
  fileName: '$id.png',
  format: 'png',
  animated: false,
  blobId: 'blob-$id',
  fileKeyB64: 'a2V5',
);

StickerInviteCandidate failed(String id) => StickerInviteCandidate(
  stickerId: id,
  fileName: '$id.png',
  format: 'png',
  animated: false,
  // Блоба нет: выгрузка не удалась.
);

StickerInviteBuildResult build({
  required List<StickerInviteCandidate> candidates,
  StickerShareMode mode = StickerShareMode.sentOnly,
  String icon = 's0',
}) {
  return buildStickerPackInvite(
    packId: 'user:P1:abc',
    packVersion: 2,
    title: 'Мои стикеры',
    iconStickerId: icon,
    shareMode: mode,
    candidates: candidates,
  );
}

void main() {
  test('🔴 ЛИЧНЫЙ набор НЕ уезжает — это обещание настройки', () {
    // Самый важный отказ во всём Ш-2. Человек выбрал «личный», и отправить набор
    // «потому что попросили поделиться» значило бы нарушить настройку, которую мы
    // сами же и предложили.
    final result = build(
      candidates: <StickerInviteCandidate>[ready('s0'), ready('s1')],
      mode: StickerShareMode.personal,
    );
    expect(result.isBuilt, isFalse);
    expect(result.refusal, StickerInviteRefusal.personalMode);
    expect(result.invite, isNull);
  });

  test('🔴 личный набор отвергается ДО всякой подготовки', () {
    // Даже если ни один стикер ещё не выгружен: выгрузка блоба — это уже
    // отправка шифртекста на сервер, и для набора, обещанного не уезжающим, её
    // делать нельзя. Поэтому проверка режима стоит ПЕРВОЙ, а не после сборки.
    final result = build(
      candidates: <StickerInviteCandidate>[failed('s0')],
      mode: StickerShareMode.personal,
    );
    expect(result.refusal, StickerInviteRefusal.personalMode,
        reason: 'режим важнее готовности стикеров');
  });

  test('обычный набор собирается', () {
    final result = build(
      candidates: <StickerInviteCandidate>[ready('s0'), ready('s1')],
    );
    expect(result.isBuilt, isTrue);
    expect(result.included, 2);
    expect(result.requested, 2);
    expect(result.isPartial, isFalse);
    expect(result.invite!.items, hasLength(2));
  });

  group('частичный успех', () {
    test('🔴 уезжает то, что готово, а не ничего', () {
      // Набор в 50 стикеров — это 50 попыток подготовки, и одна неудача почти
      // неизбежна. Ронять из-за неё всю отправку значило бы, что поделиться
      // большим набором нельзя вообще.
      final result = build(
        candidates: <StickerInviteCandidate>[
          ready('s0'),
          failed('s1'),
          ready('s2'),
        ],
      );
      expect(result.isBuilt, isTrue);
      expect(result.included, 2);
      expect(result.requested, 3);
    });

    test('🔴 про неполноту СКАЗАНО', () {
      // Молча отправить половину хуже, чем не отправить: получатель решит, что
      // автор так и задумал, а автор будет уверен, что поделился целиком.
      final result = build(
        candidates: <StickerInviteCandidate>[ready('s0'), failed('s1')],
      );
      expect(result.isPartial, isTrue);
    });

    test('ни один не готов — это ОТДЕЛЬНАЯ причина, не «пустой набор»', () {
      // Человеку надо сказать «не получилось выгрузить», а не «набор пустой»:
      // это разные причины и разные действия.
      final result = build(
        candidates: <StickerInviteCandidate>[failed('s0'), failed('s1')],
      );
      expect(result.refusal, StickerInviteRefusal.noUsableStickers);
      expect(result.requested, 2);
    });

    test('пустой набор отличается от неудачной выгрузки', () {
      expect(
        build(candidates: const <StickerInviteCandidate>[]).refusal,
        StickerInviteRefusal.emptyPack,
      );
    });
  });

  test('🔴 значок берётся ИЗ ОТПРАВЛЯЕМЫХ', () {
    // Указать стикер, который не уехал, значит отдать набор с битой обложкой.
    final result = build(
      candidates: <StickerInviteCandidate>[failed('s0'), ready('s1')],
      icon: 's0',
    );
    expect(result.invite!.iconStickerId, 's1');
  });

  test('значок сохраняется, если он уехал', () {
    final result = build(
      candidates: <StickerInviteCandidate>[ready('s0'), ready('s1')],
      icon: 's1',
    );
    expect(result.invite!.iconStickerId, 's1');
  });

  test('дубли не попадают в приглашение', () {
    final result = build(
      candidates: <StickerInviteCandidate>[ready('s0'), ready('s0')],
    );
    expect(result.invite!.items, hasLength(1));
  });

  test('🔴 потолок соблюдается и отражён в отчёте', () {
    final many = List<StickerInviteCandidate>.generate(
      StickerPackInvite.maxItems + 30,
      (i) => ready('s$i'),
    );
    final result = build(candidates: many);
    expect(result.invite!.items, hasLength(StickerPackInvite.maxItems));
    expect(result.included, StickerPackInvite.maxItems);
    expect(result.requested, many.length);
    expect(result.isPartial, isTrue, reason: 'человек должен узнать про обрез');
  });

  test('собранное приглашение переживает круг через провод', () {
    final result = build(
      candidates: <StickerInviteCandidate>[ready('s0'), ready('s1')],
    );
    final restored = StickerPackInvite.decode(result.invite!.encode());
    expect(restored, isNotNull);
    expect(restored!.items, hasLength(2));
    expect(restored.title, 'Мои стикеры');
  });
}
