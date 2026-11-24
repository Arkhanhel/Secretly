// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/animations/avatar_bridge_route.dart';
import 'package:secretly_app/ui/animations/shimmer_skeletons.dart';
import 'package:secretly_app/ui/contact_details_screen.dart';
import 'package:secretly_app/ui/premium/live_frames.dart' show LiveFramePressHost;
import 'package:secretly_app/ui/room_details_screen.dart';

/// Контроллер, у которого ничего не загружается: виден только первый кадр
/// (затравка из списка) — ровно то, что проверяем.
class _NeverLoadsController extends AppController {
  final Completer<Never> _never = Completer<Never>();

  @override
  Future<List<Contact>> listContacts() => _never.future;

  @override
  Future<List<Conversation>> listConversations() => _never.future;

  @override
  Future<String?> contactAccountIdentityPubB64(String profileId) async => null;

  @override
  Future<void> refreshProfileMeta(String profileId) async {}

  @override
  bool isSavedMessagesConvo(String convoId) => false;
}

/// Список уже держит беседу в памяти — с рамкой собеседника.
class _KnownPeerController extends _NeverLoadsController {
  @override
  Conversation? cachedConversation(String convoId) => convoId == 'peer-2'
      ? Conversation(
          convoId: 'peer-2',
          peerProfileId: 'peer-2',
          title: 'Zhenya',
          avatarPath: null,
          lastEventAtMs: 0,
          pinnedAtMs: null,
          muted: false,
          archivedAtMs: null,
          autoDeleteSeconds: null,
          emoji: null,
          frameId: 'neon',
          coverId: 'space',
        )
      : null;
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Iterable<Object> _heroTags(WidgetTester t) =>
    t.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag);

Finder _shuttle() => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_AvatarBridgeShuttle',
);

Future<void> _backGesture(
  WidgetTester t,
  String method, [
  Map<String, Object?>? args,
]) async {
  final msg = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, args),
  );
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    msg,
    (_) {},
  );
}

