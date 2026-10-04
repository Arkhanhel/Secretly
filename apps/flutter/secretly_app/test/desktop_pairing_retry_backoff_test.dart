// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Экран QR: сорвавшееся обновление кода повторяется с паузой (30.09.2026).
//
// 🔴 ЧТО БЫЛО. Код истёк, обновить не вышло — истёкший код оставался на
// экране, и счётчик раз в секунду снова звал `createDesktopLinkRequest`: без
// конца, пока сервер не ответит. Человек видел мёртвый QR с надписью
// «обновляем…», сервер ключей — запрос в секунду.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/onboarding/desktop_onboarding_screen.dart';

class _Pairing extends AppController {
  int calls = 0;
  bool fail = false;
  int expiresAtMs = 0;

  @override
  Future<DesktopLinkRequest> createDesktopLinkRequest({
    String? deviceLabel,
  }) async {
    calls += 1;
    if (fail) throw StateError('publishKeys returned ok=false');
    return DesktopLinkRequest(
      requestId: 'req-$calls',
      targetProfileId: 'pid',
      targetDeviceId: 'did',
      requestNonce: 'nonce',
      deviceLabel: 'Secretly Desktop',
      createdAtMs: 0,
      expiresAtMs: expiresAtMs,
      status: 'pending',
    );
  }

  @override
  String buildDesktopLinkQrPayload(DesktopLinkRequest request) =>
      'payload-${request.requestId}';

  @override
  Future<void> cancelDesktopLinkRequest(String requestId) async {}
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  testWidgets('🔴 не раз в секунду: пауза 30 с, потом дольше, и «Повторить»', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    var now = DateTime(2026, 9, 30, 12);
    final ctrl = _Pairing()
      ..expiresAtMs = now
          .add(const Duration(seconds: 10))
          .millisecondsSinceEpoch;
    final vm = DesktopAppViewModel(controller: ctrl);
    addTearDown(vm.dispose);

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: DesktopOnboardingScreen(vm: vm, clock: () => now),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(ctrl.calls, 1);

    Future<void> seconds(int n) async {
      for (var i = 0; i < n; i++) {
        now = now.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
    }

    // Код истёк (на 10-й секунде), а сервер перестал отвечать.
    ctrl.fail = true;
    await seconds(11);
    expect(ctrl.calls, 2);

    // Двадцать секунд — ни одного нового запроса (раньше их было бы 20).
    await seconds(20);
    expect(ctrl.calls, 2);
    // Мёртвого кода нет, ошибка названа, пауза видна, «Повторить» под рукой.
    expect(find.text(ru.desktopPairingQrUnavailable), findsOneWidget);
    expect(find.text(ru.desktopPairingPrepareFailed), findsOneWidget);
    expect(find.text(ru.desktopPairingRetryIn(9)), findsOneWidget);
    expect(find.text(ru.desktopDevicesRetry), findsOneWidget);
    expect(find.text(ru.desktopPairingCodeExpired), findsNothing);

    // Пауза вышла — пробуем сами, и следующая пауза вдвое длиннее.
    await seconds(11);
    expect(ctrl.calls, 3);
    await seconds(50);
    expect(ctrl.calls, 3);

    // «Повторить» — сразу, без ожидания паузы.
    ctrl.fail = false;
    ctrl.expiresAtMs = now.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    await t.tap(find.text(ru.desktopDevicesRetry));
    await t.pump();
    await t.pump();
    expect(ctrl.calls, 4);
    expect(find.text(ru.desktopPairingRetryIn(0)), findsNothing);
    expect(find.text(ru.desktopPairingNewQr), findsOneWidget);

    await t.pumpWidget(const SizedBox());
  });
}
