// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// C-3, ПРИЁМКА: ОБХОД НЕ ВСТРЕЧАЕТ БЕЗЫМЯННЫХ ЭЛЕМЕНТОВ.
//
// Приёмка пункта записана словами «обход настроек и переписки VoiceOver'ом не
// встречает безымянных элементов». Проверять это глазами по списку виджетов
// бессмысленно: подпись может быть в исходнике и не дойти до дерева семантики
// (так и случилось с фишкой реакции — `Semantics` без `container: true` не
// создаёт узла, и метка молча пропадает). Поэтому здесь проверяется ровно то,
// что получит экранный диктор: настоящее дерево семантики после отрисовки.
//
// 🔴 ПРАВИЛО. Узел, на котором есть действие (нажатие, увеличение,
// уменьшение), обязан иметь хоть что-то произносимое: подпись, значение,
// подсказку или пояснение. Узел БЕЗ действия под правило не подпадает —
// украшение имеет право молчать, и заставлять его говорить значит портить
// обход, а не улучшать (заглушки портретов именно поэтому замолчали).
//
// Проверка — храповик: она не запрещает добавлять кнопки, она запрещает
// добавлять БЕЗЫМЯННЫЕ кнопки.

import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/chat/composer.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/reactions_popover.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

/// Разделов настроек семнадцать — как и в [desktop_settings_sections_render_test].
const int _kSections = 17;

/// Собирает узлы с действием, но без единого произносимого слова.
List<String> _unnamed(SemanticsNode n, [List<String>? acc]) {
  final out = acc ?? <String>[];
  final d = n.getSemanticsData();
  final actionable = d.hasAction(SemanticsAction.tap) ||
      d.hasAction(SemanticsAction.increase) ||
      d.hasAction(SemanticsAction.decrease);
  final speakable = d.label.trim().isNotEmpty ||
      d.value.trim().isNotEmpty ||
      d.tooltip.trim().isNotEmpty ||
      d.hint.trim().isNotEmpty;
  if (actionable && !speakable) out.add('размером ${n.rect.size}');
  n.visitChildren((c) {
    _unnamed(c, out);
    return true;
  });
  return out;
}

Future<void> _expectAllNamed(WidgetTester t, String what) async {
  await t.pumpAndSettle();
  final bad = _unnamed(t.getSemantics(find.byType(MaterialApp)));
  expect(
    bad,
    isEmpty,
    reason: '$what: нажимаемое без единого слова — ${bad.join(', ')}',
  );
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: DColors(colors: kDColorsDark, child: child)),
);

MessageData _msg({
  List<MessageReaction> reactions = const [],
  ReplyPreview? reply,
  MessageAttachment? attachment,
}) => MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Вы',
  text: attachment == null ? 'привет' : '',
  time: '14:19',
  isSelf: true,
  delivery: DeliveryStatus.read,
  reactions: reactions,
  reply: reply,
  attachment: attachment,
);

void main() {
  testWidgets('🔴 обход НАСТРОЕК: все семнадцать разделов', (t) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host(const SettingsWorkspace()));
    await t.pumpAndSettle();

    for (var i = 0; i < _kSections; i++) {
      await t.tap(find.byType(WorkspaceIconPlate).at(i));
      await _expectAllNamed(t, 'раздел настроек №$i');
    }
    handle.dispose();
  });

  testWidgets('🔴 переключатель настройки назван и сообщает состояние',
      (t) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host(const SettingsWorkspace()));
    await t.pumpAndSettle();

    // Переключатель нарисован отдельно от своей подписи: подпись — текст
    // слева, и в его узел семантики она сама по себе не попадает.
    final spoken = <String>[];
    void scan(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.flagsCollection.isToggled != Tristate.none) spoken.add(d.label);
      n.visitChildren((c) {
        scan(c);
        return true;
      });
    }

    scan(t.getSemantics(find.byType(MaterialApp)));
    expect(spoken, isNotEmpty, reason: 'переключателей на виду не оказалось');
    expect(
      spoken.where((s) => s.trim().isEmpty),
      isEmpty,
      reason: 'переключатель без имени говорит «включено», не сказав чего',
    );
    handle.dispose();
  });

  testWidgets('🔴 обход ПЕРЕПИСКИ: список, пузыри, поле ввода', (t) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host(SizedBox(
      width: 320,
      height: 600,
      child: ChatListPanel(
        items: const [
          ChatListItem(
            id: 'c1',
            name: 'Максим',
            preview: 'привет',
            time: '11:16',
            delivery: ChatDelivery.read,
            unread: 3,
          ),
          ChatListItem(id: 'c2', name: 'Команда', preview: 'файл', time: '10:02'),
        ],
        selectedId: null,
        onSelect: (_) {},
      ),
    )));
    await _expectAllNamed(t, 'список переписок');

    final bubbles = <String, MessageData>{
      'текст': _msg(),
      'реакции': _msg(reactions: const [MessageReaction(emoji: '👍', count: 2)]),
      'ответ': _msg(
        reply: const ReplyPreview(authorName: 'Игорь', text: 'что там?'),
      ),
      'голосовое': _msg(
        attachment: const MessageAttachment(
          kind: MessageAttachmentKind.voice,
          blobId: 'b1',
          payloadEventId: 'p1',
          durationMs: 4000,
          waveform: [10, 60, 30, 90],
        ),
      ),
      'картинка не скачалась': _msg(
        attachment: const MessageAttachment(
          kind: MessageAttachmentKind.image,
          blobId: 'b2',
          payloadEventId: 'p2',
          width: 800,
          height: 600,
          failed: true,
        ),
      ),
    };
    for (final e in bubbles.entries) {
      await t.pumpWidget(
        _host(SizedBox(width: 760, child: MessageBubble(message: e.value))),
      );
      await _expectAllNamed(t, 'пузырь «${e.key}»');
    }

    await t.pumpWidget(_host(SizedBox(
      width: 760,
      child: Composer(
        controller: TextEditingController(),
        onSend: (_) {},
        onAttach: () {},
        onEmoji: () {},
        onVoice: () {},
      ),
    )));
    await _expectAllNamed(t, 'поле ввода');

    // Быстрый выбор реакции — сплошь нарисованные знаки без единой подписи.
    await t.pumpWidget(_host(SizedBox(
      width: 320,
      child: QuickReactionRow(onPicked: (_) {}),
    )));
    await _expectAllNamed(t, 'быстрый выбор реакции');
    handle.dispose();
  });

  testWidgets('🔴 обход БОКОВОЙ РЕЙКИ — она вся из значков', (t) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host(SizedBox(
      height: 900,
      child: DesktopSidebar(
        active: DesktopSection.chats,
        onSelect: (_) {},
        onOpenSettings: () {},
        onOpenProfile: () {},
        selfName: 'Юрий',
        supportUnread: 2,
      ),
    )));
    await _expectAllNamed(t, 'боковая рейка');
    handle.dispose();
  });

  testWidgets('непрочитанное читается СО СЛОВОМ, а не голым числом', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_host(SizedBox(
      width: 320,
      height: 200,
      child: ChatListPanel(
        items: const [
          ChatListItem(
            id: 'c1',
            name: 'Максим',
            preview: 'привет',
            time: '11:16',
            unread: 3,
          ),
        ],
        selectedId: null,
        onSelect: (_) {},
      ),
    )));
    await t.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(
      find.bySemanticsLabel(l10n.desktopThreadUnreadCount(3)),
      findsOneWidget,
      reason: '«три» рядом со временем не говорит, чего именно три',
    );
    handle.dispose();
  });
}
