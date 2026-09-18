// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Плашка «Идёт обсуждение» говорит только то, что знает.
//
// 🔴 Главное здесь — не вид, а ГРАНИЦА ЧЕСТНОСТИ.
//
// В макете под заголовком стоит «Игорь говорит · 3 участника · 12:41». Признак
// `speaking` в снимке созвона есть, но заполняет его LiveKit и только тому,
// кто уже внутри: снимок с релея активного говорящего не несёт. Для человека
// снаружи это поле — мусор неизвестной свежести.
//
// Плашка, один раз сказавшая «Игорь говорит» про молчащего Игоря, обесценивает
// себя целиком: дальше человек не верит ни счётчику, ни времени. Поэтому
// проверка сторожит не только то, что плашка показывает, но и то, чего она
// показывать НЕ должна.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/rooms/room_call_state.dart';
import 'package:secretly_app/ui/desktop/chat/room_call_banner.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

CachedRoomCallParticipant _p(
  String profileId, {
  String joinState = 'joined',
  bool speaking = false,
}) => CachedRoomCallParticipant(
  profileId: profileId,
  deviceId: '$profileId-1',
  joinState: joinState,
  supportsVideo: true,
  supportsScreenShare: false,
  muted: false,
  deafened: false,
  videoEnabled: false,
  screenShareEnabled: false,
  speaking: speaking,
  joinedAtMs: 1000,
  leftAtMs: null,
  updatedAtMs: 1000,
);

CachedRoomCall _call({
  String state = 'active',
  int? endedAtMs,
  int startedAtMs = 0,
  List<CachedRoomCallParticipant>? participants,
  CachedRoomCallParticipant? self,
}) => CachedRoomCall(
  roomId: 'group:core',
  callId: 'c1',
  state: state,
  mediaType: 'audio',
  createdByProfileId: 'igor',
  createdByDeviceId: 'igor-1',
  stateVersion: 7,
  startedAtMs: startedAtMs,
  updatedAtMs: startedAtMs,
  endedAtMs: endedAtMs,
  expiresAtMs: startedAtMs + 3600000,
  participants: participants ?? <CachedRoomCallParticipant>[_p('igor')],
  selfParticipant: self,
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 720, child: child),
      ),
    ),
  ),
);

void main() {
  group('что плашка показывает', () {
    testWidgets('участники и длительность — из снимка', (t) async {
      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(
              startedAtMs: 0,
              participants: <CachedRoomCallParticipant>[
                _p('igor'),
                _p('anna'),
                _p('lena'),
              ],
            ),
            onJoin: () {},
            nowMs: () => 761000, // 12 минут 41 секунда
          ),
        ),
      );
      await t.pump();

      expect(find.text('Идёт обсуждение'), findsOneWidget);
      expect(find.text('3 участника · 12:41'), findsOneWidget);
    });

    testWidgets('вышедшие в счёт не идут', (t) async {
      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(
              participants: <CachedRoomCallParticipant>[
                _p('igor'),
                _p('anna', joinState: 'left'),
              ],
            ),
            onJoin: () {},
            nowMs: () => 5000,
          ),
        ),
      );
      await t.pump();

      expect(find.textContaining('1 участник ·'), findsOneWidget);
    });

    testWidgets('🔴 не пишет, кто говорит — этого мы не знаем', (t) async {
      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(
              participants: <CachedRoomCallParticipant>[
                _p('igor', speaking: true),
              ],
            ),
            onJoin: () {},
            nowMs: () => 5000,
          ),
        ),
      );
      await t.pump();

      expect(
        find.textContaining('говорит'),
        findsNothing,
        reason:
            'признак speaking снаружи созвона недостоверен — см. шапку '
            'файла; строку нельзя вернуть, пока её не начнёт присылать релей',
      );
    });
  });

  group('кнопка', () {
    testWidgets('снаружи — «Присоединиться», внутри — «Вернуться»', (t) async {
      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(),
            onJoin: () {},
            nowMs: () => 5000,
          ),
        ),
      );
      await t.pump();
      expect(find.text('Присоединиться'), findsOneWidget);

      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(self: _p('me')),
            onJoin: () {},
            nowMs: () => 5000,
          ),
        ),
      );
      await t.pump();
      expect(
        find.text('Вернуться'),
        findsOneWidget,
        reason:
            'предложить «присоединиться» тому, кто уже внутри, — '
            'это заставить его гадать, не выкинуло ли его из созвона',
      );
    });

    testWidgets('нажатие ведёт в созвон', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          DesktopRoomCallBanner(
            call: _call(),
            onJoin: () => taps++,
            nowMs: () => 5000,
          ),
        ),
      );
      await t.pump();

      await t.tap(find.text('Присоединиться'));
      await t.pump();
      expect(taps, 1);
    });
  });

  group('длительность', () {
    test('до часа — MM:SS, после — H:MM:SS', () {
      String d(int ms) => formatRoomCallDuration(0, ms);

      expect(d(0), '00:00');
      expect(d(9000), '00:09');
      expect(d(761000), '12:41');
      expect(d(3599000), '59:59');
      expect(d(3600000), '1:00:00');
      expect(d(7325000), '2:02:05');
    });

    test('🔴 часы собеседника убежали вперёд — ноль, а не минус', () {
      // Время начала приходит с чужого устройства. «-03:12» на плашке выглядит
      // поломкой приложения, хотя поломаны часы.
      expect(formatRoomCallDuration(100000, 0), '00:00');
    });
  });

  group('склонение участников', () {
    test('обычные случаи', () {
      expect(formatParticipantsRu(1), '1 участник');
      expect(formatParticipantsRu(2), '2 участника');
      expect(formatParticipantsRu(4), '4 участника');
      expect(formatParticipantsRu(5), '5 участников');
      expect(formatParticipantsRu(21), '21 участник');
      expect(formatParticipantsRu(22), '22 участника');
    });

    test('🔴 подростковые числа — исключение из правила', () {
      // 11–14 склоняются как «много», хотя оканчиваются на 1–4. Классическая
      // ошибка в русских счётчиках: «11 участник».
      expect(formatParticipantsRu(11), '11 участников');
      expect(formatParticipantsRu(12), '12 участников');
      expect(formatParticipantsRu(14), '14 участников');
      expect(formatParticipantsRu(111), '111 участников');
    });
  });

  group('когда созвона нет', () {
    test('завершённый и неактивный созвон не считаются живыми', () {
      // Плашку строит секция чатов по этому признаку — он и есть выключатель.
      expect(_call().isActive, isTrue);
      expect(_call(endedAtMs: 5).isActive, isFalse);
      expect(_call(state: 'ended').isActive, isFalse);
    });
  });
}