void main() {
  test('метки списка и шапки чата различаются', () {
    expect(avatarBridgeListTag('c1'), 'avatar-c1');
    expect(avatarBridgeChatHeaderTag('c1'), isNot(avatarBridgeListTag('c1')));
    expect(
      const AvatarBridgeParkedTag('avatar-c1'),
      const AvatarBridgeParkedTag('avatar-c1'),
    );
    expect(const AvatarBridgeParkedTag('avatar-c1'), isNot('avatar-c1'));
  });

  testWidgets('профиль собеседника: в первом кадре уже есть аватар-Hero', (
    t,
  ) async {
    final controller = _NeverLoadsController();
    await t.pumpWidget(
      _app(
        ContactDetailsScreen(
          controller: controller,
          peerProfileId: 'peer-1',
          convoId: 'peer-1',
          initialTitle: 'Anna',
          heroTag: avatarBridgeListTag('peer-1'),
        ),
      ),
    );
    expect(find.byType(ShimmerContactDetails), findsNothing);
    expect(_heroTags(t), contains(avatarBridgeListTag('peer-1')));
    expect(find.text('Anna'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('🔴 первый кадр профиля — уже с рамкой из списка, не «чужой»', (
    t,
  ) async {
    // 23.11.2026: до загрузки профиля на долю секунды стояла другая рамка и
    // обложка, потом всё моргало и переключалось.
    final controller = _KnownPeerController();
    await t.pumpWidget(
      _app(
        ContactDetailsScreen(
          controller: controller,
          peerProfileId: 'peer-2',
          convoId: 'peer-2',
          initialTitle: 'Zhenya',
          heroTag: avatarBridgeListTag('peer-2'),
        ),
      ),
    );
    final hosts = t.widgetList<LiveFramePressHost>(
      find.byType(LiveFramePressHost),
    );
    expect(hosts.map((h) => h.frameId), contains('neon'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('страница комнаты ставит переданную метку на аватар', (t) async {
    final controller = _NeverLoadsController();
    await t.pumpWidget(
      _app(
        RoomDetailsScreen(
          controller: controller,
          groupId: 'group:alpha',
          initialTitle: 'Alpha Room',
          heroTag: avatarBridgeListTag('group:alpha'),
        ),
      ),
    );
    final tags = _heroTags(t).toList();
    expect(tags, contains(avatarBridgeListTag('group:alpha')));
    expect(tags, isNot(contains('room-avatar-group:alpha')));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('страница комнаты без метки — прежняя room-avatar', (t) async {
    final controller = _NeverLoadsController();
    await t.pumpWidget(
      _app(
        RoomDetailsScreen(
          controller: controller,
          groupId: 'group:alpha',
          initialTitle: 'Alpha Room',
        ),
      ),
    );
    expect(_heroTags(t), contains('room-avatar-group:alpha'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('строка списка → профиль: аватар летит (метки совпадают)', (
    t,
  ) async {
    final controller = _NeverLoadsController();
    final tag = avatarBridgeListTag('peer-1');
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pushAvatarBridge<void>(
                  context,
                  heroTag: tag,
                  hapticsEnabled: () => false,
                  builder: (_) => ContactDetailsScreen(
                    controller: controller,
                    peerProfileId: 'peer-1',
                    convoId: 'peer-1',
                    initialTitle: 'Anna',
                    heroTag: tag,
                  ),
                ),
                child: AvatarBridgeHero(
                  tag: tag,
                  side: AvatarBridgeSide.source,
                  spec: const AvatarBridgeSpec(seed: 'peer-1', name: 'Anna'),
                  child: const ColoredBox(
                    key: ValueKey('row-avatar'),
                    color: Color(0xFF888888),
                    child: SizedBox.square(dimension: 52),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('row-avatar')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    expect(_shuttle(), findsOneWidget);
    // 🔴 23.11.2026: инициалы в полёте — без отладочного стиля (жёлтое
    // двойное подчёркивание и запасной шрифт были без Material над ними).
    final initials = find.descendant(
      of: _shuttle(),
      matching: find.byType(RichText),
    );
    expect(initials, findsWidgets);
    for (final e in initials.evaluate()) {
      final para = e.renderObject! as RenderParagraph;
      void check(InlineSpan span) {
        final style = span.style;
        expect(style?.decoration ?? TextDecoration.none, TextDecoration.none);
        expect(style?.decorationColor, isNot(const Color(0xFFFFFF00)));
      }

      para.text.visitChildren((span) {
        check(span);
        return true;
      });
    }
    expect(
      find.ancestor(of: _shuttle(), matching: find.byType(Material)),
      findsWidgets,
    );
    await t.pump(const Duration(milliseconds: 900));
    expect(_shuttle(), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  group('Android: раскрытие кругом и предиктивный «назад»', () {
    // Платформа тестов по умолчанию — Android.
    setUp(() => expect(defaultTargetPlatform, TargetPlatform.android));

    test('радиус круга растёт с ходом перехода', () {
      const size = Size(390, 844);
      const origin = Rect.fromLTWH(16, 200, 52, 52);
      double r(double p) =>
          avatarBridgeReveal(size: size, origin: origin, progress: p).radius;
      expect(r(0.2), lessThan(r(0.5)));
      expect(r(0.5), lessThan(r(0.9)));
      final full = avatarBridgeReveal(size: size, origin: origin, progress: 1);
      expect(full.radius, full.maxRadius);
      expect(full.center, origin.center);
    });

    Future<AvatarBridgeRoute<void>> pushRoute(WidgetTester t) async {
      late BuildContext home;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              home = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      );
      final route = AvatarBridgeRoute<void>(
        origin: const Rect.fromLTWH(16, 200, 52, 52),
        hapticsEnabled: () => false,
        builder: (_) => const Scaffold(body: Center(child: Text('profile'))),
      );
      unawaited(Navigator.of(home).push(route));
      return route;
    }

    AvatarBridgeCircleClipper clipper(WidgetTester t) =>
        t
                .widget<ClipPath>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is ClipPath && w.clipper is AvatarBridgeCircleClipper,
                  ),
                )
                .clipper!
            as AvatarBridgeCircleClipper;

    testWidgets('круг раскрывается из аватара', (t) async {
      await pushRoute(t);
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      final r1 = clipper(t).radius;
      expect(clipper(t).center, const Offset(42, 226));
      await t.pump(const Duration(milliseconds: 80));
      final r2 = clipper(t).radius;
      expect(r2, greaterThan(r1));
      await t.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
    });

    double pageScale(WidgetTester t) {
      final transforms = t.widgetList<Transform>(
        find.ancestor(
          of: find.text('profile'),
          matching: find.byType(Transform),
        ),
      );
      var scale = 1.0;
      for (final tr in transforms) {
        scale = scale * tr.transform.storage[0]; // масштаб по x
      }
      return scale;
    }

    testWidgets('жест «назад» сжимает страницу, отмена — возвращает', (
      t,
    ) async {
      final route = await pushRoute(t);
      await t.pumpAndSettle();
      expect(pageScale(t), closeTo(1, 1e-6));

      await _backGesture(t, 'startBackGesture', {
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await _backGesture(t, 'updateBackGestureProgress', {
        'x': 100.0,
        'y': 300.0,
        'progress': 0.5,
        'swipeEdge': 0,
      });
      await t.pump();
      expect(route.backPreview.value, closeTo(0.5, 1e-6));
      expect(pageScale(t), closeTo(0.95, 1e-3));

      await _backGesture(t, 'cancelBackGesture');
      await t.pumpAndSettle();
      expect(route.backPreview.value, closeTo(0, 1e-3));
      expect(find.text('profile'), findsOneWidget);
    });

    testWidgets('после 35 % — «назад» закрывает страницу', (t) async {
      await pushRoute(t);
      await t.pumpAndSettle();
      await _backGesture(t, 'startBackGesture', {
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await _backGesture(t, 'updateBackGestureProgress', {
        'x': 160.0,
        'y': 300.0,
        'progress': 0.6,
        'swipeEdge': 0,
      });
      await t.pump();
      await _backGesture(t, 'commitBackGesture');
      await t.pumpAndSettle();
      expect(find.text('profile'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('медленно и меньше 35 % — страница остаётся', (t) async {
      await pushRoute(t);
      await t.pumpAndSettle();
      await _backGesture(t, 'startBackGesture', {
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await _backGesture(t, 'updateBackGestureProgress', {
        'x': 40.0,
        'y': 300.0,
        'progress': 0.2,
        'swipeEdge': 0,
      });
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await _backGesture(t, 'commitBackGesture');
      await t.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
    });
  });
}
