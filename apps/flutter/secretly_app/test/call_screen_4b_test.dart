// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Экран звонка 4b настоящей отрисовкой: входящий, вызов, разговор,
// «Ещё», ключ звонка, завершён — без переполнений на iPhone 11 и SE, на
// русском и немецком (длинные подписи). `SECRETLY_SHOTS=папка` — снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_audio_route.dart';
import 'package:secretly_app/calls/call_manager.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/calls/call_state_machine.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/active_call_screen.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

class _FakeCallManager implements CallManager {
  _FakeCallManager(CallState s) : state = ValueNotifier(s);

  @override
  final ValueNotifier<CallState> state;

  final ValueNotifier<CallAudioRouteState> _routes = ValueNotifier(
    CallAudioRouteState.idle(preferSpeakerByDefault: false),
  );

  @override
  ValueListenable<CallAudioRouteState> get audioRouteState => _routes;

  @override
  WebRtcCallSession? get session => null;

  int mutes = 0;

  @override
  Future<void> toggleMute() async {
    mutes++;
    state.value = state.value.copyWith(isMuted: !state.value.isMuted);
  }

  @override
  Future<void> onAppResumedDuringCall() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CallState _state(CallPhase phase, {bool video = false, bool incoming = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return CallState(
    lifecycle: CallLifecycleState.values.first,
    phase: phase,
    callId: 'c1',
    callAttemptId: 'a1',
    direction: incoming ? CallDirection.incoming : CallDirection.outgoing,
    startedAtMs: now,
    peerProfileId: 'PEER1234',
    peerName: 'Анна Ковальчук',
    isVideo: video,
    connectedAtMs: phase == CallPhase.connected || phase == CallPhase.ended
        ? now - 252000
        : null,
    endReason: phase == CallPhase.ended ? CallEndReason.remoteHangup : null,
  );
}

Widget _app(CallManager cm, Locale locale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
  builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
  home: ActiveCallScreen(callManager: cm),
);

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Платформенные вызовы экрана (окно ОС, «не гасить экран») — в тесте пусто.
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  for (final name in ['secretly/pip', 'secretly/call_ui', 'secretly/android_pip']) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
}

Future<void> _pump(WidgetTester t, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final (size, tag) in [
    (const Size(390, 844), 'i11'),
    (const Size(375, 667), 'se'),
  ]) {
    for (final locale in const [Locale('ru'), Locale('de')]) {
      testWidgets('звонок 4b: все фазы без ошибок ($tag, ${locale.languageCode})',
          (t) async {
        _mockChannels();
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final lc = locale.languageCode;

        // Входящий.
        final incoming = _FakeCallManager(
          _state(CallPhase.ringingIncoming, incoming: true),
        );
        await t.pumpWidget(_app(incoming, locale));
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_1_incoming');

        // Исходящий вызов.
        final out = _FakeCallManager(_state(CallPhase.ringingOutgoing));
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_app(out, locale));
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_2_outgoing');

        // Разговор.
        final cm = _FakeCallManager(_state(CallPhase.connected));
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_app(cm, locale));
        await t.pump(const Duration(seconds: 1));
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_3_audio');

        // Микрофон: белая кнопка.
        await t.tap(find.bySemanticsLabel(RegExp('Микрофон|Stumm')).first);
        await _pump(t);
        expect(cm.mutes, 1);
        // «Ещё».
        await t.tap(find.bySemanticsLabel(RegExp('Ещё|Mehr')).first);
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_4_more');

        // Ключ звонка.
        await t.tap(find.bySemanticsLabel(RegExp('Ключ звонка|Anrufschlüssel')));
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_5_key');

        // Завершён.
        final ended = _FakeCallManager(_state(CallPhase.ended));
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_app(ended, locale));
        await _pump(t);
        expect(t.takeException(), isNull);
        await _shoot(t, 'call_${tag}_${lc}_6_ended');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
      });
    }
  }
}
