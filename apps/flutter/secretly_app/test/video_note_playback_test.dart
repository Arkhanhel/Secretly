// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Видео-заметка в ленте по макету 5a (22.11.2026): раскрытие почти во всю
// ширину, ОДИН прогресс (по контуру, без полосы в мини-плеере), пауза,
// перемотка протяжкой, приглушение ленты, касание мимо, «просмотрено»,
// цепочка, лента без звука не больше двух плееров.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/chat/video_note_bubble.dart';
import 'package:secretly_app/ui/chat/video_note_playback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FakePlayer extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  int _next = 1;
  final Map<int, StreamController<VideoEvent>> streams = {};
  final Map<int, bool> playing = {};
  final Map<int, double> volume = {};
  final Map<int, bool> looping = {};
  final Map<int, Duration> position = {};
  final List<int> disposed = [];
  static const Duration length = Duration(seconds: 9);

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    final c = StreamController<VideoEvent>();
    streams[id] = c;
    position[id] = Duration.zero;
    c.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: length,
        size: const Size(480, 480),
      ),
    );
    return id;
  }

  @override
  Future<int?> create(DataSource dataSource) =>
      createWithOptions(VideoCreationOptions(dataSource: dataSource, viewType: VideoViewType.textureView));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      this.looping[playerId] = looping;

  @override
  Future<void> play(int playerId) async => playing[playerId] = true;

  @override
  Future<void> pause(int playerId) async => playing[playerId] = false;

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      this.volume[playerId] = volume;

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      this.position[playerId] = position;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      position[playerId] ?? Duration.zero;

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.teal);

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.teal);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  /// Ролик доиграл до конца.
  void finish(int id) {
    position[id] = length;
    playing[id] = false;
    streams[id]?.add(VideoEvent(eventType: VideoEventType.completed));
  }

  Iterable<int> get soundOn =>
      volume.entries.where((e) => e.value > 0 && !disposed.contains(e.key)).map((e) => e.key);
}

AttachmentEventV1 _att(String blob) => AttachmentEventV1(
  eventId: 'e-$blob',
  blobId: blob,
  fileKeyB64: 'AAAA',
  sizeBytes: 1000,
  mime: 'video/mp4',
  durationMs: 9000,
);

