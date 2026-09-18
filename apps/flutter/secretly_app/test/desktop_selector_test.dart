// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Tests the controller↔UI seam engine (DesktopSelectorHub / DesktopSelector).
//
// The hub takes a plain `Stream<void>` rather than an AppController precisely
// so this can be tested without constructing a fifty-thousand-line god object.
// What is being proven here is the behaviour the desktop tree currently does
// NOT have: one debounced query per burst of ticks, and a rebuild only when
// the value actually moved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_selector.dart';

void main() {
  late StreamController<void> changed;
  late DesktopSelectorHub hub;

  setUp(() {
    changed = StreamController<void>.broadcast();
    hub = DesktopSelectorHub(
      changed: changed.stream,
      debounce: const Duration(milliseconds: 10),
    )..start();
  });

  tearDown(() async {
    hub.dispose();
    await changed.close();
  });

  /// Lets the debounce fire and any pending load settle.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  test('a selector loads once on creation, without waiting for a tick', () async {
    var loads = 0;
    final selector = hub.select<int>(
      debugName: 'counter',
      initial: -1,
      load: () async {
        loads++;
        return 7;
      },
    );
    await settle();

    expect(loads, 1, reason: 'a fresh selector must not sit on `initial`');
    expect(selector.value, 7);
    expect(selector.hasLoaded, isTrue);
  });

  test('a burst of ticks collapses into one refresh pass', () async {
    var loads = 0;
    hub.select<int>(
      debugName: 'counter',
      initial: 0,
      load: () async {
        loads++;
        return loads;
      },
    );
    await settle();
    expect(loads, 1);

    for (var i = 0; i < 20; i++) {
      changed.add(null);
    }
    await settle();

    expect(hub.ticksObserved, 20);
    expect(hub.refreshesRun, 1, reason: '20 ticks in one burst = one pass');
    expect(loads, 2, reason: 'one creation load + one burst load');
  });

  test('an unchanged value is not republished', () async {
    var rebuilds = 0;
    final selector = hub.select<int>(
      debugName: 'constant',
      initial: 0,
      load: () async => 42,
    );
    selector.addListener(() => rebuilds++);
    await settle();
    rebuilds = 0; // ignore the first load

    for (var i = 0; i < 5; i++) {
      changed.add(null);
      await settle();
    }

    expect(selector.value, 42);
    expect(rebuilds, 0, reason: 'the value never moved, so nothing rebuilds');
    expect(selector.suppressed, 5);
    expect(selector.publishes, 1, reason: 'only the very first load published');
  });

  test('a changed value is republished exactly once per change', () async {
    var next = 1;
    var rebuilds = 0;
    final selector = hub.select<int>(
      debugName: 'moving',
      initial: 0,
      load: () async => next,
    );
    selector.addListener(() => rebuilds++);
    await settle();

    next = 2;
    changed.add(null);
    await settle();
    next = 2; // same value again
    changed.add(null);
    await settle();
    next = 3;
    changed.add(null);
    await settle();

    expect(selector.value, 3);
    expect(rebuilds, 3, reason: 'first load, 1→2, 2→3 — not the 2→2 tick');
  });

  test('a signature function stands in for a missing `==`', () async {
    // Models like CallJournalEntry are plain classes: two equal-looking lists
    // compare unequal, so `==` would report "changed" on every reload.
    var rebuilds = 0;
    final selector = hub.select<List<_Row>>(
      debugName: 'rows',
      initial: const <_Row>[],
      load: () async => <_Row>[_Row('a'), _Row('b')],
      signature: (rows) => rows.map((r) => r.id).join(','),
    );
    selector.addListener(() => rebuilds++);
    await settle();
    rebuilds = 0;

    for (var i = 0; i < 3; i++) {
      changed.add(null);
      await settle();
    }

    expect(rebuilds, 0, reason: 'fresh instances, identical content');
  });

  test('without a signature, fresh instances would rebuild every time', () async {
    // The negative case, so the reason the signature exists is recorded and
    // not "simplified away" later.
    var rebuilds = 0;
    final selector = hub.select<List<_Row>>(
      debugName: 'rows-no-signature',
      initial: const <_Row>[],
      load: () async => <_Row>[_Row('a')],
    );
    selector.addListener(() => rebuilds++);
    await settle();
    rebuilds = 0;

    changed.add(null);
    await settle();

    expect(rebuilds, 1, reason: 'identity comparison sees a new list each time');
  });

  test('concurrent refreshes coalesce instead of stacking loads', () async {
    var loads = 0;
    var inFlight = 0;
    var maxInFlight = 0;
    hub.select<int>(
      debugName: 'slow',
      initial: 0,
      load: () async {
        loads++;
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        inFlight--;
        return loads;
      },
    );

    // Ticks arriving while the first (slow) load is still running.
    for (var i = 0; i < 5; i++) {
      changed.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(maxInFlight, 1, reason: 'never two reads of the same thing at once');
    expect(loads, lessThan(7), reason: 'requests coalesced, not queued');
  });

  test('a failed load keeps the last good value', () async {
    var shouldThrow = false;
    final selector = hub.select<int>(
      debugName: 'flaky',
      initial: 0,
      load: () async {
        if (shouldThrow) throw StateError('database locked');
        return 5;
      },
    );
    await settle();
    expect(selector.value, 5);

    shouldThrow = true;
    changed.add(null);
    await settle();

    expect(selector.value, 5,
        reason: 'a transient read failure must not blank the UI');
  });

  test('the first load publishes even when it equals the initial value', () async {
    // Otherwise an empty result would leave `hasLoaded` true but listeners
    // never told, and the UI would sit on its loading state forever.
    var rebuilds = 0;
    final selector = hub.select<List<String>>(
      debugName: 'empty',
      initial: const <String>[],
      load: () async => const <String>[],
      signature: (v) => v.join(','),
    );
    selector.addListener(() => rebuilds++);
    await settle();

    expect(selector.hasLoaded, isTrue);
    expect(rebuilds, 1, reason: 'unknown → known is itself a change');
  });

  test('refreshNow skips the debounce', () async {
    var loads = 0;
    hub.select<int>(
      debugName: 'counter',
      initial: 0,
      load: () async => ++loads,
    );
    await settle();
    expect(loads, 1);

    await hub.refreshNow();
    expect(loads, 2);
  });

  test('disposing a selector detaches it from the hub', () async {
    final selector = hub.select<int>(
      debugName: 'short-lived',
      initial: 0,
      load: () async => 1,
    );
    await settle();
    expect(hub.selectorCount, 1);

    selector.dispose();
    expect(hub.selectorCount, 0);

    // A tick after disposal must not touch the dead selector.
    changed.add(null);
    await settle();
  });

  test('disposing the hub twice is a no-op', () async {
    hub.dispose();
    expect(hub.dispose, returnsNormally,
        reason: 'teardown cannot know whether the owner already disposed it');
  });

  test('disposing the hub stops everything', () async {
    var loads = 0;
    hub.select<int>(
      debugName: 'counter',
      initial: 0,
      load: () async => ++loads,
    );
    await settle();
    final before = loads;

    hub.dispose();
    changed.add(null);
    await settle();

    expect(loads, before);
    expect(hub.isDisposed, isTrue);
  });
}

/// Stands in for the plain model classes the app uses (`CallJournalEntry`,
/// `Conversation`): no `==` override, so identity is the only equality.
class _Row {
  _Row(this.id);
  final String id;
}
