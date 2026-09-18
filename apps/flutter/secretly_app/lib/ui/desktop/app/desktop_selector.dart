// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Debounced, diffing fan-in over a catch-all invalidation stream.
///
/// **The problem this solves.** `AppController.changed` is a catch-all
/// invalidation bus: it fires on the outbox pump, the service watchdog,
/// presence heartbeats, drains and receipts — constantly, on a paired client,
/// whether or not anything the user can see moved. Fourteen places in the
/// desktop tree subscribe to it independently, each with its own ad-hoc
/// debounce or none at all, and each re-queries the database on every tick.
/// The worst shape is a raw `StreamBuilder(stream: controller.changed)` around
/// a `FutureBuilder`: every tick builds a *new* future, so the list re-queries
/// and flashes its spinner while nothing has actually changed.
///
/// **The fix.** One subscription, one debounce, and a value that is only
/// published when it actually differs from the last one. This is the same
/// discipline the root already applies by hand via `_rootSignature`
/// (`desktop_production_app.dart`), which took idle CPU from ~23% to ~2% — this
/// class makes it reusable instead of copy-pasted.
///
/// Deliberately independent of `AppController`: the hub takes a plain
/// `Stream<void>`, so the engine is testable without constructing a
/// fifty-thousand-line god object. [DesktopAppViewModel] is the thin piece that
/// binds it to the real controller.
class DesktopSelectorHub {
  DesktopSelectorHub({
    required Stream<void> changed,
    this.debounce = const Duration(milliseconds: 150),
  }) : _changed = changed;

  final Stream<void> _changed;

  /// How long a burst of ticks is allowed to settle before selectors reload.
  ///
  /// Long enough to swallow a burst, short enough that the UI still feels
  /// immediate. Anything that must be instant (sending a message, opening a
  /// chat) should update optimistically rather than wait for a tick.
  final Duration debounce;

  final List<DesktopSelector<dynamic>> _selectors = <DesktopSelector<dynamic>>[];
  final ValueNotifier<int> _ticks = ValueNotifier<int>(0);
  StreamSubscription<void>? _sub;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Ticks observed since [start], including those coalesced away. Test-only
  /// visibility into the coalescing; never drive UI from this.
  @visibleForTesting
  int ticksObserved = 0;

  /// Refresh passes actually run. `ticksObserved - refreshesRun` is the work
  /// the debounce saved.
  @visibleForTesting
  int refreshesRun = 0;

  bool get isDisposed => _disposed;

  /// Bumped once per settled burst of invalidation ticks.
  ///
  /// The blunt instrument, for a widget whose rendered state is too broad to
  /// reduce to a signature — a settings pane reading three dozen controller
  /// getters, say. Binding to this with a `ValueListenableBuilder` rebuilds it
  /// once per burst instead of once per tick, and costs no subscription of its
  /// own. It does NOT diff: prefer [select] wherever the value can be named,
  /// because a selector rebuilds only when something actually moved.
  ValueListenable<int> get ticks => _ticks;

  @visibleForTesting
  int get selectorCount => _selectors.length;

  void start() {
    assert(!_disposed, 'start() on a disposed DesktopSelectorHub');
    _sub ??= _changed.listen((_) {
      ticksObserved++;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, _refreshAll);
    });
  }

  /// Creates a selector fed by this hub.
  ///
  /// [load] runs off the invalidation tick, so it may hit the database. Its
  /// result replaces the current value only when [signature] differs from the
  /// previous one — that is what stops a re-query from becoming a rebuild.
  ///
  /// [signature] defaults to `==`, which is right for a value type. Pass an
  /// explicit signature for lists and for model classes without an equality
  /// override (`CallJournalEntry`, `Conversation` and friends are plain
  /// classes — comparing them with `==` compares identity and would report
  /// "changed" on every reload).
  DesktopSelector<T> select<T>({
    required String debugName,
    required T initial,
    required Future<T> Function() load,
    Object? Function(T value)? signature,
  }) {
    assert(!_disposed, 'select() on a disposed DesktopSelectorHub');
    final selector = DesktopSelector<T>._(
      debugName: debugName,
      initial: initial,
      load: load,
      signature: signature,
      onDispose: _remove,
    );
    _selectors.add(selector);
    // Populate immediately: a selector created while the app is idle would
    // otherwise sit on `initial` until something unrelated fires a tick.
    unawaited(selector.refresh());
    return selector;
  }

  void _remove(DesktopSelector<dynamic> selector) => _selectors.remove(selector);

  void _refreshAll() {
    if (_disposed) return;
    refreshesRun++;
    _ticks.value++;
    for (final selector in List<DesktopSelector<dynamic>>.of(_selectors)) {
      unawaited(selector.refresh());
    }
  }

  /// Forces a refresh pass now, skipping the debounce.
  ///
  /// For the cases where the UI knows it just caused a change and should not
  /// wait out the debounce (e.g. right after a command).
  Future<void> refreshNow() async {
    if (_disposed) return;
    refreshesRun++;
    _ticks.value++;
    await Future.wait<void>(
      <Future<void>>[
        for (final selector in List<DesktopSelector<dynamic>>.of(_selectors))
          selector.refresh(),
      ],
    );
  }

  void dispose() {
    // Idempotent: a hub is disposed by whoever owns the view model, and again
    // by a teardown that cannot know whether that already happened. Disposing
    // a ChangeNotifier twice throws, so say no rather than blow up.
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _sub?.cancel();
    _sub = null;
    for (final selector in List<DesktopSelector<dynamic>>.of(_selectors)) {
      selector.dispose();
    }
    _selectors.clear();
    _ticks.dispose();
  }
}

