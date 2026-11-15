// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// ДВИЖЕНИЕ ПК (05.10.2026, владелец: «всё плавным, приятным, дорогим; где
// можно — трансформация кнопок; не детские и не плоские анимации; и чтобы
// работало быстро»). Правила — в `lib/ui/desktop/design/motion.dart`.
//
// Здесь — то, что легко сломать незаметно:
//  · смена значка и подписи ПЕРЕТЕКАЕТ, а не подменяется;
//  · «уменьшить движение» в системе — всё сразу, без анимаций;
//  · 🔴 содержимое под переходом НЕ ПЕРЕСОЗДАЁТСЯ в последнем кадре (иначе
//    лента теряет прокрутку, поля окна — набранное и фокус);
//  · отметка выбора на рейке ЕДЕТ через промежуточные места;
//  · пришедшее при открытой переписке въезжает, а загруженное при открытии —
//    нет;
//  · уход окна короче входа.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/motion.dart';
import 'package:secretly_app/ui/desktop/primitives/motion_widgets.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: DColors(
      colors: kDColorsDark,
      child: Scaffold(body: child),
    ),
  ),
);

/// Ребёнок, который считает, сколько раз его СОЗДАЛИ.
class _Probe extends StatefulWidget {
  const _Probe();
  static int created = 0;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

MessageData _msg(String id, String text, {bool self = false}) => MessageData(
  id: id,
  authorName: self ? 'Я' : 'Игорь',
  text: text,
  time: '12:00',
  isSelf: self,
  isTextMessage: true,
);

void main() {
  group('превращение значков и подписей', () {
    testWidgets('🔴 значок перетекает: в середине видны оба, в конце один', (
      t,
    ) async {
      var icon = Icons.mic;
      late StateSetter set;
      await t.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, s) {
              set = s;
              return Center(child: DMorphIcon(icon, size: 20));
            },
          ),
        ),
      );
      set(() => icon = Icons.mic_off);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byIcon(Icons.mic), findsOneWidget, reason: 'старый уходит');
      expect(find.byIcon(Icons.mic_off), findsOneWidget, reason: 'новый идёт');
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('«уменьшить движение» — значок сменяется сразу', (t) async {
      var icon = Icons.mic;
      late StateSetter set;
      await t.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, s) {
              set = s;
              return Center(child: DMorphIcon(icon, size: 20));
            },
          ),
          reduce: true,
        ),
      );
      set(() => icon = Icons.mic_off);
      await t.pump();
      await t.pump();
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('подпись перетекает, диктору — только нынешняя', (t) async {
      final semantics = t.ensureSemantics();
      var text = 'Выбрано: 1';
      late StateSetter set;
      await t.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, s) {
              set = s;
              return Center(child: DMorphText(text));
            },
          ),
        ),
      );
      set(() => text = 'Выбрано: 2');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Выбрано: '), findsNWidgets(2));
      // Обходим настоящее дерево доступности: в нём только нынешняя подпись.
      final labels = <String>[];
      void visit(SemanticsNode n) {
        if (n.label.isNotEmpty) labels.add(n.label);
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }
      visit(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(labels.any((l) => l.contains('Выбрано: 2')), isTrue);
      expect(labels.any((l) => l.contains('Выбрано: 1')), isFalse);
      await t.pumpAndSettle();
      expect(find.text('Выбрано: 2'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('🔴 переход не пересоздаёт содержимое в последнем кадре', () {
    testWidgets('DAppear', (t) async {
      _Probe.created = 0;
      await t.pumpWidget(_host(const DAppear(child: _Probe())));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      expect(_Probe.created, 1);
    });

    testWidgets('DPopTransition', (t) async {
      _Probe.created = 0;
      final c = AnimationController(
        vsync: const TestVSync(),
        duration: DMotion.modalIn,
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        _host(DPopTransition(animation: c, child: const _Probe())),
      );
      unawaited(c.forward());
      await t.pumpAndSettle();
      await t.pump();
      expect(_Probe.created, 1);
    });

    testWidgets('DPageSwitcher: страница живёт после перехода', (t) async {
      _Probe.created = 0;
      var page = 1;
      late StateSetter set;
      await t.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, s) {
              set = s;
              return DPageSwitcher(
                child: KeyedSubtree(
                  key: ValueKey<int>(page),
                  child: page == 1 ? const SizedBox() : const _Probe(),
                ),
              );
            },
          ),
        ),
      );
      set(() => page = 2);
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      expect(_Probe.created, 1);
    });
  });

  testWidgets('🔴 отметка рейки ЕДЕТ к новому разделу, а не перескакивает', (
    t,
  ) async {
    var active = DesktopSection.chats;
    late StateSetter set;
    await t.pumpWidget(
      _host(
        SizedBox(
          height: 900,
          child: StatefulBuilder(
            builder: (ctx, s) {
              set = s;
              return DesktopSidebar(active: active, onSelect: (_) {});
            },
          ),
        ),
      ),
    );
    // Полоска у края — белая, 4 в ширину; её «верх» и есть место отметки.
    final strip = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.color == Colors.white;
    });
    final from = t.getRect(strip).center.dy;
    set(() => active = DesktopSection.contacts);
    await t.pump();
    await t.pump(DMotion.glide ~/ 2);
    final mid = t.getRect(strip).center.dy;
    await t.pumpAndSettle();
    final to = t.getRect(strip).center.dy;
    expect(to, greaterThan(from));
    expect(mid, greaterThan(from), reason: 'отметка тронулась');
    expect(mid, lessThan(to), reason: 'и ещё в пути — не перескочила');
    // На месте — снова ровно 4×18.
    expect(t.getSize(strip), const Size(4, 18));
  });

  group('лента переписки', () {
    Widget panel(List<MessageData> messages) => _host(
      SizedBox(
        width: 900,
        height: 700,
        child: ChatThreadPanel(
          header: const ChatHeader(name: 'Игорь'),
          isDirect: true,
          messages: messages,
          onSend: (_) {},
        ),
      ),
    );

    double? arrivalFactor(WidgetTester t, String text) {
      final f = find.ancestor(
        // В пузыре текст — часть богатого текста: ищем вхождение.
        of: find.textContaining(text),
        matching: find.byType(SizeTransition),
      );
      if (f.evaluate().isEmpty) return null;
      return t.widget<SizeTransition>(f.first).sizeFactor.value;
    }

    testWidgets('🔴 пришедшее при открытой переписке въезжает', (t) async {
      final first = [_msg('1', 'Привет'), _msg('2', 'Как дела?')];
      await t.pumpWidget(panel(first));
      await t.pumpAndSettle();
      // Загруженное при открытии не въезжает.
      expect(arrivalFactor(t, 'Привет'), isNull);

      await t.pumpWidget(panel([...first, _msg('3', 'Отлично!', self: true)]));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      final mid = arrivalFactor(t, 'Отлично!');
      expect(mid, isNotNull);
      expect(mid!, greaterThan(0));
      expect(mid, lessThan(1), reason: 'место под строкой ещё раскрывается');
      await t.pumpAndSettle();
      expect(arrivalFactor(t, 'Отлично!'), 1);
    });

    testWidgets('пачка из истории не въезжает', (t) async {
      final first = [_msg('1', 'Привет')];
      await t.pumpWidget(panel(first));
      await t.pumpAndSettle();
      // Семь сразу — это досинхронизация, а не разговор.
      final batch = [
        for (var i = 0; i < 7; i++) _msg('b$i', 'Из пачки $i'),
      ];
      await t.pumpWidget(panel([...first, ...batch]));
      await t.pump();
      expect(arrivalFactor(t, 'Из пачки 6'), isNull);
    });
  });

  testWidgets('уход окна короче входа', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final route = DesktopOverlayRoute<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    expect(route.transitionDuration, DMotion.modalIn);
    expect(route.reverseTransitionDuration, DMotion.modalOut);
    expect(
      route.reverseTransitionDuration,
      lessThan(route.transitionDuration),
    );
    // И при «уменьшить движение» showDesktopOverlay даёт нулевые.
    expect(DMotion.of(ctx, DMotion.modalIn), DMotion.modalIn);
  });
}
