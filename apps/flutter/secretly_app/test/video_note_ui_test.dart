// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Вид записи видео-заметки (3b) настоящими жестами пальца: удержание,
// отмена (взвод и возврат), замок, пауза (две части на контуре), последние
// 10 секунд, просмотр с обрезкой, отправка. `SECRETLY_SHOTS=папка` — снимки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/video_note_controller.dart';
import 'package:secretly_app/ui/chat/video_note_recorder.dart';
import 'package:secretly_app/ui/chat/video_note_ui.dart';
import 'package:secretly_app/ui/chat/voice_recorder_ui.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();
final GlobalKey _buttonKey = GlobalKey();
final GlobalKey _composerKey = GlobalKey();

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

/// «Камера»: тёплая картинка с лицом-кругом, чтобы было видно кадр.
class _FakeView extends StatelessWidget {
  const _FakeView({super.key, required this.front});
  final bool front;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: front
            ? const [Color(0xFF6B4E3D), Color(0xFF2E3B4E)]
            : const [Color(0xFF3D6B52), Color(0xFF1F2E3B)],
      ),
    ),
    child: const Align(
      alignment: Alignment(0, 0.15),
      child: SizedBox(
        width: 110,
        height: 130,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFD9A982),
            borderRadius: BorderRadius.all(Radius.elliptical(55, 65)),
          ),
        ),
      ),
    ),
  );
}

class _Camera implements VideoNoteCamera {
  bool _open = false;
  bool _front = true;
  bool _rec = false;
  int _n = 0;
  final ValueNotifier<Widget?> _preview = ValueNotifier(null);
  @override
  ValueListenable<Widget?> get preview => _preview;
  @override
  bool get isOpen => _open;
  @override
  bool get isFront => _front;
  @override
  bool get canFlip => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> open({required bool front}) async {
    _open = true;
    _front = front;
    _preview.value = _FakeView(key: ValueKey(_front), front: _front);
  }

  @override
  Future<void> startSegment() async => _rec = true;
  @override
  Future<String?> stopSegment() async {
    if (!_rec) return null;
    _rec = false;
    return '/tmp/s${++_n}.mp4';
  }

  @override
  Future<void> flip() async {
    _front = !_front;
    _preview.value = _FakeView(key: ValueKey(_front), front: _front);
  }

  @override
  Future<void> setTorch(bool on) async {}
  @override
  Future<void> close() async {
    _open = false;
    _preview.value = null;
  }

  final List<double> zoomCalls = [];
  @override
  Future<VideoNoteZoomRange?> zoomRange() async =>
      _open ? const VideoNoteZoomRange(1, 16) : null;
  @override
  Future<void> setZoom(double level) async => zoomCalls.add(level);
}

class _Player implements VideoNotePreviewPlayer {
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  final ValueNotifier<Widget?> _view = ValueNotifier(
    const _FakeView(front: true),
  );
  @override
  Future<List<Duration>> load(List<VideoNoteSegment> s) async =>
      s.map((x) => x.length).toList();
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setRange(Duration a, Duration b) async {}
  @override
  Future<void> seek(Duration p) async => _pos.value = p;
  @override
  ValueListenable<Duration> get position => _pos;
  @override
  ValueListenable<Widget?> get view => _view;
  @override
  Future<void> dispose() async {}
}

const _strings = VideoNoteStrings(
  slideToCancel: 'Влево — отмена',
  releaseToDelete: 'Отпустите — удалить',
  pause: 'Пауза',
  resume: 'Продолжить',
  stop: 'Остановить и посмотреть',
  delete: 'Удалить',
  retake: 'Переснять',
  looped: 'зациклено',
  flip: 'Сменить камеру',
  light: 'Подсветка',
  play: 'Смотреть',
  trimStart: 'Начало ролика',
  trimEnd: 'Конец ролика',
  cameraUnavailable: 'Камера недоступна',
);

