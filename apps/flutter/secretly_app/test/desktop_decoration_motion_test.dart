// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 УКРАШЕНИЯ ЗАМИРАЮТ, КОГДА ОКНО БЕЗ ФОКУСА (01.10.2026).
//
// Рамки, эмодзи-статусы и живые эмодзи в тексте крутились, пока человек
// работал в другом приложении. Кружки загрузки при этом гасить нельзя
// (`onWindowBlur`), поэтому обёртка ставится только вокруг декорации, а под
// непрозрачными слоями (настройки, звонок, замок) гаснет всё.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';

void main() {
  tearDown(() => DesktopWindowActivity.focused.value = true);

  testWidgets('без фокуса тикеры декорации немые, с фокусом — снова живые',
      (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      DesktopDecorationMotion(
        child: Builder(
          builder: (context) {
            inner = context;
            TickerMode.valuesOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(TickerMode.valuesOf(inner).enabled, isTrue);

    DesktopWindowActivity.focused.value = false;
    await t.pump();
    expect(TickerMode.valuesOf(inner).enabled, isFalse);

    DesktopWindowActivity.focused.value = true;
    await t.pump();
    expect(TickerMode.valuesOf(inner).enabled, isTrue);
  });

  testWidgets('фокус не включает то, что погасил предок', (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      TickerMode(
        enabled: false,
        child: DesktopDecorationMotion(
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(TickerMode.valuesOf(inner).enabled, isFalse);
  });

  test('обёртка стоит там, где крутится декорация', () {
    String read(String path) => File(path).readAsStringSync();
    expect(
      read('lib/ui/desktop/primitives/avatar.dart'),
      contains('DesktopDecorationMotion('),
      reason: 'рамка портрета',
    );
    expect(
      read('lib/ui/desktop/chat/noto_emoji_lottie.dart'),
      contains('DesktopDecorationMotion('),
      reason: 'эмодзи-статус',
    );
    expect(
      read('lib/ui/desktop/chat/message_rich_text.dart'),
      contains('DesktopDecorationMotion('),
      reason: 'эмодзи в тексте',
    );
  });

  test('под настройками, звонком и замком окно не движется', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(
      app.contains('TickerMode(enabled: !covered, child: shell)'),
      isTrue,
    );
    final lock = File(
      'lib/ui/desktop/app/desktop_lock_overlay.dart',
    ).readAsStringSync();
    expect(
      lock.contains('TickerMode(enabled: !locked, child: widget.child)'),
      isTrue,
    );
  });
}
