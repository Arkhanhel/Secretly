// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Вид записи голосового настоящими жестами пальца: удержание, отмена
// (взвод и возврат), замок, «Стоп», прослушивание, отправка. Главный сторож:
// один слушатель касаний ведёт жест, даже когда вид кнопки меняется.
// `SECRETLY_SHOTS=папка` — снимки.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/voice_recorder_controller.dart';
import 'package:secretly_app/ui/chat/voice_recorder_ui.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();
final GlobalKey _buttonKey = GlobalKey();

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

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  // Дать анимациям дойти до конца — снимок итогового вида.
  for (var i = 0; i < 25; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
  await t.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

class _Backend implements VoiceRecorderBackend {
  final StreamController<double> levels_ = StreamController.broadcast();
  String? path;
  bool cancelled = false;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String p) async => path = p;
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Stream<double> levels() => levels_.stream;
}

class _Player implements VoicePreviewPlayer {
  @override
  Future<void> load(String path) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

const _strings = VoiceRecorderStrings(
  slideToCancel: 'Влево — отмена',
  releaseToDelete: 'Отпустите — удалить',
  deleted: 'Запись удалена',
  stop: 'Остановить и прослушать',
  delete: 'Удалить',
  play: 'Прослушать',
  pause: 'Пауза',
);

const _accentTop = Color(0xFF7FD0FF);
const _accentBottom = Color(0xFF2E9FE4);

/// Поле ввода как в чате: текст ↔ панель записи, справа — кнопка под одним
/// слушателем; слой записи — в Overlay.
class _Composer extends StatefulWidget {
  const _Composer({required this.controller});
  final VoiceRecorderController controller;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.controller.phase.addListener(_onPhase);
  }

