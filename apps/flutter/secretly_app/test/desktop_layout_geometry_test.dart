// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/shell/resizable_divider.dart';

/// Locks the pane and bubble proportions that were tuned against desktop
/// Telegram side by side.
///
/// These are single numbers with no compiler holding them in place, and they
/// are exactly the kind of value that drifts back to a "nicer looking" default
/// during unrelated work. Each one below was a visible defect before it was
/// changed, so each gets a line here.
void main() {
  group('bubble measure', () {
    test('a bubble never spans the pane', () {
      // Was 0.92, which produced ~700px single-line sentences on a wide window:
      // the eye has to travel the whole pane to find the start of the next
      // line. Telegram keeps the measure well short of the edge.
      expect(kBubbleWidthFactor, lessThanOrEqualTo(0.75));

      // ...but not so narrow that ordinary sentences turn into a ragged column.
      expect(kBubbleWidthFactor, greaterThanOrEqualTo(0.6));
    });

    test('a maximised window cannot undo the fraction', () {
      // Without the cap, 0.72 of a 1600px pane is still a 1150px line.
      expect(kBubbleMaxWidthSelf, lessThanOrEqualTo(600));
      expect(kBubbleMaxWidthSelf, greaterThanOrEqualTo(420));
      expect(kBubbleMaxWidthPeer, lessThanOrEqualTo(660));
      expect(kBubbleMaxWidthPeer, greaterThanOrEqualTo(420));
    });

    test('· чужой пузырь шире своего — у него слева ещё портрет', () {
      // Одно число на обе стороны обрезало чужой пузырь раньше своего, хотя
      // места ему остаётся МЕНЬШЕ: длинное чужое сообщение ломалось на лишние
      // строки там, где своё того же размера умещалось.
      expect(kBubbleMaxWidthPeer, greaterThan(kBubbleMaxWidthSelf));
    });
  });

  group('resizable divider', () {
    testWidgets('the grab area is wider than the line it draws', (t) async {
      // A 1px hit target cannot be hit with a mouse. The visible line stays
      // thin on purpose; the invisible hit area is what makes it usable.
      await t.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(children: [
            ResizableDivider(onDelta: (_) {}),
          ]),
        ),
      ));

      final box = t.renderObject<RenderBox>(find.byType(ResizableDivider));
      expect(box.size.width, greaterThanOrEqualTo(6),
          reason: 'divider hit area collapsed to the visible line width');
    });

    testWidgets('horizontal drags are reported to the parent', (t) async {
      final deltas = <double>[];
      await t.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(children: [
            ResizableDivider(onDelta: deltas.add),
            const Expanded(child: SizedBox()),
          ]),
        ),
      ));

      await t.drag(find.byType(ResizableDivider), const Offset(120, 0));
      await t.pump();

      expect(deltas, isNotEmpty,
          reason: 'dragging the pane edge reported nothing — the list cannot '
              'be resized');
      expect(deltas.reduce((a, b) => a + b), greaterThan(0),
          reason: 'drag direction inverted: dragging right must widen');
    });
  });
}
