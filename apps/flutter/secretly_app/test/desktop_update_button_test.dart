// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Кнопка «Обновить» внизу окна и то, откуда она узнаёт о новой версии
// (24.09.2026): на Mac — Sparkle, на Windows — свой перечень версий.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_footer.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_update_service.dart';
import 'package:secretly_app/ui/desktop/shell/now_playing_island.dart';

const _feed = '''<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Secretly</title>
    <item>
      <title>1.8.56</title>
      <sparkle:version>625</sparkle:version>
      <sparkle:shortVersionString>1.8.56</sparkle:shortVersionString>
      <enclosure url="https://updates.secretlyapp.com/Secretly-1.8.56-625-windows-x64.zip" length="1" type="application/zip"/>
    </item>
    <item>
      <title>1.8.55</title>
      <sparkle:version>624</sparkle:version>
      <sparkle:shortVersionString>1.8.55</sparkle:shortVersionString>
      <enclosure url="https://updates.secretlyapp.com/Secretly-1.8.55-624-windows-x64.zip" length="1" type="application/zip"/>
    </item>
  </channel>
</rss>''';

void main() {
  group('перечень версий Windows', () {
    test('новее установленной — предлагается самая новая', () {
      final offer = parseWindowsFeed(
        _feed,
        currentBuild: 624,
        feedHost: 'updates.secretlyapp.com',
      );
      expect(offer, isNotNull);
      expect(offer!.version, '1.8.56');
      expect(offer.build, 625);
      expect(
        offer.downloadUrl,
        endsWith('Secretly-1.8.56-625-windows-x64.zip'),
      );
    });

    test('установлена самая новая — обновления нет', () {
      expect(
        parseWindowsFeed(
          _feed,
          currentBuild: 625,
          feedHost: 'updates.secretlyapp.com',
        ),
        isNull,
      );
    });

    test('🔴 ссылку на чужой адрес не принимает', () {
      final forged = _feed.replaceAll(
        'https://updates.secretlyapp.com/Secretly-1.8.56',
        'https://evil.example/Secretly-1.8.56',
      );
      final offer = parseWindowsFeed(
        forged,
        currentBuild: 1,
        feedHost: 'updates.secretlyapp.com',
      );
      // Поддельная запись отброшена; осталась честная, пусть и не новейшая.
      expect(offer!.build, 624);
    });

    test('пустой или битый перечень — молча без обновления', () {
      expect(parseWindowsFeed('', currentBuild: 1, feedHost: 'x'), isNull);
      expect(
        parseWindowsFeed(
          '<rss><item></item></rss>',
          currentBuild: 1,
          feedHost: 'x',
        ),
        isNull,
      );
    });
  });

  group('кнопка «Обновить» рядом с «Синхронизировано»', () {
    tearDown(() => DesktopUpdateService.instance.debugReset());

    Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SizedBox(width: 320, child: child)),
      ),
    );

    testWidgets('пока новой версии нет — кнопки нет', (t) async {
      await t.pumpWidget(host(const ChatListFooter(sync: null)));
      expect(find.text('Обновить'), findsNothing);
    });

    testWidgets('нашлась — кнопка с номером в подсказке', (t) async {
      DesktopUpdateService.instance.available.value = const DesktopUpdateOffer(
        version: '1.8.56',
        build: 625,
      );
      await t.pumpWidget(host(const ChatListFooter(sync: null)));
      expect(find.text('Обновить'), findsOneWidget);
      expect(find.byTooltip('Доступна версия 1.8.56'), findsOneWidget);
    });
  });

  group('мини-плеер', () {
    test('скорость подписана без лишних нулей', () {
      expect(desktopSpeedLabel(1.0), '1×');
      expect(desktopSpeedLabel(1.5), '1.5×');
      expect(desktopSpeedLabel(0.5), '0.5×');
      expect(desktopSpeedLabel(2.0), '2×');
      expect(kDesktopPlayerSpeeds, [0.5, 1.0, 1.5, 2.0]);
    });

    test('громкость — 0..1, испорченное значение — полная', () {
      expect(DesktopUiPrefs.normalizePlayerVolume(null), 1.0);
      expect(DesktopUiPrefs.normalizePlayerVolume(double.nan), 1.0);
      expect(DesktopUiPrefs.normalizePlayerVolume(-0.3), 0.0);
      expect(DesktopUiPrefs.normalizePlayerVolume(1.7), 1.0);
      expect(DesktopUiPrefs.normalizePlayerVolume(0.42), 0.42);
    });
  });
}
