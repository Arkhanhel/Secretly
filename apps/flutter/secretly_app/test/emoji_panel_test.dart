// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Панель «Эмодзи, стикеры, GIF» на месте клавиатуры (макет 2a, 22.11.2026):
// девять эмодзи и пять стикеров в ряд, «тетрис» GIF, бегунок разделов,
// превью стикера удержанием и меню, «стереть», тон кожи запоминается,
// ☺ ⇄ ⌨ без прыжка. `SECRETLY_SHOTS=папка` — снимки с настоящего кода
// (iPhone и Android, тёмная и светлая, все три раздела).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/stickers/premium_sticker_packs.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_gifs.dart'
    show GifShimmerClock;
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_sources.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_stickers.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_widgets.dart';
import 'package:secretly_app/ui/chat/emoji_panel/gif_packing.dart';
import 'package:secretly_app/ui/chat/emoji_panel/premium_sticker_sheet.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';
import 'package:secretly_app/ui/widgets/secretly_sticker_widgets.dart'
    show SecretlyStickerAssetView;
import 'package:shared_preferences/shared_preferences.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

// ─── Подделки ───────────────────────────────────────────────────────────────

SecretlyStickerDescriptor _st(String pack, String id, {String emoji = '🙂', String? file}) =>
    file == null
        ? SecretlyStickerDescriptor.placeholder(
            packId: pack,
            packVersion: 1,
            stickerId: id,
            emojiHint: emoji,
            label: id,
          )
        : SecretlyStickerDescriptor.localFile(
            packId: pack,
            packVersion: 1,
            stickerId: id,
            localFilePath: file,
            format: SecretlyStickerFormat.png,
            animated: false,
            emojiHint: emoji,
            label: id,
            keywords: const <String>[],
          );

SecretlyStickerPack _pack(String id, String title, List<SecretlyStickerDescriptor> s) =>
    SecretlyStickerPack(
      id: id,
      version: 1,
      title: title,
      iconStickerId: s.first.stickerId,
      stickers: s,
      origin: SecretlyStickerPackOrigin.remote,
    );

class _FakeStickers extends EmojiPanelStickerSource {
  _FakeStickers({
    this.recent = const [],
    this.packs = const [],
    this.premium = const [],
    this.unlocked = false,
  });

  final List<SecretlyStickerDescriptor> recent;
  final List<SecretlyStickerPack> packs;
  final List<SecretlyStickerPack> premium;
  final bool unlocked;
  int premiumOpened = 0;
  final Set<String> favs = <String>{};

  @override
  List<SecretlyStickerPack> premiumPacks() => premium;

  @override
  bool get premiumUnlocked => unlocked;

  @override
  Future<void> openPremium(BuildContext context) async => premiumOpened++;

  @override
  String get profileId => 'ME';

  @override
  Future<List<SecretlyStickerDescriptor>> loadRecent() async => recent;

  @override
  Future<List<SecretlyStickerPack>> loadPacks({bool refresh = true}) async => packs;

  @override
  List<SecretlyStickerDescriptor> search(String query) => [
    for (final p in packs)
      for (final s in p.stickers)
        if (s.label.contains(query)) s,
  ];

  @override
  bool isFavorite(String stickerId) => favs.contains(stickerId);

  @override
  bool isPackBusy(SecretlyStickerPack pack) => false;

  @override
  Future<void> addFavorite(
    SecretlyStickerDescriptor sticker, {
    required String favoritesTitle,
  }) async => favs.add(sticker.stickerId);

  @override
  Future<void> removeFavorite(String stickerId) async => favs.remove(stickerId);

  @override
  Future<void> setCover({required String packId, required String stickerId}) async {}

  @override
  Future<void> deleteFromPack({required String packId, required String stickerId}) async {}

  @override
  Future<void> uninstallPack(SecretlyStickerPack pack) async {}

  @override
  Future<void> deleteUserPack(String packId) async {}

  @override
  Future<void> openPackEditor(
    BuildContext context,
    SecretlyStickerPack pack, {
    VoidCallback? onAddSticker,
  }) async {}
}

class _FakeGifs extends EmojiPanelGifSource {
  _FakeGifs({this.items = const [], this.images = const {}});

  final List<PanelGif> items;
  final Map<String, ImageProvider> images;

  @override
  bool get available => true;

  @override
  Future<PanelGifPage> fetch({String? query, String lang = 'en', int offset = 0}) async =>
      offset > 0
          ? PanelGifPage.empty
          : PanelGifPage(items: items, hasMore: false, returned: items.length);

  @override
  Future<List<PanelGif>> loadRecents() async => const [];

  @override
  Future<void> remember(PanelGif gif) async {}

  @override
  ImageProvider previewImage(PanelGif gif) =>
      images[gif.previewUrl] ?? super.previewImage(gif);
}

/// Превью GIF, которое никогда не догружается.
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage(this.id);

  final String id;

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImage>(this);

  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);

  @override
  bool operator ==(Object other) => other is _PendingImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Превью GIF, готовое сразу.
class _ReadyImage extends ImageProvider<_ReadyImage> {
  const _ReadyImage(this.image, this.id);

  final ui.Image image;
  final String id;

  @override
  Future<_ReadyImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ReadyImage>(this);

  @override
  ImageStreamCompleter loadImage(_ReadyImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
      );

