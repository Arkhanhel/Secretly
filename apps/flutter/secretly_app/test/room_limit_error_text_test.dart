// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_invite_failure.dart';
import 'package:secretly_app/rooms/room_policy_failure.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/ui/room_policy_error_text.dart';

// Л-1 (17.09.2026): отказ сервера по лимиту комнат (402) показывался кодом —
// «group_member_limit_reached». Теперь — понятным текстом, где бы код ни ехал.

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('код находится в любой обёртке', () {
    const relay = RelayHttpException(
      operation: 'Relay room invite redeem',
      message: 'HTTP 402',
      statusCode: 402,
      responseBody: 'group_member_limit_reached',
    );
    expect(roomLimitCodeOf(relay), 'group_member_limit_reached');
    expect(
      roomLimitCodeOf(
        RoomPolicyFailure(
          RoomPolicyFailureCode.generic,
          message: 'group_join_limit_reached',
        ),
      ),
      'group_join_limit_reached',
    );
    expect(
      roomLimitCodeOf(
        const RoomInviteFailure(
          RoomInviteFailureCode.generic,
          message: 'group_create_limit_reached',
        ),
      ),
      'group_create_limit_reached',
    );
    expect(roomLimitCodeOf(StateError('boom')), isNull);
  });

  test('🔴 человек видит текст, а не код сервера', () {
    final text = tryRoomPolicyErrorText(
      ru,
      RoomPolicyFailure(
        RoomPolicyFailureCode.generic,
        message: 'group_member_limit_reached',
      ),
    )!;
    expect(text, startsWith('Комната заполнена'));
    expect(text.contains('group_'), isFalse);
    expect(
      roomLimitErrorText(
        en,
        const RelayHttpException(
          operation: 'x',
          message: 'HTTP 402',
          statusCode: 402,
          responseBody: 'group_join_limit_reached',
        ),
      ),
      startsWith('You are already in the maximum number of rooms'),
    );
  });
}
