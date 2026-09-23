// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// C-3 — НАРИСОВАННОЕ ДОЛЖНО НАЗЫВАТЬСЯ ВСЛУХ.
//
// В `lib/ui/desktop` не было НИ ОДНОГО `Semantics(` на 67 тысяч строк. Часть
// окна при этом уже называлась сама: в проекте 132 подсказки, а `Tooltip`
// кладёт свой текст в семантику без просьбы. Молчало именно нарисованное —
// галочки доставки, волна голосового, фишки реакций: [Icon] и [Container] без
// подписи не создают узла семантики вовсе.
//
// 🔴 ПОЧЕМУ ЭТО НЕ КОСМЕТИКА. Галочка — это не украшение, а ответ на вопрос
// «моё сообщение ушло?». Незрячий слышал текст и время и не слышал состояния,
// то есть не мог отличить отправленное от застрявшего. Для мессенджера это
// разница между «сказал» и «не сказал».
//
// Обратная половина той же работы — ЗАМОЛЧАТЬ ТАМ, ГДЕ ЧИТАТЬ НЕЧЕГО.
// Инициалы в заглушке портрета диктор произносил по буквам («Ю-А») прямо перед
// настоящим именем, которое стоит рядом. Подпись у украшения делает обход
// хуже, а не лучше, поэтому здесь проверяется и то, что подписи НЕТ.

import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/widgets/avatar_initials.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: Center(child: child)),
  ),
);

MessageData _msg({
  DeliveryStatus delivery = DeliveryStatus.delivered,
  List<MessageReaction> reactions = const <MessageReaction>[],
}) => MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Вы',
  text: 'привет',
  time: '14:19',
  isSelf: true,
  delivery: delivery,
  reactions: reactions,
);

void main() {
  testWidgets('каждое состояние доставки называется вслух', (t) async {
    final handle = t.ensureSemantics();
    for (final status in DeliveryStatus.values) {
      await t.pumpWidget(
        _host(
          Builder(
            builder: (ctx) => deliveryTickGlyph(
              status,
              const Color(0xFF999999),
              semanticsLabel: deliveryStatusLabel(
                status,
                AppLocalizations.of(ctx)!,
              ),
            ),
          ),
        ),
      );
      final label = deliveryStatusLabel(
        status,
        await AppLocalizations.delegate.load(const Locale('ru')),
      );
      expect(
        find.bySemanticsLabel(label),
        findsOneWidget,
        reason: 'состояние $status обязано называться вслух',
      );
    }
    handle.dispose();
  });

  test('🔴 у шести состояний ШЕСТЬ разных подписей', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    final labels = DeliveryStatus.values
        .map((s) => deliveryStatusLabel(s, l10n))
        .toList();
    // Две одинаковые подписи означали бы, что на слух состояния слиплись —
    // ровно та беда, от которой на глаз спасает число галочек.
    expect(labels.toSet(), hasLength(DeliveryStatus.values.length));
    expect(labels.any((s) => s.trim().isEmpty), isFalse);
  });

  testWidgets('🔴 инициалы портрета ВСЛУХ НЕ ЧИТАЮТСЯ', (t) async {
    final handle = t.ensureSemantics();
    const name = 'Игорь Ковальчук';
    final initials = AvatarInitials.label(displayName: name);
    await t.pumpWidget(_host(const Avatar(name: name)));

    // Нарисованы — да; произнесены — нет.
    expect(find.text(initials), findsOneWidget);
    expect(
      find.bySemanticsLabel(initials),
      findsNothing,
      reason: 'диктор не должен читать «$initials» перед самим именем',
    );
    handle.dispose();
  });

  testWidgets('нажимаемый портрет называется именем', (t) async {
    final handle = t.ensureSemantics();
    const name = 'Игорь Ковальчук';
    await t.pumpWidget(_host(Avatar(name: name, onTap: () {})));
    expect(find.bySemanticsLabel(name), findsOneWidget);
    handle.dispose();
  });

  testWidgets('фишка реакции: эмодзи подписью, счётчик значением', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        SizedBox(
          width: 760,
          child: MessageBubble(
            message: _msg(
              reactions: const [MessageReaction(emoji: '👍', count: 3)],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final node = t.getSemantics(find.bySemanticsLabel('👍'));
    expect(node.value, '3', reason: 'счётчик обязан звучать как значение фишки');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('🔴 «моя» реакция помечена, а чужая — нет', (t) async {
    final handle = t.ensureSemantics();
    for (final mine in [true, false]) {
      await t.pumpWidget(
        _host(
          SizedBox(
            width: 760,
            child: MessageBubble(
              message: _msg(
                reactions: [
                  MessageReaction(emoji: '❤️', count: 1, byMe: mine),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final node = t.getSemantics(find.bySemanticsLabel('❤️'));
      // `isSelected` трёхзначен: «да», «нет» и «свойство неприменимо».
      expect(
        node.flagsCollection.isSelected,
        mine ? Tristate.isTrue : Tristate.isFalse,
        reason: 'на глаз это видно по насыщенности — на слух должно быть тоже',
      );
    }
    handle.dispose();
  });

  testWidgets('волна голосового называется и сообщает, сколько проиграно',
      (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        SizedBox(
          width: 760,
          child: MessageBubble(
            message: _msg().copyWith(
              text: '',
              attachment: const MessageAttachment(
                kind: MessageAttachmentKind.voice,
                blobId: 'b1',
                payloadEventId: 'p1',
                durationMs: 4000,
                waveform: [10, 40, 80, 30, 60, 20, 90, 15],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(find.bySemanticsLabel(l10n.desktopA11yVoiceProgress), findsOneWidget);
    handle.dispose();
  });

  testWidgets('🔴 голосовой пузырь размечается БЕЗ исключений', (t) async {
    // Найдено при проверке доступности, но это не про доступность.
    //
    // Волна рисовалась внутри [LayoutBuilder], который вычислял ширину ради
    // ветки `if (w.isNaN)` — невозможной. А пузырь обёрнут в [IntrinsicWidth],
    // и [LayoutBuilder] на вопрос о естественной ширине отвечать не умеет:
    // в отладке это исключение на КАЖДОМ голосовом, в выпуске — молчаливый
    // ноль вместо ширины. Проверка держит строитель разметки подальше отсюда.
    await t.pumpWidget(
      _host(
        SizedBox(
          width: 760,
          child: MessageBubble(
            message: _msg().copyWith(
              text: '',
              attachment: const MessageAttachment(
                kind: MessageAttachmentKind.voice,
                blobId: 'b1',
                payloadEventId: 'p1',
                durationMs: 4000,
                waveform: [5, 50, 95, 20],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
