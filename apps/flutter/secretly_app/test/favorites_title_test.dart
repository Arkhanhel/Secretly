// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/favorites_title.dart';

void main() {
  test('favorites title localizes by language code', () {
    expect(localizedFavoritesTitleForLanguageCode('ru'), 'Избранное');
    expect(localizedFavoritesTitleForLanguageCode('ru-RU'), 'Избранное');
    expect(localizedFavoritesTitleForLanguageCode('uk'), 'Вибране');
    expect(localizedFavoritesTitleForLanguageCode('es'), 'Favoritos');
    expect(localizedFavoritesTitleForLanguageCode('pt-BR'), 'Favoritos');
    expect(localizedFavoritesTitleForLanguageCode('fr'), 'Favoris');
    expect(localizedFavoritesTitleForLanguageCode('de'), 'Favoriten');
    expect(localizedFavoritesTitleForLanguageCode('en'), 'Favorites');
  });
}
