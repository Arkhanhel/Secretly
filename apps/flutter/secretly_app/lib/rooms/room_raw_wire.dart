// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import '../models/e2e_payload_v1.dart';

/// Сырой провод комнаты `SKR1` (К-2, 17.09.2026).
///
/// Запечатанное ключом комнаты сообщение (`gmsg`), которое реле раздаёт само
/// по `/v1/rooms/{id}/broadcast`, без попарной обёртки. Отправителя называет
/// реле (`from_device_id`), подлинность — подпись автора (К-1). Получают его
/// только устройства, заявившие `raw_v1` в подтверждении ключа.
class RoomRawWire {
  RoomRawWire._();

  static const List<int> _magic = <int>[0x53, 0x4B, 0x52, 0x31]; // "SKR1"

  static Uint8List encode(RoomMessageEventV1 event) {
    final body = utf8.encode(jsonEncode(event.toJson()));
    return Uint8List.fromList(<int>[..._magic, ...body]);
  }

  /// Провод `SKR1` с подписанным `gmsg`, или null — если это не он.
  static RoomMessageEventV1? tryDecode(Uint8List wire) {
    if (wire.length <= _magic.length) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (wire[i] != _magic[i]) return null;
    }
    try {
      final json = jsonDecode(utf8.decode(wire.sublist(_magic.length)));
      if (json is! Map || json['type'] != 'gmsg') return null;
      final event = RoomMessageEventV1.fromJson(Map<String, dynamic>.from(json));
      return event.signature == null ? null : event;
    } catch (_) {
      return null;
    }
  }

  /// Похож ли провод на `SKR1` (без разбора).
  static bool looksLike(Uint8List wire) =>
      wire.length > _magic.length &&
      wire[0] == _magic[0] &&
      wire[1] == _magic[1] &&
      wire[2] == _magic[2] &&
      wire[3] == _magic[3];
}
