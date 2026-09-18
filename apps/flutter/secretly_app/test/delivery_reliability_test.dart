// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/reliability/delivery_reliability_service.dart';
import 'package:secretly_app/ui/delivery_reliability_screen.dart';

// DELIVERY RELIABILITY (2026-07-16, delivery-wake audit): the screen surfaces
// OS-level switches that silently break delivery. These tests pin the issue
// classification (what counts as a warning) and the screen's three render
// states (all good / issues with fix buttons / OEM autostart advisory).

class _FakeService extends DeliveryReliabilityService {
  _FakeService(this.status) : super(forceIsAndroid: status?.isAndroid ?? true);
  final DeliveryReliabilityStatus? status;

  @override
  Future<DeliveryReliabilityStatus?> getStatus() async => status;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeliveryReliabilityStatus.issues', () {
    test('android: clean state has no issues', () {
      const s = DeliveryReliabilityStatus(
        isAndroid: true,
        batteryUnrestricted: true,
        dataSaver: 'disabled',
        notificationsEnabled: true,
        manufacturer: 'google',
      );
      expect(s.issues, isEmpty);
      expect(s.showAutostartAdvisory, isFalse);
    });

    test('android: restricted battery + data saver + muted notifications', () {
      const s = DeliveryReliabilityStatus(
        isAndroid: true,
        batteryUnrestricted: false,
        dataSaver: 'enabled',
        notificationsEnabled: false,
        manufacturer: 'xiaomi',
      );
      expect(
        s.issues,
        containsAll([
          ReliabilityIssue.batteryRestricted,
          ReliabilityIssue.backgroundDataBlocked,
          ReliabilityIssue.notificationsDisabled,
        ]),
      );
      expect(s.showAutostartAdvisory, isTrue);
    });

    test('android: whitelisted in data saver is NOT an issue', () {
      const s = DeliveryReliabilityStatus(
        isAndroid: true,
        batteryUnrestricted: true,
        dataSaver: 'whitelisted',
        notificationsEnabled: true,
      );
      expect(s.issues, isEmpty);
    });

    test('ios: BAR denied + low power are issues', () {
      const s = DeliveryReliabilityStatus(
        isAndroid: false,
        backgroundRefresh: 'denied',
        lowPowerMode: true,
        notificationsEnabled: true,
      );
      expect(
        s.issues,
        containsAll([
          ReliabilityIssue.backgroundRefreshOff,
          ReliabilityIssue.lowPowerMode,
        ]),
      );
      expect(s.showAutostartAdvisory, isFalse);
    });
  });

  group('DeliveryReliabilityScreen', () {
    Future<void> pump(
      WidgetTester tester,
      DeliveryReliabilityStatus? status,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryReliabilityScreen(service: _FakeService(status)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('all-good android state shows the green summary', (
      tester,
    ) async {
      await pump(
        tester,
        const DeliveryReliabilityStatus(
          isAndroid: true,
          batteryUnrestricted: true,
          dataSaver: 'disabled',
          notificationsEnabled: true,
          manufacturer: 'google',
        ),
      );
      expect(find.text('Everything is set up perfectly'), findsOneWidget);
      // No fix buttons in a clean state.
      expect(find.text('Fix'), findsNothing);
      // Pixel is not an autostart OEM — no advisory row.
      expect(find.text('Autostart'), findsNothing);
    });

    testWidgets('android issues render warning summary + fix buttons', (
      tester,
    ) async {
      await pump(
        tester,
        const DeliveryReliabilityStatus(
          isAndroid: true,
          batteryUnrestricted: false,
          dataSaver: 'enabled',
          notificationsEnabled: true,
          manufacturer: 'xiaomi',
        ),
      );
      expect(find.text('Delivery may be delayed'), findsOneWidget);
      // Battery + Data Saver are fixable; autostart advisory adds "Open".
      expect(find.text('Fix'), findsNWidgets(2));
      expect(find.text('Autostart'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('ios BAR-off renders its warning row', (tester) async {
      await pump(
        tester,
        const DeliveryReliabilityStatus(
          isAndroid: false,
          backgroundRefresh: 'denied',
          lowPowerMode: false,
          notificationsEnabled: true,
        ),
      );
      expect(find.text('Background App Refresh'), findsOneWidget);
      expect(find.text('Delivery may be delayed'), findsOneWidget);
    });

    testWidgets('unsupported platform renders the neutral card', (
      tester,
    ) async {
      await pump(tester, null);
      expect(find.text('Nothing to tune here'), findsOneWidget);
    });
  });
}
