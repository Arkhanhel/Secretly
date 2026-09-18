// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/profile_icon_gradients.dart';

void main() {
  test('profile icon secondary palette ends with black swatch', () {
    expect(kProfileIconPrimaryGradients.length, 10);
    expect(kProfileIconSecondaryGradients.length, 9);
    expect(kProfileIconAllGradients.length, 19);
    expect(kProfileIconSecondaryGradients.last.startArgb, 0xFF1F1F1F);
    expect(kProfileIconSecondaryGradients.last.endArgb, 0xFF000000);
  });
}