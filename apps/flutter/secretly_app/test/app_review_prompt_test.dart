// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Нативное окно оценки Apple / Google (24.11.2026).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_review_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _day = 24 * 60 * 60 * 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppReviewState st({
    int age = 4,
    bool existing = false,
    int launches = 6,
    int requests = 0,
    int sinceLast = 0,
  }) => AppReviewState(
    firstSeenMs: 1000 * _day - age * _day,
    existingUser: existing,
    launches: launches,
    requests: requests,
    lastRequestMs: 1000 * _day - sinceLast * _day,
  );

  test('правила: 3 суток, 5 запусков, только новые, повтор через 120 дней, '
      'не больше трёх', () {
    const now = 1000 * _day;
    expect(appReviewDue(st(), now), isTrue);
    expect(appReviewDue(st(age: 2), now), isFalse);
    expect(appReviewDue(st(launches: 4), now), isFalse);
    expect(appReviewDue(st(existing: true), now), kAppReviewExistingUsers);
    expect(appReviewDue(st(requests: 1, sinceLast: 30), now), isFalse);
    expect(appReviewDue(st(requests: 1, sinceLast: 121), now), isTrue);
    expect(appReviewDue(st(requests: 3, sinceLast: 400), now), isFalse);
  });

  group('запуски и просьба', () {
    final calls = <String>[];
    var systemAccepts = true;
    setUp(() {
      calls.clear();
      systemAccepts = true;
      SharedPreferences.setMockInitialValues({});
      AppReviewPrompt.debugReset();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('secretly/app_review'), (c) async {
        calls.add(c.method);
        return systemAccepts;
      });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('secretly/app_review'), null);
    });

    Future<void> launches(int n, int at, Future<int?> Function() oldest) async {
      for (var i = 0; i < n; i++) {
        AppReviewPrompt.debugReset();
        await AppReviewPrompt.noteLaunch(
          hasMessagesBefore: (cutoff) async {
            final o = await oldest();
            return o != null && o < cutoff;
          },
          nowMs: at,
        );
      }
    }

    test('🔴 новый пользователь: на 5-м запуске через 3 суток — одна просьба', () async {
      const t0 = 500 * _day;
      await launches(5, t0, () async => null);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 2 * _day), isFalse);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 3 * _day + 1), isTrue);
      expect(calls, ['request']);
      // Сразу ещё раз — нельзя.
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 4 * _day), isFalse);
      expect(calls, hasLength(1));
    });

    test('🔴 система не приняла просьбу (нет активной сцены) — попытка не '
        'тратится; неспокойный экран — не просим', () async {
      const t0 = 500 * _day;
      await launches(5, t0, () async => null);
      systemAccepts = false;
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 4 * _day), isFalse);
      systemAccepts = true;
      expect(
        await AppReviewPrompt.maybeRequest(nowMs: t0 + 4 * _day, screenCalm: () => false),
        isFalse,
      );
      expect(calls, ['request']);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 4 * _day + 1), isTrue);
      expect(calls, ['request', 'request']);
    });

    test('🔴 старый аккаунт (переписка старше трёх суток) не просится', () async {
      const t0 = 500 * _day;
      await launches(6, t0, () async => t0 - 30 * _day);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 10 * _day),
          kAppReviewExistingUsers);
    });

    test('свежая переписка нового пользователя не делает его старым', () async {
      const t0 = 500 * _day;
      await launches(5, t0, () async => t0 - 3600 * 1000);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 4 * _day), isTrue);
    });

    test('компьютер — никогда', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const t0 = 500 * _day;
      await launches(6, t0, () async => null);
      expect(await AppReviewPrompt.maybeRequest(nowMs: t0 + 10 * _day), isFalse);
      expect(calls, isEmpty);
    });
  });

  test('нативные окна подключены: Apple StoreKit и Google Play Review', () {
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios.contains('"secretly/app_review"'), isTrue);
    expect(ios.contains('AppStore.requestReview(in: scene)'), isTrue);
    final kt = File(
      'android/app/src/main/kotlin/com/secretly/secretly_app/MainActivity.kt',
    ).readAsStringSync();
    expect(kt.contains('"secretly/app_review"'), isTrue);
    expect(kt.contains('launchReviewFlow'), isTrue);
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('com.google.android.play:review:'), isTrue);
    final shell = File('lib/ui/app_shell.dart').readAsStringSync();
    expect(shell.contains('AppReviewPrompt.noteLaunch('), isTrue);
    expect(shell.contains('AppReviewPrompt.maybeRequest('), isTrue);
    // В запуск с доступным обновлением — не просим.
    expect(shell.contains('!updateAvailable &&'), isTrue);
  });
}
