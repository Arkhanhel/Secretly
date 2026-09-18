// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The in-app notification cue must be silenced by the phone's ringer.
///
/// 🔴 FIELD REPORT (2026-08-01): "our phones are on silent and Secretly still
/// makes a sound".
///
/// The cause was not the notification channel — that one is a plain
/// high-importance channel with no Do Not Disturb bypass, and Android silences
/// it correctly. It was that with the app OPEN we played the cue ourselves,
/// through a bare `AudioPlayer`, which on Android defaults to the MEDIA usage.
/// Media is deliberately NOT muted by the ringer — that is why music keeps
/// playing on silent — so the OS never knew this was a notification and had no
/// reason to hold it back.
///
/// The fix declares the usage instead of reading `ringerMode` ourselves, so the
/// system applies every rule it has: silent, vibrate, Do Not Disturb, the
/// separate notification volume, driving mode. These tests pin the declaration,
/// because losing it is silent — the sound simply comes back.
void main() {
  String controller() =>
      File('lib/app/app_controller.dart').readAsStringSync();

  group('the cue is declared as a notification, not as media', () {
    test('the usage tag is present', () {
      final src = controller();
      expect(
        src.contains('AndroidAudioUsage.notification'),
        isTrue,
        reason: 'without this the cue plays on the media stream and the ringer '
            'has no say over it',
      );
      expect(
        src.contains('AndroidAudioContentType.sonification'),
        isTrue,
        reason: 'a short cue is sonification, not music',
      );
    });

    test('🔴 it is NOT the ringtone usage — that would BYPASS silent', () {
      // notificationRingtone is what an incoming CALL uses precisely because it
      // cuts through. Using it here would turn the bug into a louder bug.
      final src = controller();
      final cue = src.substring(
        src.indexOf('_ensureNotificationCueAudioAttributes'),
      );
      final block = cue.substring(0, cue.indexOf('\n  }'));
      expect(block.contains('notificationRingtone'), isFalse);
      expect(block.contains('AndroidAudioUsage.alarm'), isFalse);
    });

    test('the player does not let the global session overwrite the tag', () {
      // just_audio stamps the app-wide audio-session attributes onto a player
      // unless told not to. With that left on, the careful per-player tag would
      // be replaced by whatever music playback configured.
      expect(
        controller().contains('androidApplyAudioAttributes: false'),
        isTrue,
      );
    });
  });

  group('the fix cannot reach message delivery', () {
    test('tagging failures are swallowed, never rethrown', () {
      // The cue runs immediately after a message was decrypted and stored. An
      // audio problem must never propagate into that path — a missing sound is
      // cosmetic, a thrown exception there is a lost message.
      final src = controller();
      final start = src.indexOf('_ensureNotificationCueAudioAttributes() async');
      final block = src.substring(start, src.indexOf('\n  }', start));
      expect(block.contains('catch'), isTrue);
      expect(
        RegExp(r'\brethrow\b').hasMatch(block),
        isFalse,
        reason: 'a failed audio tag must not escape into the receive path',
      );
    });

    test('it is applied once, not on every message', () {
      // Setting the attributes forces a new Android audio session id; doing it
      // per play would churn the audio stack on every incoming message.
      expect(
        controller().contains('_notificationCueAttributesApplied'),
        isTrue,
      );
    });
  });

  group('calls are a separate, deliberate case', () {
    test('only the CALL channel bypasses Do Not Disturb', () {
      // An incoming call cutting through DND matches the system dialer and is
      // intended. This pins that nothing ELSE grew a bypass: a message channel
      // with setBypassDnd would be the same complaint, one level worse.
      final dir = Directory('android/app/src/main/kotlin');
      final offenders = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.kt')) continue;
        if (!f.readAsStringSync().contains('setBypassDnd')) continue;
        if (f.path.endsWith('IncomingCallNotifier.kt')) continue;
        offenders.add(f.path);
      }
      expect(
        offenders,
        isEmpty,
        reason: 'these bypass Do Not Disturb and are not the call notifier:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
