// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Найдено на съёмке экранов 1.9 (24.11.2026):
// 1) прозрачные шапки давали белые значки строки состояния в светлой теме;
// 2) на живой (тёмной) обложке в светлой теме имя было чёрным и пропадало.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/frosted_top_bar.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  test('🔴 тема задаёт значки строки состояния по своей яркости', () {
    final s = _src('lib/main.dart');
    expect(
      s.contains(
        'statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,',
      ),
      isTrue,
    );
    // Цвета панелей системы не трогаются — только значки.
    final i = s.indexOf('systemOverlayStyle: SystemUiOverlayStyle(');
    final block = s.substring(i, s.indexOf('),', i));
    expect(block.contains('systemNavigationBarColor'), isFalse);
    expect(block.contains('statusBarColor'), isFalse);
  });

  testWidgets('шапка берёт стиль из темы, а свой — если задан', (t) async {
    const light = SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
    );
    final bar = frostedAppBar(title: const Text('x'));
    expect(bar.systemOverlayStyle, isNull);
    final own = frostedAppBar(title: const Text('x'), systemOverlayStyle: light);
    expect(own.systemOverlayStyle, light);
  });

  test('🔴 на живой обложке имя и «в сети» белые — свой профиль и чужой', () {
    final own = _src('lib/ui/profile_screen.dart');
    expect(own.contains('bool _ownCoverWantsLightText(AppController c)'), isTrue);
    expect(own.contains('final liveCoverText = _ownCoverWantsLightText(controller);'),
        isTrue);
    expect(own.contains('systemOverlayStyle: _ownCoverWantsLightText('), isTrue);
    final peer = _src('lib/ui/contact_details_screen.dart');
    expect(peer.contains('final liveCoverText ='), isTrue);
    expect(
      peer.contains('(_pullExpand > 0.35 && !heroOnLightFallback) || liveCoverText'),
      isTrue,
    );
  });
}
