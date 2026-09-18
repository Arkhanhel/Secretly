// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Рамка аватара выбирается в самом профиле, а не только в модальном окне.
//
// 🔴 ЧТО БЫЛО. Рамку можно было выбрать ТОЛЬКО в диалоге за кнопкой «Рамка»:
// о существовании двух десятков рамок надо было сперва догадаться. В макете
// они лежат в профиле кружками с настоящими градиентами и подписями — человек
// видит, за что платит, ещё ничего не нажав.
//
// Второе: платные варианты ПОКАЗЫВАЮТСЯ с замком, а не прячутся. Спрятанное
// платное содержимое человек считает отсутствующим, а увиденное — выбором.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final view = File(
    'lib/ui/desktop/chat/details/self_profile_view.dart',
  ).readAsStringSync();

  test('полоса рамок стоит в самой панели', () {
    expect(view.contains('_FrameStrip('), isTrue);
    expect(
      view.contains('frames: kAvatarFrames'),
      isTrue,
      reason: 'полоса должна брать настоящий каталог, а не свой список',
    );
  });

  test('кнопка в полную сетку никуда не делась', () {
    expect(view.contains('onMore: () => unawaited(_pickCosmetic(frame: true))'), isTrue);
    expect(view.contains('class _MoreFramesTile'), isTrue);
  });

  test('🔴 заблокированные рамки видны, но не применяются', () {
    expect(view.contains('locked: !unlocked'), isTrue);
    expect(
      view.contains('onTap: unlocked ? () => onPick(f.id) : null'),
      isTrue,
      reason: 'нажатие по заблокированной рамке не должно ничего применять',
    );
    expect(view.contains("'PRO'"), isTrue);
    expect(view.contains('lock_closed_12_filled'), isTrue);
  });

  test('признак доступа читается публичным геттером контроллера', () {
    expect(view.contains('unlocked: _c.cosmeticsUnlocked'), isTrue);
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(
      ctrl.contains('bool get cosmeticsUnlocked => _cosmeticsUnlocked;'),
      isTrue,
      reason: 'геттер добавочный: приватный остаётся тем, что решает публикацию',
    );
    // Приватный геттер НЕ должен был измениться — на нём висит поведение
    // телефона: публикация рамки, обложки и эмодзи-статуса.
    expect(
      ctrl.contains(
        'bool get _cosmeticsUnlocked =>\n'
        '      FeatureGate.isUnlocked(entitlementStateNow, GatedFeature.cosmetic);',
      ),
      isTrue,
    );
  });

  test('живые кольца в полосе выключены', () {
    // Панель открыта постоянно: два десятка анимированных рамок здесь — это
    // вечная перерисовка, за которую уже платили процентами процессора.
    expect(view.contains('allowAnimatedFrame: false'), isTrue);
  });
}