  @override
  bool operator ==(Object other) => other is _ReadyImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Каталог как у экрана чата (`_emojiPickerCategories`): все разделы Noto.
List<EmojiPanelCategory> _categories() {
  final buckets = <String, List<String>>{for (final s in kNotoCategoryOrder) s: <String>[]};
  for (final e in kNotoCodepoints.keys) {
    if (kNotoSkinToneHidden.contains(e)) continue;
    (buckets[kNotoCategories[e] ?? 'symbols'] ??= <String>[]).add(e);
  }
  const ru = {
    'smileys_and_emotions': 'Смайлики и эмоции',
    'people': 'Люди и жесты',
    'animals_and_nature': 'Животные и природа',
    'food_and_drink': 'Еда и напитки',
    'travel_and_places': 'Путешествия и места',
    'activities_and_events': 'Активности',
    'objects': 'Предметы',
    'symbols': 'Символы',
    'flags': 'Флаги',
  };
  return [
    for (final s in kNotoCategoryOrder)
      if (buckets[s]!.isNotEmpty) (label: ru[s]!, emoji: buckets[s]!),
  ];
}

// ─── Стенд ──────────────────────────────────────────────────────────────────

class _Bench {
  _Bench({
    required this.controller,
    required this.text,
    required this.stickers,
    required this.gifs,
    this.categories,
  });

