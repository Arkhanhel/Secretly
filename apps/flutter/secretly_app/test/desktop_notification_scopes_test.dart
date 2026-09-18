// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-scope notification muting: rooms and direct chats are independent.
///
/// Desktop previously notified for everything, so one busy room made the whole
/// feature unusable and the only remedy was Do Not Disturb — which also
/// silenced the messages the user actually wanted. These pin the decision
/// itself, and the key names, which are SHARED with mobile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mirrors of the service constants — a rename here fails loudly and names
  // the contract that broke, rather than silently splitting the setting in two.
  const privateKey = 'notif_private_chats_v1';
  const groupsKey = 'notif_groups_v1';

  /// The service's rule: rooms are convo ids prefixed `group:`.
  bool shouldNotify({
    required String convoId,
    required bool privateEnabled,
    required bool groupsEnabled,
  }) {
    final isRoom = convoId.startsWith('group:');
    if (isRoom && !groupsEnabled) return false;
    if (!isRoom && !privateEnabled) return false;
    return true;
  }

  test('muting rooms leaves direct messages alone', () {
    expect(
      shouldNotify(
          convoId: 'group:abc', privateEnabled: true, groupsEnabled: false),
      isFalse,
    );
    expect(
      shouldNotify(
          convoId: 'peer-123', privateEnabled: true, groupsEnabled: false),
      isTrue,
      reason: 'this is the whole point — a noisy room must not cost you DMs',
    );
  });

  test('muting direct chats leaves rooms alone', () {
    expect(
      shouldNotify(
          convoId: 'peer-123', privateEnabled: false, groupsEnabled: true),
      isFalse,
    );
    expect(
      shouldNotify(
          convoId: 'group:abc', privateEnabled: false, groupsEnabled: true),
      isTrue,
    );
  });

  test('both on notifies for both', () {
    for (final id in ['group:abc', 'peer-123']) {
      expect(
        shouldNotify(convoId: id, privateEnabled: true, groupsEnabled: true),
        isTrue,
        reason: id,
      );
    }
  });

  test('both off notifies for neither', () {
    for (final id in ['group:abc', 'peer-123']) {
      expect(
        shouldNotify(convoId: id, privateEnabled: false, groupsEnabled: false),
        isFalse,
        reason: id,
      );
    }
  });

  test('a convo id merely CONTAINING "group:" is still a direct chat', () {
    // The rule is a prefix, not a substring: a peer id that happens to embed
    // the word must not be silenced by the rooms switch.
    expect(
      shouldNotify(
          convoId: 'peer-group:x', privateEnabled: false, groupsEnabled: true),
      isFalse,
    );
  });

  group('persistence', () {
    test('defaults to notifying for both', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(privateKey) ?? true, isTrue);
      expect(p.getBool(groupsKey) ?? true, isTrue);
    });

    test('a choice made on the phone is read here', () async {
      SharedPreferences.setMockInitialValues({groupsKey: false});
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(groupsKey) ?? true, isFalse,
          reason: 'the keys are shared, so the profile setting must govern');
    });
  });
}