  void _onPhase() {
    final active = widget.controller.phase.value != VoicePhase.idle;
    if (active && _entry == null) {
      _entry = OverlayEntry(
        builder: (_) => VoiceRecorderOverlay(
          controller: widget.controller,
          anchor: () {
            final box =
                _buttonKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return null;
            return box.localToGlobal(Offset.zero) & box.size;
          },
          accentTop: _accentTop,
          accentBottom: _accentBottom,
          strings: _strings,
        ),
      );
      Overlay.of(context).insert(_entry!);
    } else if (!active) {
      _entry?.remove();
      _entry = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.phase.removeListener(_onPhase);
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.phase.value != VoicePhase.idle;
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 28),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xF0232E3C),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: active
                ? VoiceRecorderPanel(
                    controller: widget.controller,
                    strings: _strings,
                    accent: _accentTop,
                  )
                : const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Сообщение'),
                  ),
          ),
          VoiceRecordGestureArea(
            key: _buttonKey,
            controller: widget.controller,
            child: ValueListenableBuilder<VoicePhase>(
              valueListenable: widget.controller.phase,
              builder: (context, phase, _) {
                final send =
                    phase == VoicePhase.locked || phase == VoicePhase.preview;
                return Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_accentTop, _accentBottom],
                    ),
                  ),
                  child: Icon(
                    send ? Icons.arrow_upward_rounded : VoiceIcons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _app(VoiceRecorderController c, Brightness b) => MaterialApp(
  theme: ThemeData(brightness: b, fontFamily: 'Inter'),
  builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
  home: Scaffold(
    backgroundColor: b == Brightness.dark
        ? const Color(0xFF151E27)
        : const Color(0xFFF2F2F7),
    body: Column(
      children: [
        const Spacer(),
        _Composer(controller: c),
      ],
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);

  for (final (p, tag) in [
    (TargetPlatform.iOS, 'ios'),
    (TargetPlatform.android, 'android'),
  ]) {
    for (final b in [Brightness.dark, Brightness.light]) {
      final bt = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('запись настоящими жестами ($tag, $bt)', (t) async {
        t.view.physicalSize = const Size(390, 844) * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final backend = _Backend();
        final sent = <VoiceTake>[];
        final c = VoiceRecorderController(
          backend: backend,
          newTempPath: () async => '/tmp/v.m4a',
          canStart: () async => true,
          onSend: (x) async => sent.add(x),
          onHint: (_) {},
          previewPlayer: _Player.new,
          deleteFile: (_) async {},
          haptics: false,
        );
        await t.pumpWidget(_app(c, b));
        final center = t.getCenter(find.byKey(_buttonKey));

        // Удержание.
        final g = await t.startGesture(center);
        await t.pump(const Duration(milliseconds: 160));
        await t.pump();
        expect(c.phase.value, VoicePhase.holding);
        for (var i = 0; i < 40; i++) {
          backend.levels_.add(0.15 + (i % 7) * 0.12);
        }
        await t.pump(const Duration(milliseconds: 1400));
        expect(find.text('Влево — отмена'), findsOneWidget);
        await _shoot(t, 'rec_${tag}_${bt}_1_holding');

        // Влево за порог — отмена взведена, но запись идёт.
        await g.moveBy(const Offset(-80, 0));
        await g.moveBy(const Offset(-70, 0));
        await t.pump(const Duration(milliseconds: 250));
        expect(c.cancelArmed.value, isTrue);
        expect(find.text('Отпустите — удалить'), findsOneWidget);
        await _shoot(t, 'rec_${tag}_${bt}_2_cancel_armed');
        // Вернул палец — снята.
        await g.moveBy(const Offset(130, 0));
        await t.pump(const Duration(milliseconds: 250));
        expect(c.cancelArmed.value, isFalse);

        // Вверх к замку.
        await g.moveBy(const Offset(0, -55));
        await t.pump(const Duration(milliseconds: 200));
        await _shoot(t, 'rec_${tag}_${bt}_3_lock_pull');
        await g.moveBy(const Offset(0, -45));
        await t.pump(const Duration(milliseconds: 300));
        expect(c.phase.value, VoicePhase.locked);
        await g.up();
        await t.pump(const Duration(milliseconds: 400));
        expect(c.phase.value, VoicePhase.locked);
        await _shoot(t, 'rec_${tag}_${bt}_4_locked');

        // «Стоп» — прослушивание.
        await t.tap(find.bySemanticsLabel('Остановить и прослушать'));
        await t.pump(const Duration(milliseconds: 400));
        expect(c.phase.value, VoicePhase.preview);
        await _shoot(t, 'rec_${tag}_${bt}_5_preview');

        // «Отправить» — та же кнопка, тот же слушатель.
        await t.tapAt(center);
        await t.pump(const Duration(milliseconds: 400));
        expect(sent, hasLength(1));
        expect(c.phase.value, VoicePhase.idle);
        await t.pumpWidget(const SizedBox());
        await c.dispose();
      }, variant: TargetPlatformVariant.only(p));
    }
  }

  testWidgets('отпускание с взведённой отменой — «Запись удалена»', (t) async {
    final backend = _Backend();
    final c = VoiceRecorderController(
      backend: backend,
      newTempPath: () async => '/tmp/v.m4a',
      canStart: () async => true,
      onSend: (_) async {},
      onHint: (_) {},
      previewPlayer: _Player.new,
      deleteFile: (_) async {},
      haptics: false,
    );
    await t.pumpWidget(_app(c, Brightness.dark));
    final g = await t.startGesture(t.getCenter(find.byKey(_buttonKey)));
    await t.pump(const Duration(milliseconds: 160));
    await t.pump(const Duration(milliseconds: 900));
    await g.moveBy(const Offset(-160, 0));
    await t.pump();
    await g.up();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Запись удалена'), findsOneWidget);
    expect(backend.cancelled, isTrue);
    await _shoot(t, 'rec_deleted');
    await t.pump(const Duration(seconds: 1));
    expect(c.phase.value, VoicePhase.idle);
    await t.pumpWidget(const SizedBox());
    await c.dispose();
  });
}
