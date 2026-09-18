// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/room_flags.dart';

// К-2 / К-5 (17.09.2026): второй подписанный блок комнат. Текст подписи
// обязан совпадать с Rust `rooms2_signing_message` побайтово — иначе блок
// никогда не проверится и большие комнаты не откроются.

void main() {
  test('подписываемый текст совпадает с сервером', () {
    expect(
      rooms2SigningMessage(
        rawBroadcastEnabled: true,
        bigRoomMembers: 50,
        bigRoomMinBuild: 600,
        issuedAtMs: 42,
      ),
      'secretly-rooms2-v1|true|50|600|42',
    );
  });

  test('без проверенной подписи — всё выключено', () {
    final config = <String, dynamic>{
      'rooms2': <String, dynamic>{
        'raw_broadcast_enabled': true,
        'big_room_members': 50,
        'big_room_min_build': 600,
      },
    };
    expect(
      Rooms2Flags.fromConfigResponse(config, verified: false),
      Rooms2Flags.defaults,
    );
    final on = Rooms2Flags.fromConfigResponse(config, verified: true);
    expect(on.rawBroadcastEnabled, isTrue);
    expect(on.bigRoomMembers, 50);
    expect(on.bigRoomsAllowFor(600), isTrue);
    expect(on.bigRoomsAllowFor(599), isFalse);
    expect(const Rooms2Flags(bigRoomMembers: 50).bigRoomsAllowFor(999), isFalse);
  });

  test('старый сервер без блока — выключено', () {
    expect(
      Rooms2Flags.fromConfigResponse(const {}, verified: true),
      Rooms2Flags.defaults,
    );
  });
}
