// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// НАБОР СТИКЕРОВ НА КОМПЬЮТЕРЕ.
//
// 🔴 Присланный стикер на компьютере был просто картинкой: нажатие не делало
// ничего, и поставить себе чужой набор было нельзя — только с телефона.
//
// Окно намеренно не знает про контроллер: оно получает снимок состояния и два
// действия. Поэтому его можно проверить целиком, без приложения.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/desktop/chat/sticker_pack_dialog.dart';

SecretlyStickerDescriptor _sticker(String id) => SecretlyStickerDescriptor(
  packId: 'user:someone',
  packVersion: 1,
  stickerId: id,
  assetPath: '',
  format: SecretlyStickerFormat.png,
  animated: false,
  emojiHint: '🙂',
  label: id,
  keywords: const <String>[],
  // «Нет файла» — рисуется запасной значок, а не грузится ассет: проверяем
  // окно, а не картинки.
  assetSource: SecretlyStickerAssetSource.missing,
);

Widget _host({
  required DesktopStickerPackView view,
  Stream<void>? changed,
  Future<void> Function()? onInstall,
  Future<void> Function(SecretlyStickerDescriptor)? onSend,
}) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DesktopStickerPackDialog(
        changed: changed ?? const Stream<void>.empty(),
        snapshot: () => view,
        onInstall: onInstall ?? () async {},
        onSend: onSend ?? (_) async {},
      ),
    ),
  );
}

DesktopStickerPackView _view({
  String title = 'Кошки',
  int total = 24,
  int have = 1,
  DesktopStickerPackAvailability availability =
      DesktopStickerPackAvailability.canInstall,
  bool inFlight = false,
  int received = 0,
  int expected = 0,
}) {
  return DesktopStickerPackView(
    title: title,
    total: total,
    stickers: <SecretlyStickerDescriptor>[
      for (var i = 0; i < have; i++) _sticker('s$i'),
    ],
    availability: availability,
    inFlight: inFlight,
    received: received,
    expected: expected,
  );
}

void main() {
  testWidgets('название набора и его размер видны сразу', (t) async {
    await t.pumpWidget(_host(view: _view()));
    expect(find.text('Кошки'), findsOneWidget);
    // Русское число: 24 — «стикера» (24 % 10 = 4), а 25 уже «стикеров».
    expect(find.text('24 стикера'), findsOneWidget);
  });

  testWidgets('🔴 размер набора виден ДО установки — пустыми плитками', (
    t,
  ) async {
    final v = _view(total: 24, have: 1);
    // Один пришедший плюс пустые места, но не больше шестнадцати: окно не
    // должно растягиваться на набор в тысячу.
    expect(v.missing, 16);
    await t.pumpWidget(_host(view: v));
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('кнопка называет число, а не безликое «Установить»', (t) async {
    var installs = 0;
    await t.pumpWidget(
      _host(
        view: _view(total: 24),
        onInstall: () async => installs++,
      ),
    );
    final button = find.text('Добавить 24 стикера');
    expect(button, findsOneWidget);
    await t.tap(button);
    await t.pump();
    expect(installs, 1, reason: 'нажатие просит набор у автора');
  });

  testWidgets('🔴 три формы русского числительного, а не одна', (t) async {
    // 1 стикер / 24 стикера / 25 стикеров — правило языка, а не украшение:
    // «Добавить 25 стикера» читается как ошибка приложения.
    await t.pumpWidget(_host(view: _view(total: 1, have: 1)));
    expect(find.text('Добавить 1 стикер'), findsOneWidget);

    await t.pumpWidget(_host(view: _view(total: 25, have: 1)));
    expect(find.text('Добавить 25 стикеров'), findsOneWidget);

    await t.pumpWidget(_host(view: _view(total: 11, have: 1)));
    expect(find.text('Добавить 11 стикеров'), findsOneWidget,
        reason: '11–14 — исключение, «11 стикер» было бы ошибкой');
  });

  testWidgets('идёт установка — счёт кусков, нажать нельзя', (t) async {
    await t.pumpWidget(
      _host(
        view: _view(inFlight: true, received: 3, expected: 8),
        onInstall: () async => fail('во время установки жать нечего'),
      ),
    );
    expect(find.text('Установка… 3/8'), findsOneWidget);
    await t.tap(find.text('Установка… 3/8'));
    await t.pump();
  });

  testWidgets('🔴 пока автор не ответил, числа нет — «0/0» читалось бы как '
      'поломка', (t) async {
    await t.pumpWidget(
      _host(view: _view(inFlight: true, received: 0, expected: 0)),
    );
    expect(find.text('Установка…'), findsOneWidget);
    expect(find.text('Установка… 0/0'), findsNothing);
  });

  testWidgets('уже стоит — так и написано, без кнопки', (t) async {
    await t.pumpWidget(
      _host(
        view: _view(
          availability: DesktopStickerPackAvailability.installed,
          total: 3,
          have: 3,
        ),
      ),
    );
    expect(find.text('Установлено'), findsOneWidget);
    expect(find.textContaining('Добавить'), findsNothing);
  });

  testWidgets('свой набор ставить нечего', (t) async {
    await t.pumpWidget(
      _host(view: _view(availability: DesktopStickerPackAvailability.own)),
    );
    expect(find.text('Это ваш набор'), findsOneWidget);
    expect(find.textContaining('Добавить'), findsNothing);
  });

  testWidgets('🔴 автор неизвестен — объяснение вместо кнопки, которая '
      'ничего не сделает', (t) async {
    await t.pumpWidget(
      _host(view: _view(availability: DesktopStickerPackAvailability.noAuthor)),
    );
    expect(find.textContaining('Автор набора неизвестен'), findsOneWidget);
    expect(find.textContaining('Добавить'), findsNothing);
  });

  testWidgets('нажатие на стикер отправляет его в переписку', (t) async {
    final sent = <String>[];
    await t.pumpWidget(
      _host(
        view: _view(
          availability: DesktopStickerPackAvailability.installed,
          total: 2,
          have: 2,
        ),
        onSend: (s) async => sent.add(s.stickerId),
      ),
    );
    await t.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    await t.pump();
    expect(sent, isNotEmpty);
    expect(sent.first, 's0');
  });

  testWidgets('счёт принятых обновляется по тику контроллера', (t) async {
    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);
    var received = 1;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DesktopStickerPackDialog(
            changed: ticks.stream,
            snapshot: () => _view(
              inFlight: true,
              received: received,
              expected: 8,
            ),
            onInstall: () async {},
            onSend: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Установка… 1/8'), findsOneWidget);
    received = 5;
    ticks.add(null);
    await t.pump();
    expect(find.text('Установка… 5/8'), findsOneWidget);
  });
}
