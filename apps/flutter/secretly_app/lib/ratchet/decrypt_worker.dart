// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'double_ratchet_v3.dart';

/// An error that came back from the worker isolate, carrying the ORIGINAL
/// error's text verbatim.
///
/// 🔴 Н-6, and the reason this class exists at all. Exceptions do not cross an
/// isolate boundary as objects, and the decision that decides message loss —
/// `DeliveredDecryptAckPolicy.isTransientDecryptError` vs `isGenuineMacFailure`
/// — classifies by matching substrings of `error.toString()`.
///
/// So type identity is irrelevant, but the TEXT is everything: lose it and a
/// transient "session not found" reads as an unrecognised error, or worse a
/// permanent one, and the wire is acknowledged away instead of parked. That is
/// exactly the defect fixed on 2026-07-31.
///
/// [toString] therefore returns the original text unchanged, so every existing
/// classifier reaches byte-identical verdicts on the reconstructed error.
class RemoteDecryptError implements Exception {
  RemoteDecryptError(this.originalText);

  final String originalText;

  @override
  String toString() => originalText;
}

/// Runs the (pure) Double Ratchet decrypt on a long-lived worker isolate so the
/// heaviest maths in the app stops competing with the thread that draws frames.
///
/// This is step Б of `docs/TZ_HEAT_ISOLATE_AND_PUMP_2026-07-31.md`. It is only
/// possible because step А made [DoubleRatchetV3.decrypt] pure: it takes state
/// and bytes, returns state and bytes, and touches no database and no
/// callbacks. Nothing here may reintroduce either — see Ф-3.Б: a database call
/// from this isolate would deadlock against the transaction the caller holds
/// open on the main isolate.
///
/// **Degradation is always safe.** Every failure to spawn, send, or receive
/// falls back to computing in place, which is exactly what the app did before
/// this class existed. The worker is an optimisation, never a dependency.
class DecryptWorker {
  DecryptWorker._();

  static final DecryptWorker instance = DecryptWorker._();

  /// Spawning costs far more than one decrypt, so the isolate is created once
  /// and kept (Н-7). Null while it has never started, or after a crash.
  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  StreamSubscription<dynamic>? _sub;

  /// In-flight requests by id. A crash completes all of them with an error so
  /// nothing can hang forever waiting on a dead isolate.
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _nextId = 1;

  /// Guards against two concurrent first-calls both spawning.
  Future<bool>? _starting;

  /// Set when spawning has failed; we then stay in-place rather than paying the
  /// spawn cost on every message on a device that cannot give us an isolate.
  bool _spawnFailed = false;

  bool get isRunning => _toWorker != null;

  Future<bool> _ensureStarted() {
    if (_toWorker != null) return Future.value(true);
    if (_spawnFailed) return Future.value(false);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<bool> _start() async {
    try {
      final rp = ReceivePort();
      final iso = await Isolate.spawn(
        _workerMain,
        rp.sendPort,
        errorsAreFatal: true,
        debugName: 'secretly-decrypt',
      );
      final completer = Completer<SendPort>();
      _sub = rp.listen((message) {
        if (message is SendPort) {
          if (!completer.isCompleted) completer.complete(message);
          return;
        }
        if (message is Map) {
          final id = message['id'] as int?;
          if (id == null) return;
          final c = _pending.remove(id);
          c?.complete(message.cast<String, dynamic>());
        }
      });
      final port = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('decrypt worker did not hand back a port'),
      );
      _isolate = iso;
      _fromWorker = rp;
      _toWorker = port;
      return true;
    } catch (_) {
      _spawnFailed = true;
      _teardown();
      return false;
    }
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _fromWorker?.close();
    _fromWorker = null;
    _toWorker = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    // Never leave a caller awaiting a port nobody will answer.
    final stranded = _pending.values.toList(growable: false);
    _pending.clear();
    for (final c in stranded) {
      if (!c.isCompleted) {
        c.complete(<String, dynamic>{'err': 'decrypt worker died'});
      }
    }
  }

  /// Drops the worker. Called when a request fails in a way that suggests the
  /// isolate is unhealthy; the next call lazily starts a fresh one.
  void _recycle() {
    _teardown();
    // Deliberately NOT setting _spawnFailed: a crash mid-work is different from
    // a device that cannot spawn at all, and deserves another chance.
  }

