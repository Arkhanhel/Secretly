// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/theme_presets.dart';
import 'package:secretly_app/ui/widgets/app_background.dart';
import 'package:secretly_app/ui/widgets/avatar_initials.dart';
import 'package:secretly_app/ui/widgets/shared_palette.dart';

// 🔴 ЗАГЛУШКА ПОРТРЕТА — ОДНА НА ТЕЛЕФОН И КОМПЬЮТЕР (17.09.2026).
//
// Указание владельца: портреты с буквами на телефоне — «такими же цветами, как
// в пк версии». Компьютер рисует приглушённую заливку оттенка и цветные буквы
// (макет 14.09), телефон рисовал яркий градиент и белые буквы. Теперь формула
// одна — `sharedAvatarInk` — и здесь сторожится:
//   • тёмная тема компьютера не сдвинулась ни на пиксель (её подбирали по
//     макету);
//   • буквы читаются на КАЖДОЙ теме телефона и компьютера, светлой и тёмной;
//   • один и тот же человек на двух устройствах — одних и тех же цветов.

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Прежняя формула компьютера, дословно (до 17.09.2026 жила в `Avatar`).
({Color fill, Color ink}) _desktopFormulaBefore(List<Color> pair, Color bg) {
  final tint = Color.lerp(pair.first, pair.last, 0.5)!;
  final fill = Color.alphaBlend(tint.withValues(alpha: 0.15), bg);
  final hsl = HSLColor.fromColor(tint);
  final ink = hsl
      .withLightness(0.66)
      .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
      .toColor();
  return (fill: fill, ink: ink);
}

/// Фон страницы телефона — так же, как его собирает `main.dart`: тёмная тема
/// берёт самую тёмную точку градиента, светлая — нижнюю
/// (`AppBackground.scrimColorOf`).
Map<String, Color> _phoneBackgrounds({required bool dark}) {
  final out = <String, Color>{};
  for (final preset in kAppThemePresets) {
    if (dark) {
      final stops = preset.id == 'graphite'
          ? const <Color>[Color(0xFF000000)]
          : <Color>[preset.darkBgBottom, preset.darkBgMid, preset.darkBgTop];
      out[preset.id] = stops.reduce(
        (a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b,
      );
    } else {
      final bottom =
          preset.lightBgBottom ??
          Color.lerp(preset.lightSurface, preset.lightSecondary, 0.14)!;
      out[preset.id] = Color.lerp(bottom, Colors.white, 0.32)!;
    }
  }
  return out;
}

Widget _phoneHost({
  required Brightness brightness,
  required List<Color> page,
  required Widget child,
}) => MaterialApp(
  // Как в `main.dart`: экраны прозрачны и лежат на общем градиенте.
  theme: ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: Colors.transparent,
  ),
  home: AppBackground(
    gradient: LinearGradient(colors: page),
    child: Scaffold(body: Center(child: child)),
  ),
);

BoxDecoration _bubbleDecoration(WidgetTester t) =>
    t.widget<Container>(find.byType(Container).first).decoration!
        as BoxDecoration;

Color _bubbleInk(WidgetTester t) =>
    t.widget<Text>(find.byType(Text).first).style!.color!;

