// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_controller.dart';
import '../../../calls/call_event.dart';
import 'desktop_selector.dart';

/// The seam between the desktop UI and [AppController].
///
/// **Why a seam at all.** `AppController` is ~50 000 lines and the desktop tree
/// reaches into 119 of its members from 20 files, each widget free to call
/// anything and to subscribe to the catch-all `changed` bus on its own terms.
/// That is what makes desktop parity work expensive: there is no place to state
/// what the desktop actually needs, so every new screen re-derives it, and the
/// controller can never be refactored because everything depends on everything.
///
/// This class is that place. It is deliberately **thin**: it wraps, it does not
/// reimplement. Nothing here adds behaviour to the controller — commands
/// delegate 1:1, and reads go through [DesktopSelector]s so a burst of
/// invalidation ticks costs one debounced query and republishes only when the
/// value actually moved. See [DesktopSelectorHub] for the mechanism.
///
/// **Two deviations from the design in
/// `docs/DESKTOP_TZ/02_ARCHITECTURE_UNIFICATION.md` §2, both deliberate:**
///
///  1. *The VM wraps the controller, it does not own it.*
///     `_DesktopProductionAppState` constructs the controller, disposes it, and
///     replaces it wholesale on restart. Moving that lifecycle into the VM
///     would be a rewrite of the boot path for no gain, so instead a VM is
///     created per controller instance and disposed with it.
///  2. *The command surface is grown per migrated consumer, not written out in
///     full.* Pre-writing 119 delegating methods nobody calls yet would be dead
///     code, which TZ principle P-5 forbids outright. Each migration adds the
///     commands it needs and deletes the direct controller reach it replaces.
///
/// **What this class is NOT for.** Two of the three problems the original
/// design cites have since been fixed by other means and must not be re-done
/// here: the root no longer rebuilds globally on `changed` (it diffs
/// `_rootSignature`, which took idle CPU from ~23% to ~2%), and the
/// `ChatEvent → MessageData` mapper now fills reply / continuation / mention /
/// edited and attributes group senders correctly. This seam exists for the
/// remaining problem: fourteen uncoordinated subscriptions and no boundary.
class DesktopAppViewModel {
  DesktopAppViewModel({
    required AppController controller,
    Duration debounce = const Duration(milliseconds: 150),
  })  : _controller = controller,
        _hub = DesktopSelectorHub(changed: controller.changed, debounce: debounce) {
    _hub.start();
    _relayOnline = ValueNotifier<bool>(controller.relayOnline);
    _relaySub = controller.relayConnectionChanges.listen((online) {
      if (_disposed) return;
      _relayOnline.value = online;
    });
  }

  final AppController _controller;
  final DesktopSelectorHub _hub;
  late final ValueNotifier<bool> _relayOnline;
  StreamSubscription<bool>? _relaySub;
  bool _disposed = false;

  /// Direct access to the controller, for surfaces not migrated yet.
  ///
  /// Every use is a piece of the seam that does not exist. The ratchet in
  /// `test/desktop_controller_seam_ratchet_test.dart` counts the files still
  /// importing `app_controller.dart` under `lib/ui/desktop/**` and fails if
  /// that number grows — so this escape hatch can be used, but the debt it
  /// represents can only shrink.
  AppController get controller => _controller;

  @visibleForTesting
  DesktopSelectorHub get hub => _hub;

  // ---------------------------------------------------------------------
  // Selectors — read state without subscribing to the catch-all bus.
  // ---------------------------------------------------------------------

  /// Bumped once per settled burst of controller ticks.
  ///
  /// The coarse binding, for a widget whose rendered state is too broad to
  /// name — a settings pane reading three dozen getters. It rebuilds once per
  /// burst instead of once per tick and costs no subscription of its own.
  /// Prefer a named selector wherever the value CAN be named: this one does
  /// not diff, so it rebuilds even when nothing the pane shows has moved.
  ValueListenable<int> get ticks => _hub.ticks;

  /// Whether the relay socket is up. Mirrors `AppController.relayOnline`,
  /// kept current from `relayConnectionChanges`.
  ValueListenable<bool> get relayOnline => _relayOnline;

  /// The call journal, newest first.
  ///
  /// Replaces a `StreamBuilder(stream: changed)` wrapped around a
  /// `FutureBuilder`, which built a fresh 200-row query on every tick and
  /// flashed a spinner each time because the new future starts with
  /// `data == null`. Now: one query per settled burst, republished only when
  /// the journal actually differs.
  DesktopSelector<List<CallJournalEntry>> callJournal({int limit = 200}) {
    return _hub.select<List<CallJournalEntry>>(
      debugName: 'callJournal',
      initial: const <CallJournalEntry>[],
      load: () => _controller.listCallJournalEntries(limit: limit),
      // CallJournalEntry is a plain class with no `==` override, so comparing
      // lists of them compares identity and would report "changed" on every
      // single reload — exactly the rebuild we are trying to avoid. Compare
      // the fields that can actually move for an entry instead.
      signature: _callJournalSignature,
    );
  }

  static String _callJournalSignature(List<CallJournalEntry> entries) {
    final buffer = StringBuffer()..write(entries.length);
    for (final e in entries) {
      buffer
        // Unit separator, written as an escape so the source stays free of
        // invisible control characters. It cannot occur in an id, so two
        // different journals can never collapse to the same signature.
        ..write('\u001f')
        ..write(e.callId)
        ..write(':')
        ..write(e.result.index)
        ..write(':')
        ..write(e.endedAtMs)
        ..write(':')
        ..write(e.durationMs)
        ..write(':')
        ..write(e.acknowledgedAtMs ?? 0);
    }
    return buffer.toString();
  }

  /// Creates a selector for a query that belongs to one screen.
  ///
  /// Named selectors above ([callJournal]) are for state the whole app shares.
  /// This is for the other kind: a pane's own query — the blocked list, a
  /// device list — which has no business being a field on an app-wide facade.
  /// It still runs on the single shared subscription and still republishes
  /// only on a real change; the caller owns the selector and must dispose it
  /// with the widget.
  DesktopSelector<T> select<T>({
    required String debugName,
    required T initial,
    required Future<T> Function() load,
    Object? Function(T value)? signature,
  }) =>
      _hub.select<T>(
        debugName: debugName,
        initial: initial,
        load: load,
        signature: signature,
      );

  // ---------------------------------------------------------------------
  // Commands — 1:1 delegation, no new behaviour.
  // ---------------------------------------------------------------------

  /// Clears the missed-call badge. Delegates to
  /// [AppController.acknowledgeMissedCalls].
  Future<void> acknowledgeMissedCalls({String? convoId}) =>
      _controller.acknowledgeMissedCalls(convoId: convoId);

  /// Личная заметка по разговору. Пусто — заметки нет.
  ///
  /// ◆ Вкладка «Заметки» в панели созвона и раздел в «Инфо» комнаты. Заметка
  /// личная: её не отправляют и не показывают в переписке, — но лежит она в
  /// той же зашифрованной базе, что и сообщения.
  Future<String> localConvoNote(String convoId) =>
      _controller.localConvoNote(convoId);

  /// Сохраняет личную заметку. Пустая строка стирает её.
  Future<void> setLocalConvoNote(String convoId, String body) =>
      _controller.setLocalConvoNote(convoId, body);

  /// Reloads every selector now, skipping the debounce.
  ///
  /// For the moment right after a command, when the UI knows something moved
  /// and should not wait out a tick that may not come.
  Future<void> refreshNow() => _hub.refreshNow();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _relaySub?.cancel();
    _relaySub = null;
    _hub.dispose();
    _relayOnline.dispose();
  }
}
