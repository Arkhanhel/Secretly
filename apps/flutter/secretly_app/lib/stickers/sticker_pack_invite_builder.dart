// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Сборка приглашения в набор — решающая часть Ш-2, вынесенная из ввода-вывода.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНО ОТ КОНТРОЛЛЕРА. Здесь живут решения, которые дороже всего
/// ошибиться: уезжает ли личный набор, что делать с частично выгруженными
/// стикерами, сколько сказать человеку. Внутри контроллера это было бы
/// непроверяемо — а проверять надо именно эти ответы, не выгрузку.
library;

import 'sticker_pack_invite.dart';
import 'sticker_share_mode.dart';

/// Почему приглашение не собралось.
enum StickerInviteRefusal {
  /// Набор помечен личным.
  ///
  /// 🔴 Самый важный отказ во всём Ш-2. Человек выбрал «личный», и это
  /// обещание: набор не уезжает. Отправить его «потому что попросили поделиться»
  /// значило бы нарушить настройку, которую сам же и предложил.
  personalMode,

  /// В наборе нет стикеров.
  emptyPack,

  /// Ни одного стикера не удалось подготовить к отправке.
  ///
  /// Отличается от [emptyPack] намеренно: человеку надо сказать «не получилось
  /// выгрузить», а не «набор пустой» — это разные причины и разные действия.
  noUsableStickers,
}

/// Стикер-кандидат: то, что о нём знает база, плюс ссылка на блоб, если она
/// уже есть.
class StickerInviteCandidate {
  const StickerInviteCandidate({
    required this.stickerId,
    required this.fileName,
    required this.format,
    required this.animated,
    this.emojiHint = '',
    this.label = '',
    this.sizeBytes,
    this.sha256B64,
    this.blobId,
    this.fileKeyB64,
    this.accessTokenB64,
  });

  final String stickerId;
  final String fileName;
  final String format;
  final bool animated;
  final String emojiHint;
  final String label;
  final int? sizeBytes;
  final String? sha256B64;

  /// Ссылка на шифртекст. `null`, если выгрузить не удалось.
  final String? blobId;
  final String? fileKeyB64;
  final String? accessTokenB64;

  bool get hasBlob =>
      (blobId ?? '').trim().isNotEmpty && (fileKeyB64 ?? '').trim().isNotEmpty;
}

/// Что вышло из сборки.
class StickerInviteBuildResult {
  const StickerInviteBuildResult._({
    this.invite,
    this.refusal,
    required this.requested,
    required this.included,
  });

  const StickerInviteBuildResult.refused(
    StickerInviteRefusal reason, {
    required int requested,
  }) : this._(refusal: reason, requested: requested, included: 0);

  const StickerInviteBuildResult.built(
    StickerPackInvite invite, {
    required int requested,
    required int included,
  }) : this._(invite: invite, requested: requested, included: included);

  final StickerPackInvite? invite;
  final StickerInviteRefusal? refusal;

  /// Сколько стикеров было в наборе.
  final int requested;

  /// Сколько уехало.
  final int included;

  bool get isBuilt => invite != null;

  /// Уехало не всё.
  ///
  /// 🔴 Отдельный признак, потому что человеку надо СКАЗАТЬ. Молча отправить
  /// половину набора хуже, чем не отправить: получатель решит, что автор так и
  /// задумал, а автор будет уверен, что поделился целиком.
  bool get isPartial => isBuilt && included < requested;
}

/// Собирает приглашение.
///
/// 🔴 ЧАСТИЧНЫЙ УСПЕХ ЛУЧШЕ ОТКАЗА, но только если о нём сказать. Набор в 50
/// стикеров — это 50 попыток подготовки, и одна неудача почти неизбежна. Ронять
/// из-за неё всю отправку значило бы, что поделиться большим набором нельзя
/// вообще. Поэтому отправляем то, что готово, и возвращаем [
/// StickerInviteBuildResult.isPartial], чтобы интерфейс не смолчал.
StickerInviteBuildResult buildStickerPackInvite({
  required String packId,
  required int packVersion,
  required String title,
  required String iconStickerId,
  required StickerShareMode shareMode,
  required List<StickerInviteCandidate> candidates,
}) {
  final requested = candidates.length;

  // 🔴 ПЕРВОЙ ПРОВЕРКОЙ, до всякой работы. Личный набор не должен даже начать
  // готовиться к отправке: выгрузка блоба — это уже отправка шифртекста на
  // сервер, и делать её для набора, который обещан не уезжающим, нельзя.
  if (!shareMode.allowsSendingToPeers) {
    return StickerInviteBuildResult.refused(
      StickerInviteRefusal.personalMode,
      requested: requested,
    );
  }

  if (requested == 0) {
    return StickerInviteBuildResult.refused(
      StickerInviteRefusal.emptyPack,
      requested: 0,
    );
  }

  final items = <StickerPackInviteItem>[];
  final seen = <String>{};
  for (final candidate in candidates) {
    if (items.length >= StickerPackInvite.maxItems) break;
    if (!candidate.hasBlob) continue;
    final id = candidate.stickerId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    items.add(
      StickerPackInviteItem(
        stickerId: id,
        fileName: candidate.fileName.trim().isEmpty
            ? '$id.${candidate.format}'
            : candidate.fileName.trim(),
        format: candidate.format.trim(),
        animated: candidate.animated,
        blobId: candidate.blobId!.trim(),
        fileKeyB64: candidate.fileKeyB64!.trim(),
        accessTokenB64: (candidate.accessTokenB64 ?? '').trim().isEmpty
            ? null
            : candidate.accessTokenB64!.trim(),
        emojiHint: candidate.emojiHint.trim(),
        label: candidate.label.trim(),
        sizeBytes: candidate.sizeBytes,
        sha256B64: candidate.sha256B64,
      ),
    );
  }

  if (items.isEmpty) {
    return StickerInviteBuildResult.refused(
      StickerInviteRefusal.noUsableStickers,
      requested: requested,
    );
  }

  final icon = iconStickerId.trim();
  return StickerInviteBuildResult.built(
    StickerPackInvite(
      packId: packId.trim(),
      packVersion: packVersion,
      title: title.trim(),
      // Значок обязан быть ИЗ ОТПРАВЛЯЕМЫХ. Указать стикер, который не уехал,
      // значит отдать набор с битой обложкой.
      iconStickerId: seen.contains(icon) ? icon : items.first.stickerId,
      items: List<StickerPackInviteItem>.unmodifiable(items),
    ),
    requested: requested,
    included: items.length,
  );
}
