// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import 'dart:io';

/// Открытая выкладка (`tools/build_public_repo.py` кладёт метку
/// `.public_tree`): звуков, обоев, значков и прочих файлов с чужой лицензией
/// или растров в ней нет. Проверки самих этих файлов там пропускаются.
final bool kPublicSourceTree = File('.public_tree').existsSync();

/// Причина пропуска для `skip:` — или `null` в рабочем репозитории.
String? skipInPublicTree(String what) => kPublicSourceTree
    ? 'в открытой выкладке нет $what (лицензия или растр)'
    : null;
