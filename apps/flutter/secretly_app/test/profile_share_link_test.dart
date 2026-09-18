// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/share_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile share link round-trips through app-link parser', () {
    const profileId = 'user-123';
    final link = buildProfileShareLink(profileId: profileId);

    expect(link, startsWith('https://links.secretlyapp.com'));
    expect(link, contains('/profile/$profileId'));
    expect(tryParseProfileShareUri(Uri.parse(link)), profileId);
  });

  test('profile share text leads with clickable https app-link', () {
    const profileId = 'user-123';
    final link = buildProfileShareLink(profileId: profileId);
    final text = buildProfileShareText(
      profileId: profileId,
      isRu: true,
      displayName: 'Alice',
    );

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    expect(lines.first, link);
      expect(lines, hasLength(1));
      expect(text.trim(), link);
    expect(text, isNot(contains('secretly://profile/')));
    expect(text, isNot(contains('https://www.secretlyapp.com/download')));
      expect(text, isNot(contains('Secretly ID: $profileId')));
  });

  test('invite friend share text uses download link instead of profile link', () {
    final controller = AppController();
    final text = buildInviteFriendShareText(controller: controller, isRu: false);

    expect(text, contains('https://www.secretlyapp.com/download'));
    expect(text, isNot(contains('secretly://profile/')));
    expect(text, isNot(contains('https://www.secretlyapp.com/install')));
  });
}
