// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Звонок один на один на компьютере: каждая кнопка и каждое сочетание
// нажимаются по-настоящему, и проверяется, какой вызов ушёл (24.09.2026).
//
// 🔴 ЧТО БЫЛО. Внизу звонка стояли «Чат», «Участники» и «Ещё» — без
// обработчиков: нажимались и ничего не делали. «Поднять руку» меняла только
// свой значок — собеседник её не видел. «Экран» в голосовом звонке молча
// проваливался. Подсказки обещали ⌘D, ⌘E, ⌘W, а сочетаний не было. Свернуть
// звонок было нечем вовсе — владелец: «не могу никак скрыть этот звонок».

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_audio_route.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/calls/call_mini_window.dart';
import 'package:secretly_app/ui/desktop/calls/one_to_one_call_screen.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

class _FakeCall implements DesktopDirectCall {
  _FakeCall(CallState initial) : state = ValueNotifier<CallState>(initial);

  @override
  final ValueNotifier<CallState> state;

  @override
  final ValueNotifier<CallAudioRouteState> audioRouteState =
      ValueNotifier<CallAudioRouteState>(const CallAudioRouteState.idle());

  @override
  WebRtcCallSession? get session => null;

  final List<String> calls = <String>[];
  bool shareResult = true;

  @override
  Future<void> toggleMute() async {
    calls.add('mute');
    state.value = state.value.copyWith(isMuted: !state.value.isMuted);
  }

  @override
  Future<void> toggleCamera() async => calls.add('camera');

  @override
  Future<void> upgradeToVideo() async => calls.add('upgrade');

  @override
  Future<bool> toggleScreenShare() async {
    calls.add('share');
    return shareResult;
  }

  @override
  Future<void> selectAudioRoute(String routeId) async =>
      calls.add('route:$routeId');

  @override
  Future<void> hangup() async => calls.add('hangup');
}

CallState _state({
  CallPhase phase = CallPhase.connected,
  bool video = false,
}) => CallState.empty.copyWith(
  phase: phase,
  callId: 'c1',
  peerProfileId: 'peer-1',
  peerName: 'Анна',
  isVideo: video,
  connectedAtMs: DateTime.now().millisecondsSinceEpoch - 65000,
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: SizedBox(width: 1200, height: 800, child: child),
    ),
  ),
);

/// Кнопка дока по её подписи.
Finder _dock(String label) => find.text(label);

