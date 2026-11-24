// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Обложка по умолчанию — «Отпечаток S»; «Своя обложка» — первой строкой
// выбора (владелец, 23.11.2026).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  test('по умолчанию — «Отпечаток S», бесплатная и в каталоге', () {
    expect(kSPrintDefaultCover, isTrue);
    expect(kDefaultProfileCoverId, 'pattern_smark');
    expect(coverById(kDefaultProfileCoverId), isNotNull);
    expect(isCosmeticFree(CosmeticKind.profileCover, kDefaultProfileCoverId),
        isTrue);
    expect(coverWidgetFor(kDefaultProfileCoverId), isNotNull);
  });

  test('🔴 свой профиль и профиль собеседника: без обложки — «Отпечаток S», '
      '«Без обложки» остаётся пустым', () {
    final own = _src('lib/ui/profile_screen.dart');
    expect(own.contains('? kDefaultProfileCoverId'), isTrue);
    expect(own.contains('final noCover = controller.myCoverId == kNoProfileCoverId;'),
        isTrue);
    final peer = _src('lib/ui/contact_details_screen.dart');
    expect(peer.contains('kDefaultProfileCoverId,'), isTrue);
    expect(peer.contains('vm.coverId == kNoProfileCoverId'), isTrue);
    for (final f in [
      'lib/ui/desktop/chat/details/contact_details_view.dart',
      'lib/ui/desktop/chat/details/self_profile_view.dart',
    ]) {
      final s = _src(f);
      expect(s.contains('coverBackWidgetFor(kDefaultProfileCoverId)'), isTrue,
          reason: f);
      expect(s.contains('kNoProfileCoverId'), isTrue, reason: f);
    }
  });

  test('«Своя обложка» — в самом верху списка обложек', () {
    final s = _src('lib/ui/profile_cosmetics_screen.dart');
    final top = s.indexOf('if (row == 0) {');
    expect(top, greaterThan(0));
    expect(s.indexOf('return _CustomCoverTile(', top), greaterThan(top));
    expect(s.contains('final customAt'), isFalse);
  });
}
