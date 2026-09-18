// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Sticker tab is housed inside [EmojiPopover] via tabs ("Эмодзи / Стикеры / GIF").
/// Keeping this file as an explicit marker for the architecture; re-export the
/// EmojiPopover so callers can `import 'sticker_popover.dart'` if they prefer
/// that mental model.
library;

export 'emoji_popover.dart';
