// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Подпись альбома (24.11.2026, владелец: «комент почему-то не в пузыре
/// под фото, а только если открыть фото»).
///
/// В редакторе перед отправкой подпись пишется к открытому снимку — не
/// обязательно к первому. Пузырь альбома брал подпись только у первого
/// элемента, а при отправке подпись не первого снимка терялась. Теперь
/// подпись альбома — непустые подписи всех снимков по порядку, без
/// повторов, через перевод строки; `null` — подписи нет.
library;

String? albumCaptionOf(Iterable<String?> captions) {
  final seen = <String>{};
  final out = <String>[];
  for (final c in captions) {
    final t = c?.trim() ?? '';
    if (t.isEmpty || !seen.add(t)) continue;
    out.add(t);
  }
  return out.isEmpty ? null : out.join('\n');
}
