// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
package com.secretly.secretly_app

import androidx.core.content.FileProvider

/**
 * «Копировать» фото в просмотре (22.11.2026): плагин pasteboard кладёт снимок
 * в кэш и отдаёт буферу обмена ссылку через `${applicationId}.provider`.
 * Второй FileProvider нельзя объявить тем же классом, что и основной
 * (`.fileprovider`), — слияние манифестов отвергнет дубль, поэтому свой
 * пустой подкласс. Пути — те же `secretly_file_paths` (кэш приложения).
 */
class PasteboardFileProvider : FileProvider()
