// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// C-6: РАЗМЕР ТЕКСТА В ОКНЕ.
//
// 🔴 ЧЕГО НЕ ХВАТАЛО. На 4K подписи мелкие, и изменить их было нечем: окно
// рисовалось ровно по макету при любом экране.
//
// 🔴 ПОЧЕМУ «РАЗМЕР ТЕКСТА», А НЕ «МАСШТАБ ИНТЕРФЕЙСА». Растянуть окно целиком
// значило бы растянуть отступы, значки и рамки — то есть пересчитать раскладку,
// выверенную по макету до точки. Текст лежит в строках с ЗАДАННОЙ МИНИМАЛЬНОЙ
// высотой и растёт, не ломая их. Обещать одно, а делать другое — неправда, и
// подпись в настройках говорит ровно то, что переключатель делает.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// `intl` экспортирует СВОЙ TextDirection и перекрывает флаттеровский.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

void main() {
  test('ступени включают ровно 100 % — к «как было» всегда можно вернуться', () {
    expect(DesktopUiPrefs.textScaleSteps, contains(1.0));
    expect(DesktopUiPrefs.textScaleSteps.first, lessThan(1.0));
    expect(DesktopUiPrefs.textScaleSteps.last, greaterThan(1.0));
  });

  test('🔴 испорченная настройка не делает окно нечитаемым', () {
    // Список ступеней закрытый: что бы ни лежало в настройках, применится
    // ближайшая разрешённая величина, а не она сама.
    expect(DesktopUiPrefs.normalizeTextScale(99.0), 1.5);
    expect(DesktopUiPrefs.normalizeTextScale(0.01), 0.9);
    expect(DesktopUiPrefs.normalizeTextScale(double.nan), 1.0);
    expect(DesktopUiPrefs.normalizeTextScale(double.infinity), 1.0);
    expect(DesktopUiPrefs.normalizeTextScale(null), 1.0);
  });

  test('близкое значение притягивается к своей ступени', () {
    expect(DesktopUiPrefs.normalizeTextScale(1.14), 1.15);
    expect(DesktopUiPrefs.normalizeTextScale(1.28), 1.3);
    expect(DesktopUiPrefs.normalizeTextScale(0.95), closeTo(0.9, 0.11));
  });

  testWidgets('множитель и правда увеличивает текст', (t) async {
    // Проверяем не настройку, а последствие: та же подпись при 150 % должна
    // занимать больше места. Иначе «размер текста» был бы просто числом в
    // настройках, ни на что не влияющим.
    Future<Size> sizeAt(double scale) async {
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const Scaffold(
            body: Center(child: Text('Привет', textDirection: TextDirection.ltr)),
          ),
        ),
      ));
      await t.pumpAndSettle();
      return t.getSize(find.text('Привет'));
    }

    final small = await sizeAt(1.0);
    final big = await sizeAt(1.5);
    expect(big.height, greaterThan(small.height));
    expect(big.width, greaterThan(small.width));
  });

  testWidgets('🔴 при 150 % настройки не переполняются', (t) async {
    // Крупный текст в окне, выверенном по ширине до точки, — первое, что
    // способно сломать раскладку. Переполнение в проверке даёт исключение,
    // поэтому «ничего не всплыло» здесь и есть доказательство.
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: const TextScaler.linear(1.5),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SettingsWorkspace()),
      ),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    for (var i = 0; i < 17; i++) {
      await t.tap(find.byType(WorkspaceIconPlate).at(i));
      await t.pumpAndSettle();
      expect(
        t.takeException(),
        isNull,
        reason: 'раздел №$i переполняется при крупном тексте',
      );
    }
  });

  testWidgets('🔴 при 150 % не переполняются переписка и список', (t) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, c) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: const TextScaler.linear(1.5),
        ),
        child: c ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: DColors(colors: kDColorsDark, child: child),
      ),
    );

    await t.pumpWidget(host(const SizedBox(
      width: 320,
      height: 600,
      child: ChatListPanel(
        items: [
          ChatListItem(
            id: 'c1',
            name: 'Максим Александрович',
            preview: 'Длинное превью последнего сообщения в списке',
            time: '11:16',
            delivery: ChatDelivery.read,
            unread: 12,
          ),
        ],
        selectedId: null,
        onSelect: _ignore,
      ),
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'список переписок переполняется');

    await t.pumpWidget(host(SizedBox(
      width: 760,
      child: MessageBubble(
        message: MessageData(
          id: 'm1',
          payloadId: 'p1',
          authorName: 'Вы',
          text: 'Сообщение подлиннее, чтобы пузырь считал перенос строк',
          time: '14:19',
          isSelf: true,
          delivery: DeliveryStatus.read,
          reactions: const [MessageReaction(emoji: '👍', count: 3)],
        ),
      ),
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'пузырь сообщения переполняется');
  });

  test('🔴 знак процента ставится по правилам языка, а не руками', () {
    // В английском «90%» вплотную, в русском и французском — «90 %» через
    // неразрывный пробел. Собранная руками строка была бы верна ровно в одном
    // языке из восьми.
    final en = NumberFormat.percentPattern('en').format(0.9);
    final ru = NumberFormat.percentPattern('ru').format(0.9);
    expect(en, isNot(equals(ru)), reason: 'форматы языков обязаны различаться');
    expect(en.contains('90'), isTrue);
    expect(ru.contains('90'), isTrue);
  });
}

void _ignore(String _) {}
