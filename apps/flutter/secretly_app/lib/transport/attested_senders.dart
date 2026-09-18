// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Кто на самом деле прислал провод — по словам реле (ИД-1 / С-1, 17.09.2026).
///
/// Номер отправителя в заголовке провода — слова самого провода. Реле же знает
/// отправителя наверняка: оно проверило подпись при отправке. С 17.09 оно
/// отдаёт его в кадре доставки (`from_device_id`). Кадр разбирается в одном
/// месте, а решение принимается в другом (`AppController._handleDelivered`),
/// поэтому номер ждёт здесь, по `msg_id`.
///
/// Один реестр на изолят: фоновый изолят заполняет свой и сам же читает.
/// Ограничен по размеру: неразобранные записи не копятся.
class AttestedSenders {
  AttestedSenders._();

  static const int _cap = 4096;
  static final LinkedHashMap<String, String> _byMsgId =
      LinkedHashMap<String, String>();

  /// Запомнить отправителя провода [msgId]. Пустые значения игнорируются.
  static void record(String? msgId, Object? fromDeviceId) {
    final id = (msgId ?? '').trim();
    final from = fromDeviceId is String ? fromDeviceId.trim() : '';
    if (id.isEmpty || from.isEmpty) return;
    _byMsgId.remove(id);
    _byMsgId[id] = from;
    while (_byMsgId.length > _cap) {
      _byMsgId.remove(_byMsgId.keys.first);
    }
  }

  /// Отправитель по словам реле, или null — если реле его не назвало
  /// (старое реле, строка из очереди до 17.09, путь без этого поля).
  static String? lookup(String msgId) => _byMsgId[msgId.trim()];

  static void forget(String msgId) => _byMsgId.remove(msgId.trim());

  @visibleForTesting
  static void clearForTesting() => _byMsgId.clear();
}
