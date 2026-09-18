// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/stickers/sticker_pack_invite.dart';

// Ш-2 ТЗ по стикерам: приглашение в набор по E2EE (08.08.2026).
//
// 🔴 ЭТОТ ФОРМАТ УВИДЯТ ЧУЖИЕ СБОРКИ, поэтому ошибка в нём необратима: она
// приезжает в чужие руки и живёт там до обновления. Здесь закреплено то, что
// формат обязан выдерживать: незнакомую версию, мусор в полях, дубли, слишком
// большие наборы — и всё это БЕЗ падения на входящем сообщении.
//
// Шрам, ради которого это так: 1.7.4+416, где отказ читать входящее означал
// безвозвратную потерю сообщений.

StickerPackInviteItem item(String id) => StickerPackInviteItem(
  stickerId: id,
  fileName: '$id.png',
  format: 'png',
  animated: false,
  blobId: 'blob-$id',
  fileKeyB64: 'a2V5',
  emojiHint: '🙂',
  sizeBytes: 1234,
);

StickerPackInvite invite({int count = 2}) => StickerPackInvite(
  packId: 'user:P1:abc',
  packVersion: 3,
  title: 'Мои стикеры',
  iconStickerId: 's0',
  items: List<StickerPackInviteItem>.generate(count, (i) => item('s$i')),
);

void main() {
  group('круг', () {
    test('приглашение переживает кодирование и разбор', () {
      final restored = StickerPackInvite.decode(invite().encode())!;
      expect(restored.packId, 'user:P1:abc');
      expect(restored.packVersion, 3);
      expect(restored.title, 'Мои стикеры');
      expect(restored.items, hasLength(2));
      expect(restored.items.first.blobId, 'blob-s0');
      expect(restored.items.first.fileKeyB64, 'a2V5');
      expect(restored.isUserPack, isTrue);
    });

    test('🔴 путь к файлу на моём устройстве НЕ уезжает', () {
      // Собеседнику он бесполезен, а раскрывает лишнее: имя пользователя в
      // пути, структуру каталогов, иногда модель устройства.
      final raw = invite().encode().toLowerCase();
      expect(raw.contains('localpath'), isFalse);
      expect(raw.contains('/users/'), isFalse);
      expect(raw.contains('/var/mobile'), isFalse);
    });
  });

  group('отказ в закрытую', () {
    test('🔴 незнакомая версия игнорируется, а НЕ роняет разбор', () {
      final json = invite().toJson()..['v'] = 999;
      expect(StickerPackInvite.fromJson(json), isNull);
      // И обратно: то же сообщение без версии тоже просто не наше.
      final noVersion = invite().toJson()..remove('v');
      expect(StickerPackInvite.fromJson(noVersion), isNull);
    });

    test('чужой вид сообщения не разбирается как приглашение', () {
      final json = invite().toJson()..['kind'] = 'sticker';
      expect(StickerPackInvite.fromJson(json), isNull);
    });

    test('мусор вместо приглашения даёт null, а не исключение', () {
      for (final raw in <Object?>[null, 42, 'строка', <int>[1, 2], <String, Object?>{}]) {
        expect(StickerPackInvite.fromJson(raw), isNull, reason: '$raw');
      }
      expect(StickerPackInvite.decode('не json'), isNull);
      expect(StickerPackInvite.decode(''), isNull);
    });

    test('приглашение без обязательных полей отвергается', () {
      for (final key in const <String>['packId', 'title']) {
        final json = invite().toJson()..[key] = '';
        expect(StickerPackInvite.fromJson(json), isNull, reason: key);
      }
      expect(
        StickerPackInvite.fromJson(invite().toJson()..['packVersion'] = 0),
        isNull,
      );
    });
  });

  group('негодные стикеры внутри годного приглашения', () {
    test('🔴 битый стикер отбрасывается, остальные принимаются', () {
      // Выбросить весь набор из-за одного битого стикера было бы хуже для
      // человека, чем набор на один стикер меньше.
      final json = invite().toJson();
      final items = List<Object?>.from(json['items'] as List);
      items.add(<String, Object?>{'stickerId': 'нет блоба'});
      items.add('вообще не карта');
      items.add(<String, Object?>{'blobId': 'b', 'fileKeyB64': 'k'}); // нет id
      json['items'] = items;

      final restored = StickerPackInvite.fromJson(json)!;
      expect(restored.items, hasLength(2), reason: 'только пригодные');
    });

    test('🔴 стикер БЕЗ ключа непригоден — иначе набор придёт с дырами', () {
      final json = invite(count: 1).toJson();
      (json['items'] as List)[0] = <String, Object?>{
        'stickerId': 's0',
        'fileName': 's0.png',
        'format': 'png',
        'blobId': 'blob-s0',
        // fileKeyB64 отсутствует
      };
      expect(StickerPackInvite.fromJson(json), isNull,
          reason: 'ни одного пригодного стикера — предлагать нечего');
    });

    test('дубли по stickerId схлопываются', () {
      final json = invite(count: 1).toJson();
      final items = List<Object?>.from(json['items'] as List);
      items.add(item('s0').toJson());
      json['items'] = items;
      expect(StickerPackInvite.fromJson(json)!.items, hasLength(1));
    });

    test('имя файла и значок восстановимы, набор из-за них не теряется', () {
      final json = invite(count: 1).toJson();
      (json['items'] as List)[0] = <String, Object?>{
        'stickerId': 's0',
        'format': 'png',
        'blobId': 'b',
        'fileKeyB64': 'k',
      };
      json['iconStickerId'] = '';
      final restored = StickerPackInvite.fromJson(json)!;
      expect(restored.items.first.fileName, 's0.png');
      expect(restored.iconStickerId, 's0');
    });
  });

  test('🔴 потолок стикеров соблюдается', () {
    // Конверт едет ОДНИМ сообщением: набор в тысячу стикеров собрал бы конверт,
    // который не пролезет, и отправка молча умерла бы у человека на руках.
    final json = invite(count: 1).toJson();
    json['items'] = List<Object?>.generate(
      StickerPackInvite.maxItems + 50,
      (i) => item('s$i').toJson(),
    );
    final restored = StickerPackInvite.fromJson(json)!;
    expect(restored.items, hasLength(StickerPackInvite.maxItems));
  });

  test('вид и версия на проводе закреплены', () {
    // Смена любого из двух ломает совместимость со сборками, которые уже уехали.
    expect(StickerPackInvite.wireKind, 'sticker_pack_invite');
    expect(StickerPackInvite.wireVersion, 1);
    final decoded = jsonDecode(invite().encode()) as Map<String, Object?>;
    expect(decoded['kind'], 'sticker_pack_invite');
    expect(decoded['v'], 1);
  });
}
