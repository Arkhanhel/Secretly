// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/calls/call_peer_label.dart';

// 🔴 КОМПЬЮТЕР ПОКАЗЫВАЛ СЫРОЙ profile_id ВМЕСТО ИМЕНИ ЗВОНЯЩЕГО (17.09.2026).
//
// Общий код звонков оставляет имя пустым, пока оно не найдено (`34e0a83a`), а
// компьютер подставлял туда profile_id в четырёх местах: окно входящего,
// экран звонка, системное уведомление. Как на телефоне: «Входящий звонок»,
// пока звонят, «Звонок» — во время разговора, и «?» на заглушке.

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  CallState st(CallPhase phase, {String name = ''}) => CallState(
    phase: phase,
    callId: 'c1',
    peerProfileId: 'PID-RAW-123',
    peerName: name,
  );

  test('звонят, имени нет — «Входящий звонок», без profile_id', () {
    final title = desktopCallPeerTitle(st(CallPhase.ringingIncoming), ru);
    expect(title, ru.callRecordIncomingCall);
    expect(title.contains('PID-RAW'), isFalse);
  });

  test('разговор, имени нет — «Звонок»', () {
    expect(desktopCallPeerTitle(st(CallPhase.connected), ru), ru.contactDetailsCall);
    expect(
      desktopCallPeerTitle(st(CallPhase.ringingOutgoing), ru),
      ru.contactDetailsCall,
    );
  });

  test('имя есть — имя; переданное вызывающим важнее', () {
    expect(
      desktopCallPeerTitle(st(CallPhase.connected, name: ' Игорь '), ru),
      'Игорь',
    );
    expect(
      desktopCallPeerTitle(
        st(CallPhase.connected, name: 'Игорь'),
        ru,
        preferred: 'Игорь П.',
      ),
      'Игорь П.',
    );
  });

  test('буквы заглушки — только из настоящего имени', () {
    expect(desktopCallPeerKnownName(st(CallPhase.ringingIncoming)), '');
    expect(
      desktopCallPeerKnownName(st(CallPhase.ringingIncoming, name: 'Анна')),
      'Анна',
    );
  });

  test('🔴 ни одно место компьютера не подставляет profile_id вместо имени', () {
    for (final path in [
      'lib/ui/desktop/app/desktop_production_app.dart',
      'lib/ui/desktop/calls/one_to_one_call_screen.dart',
      'lib/ui/desktop/services/desktop_notification_service.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('? s.peerProfileId : s.peerName'), isFalse, reason: path);
      expect(src.contains('return s.peerProfileId;'), isFalse, reason: path);
    }
  });

  test('окно входящего пересобирается, когда приходят имя или фото', () {
    final src = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(
      src.contains(
        "final toastKey = '\${s.peerName.trim()}|\${s.peerAvatarPath ?? ''}';",
      ),
      isTrue,
    );
    expect(src.contains('_toastPeerKey == toastKey'), isTrue);
    // Окно поднимается только на НОВЫЙ звонок, не на каждое обновление имени.
    expect(src.contains('if (_isNativeDesktop && isNewCall) {'), isTrue);
  });
}