  /// Decrypts one wire, on the worker when one is available and in place
  /// otherwise. The result is identical either way.
  Future<DoubleRatchetDecryptResultV3> decrypt({
    required DoubleRatchetV3 ratchet,
    required DoubleRatchetStateV3 state,
    required String headerDhPubB64,
    required int pn,
    required int n,
    required List<int> ciphertext,
    Uint8List? preloadedSkippedKey,
    List<int> aad = const <int>[],
  }) async {
    Future<DoubleRatchetDecryptResultV3> inPlace() => ratchet.decrypt(
          state: state,
          headerDhPubB64: headerDhPubB64,
          pn: pn,
          n: n,
          ciphertext: ciphertext,
          preloadedSkippedKey: preloadedSkippedKey,
          aad: aad,
        );

    // 🔴 The worker builds its OWN DoubleRatchetV3 — it cannot receive this
    // one, because objects that cross an isolate boundary are copies and a
    // subclass's overridden methods do not survive the trip.
    //
    // So a CUSTOMISED ratchet must never be routed here: its behaviour would be
    // silently replaced by the stock implementation. Caught by
    // `session_manager_concurrent_decrypt_test.dart`, which injects a logging
    // subclass to prove per-peer serialization and saw an empty log.
    //
    // An exact runtimeType check, not `is DoubleRatchetV3`: a subclass passes
    // `is` and is exactly the case we must exclude. `maxSkip` is forwarded
    // explicitly below because it is configuration, not behaviour.
    if (ratchet.runtimeType != DoubleRatchetV3) return inPlace();

    if (!await _ensureStarted()) return inPlace();
    final port = _toWorker;
    if (port == null) return inPlace();

    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      port.send(<String, dynamic>{
        'id': id,
        'maxSkip': ratchet.maxSkip,
        'state': _encodeState(state),
        'dh': headerDhPubB64,
        'pn': pn,
        'n': n,
        'ct': Uint8List.fromList(ciphertext),
        'pre': preloadedSkippedKey,
        'aad': Uint8List.fromList(aad),
      });
    } catch (_) {
      _pending.remove(id);
      _recycle();
      return inPlace();
    }

    final Map<String, dynamic> reply;
    try {
      reply = await completer.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      // A hung or dead worker must never hold a message hostage.
      _pending.remove(id);
      _recycle();
      return inPlace();
    }

    final err = reply['err'] as String?;
    if (err != null) {
      // 🔴 The worker reached a real ratchet verdict (e.g. "too many skipped
      // messages"). That is an ANSWER, not a transport failure, so it must be
      // raised — recomputing in place would only reach the same verdict, and
      // swallowing it would apply a message we never opened.
      if (reply['fatal'] == true) {
        _recycle();
        return inPlace();
      }
      throw RemoteDecryptError(err);
    }
    return _decodeResult(reply);
  }

  static Map<String, dynamic> _encodeState(DoubleRatchetStateV3 s) => {
        'peer': s.peerDeviceId,
        'root': s.rootKey,
        'seed': s.dhSelfSeed,
        'pub': s.dhSelfPub,
        'rpub': s.dhRemotePub,
        'sck': s.sendChainKey,
        'rck': s.recvChainKey,
        'ns': s.ns,
        'nr': s.nr,
        'pn': s.pn,
      };

  static DoubleRatchetStateV3 _decodeState(Map m) => DoubleRatchetStateV3(
        peerDeviceId: m['peer'] as String,
        rootKey: m['root'] as Uint8List,
        dhSelfSeed: m['seed'] as Uint8List,
        dhSelfPub: m['pub'] as Uint8List,
        dhRemotePub: m['rpub'] as Uint8List?,
        sendChainKey: m['sck'] as Uint8List?,
        recvChainKey: m['rck'] as Uint8List?,
        ns: m['ns'] as int,
        nr: m['nr'] as int,
        pn: m['pn'] as int,
      );

  static DoubleRatchetDecryptResultV3 _decodeResult(Map<String, dynamic> m) {
    final skipped = <SkippedKeyRecordV3>[];
    for (final raw in (m['skipped'] as List? ?? const [])) {
      final r = raw as Map;
      skipped.add(SkippedKeyRecordV3(
        dhPubB64: r['dh'] as String,
        msgNum: r['n'] as int,
        messageKey: r['mk'] as Uint8List,
      ));
    }
    return DoubleRatchetDecryptResultV3(
      updated: _decodeState(m['state'] as Map),
      plaintext: m['plain'] as Uint8List,
      skippedToStore: skipped,
      consumedPreloadedKey: m['consumed'] == true,
    );
  }

  /// The worker's entry point. Runs forever, one request at a time.
  ///
  /// It builds its OWN [DoubleRatchetV3] — the algorithm objects from
  /// package:cryptography are not worth sending, and constructing them is
  /// trivial. Crucially it opens no database and holds no app state, so it can
  /// never deadlock against the transaction the caller holds.
  static Future<void> _workerMain(SendPort toMain) async {
    final rp = ReceivePort();
    toMain.send(rp.sendPort);

    await for (final message in rp) {
      if (message is! Map) continue;
      final id = message['id'] as int?;
      if (id == null) continue;
      try {
        final dr = DoubleRatchetV3(maxSkip: message['maxSkip'] as int? ?? 200);
        final result = await dr.decrypt(
          state: _decodeState(message['state'] as Map),
          headerDhPubB64: message['dh'] as String,
          pn: message['pn'] as int,
          n: message['n'] as int,
          ciphertext: message['ct'] as Uint8List,
          preloadedSkippedKey: message['pre'] as Uint8List?,
          aad: message['aad'] as Uint8List,
        );
        toMain.send(<String, dynamic>{
          'id': id,
          'state': _encodeState(result.updated),
          'plain': result.plaintext,
          'consumed': result.consumedPreloadedKey,
          'skipped': [
            for (final r in result.skippedToStore)
              {'dh': r.dhPubB64, 'n': r.msgNum, 'mk': r.messageKey},
          ],
        });
      } catch (e) {
        // Н-6: the TEXT is the contract. Everything downstream classifies on it.
        toMain.send(<String, dynamic>{'id': id, 'err': e.toString()});
      }
    }
  }

  /// Test/teardown hook. Safe to call when nothing is running.
  void disposeForTesting() {
    _teardown();
    _spawnFailed = false;
  }
}