Rect? _rectOf(GlobalKey k) {
  final box = k.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _Chat extends StatefulWidget {
  const _Chat({required this.controller});
  final VideoNoteController controller;
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  OverlayEntry? _entry;
  VideoNoteController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.phase.addListener(_onPhase);
  }

  void _onPhase() {
    if (c.isActive && _entry == null) {
      _entry = OverlayEntry(
        builder: (_) => VideoNoteOverlay(
          controller: c,
          anchor: () => _rectOf(_buttonKey),
          composer: () => _rectOf(_composerKey),
          strings: _strings,
          onClosed: () {
            _entry?.remove();
            _entry = null;
          },
        ),
      );
      Overlay.of(context).insert(_entry!);
    }
    setState(() {});
  }

  @override
  void dispose() {
    c.phase.removeListener(_onPhase);
    _entry?.remove();
    super.dispose();
  }

  Widget _bubble(String text, {required bool me}) => Align(
    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: me ? const Color(0xFF2B5278) : const Color(0xFF232E3C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final active = c.isActive;
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text('Анна', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        _bubble('Привет! Как дела?', me: false),
        _bubble('Покажи, что там у тебя', me: false),
        _bubble('Сейчас сниму 🙂', me: true),
        const SizedBox(height: 8),
        Container(
          key: _composerKey,
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
                    ? VideoNoteComposerPanel(controller: c, strings: _strings)
                    : const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'Сообщение',
                          style: TextStyle(color: Color(0xB8A0B0C0)),
                        ),
                      ),
              ),
              VoiceRecordGestureArea(
                key: _buttonKey,
                controller: c,
                child: ValueListenableBuilder<VideoNotePhase>(
                  valueListenable: c.phase,
                  builder: (context, phase, _) {
                    final send =
                        phase == VideoNotePhase.locked ||
                        phase == VideoNotePhase.paused ||
                        phase == VideoNotePhase.preview;
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7FD0FF), Color(0xFF2E9FE4)],
                        ),
                      ),
                      child: Icon(
                        send ? Icons.arrow_upward_rounded : VideoNoteIcons.camera,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _app(VideoNoteController c) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
  builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
  home: Scaffold(
    backgroundColor: const Color(0xFF18222D),
    body: _Chat(controller: c),
  ),
);

VideoNoteController _controller(
  List<VideoNoteRecorderResult> sent, {
  _Camera? camera,
}) =>
    VideoNoteController(
      camera: camera ?? _Camera(),
      canStart: () async => true,
      onSend: (r) async => sent.add(r),
      onHint: (_) {},
      previewPlayer: _Player.new,
      produce: (s, {trimStart, trimEnd}) async => '/tmp/out.mp4',
      deleteFile: (_) async {},
      haptics: false,
    );

void main() {
  setUpAll(_loadFonts);

  for (final (p, tag) in [
    (TargetPlatform.iOS, 'ios'),
    (TargetPlatform.android, 'android'),
  ]) {
    testWidgets('видео-заметка настоящими жестами ($tag)', (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final sent = <VideoNoteRecorderResult>[];
      final c = _controller(sent);
      await t.pumpWidget(_app(c));
      final center = t.getCenter(find.byKey(_buttonKey));

      // Удержание: квадрат вырос из кнопки, контур идёт.
      final g = await t.startGesture(center);
      await t.pump(const Duration(milliseconds: 160));
      await t.pump();
      expect(c.phase.value, VideoNotePhase.holding);
      await t.pump(const Duration(milliseconds: 7200));
      expect(find.text('Влево — отмена'), findsOneWidget);
      expect(find.text('/ 1:00'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _shoot(t, 'vn_${tag}_1_holding');

      // Влево — отмена взведена; квадрат наклонился и покраснел.
      await g.moveBy(const Offset(-80, 0));
      await g.moveBy(const Offset(-60, 0));
      await t.pump(const Duration(milliseconds: 200));
      expect(c.cancelArmed.value, isTrue);
      expect(find.text('Отпустите — удалить'), findsOneWidget);
      await _shoot(t, 'vn_${tag}_2_cancel_armed');
      await g.moveBy(const Offset(140, 0));
      await t.pump(const Duration(milliseconds: 200));
      expect(c.cancelArmed.value, isFalse);

      // Вверх — замок.
      await g.moveBy(const Offset(0, -50));
      await t.pump(const Duration(milliseconds: 120));
      await _shoot(t, 'vn_${tag}_3_lock_pull');
      await g.moveBy(const Offset(0, -50));
      await t.pump(const Duration(milliseconds: 200));
      expect(c.phase.value, VideoNotePhase.locked);
      await g.up();
      await t.pump(const Duration(seconds: 5));

      // Пауза — и продолжение: на контуре две части.
      await t.tap(find.text('Пауза'));
      await t.pump(const Duration(milliseconds: 300));
      expect(c.phase.value, VideoNotePhase.paused);
      await _shoot(t, 'vn_${tag}_4_paused');
      await t.tap(find.text('Продолжить'));
      await t.pump(const Duration(seconds: 8));
      expect(c.ranges.value, hasLength(2));
      await _shoot(t, 'vn_${tag}_5_locked_two_parts');

      // Двойное касание по квадрату — смена камеры.
      final layout = VideoNoteLayout.of(
        screen: const Size(390, 844),
        padding: EdgeInsets.zero,
        composer: _rectOf(_composerKey),
      );
      await t.tapAt(layout.square.center);
      await t.pump(const Duration(milliseconds: 80));
      await t.tapAt(layout.square.center);
      await t.pump(const Duration(milliseconds: 400));
      expect(c.front.value, isFalse, reason: 'двойное касание сменило камеру');

      // Последние 10 секунд — контур жёлтый.
      await t.pump(const Duration(seconds: 31));
      expect(c.nearLimit.value, isTrue);
      await _shoot(t, 'vn_${tag}_6_last_seconds');

      // «Стоп» — просмотр с лентой обрезки.
      await t.tap(find.bySemanticsLabel('Остановить и посмотреть'));
      await t.pump(const Duration(milliseconds: 400));
      expect(c.phase.value, VideoNotePhase.preview);
      expect(find.text('Переснять'), findsOneWidget);
      // Тянем левый край ленты вправо.
      final strip = find.byType(VideoNoteTrimStrip);
      final r = t.getRect(strip);
      await t.dragFrom(r.centerLeft + const Offset(4, 0), const Offset(60, 0));
      await t.pump(const Duration(milliseconds: 300));
      expect(c.trim.value.start, greaterThan(Duration.zero));
      await _shoot(t, 'vn_${tag}_7_preview_trim');

      // «Отправить» — та же кнопка.
      await t.tapAt(center);
      await t.pump(const Duration(milliseconds: 500));
      expect(sent, hasLength(1));
      expect(c.phase.value, VideoNotePhase.idle);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await c.dispose();
    }, variant: TargetPlatformVariant.only(p));
  }

  testWidgets('отпускание с взведённой отменой — квадрат улетает', (t) async {
    t.view.physicalSize = const Size(375, 667) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final sent = <VideoNoteRecorderResult>[];
    final c = _controller(sent);
    await t.pumpWidget(_app(c));
    final g = await t.startGesture(t.getCenter(find.byKey(_buttonKey)));
    await t.pump(const Duration(milliseconds: 160));
    await t.pump(const Duration(seconds: 2));
    expect(t.takeException(), isNull, reason: 'iPhone SE: без переполнений');
    await _shoot(t, 'vn_se_holding');
    await g.moveBy(const Offset(-150, 0));
    await t.pump();
    await g.up();
    await t.pump(const Duration(milliseconds: 150));
    expect(c.phase.value, VideoNotePhase.cancelling);
    await _shoot(t, 'vn_se_cancelling');
    await t.pump(const Duration(seconds: 1));
    expect(c.phase.value, VideoNotePhase.idle);
    expect(sent, isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await c.dispose();
  });
  testWidgets('приближение настоящими жестами: щипок, выше замка, в замке', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final sent = <VideoNoteRecorderResult>[];
    final cam = _Camera();
    final c = _controller(sent, camera: cam);
    await t.pumpWidget(_app(c));
    final g = await t.startGesture(t.getCenter(find.byKey(_buttonKey)));
    await t.pump(const Duration(milliseconds: 160));
    await t.pump(const Duration(seconds: 2));
    expect(c.phase.value, VideoNotePhase.holding);
    expect(c.zoomEnabled.value, isTrue);
    final square = VideoNoteLayout.of(
      screen: const Size(390, 844),
      padding: EdgeInsets.zero,
      composer: _rectOf(_composerKey),
    ).square;

    // Палец держит кнопку, двумя другими — щипок по квадрату.
    final a = await t.startGesture(square.center - const Offset(40, 0), pointer: 7);
    final b = await t.startGesture(square.center + const Offset(40, 0), pointer: 8);
    for (var i = 0; i < 12; i++) {
      await a.moveBy(const Offset(-5, 0));
      await b.moveBy(const Offset(5, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await t.pump(const Duration(milliseconds: 100));
    final pinched = c.zoom.value;
    // Пальцы разошлись вдвое (80 → 200); часть хода — порог распознавания.
    expect(pinched, greaterThan(1.5));
    expect(pinched, lessThanOrEqualTo(2.51));
    expect(c.phase.value, VideoNotePhase.holding, reason: 'щипок — не замок');
    expect(c.cancelArmed.value, isFalse);
    expect(c.front.value, isTrue, reason: 'щипок — не двойное касание');
    expect(cam.zoomCalls, isNotEmpty);
    // Капсула со значением видна и гаснет.
    expect(find.text('${pinched.toStringAsFixed(1)}×'), findsOneWidget);
    double pillOpacity() => t
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(VideoNoteZoomPill),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(pillOpacity(), 1);
    await _shoot(t, 'vn_zoom_1_pinch');
    await t.pump(const Duration(seconds: 1));
    expect(pillOpacity(), 0);

    // Тот же палец: вверх — замок, как раньше. 🔴 Дальше вверх — НЕ
    // приближает (слово владельца 22.11.2026): только жест по квадрату.
    await g.moveBy(const Offset(0, -50));
    await g.moveBy(const Offset(0, -50));
    await t.pump();
    expect(c.phase.value, VideoNotePhase.locked);
    expect(c.zoom.value, pinched, reason: 'на самом замке — без изменений');
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -20));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(c.zoom.value, pinched, reason: 'палец к замку не приближает');
    await g.up();
    await t.pump(const Duration(milliseconds: 300));
    expect(c.phase.value, VideoNotePhase.locked, reason: 'отпустил — замок');
    expect(sent, isEmpty);

    // В замке — один палец вверх по квадрату: ближе, вниз — дальше.
    await t.dragFrom(square.center, const Offset(0, -90));
    await t.pump(const Duration(milliseconds: 100));
    final lifted = c.zoom.value;
    expect(lifted, greaterThan(pinched + 0.5));
    await t.dragFrom(square.center, const Offset(0, 90));
    await t.pump(const Duration(milliseconds: 100));
    expect(c.zoom.value, lessThan(lifted - 0.5));
    expect(c.phase.value, VideoNotePhase.locked);

    // Двойное касание — смена камеры, приближение снова 1×.
    await t.pump(const Duration(milliseconds: 400));
    await t.tapAt(square.center);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(square.center);
    await t.pump(const Duration(milliseconds: 400));
    expect(c.front.value, isFalse);
    expect(c.zoom.value, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await c.dispose();
  });

  test('подпись приближения: запятая, кроме английского', () {
    expect(videoNoteZoomLabel(1.84, const Locale('ru')), '1,8×');
    expect(videoNoteZoomLabel(1.84, const Locale('de')), '1,8×');
    expect(videoNoteZoomLabel(1.84, const Locale('en')), '1.8×');
    expect(videoNoteZoomLabel(2, const Locale('uk')), '2,0×');
  });

  test('23.11.2026: при открытой клавиатуре квадрат и кнопки над полем', () {
    // iPhone 14 и SE с открытой клавиатурой: поле ввода поднято над ней.
    for (final (screen, padding, composerTop) in [
      (const Size(390, 844), const EdgeInsets.only(top: 47, bottom: 34), 452.0),
      (const Size(375, 667), const EdgeInsets.only(top: 20), 352.0),
    ]) {
      final composer = Rect.fromLTWH(0, composerTop, screen.width, 60);
      final l = VideoNoteLayout.of(
        screen: screen,
        padding: padding,
        composer: composer,
      );
      expect(l.pillTop, greaterThanOrEqualTo(padding.top));
      expect(l.square.top, greaterThan(l.pillTop + 36));
      expect(l.square.width, greaterThanOrEqualTo(120));
      expect(l.square.left, greaterThanOrEqualTo(0));
      expect(l.square.right, lessThanOrEqualTo(screen.width));
      // Кнопки (96) кончаются выше поля ввода.
      expect(l.controlsTop + 96, lessThanOrEqualTo(composer.top), reason: '$screen');
    }
    // Без клавиатуры раскладка прежняя: зазоры 18, таймер на +46.
    final open = VideoNoteLayout.of(
      screen: const Size(390, 844),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
      composer: const Rect.fromLTWH(0, 760, 390, 60),
    );
    expect(open.pillTop, 47 + 46);
    expect(open.square.width, 366);
  });
}
