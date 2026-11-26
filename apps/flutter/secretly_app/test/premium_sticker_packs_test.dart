// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Премиум-наборы стикеров «Секретный сейф» и «Pixel» (24.11.2026).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:lottie/lottie.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/stickers/premium_sticker_packs.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/chat/emoji_panel/premium_sticker_sheet.dart';

/// Публичная выкладка не несёт двоичных ресурсов (.tgs): проверки файлов
/// там молчат, а не падают (26.11.2026).
final String? _noStickerFiles =
    File('assets/stickers/premium_safe/diamond.tgs').existsSync()
    ? null
    : 'файлов стикеров нет (публичная выкладка)';

void main() {
  // Стикеры дизайнера встают на паузу вне экрана (VisibilityDetector):
  // в тестах — без задержки, чтобы не оставалось таймеров.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  test('два набора: 20 и 12 стикеров, Lottie, премиум, ключи уникальны', () {
    expect(premiumStickerPacks.map((p) => p.id), [
      kPremiumSafePackId,
      kPremiumPixelPackId,
    ]);
    expect(premiumStickerPacks[0].stickers, hasLength(20));
    expect(premiumStickerPacks[1].stickers, hasLength(12));
    for (final p in premiumStickerPacks) {
      expect(p.premium, isTrue);
      expect(isPremiumStickerPackId(p.id), isTrue);
      expect(p.iconSticker.stickerId, p.stickers.first.stickerId);
      final ids = p.stickers.map((s) => s.stickerId).toSet();
      expect(ids, hasLength(p.stickers.length));
      for (final s in p.stickers) {
        expect(s.format, SecretlyStickerFormat.lottie);
        expect(s.assetSource, SecretlyStickerAssetSource.bundledAsset);
        expect(s.assetPath, startsWith('$kPremiumStickerAssetsDir/'));
        expect(s.assetPath, endsWith('/${s.stickerId}.tgs'));
        // Старые сборки и получатель без набора видят подсказку-эмодзи.
        expect(s.emojiHint, isNotEmpty);
      }
    }
    expect(isPremiumStickerPackId('user:x:cats'), isFalse);
  });

  test('🔴 выключатель: без него наборов нет ни в панели, ни в поиске по '
      'событию; с ним — оба и все файлы на месте', () {
    final found = SecretlyStickerCatalog.findSticker(
      packId: kPremiumSafePackId,
      packVersion: kPremiumPackVersion,
      stickerId: 'crown',
    );
    if (!kPremiumStickerPacks) {
      expect(SecretlyStickerCatalog.premiumPickerPacks, isEmpty);
      expect(found, isNull);
      return;
    }
    expect(SecretlyStickerCatalog.premiumPickerPacks, hasLength(2));
    expect(found?.stickerId, 'crown');
    // Премиум-наборов нет в общей панели и в поиске — только у лупы.
    expect(
      SecretlyStickerCatalog.pickerPacks.any((p) => p.premium),
      isFalse,
    );
  });

  test('🔴 файлы всех встроенных наборов на месте: .tgs = gzip Lottie '
      '512×512, не больше 64 КБ', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final p in [...premiumStickerPacks, kidsStickerPack]) {
      final first = p.stickers.first.assetPath;
      final dir = first.substring(0, first.lastIndexOf('/') + 1);
      expect(pubspec.contains('- $dir'), isTrue, reason: dir);
      for (final s in p.stickers) {
        final f = File(s.assetPath);
        expect(f.existsSync(), isTrue, reason: s.assetPath);
        final bytes = f.readAsBytesSync();
        expect(bytes.length, lessThan(64 * 1024), reason: s.assetPath);
        final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
        expect(j['w'], 512, reason: s.assetPath);
        expect(j['h'], 512, reason: s.assetPath);
      }
    }
  }, skip: _noStickerFiles);

  test('«Детки» — бесплатно для всех: в панели первым набором, ищется, '
      'отправка без замка', () {
    expect(kidsStickerPack.premium, isFalse);
    expect(kidsStickerPack.stickers, hasLength(12));
    expect(isPremiumStickerPackId(kKidsStickerPackId), isFalse);
    if (!kKidsStickerPack) return;
    expect(SecretlyStickerCatalog.pickerPacks.first.id, kKidsStickerPackId);
    expect(
      SecretlyStickerCatalog.findSticker(
        packId: kKidsStickerPackId,
        packVersion: kPremiumPackVersion,
        stickerId: 'k_wave',
      )?.emojiHint,
      '👋',
    );
    expect(
      SecretlyStickerCatalog.search('привет').any((s) => s.stickerId == 'k_wave'),
      isTrue,
    );
  });

  test('🔴 каждый стикер разбирается Lottie: 3 секунды, без предупреждений '
      'о неподдерживаемом', () async {
    for (final p in [...premiumStickerPacks, kidsStickerPack]) {
      for (final s in p.stickers) {
        final c = await LottieComposition.decodeGZip(
          File(s.assetPath).readAsBytesSync(),
        );
        expect(c, isNotNull, reason: s.assetPath);
        expect(c!.duration.inMilliseconds, inInclusiveRange(2900, 3100), reason: s.assetPath);
        expect(c.warnings, isEmpty, reason: '${s.assetPath}: ${c.warnings}');
      }
    }
  }, skip: _noStickerFiles);

  test('«Pixel» рисуется 12 кадрами в секунду, остальные — как в файле', () {
    expect(stickerPackFrameRate(kPremiumPixelPackId), 12);
    expect(stickerPackFrameRate(kPremiumSafePackId), isNull);
    expect(stickerPackFrameRate(kKidsStickerPackId), isNull);
  });

  test('🔴 без Premium стикер не уходит: проверка в контроллере (лично и в '
      'комнату), экран открывает покупку', () {
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    for (final m in ['Future<String> sendSticker(', 'Future<String> sendGroupSticker(']) {
      final i = c.indexOf(m);
      expect(i, greaterThan(0), reason: m);
      final body = c.substring(i, i + 400);
      expect(body.contains('_ensurePremiumStickerAllowed(sticker);'), isTrue, reason: m);
    }
    expect(c.contains('GatedFeature.premiumStickers'), isTrue);
    final ui = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(ui.contains('on PremiumStickerLockedException'), isTrue);
    expect(ui.contains('isPremiumStickerPackId(event.packId)'), isTrue);
  });

  Widget host(Widget child, {Brightness b = Brightness.dark}) => MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(brightness: b),
    home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
  );

  testWidgets('окно набора: без Premium — кнопка покупки, с Premium — '
      'касание отправляет', (t) async {
    t.view.physicalSize = const Size(1179, 2556);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    var opened = 0;
    await t.pumpWidget(
      host(
        PremiumStickerPackSheet(
          pack: premiumStickerPacks[1],
          unlocked: false,
          onOpenPremium: () => opened++,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Pixel'), findsOneWidget);
    expect(find.text('Анимированные стикеры для подписчиков Premium'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('premium-sticker-sheet:unlock')));
    expect(opened, 1);

    final sent = <String>[];
    await t.pumpWidget(
      host(
        PremiumStickerPackSheet(
          pack: premiumStickerPacks[0],
          unlocked: true,
          onOpenPremium: () {},
          onSend: (s) => sent.add(s.stickerId),
        ),
        b: Brightness.light,
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Секретный сейф'), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-sticker-sheet:unlock')), findsNothing);
    await t.tap(find.byKey(const ValueKey('premium-sticker-sheet:cell:diamond')));
    expect(sent, ['diamond']);
  });
}
