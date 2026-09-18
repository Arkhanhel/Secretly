// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math';

import '../storage/app_db.dart';

class OutgoingMessageScheduler {
  OutgoingMessageScheduler({
    required this.db,
    required this.pumpTransport,
    String? workerId,
  }) : workerId = workerId ?? _newWorkerId();

  final AppDb db;
  final Future<void> Function() pumpTransport;
  final String workerId;

  static const int staleLeaseMs = 45 * 1000;

  static String _newWorkerId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'msg-worker-$now-$rand';
  }

  Future<int> recoverStaleLeases({int? nowMs}) async {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return db.outboxRecoverStaleLeases(olderThanMs: ts - staleLeaseMs);
  }

  Future<List<Map<String, Object?>>> leaseDue({int limit = 20}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.outboxLeaseDue(
      workerId: workerId,
      nowMs: now,
      limit: limit,
      staleLeaseBeforeMs: now - staleLeaseMs,
    );
  }

  Future<void> releaseLease(String msgId) {
    return db.outboxReleaseLease(msgId: msgId, workerId: workerId);
  }

  Future<void> triggerNow() => pumpTransport();
}