void main() {
  group('пульт звонка один на один', () {
    late _FakeCall call;
    late List<String> ui;

    Future<void> pump(WidgetTester t, CallState s) async {
      call = _FakeCall(s);
      ui = <String>[];
      await t.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        _host(
          OneToOneCallScreen(
            call: call,
            peerName: 'Анна',
            onEnd: () => ui.add('end'),
            onMinimize: () => ui.add('minimize'),
            onOpenChat: () => ui.add('chat'),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('🔴 кнопок, которые ничего не делают, нет', (t) async {
      await pump(t, _state());
      for (final label in ['Микрофон', 'Камера', 'Чат', 'Свернуть', 'Завершить']) {
        expect(_dock(label), findsOneWidget, reason: label);
      }
      // Участников в звонке вдвоём нет, «ещё» было пустым, руку собеседник
      // не видел.
      expect(find.text('Участники'), findsNothing);
      expect(find.byTooltip('Поднять руку'), findsNothing);
      // В голосовом звонке показывать экран нечем — кнопки нет.
      expect(_dock('Экран'), findsNothing);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('каждая кнопка зовёт свой вызов', (t) async {
      await pump(t, _state());
      await t.tap(_dock('Микрофон'));
      await t.pump();
      expect(call.calls, ['mute']);
      // Голосовой звонок: «Камера» включает картинку, а не «камеру вкл/выкл».
      await t.tap(_dock('Камера'));
      await t.pump();
      expect(call.calls, ['mute', 'upgrade']);
      await t.tap(_dock('Чат'));
      await t.tap(_dock('Свернуть'));
      await t.tap(_dock('Завершить'));
      await t.pump();
      expect(ui, ['chat', 'minimize', 'end']);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('микрофон выключен — кнопка это показывает', (t) async {
      await pump(t, _state());
      await t.tap(_dock('Микрофон'));
      await t.pump();
      expect(find.byTooltip(RegExp('^Включить микрофон')), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('пока звоним, картинку не включить', (t) async {
      await pump(t, _state(phase: CallPhase.ringingOutgoing));
      await t.tap(_dock('Камера'), warnIfMissed: false);
      await t.pump();
      expect(call.calls, isEmpty);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('видеозвонок: «Экран» есть и работает', (t) async {
      await pump(t, _state(video: true));
      expect(_dock('Экран'), findsOneWidget);
      await t.tap(_dock('Экран'));
      await t.pump();
      expect(call.calls, ['share']);
      await t.tap(_dock('Камера'));
      await t.pump();
      expect(call.calls, ['share', 'camera']);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('🔴 отказ показа экрана — словами', (t) async {
      await pump(t, _state(video: true));
      call.shareResult = false;
      await t.tap(_dock('Экран'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Не удалось показать экран'), findsOneWidget);
      await t.pump(const Duration(seconds: 8));
    });

    testWidgets('🔴 голосовой звонок: пульт не прячется', (t) async {
      await pump(t, _state());
      await t.pump(const Duration(seconds: 6));
      await t.tap(_dock('Свернуть'));
      expect(ui, ['minimize']);
    });

    testWidgets('🔴 видеозвонок: спрятанный пульт не нажимается', (t) async {
      await pump(t, _state(video: true));
      await t.pump(const Duration(seconds: 6));
      // Прозрачная «Завершить» раньше клала трубку от случайного щелчка.
      await t.tap(_dock('Завершить'), warnIfMissed: false);
      expect(ui, isEmpty);
    });

    group('сочетания', () {
      final command = !kIsWeb && Platform.isMacOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      Future<void> chord(WidgetTester t, LogicalKeyboardKey key) async {
        await t.sendKeyDownEvent(command);
        await t.sendKeyEvent(key);
        await t.sendKeyUpEvent(command);
        await t.pump();
      }

      testWidgets('Esc сворачивает', (t) async {
        await pump(t, _state());
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(ui, ['minimize']);
        await t.pump(const Duration(seconds: 2));
      });

      testWidgets('⌘D / Ctrl+D — микрофон, ⌘E — камера, ⌘W — положить трубку',
          (t) async {
        await pump(t, _state());
        await chord(t, LogicalKeyboardKey.keyD);
        await chord(t, LogicalKeyboardKey.keyE);
        expect(call.calls, ['mute', 'upgrade']);
        await chord(t, LogicalKeyboardKey.keyW);
        expect(ui, ['end']);
        await t.pump(const Duration(seconds: 2));
      });

      testWidgets('подсказка называет сочетание своей системы', (t) async {
        await pump(t, _state());
        final mod = !kIsWeb && Platform.isMacOS ? '⌘D' : 'Ctrl+D';
        expect(find.byTooltip('Выключить микрофон   $mod'), findsOneWidget);
        await t.pump(const Duration(seconds: 2));
      });
    });
  });

  group('мини-окно звонка один на один', () {
    testWidgets('кнопки мини-окна зовут те же вызовы', (t) async {
      final call = _FakeCall(_state());
      final ui = <String>[];
      await t.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: OneToOneCallMini.sizeFor(call.state.value),
              child: OneToOneCallMini(
                call: call,
                peerName: 'Анна',
                onExpand: () => ui.add('expand'),
                onEnd: () => ui.add('end'),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.text('Анна'), findsOneWidget);
      // Время разговора идёт и в мини-окне.
      expect(find.textContaining('01:0'), findsOneWidget);

      await t.tap(find.byTooltip('Выключить микрофон'));
      await t.pump();
      expect(call.calls, ['mute']);
      await t.tap(find.byTooltip('Включить камеру'));
      await t.pump();
      expect(call.calls, ['mute', 'upgrade']);
      await t.tap(find.byTooltip('Развернуть звонок'));
      await t.tap(find.byTooltip('Завершить'));
      await t.pump();
      expect(ui, ['expand', 'end']);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('двойной щелчок по сцене разворачивает', (t) async {
      final call = _FakeCall(_state());
      var expanded = 0;
      await t.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: OneToOneCallMini.sizeFor(call.state.value),
              child: OneToOneCallMini(
                call: call,
                peerName: 'Анна',
                onExpand: () => expanded++,
                onEnd: () {},
              ),
            ),
          ),
        ),
      );
      await t.pump();
      final at = t.getCenter(find.text('Анна'));
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 400));
      expect(expanded, 1);
      await t.pump(const Duration(seconds: 2));
    });

    test('высота — по виду звонка', () {
      expect(
        OneToOneCallMini.sizeFor(_state()).height,
        lessThan(OneToOneCallMini.sizeFor(_state(video: true)).height),
      );
      expect(
        OneToOneCallMini.sizeFor(_state()).width,
        DesktopCallMiniSize.width,
      );
    });
  });
}
