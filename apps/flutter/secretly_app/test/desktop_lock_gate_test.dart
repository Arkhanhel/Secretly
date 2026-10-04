// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗАМОК НАД НАВИГАТОРОМ (30.09.2026).
//
// Замки рисовались внутри главного экрана, а просмотр фото и документов,
// окна посередине (набор восстановления), диалоги — маршруты корневого
// навигатора, то есть выше. После автоблокировки открытый документ оставался
// на экране и работал. Заодно каждое запирание пересоздавало оболочку: лишний
// `Stack` вокруг запертого окна сбрасывал открытый чат, прокрутку и поиск.
//
// И звонок: замок «Вход в приложение» снимался на время звонка целиком.
// Теперь он остаётся, а поверх — только управление звонком, без имени.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_lock_overlay.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Кусок «оболочки» со своим состоянием: по нему видно, пережило ли оно замок.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  final FocusNode field = FocusNode(debugLabel: 'composer');

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('нажато $taps'),
        ),
        TextField(focusNode: field),
      ],
    ),
  );
}

void main() {
  late ValueNotifier<bool> locked;

  setUp(() => locked = ValueNotifier<bool>(false));
  tearDown(() => locked.dispose());

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        builder: (ctx, child) => ValueListenableBuilder<bool>(
          valueListenable: locked,
          builder: (_, isLocked, _) => DesktopLockGate(
            locked: isLocked,
            layers: const [
              Positioned.fill(
                key: ValueKey<String>('lock'),
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(child: Text('ЗАМОК')),
                ),
              ),
            ],
            child: child!,
          ),
        ),
        home: const _Counter(),
      ),
    );
  }

  testWidgets('🔴 окно поверх главного экрана не выходит поверх замка', (
    t,
  ) async {
    await pumpApp(t);
    var opened = 0;
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    // «Документ» — маршрутом корневого навигатора, как просмотр фото.
    unawaited(
      showGeneralDialog<void>(
        context: nav.context,
        pageBuilder: (_, _, _) => Center(
          child: TextButton(
            onPressed: () => opened++,
            child: const Text('ДОКУМЕНТ'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('ДОКУМЕНТ').hitTestable(), findsOneWidget);

    locked.value = true;
    await t.pump();
    expect(find.text('ЗАМОК').hitTestable(), findsOneWidget);
    expect(find.text('ДОКУМЕНТ').hitTestable(), findsNothing);
    await t.tapAt(t.getCenter(find.text('ДОКУМЕНТ')));
    await t.pump();
    expect(opened, 0);
  });

  testWidgets('🔴 под замком фокуса нет — набор не уходит в переписку', (
    t,
  ) async {
    await pumpApp(t);
    final state = t.state<_CounterState>(find.byType(_Counter));
    state.field.requestFocus();
    await t.pump();
    expect(state.field.hasFocus, isTrue);

    locked.value = true;
    await t.pump();
    expect(state.field.hasFocus, isFalse);
    expect(state.field.canRequestFocus, isFalse);

    // После разблокировки фокус возвращается в недописанное.
    locked.value = false;
    await t.pump();
    await t.pump();
    expect(state.field.hasFocus, isTrue);
  });

  testWidgets('🔴 оболочка переживает запирание и разблокировку', (t) async {
    await pumpApp(t);
    await t.tap(find.text('нажато 0'));
    await t.pump();
    await t.tap(find.text('нажато 1'));
    await t.pump();
    final before = t.state<_CounterState>(find.byType(_Counter));

    locked.value = true;
    await t.pump();
    locked.value = false;
    await t.pump();

    expect(
      identical(t.state<_CounterState>(find.byType(_Counter)), before),
      isTrue,
    );
    expect(find.text('нажато 2'), findsOneWidget);
    expect(find.text('ЗАМОК'), findsNothing);
  });

  group('звонок поверх замка', () {
    Future<List<String>> pumpStrip(WidgetTester t, DesktopLockCall call) async {
      final events = <String>[];
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: DesktopLockCallStrip(
                call: call,
                onAccept: () => events.add('accept'),
                onDecline: () => events.add('decline'),
                onToggleMic: () => events.add('mic'),
                onEnd: () => events.add('end'),
              ),
            ),
          ),
        ),
      );
      return events;
    }

    testWidgets('входящий: ответить или отклонить — без имени', (t) async {
      final events = await pumpStrip(
        t,
        const DesktopLockCall(kind: DesktopLockCallKind.incoming),
      );
      expect(find.text('Входящий звонок'), findsOneWidget);
      await t.tap(find.text('Ответить'));
      await t.tap(find.text('Отклонить'));
      expect(events, ['accept', 'decline']);
    });

    testWidgets('видеозвонок принимают с видео', (t) async {
      await pumpStrip(
        t,
        const DesktopLockCall(kind: DesktopLockCallKind.incoming, video: true),
      );
      expect(find.text('Ответить с видео'), findsOneWidget);
    });

    testWidgets('идущий звонок: микрофон и трубка', (t) async {
      final events = await pumpStrip(
        t,
        const DesktopLockCall(kind: DesktopLockCallKind.direct),
      );
      expect(find.text('Звонок'), findsOneWidget);
      await t.tap(find.text('Выключить микрофон'));
      await t.tap(find.text('Завершить'));
      expect(events, ['mic', 'end']);
    });

    testWidgets('созвон комнаты: выйти, микрофон уже выключен', (t) async {
      final events = await pumpStrip(
        t,
        const DesktopLockCall(kind: DesktopLockCallKind.room, muted: true),
      );
      expect(find.text('Идёт созвон'), findsOneWidget);
      await t.tap(find.text('Включить микрофон'));
      await t.tap(find.text('Выйти из созвона'));
      expect(events, ['mic', 'end']);
    });
  });

  group('корень приложения', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    test('замки — над навигатором, а не в главном экране', () {
      expect(
        app.contains('child: _buildLockGate(\n'),
        isTrue,
      );
      final root = app.substring(
        app.indexOf('  Widget _buildRoot() {'),
        app.indexOf('  /// 🔴 ПАРОЛЬ «ВХОД В ПРИЛОЖЕНИЕ» НА КОМПЬЮТЕРЕ'),
      );
      expect(root.contains('AppSecurityLockOverlay'), isFalse);
      expect(root.contains('DesktopLockOverlay('), isFalse);
    });

    test('🔴 звонок больше не снимает замок', () {
      final getter = app.substring(
        app.indexOf('  bool get _appScopeLocked {'),
        app.indexOf('  bool get _deviceLocked {'),
      );
      expect(getter.contains('isRinging'), isFalse);
      expect(getter.contains('_callManager'), isFalse);
    });
  });
}
