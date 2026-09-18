// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/diagnostics/identity_journal.dart';

/// The breadcrumb that explains why an identity was replaced.
///
/// On 2026-07-30 we found 38 identity replacements on the relay — nine of them
/// identities that died within a MINUTE of birth — and could not say why a
/// single one happened. The answer had to be reconstructed by joining two
/// production databases, and it still came out inconclusive. These tests pin
/// the properties that make the next occurrence explain itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('identity_journal');
    // path_provider has no implementation in a unit test; point it at tmp.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File journalFile() => File(p.join(tmp.path, IdentityJournal.fileName));

  test('records who decided, and keeps the evidence in order', () async {
    await IdentityJournal.record(
      reason: IdentityJournal.reasonNoLocalProfile,
      nowMs: 1000,
      detail: const {'db_file_present': true},
    );
    await IdentityJournal.record(
      reason: IdentityJournal.reasonServerSaysDeleted,
      nowMs: 2000,
      previousProfileId: 'ABCD-EFGH-IJKL',
      previousDeviceId: '01234567-89ab',
    );

    final entries = await IdentityJournal.read();
    expect(entries, hasLength(2));
    expect(entries.first['reason'], IdentityJournal.reasonNoLocalProfile);
    // The distinguishing fact: a fresh install has no database file, so its
    // presence means state was PARTIALLY lost.
    expect(entries.first['db_file_present'], isTrue);
    expect(entries.last['reason'], IdentityJournal.reasonServerSaysDeleted);
    expect(entries.last['at_ms'], 2000);
  });

  test('stores only a prefix of an identity, never the whole thing', () async {
    // This file is meant to be pasted into a support ticket. It must be enough
    // to correlate with a server-side record and not a copy of the user's
    // identity sitting in a readable file.
    await IdentityJournal.record(
      reason: IdentityJournal.reasonUserInitiated,
      nowMs: 1,
      previousProfileId: 'SECRET-PROFILE-ID-1234567890',
      previousDeviceId: 'secret-device-id-0987654321',
    );
    final raw = await journalFile().readAsString();
    expect(raw.contains('SECRET-PROFILE-ID-1234567890'), isFalse);
    expect(raw.contains('secret-device-id-0987654321'), isFalse);
    expect(raw.contains('SECRET-P'), isTrue);
  });

  test('survives the wipe it is meant to explain', () async {
    // The reset deletes the database and the preferences — the very stores a
    // lost identity may have vanished from. Recording the breadcrumb in either
    // of them would be circular, so it lives in its own file.
    await IdentityJournal.record(
      reason: IdentityJournal.reasonServerSaysDeleted,
      nowMs: 1,
    );
    File(p.join(tmp.path, 'secretly.db')).writeAsStringSync('db');
    File(p.join(tmp.path, 'secretly.db')).deleteSync();

    expect(await IdentityJournal.read(), hasLength(1));
  });

  test('is capped, keeping the NEWEST — a burst must not push out itself',
      () async {
    for (var i = 0; i < IdentityJournal.maxEntries + 12; i++) {
      await IdentityJournal.record(
        reason: IdentityJournal.reasonNoLocalProfile,
        nowMs: i,
      );
    }
    final entries = await IdentityJournal.read();
    expect(entries, hasLength(IdentityJournal.maxEntries));
    // The oldest were dropped, not the newest: an investigation starts from
    // what just happened.
    expect(entries.last['at_ms'], IdentityJournal.maxEntries + 11);
  });

  test('a truncated line never hides the entries around it', () async {
    await IdentityJournal.record(
      reason: IdentityJournal.reasonUserInitiated,
      nowMs: 1,
    );
    await journalFile().writeAsString(
      '${jsonEncode({'at_ms': 1, 'reason': 'a'})}\n'
      '{"at_ms": 2, "reason": "b"\n' // torn write
      '${jsonEncode({'at_ms': 3, 'reason': 'c'})}\n',
    );
    final entries = await IdentityJournal.read();
    expect(entries.map((e) => e['reason']), ['a', 'c']);
  });

  test('reading an absent journal is empty, not an error', () async {
    expect(await IdentityJournal.read(), isEmpty);
    expect(await IdentityJournal.summarize(), contains('empty'));
  });
}
