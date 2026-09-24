// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Мини-окно свёрнутого звонка (24.09.2026, владелец: «не могу никак скрыть
// этот звонок или свернуть в мини окно, чтобы пользоваться дальше
// приложением»; групповой созвон «не должен мешать пользоваться другими
// чатами»).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/calls/active_call_bar.dart';
import 'package:secretly_app/ui/desktop/calls/call_mini_window.dart';
import 'package:secretly_app/ui/desktop/calls/call_presence.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

Widget _host(Widget child, {Size size = const Size(1200, 800)}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox.fromSize(size: size, child: child)),
  ),
);

void main() {
  group('где стоит мини-окно', () {
    const area = Size(1200, 800);
    const card = Size(288, 124);
    const insets = kDesktopCallMiniInsets;

    test('углы — с отступами от того, что под ними лежит', () {
      expect(
        desktopCallMiniOrigin(
          corner: DesktopCallMiniCorner.topRight,
          area: area,
          size: card,
        ),
        Offset(area.width - insets.right - card.width, insets.top),
      );
      expect(
        desktopCallMiniOrigin(
          corner: DesktopCallMiniCorner.bottomLeft,
          area: area,
          size: card,
        ),
        Offset(insets.left, area.height - insets.bottom - card.height),
      );
    });

    test('🔴 в маленьком окне прижимается к краю, а не уходит за него', () {
      final o = desktopCallMiniOrigin(
        corner: DesktopCallMiniCorner.bottomRight,
        area: const Size(300, 150),
        size: card,
      );
      expect(o.dx, inInclusiveRange(0, 300 - card.width));
      expect(o.dy, inInclusiveRange(0, 150 - card.height));
    });

    test('отпущенное прилипает к ближайшему углу', () {
      expect(
        desktopCallMiniNearestCorner(center: const Offset(100, 100), area: area),
        DesktopCallMiniCorner.topLeft,
      );
      expect(
        desktopCallMiniNearestCorner(center: const Offset(1100, 700), area: area),
        DesktopCallMiniCorner.bottomRight,
      );
    });

    test('испорченная настройка угла — правый верхний', () {
      expect(desktopCallMiniCornerFrom('???'), DesktopCallMiniCorner.topRight);
      expect(desktopCallMiniCornerFrom(null), DesktopCallMiniCorner.topRight);
      expect(
        desktopCallMiniCornerFrom('bottomLeft'),
        DesktopCallMiniCorner.bottomLeft,
      );
    });

    test('время разговора', () {
      expect(desktopCallMiniDuration(0, nowMs: 65000), '01:05');
      expect(desktopCallMiniDuration(0, nowMs: 3725000), '1:02:05');
      expect(desktopCallMiniDuration(1000, nowMs: 0), '00:00');
    });
  });

  group('слой мини-окон', () {
    testWidgets('🔴 мимо мини-окна нажатия проходят в приложение', (t) async {
      var underneath = 0;
      await t.pumpWidget(
        _host(
          Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => underneath++,
                ),
              ),
              Positioned.fill(
                child: DesktopCallMiniLayer(
                  corner: DesktopCallMiniCorner.topRight,
                  onCornerChanged: (_) {},
                  entries: [
                    DesktopCallMiniEntry(
                      id: 'x',
                      size: const Size(288, 124),
                      child: Container(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await t.tapAt(const Offset(300, 400));
      expect(underneath, 1);
    });

    testWidgets('утащил и отпустил — прилипает к углу и запоминается',
        (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final corners = <DesktopCallMiniCorner>[];
      await t.pumpWidget(
        _host(
          DesktopCallMiniLayer(
            corner: DesktopCallMiniCorner.topRight,
            onCornerChanged: corners.add,
            entries: [
              DesktopCallMiniEntry(
                id: 'x',
                size: const Size(288, 124),
                child: Container(key: const Key('card'), color: Colors.red),
              ),
            ],
          ),
        ),
      );
      await t.drag(find.byKey(const Key('card')), const Offset(-800, 500));
      await t.pumpAndSettle();
      expect(corners, [DesktopCallMiniCorner.bottomLeft]);
      final at = t.getTopLeft(find.byKey(const Key('card')));
      expect(at.dx, kDesktopCallMiniInsets.left);
      expect(at.dy, 800 - kDesktopCallMiniInsets.bottom - 124);
    });

    testWidgets('два звонка — два мини-окна одним столбиком', (t) async {
      await t.pumpWidget(
        _host(
          DesktopCallMiniLayer(
            corner: DesktopCallMiniCorner.topRight,
            onCornerChanged: (_) {},
            entries: [
              for (final id in ['a', 'b'])
                DesktopCallMiniEntry(
                  id: id,
                  size: const Size(288, 124),
                  child: Container(key: Key('card-$id'), color: Colors.red),
                ),
            ],
          ),
        ),
      );
      final a = t.getTopLeft(find.byKey(const Key('card-a')));
      final b = t.getTopLeft(find.byKey(const Key('card-b')));
      expect(b.dx, a.dx);
      expect(b.dy - a.dy, 124 + kDesktopCallMiniGap);
    });
  });

  group('вид звонка', () {
    setUp(DesktopCallPresence.instance.debugReset);
    tearDown(DesktopCallPresence.instance.debugReset);

    test('🔴 новый звонок открывается во всё окно', () {
      final p = DesktopCallPresence.instance;
      p.syncDirect(active: true, callId: 'a');
      p.minimizeDirect();
      expect(p.directMinimized.value, isTrue);
      // Тот же звонок — остаётся свёрнутым.
      p.syncDirect(active: true, callId: 'a');
      expect(p.directMinimized.value, isTrue);
      // Следующий звонок — во всё окно.
      p.syncDirect(active: true, callId: 'b');
      expect(p.directMinimized.value, isFalse);
    });

    test('🔴 запоздалое «закрылось» от старого окна не гасит новое', () {
      final p = DesktopCallPresence.instance;
      final oldWindow = Object();
      final newWindow = Object();
      p.roomWindowOpened('room', oldWindow);
      p.roomWindowOpened('room', newWindow);
      p.roomWindowClosed(oldWindow);
      expect(p.roomWindowOpen.value, 'room');
      p.roomWindowClosed(newWindow);
      expect(p.roomWindowOpen.value, isNull);
    });

    test('имя комнаты помнится, когда её уже не открыть', () {
      final p = DesktopCallPresence.instance;
      p.rememberRoomTitle('r1', ' Команда ');
      p.rememberRoomTitle('r1', '');
      expect(p.roomTitle('r1'), 'Команда');
    });
  });

  group('полоса: звонок один на один', () {
    CallState st(CallPhase phase, {bool muted = false}) => CallState.empty
        .copyWith(
          phase: phase,
          callId: 'c1',
          peerProfileId: 'p1',
          peerName: 'Анна',
          isMuted: muted,
        );

    testWidgets('идёт звонок — полоса с кнопками, и они работают', (t) async {
      final direct = ValueNotifier<CallState>(st(CallPhase.connected));
      final ui = <String>[];
      await t.pumpWidget(
        _host(
          DesktopActiveCallBar(
            titleFor: (_) => '',
            onReturn: (_, _) {},
            onToggleMic: () async {},
            direct: direct,
            onDirectReturn: () => ui.add('return'),
            onDirectToggleMic: () async => ui.add('mic'),
            onDirectEnd: () => ui.add('end'),
          ),
        ),
      );
      expect(find.text('Идёт звонок · Анна'), findsOneWidget);
      await t.tap(find.byTooltip('Выключить микрофон'));
      await t.tap(find.byTooltip('Завершить'));
      await t.tap(find.text('Вернуться'));
      expect(ui, ['mic', 'end', 'return']);
    });

    testWidgets('входящий, ещё не взятый, — полосы нет', (t) async {
      final direct = ValueNotifier<CallState>(st(CallPhase.ringingIncoming));
      await t.pumpWidget(
        _host(
          DesktopActiveCallBar(
            titleFor: (_) => '',
            onReturn: (_, _) {},
            onToggleMic: () async {},
            direct: direct,
          ),
        ),
      );
      expect(find.textContaining('Анна'), findsNothing);
      // И звонок кончился — полоса уходит сама.
      direct.value = st(CallPhase.connected);
      await t.pump();
      expect(find.textContaining('Анна'), findsOneWidget);
      direct.value = CallState.empty;
      await t.pump();
      expect(find.textContaining('Анна'), findsNothing);
    });
  });

  group('окно группового созвона', () {
    final win = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();

    test('🔴 «Свернуть» — в доке, а не только стрелкой в углу', () {
      expect(win.contains('label: _l10n.callMinimize'), isTrue);
      expect(win.contains('onTap: _minimize,'), isTrue);
      // Свернуть — значит свернуть: окно уходит, созвон остаётся.
      final i = win.indexOf('void _minimize() {');
      expect(i, greaterThan(0));
      final body = win.substring(i, i + 200);
      expect(body.contains('roomWindowClosed(this)'), isTrue);
      expect(body.contains('maybePop()'), isTrue);
      expect(body.contains('_leave'), isFalse);
    });

    test('окно сообщает, что открыто, — и мини-окна в это время нет', () {
      expect(win.contains('presence.roomWindowOpened(widget.groupId, this)'), isTrue);
      expect(win.contains('DesktopCallPresence.instance.roomWindowClosed(owner)'), isTrue);
      // Сообщает ПОСЛЕ кадра: посреди постройки дерева перестраивать его нельзя.
      expect(win.contains('addPostFrameCallback'), isTrue);
    });

    test('Esc сворачивает, ⌘D / ⌘E / ⌘W — микрофон, камера, выход', () {
      expect(win.contains('onKeyEvent: _onKey'), isTrue);
      expect(win.contains('LogicalKeyboardKey.escape'), isTrue);
      expect(win.contains('LogicalKeyboardKey.keyD'), isTrue);
      expect(win.contains('LogicalKeyboardKey.keyE'), isTrue);
      expect(win.contains('LogicalKeyboardKey.keyW'), isTrue);
    });

    test('🔴 на Windows у окна созвона есть свои кнопки окна', () {
      expect(win.contains('if (isWindows) const DesktopWindowsCaptionButtons()'), isTrue);
      expect(win.contains('DesktopWindowDragRegion()'), isTrue);
    });

    test('🔴 отказы движка и релея — словами над доком', () {
      expect(win.contains('localMedia.errorMessage'), isTrue);
      expect(win.contains('(_actionError ?? _mediaProblem())'), isTrue);
      expect(win.contains('throw StateError(_l10n.desktopCallLeaveFailed)'), isTrue);
      expect(win.contains('throw StateError(_l10n.desktopCallToggleFailed)'), isTrue);
    });

    test('«Экран» и «Сетка» не красные, когда выключены', () {
      expect('neutralWhenOff: true'.allMatches(win).length, greaterThanOrEqualTo(2));
      expect(win.contains('highlighted: shareOn'), isTrue);
    });
  });

  test('🔴 окна звонков не обещают сочетаний строкой перевода', () {
    // Раньше «⌘D» было вшито в перевод и на Windows называло клавишу,
    // которой на её клавиатуре нет. Подпись собирается по системе.
    for (final f in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!f.path.endsWith('.arb')) continue;
      expect(f.readAsStringSync().contains('desktopCallCtlMicOn'), isFalse, reason: f.path);
    }
    if (!kIsWeb) {
      expect(
        File('lib/ui/desktop/calls/call_controls.dart')
            .readAsStringSync()
            .contains("Platform.isMacOS) ? '⌘\$key' : 'Ctrl+\$key'"),
        isTrue,
      );
    }
  });
}
