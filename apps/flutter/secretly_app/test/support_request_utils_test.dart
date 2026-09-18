// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/support_request_utils.dart';

void main() {
  test('buildSupportTechnicalInfo includes marker device and profile ids', () {
    final info = buildSupportTechnicalInfo(
      buildMarker: 'release-20260420',
      deviceId: 'device-1',
      profileId: 'profile-1',
    );

    expect(info, contains('Build marker: release-20260420'));
    expect(info, contains('Device ID: device-1'));
    expect(info, contains('Profile ID: profile-1'));
  });

  test('buildSupportRequestPayload appends technical info automatically', () {
    final payload = buildSupportRequestPayload(
      name: 'Alice',
      email: 'alice@example.com',
      message: 'The page reloads during checkout.',
      technicalInfo: 'Build marker: release-20260420\nDevice ID: device-1',
    );

    expect(payload, startsWith('Secretly Support Request'));
    expect(payload, contains('Name: Alice'));
    expect(payload, contains('Email: alice@example.com'));
    expect(payload, contains('Message:\nThe page reloads during checkout.'));
    expect(
      payload,
      contains(
        'Technical info:\nBuild marker: release-20260420\nDevice ID: device-1',
      ),
    );
  });

  test('buildAbuseReportPayload includes target reason and technical info', () {
    final payload = buildAbuseReportPayload(
      targetType: 'profile',
      targetId: 'peer-profile-1',
      targetTitle: 'Bad Actor',
      conversationId: 'peer-profile-1',
      reasonCode: 'spam_or_scam',
      reasonLabel: 'Spam or scam',
      details: 'They keep sending phishing links.',
      generatedAtUtc: DateTime.utc(2026, 5, 4, 12),
      technicalInfo: 'Build marker: release-20260504\nDevice ID: device-1',
    );

    expect(payload, startsWith('Secretly Abuse Report'));
    expect(payload, contains('Generated at UTC: 2026-05-04T12:00:00.000Z'));
    expect(payload, contains('Type: profile'));
    expect(payload, contains('ID: peer-profile-1'));
    expect(payload, contains('Title: Bad Actor'));
    expect(payload, contains('Code: spam_or_scam'));
    expect(payload, contains('Label: Spam or scam'));
    expect(payload, contains('They keep sending phishing links.'));
    expect(payload, contains('Build marker: release-20260504'));
  });
}
