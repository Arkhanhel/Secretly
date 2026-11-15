// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 15.11.2026, ТЗ панели стикеров по образцу владельца: одна лента разделов,
// «Создать» — первая клетка «Недавних», ⚙ у своего набора, ⋯ у чужого,
// окно набора с «+» и «Готово», ни одно удаление без вопроса.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/widgets/secretly_sticker_widgets.dart';

const _own = 'user:ME:mine';
const _foreign = 'user:OTHER:theirs';

SecretlyStickerDescriptor _s(String pack, String id) =>
    SecretlyStickerDescriptor.placeholder(
      packId: pack,
      packVersion: 1,
      stickerId: id,
      emojiHint: '🙂',
      label: id,
      keywords: const <String>[],
    );

SecretlyStickerPack _pack(String id, String title, List<String> stickers) =>
    SecretlyStickerPack(
      id: id,
      version: 1,
      title: title,
      description: '',
      iconStickerId: stickers.first,
      iconEmojiHint: '🙂',
      installed: true,
      origin: SecretlyStickerPackOrigin.remote,
      stickers: [for (final s in stickers) _s(id, s)],
    );

class _FakeController extends AppController {
  _FakeController(this.packs);

  final List<SecretlyStickerPack> packs;
  final List<String> deletedStickers = <String>[];
  final List<String> deletedPacks = <String>[];

  @override
  String get profileId => 'ME';

  @override
  bool get stickerPackAccessUiEnabled => false;

  @override
  Future<List<SecretlyStickerPack>> loadStickerPickerPacks({
    bool refresh = true,
  }) async =>
      packs;

  @override
  bool isStickerPackBusy({required String packId, required int packVersion}) =>
      false;

  @override
  bool isStickerFavorite(String stickerId) => false;

  @override
  Future<void> deleteUserStickerFromPack({
    required String packId,
    required String stickerId,
  }) async {
    deletedStickers.add('$packId/$stickerId');
  }

  @override
  Future<void> deleteUserStickerPack(String packId) async {
    deletedPacks.add(packId);
  }
}

void main() {
  late _FakeController controller;
  String? addRequestedFor;
  var createTapped = false;

  setUp(() {
    final packs = [
      _pack(_own, 'Мишка', ['a', 'b']),
      _pack(_foreign, 'Чужой', ['c']),
    ];
    SecretlyStickerCatalog.applyRemoteCatalog(packs);
    controller = _FakeController(packs);
    addRequestedFor = null;
    createTapped = false;
  });

  tearDown(SecretlyStickerCatalog.clearRemoteCatalog);

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Scaffold(
          body: SecretlyStickerPickerTab(
            controller: controller,
            recentStickers: [_s(_own, 'a')],
            onStickerSelected: (_) {},
            onCreateSticker: () => createTapped = true,
            onAddStickerToPack: (id) => addRequestedFor = id,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('«Создать» — первая клетка «Недавних», а не плитка в углу', (
    tester,
  ) async {
    await pumpPanel(tester);
    final create = find.byKey(const ValueKey('stickers:create'));
    expect(create, findsOneWidget);
    final recentHeader = find.text('Недавние стикеры');
    expect(recentHeader, findsOneWidget);
    final createTop = tester.getTopLeft(create);
    final headerBottom = tester.getBottomLeft(recentHeader);
    expect(createTop.dy, greaterThan(headerBottom.dy - 1));
    expect(createTop.dy - headerBottom.dy, lessThan(40),
        reason: 'сразу под заголовком «Недавние»');
    expect(createTop.dx, lessThan(40), reason: 'первая клетка ряда');
    await tester.tap(create);
    expect(createTapped, isTrue);
  });

  testWidgets('⚙ только у своего набора, ⋯ — у чужого', (tester) async {
    await pumpPanel(tester);
    expect(find.byKey(const ValueKey('stickers:settings:$_own')), findsOneWidget);
    expect(find.byKey(const ValueKey('stickers:settings:$_foreign')),
        findsNothing);
    expect(find.byKey(const ValueKey('stickers:more:$_foreign')), findsOneWidget);
    expect(find.byKey(const ValueKey('stickers:more:$_own')), findsNothing);
  });

  testWidgets('⚙ открывает набор: «⋯» у стикеров, «+», «Готово»; «+» — '
      'создание стикера в этот набор', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.byKey(const ValueKey('stickers:settings:$_own')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stickers:pack-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('stickers:sticker-more:a')), findsOneWidget);
    expect(find.byKey(const ValueKey('stickers:sticker-more:b')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stickers:pack-add')));
    await tester.pumpAndSettle();
    expect(addRequestedFor, _own);
  });

  testWidgets('🔴 удаление стикера — только после вопроса', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.byKey(const ValueKey('stickers:settings:$_own')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stickers:sticker-more:a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(find.text('Удалить стикер?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(controller.deletedStickers, isEmpty, reason: 'отмена — ничего');

    await tester.tap(find.byKey(const ValueKey('stickers:sticker-more:a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stickers:confirm')));
    await tester.pumpAndSettle();
    expect(controller.deletedStickers, ['$_own/a']);
  });

  testWidgets('удалить весь свой набор — через ⋮ и вопрос', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.byKey(const ValueKey('stickers:settings:$_own')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stickers:pack-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить набор'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить набор?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stickers:confirm')));
    await tester.pumpAndSettle();
    expect(controller.deletedPacks, [_own]);
  });

  testWidgets('чужой набор — «Убрать из моих наборов» с вопросом', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.byKey(const ValueKey('stickers:more:$_foreign')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stickers:remove-foreign')));
    await tester.pumpAndSettle();
    expect(find.textContaining('У автора и у других'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stickers:confirm')));
    await tester.pumpAndSettle();
    expect(controller.deletedPacks, [_foreign]);
  });
}
