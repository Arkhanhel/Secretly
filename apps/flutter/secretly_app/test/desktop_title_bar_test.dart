// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Шапка окна: островок «сейчас играет» посередине, поиск — слева от него,
// выдача поиска — под полем, а не отдельным окном (24.09.2026).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_production_app.dart'
    show desktopNowPlayingOf;
import 'package:secretly_app/ui/desktop/app/desktop_spotlight.dart';
import 'package:secretly_app/ui/desktop/chat/details/desktop_selection_store.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/now_playing_island.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart' show DesktopSection;
import 'package:secretly_app/ui/desktop/shell/window_chrome.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: child),
  ),
);

DesktopNowPlaying _now({
  bool playing = true,
  Duration position = Duration.zero,
  Duration duration = const Duration(seconds: 100),
  int queueLength = 1,
  int queueIndex = 0,
}) => DesktopNowPlaying(
  title: 'Izzamuzzic – run in',
  artist: 'Yurii iOS',
  sourceConvoId: 'convo-1',
  playing: playing,
  position: position,
  duration: duration,
  queue: [
    for (var i = 0; i < queueLength; i++)
      DesktopNowPlayingEntry(
        title: i == queueIndex ? 'Izzamuzzic – run in' : 'Песня $i',
        artist: 'Yurii iOS',
      ),
  ],
  queueIndex: queueIndex,
);

