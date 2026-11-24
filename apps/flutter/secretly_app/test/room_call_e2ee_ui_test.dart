// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Интерфейс шифрования групповых созвонов (ТЗ E2EE созвонов, §7.3, §8).
// 🔴 Главное: пока у устройства нет раскатки, вход идёт как раньше — без
// окон, а плашек нет вовсе.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/rooms/call_e2ee/call_e2ee_protocol.dart';
import 'package:secretly_app/rooms/call_e2ee/room_call_e2ee_status.dart';
import 'package:secretly_app/rooms/call_e2ee/room_call_join_plan.dart';
import 'package:secretly_app/ui/desktop/calls/room_call_e2ee_desktop.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/room_call_e2ee_ui.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

final AppLocalizations _l10n = AppLocalizationsEn();

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: child),
  ),
);

class _Asks {
  int creator = 0;
  int open = 0;
  final List<String> blocked = <String>[];
  String? names;
}

Future<RoomCallJoinDecision?> _decide(
  RoomCallJoinPlan plan,
  _Asks asks, {
  ({bool encrypted, bool notify})? creatorAnswer,
  bool openAnswer = true,
}) => decideRoomCallJoin(
  loadPlan: () async => plan,
  displayName: (id) async => id == 'p1' ? 'Igor' : null,
  l10n: _l10n,
  askCreatorChoice: (names) async {
    asks.creator += 1;
    asks.names = names;
    return creatorAnswer;
  },
  askOpenJoin: () async {
    asks.open += 1;
    return openAnswer;
  },
  notifyBlocked: asks.blocked.add,
);

