// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import '../../../models/e2e_payload_v1.dart';
import 'message_bubble.dart' show MessageAttachmentKind;

/// Какого вида вложение — по тем же признакам, что у телефона.
///
/// 🔴 ГОЛОСОВОЕ УЗНАЁТСЯ И ПО ВОЛНЕ. Телефон пишет голосовые в `.m4a` с
/// типом `audio/mp4` — по типу это неотличимо от песни, и окно показывало
/// голосовые с телефона как «Аудиофайл». Телефон отличает их по волне
/// громкости: у голосового она есть всегда, у музыки её нет
/// (`_isVoiceMessageAttachment` в `chat_screen.dart`).
MessageAttachmentKind desktopAttachmentKind(AttachmentEventV1 a) {
  final lower = (a.mime ?? '').trim().toLowerCase();
  if (lower.startsWith('image/')) return MessageAttachmentKind.image;
  if (lower.startsWith('video/')) return MessageAttachmentKind.video;
  if (isVoiceMime(lower) || (a.waveform?.isNotEmpty ?? false)) {
    return MessageAttachmentKind.voice;
  }
  if (lower.startsWith('audio/')) return MessageAttachmentKind.audio;
  return MessageAttachmentKind.file;
}

bool isVoiceMime(String lower) =>
    lower == 'audio/ogg' ||
    lower == 'audio/opus' ||
    lower.startsWith('audio/webm') ||
    lower == 'audio/3gpp' ||
    lower == 'audio/amr';

/// Качается ли вложение само, без нажатия.
///
/// Как в Telegram: снимки, ролики и голосовые показываются прямо в ленте и
/// качаются сразу; файл и песня — по нажатию «Загрузить».
bool desktopAutoDownloads(
  MessageAttachmentKind kind, {
  required bool sentAsFile,
}) {
  if (sentAsFile) return false;
  return switch (kind) {
    MessageAttachmentKind.image ||
    MessageAttachmentKind.video ||
    MessageAttachmentKind.voice => true,
    MessageAttachmentKind.audio || MessageAttachmentKind.file => false,
  };
}

/// Миниатюра от отправителя (`thumb_b64`). Испорченная — `null`.
Uint8List? decodeAttachmentThumb(String? b64) {
  final raw = (b64 ?? '').trim();
  if (raw.isEmpty || raw.length > 64 * 1024) return null;
  try {
    final bytes = base64Decode(raw);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}
