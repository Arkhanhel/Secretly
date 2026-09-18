// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ВХОД В КОМНАТУ ПО ССЫЛКЕ НА КОМПЬЮТЕРЕ.
//
// 🔴 Ссылка-приглашение была тупиком: из переписки она уходила во внешний
// браузер, а пришедшая от системы просто игнорировалась. Человек нажимал — и
// ничего не происходило. Телефон в этом месте открывает экран входа с
// проверкой и понятными отказами; теперь тот же экран открывает и компьютер.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_link_router.dart';

void main() {
  tearDown(() => DesktopLinkRouter.handler = null);

  group('маршрутизатор ссылок', () {
    test('без обработчика ссылка идёт наружу', () {
      expect(DesktopLinkRouter.handle(Uri.parse('https://example.com')), isFalse);
    });

    test('обработчик забирает свою ссылку', () {
      final seen = <Uri>[];
      DesktopLinkRouter.handler = (uri) {
        seen.add(uri);
        return uri.path.contains('/join/');
      };
      expect(
        DesktopLinkRouter.handle(Uri.parse('https://links.example.com/join/abc')),
        isTrue,
      );
      expect(
        DesktopLinkRouter.handle(Uri.parse('https://example.com/news')),
        isFalse,
        reason: 'чужие ссылки по-прежнему открывает браузер',
      );
      expect(seen, hasLength(2));
    });

    test('🔴 сбой обработчика не ломает нажатие', () {
      DesktopLinkRouter.handler = (_) => throw StateError('boom');
      expect(
        DesktopLinkRouter.handle(Uri.parse('https://example.com')),
        isFalse,
        reason: 'внешний путь обязан остаться запасным',
      );
    });
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 ссылка из переписки сперва предлагается приложению', () {
      for (final path in const [
        'lib/ui/desktop/chat/linkified_text.dart',
        'lib/ui/desktop/chat/message_rich_text.dart',
      ]) {
        final src = read(path);
        final router = src.indexOf('DesktopLinkRouter.handle(');
        final launch = src.indexOf('launchUrl(');
        expect(router, greaterThan(0), reason: path);
        expect(
          router < launch,
          isTrue,
          reason: '$path: браузер не должен опережать приложение',
        );
      }
    });

    test('🔴 ссылка от системы открывает экран входа', () {
      final shell = read('lib/ui/desktop/app/desktop_production_app.dart');
      expect(shell.contains('tryParseRoomInviteUri('), isTrue);
      expect(shell.contains('RoomInviteJoinScreen('), isTrue);
      expect(
        shell.contains('onJoined: _openConvoOrReport'),
        isTrue,
        reason: 'после входа комната должна открыться в окне',
      );
    });

    test('в меню «+» есть вход по ссылке', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      expect(section.contains('desktopJoinRoomByLink'), isTrue);
      expect(section.contains('RoomInviteJoinScreen('), isTrue);
    });

    test('подпись есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopJoinRoomByLink',
          'desktopJoinRoomLinkHint',
          'desktopJoinRoomLinkInvalid',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
