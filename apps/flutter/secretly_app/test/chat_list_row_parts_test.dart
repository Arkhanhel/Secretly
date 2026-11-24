// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Строка списка чатов по макету 3b (22.11.2026): подпись времени, счётчики,
// галочки, черновики, вспышка. `SECRETLY_SHOTS=папка` — снимок деталей.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/ui/chat/chat_list_row_parts.dart';

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

Widget _app(Widget child, {Brightness b = Brightness.dark}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ru'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(
    brightness: b,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7FE0),
      brightness: b,
    ),
  ),
  home: Scaffold(body: Center(child: child)),
);

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) =>
      Text('n=$n', textDirection: TextDirection.ltr);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    await _loadFonts();
  });

  group('подпись времени', () {
    final ru = AppLocalizationsRu();
    final en = AppLocalizationsEn();
    final now = DateTime(2026, 11, 22, 12, 41);
    int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch;

    test('сейчас · минуты · сегодня', () {
      expect(chatListTimeLabel(ago(const Duration(seconds: 20)), ru, now: now), 'сейчас');
      expect(chatListTimeLabel(ago(const Duration(minutes: 4)), ru, now: now), '4 мин');
      expect(chatListTimeLabel(ago(const Duration(minutes: 81)), ru, now: now), '11:20');
      expect(chatListTimeLabel(ago(const Duration(minutes: 4)), en, now: now), '4 min');
    });

    test('вчера · день недели · дата · прошлый год', () {
      expect(
        chatListTimeLabel(DateTime(2026, 11, 21, 23, 50).millisecondsSinceEpoch, ru, now: now),
        'вчера',
      );
      // 22.11.2026 — воскресенье; 18.11 — среда.
      expect(
        chatListTimeLabel(DateTime(2026, 11, 18, 9).millisecondsSinceEpoch, ru, now: now),
        'ср',
      );
      expect(
        chatListTimeLabel(DateTime(2026, 10, 12, 9).millisecondsSinceEpoch, ru, now: now),
        '12 окт',
      );
      expect(
        chatListTimeLabel(DateTime(2025, 10, 18, 9).millisecondsSinceEpoch, ru, now: now),
        '18.10.25',
      );
    });

    test('время из будущего — «сейчас», ноль — пусто', () {
      expect(
        chatListTimeLabel(now.add(const Duration(hours: 2)).millisecondsSinceEpoch, ru, now: now),
        'сейчас',
      );
      expect(chatListTimeLabel(0, ru, now: now), '');
    });

    test('🔴 перевод часов: вчерашнее — «вчера», а не день недели', () {
      // 29.03.2026 в Европе — 23-часовые сутки (весенний перевод).
      final after = DateTime(2026, 3, 30, 10);
      expect(
        chatListTimeLabel(DateTime(2026, 3, 29, 9).millisecondsSinceEpoch, ru, now: after),
        'вчера',
      );
      // Осень: 25-часовые сутки (25.10.2026).
      final autumn = DateTime(2026, 10, 26, 0, 30);
      expect(
        chatListTimeLabel(DateTime(2026, 10, 25, 23).millisecondsSinceEpoch, ru, now: autumn),
        'вчера',
      );
    });
  });

  testWidgets('счётчик: без звука — тональный, иначе градиент', (t) async {
    await t.pumpWidget(_app(const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatListUnreadBadge(key: ValueKey('on'), count: 3),
        ChatListUnreadBadge(key: ValueKey('off'), count: 120, muted: true),
      ],
    )));
    await t.pump(const Duration(milliseconds: 400));
    BoxDecoration deco(String k) => t
        .widget<AnimatedContainer>(find.descendant(
          of: find.byKey(ValueKey(k)),
          matching: find.byType(AnimatedContainer),
        ))
        .decoration! as BoxDecoration;
    expect(deco('on').gradient, isNotNull);
    expect(deco('off').gradient, isNull);
    expect(find.text('99+'), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('on'))).height, 20);
  });

  testWidgets('«4 мин»: часы тикают, пока строка на экране, и уходят с ней', (t) async {
    final ms = DateTime.now().subtract(const Duration(minutes: 4)).millisecondsSinceEpoch;
    await t.pumpWidget(_app(ChatListTime(ms: ms, highlight: true)));
    expect(find.text('4 мин'), findsOneWidget);
    await t.pump(const Duration(seconds: 31));
    expect(find.textContaining('мин'), findsOneWidget);
    // Снята с экрана — таймер остановлен (иначе тест упал бы с «висящим»).
    await t.pumpWidget(const SizedBox());
  });

  test('черновики: свежий текст и стирание', () {
    ChatListDrafts.set('peer1', 'Привет');
    expect(ChatListDrafts.drafts.value['peer1'], 'Привет');
    ChatListDrafts.set('peer1', '   ');
    expect(ChatListDrafts.drafts.value.containsKey('peer1'), isFalse);
  });

  testWidgets('вспышка не пересоздаёт строку', (t) async {
    final key = GlobalKey<_CounterState>();
    Widget row(int stamp, int unread) => _app(
      ChatListRowFlash(stamp: stamp, unread: unread, child: _Counter(key: key)),
    );
    await t.pumpWidget(row(1, 0));
    key.currentState!.n = 7;
    final state = key.currentState;
    await t.pumpWidget(row(2, 1));
    await t.pump(const Duration(milliseconds: 120));
    expect(key.currentState, same(state));
    await t.pump(const Duration(seconds: 1));
    expect(key.currentState, same(state));
  });

  testWidgets('снимок деталей строки', (t) async {
    t.view.physicalSize = const Size(390 * 2, 300 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    for (final b in Brightness.values) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await t.pumpWidget(_app(
        RepaintBoundary(
          key: _shotKey,
          child: Container(
            width: 390,
            color: b == Brightness.dark ? const Color(0xFF0F1620) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ChatListTime(ms: now - 4 * 60000, highlight: true),
                  const SizedBox(width: 12),
                  ChatListTime(ms: now - 26 * 3600000),
                  const SizedBox(width: 12),
                  const ChatListPinGlyph(),
                  const SizedBox(width: 12),
                  const ChatListUnreadBadge(count: 2),
                  const SizedBox(width: 8),
                  const ChatListUnreadBadge(count: 12, muted: true),
                  const SizedBox(width: 8),
                  const ChatListMissedCallBadge(count: 2),
                ]),
                const SizedBox(height: 14),
                const Row(children: [
                  ChatListTickGlyph(tick: ChatListTick.read),
                  Text('Скинул файл, глянь'),
                ]),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 300,
                  child: ChatListDraftLine(text: 'Слушай, а ты в субботу свободна?'),
                ),
              ],
            ),
          ),
        ),
        b: b,
      ));
      await t.pump(const Duration(milliseconds: 400));
      final dir = _shots;
      if (dir != null && dir.isNotEmpty) {
        await t.runAsync(() async {
          final rb = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await rb.toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/chat_row_parts_${b.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    }
    await t.pumpWidget(const SizedBox());
  });
}
