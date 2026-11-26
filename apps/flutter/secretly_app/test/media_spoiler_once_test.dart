// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// SendFlow Э5: обложка спойлера и плашка одноразового.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/chat/media_spoiler_once.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ViewOnceStore.debugReset();
    debugResetRevealedSpoilers();
  });

  testWidgets('спойлер: закрыт до касания, касание открывает', (t) async {
    var tapsBelow = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: MediaSpoilerCover(
              eventId: 'e1',
              child: GestureDetector(
                onTap: () => tapsBelow++,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('spoiler:e1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('spoiler:e1')));
    expect(tapsBelow, 0); // первое касание — только открыть
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('spoiler:e1')), findsNothing);
    await t.tap(find.byType(ColoredBox).last);
    expect(tapsBelow, 1);
  });

  testWidgets('одноразовое: получатель открывает один раз, отправитель — нет', (
    t,
  ) async {
    await ViewOnceStore.load();
    final a = AttachmentEventV1(
      eventId: 'v1',
      blobId: 'b',
      fileKeyB64: 'k',
      sizeBytes: 1,
      mime: 'image/jpeg',
      viewOnce: true,
    );
    var opened = 0;
    Widget tile(bool isMe) => MaterialApp(
      locale: const Locale('ru'),
      home: Scaffold(
        body: ViewOnceTile(
          attachment: a,
          isMe: isMe,
          color: Colors.white,
          onOpen: () => opened++,
        ),
      ),
    );
    await t.pumpWidget(tile(true));
    await t.tap(find.byKey(const ValueKey('view-once:v1')));
    expect(opened, 0);
    await t.pumpWidget(tile(false));
    await t.tap(find.byKey(const ValueKey('view-once:v1')));
    expect(opened, 1);
    await t.runAsync(() => ViewOnceStore.markOpened('v1'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('view-once:v1')));
    expect(opened, 1);
    expect(ViewOnceStore.isOpened('v1'), isTrue);
  });
}