void main() {
  group('решение перед входом', () {
    test('🔴 раскатки нет: открытый созвон, ни одного окна', () async {
      final asks = _Asks();
      final d = await _decide(
        const RoomCallJoinPlan(
          contract: kRoomMediaContractV1,
          existingCall: false,
        ),
        asks,
      );
      expect(d!.contract, kRoomMediaContractV1);
      expect(d.notifyMembers, isFalse);
      expect(asks.creator + asks.open, 0);
      expect(asks.blocked, isEmpty);
    });

    test('идёт зашифрованный созвон — входим зашифрованным без окон', () async {
      final asks = _Asks();
      final d = await _decide(
        const RoomCallJoinPlan(
          contract: kRoomMediaContractE2eeV1,
          existingCall: true,
        ),
        asks,
      );
      expect(d!.contract, kRoomMediaContractE2eeV1);
      expect(asks.creator + asks.open, 0);
    });

    test('открытый созвон при раскатке — только с согласия', () async {
      final asks = _Asks();
      const plan = RoomCallJoinPlan(
        contract: kRoomMediaContractV1,
        existingCall: true,
        needsOpenJoinConsent: true,
      );
      expect((await _decide(plan, asks))!.contract, kRoomMediaContractV1);
      expect(await _decide(plan, asks, openAnswer: false), isNull);
      expect(asks.open, 2);
    });

    test('окно у создателя: зашифрованный с сообщением в чат', () async {
      final asks = _Asks();
      const plan = RoomCallJoinPlan(
        contract: kRoomMediaContractE2eeV1,
        existingCall: false,
        membersWithoutE2ee: ['p1', 'p2-long-profile-id'],
        offerOpenAlternative: true,
      );
      final d = await _decide(
        plan,
        asks,
        creatorAnswer: (encrypted: true, notify: true),
      );
      expect(d!.contract, kRoomMediaContractE2eeV1);
      expect(d.notifyMembers, isTrue);
      expect(asks.names, 'Igor, p2-long-');
    });

    test('окно у создателя: открытый — без сообщения; закрыл окно — не '
        'входим', () async {
      final asks = _Asks();
      const plan = RoomCallJoinPlan(
        contract: kRoomMediaContractE2eeV1,
        existingCall: false,
        membersWithoutE2ee: ['p1'],
        offerOpenAlternative: true,
      );
      final open = await _decide(
        plan,
        asks,
        creatorAnswer: (encrypted: false, notify: true),
      );
      expect(open!.contract, kRoomMediaContractV1);
      expect(open.notifyMembers, isFalse);
      expect(await _decide(plan, asks), isNull);
    });

    test(
      'флаг-день: открытой альтернативы нет — без окна, зашифрованный',
      () async {
        final asks = _Asks();
        final d = await _decide(
          const RoomCallJoinPlan(
            contract: kRoomMediaContractE2eeV1,
            existingCall: false,
            membersWithoutE2ee: ['p1'],
          ),
          asks,
        );
        expect(d!.contract, kRoomMediaContractE2eeV1);
        expect(asks.creator, 0);
      },
    );

    test('вход закрыт — сообщение и не входим', () async {
      final asks = _Asks();
      final d = await _decide(
        const RoomCallJoinPlan(
          contract: kRoomMediaContractE2eeV1,
          existingCall: true,
          block: RoomCallJoinBlock.platformUnsupported,
        ),
        asks,
      );
      expect(d, isNull);
      expect(asks.blocked, [_l10n.roomCallE2eeUnsupported]);
    });
  });

  group('подписи', () {
    test('подсказка в шапке ПК: открытый созвон — прежняя', () {
      expect(
        desktopRoomCallSecurityHint(null, _l10n),
        _l10n.desktopRoomCallTransportEncrypted,
      );
      expect(
        desktopRoomCallSecurityHint(
          const RoomCallE2eeStatus(own: RoomCallE2eeOwnState.encrypting),
          _l10n,
        ),
        _l10n.roomCallE2eeOnHint,
      );
      expect(
        desktopRoomCallSecurityHint(
          const RoomCallE2eeStatus(
            own: RoomCallE2eeOwnState.failed,
            errorCode: 'platform_unsupported',
          ),
          _l10n,
        ),
        _l10n.roomCallE2eeUnsupported,
      );
    });

    test('плитка собеседника', () {
      const status = RoomCallE2eeStatus(
        own: RoomCallE2eeOwnState.encrypting,
        peersByDeviceId: {
          'a': RoomCallE2eePeerState.waitingKey,
          'b': RoomCallE2eePeerState.failing,
          'c': RoomCallE2eePeerState.decrypting,
        },
      );
      expect(
        roomCallE2eePeerCaption(status, 'a', _l10n),
        _l10n.roomCallE2eeWaitingKey,
      );
      expect(
        roomCallE2eePeerCaption(status, 'b', _l10n),
        _l10n.roomCallE2eeFailing,
      );
      expect(roomCallE2eePeerCaption(status, 'c', _l10n), isNull);
      expect(roomCallE2eePeerCaption(null, 'a', _l10n), isNull);
    });
  });

  group('плашки', () {
    testWidgets('🔴 ПК: открытый созвон без раскатки — пусто', (t) async {
      await t.pumpWidget(
        _app(
          const DesktopRoomCallE2eeStrip(status: null, showOpenWarning: false),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('ПК: открытый созвон при раскатке — предупреждение', (t) async {
      await t.pumpWidget(
        _app(
          const DesktopRoomCallE2eeStrip(status: null, showOpenWarning: true),
        ),
      );
      expect(find.text(_l10n.roomCallOpenBanner), findsOneWidget);
    });

    testWidgets('ПК: шифрование включено — места не занимает', (t) async {
      await t.pumpWidget(
        _app(
          const DesktopRoomCallE2eeStrip(
            status: RoomCallE2eeStatus(own: RoomCallE2eeOwnState.encrypting),
            showOpenWarning: false,
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('ПК: неизвестные участники названы числом', (t) async {
      await t.pumpWidget(
        _app(
          const DesktopRoomCallE2eeStrip(
            status: RoomCallE2eeStatus(
              own: RoomCallE2eeOwnState.encrypting,
              unknownParticipants: 2,
            ),
            showOpenWarning: false,
          ),
        ),
      );
      expect(
        find.text(_l10n.roomCallE2eeUnknownParticipants(2)),
        findsOneWidget,
      );
    });

    testWidgets('🔴 телефон: открытый созвон без раскатки — знака нет', (
      t,
    ) async {
      RoomCallE2eeMark? seen;
      var built = false;
      await t.pumpWidget(
        _app(
          RoomCallE2eeMarkBuilder(
            mediaController: null,
            showOpenWarning: false,
            builder: (context, mark) {
              built = true;
              seen = mark;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(built, isTrue);
      expect(seen, isNull);
    });

    test('телефон: открытый созвон при раскатке — красный открытый замок', () {
      final mark = roomCallE2eeMark(null, showOpenWarning: true, l10n: _l10n)!;
      expect(mark.icon, AdaptiveIcons.lock_open_rounded);
      expect(mark.title, _l10n.roomCallOpenBanner);
      expect(mark.alert, isFalse);
    });

    test('телефон: шифрование включено — замок, пояснение по нажатию', () {
      final mark = roomCallE2eeMark(
        const RoomCallE2eeStatus(own: RoomCallE2eeOwnState.encrypting),
        showOpenWarning: true,
        l10n: _l10n,
      )!;
      expect(mark.icon, AdaptiveIcons.lock_rounded);
      expect(mark.title, _l10n.roomCallE2eeOn);
      expect(mark.detail, _l10n.roomCallE2eeOnHint);
      expect(mark.alert, isFalse);
    });

    test('телефон: неизвестные участники — жёлтый замок и число', () {
      final calm = roomCallE2eeMark(
        const RoomCallE2eeStatus(own: RoomCallE2eeOwnState.encrypting),
        showOpenWarning: false,
        l10n: _l10n,
      )!;
      final mark = roomCallE2eeMark(
        const RoomCallE2eeStatus(
          own: RoomCallE2eeOwnState.encrypting,
          unknownParticipants: 2,
        ),
        showOpenWarning: false,
        l10n: _l10n,
      )!;
      expect(mark.color, isNot(calm.color));
      expect(mark.detail, _l10n.roomCallE2eeUnknownParticipants(2));
    });

    test('🔴 телефон: отказ говорит словами в шапке', () {
      final mark = roomCallE2eeMark(
        const RoomCallE2eeStatus(
          own: RoomCallE2eeOwnState.failed,
          errorCode: 'platform_unsupported',
        ),
        showOpenWarning: false,
        l10n: _l10n,
      )!;
      expect(mark.alert, isTrue);
      expect(mark.title, _l10n.roomCallE2eeUnsupported);
    });

    testWidgets('телефон: пояснение открывается листом', (t) async {
      final mark = roomCallE2eeMark(
        const RoomCallE2eeStatus(own: RoomCallE2eeOwnState.encrypting),
        showOpenWarning: false,
        l10n: _l10n,
      )!;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRoomCallE2eeDetails(context, mark),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text(_l10n.roomCallE2eeOn), findsOneWidget);
      expect(find.text(_l10n.roomCallE2eeOnHint), findsOneWidget);
    });
  });

  group('экран созвона телефона', () {
    // 🔴 По просьбе владельца (06.10.2026): без отдельных строк и слов там,
    // где хватает значка.
    final src = File('lib/ui/room_call_screen.dart').readAsStringSync();

    test('шифрование — знак в шапке, а не строка под ней', () {
      expect(src.contains('RoomCallE2eeBanner'), isFalse);
      expect(src.contains('RoomCallE2eeMarkBuilder('), isTrue);
      expect(src.contains('showRoomCallE2eeDetails('), isTrue);
    });

    test('на плитке нет чипа «Вы» и подписей у значков', () {
      expect(src.contains("label: _roomCallText(context, ru: 'Вы'"), isFalse);
      expect(src.contains('label: compact ?'), isFalse);
    });

    test('вход в идущий созвон — одна кнопка', () {
      expect(src.contains("ru: 'Идёт голосовой звонок'"), isFalse);
      expect(src.contains("участников уже в эфире',"), isFalse);
    });
  });
}
