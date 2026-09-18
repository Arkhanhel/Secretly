// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/chat_message_mentions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resolveChatMessageMentions prefers longest token and ignores embedded handles',
    () {
      const text = 'Hi @alice and @all, but not mail@test.com';
      final mentions = resolveChatMessageMentions(
        text: text,
        candidates: const <ChatMentionCandidate>[
          ChatMentionCandidate(
            token: '@al',
            type: MsgMentionV1.profileType,
            profileId: 'short',
          ),
          ChatMentionCandidate(
            token: '@alice',
            type: MsgMentionV1.profileType,
            profileId: 'peer-1',
          ),
          ChatMentionCandidate(token: '@all', type: MsgMentionV1.allType),
          ChatMentionCandidate(
            token: '@test',
            type: MsgMentionV1.profileType,
            profileId: 'embedded',
          ),
        ],
      );

      expect(mentions, hasLength(2));
      expect(text.substring(mentions[0].start, mentions[0].end), '@alice');
      expect(mentions[0].profileId, 'peer-1');
      expect(text.substring(mentions[1].start, mentions[1].end), '@all');
      expect(mentions[1].isAll, isTrue);
    },
  );

  testWidgets(
    'buildChatMessageTextSpans makes profile mentions tappable and highlights targeted mentions',
    (tester) async {
      var tappedProfileId = '';
      late List<InlineSpan> spans;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) {
                const baseStyle = TextStyle(fontSize: 16, height: 1.25);
                spans = buildChatMessageTextSpans(
                  context: context,
                  text: 'Hi @alice and @admins',
                  mentions: const <MsgMentionV1>[
                    MsgMentionV1(
                      type: MsgMentionV1.profileType,
                      start: 3,
                      end: 9,
                      profileId: 'peer-1',
                    ),
                    MsgMentionV1(
                      type: MsgMentionV1.adminsType,
                      start: 14,
                      end: 21,
                    ),
                  ],
                  baseStyle: baseStyle,
                  isOutgoing: false,
                  selfProfileId: 'peer-1',
                  currentUserCanReceiveAdminMentions: true,
                  onProfileMentionTap: (profileId) {
                    tappedProfileId = profileId;
                  },
                );
                return RichText(
                  text: TextSpan(
                    style: baseStyle,
                    children: spans,
                  ),
                );
              },
            ),
          ),
        ),
      );

      final aliceFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '@alice',
      );
      expect(aliceFinder, findsOneWidget);

      await tester.tap(aliceFinder);
      await tester.pump();

      expect(tappedProfileId, 'peer-1');

      // Every mention kind renders identically as a WidgetSpan-wrapped rounded
      // chip (profile mention AND @admins alike) — no TextSpan/WidgetSpan split.
      final aliceSpan = spans[1] as WidgetSpan;
      final adminsSpan = spans[3] as WidgetSpan;

      // Both chips contain the mention text painted in the accent colour
      // (incoming bubble → cs.primary), rendered on a rounded container rather
      // than a rectangular TextStyle.backgroundColor.
      Text mentionTextOf(WidgetSpan span) {
        return find
            .descendant(
              of: find.byWidget(span.child),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => e.widget as Text)
            .first;
      }

      final aliceText = mentionTextOf(aliceSpan);
      final adminsText = mentionTextOf(adminsSpan);
      expect(aliceText.data, '@alice');
      expect(adminsText.data, '@admins');
      expect(aliceText.style?.color, isNotNull);
      expect(aliceText.style?.color, adminsText.style?.color);
      expect(aliceText.style?.backgroundColor, isNull);
    },
  );
}