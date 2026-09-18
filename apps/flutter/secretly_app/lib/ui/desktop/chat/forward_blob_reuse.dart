// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПЕРЕСЫЛКА СЕБЕ: ТОТ ЖЕ ФАЙЛ, БЕЗ НОВОЙ ЗАЛИВКИ.
///
/// 🔴 ПОЧЕМУ ТОЛЬКО СЕБЕ (правило телефона от 14.08.2026). Пересылая на свои
/// устройства, можно отдать тот же зашифрованный файл и тот же ключ: оба конца
/// мои, заливать заново незачем — экономится и время, и трафик.
///
/// Чужому получателю так делать НЕЛЬЗЯ: сервер увидел бы один файл в двух
/// разных переписках, то есть узнал бы, что его переслали из A в B. Само
/// содержимое защищено одинаково, речь именно о следах.
///
/// Компьютер этого не делал вовсе и каждый раз заливал файл заново.
library;

import '../../../models/e2e_payload_v1.dart';

AttachmentEventV1? desktopReusableBlobForForward({
  required AttachmentEventV1? source,
  required bool toGroup,
  required String? targetProfileId,
  required String myProfileId,
}) {
  if (source == null) return null;
  if (toGroup) return null;
  final target = (targetProfileId ?? '').trim();
  final me = myProfileId.trim();
  if (target.isEmpty || me.isEmpty) return null;
  if (target != me) return null;
  return source;
}
