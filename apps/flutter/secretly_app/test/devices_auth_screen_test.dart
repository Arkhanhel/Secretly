// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/devices_auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowsOnly = TargetPlatformVariant(<TargetPlatform>{
    TargetPlatform.windows,
  });

  Widget buildSubject(AppController controller, {Locale? locale}) {
    return DefaultAssetBundle(
      bundle: _FakeJsonAssetBundle(),
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: DevicesAuthScreen(controller: controller),
      ),
    );
  }

  testWidgets('desktop auth screen cancels active QR session', (
    WidgetTester tester,
  ) async {
    final controller = _FakeDevicesAuthController.withRequest(
      DesktopLinkRequest(
        requestId: 'req-1',
        targetProfileId: 'profile-1',
        targetDeviceId: 'device-1',
        requestNonce: 'nonce-1',
        deviceLabel: 'Windows Desktop',
        createdAtMs: 1,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        status: 'pending',
      ),
    );

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    expect(find.text('Cancel QR'), findsOneWidget);
    expect(find.text('Refresh QR'), findsOneWidget);

    await tester.tap(find.text('Cancel QR'));
    await tester.pumpAndSettle();

    expect(controller.lastCancelledRequestId, 'req-1');
    expect(find.text('Sign in via QR'), findsOneWidget);

    controller.disposeFake();
  }, variant: windowsOnly);

  testWidgets('desktop auth screen refreshes QR session', (
    WidgetTester tester,
  ) async {
    final controller = _FakeDevicesAuthController();

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in via QR'));
    await tester.pumpAndSettle();

    expect(controller.createRequestCalls, 1);
    expect(find.text('Refresh QR'), findsOneWidget);
    expect(find.textContaining('QR expires in'), findsOneWidget);

    controller.disposeFake();
  }, variant: windowsOnly);

  testWidgets('desktop auth screen surfaces expired QR state', (
    WidgetTester tester,
  ) async {
    final controller = _FakeDevicesAuthController.withRequest(
      DesktopLinkRequest(
        requestId: 'req-expired',
        targetProfileId: 'profile-1',
        targetDeviceId: 'device-1',
        requestNonce: 'nonce-1',
        deviceLabel: 'Windows Desktop',
        createdAtMs: 1,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        status: 'pending',
      ),
      state: AuthFlowState.qrSessionPending,
    );

    await tester.pumpWidget(buildSubject(controller));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('QR session expired. Generate a new QR and retry.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Sign in via QR'), findsOneWidget);

    controller.disposeFake();
  }, variant: windowsOnly);

  testWidgets(
    'desktop auth screen retries after primary phone declines',
    (WidgetTester tester) async {
      final controller = _FakeDevicesAuthController(
        state: AuthFlowState.authError,
        error:
            'Sign-in was declined on the primary phone. Generate a new QR to retry.',
      );

      await tester.pumpWidget(buildSubject(controller));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sign-in was declined on the primary phone. Generate a new QR to retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in via QR'), findsOneWidget);

      await tester.tap(find.text('Sign in via QR'));
      await tester.pumpAndSettle();

      expect(controller.createRequestCalls, 1);
      expect(find.text('Refresh QR'), findsOneWidget);

      controller.disposeFake();
    },
    variant: windowsOnly,
  );

  testWidgets(
    'desktop auth screen retries after interrupted secure sync',
    (WidgetTester tester) async {
      final controller = _FakeDevicesAuthController(
        state: AuthFlowState.authError,
        error:
            'Secure sync was interrupted before completion. Generate a new QR and retry.',
      );

      await tester.pumpWidget(buildSubject(controller));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Secure sync was interrupted before completion. Generate a new QR and retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in via QR'), findsOneWidget);

      await tester.tap(find.text('Sign in via QR'));
      await tester.pumpAndSettle();

      expect(controller.createRequestCalls, 1);
      expect(find.textContaining('QR expires in'), findsOneWidget);

      controller.disposeFake();
    },
    variant: windowsOnly,
  );

  testWidgets('desktop auth screen shows wait-for-confirmation state', (
    WidgetTester tester,
  ) async {
    final controller = _FakeDevicesAuthController.withRequest(
      DesktopLinkRequest(
        requestId: 'req-confirm',
        targetProfileId: 'profile-1',
        targetDeviceId: 'device-1',
        requestNonce: 'nonce-1',
        deviceLabel: 'Windows Desktop',
        createdAtMs: 1,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        status: 'scanned',
      ),
      state: AuthFlowState.qrScannedWaitConfirm,
    );

    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    expect(find.text('QR scanned. Confirm sign-in on phone.'), findsOneWidget);
    expect(find.text('Cancel QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    controller.disposeFake();
  }, variant: windowsOnly);

  testWidgets('desktop auth screen localizes typed desktop-link failures', (
    WidgetTester tester,
  ) async {
    final controller = _FakeDevicesAuthController(
      state: AuthFlowState.authError,
      error:
          'Sign-in was declined on the primary phone. Generate a new QR to retry.',
      failure: DesktopLinkFailure(DesktopLinkFailureCode.decisionDeclined),
    );

    await tester.pumpWidget(
      buildSubject(controller, locale: const Locale('ru')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Вход был отклонён на основном телефоне. Создайте новый QR и повторите попытку.',
      ),
      findsOneWidget,
    );

    controller.disposeFake();
  }, variant: windowsOnly);
}

class _FakeDevicesAuthController extends AppController {
  _FakeDevicesAuthController({
    List<DesktopLinkRequest> requests = const <DesktopLinkRequest>[],
    AuthFlowState state = AuthFlowState.unauthenticated,
    String? error,
    DesktopLinkFailure? failure,
  }) : _requests = List<DesktopLinkRequest>.from(requests),
       _state = state,
       _error = error,
       _failure = failure;

  factory _FakeDevicesAuthController.withRequest(
    DesktopLinkRequest request, {
    AuthFlowState state = AuthFlowState.qrSessionPending,
    String? error,
  }) {
    return _FakeDevicesAuthController(
      requests: <DesktopLinkRequest>[request],
      state: state,
      error: error,
    );
  }

  final StreamController<void> _changedController =
      StreamController<void>.broadcast();
  List<DesktopLinkRequest> _requests;
  AuthFlowState _state;
  String? _error;
  DesktopLinkFailure? _failure;

  int createRequestCalls = 0;
  String? lastCancelledRequestId;

  @override
  Stream<void> get changed => _changedController.stream;

  @override
  List<DesktopLinkRequest> get desktopLinkRequests =>
      List<DesktopLinkRequest>.unmodifiable(_requests);

  @override
  DesktopLinkRequest? get activeDesktopLinkRequest {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final request in _requests) {
      if (request.isAwaitingDecision && !request.isExpiredAt(now)) {
        return request;
      }
    }
    return null;
  }

  @override
  AuthFlowState get authFlowState => _state;

  @override
  String? get authFlowError => _error;

  @override
  DesktopLinkFailure? get authFlowFailure => _failure;

  @override
  Future<DesktopLinkRequest> createDesktopLinkRequest({
    String? deviceLabel,
  }) async {
    createRequestCalls += 1;
    final request = DesktopLinkRequest(
      requestId: 'req-$createRequestCalls',
      targetProfileId: 'profile-$createRequestCalls',
      targetDeviceId: 'device-$createRequestCalls',
      requestNonce: 'nonce-$createRequestCalls',
      deviceLabel: deviceLabel ?? 'Desktop/Web',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
      status: 'pending',
    );
    _requests = <DesktopLinkRequest>[request];
    _state = AuthFlowState.qrSessionPending;
    _error = null;
    _failure = null;
    _changedController.add(null);
    return request;
  }

  @override
  String buildDesktopLinkQrPayload(DesktopLinkRequest request) {
    return 'type=${AppController.desktopLinkQrType}\nrequest_id=${request.requestId}';
  }

  @override
  Future<void> cancelDesktopLinkRequest(String requestId) async {
    lastCancelledRequestId = requestId;
    _requests = _requests
        .map(
          (request) => request.requestId == requestId
              ? request.copyWith(status: 'cancelled')
              : request,
        )
        .toList(growable: false);
    _state = AuthFlowState.unauthenticated;
    _error = null;
    _failure = null;
    _changedController.add(null);
  }

  @override
  Future<bool> expireDesktopLinkRequestsIfNeeded() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hadExpired = _requests.any(
      (request) => request.isAwaitingDecision && request.isExpiredAt(now),
    );
    if (!hadExpired) return false;
    _requests = _requests
        .where(
          (request) => !request.isAwaitingDecision || !request.isExpiredAt(now),
        )
        .toList(growable: false);
    _state = AuthFlowState.authError;
    _error = 'QR session expired. Generate a new QR and retry.';
    _failure = DesktopLinkFailure(DesktopLinkFailureCode.syncSessionExpired);
    _changedController.add(null);
    return true;
  }

  void disposeFake() {
    _changedController.close();
  }
}

class _FakeJsonAssetBundle extends CachingAssetBundle {
  static const String _lottieStub =
      '{"v":"5.5.7","fr":30,"ip":0,"op":1,"w":10,"h":10,"nm":"stub","ddd":0,"assets":[],"layers":[]}';

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_lottieStub));
    return ByteData.view(bytes.buffer);
  }
}
