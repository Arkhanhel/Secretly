// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Стиль Apple на iPhone (17.11.2026): уведомления капсулой сверху и системный
// шрифт. На Android и компьютере — без изменений.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/apple_style.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

/// Корень как в `main.dart`: почтальон снаружи, капсула в общем `Stack`.
Widget _app({required Widget home, bool dark = false}) {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  return MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => AppleToastMessenger(
      key: messengerKey,
      child: Stack(
        children: [child ?? const SizedBox.shrink(), const AppleToastHost()],
      ),
    ),
    home: home,
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.onShow, this.onBottomTap});

  final void Function(BuildContext context) onShow;
  final VoidCallback? onBottomTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 300),
          Builder(
            builder: (context) => TextButton(
              onPressed: () => onShow(context),
              child: const Text('показать'),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onBottomTap,
            child: const Text('нижняя кнопка'),
          ),
        ],
      ),
    );
  }
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    appleToastCurrent.value = null;
  });

  test('включено только на iPhone', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(appleTopToastsEnabled, isTrue);
    expect(appleSystemFontEnabled, isTrue);
    for (final p in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = p;
      expect(appleTopToastsEnabled, isFalse, reason: '$p');
      expect(appleSystemFontEnabled, isFalse, reason: '$p');
    }
  });

  testWidgets('уведомление — капсулой у верхнего края и уходит по времени', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SecretlySnackBar(content: const Text('Скопировано'))),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();

    final capsule = find.byType(AppleToastCapsule);
    expect(capsule, findsOneWidget);
    expect(
      find.descendant(of: capsule, matching: find.text('Скопировано')),
      findsOneWidget,
    );
    // Наверху, а не внизу и не под шапкой.
    expect(tester.getTopLeft(capsule).dy, lessThan(40));
    // У текста есть основа оформления: без неё Flutter подчёркивает его
    // жёлтым двойным подчёркиванием.
    final text = tester.widget<RichText>(
      find.descendant(of: capsule, matching: find.byType(RichText)).first,
    );
    expect(text.text.style?.decoration, isNot(TextDecoration.underline));
    expect(text.text.style?.decorationStyle, isNot(TextDecorationStyle.double));
    // Старой матовой плашки нет.
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Скопировано'),
      ),
      findsNothing,
    );

    // 2 с штатного времени показа + уход.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(AppleToastCapsule), findsNothing);
    expect(appleToastCurrent.value, isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('пока капсула видна, нажатия внизу экрана проходят', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var bottomTaps = 0;
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SecretlySnackBar(content: const Text('Готово'))),
          onBottomTap: () => bottomTaps++,
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AppleToastCapsule), findsOneWidget);

    await tester.tap(find.text('нижняя кнопка'));
    expect(bottomTaps, 1);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('кнопка действия срабатывает и закрывает капсулу', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var retried = 0;
    SnackBarClosedReason? reason;
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(context)
              .showSnackBar(
                SecretlySnackBar(
                  content: const Text('Не удалось отправить'),
                  action: SnackBarAction(
                    label: 'Повторить',
                    onPressed: () => retried++,
                  ),
                ),
              )
              .closed
              .then((r) => reason = r),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppleToastCapsule),
        matching: find.text('Повторить'),
      ),
    );
    await tester.pumpAndSettle();
    expect(retried, 1);
    expect(reason, SnackBarClosedReason.action);
    expect(find.byType(AppleToastCapsule), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('смахнуть вверх — закрыть', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SnackBarClosedReason? reason;
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(context)
              .showSnackBar(
                SecretlySnackBar(
                  content: const Text('Сообщение удалено'),
                  duration: const Duration(seconds: 20),
                ),
              )
              .closed
              .then((r) => reason = r),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(AppleToastCapsule), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(reason, SnackBarClosedReason.swipe);
    expect(find.byType(AppleToastCapsule), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('обычный SnackBar тоже становится капсулой', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      _app(
        dark: true,
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Память очищена'))),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppleToastCapsule),
        matching: find.text('Память очищена'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('капсула видна и после перехода на другой экран', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) {
            ScaffoldMessenger.of(context).showSnackBar(
              SecretlySnackBar(
                content: const Text('Ссылка скопирована'),
                duration: const Duration(seconds: 20),
              ),
            );
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('второй экран')),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pumpAndSettle();
    expect(find.text('второй экран'), findsOneWidget);
    expect(find.byType(AppleToastCapsule), findsOneWidget);
    expect(find.text('Ссылка скопирована'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('голосовой диктор слышит текст капсулы', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SecretlySnackBar(content: const Text('Скопировано'))),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find
          .ancestor(
            of: find.text('Скопировано'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('на Android уведомление остаётся прежним', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        home: _Home(
          onShow: (context) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SecretlySnackBar(content: const Text('Скопировано'))),
        ),
      ),
    );
    await tester.tap(find.text('показать'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AppleToastCapsule), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Скопировано'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    '«Повторить» срабатывает один раз, капсула с кнопкой — ниже шапки',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var retried = 0;
      await tester.pumpWidget(
        _app(
          home: _Home(
            onShow: (context) => ScaffoldMessenger.of(context).showSnackBar(
              SecretlySnackBar(
                content: const Text('GIF не отправлен'),
                action: SnackBarAction(
                  label: 'Повторить',
                  onPressed: () => retried++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('показать'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(AppleToastCapsule)).dy,
        greaterThanOrEqualTo(56),
        reason: 'шапка экрана остаётся доступной',
      );
      final retry = find.descendant(
        of: find.byType(AppleToastCapsule),
        matching: find.text('Повторить'),
      );
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 50));
      if (retry.evaluate().isNotEmpty) {
        await tester.tap(retry, warnIfMissed: false);
      }
      await tester.pumpAndSettle();
      expect(retried, 1);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