void main() {
  group('формула', () {
    test('🔴 тёмная тема компьютера — прежняя, до пикселя', () {
      for (final bg in [kDColorsDark.bg, const Color(0xFF000000)]) {
        for (final pair in kSharedAvatarGradients) {
          final now = sharedAvatarInkFor(pair, background: bg);
          final before = _desktopFormulaBefore(pair, bg);
          expect(now.fill, before.fill, reason: '$pair на $bg');
          expect(now.ink, before.ink, reason: '$pair на $bg');
        }
      }
    });

    test('заливка — 15 % оттенка поверх фона и без прозрачности', () {
      for (final bg in [kDColorsDark.bg, kDColorsLight.bg, Colors.white]) {
        for (final pair in kSharedAvatarGradients) {
          final fill = sharedAvatarInkFor(pair, background: bg).fill;
          expect(fill.a, 1.0);
          expect(fill, isNot(pair.first));
          expect(fill, isNot(pair.last));
        }
      }
    });

    test('ключ тот же — оттенок тот же, что и был', () {
      const seed = 'PID-42';
      final pair = sharedAvatarGradientColors(seed);
      expect(
        sharedAvatarInk(seed, background: kDColorsDark.bg).fill,
        sharedAvatarInkFor(pair, background: kDColorsDark.bg).fill,
      );
    });
  });

  group('читаемость', () {
    test('🔴 тёмные темы телефона и компьютера: буквы не тонут', () {
      final backgrounds = <String, Color>{
        'компьютер': kDColorsDark.bg,
        ..._phoneBackgrounds(dark: true),
      };
      for (final entry in backgrounds.entries) {
        for (final pair in kSharedAvatarGradients) {
          final c = sharedAvatarInkFor(pair, background: entry.value);
          expect(
            _contrast(c.ink, c.fill),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key}: $pair',
          );
        }
      }
    });

    test('🔴 светлые темы телефона и компьютера: буквы читаются', () {
      // Прежняя светлота 0,66 давала здесь 1,2–3,4 : 1.
      final backgrounds = <String, Color>{
        'компьютер': kDColorsLight.bg,
        'белый': Colors.white,
        ..._phoneBackgrounds(dark: false),
      };
      for (final entry in backgrounds.entries) {
        for (final pair in kSharedAvatarGradients) {
          final c = sharedAvatarInkFor(pair, background: entry.value);
          expect(
            _contrast(c.ink, c.fill),
            greaterThanOrEqualTo(3.5),
            reason: '${entry.key}: $pair',
          );
        }
      }
    });

    test('в светлой теме все оттенки читаются одинаково', () {
      // Постоянная светлота давала бирюзе 2 : 1, а индиго 10 : 1.
      final contrasts = <double>[
        for (final pair in kSharedAvatarGradients)
          () {
            final c = sharedAvatarInkFor(pair, background: kDColorsLight.bg);
            return _contrast(c.ink, c.fill);
          }(),
      ];
      final spread =
          contrasts.reduce((a, b) => a > b ? a : b) -
          contrasts.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(0.6), reason: '$contrasts');
      // И это по-прежнему цвет, а не чёрный.
      for (final pair in kSharedAvatarGradients) {
        final ink = sharedAvatarInkFor(pair, background: Colors.white).ink;
        expect(HSLColor.fromColor(ink).saturation, greaterThan(0.4));
      }
    });
  });

  group('фон под портретом', () {
    test('🔴 экраны звонков: буквы не бледнее 3 : 1', () {
      // Индиго на синем фоне активного звонка давал 2,2 : 1, на входящем —
      // 2,9 : 1. Прежние белые буквы там держали не меньше 3,3 : 1.
      final backgrounds = <String, Color>{
        'активный звонок': Color.lerp(
          const Color(0xFF2A4D94),
          const Color(0xFF0D0D0D),
          0.25,
        )!,
        'входящий видеозвонок': const Color(0xFF0D2A3E),
        'входящий аудиозвонок': const Color(0xFF0A2E22),
        'сцена созвона компьютера': const Color(0xFF0A0B0E),
      };
      for (final entry in backgrounds.entries) {
        for (final pair in kSharedAvatarGradients) {
          final c = sharedAvatarInkFor(pair, background: entry.value);
          expect(
            _contrast(c.ink, c.fill),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key}: $pair',
          );
          // Сдвигается только светлота — оттенок буквы прежний.
          final tint = Color.lerp(pair.first, pair.last, 0.5)!;
          final hueDelta =
              (HSLColor.fromColor(c.ink).hue - HSLColor.fromColor(tint).hue)
                  .abs();
          expect(
            hueDelta < 2.0 || hueDelta > 358.0,
            isTrue,
            reason: '${entry.key}: $pair — оттенок ушёл на $hueDelta°',
          );
        }
      }
    });

    test('фон посередине яркости: планку не взять — буквы белые', () {
      final c = sharedAvatarInkFor(
        kSharedAvatarGradients.first,
        background: const Color(0xFFAAAAAA),
      );
      expect(c.ink.toARGB32(), 0xFFFFFFFF);
    });

    testWidgets('светлая ли заливка — по теме, а не по оттенку', (t) async {
      for (final (brightness, page, light) in [
        (
          Brightness.light,
          const <Color>[Color(0xFFF7F8FB), Color(0xFFEAEFF6)],
          true,
        ),
        (
          Brightness.dark,
          const <Color>[Color(0xFF151E27), Color(0xFF1D2733)],
          false,
        ),
      ]) {
        final got = <bool>[];
        await t.pumpWidget(
          _phoneHost(
            brightness: brightness,
            page: page,
            child: Builder(
              builder: (context) {
                for (final seed in ['PID-1', 'PID-2', 'PID-3', 'PID-4']) {
                  got.add(AvatarInitials.fillIsLight(context, seed: seed));
                }
                return const SizedBox();
              },
            ),
          ),
        );
        expect(got, everyElement(light), reason: '$brightness');
      }
    });

    testWidgets('🔴 компьютер: заливка от чёрной сцены созвона, не от окна', (
      t,
    ) async {
      const stage = Color(0xFF0A0B0E);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DColors(
              colors: kDColorsLight,
              child: const Center(
                child: Avatar(
                  name: 'Игорь',
                  seed: 'PID-1',
                  size: 160,
                  background: stage,
                ),
              ),
            ),
          ),
        ),
      );
      final desk = t.widget<Container>(
        find
            .descendant(of: find.byType(Avatar), matching: find.byType(Container))
            .first,
      );
      final expected = sharedAvatarInk('PID-1', background: stage);
      expect((desk.decoration! as BoxDecoration).color, expected.fill);
      expect(expected.fill.computeLuminance(), lessThan(0.1));
    });
  });

  group('🔴 телефон и компьютер — одни и те же цвета', () {
    for (final (label, set) in [
      ('тёмная', kDColorsDark),
      ('светлая', kDColorsLight),
    ]) {
      testWidgets('$label тема', (t) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DColors(
                colors: set,
                child: const Center(
                  child: Avatar(name: 'Игорь', seed: 'PID-1', size: 46),
                ),
              ),
            ),
          ),
        );
        final desk = t.widget<Container>(
          find
              .descendant(
                of: find.byType(Avatar),
                matching: find.byType(Container),
              )
              .first,
        );
        final deskFill = (desk.decoration! as BoxDecoration).color;
        final deskInk = t
            .widget<Text>(
              find
                  .descendant(of: find.byType(Avatar), matching: find.byType(Text))
                  .first,
            )
            .style!
            .color;

        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => AvatarInitials.fallbackBubble(
                    context: context,
                    radius: 23,
                    seed: 'PID-1',
                    displayName: 'Игорь',
                    background: set.bg,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(_bubbleDecoration(t).color, deskFill);
        expect(_bubbleInk(t), deskInk);
        expect(find.text('ИГ'), findsOneWidget);
      });
    }
  });

  group('заглушка телефона', () {
    testWidgets('🔴 приглушённая заливка и цветные буквы, без градиента', (
      t,
    ) async {
      const page = <Color>[Color(0xFF151E27), Color(0xFF18222D), Color(0xFF1D2733)];
      await t.pumpWidget(
        _phoneHost(
          brightness: Brightness.dark,
          page: page,
          child: Builder(
            builder: (context) => AvatarInitials.fallbackBubble(
              context: context,
              radius: 26,
              seed: 'PID-7',
              displayName: 'Анна Петрова',
            ),
          ),
        ),
      );
      final d = _bubbleDecoration(t);
      expect(d.gradient, isNull, reason: 'яркий градиент во всю плитку ушёл');
      final expected = sharedAvatarInk('PID-7', background: page.first);
      // Самая тёмная точка страницы — под заливкой.
      expect(d.color, expected.fill);
      expect(_bubbleInk(t), expected.ink);
      expect(_bubbleInk(t), isNot(Colors.white));
      expect(find.text('АП'), findsOneWidget);
    });

    testWidgets('в светлой теме заливка светлая, буквы тёмные', (t) async {
      const page = <Color>[Color(0xFFF7F8FB), Color(0xFFF1F3F8), Color(0xFFEAEFF6)];
      await t.pumpWidget(
        _phoneHost(
          brightness: Brightness.light,
          page: page,
          child: Builder(
            builder: (context) => AvatarInitials.fallbackBubble(
              context: context,
              radius: 26,
              seed: 'PID-7',
              displayName: 'Анна',
            ),
          ),
        ),
      );
      final expected = sharedAvatarInk('PID-7', background: page.last);
      expect(_bubbleDecoration(t).color, expected.fill);
      expect(_bubbleInk(t), expected.ink);
      expect(expected.fill.computeLuminance(), greaterThan(0.5));
      expect(expected.ink.computeLuminance(), lessThan(0.2));
    });

    testWidgets('явный фон важнее страницы (экран звонка)', (t) async {
      const callBg = Color(0xFF0A2E22);
      await t.pumpWidget(
        _phoneHost(
          brightness: Brightness.light,
          page: const <Color>[Colors.white, Colors.white],
          child: Builder(
            builder: (context) => AvatarInitials.fallbackBubble(
              context: context,
              radius: 60,
              seed: 'PID-9',
              displayName: '🎯 Игорь',
              background: callBg,
            ),
          ),
        ),
      );
      final expected = sharedAvatarInk('PID-9', background: callBg);
      expect(_bubbleDecoration(t).color, expected.fill);
      expect(_bubbleInk(t), expected.ink);
      // Эмодзи в начале имени — целый знак, а не половина пары.
      expect(find.text('🎯И'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('🔴 тёмная витрина при светлой теме — заливка от витрины', (
      t,
    ) async {
      // Витрина украшений и обрезка обложки держат свою тёмную тему с
      // непрозрачным фоном, а общий градиент под ними — светлый.
      const showcase = Color(0xFF0C0D11);
      await t.pumpWidget(
        _phoneHost(
          brightness: Brightness.light,
          page: const <Color>[Colors.white, Color(0xFFEAEFF6)],
          child: Theme(
            data: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: showcase,
            ),
            child: Builder(
              builder: (context) => AvatarInitials.fallbackBubble(
                context: context,
                radius: 36,
                seed: 'PID-3',
                displayName: 'Секрет',
              ),
            ),
          ),
        ),
      );
      final expected = sharedAvatarInk('PID-3', background: showcase);
      expect(_bubbleDecoration(t).color, expected.fill);
      expect(_bubbleInk(t), expected.ink);
      expect(expected.fill.computeLuminance(), lessThan(0.1));
    });

    test('CircleAvatar-помощники — те же два цвета', () {
      // backgroundColor / foregroundColor берут у CircleAvatar личных чатов и
      // у строки «@все» — они обязаны совпадать с заглушкой.
      final src = File('lib/ui/widgets/avatar_initials.dart').readAsStringSync();
      expect(src.contains('colors(context, seed: seed).fill'), isTrue);
      expect(src.contains('colors(context, seed: seed).ink'), isTrue);
    });
  });

  group('места, где телефон рисовал заглушку сам', () {
    String read(String path) => File(path).readAsStringSync();

    /// Код без строк-комментариев: в них история, а не поведение.
    String code(String path) => read(path)
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('🔴 нигде не осталось яркого градиента с белыми буквами', () {
      for (final path in [
        'lib/ui/room_details_screen.dart',
        'lib/ui/profile_screen.dart',
        'lib/ui/contact_details_screen.dart',
        'lib/ui/forward_target_picker_screen.dart',
        'lib/ui/chat_screen.dart',
      ]) {
        expect(
          read(path).contains('backgroundGradient('),
          isFalse,
          reason: path,
        );
      }
      expect(
        read('lib/ui/widgets/avatar_initials.dart').contains('gradient:'),
        isFalse,
      );
    });

    test('🔴 звонки: ключ — профиль, буквы — общий счётчик', () {
      for (final path in [
        'lib/ui/incoming_call_screen.dart',
        'lib/ui/active_call_screen.dart',
      ]) {
        final src = code(path);
        expect(src.contains('name.hashCode'), isFalse, reason: path);
        expect(src.contains('name[0]'), isFalse, reason: path);
        expect(src.contains('AvatarInitials.fallbackBubble('), isTrue);
        expect(src.contains('seed: state.peerProfileId'), isTrue, reason: path);
      }
    });

    test('🔴 шапка комнаты красится по номеру комнаты, как список', () {
      expect(
        read('lib/ui/chat_screen.dart').contains(
          'fallbackId: _isGroupChat\n'
          '                                                ? widget.convoId\n'
          '                                                : headerProfileId,',
        ),
        isTrue,
      );
    });

    test('🔴 портрет автора в комнате — по профилю, имя — по устройству', () {
      // Компьютер красит портрет автора по профилю, имя — по устройству.
      // Телефон красил и то и другое по устройству: человек, писавший то с
      // телефона, то с компьютера, выходил в одной комнате двух цветов.
      final src = read('lib/ui/chat_screen.dart');
      expect(
        src.contains(
          'final colorSeed = _roomAuthorProfileIdByDevice[seed] ?? seed ?? title;',
        ),
        isTrue,
      );
      expect(
        src.contains('_roomAuthorProfileIdByDevice[deviceId] = profileId;'),
        isTrue,
      );
      expect(src.contains('seed: groupAuthorSeed ?? groupAuthorName!,'), isTrue);
    });

    test('реакции — по профилю на обеих версиях', () {
      expect(
        read('lib/ui/chat_screen.dart').contains(
          'final seed = fallbackId.isNotEmpty\n'
          '        ? fallbackId\n'
          "        : (name.isNotEmpty ? name : 'reaction');",
        ),
        isTrue,
      );
      expect(
        read('lib/ui/desktop/chat/message_bubble.dart').contains(
          "final seed = pid.isNotEmpty ? pid : (name.isEmpty ? 'reaction' : name);",
        ),
        isTrue,
      );
    });

    test('участники комнаты — по профилю во всех списках', () {
      final src = read('lib/ui/room_details_screen.dart');
      final calls = RegExp(r'_MiniAvatar\(([^)]*)\)').allMatches(src).toList();
      // Первое совпадение — конструктор класса.
      final uses = calls.where((m) => m.group(1)!.contains('title:')).toList();
      expect(uses, hasLength(6));
      for (final m in uses) {
        expect(m.group(1)!.contains('seed:'), isTrue, reason: m.group(0));
      }
    });

    test('🔴 баннер при скрытом отправителе не красит по переписке', () {
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'PID-1',
          showSender: false,
          peerProfileId: 'PID-1',
        ),
        isNull,
      );
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'req:PID-2',
          showSender: false,
          peerProfileId: 'PID-2',
        ),
        isNull,
      );
      // У комнаты заголовок и так её называет.
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'group:R1',
          showSender: false,
          senderProfileId: 'PID-3',
        ),
        'group:R1',
      );
      final ctrl = read('lib/app/app_controller.dart');
      expect(
        ctrl.contains(
          'avatarSeed: inAppBannerAvatarSeed(\n'
          '            convoId: cid,\n'
          '            showSender: notificationPresentation.showSender,\n'
          '            peerProfileId: peerProfileIdForPrivacy,\n'
          '            senderProfileId: bannerSenderPid,',
        ),
        isTrue,
      );
      expect(ctrl.contains('bannerSenderPid = senderPid;'), isTrue);
      final shell = read('lib/ui/app_shell.dart');
      final i = shell.indexOf('class _InAppNotifAvatar');
      final body = shell.substring(i, (i + 2600).clamp(0, shell.length));
      expect(body.contains('event.avatarSeed'), isTrue);
      expect(body.contains('cs.primaryContainer'), isTrue);
    });

    test('баннер красит того, кого называет', () {
      // Запрос: ключ переписки `req:<профиль>`, а список красит по профилю.
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'req:PID-2',
          showSender: true,
          peerProfileId: 'PID-2',
        ),
        'PID-2',
      );
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'PID-1',
          showSender: true,
          peerProfileId: 'PID-1',
        ),
        'PID-1',
      );
      // Комната с именем автора в заголовке — цвет автора, а не комнаты.
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'group:R1',
          showSender: true,
          senderProfileId: 'PID-3',
        ),
        'PID-3',
      );
      // Автор не определился — заголовок остался названием комнаты.
      expect(
        AppController.inAppBannerAvatarSeed(
          convoId: 'group:R1',
          showSender: true,
        ),
        'group:R1',
      );
    });

    test('🔴 раскрытая шапка без фото: текст не белеет по светлой заливке', () {
      for (final path in [
        'lib/ui/contact_details_screen.dart',
        'lib/ui/room_details_screen.dart',
      ]) {
        final src = code(path);
        expect(
          src.contains(
            'final heroTextWhite = _pullExpand > 0.35 && !heroOnLightFallback;',
          ),
          isTrue,
          reason: path,
        );
        expect(src.contains('AvatarInitials.fillIsLight('), isTrue, reason: path);
        // Ни одного белого текста шапки по одному лишь раскрытию.
        expect(
          RegExp(r'color: _pullExpand > 0\.35\s*\?\s*Colors\.white').hasMatch(src),
          isFalse,
          reason: path,
        );
      }
    });

    test('звонок на компьютере — тоже по профилю', () {
      expect(
        read('lib/ui/desktop/calls/one_to_one_call_screen.dart').contains(
          '          Avatar(\n'
          '            name: avatarName,\n'
          '            seed: seed,\n'
          '            image: image,\n'
          '            size: 160,\n'
          '            background: _kCallStage,\n'
          '          ),',
        ),
        isTrue,
      );
      expect(
        read('lib/ui/desktop/app/desktop_production_app.dart').contains(
          'callerSeed: s.peerProfileId,',
        ),
        isTrue,
      );
    });
  });
}
