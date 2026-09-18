// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_audio_route.dart';

void main() {
  group('resolvePreferredCallAudioRouteId', () {
    test('prefers bluetooth over every other route', () {
      expect(
        resolvePreferredCallAudioRouteId(
          availableRoutes: const <CallAudioRouteOption>[
            CallAudioRouteOption(
              deviceId: 'speaker',
              label: 'Speaker',
              kind: CallAudioRouteKind.speaker,
            ),
            CallAudioRouteOption(
              deviceId: 'earpiece',
              label: 'Earpiece',
              kind: CallAudioRouteKind.earpiece,
            ),
            CallAudioRouteOption(
              deviceId: 'bluetooth',
              label: 'BT Headset',
              kind: CallAudioRouteKind.bluetooth,
            ),
          ],
          preferSpeakerByDefault: true,
        ),
        'bluetooth',
      );
    });

    test('defaults audio calls to earpiece when no accessory is present', () {
      expect(
        resolvePreferredCallAudioRouteId(
          availableRoutes: const <CallAudioRouteOption>[
            CallAudioRouteOption(
              deviceId: 'speaker',
              label: 'Speaker',
              kind: CallAudioRouteKind.speaker,
            ),
            CallAudioRouteOption(
              deviceId: 'earpiece',
              label: 'Earpiece',
              kind: CallAudioRouteKind.earpiece,
            ),
          ],
          preferSpeakerByDefault: false,
        ),
        'earpiece',
      );
    });

    test('defaults video calls to speaker when no accessory is present', () {
      expect(
        resolvePreferredCallAudioRouteId(
          availableRoutes: const <CallAudioRouteOption>[
            CallAudioRouteOption(
              deviceId: 'speaker',
              label: 'Speaker',
              kind: CallAudioRouteKind.speaker,
            ),
            CallAudioRouteOption(
              deviceId: 'earpiece',
              label: 'Earpiece',
              kind: CallAudioRouteKind.earpiece,
            ),
          ],
          preferSpeakerByDefault: true,
        ),
        'speaker',
      );
    });
  });

  group('shouldAutoPromoteExternalAudioRoute', () {
    test('promotes newly available bluetooth over speaker', () {
      expect(
        shouldAutoPromoteExternalAudioRoute(
          availableRoutes: const <CallAudioRouteOption>[
            CallAudioRouteOption(
              deviceId: 'speaker',
              label: 'Speaker',
              kind: CallAudioRouteKind.speaker,
            ),
            CallAudioRouteOption(
              deviceId: 'bluetooth',
              label: 'BT Headset',
              kind: CallAudioRouteKind.bluetooth,
            ),
          ],
          currentRouteId: 'speaker',
        ),
        isTrue,
      );
    });

    test('keeps current route when already on an external accessory', () {
      expect(
        shouldAutoPromoteExternalAudioRoute(
          availableRoutes: const <CallAudioRouteOption>[
            CallAudioRouteOption(
              deviceId: 'speaker',
              label: 'Speaker',
              kind: CallAudioRouteKind.speaker,
            ),
            CallAudioRouteOption(
              deviceId: 'wired-headset',
              label: 'Wired headset',
              kind: CallAudioRouteKind.wiredHeadset,
            ),
          ],
          currentRouteId: 'wired-headset',
        ),
        isFalse,
      );
    });

    test(
      'respects explicit user selection of speaker even when wired headset is connected',
      () {
        expect(
          shouldAutoPromoteExternalAudioRoute(
            availableRoutes: const <CallAudioRouteOption>[
              CallAudioRouteOption(
                deviceId: 'speaker',
                label: 'Speaker',
                kind: CallAudioRouteKind.speaker,
              ),
              CallAudioRouteOption(
                deviceId: 'earpiece',
                label: 'Earpiece',
                kind: CallAudioRouteKind.earpiece,
              ),
              CallAudioRouteOption(
                deviceId: 'wired-headset',
                label: 'Wired headset',
                kind: CallAudioRouteKind.wiredHeadset,
              ),
            ],
            currentRouteId: 'speaker',
            userSelectionActive: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'respects explicit user selection of earpiece even when bluetooth is connected',
      () {
        expect(
          shouldAutoPromoteExternalAudioRoute(
            availableRoutes: const <CallAudioRouteOption>[
              CallAudioRouteOption(
                deviceId: 'speaker',
                label: 'Speaker',
                kind: CallAudioRouteKind.speaker,
              ),
              CallAudioRouteOption(
                deviceId: 'earpiece',
                label: 'Earpiece',
                kind: CallAudioRouteKind.earpiece,
              ),
              CallAudioRouteOption(
                deviceId: 'bluetooth',
                label: 'BT Headset',
                kind: CallAudioRouteKind.bluetooth,
              ),
            ],
            currentRouteId: 'earpiece',
            userSelectionActive: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'still auto-promotes when no user selection is active',
      () {
        expect(
          shouldAutoPromoteExternalAudioRoute(
            availableRoutes: const <CallAudioRouteOption>[
              CallAudioRouteOption(
                deviceId: 'speaker',
                label: 'Speaker',
                kind: CallAudioRouteKind.speaker,
              ),
              CallAudioRouteOption(
                deviceId: 'wired-headset',
                label: 'Wired headset',
                kind: CallAudioRouteKind.wiredHeadset,
              ),
            ],
            currentRouteId: 'speaker',
            userSelectionActive: false,
          ),
          isTrue,
        );
      },
    );
  });
}