  final EmojiPanelController controller;
  final TextEditingController text;
  final _FakeStickers stickers;
  final _FakeGifs gifs;
  final List<EmojiPanelCategory>? categories;
  final List<SecretlyStickerDescriptor> sent = [];
  final List<String> sentGifs = [];
}

Widget _app(
  _Bench b, {
  Brightness brightness = Brightness.dark,
  bool ios = true,
  double height = 336,
  Key? panelKey,
}) {
  final dark = brightness == Brightness.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7FE0),
        brightness: brightness,
      ),
    ),
    // Снимок — вместе с оверлеем (превью стикера, окно тонов).
    builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: dark ? const Color(0xFF0F1620) : const Color(0xFFEAF0F6),
        body: Stack(
          children: [
            // Обои макета: цветные пятна, чтобы было видно стекло.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.8, .7),
                    radius: .9,
                    colors: [
                      const Color(0xFF2E9FE4).withValues(alpha: dark ? .32 : .28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.9, .45),
                    radius: .8,
                    colors: [
                      const Color(0xFF6A4FD0).withValues(alpha: dark ? .34 : .24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height,
              child: EmojiPanel(
                key: panelKey,
                controller: b.controller,
                textController: b.text,
                categories: b.categories ?? _categories(),
                stickerSource: b.stickers,
                gifSource: b.gifs,
                profileKey: 'ME',
                frosted: true,
                solidFill: dark ? const Color(0xFF242629) : Colors.white,
                ios: ios,
                onSendSticker: b.sent.add,
                onSendGif: b.sentGifs.add,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _frames(WidgetTester t, [int n = 40]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  // Цветные эмодзи для снимков: системный шрифт Apple (на Mac), иначе Noto,
  // который приложение возит для Windows.
  final apple = File('/System/Library/Fonts/Apple Color Emoji.ttc');
  final noto = apple.existsSync()
      ? apple
      : File('windows/fonts/NotoColorEmoji_WindowsCompatible.ttf');
  if ((_shots ?? '').isNotEmpty && noto.existsSync()) {
    final bytes = noto.readAsBytesSync();
    final loader = FontLoader('Noto Color Emoji')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void _view(WidgetTester t, {double h = 520}) {
  t.view.physicalSize = Size(390 * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

_Bench _bench(WidgetTester t, {List<EmojiPanelCategory>? categories, _FakeStickers? stickers, _FakeGifs? gifs}) {
  final c = EmojiPanelController(vsync: const TestVSync(), ios: true);
  addTearDown(c.dispose);
  final text = TextEditingController();
  addTearDown(text.dispose);
  return _Bench(
    controller: c,
    text: text,
    stickers: stickers ?? _FakeStickers(),
    gifs: gifs ?? _FakeGifs(),
    categories: categories,
  );
}

List<double> _rowTops(WidgetTester t, Finder f) {
  final tops = <double>[];
  for (final e in f.evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.hasSize || !box.attached) continue;
    tops.add(box.localToGlobal(Offset.zero).dy.roundToDouble());
  }
  return tops;
}

int _firstRowCount(List<double> tops) {
  if (tops.isEmpty) return 0;
  final first = tops.reduce(math.min);
  return tops.where((y) => (y - first).abs() < 1).length;
}

void main() {
  // Стикеры дизайнера встают на паузу вне экрана (VisibilityDetector):
  // в тестах — без задержки, чтобы не оставалось таймеров.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ─── Укладка GIF ──────────────────────────────────────────────────────────

  group('укладка GIF «тетрис»', () {
    const width = 374.0;
    const gap = 6.0;
    final colW = (width - 2 * gap) / 3;

    for (final seed in [1, 7, 42, 2026]) {
      test('без пересечений, в границах, широкие на две колонки (seed $seed)', () {
        final rnd = math.Random(seed);
        final aspects = [
          for (var i = 0; i < 90; i++)
            [0.56, 0.75, 1.0, 1.33, 1.5, 1.78, 2.0, 2.4][rnd.nextInt(8)] *
                (0.9 + rnd.nextDouble() * 0.2),
        ];
        final r = packGifTiles(aspects, width: width, gap: gap);
        expect(r.tiles.length, aspects.length);
        expect({for (final t in r.tiles) t.index}.length, aspects.length);
        for (final t in r.tiles) {
          expect(t.rect.left, greaterThanOrEqualTo(-0.01));
          expect(t.rect.right, lessThanOrEqualTo(width + 0.01));
          expect(t.rect.top, greaterThanOrEqualTo(0));
          expect(t.rect.height, greaterThan(20));
          // На две колонки — только широкие.
          if (t.span == 2) expect(aspects[t.index], greaterThanOrEqualTo(kGifWideAspect));
          expect(t.rect.width, closeTo(t.span * colW + (t.span - 1) * gap, .01));
        }
        // Широкие почти всегда на две колонки (одна — только чтобы выровнять
        // колонки, «другой стороной»).
        final wides = r.tiles.where((t) => aspects[t.index] >= kGifWideAspect).toList();
        expect(wides, isNotEmpty);
        expect(
          wides.where((t) => t.span == 2).length / wides.length,
          greaterThanOrEqualTo(.75),
        );
        for (var i = 0; i < r.tiles.length; i++) {
          for (var j = i + 1; j < r.tiles.length; j++) {
            final a = r.tiles[i].rect.deflate(.01);
            final b = r.tiles[j].rect.deflate(.01);
            expect(a.overlaps(b), isFalse, reason: 'плитки $i и $j');
          }
        }
        // Колонки выровнены: разница не больше одной высокой плитки.
        final tallest = r.tiles.map((t) => t.rect.height).reduce(math.max);
        final hs = r.columnHeights;
        expect(hs.reduce(math.max) - hs.reduce(math.min), lessThanOrEqualTo(tallest + gap));
        // Дыр мало: заполнено больше 90 % площади до нижней кромки самой
        // короткой колонки.
        final floor = hs.reduce(math.min);
        var filled = 0.0;
        for (final t in r.tiles) {
          final top = t.rect.top;
          final bottom = math.min(t.rect.bottom, floor);
          if (bottom > top) filled += (bottom - top) * t.rect.width;
        }
        expect(filled / (floor * width), greaterThan(.9));
      });
    }

    test('порядок выдачи сдвигается не дальше окна', () {
      final aspects = [1.0, 0.8, 1.9, 1.2, 0.7, 2.0, 1.1, 1.0, 1.8, 0.9];
      final r = packGifTiles(aspects, width: width, gap: gap, lookahead: 3);
      for (var pos = 0; pos < r.tiles.length; pos++) {
        expect((r.tiles[pos].index - pos).abs(), lessThanOrEqualTo(3));
      }
    });

    test('пусто — пусто', () {
      expect(packGifTiles(const [], width: width).tiles, isEmpty);
    });
  });

  // ─── Правка поля ──────────────────────────────────────────────────────────

  test('вставка на место курсора и «стереть» по графемам', () {
    final c = TextEditingController(text: 'ab');
    c.selection = const TextSelection.collapsed(offset: 1);
    emojiPanelInsertText(c, '😀');
    expect(c.text, 'a😀b');
    expect(c.selection.baseOffset, 1 + '😀'.length);
    c.selection = TextSelection.collapsed(offset: c.text.length);
    emojiPanelInsertText(c, '👍🏽');
    expect(c.text, 'a😀b👍🏽');
    emojiPanelBackspace(c);
    expect(c.text, 'a😀b');
    c.selection = const TextSelection.collapsed(offset: 3);
    emojiPanelBackspace(c);
    expect(c.text, 'ab');
    c.dispose();
  });

  // ─── Сетки ────────────────────────────────────────────────────────────────

  testWidgets('девять эмодзи в ряд при ширине 390', (t) async {
    _view(t);
    final b = _bench(t);
    await t.pumpWidget(_app(b));
    await _frames(t, 10);
    final tops = _rowTops(t, find.byType(PanelEmojiGlyph));
    expect(_firstRowCount(tops), 9);
    // Клетки квадратные: (390 − 16) / 9.
    final size = t.getSize(find.byType(PanelEmojiGlyph).first);
    expect(size.width, closeTo((390 - 16) / 9, .01));
    expect(size.height, closeTo(size.width, .01));
  });

  testWidgets('пять стикеров в ряд при ширине 390', (t) async {
    _view(t);
    final stickers = _FakeStickers(
      packs: [
        _pack('user:OTHER:cats', 'Котики', [for (var i = 0; i < 12; i++) _st('user:OTHER:cats', 'c$i')]),
      ],
    );
    final b = _bench(t, stickers: stickers);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    final cells = find.byWidgetPredicate(
      (w) => w is PanelStickerThumb && w.size > 40,
    );
    expect(_firstRowCount(_rowTops(t, cells)), 5);
  });

  testWidgets('бегунок разделов переезжает', (t) async {
    _view(t);
    final b = _bench(t);
    await t.pumpWidget(_app(b));
    await _frames(t, 5);
    final ind = find.byKey(const ValueKey('emoji-panel:segment-indicator'));
    final x0 = t.getTopLeft(ind).dx;
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    final x1 = t.getTopLeft(ind).dx;
    expect(b.controller.tab.value, 1);
    expect(x1, greaterThan(x0 + 60));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
    await _frames(t, 40);
    expect(t.getTopLeft(ind).dx, greaterThan(x1 + 60));
    // Страницы уехали следом.
    expect(find.byKey(const ValueKey('emoji-panel:gif-scroll')), findsOneWidget);
  });

  testWidgets('поиск: лупа выдвигает поле на место рейки, «назад» стирает и прячет', (t) async {
    _view(t);
    final b = _bench(t);
    await t.pumpWidget(_app(b));
    await _frames(t, 5);
    final field = find.byKey(const ValueKey('emoji-panel:emoji-search'));
    expect(field, findsNothing);
    final rail = find.byKey(const ValueKey('rail:e'));
    double railOpacity() => t
        .widget<Opacity>(find.ancestor(of: rail, matching: find.byType(Opacity)).first)
        .opacity;
    expect(railOpacity(), 1);
    final pill0 = t.getSize(find.byKey(const ValueKey('emoji-panel:search'))).width;
    await t.tap(find.byKey(const ValueKey('emoji-panel:search')));
    await _frames(t, 40);
    expect(field, findsOneWidget);
    expect(railOpacity(), 0);
    expect(
      t.getSize(find.byKey(const ValueKey('emoji-panel:search'))).width,
      greaterThan(pill0 + 200),
    );
    await t.enterText(field, 'abc');
    await _frames(t, 5);
    await t.tap(find.byKey(const ValueKey('emoji-panel:search-close')));
    await _frames(t, 30);
    expect(field, findsNothing);
    expect(railOpacity(), 1);
    // Сменили раздел — поле того раздела, запрос прежнего стёрт.
    await t.tap(find.byKey(const ValueKey('emoji-panel:search')));
    await _frames(t, 40);
    await t.enterText(field, 'xyz');
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
    await _frames(t, 40);
    expect(find.byKey(const ValueKey('emoji-panel:gif-search')), findsNothing);
  });

  testWidgets('сетка до самого низа: островки поверх, под ними пустое место', (t) async {
    _view(t);
    final b = _bench(t);
    await t.pumpWidget(_app(b));
    await _frames(t, 5);
    final pages = t.getRect(find.byKey(const ValueKey('emoji-panel:pages')));
    final panel = t.getRect(find.byKey(const ValueKey('emoji-panel:surface')));
    expect(pages.bottom, panel.bottom);
    final seg = t.getRect(find.byKey(const ValueKey('emoji-panel:segment')));
    expect(seg.bottom, lessThan(panel.bottom));
    expect(seg.width, lessThanOrEqualTo(210));
    expect(seg.height, 38);
  });

  testWidgets('удержание стикера: превью, ведём пальцем, отпустили — меню', (t) async {
    _view(t);
    final stickers = _FakeStickers(
      packs: [
        _pack('user:OTHER:cats', 'Котики', [
          for (var i = 0; i < 10; i++) _st('user:OTHER:cats', 'c$i', emoji: ['😺', '😸', '😹', '😻', '😼'][i % 5]),
        ]),
      ],
    );
    final b = _bench(t, stickers: stickers);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    final cells = find.byWidgetPredicate((w) => w is PanelStickerThumb && w.size > 40);
    final first = t.getCenter(cells.at(0));
    final third = t.getCenter(cells.at(2));
    final g = await t.startGesture(first);
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('stickers:preview:backdrop')), findsOneWidget);
    expect(find.text('Котики'), findsWidgets);
    // Ведём по сетке — превью меняется.
    await g.moveTo(third);
    await _frames(t, 10);
    final preview = t.widget<SecretlyStickerAssetView>(
      find.byWidgetPredicate((w) => w is SecretlyStickerAssetView && w.size == 180),
    );
    expect(preview.sticker.stickerId, 'c2');
    await g.up();
    await _frames(t, 30);
    final send = find.byKey(const ValueKey('stickers:preview:send'));
    expect(send, findsOneWidget);
    expect(find.byKey(const ValueKey('stickers:preview:favorite')), findsOneWidget);
    // Беззвучной отправки в приложении нет — пункта нет.
    expect(find.byKey(const ValueKey('stickers:preview:silent')), findsNothing);
    await t.tap(send);
    await _frames(t, 10);
    expect(b.sent.single.stickerId, 'c2');
    expect(find.byKey(const ValueKey('stickers:preview:backdrop')), findsNothing);
  });

  testWidgets('тап по стикеру — отправка', (t) async {
    _view(t);
    final stickers = _FakeStickers(
      packs: [
        _pack('user:OTHER:cats', 'Котики', [for (var i = 0; i < 6; i++) _st('user:OTHER:cats', 'c$i')]),
      ],
    );
    final b = _bench(t, stickers: stickers);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    await t.tap(find.byWidgetPredicate((w) => w is PanelStickerThumb && w.size > 40).at(1));
    await _frames(t, 10);
    expect(b.sent.single.stickerId, 'c1');
  });

  testWidgets('🔴 премиум-наборы без Premium: значки со звёздочкой у лупы, '
      'касание — окно набора с покупкой, в сетке их нет', (t) async {
    _view(t);
    final stickers = _FakeStickers(
      packs: [
        _pack('user:OTHER:cats', 'Котики', [for (var i = 0; i < 3; i++) _st('user:OTHER:cats', 'c$i')]),
      ],
      premium: premiumStickerPacks,
    );
    final b = _bench(t, stickers: stickers);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    final safe = find.byKey(const ValueKey('emoji-panel:premium-pin:$kPremiumSafePackId'));
    final pixel = find.byKey(const ValueKey('emoji-panel:premium-pin:$kPremiumPixelPackId'));
    expect(safe, findsOneWidget);
    expect(pixel, findsOneWidget);
    expect(find.byType(PremiumStickerStar), findsNWidgets(2));
    // Значки — слева от лупы, правее рейки.
    final search = t.getRect(find.byKey(const ValueKey('emoji-panel:search')));
    expect(t.getRect(pixel).right, lessThanOrEqualTo(search.left + 1));
    expect(t.getRect(safe).right, lessThanOrEqualTo(t.getRect(pixel).left + 1));
    // В сетке премиум-стикеров нет.
    expect(find.text('Секретный сейф'), findsNothing);
    await t.tap(safe);
    await _frames(t, 30);
    expect(find.byKey(const ValueKey('premium-sticker-sheet:$kPremiumSafePackId')), findsOneWidget);
    expect(find.text('Секретный сейф'), findsOneWidget);
    expect(find.text('Открыть с Premium'), findsOneWidget);
    // Касание стикера в окне ничего не отправляет.
    await t.tap(find.byKey(const ValueKey('premium-sticker-sheet:cell:crown')));
    await _frames(t, 5);
    expect(b.sent, isEmpty);
    await t.tap(find.byKey(const ValueKey('premium-sticker-sheet:unlock')));
    await _frames(t, 30);
    expect(stickers.premiumOpened, 1);
    expect(find.byKey(const ValueKey('premium-sticker-sheet:$kPremiumSafePackId')), findsNothing);
  });

  testWidgets('премиум-наборы с Premium: разделы в конце сетки, значок ведёт '
      'к разделу и подсвечивается, стикер отправляется', (t) async {
    _view(t);
    final stickers = _FakeStickers(
      packs: [
        _pack('user:OTHER:cats', 'Котики', [for (var i = 0; i < 3; i++) _st('user:OTHER:cats', 'c$i')]),
      ],
      premium: premiumStickerPacks,
      unlocked: true,
    );
    final b = _bench(t, stickers: stickers);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
    await _frames(t, 40);
    await t.tap(find.byKey(const ValueKey('emoji-panel:premium-pin:$kPremiumPixelPackId')));
    await _frames(t, 60);
    expect(find.byType(PremiumStickerPackSheet), findsNothing);
    expect(find.text('Pixel'), findsWidgets);
    // Прокручиваемая рейка не подсвечивает свой последний значок.
    final pin = t.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('emoji-panel:premium-pin:$kPremiumPixelPackId')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((pin.decoration as BoxDecoration?)?.color, isNot(Colors.transparent));
    final cells = find.byWidgetPredicate(
      (w) => w is PanelStickerThumb && w.size > 40 && w.sticker.packId == kPremiumPixelPackId,
    );
    expect(cells, findsWidgets);
    await t.tap(cells.first);
    await _frames(t, 10);
    expect(b.sent.single.packId, kPremiumPixelPackId);
  });

  testWidgets('«стереть» стирает из поля и гаснет на пустом', (t) async {
    _view(t);
    final b = _bench(t, categories: const [(label: 'Смайлики', emoji: ['😀', '😂', '❤️'])]);
    await t.pumpWidget(_app(b));
    await _frames(t, 5);
    final bs = find.byKey(const ValueKey('emoji-panel:backspace'));
    double opacity() => t
        .widget<AnimatedOpacity>(find.ancestor(of: bs, matching: find.byType(AnimatedOpacity)).first)
        .opacity;
    expect(opacity(), lessThan(.5));
    await t.tap(find.byType(PanelEmojiGlyph).at(1));
    await _frames(t, 5);
    await t.tap(find.byType(PanelEmojiGlyph).at(0));
    await _frames(t, 30);
    expect(b.text.text, '😂😀');
    expect(opacity(), 1);
    await t.tap(bs);
    await _frames(t, 5);
    expect(b.text.text, '😂');
    await t.tap(bs);
    await _frames(t, 30);
    expect(b.text.text, '');
    expect(opacity(), lessThan(.5));
  });

  testWidgets('тон кожи: удержание, выбор, запоминается', (t) async {
    _view(t);
    final b = _bench(t, categories: const [(label: 'Люди', emoji: ['👍', '👋', '😀'])]);
    await t.pumpWidget(_app(b));
    await _frames(t, 10);
    final thumb = find.byType(PanelEmojiGlyph).at(0);
    await t.longPress(thumb);
    await _frames(t, 30);
    expect(find.byKey(const ValueKey('emoji-panel:tone-popup')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('emoji-panel:tone:👍🏽')));
    await _frames(t, 30);
    expect(b.text.text, '👍🏽');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mobile_emoji_panel_tones_v1:ME');
    expect(jsonDecode(saved!), {'👍': '👍🏽'});
    // Новая панель (новый показ): клетка уже с выбранным тоном, тап вставляет
    // его без окна.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(b, panelKey: const ValueKey('again')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _frames(t, 10);
    // Клетка раздела и «Недавние» — обе с выбранным тоном.
    expect(
      find.byWidgetPredicate((w) => w is PanelEmojiGlyph && w.emoji == '👍🏽'),
      findsNWidgets(2),
    );
    b.text.clear();
    await t.tap(find.byType(PanelEmojiGlyph).at(0));
    await _frames(t, 30);
    expect(b.text.text, '👍🏽');
  });

  testWidgets('недавние эмодзи обновляются при закрытии, а не под пальцем', (t) async {
    _view(t);
    final b = _bench(t, categories: const [(label: 'Смайлики', emoji: ['😀', '😂', '❤️'])]);
    await t.pumpWidget(_app(b));
    await _frames(t, 5);
    await t.tap(find.byType(PanelEmojiGlyph).at(2));
    await _frames(t, 30);
    // Под пальцем раздел «Недавние» не появился.
    expect(find.text('НЕДАВНИЕ'), findsNothing);
    b.controller.flushRecents();
    await _frames(t, 5);
    expect(find.text('НЕДАВНИЕ'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('mobile_emoji_panel_recents_v1:ME'), ['❤️']);
  });

  testWidgets('GIF: плитки ложатся тетрисом, тап — отправка', (t) async {
    _view(t);
    final gifs = _FakeGifs(
      items: [
        for (var i = 0; i < 12; i++)
          PanelGif(
            previewUrl: 'p$i',
            fullUrl: 'f$i',
            aspect: [1.0, 1.78, .75, 1.3, 2.0, .9][i % 6],
          ),
      ],
    );
    final b = _bench(t, gifs: gifs);
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
    await _frames(t, 40);
    final tiles = find.byWidgetPredicate((w) => w is Positioned && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('f'));
    expect(tiles, findsWidgets);
    // Широкая (1,78) — на две колонки.
    final wide = t.getSize(find.byKey(const ValueKey('f1')));
    final narrow = t.getSize(find.byKey(const ValueKey('f0')));
    expect(wide.width, greaterThan(narrow.width * 1.9));
    await t.tap(find.byKey(const ValueKey('f0')));
    await _frames(t, 10);
    expect(b.sentGifs, ['f0']);
  });

  // С-8 (22.11.2026): мерцание крутится, только пока есть незагруженные плитки.
  List<PanelGif> gifItems() => [
    for (var i = 0; i < 6; i++)
      PanelGif(previewUrl: 'p$i', fullUrl: 'f$i', aspect: 1.0),
  ];

  testWidgets('С-8: GIF ещё грузятся — мерцание тикает', (t) async {
    _view(t);
    GifShimmerClock.debugTicking = 0;
    final b = _bench(
      t,
      gifs: _FakeGifs(
        items: gifItems(),
        images: {for (var i = 0; i < 6; i++) 'p$i': _PendingImage('p$i')},
      ),
    );
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
    await _frames(t, 30);
    expect(GifShimmerClock.debugTicking, 1);
    await t.pumpWidget(const SizedBox());
    expect(GifShimmerClock.debugTicking, 0);
  });

  testWidgets('С-8: все GIF загрузились — мерцание стоит, кадров нет', (t) async {
    _view(t);
    GifShimmerClock.debugTicking = 0;
    final img = (await t.runAsync(() => createTestImage(width: 4, height: 4)))!;
    addTearDown(img.dispose);
    final b = _bench(
      t,
      gifs: _FakeGifs(
        items: gifItems(),
        images: {for (var i = 0; i < 6; i++) 'p$i': _ReadyImage(img, 'p$i')},
      ),
    );
    await t.pumpWidget(_app(b));
    await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
    await _frames(t, 40);
    expect(find.byKey(const ValueKey('f0')), findsOneWidget);
    expect(GifShimmerClock.debugTicking, 0);
  });

  // ─── Клавиатура ⇄ панель ──────────────────────────────────────────────────

  testWidgets('☺ при поднятой клавиатуре: панель её высоты, без анимации; ⌨ — панель уходит, когда клавиатура встала', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = EmojiPanelController(vsync: const TestVSync(), field: focus, ios: true);
    addTearDown(c.dispose);
    // Клавиатура 336 стоит.
    t.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    t.binding.handleMetricsChanged();
    await t.pump();
    expect(c.keyboard.value, 336);
    c.open();
    expect(c.isOpen.value, isTrue);
    expect(c.height.value, 336);
    expect(c.inset.value, 336);
    // Клавиатура уезжает — место внизу то же.
    for (final kb in [300.0, 200.0, 80.0, 0.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: kb * 3);
      t.binding.handleMetricsChanged();
      await t.pump(const Duration(milliseconds: 16));
      expect(math.max(kb, c.inset.value), 336);
    }
    // ⌨: панель держит место, пока клавиатура не встала.
    c.showKeyboard();
    expect(c.isOpen.value, isFalse);
    for (final kb in [120.0, 260.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: kb * 3);
      t.binding.handleMetricsChanged();
      await t.pump(const Duration(milliseconds: 16));
      expect(math.max(kb, c.inset.value), 336);
    }
    t.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    t.binding.handleMetricsChanged();
    await t.pump(const Duration(milliseconds: 16));
    expect(c.height.value, 0);
    expect(c.inset.value, 0);
    t.view.resetViewInsets();
  });

  // С-16 (22.11.2026): клавиатура ниже панели — раньше 0,7 с висела полоса.
  testWidgets('С-16: клавиатура ниже раскрытой панели — передача кончается, когда клавиатура встала; панель доезжает плавно', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = EmojiPanelController(vsync: const TestVSync(), field: focus, ios: true);
    addTearDown(c.dispose);
    c.open();
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    c.toggleExpanded();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    final panel = c.height.value;
    expect(panel, greaterThan(400));
    c.showKeyboard();
    // Клавиатура поднимается до 260 — панель держит место.
    for (final kb in [100.0, 180.0, 240.0, 260.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: kb * 3);
      t.binding.handleMetricsChanged();
      await t.pump(const Duration(milliseconds: 16));
      expect(c.height.value, closeTo(panel, .5));
    }
    // Клавиатура встала (метрик больше нет) — через ~4 кадра передача
    // кончается, а не через 0,7 с.
    await t.pump(const Duration(milliseconds: 80));
    await t.pump(const Duration(milliseconds: 100));
    final mid = c.height.value;
    expect(mid, lessThan(panel - 1));
    expect(mid, greaterThan(260));
    // Панель не проваливается ниже клавиатуры: поле опускается до неё.
    expect(math.max(260.0, c.inset.value), greaterThanOrEqualTo(260));
    await t.pump(const Duration(milliseconds: 200));
    expect(c.height.value, 0);
    expect(c.inset.value, 0);
    t.view.resetViewInsets();
  });

  testWidgets('С-16: клавиатура дошла до прошлой высоты — передача сразу, панель доезжает до неё', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = EmojiPanelController(vsync: const TestVSync(), field: focus, ios: true);
    addTearDown(c.dispose);
    // Клавиатуру 300 уже видели.
    t.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    t.binding.handleMetricsChanged();
    await t.pump();
    c.open();
    t.view.viewInsets = FakeViewPadding.zero;
    t.binding.handleMetricsChanged();
    await t.pump();
    c.toggleExpanded();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    final panel = c.height.value;
    expect(panel, greaterThan(400));
    c.showKeyboard();
    t.view.viewInsets = const FakeViewPadding(bottom: 200 * 3);
    t.binding.handleMetricsChanged();
    await t.pump(const Duration(milliseconds: 16));
    expect(c.height.value, closeTo(panel, .5));
    t.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    t.binding.handleMetricsChanged();
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 60));
    expect(c.height.value, inExclusiveRange(300, panel));
    await t.pump(const Duration(milliseconds: 250));
    expect(c.height.value, 0);
    t.view.resetViewInsets();
  });

  testWidgets('без клавиатуры панель выезжает до высоты клавиатуры и закрывается', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = EmojiPanelController(vsync: const TestVSync(), ios: true);
    addTearDown(c.dispose);
    c.open();
    final target = c.baseHeight;
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(c.height.value, inExclusiveRange(0, target + 40));
    await t.pump(const Duration(milliseconds: 500));
    expect(c.height.value, closeTo(target, .5));
    c.toggleExpanded();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(c.height.value, closeTo(c.expandedHeight, .5));
    expect(c.expandedHeight, greaterThan(target));
    c.close();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(c.height.value, 0);
    expect(c.isOpen.value, isFalse);
  });

  // ─── Снимки ───────────────────────────────────────────────────────────────

  final shots = _shots;
  if (shots != null && shots.isNotEmpty) {
    for (final ios in [true, false]) {
      for (final br in Brightness.values) {
        testWidgets('снимки: ${ios ? 'ios' : 'android'} ${br.name}', (t) async {
          _view(t, h: 520);
          debugDefaultTargetPlatformOverride = ios ? TargetPlatform.iOS : TargetPlatform.android;
          final assets = await t.runAsync(_makeShotAssets);
          final stickers = _FakeStickers(
            recent: assets!.recent,
            packs: assets.packs,
          );
          final gifs = _FakeGifs(items: assets.gifs, images: assets.gifImages);
          final b = _bench(t, stickers: stickers, gifs: gifs);
          SharedPreferences.setMockInitialValues(<String, Object>{
            'mobile_emoji_panel_recents_v1:ME': ['😂', '❤️', '👍', '🔥', '🥹', '😍', '🙏', '😭', '✨', '🎉', '😅', '👀', '🤔', '😎', '🥳', '💯'],
          });
          b.text.text = 'Привет 😊';
          await t.pumpWidget(_app(b, brightness: br, ios: ios, height: ios ? 336 : 324));
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
          // Картинки — заранее, вне подделанного времени (иначе загрузка,
          // начатая сеткой, ждала бы его вечно).
          await _precache(t, assets.files);
          await t.runAsync(() async {
            for (final img in assets.gifImages.values) {
              await precacheImage(img, _shotKey.currentContext!);
            }
          });
          await _frames(t, 30);
          final tag = '${ios ? 'ios' : 'android'}_${br.name}';
          await _shot(t, 'emoji_panel_${tag}_1_emoji');

          // Поиск выдвигается из лупы на место рейки.
          await t.tap(find.byKey(const ValueKey('emoji-panel:search')));
          await _frames(t, 40);
          await _shot(t, 'emoji_panel_${tag}_1b_search');
          await t.tap(find.byKey(const ValueKey('emoji-panel:search-close')));
          await _frames(t, 30);

          await t.tap(find.byKey(const ValueKey('emoji-panel:tab:1')));
          await _frames(t, 45);
          await _shot(t, 'emoji_panel_${tag}_2_stickers');

          // Превью стикера (удержание, отпустили — меню).
          final cells = find.byWidgetPredicate((w) => w is PanelStickerThumb && w.size > 40);
          final g = await t.startGesture(t.getCenter(cells.at(3)));
          await t.pump(kLongPressTimeout + const Duration(milliseconds: 60));
          await g.up();
          await _frames(t, 30);
          await _shot(t, 'emoji_panel_${tag}_2b_sticker_preview');
          await t.tapAt(const Offset(20, 20));
          await _frames(t, 10);

          await t.tap(find.byKey(const ValueKey('emoji-panel:tab:2')));
          await _frames(t, 60);
          await _shot(t, 'emoji_panel_${tag}_3_gif');
          await t.pumpWidget(const SizedBox());
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }
}

Future<void> _precache(WidgetTester t, List<File> files) async {
  final ctx = _shotKey.currentContext!;
  await t.runAsync(() async {
    for (final f in files) {
      await precacheImage(FileImage(f), ctx);
      const cell = (390 - 16 - 8) / 5;
      await precacheImage(ResizeImage(FileImage(f), width: ((cell - 12) * 2).round()), ctx);
      await precacheImage(ResizeImage(FileImage(f), width: 56), ctx);
    }
  });
}

class _ShotAssets {
  _ShotAssets(this.recent, this.packs, this.gifs, this.gifImages, this.files);

  final List<SecretlyStickerDescriptor> recent;
  final List<SecretlyStickerPack> packs;
  final List<PanelGif> gifs;
  final Map<String, ImageProvider> gifImages;
  final List<File> files;
}

/// Стикеры снимков — эмодзи Noto с белой обводкой, отрисованные в PNG (как
/// настоящие стикеры наборов); GIF — цветные плитки разных пропорций.
Future<_ShotAssets> _makeShotAssets() async {
  final dir = Directory.systemTemp.createTempSync('emoji_panel_shots');
  final files = <File>[];
  Future<File> sticker(String emoji, String name) async {
    const s = 256.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    TextPainter tp(Paint? fg) => TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: 190,
          height: 1,
          fontFamilyFallback: kPanelEmojiFontFallback,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final p = tp(null);
    final o = Offset((s - p.width) / 2, (s - p.height) / 2);
    // Белая обводка — восемь сдвигов под самим глифом.
    final outline = Paint()
      ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    for (var a = 0; a < 16; a++) {
      final d = Offset(math.cos(a * math.pi / 8), math.sin(a * math.pi / 8)) * 7;
      canvas.saveLayer(null, outline);
      p.paint(canvas, o + d);
      canvas.restore();
    }
    p.paint(canvas, o);
    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('${dir.path}/$name.png')..writeAsBytesSync(bytes!.buffer.asUint8List());
    files.add(f);
    return f;
  }

  Future<List<SecretlyStickerDescriptor>> pack(String id, List<String> emoji) async => [
    for (var i = 0; i < emoji.length; i++)
      _st(id, '$id-$i', emoji: emoji[i], file: (await sticker(emoji[i], '${id.replaceAll(':', '_')}_$i')).path),
  ];

  final cats = await pack('user:OTHER:cats', ['😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾', '🐈']);
  final morning = await pack('user:OTHER:morning', ['☕', '🥐', '🌅', '🛏️', '⏰', '🥱', '🍳', '🧃']);
  final forest = await pack('user:OTHER:forest', ['🦊', '🦔', '🐻', '🦉', '🐿️', '🦌', '🍄', '🌲']);
  final space = await pack('user:OTHER:space', ['🚀', '🪐', '👽', '🌙', '⭐', '🛸', '🌌', '☄️']);
  final packs = [
    _pack('user:OTHER:cats', 'Котики', cats),
    _pack('user:OTHER:morning', 'Доброе утро', morning),
    _pack('user:OTHER:forest', 'Лесные', forest),
    _pack('user:OTHER:space', 'Космос', space),
  ];
  final recent = [cats[2], forest[1], space[0], morning[0], cats[3], forest[0]];

  // GIF: градиентные плитки (в макете GIF — тоже цветные плитки).
  final gifs = <PanelGif>[];
  final images = <String, ImageProvider>{};
  const aspects = [1.0, 1.78, 0.75, 1.33, 2.0, 0.9, 1.25, 0.8, 1.9, 1.1, 0.7, 1.5];
  for (var i = 0; i < aspects.length; i++) {
    final w = 240.0;
    final h = (w / aspects[i]).roundToDouble();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final hue = (i * 37 + 200) % 360.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, h),
          [
            HSLColor.fromAHSL(1, hue, .55, .55).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, .5, .32).toColor(),
          ],
        ),
    );
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('${dir.path}/gif_$i.png')..writeAsBytesSync(bytes!.buffer.asUint8List());
    gifs.add(PanelGif(previewUrl: 'shot://$i', fullUrl: 'full://$i', aspect: aspects[i]));
    images['shot://$i'] = FileImage(f);
  }
  return _ShotAssets(recent, packs, gifs, images, files);
}