void main() {
  late _FakePlayer fake;
  late Directory dir;

  setUp(() {
    fake = _FakePlayer();
    VideoPlayerPlatform.instance = fake;
    SharedPreferences.setMockInitialValues({});
    VideoNotePlayback.instance.resetForTest();
    VideoNoteWatched.instance.resetForTest(sinceMs: 0);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    dir = Directory.systemTemp.createTempSync('vn_');
  });

  tearDown(() {
    VideoNotePlayback.instance.resetForTest();
    dir.deleteSync(recursive: true);
  });

  Future<File> resolve(AttachmentEventV1 a) async => File('${dir.path}/${a.blobId}.mp4');

  Widget app(List<Widget> notes) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(title: const Text('Anna')),
      body: VideoNoteOutsideTap(
        child: ListView(
          children: [
            for (final n in notes) VideoNoteDim(child: n),
            const VideoNoteDim(
              child: SizedBox(
                key: ValueKey('other'),
                height: 80,
                child: Text('other message'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  VideoNoteBubble note(String blob, {bool isMe = false, int at = 1000}) =>
      VideoNoteBubble(
        key: ValueKey(blob),
        attachment: _att(blob),
        isMe: isMe,
        resolveFile: resolve,
        footer: const SizedBox(height: 12),
        createdAtMs: at,
        authorName: 'Anna',
        hapticsEnabled: () => false,
      );

  Future<void> settle(WidgetTester t, [int frames = 40]) async {
    for (var i = 0; i < frames; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('раскрытие почти во всю ширину, звук, один прогресс', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    VideoNotePlayback.instance.feedAutoplayEnabled = false;
    await t.pumpWidget(app([note('a')]));
    await settle(t, 5);
    final square = find.byWidgetPredicate(
      (w) => w is SizedBox && w.key is GlobalKey && w.width == w.height && (w.width ?? 0) > 100,
    );
    expect(t.getSize(square.first).width, closeTo(176, .5));

    await t.tap(square.first);
    await settle(t);
    expect(t.getSize(square.first).width, closeTo(366, .5), reason: '390 − 2×12');
    expect(VideoNotePlayback.instance.active.value, isNotNull);
    expect(fake.soundOn, isNotEmpty, reason: 'раскрытая играет со звуком');

    // Мини-плеер: заголовок и время, БЕЗ полосы прогресса.
    expect(find.text('Anna · video note'), findsOneWidget);
    expect(find.textContaining(' / 0:09'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // Прогресс — один, по контуру.
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is VideoNotePerimeterPainter),
      findsOneWidget,
    );

    // Остальная лента приглушена.
    final otherOpacity = t.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('other message'), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(otherOpacity.opacity, .35);

    // Касание по раскрытому — пауза: по центру ▶.
    await t.tap(square.first);
    await settle(t, 20);
    expect(fake.playing.values.where((p) => p), isEmpty);

    // Касание мимо — сворачивается, точка «не просмотрено» гаснет.
    await t.tap(find.text('other message'));
    await settle(t);
    expect(VideoNotePlayback.instance.active.value, isNull);
    expect(t.getSize(square.first).width, closeTo(176, .5));
    expect(VideoNoteWatched.instance.isWatched('a', 1000), isTrue);
    expect(find.text('Anna · video note'), findsNothing);
    // Касание мимо только сворачивает — его «съели».
    expect(VideoNotePlayback.instance.takeSwallowedTap(), isTrue);
    await settle(t, 40);
  });

  testWidgets('протяжка вбок перематывает и не ставит паузу касанием', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    VideoNotePlayback.instance.feedAutoplayEnabled = false;
    await t.pumpWidget(app([note('a')]));
    await settle(t, 5);
    final square = find.byWidgetPredicate(
      (w) => w is SizedBox && w.key is GlobalKey && w.width == w.height && (w.width ?? 0) > 100,
    );
    await t.tap(square.first);
    await settle(t);
    final center = t.getCenter(square.first);
    final g = await t.startGesture(center - const Offset(100, 0));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(18, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    // По центру — время с шевронами.
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    await g.up();
    await settle(t, 10);
    final mainId = fake.volume.entries.firstWhere((e) => e.value > 0).key;
    // ≈160 из 366 (минус порог начала протяжки) ≈ 4 секунды из 9.
    expect(fake.position[mainId]!.inMilliseconds, inInclusiveRange(3000, 5000));
    expect(fake.playing[mainId], isTrue, reason: 'после перемотки — играет');
    VideoNotePlayback.instance.collapseActive();
    await settle(t);
  });

  testWidgets('конец ролика — следующая непросмотренная входящая ниже', (t) async {
    t.view.physicalSize = const Size(390 * 3, 2400 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    VideoNotePlayback.instance.feedAutoplayEnabled = false;
    await t.pumpWidget(
      app([
        note('a', at: 1000),
        note('mine', isMe: true, at: 1500),
        note('b', at: 2000),
      ]),
    );
    await settle(t, 5);
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('a')),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.key is GlobalKey),
      ),
    );
    await settle(t);
    final aId = fake.volume.entries.firstWhere((e) => e.value > 0).key;
    fake.finish(aId);
    await settle(t, 40);
    // Через 380 мс раскрылась «b», а не своя.
    await t.pump(const Duration(milliseconds: 400));
    await settle(t, 30);
    final active = VideoNotePlayback.instance.active.value;
    expect(active?.noteId, 'b');
    VideoNotePlayback.instance.collapseActive();
    await settle(t);
  });

  test('лента без звука: не больше двух самых видимых', () {
    final pb = VideoNotePlayback.instance;
    final live = <String, bool>{};
    for (final id in ['x', 'y', 'z']) {
      pb.register(_Client(id, live));
    }
    pb.reportVisibility('x', 1);
    pb.reportVisibility('y', .9);
    pb.reportVisibility('z', .6);
    expect(live, {'x': true, 'y': true});
    pb.reportVisibility('x', 0);
    expect(live['x'], isFalse);
    expect(live['z'], isTrue);
  });

  test('лента стоит под меню, записью и просмотром медиа (suspendFeed)', () {
    final pb = VideoNotePlayback.instance;
    final live = <String, bool>{};
    for (final id in ['s1', 's2']) {
      pb.register(_Client(id, live));
    }
    pb.reportVisibility('s1', 1);
    expect(live['s1'], isTrue);
    final resumeA = pb.suspendFeed();
    expect(live['s1'], isFalse);
    final resumeB = pb.suspendFeed();
    resumeA();
    resumeA(); // повторный вызов ничего не ломает
    expect(live['s1'], isFalse, reason: 'второе перекрытие ещё открыто');
    resumeB();
    expect(live['s1'], isTrue);
    pb.reportVisibility('s1', 0);
  });

  test('заметки старше первого запуска считаются просмотренными', () async {
    VideoNoteWatched.instance.resetForTest(sinceMs: 5000);
    expect(VideoNoteWatched.instance.isWatched('old', 4000), isTrue);
    expect(VideoNoteWatched.instance.isWatched('new', 6000), isFalse);
    await VideoNoteWatched.instance.markWatched('new');
    expect(VideoNoteWatched.instance.isWatched('new', 6000), isTrue);
  });

  test('контур: старт сверху посередине, перерисовка только при смене', () {
    final a = VideoNotePerimeterPainter(fraction: .3, radius: 35);
    expect(a.shouldRepaint(VideoNotePerimeterPainter(fraction: .3, radius: 35)), isFalse);
    expect(a.shouldRepaint(VideoNotePerimeterPainter(fraction: .31, radius: 35)), isTrue);
    expect(formatVideoNoteTime(const Duration(seconds: 65)), '1:05');
  });
}

class _Client implements VideoNoteFeedClient {
  _Client(this.noteId, this.live);

  @override
  final String noteId;
  final Map<String, bool> live;

  @override
  int get createdAtMs => 0;

  @override
  bool get isMe => false;

  @override
  void openFromChain() {}

  @override
  void setFeedLive(bool v) => live[noteId] = v;
}
