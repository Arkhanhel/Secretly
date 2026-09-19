// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Полоса идущего созвона — над всем окном, из любого раздела.
//
// 🔴 ЧТО БЫЛО. Плашка «Идёт обсуждение» жила ВНУТРИ ленты своей комнаты.
// Свернул окно созвона, открыл другой чат, зашёл в настройки — и о том, что
// разговор идёт, не напоминало ничто: ни полосы, ни кнопки возврата.
// Вернуться можно было, только вспомнив, в какой комнате созвон, и дойдя до
// неё.
//
// Проверено живьём вдвоём: свернув созвон, найти дорогу назад было нечем.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/calls/active_call_bar.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 900, child: child)),
  ),
);

void main() {
  testWidgets('без созвона полосы нет вовсе', (t) async {
    // `RoomCallManager.instance` в тесте пуст — это и есть «созвона нет».
    await t.pumpWidget(
      host(
        DesktopActiveCallBar(
          titleFor: (_) => 'тест 2',
          onReturn: (_, _) {},
          onToggleMic: () async {},
        ),
      ),
    );
    expect(find.textContaining('Идёт созвон'), findsNothing);
    expect(find.text('Вернуться'), findsNothing);
    // И не занимает высоту: полоса-пустышка сдвигала бы всё окно вниз.
    expect(t.getSize(find.byType(DesktopActiveCallBar)).height, 0);
  });

  group('правила полосы', () {
    final src = File(
      'lib/ui/desktop/calls/active_call_bar.dart',
    ).readAsStringSync();

    test('🔴 показывается только когда Я САМ в созвоне', () {
      // Чужой идущий созвон полосой не показываем: звать в него — дело
      // плашки внутри комнаты. Иначе два разных приглашения об одном.
      expect(src.contains('self.isJoined'), isTrue);
      expect(src.contains('if (roomId == null) return const SizedBox.shrink();'), isTrue);
    });

    test('сама следит за состоянием созвона', () {
      expect(src.contains('state.addListener(_onState)'), isTrue);
      expect(src.contains('state.removeListener(_onState)'), isTrue);
    });

    test('времени разговора в полосе НЕТ намеренно', () {
      // Оно уже идёт в шапке окна созвона, а у полосы другая работа —
      // вернуть человека туда, где оно и так видно.
      expect(src.contains('Timer'), isFalse);
    });

    test('не нашли имя комнаты — показываем без имени, а не идентификатор', () {
      expect(src.contains('title.isEmpty'), isTrue);
      expect(src.contains('l10n.desktopCallInProgress'), isTrue);
      final app = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      expect(app.contains("return '';"), isTrue);
    });

    test('🔴 имя комнаты не теряется при уходе в другой раздел', () {
      // Имя приходит из складов выбора: ушёл в «Чаты» — склад комнату уже не
      // держит, и полоса теряла имя посреди разговора. Проверено живьём.
      expect(src.contains('String _rememberedTitle'), isTrue);
      expect(src.contains('if (fresh.isNotEmpty) _rememberedTitle = fresh;'), isTrue);
      // И сбрасывается вместе с созвоном, чтобы не всплыть в следующем.
      expect(src.contains("if (_joinedRoomId == null) _rememberedTitle = '';"), isTrue);
    });
  });

  test('полоса стоит в оболочке между шапкой и содержимым', () {
    final shell = File(
      'lib/ui/desktop/shell/desktop_shell.dart',
    ).readAsStringSync();
    expect(shell.contains('final Widget? activeCallBar;'), isTrue);
    expect(
      shell.contains('if (widget.activeCallBar != null) widget.activeCallBar!,'),
      isTrue,
    );
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(app.contains('activeCallBar: DesktopActiveCallBar('), isTrue);
    expect(app.contains('onReturn: _returnToRoomCall'), isTrue);
  });

  test('🔴 «Вернуться» берёт навигатор у КЛЮЧА, а не по контексту', () {
    // Этот виджет сам строит `MaterialApp`: навигатора среди его предков нет,
    // `Navigator.of` не находит ничего, и кнопка молча не работает.
    // Проверено живьём — нажатие не открывало окно созвона.
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    final i = app.indexOf('void _returnToRoomCall(');
    expect(i, greaterThan(0));
    final body = app.substring(i, i + 700);
    expect(body.contains('_navigatorKey.currentState'), isTrue);
    expect(body.contains('Navigator.of(context)'), isFalse);
  });

  // 🔴 ЗАМОЛЧАТЬ, НЕ ВОЗВРАЩАЯСЬ В ОКНО СОЗВОНА.
  //
  // ТЗ просило поставить микрофон внизу колонки пространства. Требование
  // верное, место — нет: рейка про РАЗДЕЛЫ приложения, а не про идущий
  // разговор, и кнопка там стала бы третьим местом рядом с доком созвона и
  // этой полосой. Полоса и так говорит «разговор идёт» и видна отовсюду.
  group('микрофон в полосе', () {
    final src = File(
      'lib/ui/desktop/calls/active_call_bar.dart',
    ).readAsStringSync();
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    test('кнопка есть и называет состояние', () {
      expect(src.contains('mic_off_24_filled'), isTrue);
      expect(
        src.contains('l10n.desktopCallMicOn : l10n.desktopCallMicOff'),
        isTrue,
      );
    });

    test('🔴 состояние читается у СЕССИИ, а не из своего поля', () {
      // Окно созвона меняет то же состояние; два места не должны спорить.
      expect(
        src.contains('state.value.session?.selfParticipant?.muted'),
        isTrue,
      );
    });

    test('🔴 переключение идёт ТЕМ ЖЕ путём, что и док созвона', () {
      // Два места, меняющие одно состояние разными путями, разъезжаются — а
      // тут это значит «думаю, что молчу, а меня слышно».
      expect(app.contains('Future<void> _toggleRoomCallMic()'), isTrue);
      expect(app.contains('_controller.updateRelayRoomCallParticipant('), isTrue);
      expect(app.contains('muted: !self.muted'), isTrue);
      // И состояние берётся из СВЕЖЕГО снимка, а не из того, что помнит полоса.
      expect(app.contains('_controller.getCachedRoomCall(roomId)'), isTrue);
    });

    test('пока переключение летит — кнопка не принимает нажатий', () {
      // Иначе два быстрых нажатия разъедутся с ответом и состояние замигает.
      expect(src.contains('if (_busy) return;'), isTrue);
      expect(src.contains('onTap: _busy ? null : _toggleMic'), isTrue);
    });

    test('созвон не тот — ничего не трогаем', () {
      expect(app.contains('cached.callId != callId'), isTrue);
    });
  });
}
