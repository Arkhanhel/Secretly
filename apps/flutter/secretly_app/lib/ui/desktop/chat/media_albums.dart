// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'message_bubble.dart';

/// Наибольшее число вложений в одном альбоме — как в Telegram.
const int kMaxAlbumItems = 10;

/// Какая «полка» у вложения: снимки и ролики склеиваются в сетку, файлы — в
/// стопку, музыка — в свою стопку. Голосовые и кружки не склеиваются.
enum AlbumShelf { visual, files, music }

AlbumShelf? albumShelfOf(MessageData m) {
  final a = m.attachment;
  if (a == null || m.sticker != null || m.callEvent != null) return null;
  if (a.videoNote || a.kind == MessageAttachmentKind.voice) return null;
  if (!a.sentAsFile &&
      (a.kind == MessageAttachmentKind.image ||
          a.kind == MessageAttachmentKind.video)) {
    return AlbumShelf.visual;
  }
  if (a.kind == MessageAttachmentKind.audio) return AlbumShelf.music;
  return AlbumShelf.files;
}

/// Склеивает альбомы: ПОДРЯД идущие сообщения одной группы (`media_group_id`)
/// от одного устройства и одной «полки».
///
/// 🔴 ПРАВИЛО ТО ЖЕ, ЧТО У ТЕЛЕФОНА (`sameImageGroup` в `chat_screen.dart`):
/// одна группа, одно устройство, снимки — только без имени файла. Иначе один
/// и тот же альбом выглядел бы на двух устройствах по-разному. Файлы телефон
/// не склеивает (каждый — своим пузырём); здесь они ложатся стопкой в один
/// пузырь, как в Telegram Desktop, — это различие только в показе.
///
/// Одно сообщение с номером группы остаётся обычной строкой: альбом из
/// одного снимка выглядит ровно как одиночный снимок.
List<MessageData> groupMediaAlbums(List<MessageData> messages) {
  final out = <MessageData>[];
  var i = 0;
  while (i < messages.length) {
    final first = messages[i];
    final group = (first.mediaGroupId ?? '').trim();
    final shelf = albumShelfOf(first);
    if (group.isEmpty || shelf == null) {
      out.add(first);
      i++;
      continue;
    }
    var j = i + 1;
    while (j < messages.length &&
        j - i < kMaxAlbumItems &&
        (messages[j].mediaGroupId ?? '').trim() == group &&
        messages[j].authorSeed == first.authorSeed &&
        albumShelfOf(messages[j]) == shelf) {
      j++;
    }
    if (j - i == 1) {
      out.add(first);
    } else {
      out.add(albumRow(messages.sublist(i, j)));
    }
    i = j;
  }
  return out;
}

/// Строка альбома: описывает первое сообщение группы, а подпись берёт у
/// того, у кого она есть (телефон кладёт её на первое).
MessageData albumRow(List<MessageData> items) {
  assert(items.length > 1);
  final first = items.first;
  MessageData? captioned;
  for (final m in items) {
    if (m.text.trim().isNotEmpty) {
      captioned = m;
      break;
    }
  }
  return first.copyWith(
    text: captioned?.text ?? '',
    mentions: captioned?.mentions,
    hasMention: items.any((m) => m.hasMention),
    edited: items.any((m) => m.edited),
    delivery: worstDelivery(items),
    albumItems: List<MessageData>.unmodifiable(items),
  );
}

/// Состояние доставки альбома — по самому отстающему сообщению: «прочитано»
/// честно только тогда, когда прочитано всё.
DeliveryStatus worstDelivery(List<MessageData> items) {
  const order = <DeliveryStatus>[
    DeliveryStatus.failed,
    DeliveryStatus.sending,
    DeliveryStatus.scheduled,
    DeliveryStatus.sent,
    DeliveryStatus.delivered,
    DeliveryStatus.read,
  ];
  var worst = items.first.delivery;
  for (final m in items) {
    if (order.indexOf(m.delivery) < order.indexOf(worst)) worst = m.delivery;
  }
  return worst;
}

/// Строка ленты, в которой лежит сообщение с [payloadId] (или с [id]):
/// сама строка или альбом, куда оно входит.
int indexOfRowContaining(
  List<MessageData> rows, {
  String? payloadId,
  String? id,
}) {
  bool matches(MessageData m) =>
      (payloadId != null && (m.payloadId ?? m.id) == payloadId) ||
      (id != null && m.id == id);
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (matches(row)) return i;
    final items = row.albumItems;
    if (items != null && items.any(matches)) return i;
  }
  return -1;
}
