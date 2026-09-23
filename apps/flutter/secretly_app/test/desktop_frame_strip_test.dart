// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПОЛОСЫ РАМОК В ПРОФИЛЕ БОЛЬШЕ НЕТ (указание владельца 23.09.2026).
//
// ЧТО БЫЛО И ПОЧЕМУ УШЛО. Полоса показывала первые несколько рамок кружками
// прямо в профиле — задумка была в том, чтобы человек видел, за что платит, не
// нажимая ничего. На деле она дублировала кнопку «Рамка» из ряда действий и
// показывала при этом НЕ ВСЕ варианты: два входа в одно и то же, причём
// меньший врал полнотой.
//
// Файл оставлен, а не удалён: то, что полосы нет, — решение, и оно должно
// стеречься так же, как стереглось её наличие. Плюс здесь остались две
// проверки, которые пережили удаление и по-прежнему верны.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final view = File(
    'lib/ui/desktop/chat/details/self_profile_view.dart',
  ).readAsStringSync();

  test('🔴 полосы рамок в профиле нет', () {
    expect(view.contains('_FrameStrip'), isFalse);
    expect(view.contains('_FrameTile'), isFalse);
    expect(view.contains('_MoreFramesTile'), isFalse);
  });

  test('кнопка «Рамка» осталась — за ней полная сетка', () {
    // Единственный вход, и он ведёт ко ВСЕМ рамкам, а не к первым нескольким.
    expect(view.contains('_pickCosmetic(frame: true)'), isTrue);
  });

  test('признак доступа читается публичным геттером контроллера', () {
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(
      ctrl.contains('bool get cosmeticsUnlocked => _cosmeticsUnlocked;'),
      isTrue,
      reason: 'геттер добавочный: приватный остаётся тем, что решает публикацию',
    );
    // 🔴 Приватный геттер НЕ должен меняться — на нём висит поведение телефона:
    // публикация рамки, обложки и эмодзи-статуса.
    expect(
      ctrl.contains(
        'bool get _cosmeticsUnlocked =>\n'
        '      FeatureGate.isUnlocked(entitlementStateNow, GatedFeature.cosmetic);',
      ),
      isTrue,
    );
  });
}
