// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import '../models/link_preview_v1.dart';
import '../ui/chat_message_mentions.dart'
    show extractChatMessageLinks, firstChatMessageLink;

/// Для какой ссылки текста готовить превью — первой http(s)-ссылки.
///
/// Первая — потому что карточка у сообщения одна, и так же выбирает телеграм.
Uri? linkPreviewTargetFor(String text) {
  final link = firstChatMessageLink(text);
  if (link == null) return null;
  final scheme = link.uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  return link.uri;
}

/// Сколько байт может занимать открытый текст сообщения вместе с превью.
///
/// 🔴 СООБЩЕНИЕ КОМНАТЫ ПО ДОРОГЕ ТРИЖДЫ ЗАВОРАЧИВАЕТСЯ В BASE64: конверт
/// комнаты, запечатывание ключом комнаты, пересылка по устройствам — каждый
/// слой прибавляет треть. Реле принимает до 256 КБ, и 90 КБ × (4/3)³ ≈ 213 КБ
/// оставляют запас на служебные поля. Без этого предела длинный текст со
/// ссылкой, который раньше уходил, перестал бы отправляться вовсе.
const int kLinkPreviewMessageBudgetBytes = 90 * 1024;

/// Превью можно отправить вместе с [text], только если оно — для первой
/// ссылки ЭТОГО текста и сообщение с ним не выходит за
/// [kLinkPreviewMessageBudgetBytes].
///
/// Человек мог стереть ссылку или вставить другую, пока превью грузилось;
/// карточка от прежней ссылки ушла бы к чужому тексту. Не влезает целиком —
/// уходит без картинки; не влезает и так — сообщение уходит без карточки,
/// ровно как уходило до превью.
LinkPreviewV1? linkPreviewForOutgoing(LinkPreviewV1? preview, String text) {
  if (preview == null) return null;
  final target = linkPreviewTargetFor(text);
  if (target == null || target.toString() != preview.url) return null;
  final textBytes = utf8.encode(text).length;
  int size(LinkPreviewV1 p) => utf8.encode(jsonEncode(p.toJson())).length;
  if (textBytes + size(preview) <= kLinkPreviewMessageBudgetBytes) {
    return preview;
  }
  if (preview.thumbnail == null) return null;
  final bare = preview.withoutThumbnail();
  if (bare.isEmpty) return null;
  return textBytes + size(bare) <= kLinkPreviewMessageBudgetBytes ? bare : null;
}

/// Приехавшее превью показывается, только если его адрес — одна из ссылок
/// САМОГО сообщения.
///
/// 🔴 Иначе отправитель мог бы написать «вот ссылка на банк» с одним адресом,
/// а карточку приложить от другого — подделка, которую карточка делала бы
/// убедительной. Так же поступает Signal.
LinkPreviewV1? acceptIncomingLinkPreview(LinkPreviewV1? preview, String text) {
  if (preview == null) return null;
  for (final link in extractChatMessageLinks(text)) {
    if (link.uri.toString() == preview.url) return preview;
  }
  return null;
}
