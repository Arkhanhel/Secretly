// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/nack_burst_gate.dart';

void main() {
  const windowMs = 10 * 60 * 1000; // 10 min
  const burst = 16;

  NackBurstGate makeGate() =>
      NackBurstGate(windowMs: windowMs, burstPerWindow: burst);

  group('NackBurstGate', () {
    test('allows exactly burstPerWindow NACKs, then declines within the window',
        () {
      final gate = makeGate();
      const dev = 'peerA';
      var now = 1000;

      // Simulate the real caller: hasRoom() gate, then consume() only on a
      // fresh wire. Here every wire is fresh, so all burst slots are spent.
      var allowed = 0;
      for (var i = 0; i < burst + 5; i++) {
        now += 100; // wires stream in a few ms apart, well inside the window
        if (gate.hasRoom(dev, now)) {
          gate.consume(dev, now);
          allowed++;
        }
      }
      expect(allowed, burst,
          reason: 'a backlog recovers up to the ceiling in one window');
      expect(gate.hasRoom(dev, now), isFalse,
          reason: 'ceiling reached — further NACKs are declined');
    });

    test('opens a fresh window after windowMs elapses', () {
      final gate = makeGate();
      const dev = 'peerA';
      var now = 1000;

      for (var i = 0; i < burst; i++) {
        gate.hasRoom(dev, now);
        gate.consume(dev, now);
      }
      expect(gate.hasRoom(dev, now), isFalse);

      // Still gated just before the window closes.
      expect(gate.hasRoom(dev, now + windowMs - 1), isFalse);

      // Window elapsed → fresh burst available.
      now += windowMs;
      expect(gate.hasRoom(dev, now), isTrue);
      gate.consume(dev, now);
      expect(gate.debugCountFor(dev), 1,
          reason: 'consume opens the fresh window at count 1');
    });

    test('hasRoom does not spend a slot (idempotent probe)', () {
      final gate = makeGate();
      const dev = 'peerA';
      const now = 5000;

      for (var i = 0; i < 100; i++) {
        expect(gate.hasRoom(dev, now), isTrue);
      }
      expect(gate.debugCountFor(dev), 0,
          reason: 'probing must never consume the burst');
    });

    test('an already-claimed wire (hasRoom but no consume) never burns a slot',
        () {
      // Models the replay sweep re-walking the SAME parked rows: it probes
      // hasRoom every run, but consume() runs only when the row is claimed
      // fresh. Re-probing an already-NACKed backlog must not exhaust the burst.
      final gate = makeGate();
      const dev = 'peerA';
      var now = 1000;

      // One genuinely fresh NACK.
      expect(gate.hasRoom(dev, now), isTrue);
      gate.consume(dev, now);

      // 1000 re-walks of already-claimed rows: probe only, never consume.
      for (var i = 0; i < 1000; i++) {
        now += 100;
        gate.hasRoom(dev, now); // would-be already_claimed → no consume
      }
      expect(gate.debugCountFor(dev), 1,
          reason: 'only the fresh wire spent a slot');
      expect(gate.hasRoom(dev, now), isTrue,
          reason: 'burst is nowhere near exhausted by re-probes');
    });

    test('per-device isolation: one peer\'s burst does not gate another', () {
      final gate = makeGate();
      const now = 2000;

      for (var i = 0; i < burst; i++) {
        gate.hasRoom('peerA', now);
        gate.consume('peerA', now);
      }
      expect(gate.hasRoom('peerA', now), isFalse);
      expect(gate.hasRoom('peerB', now), isTrue,
          reason: 'the gate is per peer device');
    });

    test('regression: the old one-per-window gate would have starved a backlog',
        () {
      // 17 dead wires (the largest field backlog) arriving inside one window.
      // Old behaviour: 1 NACK, 16 declined → "не все". New: all 16 up to the
      // ceiling recover in the same window (17th waits for the next).
      final gate = makeGate();
      const dev = 'peerA';
      var now = 1000;
      var emitted = 0;
      for (var i = 0; i < 17; i++) {
        now += 50;
        if (gate.hasRoom(dev, now)) {
          gate.consume(dev, now);
          emitted++;
        }
      }
      expect(emitted, greaterThanOrEqualTo(16),
          reason: 'the backlog is no longer starved to one wire per 10 min');
    });
  });
}
