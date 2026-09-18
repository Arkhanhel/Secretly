// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

String localizedFavoritesTitleForLanguageCode(String languageCode) {
  final normalized = languageCode.toLowerCase().replaceAll('-', '_');
  if (normalized.startsWith('de')) return 'Favoriten';
  if (normalized.startsWith('es')) return 'Favoritos';
  if (normalized.startsWith('fr')) return 'Favoris';
  if (normalized.startsWith('pt')) return 'Favoritos';
  if (normalized == 'ru' || normalized.startsWith('ru_')) return 'Избранное';
  if (normalized.startsWith('uk')) return 'Вибране';
  return 'Favorites';
}

String localizedFavoritesTitle(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (l10n != null) return l10n.favoritesTitle;
  final locale = Localizations.maybeLocaleOf(context);
  return localizedFavoritesTitleForLanguageCode(
    locale?.toLanguageTag() ?? 'en',
  );
}
