// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Пачка 21.11.2026 (вечер): зелёная плашка звонка закреплена под верхними
// островами (не уезжает с лентой), чужие реакции — нейтральной плашкой,
// видео-заметка в ленте по макету 3b, реакции над листом стикера и по
// касанию на GIF. `SECRETLY_SHOTS=папка` — снимки.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/sticker_reaction_bar.dart';
import 'package:secretly_app/ui/chat/video_note_bubble.dart';
import 'package:secretly_app/ui/shared_audio_controls.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

String _src(String path) => File(path).readAsStringSync();

Future<void> _shot(WidgetTester t, String name) async {
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

void main() {
  group('плашка звонка', () {
    test('🔴 закреплена под верхними островами, а не строкой списка', () {
      final audio = _src('lib/ui/shared_audio_controls.dart');
      // 23.11.2026: музыка, звонок и звонок в комнате — одна пластина.
      expect(audio.contains("if (callMinimized) 'call',"), isTrue);
      expect(audio.contains("if (room != null) 'room_call',"), isTrue);
      expect(audio.contains('class SharedAudioCallBannerGate'), isFalse);
      expect(audio.contains('class PinnedRoomCallIsland'), isFalse);
      // Ни в Чатах, ни в Комнатах плашка звонка не строка ленты.
      for (final f in ['lib/ui/chats_screen.dart', 'lib/ui/groups_screen.dart']) {
        final s = _src(f);
        expect(s.contains('SharedAudioCallBannerGate'), isFalse, reason: f);
        expect(s.contains('SharedAudioTopIslands('), isTrue, reason: f);
        expect(s.contains('SharedAudioTopIslandsReserve('), isTrue, reason: f);
        expect(s.contains('roomCallVisible: roomCall != null'), isTrue, reason: f);
      }
      expect(sharedTopIslandsHeight(const []), 0);
      expect(
        sharedTopIslandsHeight(const ['call']),
        8 + kPinnedCallIslandRowHeight + 6,
      );
      expect(
        sharedTopIslandsHeight(const ['music', 'call', 'room_call']),
        8 +
            kSharedAudioIslandRowHeight +
            2 * kSharedAudioCallRowHeight +
            2 * 0.5 +
            6,
      );
    });
  });

  test('🔴 чужая реакция — нейтральная плашка, своя — цвет индикатора', () {
    final s = _src('lib/ui/chat_screen.dart');
    expect(
      s.contains('color: isOwn ? cs.primary : _othersReactionPlate(context),'),
      isTrue,
    );
    expect(s.contains('cs.primary.withValues(alpha: 0.68)'), isFalse);
  });

  group('видео-заметка в ленте (3b)', () {
    // 22.11.2026: макет 5a — в ленте 176 со скруглением 20 %.
    test('квадрат 176 со скруглением 35; на узком экране меньше', () {
      expect(kVideoNoteRadius, 35);
      expect(videoNoteSmallSide(390), 176);
      expect(videoNoteSmallSide(320), closeTo(150.4, 0.01));
      expect(videoNoteRadiusFor(176), closeTo(35.2, 0.01));
      // Раскрытый — почти во всю ширину, зазор 12 по краям.
      expect(videoNoteLargeSide(const Size(390, 844)), 366);
      final s = _src('lib/ui/chat/video_note_bubble.dart');
      // Без большого круга «играть» по центру маленького квадрата.
      expect(s.contains('glyph: ChatMediaGlyph.play,\n                              size: 52,'), isFalse);
      final chat = _src('lib/ui/chat_screen.dart');
      expect(chat.contains('const VideoNoteStripes(isMe: true),'), isTrue);
      expect(chat.contains('BorderRadius.circular(kVideoNoteRadius)'), isTrue);
    });

    testWidgets('подложка и ярлык рисуются (снимок)', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: _shotKey,
              child: ColoredBox(
                color: const Color(0xFF18222D),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final me in [false, true])
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              kVideoNoteRadius,
                            ),
                            child: SizedBox.square(
                              dimension: 160,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: VideoNoteStripes(isMe: me),
                                  ),
                                  const Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: VideoNoteDurationTag(
                                      label: '0:09',
                                      icon: Icons.play_arrow_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.text('0:09'), findsNWidgets(2));
      await _shot(t, 'video_note_3b');
    });
  });

  group('реакции над стикером', () {
    testWidgets('выбор отдаёт эмодзи и место; своя подсвечена; один раз',
        (t) async {
      final picks = <(String, Rect)>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: _shotKey,
                child: StickerReactionBar(
                  emojis: const ['❤️', '👍', '😂', '🔥', '😮', '😢', '🙏'],
                  selected: '👍',
                  emojiBuilder: (e) =>
                      Text(e, style: const TextStyle(fontSize: 24)),
                  onPick: (e, r) => picks.add((e, r)),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _shot(t, 'sticker_reaction_bar');
      await t.tap(find.text('🔥'));
      await t.tap(find.text('😂'));
      expect(picks, hasLength(1));
      expect(picks.single.$1, '🔥');
      expect(picks.single.$2.width, 44);
      final selected = t
          .widgetList<Semantics>(find.byType(Semantics))
          .where((w) => w.properties.selected == true)
          .map((w) => w.properties.label)
          .toList();
      expect(selected, ['👍']);
    });

    test('🔴 лист стикера — с реакциями; GIF по касанию — меню реакций', () {
      final s = _src('lib/ui/chat_screen.dart');
      final at = s.indexOf('Future<void> _showStickerPackSheet(');
      final body = s.substring(at, at + 6000);
      expect(body.contains('StickerReactionBar('), isTrue);
      expect(body.contains('_shouldShowOutgoingSendStateMenu(entry)'), isTrue);
      expect(body.contains('launchReactionFlight('), isTrue);
      expect(s.contains('reactions: entryReactions,\n'), isTrue);
      expect(s.contains(".toLowerCase().contains('gif')\n"), isTrue);
    });
  });

  test('🔴 выделение текста — в самом пузыре, «Копировать / Цитировать»', () {
    final s = _src('lib/ui/chat_screen.dart');
    final at = s.indexOf('Future<void> _openMessageTextSelection(');
    final body = s.substring(at, at + 2400);
    expect(body.contains('setState(() => _textSelectEventId = event.eventId);'), isTrue);
    expect(body.contains('selectWordAt(position)'), isTrue);
    final w = s.indexOf('Widget _inlineTextSelection(');
    final menu = s.substring(w, w + 4000);
    expect(menu.contains("label('Копировать'"), isTrue);
    expect(menu.contains("label('Цитировать'"), isTrue);
    expect(menu.contains('_startReply('), isTrue);
    // Пока выделяется текст, жесты — выделению, а не обёртке сообщения.
    expect(s.contains('passThrough: _textSelectEventId == event.eventId,'), isTrue);
    // 24.11.2026: касание снимает выделение и в режиме текста, долгое —
    // выбирает другое слово; двойного касания в режиме выделения нет.
    expect(s.contains('onTap: pass\n          ? widget.onTextTap'), isTrue);
    expect(s.contains('onTextTap: () => _toggleSelection(event.eventId)'), isTrue);
    expect(s.contains('onDoubleTap: pass || widget.selectionMode'), isTrue);
    expect(s.contains('widget.onLongPress(details.globalPosition);'), isTrue);
  });
}
