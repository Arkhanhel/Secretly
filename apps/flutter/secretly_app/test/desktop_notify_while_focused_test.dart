// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ОКНО В ФОКУСЕ МОЛЧИТ ТОЛЬКО ОБ ОТКРЫТОЙ ПЕРЕПИСКЕ (30.09.2026, ТЗ «ПК
// как Telegram» §5, этап 1).
//
// Раньше окно в фокусе глушило все уведомления: человек переписывался с
// одним и не знал, что пишет другой. Telegram Desktop молчит только о чате,
// который открыт перед глазами.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';

void main() {
  test('другой чат — уведомление', () {
    expect(
      desktopNotifyWhileFocused(
        enabled: true,
        openConvoId: 'dm:alice',
        convoId: 'dm:bob',
      ),
      isTrue,
    );
  });

  test('открытый чат — тишина', () {
    expect(
      desktopNotifyWhileFocused(
        enabled: true,
        openConvoId: 'group:team',
        convoId: 'group:team',
      ),
      isFalse,
    );
  });

  test('ничего не открыто — уведомление', () {
    expect(
      desktopNotifyWhileFocused(
        enabled: true,
        openConvoId: '',
        convoId: 'dm:bob',
      ),
      isTrue,
    );
  });

  test('выключено в настройках — тишина при окне в фокусе', () {
    expect(
      desktopNotifyWhileFocused(
        enabled: false,
        openConvoId: 'dm:alice',
        convoId: 'dm:bob',
      ),
      isFalse,
    );
  });
}
