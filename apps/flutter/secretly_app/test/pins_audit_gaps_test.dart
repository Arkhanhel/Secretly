// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Разбор закреплённых 23.11.2026. Две группы:
//  * «гарантии» — то, что уже работает и не должно сломаться;
//  * «пробелы» — тесты фиксируют НАЙДЕННЫЙ дефект как он есть. Когда дефект
//    исправят, такой тест упадёт — тогда переверните ожидание.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/chat_pins_logic.dart';
import 'package:secretly_app/app/message_command_utils.dart';

String _src(String path) => File(path).readAsStringSync();

/// Тело метода верхнего уровня класса (отступ 2): от сигнатуры до `\n  }\n`.
String _body(String src, String signature) {
  final start = src.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: 'нет $signature');
  final end = src.indexOf('\n  }\n', start);
  return src.substring(start, end < 0 ? src.length : end);
}

void main() {
  const controller = 'lib/app/app_controller.dart';
  const screen = 'lib/ui/chat_screen.dart';
  const desktop = 'lib/ui/desktop/app/desktop_chats_section.dart';

  group('гарантии', () {
    test('ревизия «из будущего» не получает вечного первенства (G-3)', () {
      const now = 1000000;
      final far = now + 60 * 60 * 1000;
      expect(trustedPinFreshnessMs(far, now, messageAtMs: now - 5), now - 5);
      expect(
        trustedPinFreshnessMs(far, now),
        now + kPinRevisionFutureSkewMs,
      );
      expect(trustedPinFreshnessMs(now + 10, now), now + 10);
    });

    test('пустой список уходит с ревизией и повторяется (нет «призрака»)', () {
      final c = _src(controller);
      final remember = _body(c, 'Future<void> rememberChatPins(');
      // Пустой список стирает ключ списка, но ревизию оставляет.
      expect(remember, contains("prefs.remove('\$_kPrefsChatPinsPrefix\$id')"));
      expect(remember, contains("prefs.setInt('\$_kPrefsChatPinsRevPrefix\$id'"));
      final resend = _body(c, 'Future<void> maybeResendChatPins(');
      expect(resend, contains('pins.isEmpty && !kPinSyncChecksV2'));
      final cmd = parsePinSyncCommand(
        buildPinSyncCommand(const <PinnedRef>[], revision: 42, convoId: 'P'),
      )!;
      expect(cmd.pins, isEmpty);
      expect(cmd.revision, 42);
    });

    test('старый список (ревизия не новее) не принимается', () {
      final adopt = _body(
        _src(controller),
        'Future<bool> _adoptInboundChatPins(',
      );
      expect(adopt, contains('if (fresh <= localRevision) return false;'));
    });

    test('комната: список от того, кому закреплять нельзя, отклоняется', () {
      expect(
        roomPinAuthorAllowed(isOwn: false, authorRole: null, settings: null),
        isFalse,
      );
      expect(
        roomPinAuthorAllowed(isOwn: true, authorRole: null, settings: null),
        isTrue,
      );
    });
  });

  group('пробелы (тест упадёт, когда дефект исправят)', () {
    test('одновременные правки: побеждает последняя, чужое закрепление '
        'теряется (слияния после первого приёма нет)', () {
      // Устройство A уже знает список (ревизия > 0) с [X]; приходит более
      // новый список B с [Y] — объединения нет, X пропадает.
      expect(
        needsFirstAdoptionMerge(
          isGroup: false,
          localRevision: 1000,
          localPins: const [PinnedRef(eventId: 'X', pinnedAtMs: 999)],
        ),
        isFalse,
      );
      expect(
        needsFirstAdoptionMerge(
          isGroup: true,
          localRevision: 0,
          localPins: const [PinnedRef(eventId: 'X')],
        ),
        isFalse,
      );
    });

    test('ПК: в личном чате закреплённых нет вовсе, в комнате — только '
        'одиночное закрепление реле, общий список не читается и не шлётся', () {
      final d = _src(desktop);
      expect(d, contains('pinnedPayloadEventId: _isDirect ? null'));
      expect(d, contains('onTogglePinMessage: (!_isDirect && _canPinMessages)'));
      expect(d.contains('broadcastChatPins'), isFalse);
      expect(d.contains('loadChatPins'), isFalse);
      expect(d.contains('broadcastRoomPins'), isFalse);
    });

    test('телефон с общим списком игнорирует смену закрепления реле '
        '(закреплённое с ПК не видно на телефоне)', () {
      final refresh = _body(
        _src(screen),
        'Future<void> _refreshRoomPinnedMessageState(',
      );
      expect(
        refresh,
        contains(
          'if (_appliedPinSyncAtMs > 0) {\n'
          '        setState(() => _groupPinnedMessageEventId = normalized);\n'
          '        return;',
        ),
      );
    });

    test('открепление с ПК видят только телефоны, где комната открыта в тот '
        'момент: признак «реле было X» живёт в памяти экрана', () {
      final s = _src(screen);
      final refresh = _body(s, 'Future<void> _refreshRoomPinnedMessageState(');
      expect(
        refresh,
        contains('normalized == null && relayKnownBefore && relayBefore != null'),
      );
      // При открытии экрана признак сброшен — первое чтение «реле пусто»
      // ничего не убирает.
      expect(s, contains('_relayPinRead = false;'));
      // Контроллер переходы реле для закреплённых не отслеживает.
      final c = _src(controller);
      final setRelay = _body(c, 'Future<void> setRoomPinnedMessage(');
      expect(setRelay.contains('broadcastChatPins'), isFalse);
    });

    test('🔴 очистка истории, удаление чата и автоудаление убирают '
        'закреплённые стёртых сообщений у себя (исправлено 23.11.2026)', () {
      final c = _src(controller);
      for (final sig in const [
        'Future<void> deleteChat(',
        'Future<void> _applyAutoDeleteRetentionForConvo(',
        'Future<void> _applyConversationHistoryClear(',
      ]) {
        expect(
          _body(c, sig).contains('dropLocalChatPinsBefore('),
          isTrue,
          reason: sig,
        );
      }
      // Обе очистки истории идут через _applyConversationHistoryClear.
      for (final sig in const [
        'Future<void> clearChatHistory(',
        'Future<void> clearChatHistoryEverywhere(',
      ]) {
        expect(
          _body(c, sig).contains('_applyConversationHistoryClear('),
          isTrue,
          reason: sig,
        );
      }
    });

    test('🔴 повтор неотправленного списка — при открытии чата и при '
        'выходе в сеть (исправлено 23.11.2026)', () {
      final s = _src(screen);
      expect(RegExp(r'maybeResendChatPins\(').allMatches(s).length, 1);
      final c = _src(controller);
      expect(
        _body(c, 'void _handleRelayConnectionChanged(')
            .contains('_resendUndeliveredChatPins()'),
        isTrue,
      );
      expect(
        _body(c, 'Future<void> _resendUndeliveredChatPins(')
            .contains("sent['partial'] != true"),
        isTrue,
      );
    });
  });
}
