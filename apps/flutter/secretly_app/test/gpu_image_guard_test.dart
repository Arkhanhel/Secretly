// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Розово-фиолетовые квадраты (23.11.2026): картинки видеокарты для долгих
// кешей делаются только на экране и сбрасываются при возвращении из фона.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/gpu_image_guard.dart';

void main() {
  testWidgets('в фоне снимков нет, при возвращении кеши сбрасываются', (
    t,
  ) async {
    var resets = 0;
    GpuImageGuard.register(() => resets++);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(GpuImageGuard.canSnapshot, isTrue);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(GpuImageGuard.canSnapshot, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(GpuImageGuard.canSnapshot, isFalse);
    expect(resets, 0);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(GpuImageGuard.canSnapshot, isTrue);
    expect(resets, 1, reason: 'возвращение из фона сбрасывает кеши');

    // Шторка (неактивно → на экране) — без сброса.
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(resets, 1);
  });

  test('🔴 статусы не держат кадры картинками видеокарты', () {
    final src = File('lib/ui/emoji/noto_status_emoji.dart').readAsStringSync();
    expect(src.contains('renderCache: RenderCache.raster'), isFalse);
    expect(src.contains('renderCache: RenderCache.drawingCommands'), isTrue);
  });

  test('долгие кеши подключены к сторожу и кешируют всегда', () {
    for (final f in const [
      'lib/ui/premium/profile_fx/util.dart',
      'lib/ui/premium/profile_fx/covers/classic.dart',
      'lib/ui/chat/reaction_burst.dart',
      'lib/ui/profile/pattern_cover_extra.dart',
      'lib/ui/premium/premium_firefly_logo.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('GpuImageGuard.register('), isTrue, reason: f);
      // 🔴 Сборка 725: «не на экране — не класть в кеш» делало новую
      // картинку на каждый вызов (лаги, пропадали рамки и обложки). Кеш
      // работает всегда, сторож только сбрасывает его после фона.
      expect(src.contains('GpuImageGuard.canSnapshot'), isFalse, reason: f);
    }
  });
}