void main() {
  group('островок «сейчас играет»', () {
    late List<String> calls;

    setUp(() => calls = <String>[]);

    Widget island(DesktopNowPlaying? now, {double width = 340}) => _host(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 48,
          child: DesktopNowPlayingIsland(
            state: now,
            onTogglePlay: () => calls.add('toggle'),
            onSeek: (d) => calls.add('seek ${d.inSeconds}'),
            onClose: () => calls.add('close'),
            onPrevious: () => calls.add('prev'),
            onNext: () => calls.add('next'),
            onPlayIndex: (i) => calls.add('play $i'),
            onOpenSource: (id) => calls.add('open $id'),
          ),
        ),
      ),
    );

    testWidgets('пока плеер пуст, островка нет', (t) async {
      await t.pumpWidget(island(null));
      expect(
        find.textContaining('Izzamuzzic', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('играет — видно название, отправителя и время', (t) async {
      await t.pumpWidget(
        island(
          _now(
            position: const Duration(seconds: 62),
            duration: const Duration(seconds: 205),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(
        find.textContaining('Izzamuzzic – run in', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Yurii iOS', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1:02 / 3:25'), findsOneWidget);
      // Одна запись — «назад/вперёд» не обещают перехода, которого нет.
      expect(find.byTooltip('Предыдущий'), findsNothing);
      expect(find.byTooltip('Следующий'), findsNothing);
    });

    testWidgets('кнопки управляют общим плеером', (t) async {
      await t.pumpWidget(island(_now(queueLength: 2)));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Пауза'));
      await t.tap(find.byTooltip('Следующий'));
      // Первая в очереди — «назад» гаснет, а не исчезает.
      expect(find.byTooltip('Предыдущий'), findsOneWidget);
      await t.tap(find.byTooltip('Предыдущий'), warnIfMissed: false);
      await t.tap(find.byTooltip('Закрыть плеер'));
      expect(calls, ['toggle', 'next', 'close']);
    });

    testWidgets('🔴 нажатие на название раскрывает музыку этого чата', (
      t,
    ) async {
      await t.pumpWidget(island(_now(queueLength: 3, queueIndex: 1)));
      await t.pumpAndSettle();
      expect(
        find.text('Песня 0'),
        findsNothing,
        reason: 'до нажатия списка нет',
      );

      await t.tap(find.textContaining('Izzamuzzic', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Песня 0'), findsOneWidget);
      expect(find.text('Песня 2'), findsOneWidget);
      final islandRect = t.getRect(find.byType(DesktopNowPlayingIsland));
      expect(
        t.getRect(find.text('Песня 0')).top,
        greaterThan(islandRect.center.dy),
        reason: 'список выпадает ПОД островок',
      );

      // Другая запись — включить её; текущая — пауза.
      await t.tap(find.text('Песня 2'));
      await t.tap(find.text('Izzamuzzic – run in').last);
      await t.tap(find.text('Перейти к сообщению'));
      await t.pumpAndSettle();
      expect(calls, ['play 2', 'toggle', 'open convo-1']);
      expect(
        find.text('Песня 0'),
        findsNothing,
        reason: 'переход к сообщению закрывает список',
      );
    });

    testWidgets('щелчок мимо закрывает список', (t) async {
      await t.pumpWidget(island(_now(queueLength: 2)));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Izzamuzzic', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Песня 1'), findsOneWidget);
      await t.tapAt(const Offset(700, 500));
      await t.pumpAndSettle();
      expect(find.text('Песня 1'), findsNothing);
    });

    testWidgets('на паузе кнопка обещает «играть»', (t) async {
      await t.pumpWidget(island(_now(playing: false)));
      await t.pumpAndSettle();
      expect(find.byTooltip('Воспроизвести'), findsOneWidget);
      expect(find.byTooltip('Пауза'), findsNothing);
    });

    testWidgets('полоса снизу перематывает', (t) async {
      await t.pumpWidget(island(_now()));
      await t.pumpAndSettle();
      final box = t.getRect(find.byType(DesktopNowPlayingIsland));
      // Островок — 30 точек посередине слота в 48; полоса — нижние пять.
      final bottom = box.center.dy + 15;
      await t.tapAt(Offset(box.left + box.width / 2, bottom - 2));
      expect(calls, contains('seek 50'));
    });

    testWidgets('без места островок прячется, а не мнётся', (t) async {
      await t.pumpWidget(island(_now(), width: 0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(
        find.textContaining('Izzamuzzic', findRichText: true),
        findsNothing,
      );
    });

    test('корень переводит состояние плеера в описание островка', () {
      expect(desktopNowPlayingOf(const SharedAudioPlaybackState()), isNull);
      final a = SharedAudioTrack(
        trackId: 'a',
        kind: SharedAudioTrackKind.attachment,
        title: 'Голосовое сообщение',
        artist: 'Yurii iOS',
        sourceConvoId: 'convo-1',
        resolveFilePath: () async => '/dev/null',
      );
      final b = SharedAudioTrack(
        trackId: 'b',
        kind: SharedAudioTrackKind.attachment,
        title: 'Песня',
        artist: 'Yurii iOS',
        resolveFilePath: () async => '/dev/null',
      );
      final now = desktopNowPlayingOf(
        SharedAudioPlaybackState(
          currentTrack: b,
          queue: [a, b],
          queueIndex: 1,
          loadingTrackId: 'b',
          playing: true,
          position: const Duration(seconds: 3),
          duration: const Duration(seconds: 9),
        ),
      )!;
      expect(now.title, 'Песня');
      expect(now.queue.map((e) => e.title), ['Голосовое сообщение', 'Песня']);
      expect(now.loading, isTrue);
      expect(now.canPrevious, isTrue);
      expect(now.canNext, isFalse);
      expect(now.position, const Duration(seconds: 3));
      expect(now.duration, const Duration(seconds: 9));
    });
  });

  group('раскладка шапки', () {
    const searchKey = Key('search');
    const islandKey = Key('island');
    const trailKey = Key('trail');

    Future<({Rect search, Rect island, Rect trail, Rect crumbs})> layout(
      WidgetTester t,
      double width,
    ) async {
      t.view.physicalSize = Size(width, 700);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _host(
          Column(
            children: [
              DesktopWindowChrome(
                leading: const DesktopBreadcrumbs(
                  crumbs: ['Чаты', 'Yurii iOS'],
                ),
                search: Container(
                  key: searchKey,
                  height: 30,
                  color: Colors.blue,
                ),
                island: Container(
                  key: islandKey,
                  height: 30,
                  color: Colors.red,
                ),
                trailing: const SizedBox(key: trailKey, width: 64, height: 28),
              ),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      return (
        search: t.getRect(find.byKey(searchKey)),
        island: t.getRect(find.byKey(islandKey)),
        trail: t.getRect(find.byKey(trailKey)),
        crumbs: t.getRect(find.byType(DesktopBreadcrumbs)),
      );
    }

    testWidgets('🔴 островок — посередине окна, поиск — сразу слева', (
      t,
    ) async {
      final r = await layout(t, 1720);
      expect(r.island.center.dx, closeTo(1720 / 2, 0.5));
      expect(r.island.width, 340);
      expect(r.search.width, 280);
      expect(r.island.left - r.search.right, 12);
      expect(r.trail.right, lessThanOrEqualTo(1720));
      expect(r.crumbs.right, lessThan(r.search.left));
    });

    testWidgets('в узком окне крошки не задвигаются под поле', (t) async {
      final r = await layout(t, 1100);
      expect(r.crumbs.right, lessThan(r.search.left));
      expect(r.search.right, lessThanOrEqualTo(r.island.left));
      expect(r.island.right, lessThanOrEqualTo(r.trail.left));
      expect(r.island.width, greaterThanOrEqualTo(220));
    });

    testWidgets('совсем тесно — уходит островок, поле остаётся', (t) async {
      final r = await layout(t, 760);
      expect(r.search.width, greaterThanOrEqualTo(190));
      expect(r.island.width, 0);
      expect(r.search.right, lessThanOrEqualTo(r.trail.left));
    });
  });

  group('поиск в шапке', () {
    late AppController controller;
    late DesktopChatSelectionStore chats;
    late DesktopChatSelectionStore rooms;
    late FocusNode focus;
    late List<DesktopSection> sections;

    setUp(() {
      controller = AppController();
      chats = DesktopChatSelectionStore();
      rooms = DesktopChatSelectionStore();
      focus = FocusNode();
      sections = <DesktopSection>[];
    });
    tearDown(() {
      chats.dispose();
      rooms.dispose();
      focus.dispose();
    });

    Widget field() => _host(
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 300, top: 9),
          child: SizedBox(
            width: 280,
            child: WindowSearchField(
              controller: controller,
              chatsSelection: chats,
              roomsSelection: rooms,
              selectSection: sections.add,
              focusNode: focus,
            ),
          ),
        ),
      ),
    );

    testWidgets('🔴 печатают прямо в шапке — отдельного окна нет', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(field());
      expect(
        find.text('Перейти к чатам'),
        findsNothing,
        reason: 'до нажатия выдачи нет',
      );

      await t.tap(find.byType(WindowSearchField));
      await t.pumpAndSettle();
      expect(focus.hasFocus, isTrue, reason: 'курсор — в поле шапки');
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'второго поля ввода, как было в окне ⌘K, нет',
      );

      final fieldRect = t.getRect(find.byType(WindowSearchField));
      final row = t.getRect(find.text('Перейти к чатам'));
      expect(
        row.top,
        greaterThan(fieldRect.bottom),
        reason: 'выдача выпадает ПОД поле',
      );
      expect(row.left, greaterThanOrEqualTo(fieldRect.left));

      await t.enterText(find.byType(TextField), 'ком');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.text('Перейти к комнатам'), findsOneWidget);
      expect(find.text('Перейти к чатам'), findsNothing);

      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(sections, [DesktopSection.rooms]);
      expect(focus.hasFocus, isFalse, reason: 'после выбора курсор уходит');
      expect(find.text('Перейти к комнатам'), findsNothing);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('Esc очищает и закрывает', (t) async {
      await t.pumpWidget(field());
      await t.tap(find.byType(WindowSearchField));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'ча');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(find.text('Перейти к чатам'), findsNothing);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('⌘K — это фокус того же поля', (t) async {
      await t.pumpWidget(field());
      focus.requestFocus();
      await t.pumpAndSettle();
      expect(find.text('Перейти к чатам'), findsOneWidget);
    });
  });

  test('подсказка сочетания говорит правду о клавиатуре', () {
    // На Windows ⌘ нет. Площадку в тесте не подменить (поле читает
    // `Platform`), поэтому сверяем исходник: подпись «⌘K» без ветки для
    // Windows увидел бы каждый, кто откроет там окно.
    final src = File(
      'lib/ui/desktop/app/desktop_spotlight.dart',
    ).readAsStringSync();
    expect(src.contains("Platform.isMacOS ? '⌘K' : 'Ctrl K'"), isTrue);
    expect(
      src.contains("'⌘K',"),
      isFalse,
      reason: 'голая подпись ⌘K без ветки площадки',
    );
  });

  test(
    '🔴 очередь одного вида: после песни — песня, после голосового — голосовое',
    () {
      final src = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(
        src.contains('if (wanted != null && att.kind != wanted) continue;'),
        isTrue,
      );
    },
  );
}
