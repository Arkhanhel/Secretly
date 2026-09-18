// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/animation.dart';

class DMotion {
  DMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration xslow = Duration(milliseconds: 320);

  static const Cubic easeOutCubic = Cubic(0.33, 1.0, 0.68, 1.0);
  static const Cubic easeInCubic = Cubic(0.32, 0.0, 0.67, 0.0);
  static const Cubic easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeInOut = Curves.easeInOut;

  static final SpringDescription snap = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 22,
  );
}