/// A value derived from the controller, republished only when it changes.
///
/// Create these with [DesktopSelectorHub.select]; the constructor is private so
/// a selector can never end up orphaned from a hub and silently stale.
class DesktopSelector<T> extends ValueNotifier<T> {
  DesktopSelector._({
    required this.debugName,
    required T initial,
    required Future<T> Function() load,
    required Object? Function(T value)? signature,
    required void Function(DesktopSelector<dynamic>) onDispose,
  })  : _load = load,
        _signature = signature,
        _onDispose = onDispose,
        super(initial) {
    _lastSignature = _signatureOf(initial);
  }

  final String debugName;
  final Future<T> Function() _load;
  final Object? Function(T value)? _signature;
  final void Function(DesktopSelector<dynamic>) _onDispose;

  Object? _lastSignature;
  bool _loading = false;
  bool _dirty = false;
  bool _disposed = false;
  bool _hasLoaded = false;

  /// Whether a load has completed at least once.
  ///
  /// The distinction matters for anything with an empty state: an empty list
  /// that has not loaded yet means "still reading", and an empty list that
  /// has loaded means "there is nothing". Rendering "no calls yet" over the
  /// first is the app telling the user something untrue (TZ principle P-5).
  ///
  /// The transition to loaded always notifies listeners, even when the loaded
  /// value equals [initial] — going from unknown to known is itself news.
  bool get hasLoaded => _hasLoaded;

  /// Whether the last load produced a value different from the previous one.
  /// Test-only; counts republishes, which is what a rebuild costs.
  @visibleForTesting
  int publishes = 0;

  /// Loads reduced to nothing because the value was unchanged.
  @visibleForTesting
  int suppressed = 0;

  Object? _signatureOf(T value) =>
      _signature == null ? value : _signature(value);

  /// Reloads the value, coalescing concurrent calls.
  ///
  /// A refresh requested while one is in flight does not queue a second load —
  /// it marks the selector dirty, and one more load runs when the first
  /// finishes. Without this, a burst of ticks on a slow query stacks reads.
  Future<void> refresh() async {
    if (_disposed) return;
    if (_loading) {
      _dirty = true;
      return;
    }
    _loading = true;
    try {
      do {
        _dirty = false;
        final T next;
        try {
          next = await _load();
        } catch (_) {
          // A failed load leaves the previous value in place. The desktop
          // reads its data from a local database that can be locked or
          // mid-migration; blanking the UI on a transient read is worse than
          // showing the last good value.
          return;
        }
        if (_disposed) return;
        final nextSignature = _signatureOf(next);
        final wasLoaded = _hasLoaded;
        _hasLoaded = true;
        if (wasLoaded && nextSignature == _lastSignature) {
          suppressed++;
          continue;
        }
        _lastSignature = nextSignature;
        publishes++;
        final previous = value;
        value = next;
        if (previous == value) {
          // The setter suppresses a notification when the value compares
          // equal. On the very first load that would hide the unknown →
          // known transition from listeners reading [hasLoaded], so say it.
          notifyListeners();
        }
      } while (_dirty && !_disposed);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose(this);
    super.dispose();
  }
}

/// A tick source that never fires.
///
/// For a widget that can render without a view model (the settings workspace
/// is also built in a demo configuration with no controller behind it). Binding
/// to this is the honest "there is nothing to listen to here" — better than a
/// nullable `ValueListenable` and a branch at every use site.
final ValueNotifier<int> kDesktopNoTicks = ValueNotifier<int>(0);
