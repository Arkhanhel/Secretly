// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Ключи одного зашифрованного созвона: свой ключ, ключи собеседников,
/// очередь установки и планировщик смены ключа (ТЗ E2EE созвонов, §4.4).
///
/// Без движка: всё, что трогает натив, идёт через [CallKeySink], поэтому
/// логика проверяется тестами без LiveKit и без платформы.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'call_e2ee_protocol.dart';

/// Куда ставятся ключи: в настоящем созвоне — нативный провайдер
/// `flutter_webrtc`, в тестах — запись вызовов.
abstract interface class CallKeySink {
  /// Поставить [key] участнику [participantId] в ячейку [index].
  ///
  /// 🔴 Каждый вызов — это PBKDF2 на 100 000 итераций в главном потоке
  /// платформы (ЛК-18). Поэтому [CallKeyBook] зовёт его строго по одному.
  Future<void> setKey(String participantId, int index, Uint8List key);

  /// Переключить шифрование СВОИХ дорожек на ячейку [index].
  Future<void> setOwnEncryptionIndex(int index);
}

/// Что разослать после смены своего ключа.
class OwnCallKey {
  OwnCallKey({required this.epoch, required this.index, required Uint8List key})
    : key = Uint8List.fromList(key);

  final int epoch;
  final int index;
  final Uint8List key;
}

class _RemoteKeyState {
  _RemoteKeyState(this.epoch, this.index, this.key);

  int epoch;
  int index;
  Uint8List key;
}

class _PendingSetKey {
  _PendingSetKey(this.participantId, this.index, this.key, this.own);

  final String participantId;
  final int index;
  final Uint8List key;
  final bool own;
}

/// Ключи одного созвона.
class CallKeyBook {
  CallKeyBook({
    required this.ownIdentity,
    required CallKeySink sink,
    Duration keySwitchDelay = const Duration(milliseconds: 2000),
    Duration explicitLeaveCoalesce = const Duration(milliseconds: 1500),
    Duration transportLossGrace = const Duration(seconds: 15),
    Random? random,
    int Function()? nowMs,
  }) : _sink = sink,
       _keySwitchDelay = _clampSwitchDelay(keySwitchDelay),
       _explicitLeaveCoalesce = explicitLeaveCoalesce,
       _transportLossGrace = transportLossGrace,
       _random = random ?? Random.secure(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// `I(P, D)` этого устройства.
  final String ownIdentity;

  final CallKeySink _sink;
  final Duration _keySwitchDelay;
  final Duration _explicitLeaveCoalesce;
  final Duration _transportLossGrace;
  final Random _random;
  final int Function() _nowMs;

  OwnCallKey? _own;
  int _activeOwnIndex = 0;
  final Map<String, _RemoteKeyState> _remote = <String, _RemoteKeyState>{};
  final Map<String, Queue<int>> _grantTimes = <String, Queue<int>>{};

  final Queue<_PendingSetKey> _queue = Queue<_PendingSetKey>();
  bool _draining = false;
  bool _disposed = false;

  Timer? _rotationTimer;
  Timer? _switchTimer;
  final Map<String, Timer> _lossTimers = <String, Timer>{};

  /// Позвать, когда нужна смена своего ключа: разослать [OwnCallKey] всем
  /// оставшимся. Ставит [CallKeyBook] сам — сюда приходит уже поставленный
  /// (в очередь) ключ.
  void Function(OwnCallKey key)? onOwnKeyRotated;

  /// Своя ячейка, которой сейчас шифруются свои дорожки. Её же отдаёт
  /// провайдер в `getLatestIndex`: новые публикации стартуют с неё, а не с
  /// ещё не включённой (ЛК, `key_provider.dart:156`).
  int get activeOwnIndex => _activeOwnIndex;

  OwnCallKey? get ownKey => _own;

  bool get isDisposed => _disposed;

  static Duration _clampSwitchDelay(Duration d) {
    const min = Duration(milliseconds: 500);
    const max = Duration(milliseconds: 5000);
    if (d < min) return min;
    if (d > max) return max;
    return d;
  }

  Uint8List _newKey() {
    final out = Uint8List(kCallKeyLength);
    for (var i = 0; i < out.length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// Начало отсчёта эпох: 01.01.2025 00:00 UTC, в секундах.
  static const int _epochBaseSeconds = 1735689600;

  /// Первый свой ключ, ячейка 0. Ставится до подключения.
  ///
  /// 🔴 Эпоха — секунды от [_epochBaseSeconds], а не 1. Иначе после
  /// перезапуска приложения посреди созвона новый ключ этого устройства
  /// приходил бы собеседникам с эпохой 1 — меньше уже принятой — и
  /// отбрасывался бы как старый: устройство молчало бы до конца созвона.
  Future<OwnCallKey> createInitialOwnKey() async {
    final existing = _own;
    if (existing != null) return existing;
    final seconds = _nowMs() ~/ 1000 - _epochBaseSeconds;
    final key = OwnCallKey(
      epoch: seconds < 1 ? 1 : seconds,
      index: 0,
      key: _newKey(),
    );
    _own = key;
    _activeOwnIndex = 0;
    await _enqueueAndWait(_PendingSetKey(ownIdentity, 0, key.key, true));
    return key;
  }

  /// Новый свой ключ (уход участника, полное переподключение). Ключ ставится
  /// в новую ячейку сразу, а шифрование переходит на неё через задержку:
  /// получатели успевают получить ключ, а опоздавшие кадры старой ячейки
  /// остаются читаемыми.
  Future<OwnCallKey> rotateOwnKey() async {
    final previous = _own;
    final next = OwnCallKey(
      epoch: (previous?.epoch ?? 0) + 1,
      index: previous == null ? 0 : (previous.index + 1) % kCallKeyRingSize,
      key: _newKey(),
    );
    _own = next;
    await _enqueueAndWait(
      _PendingSetKey(ownIdentity, next.index, next.key, true),
    );
    _switchTimer?.cancel();
    if (previous == null) {
      _activeOwnIndex = next.index;
      await _sink.setOwnEncryptionIndex(next.index);
    } else {
      _switchTimer = Timer(_keySwitchDelay, () {
        if (_disposed || !identical(_own, next)) return;
        _activeOwnIndex = next.index;
        unawaited(_sink.setOwnEncryptionIndex(next.index));
      });
    }
    return next;
  }

  /// Сколько ключей от [identity] пришло за последнюю минуту.
  int grantsFromLastMinute(String identity) {
    final times = _grantTimes[identity];
    if (times == null) return 0;
    final cutoff = _nowMs() - const Duration(minutes: 1).inMilliseconds;
    while (times.isNotEmpty && times.first < cutoff) {
      times.removeFirst();
    }
    return times.length;
  }

  int? lastEpochFrom(String identity) => _remote[identity]?.epoch;

  Uint8List? lastKeyFrom(String identity) => _remote[identity]?.key;

  bool hasKeyFor(String identity) => _remote.containsKey(identity);

  /// Принять ключ собеседника, уже прошедший [checkRoomCallKeyGrant].
  void acceptRemoteKey(RoomCallKeyGrant grant) {
    if (_disposed) return;
    final times = _grantTimes.putIfAbsent(grant.identity, Queue<int>.new);
    times.addLast(_nowMs());
    final state = _remote[grant.identity];
    if (state != null &&
        state.epoch == grant.epoch &&
        state.index == grant.keyIndex &&
        _bytesEqual(state.key, grant.key)) {
      return;
    }
    _remote[grant.identity] = _RemoteKeyState(
      grant.epoch,
      grant.keyIndex,
      Uint8List.fromList(grant.key),
    );
    unawaited(
      _enqueueAndWait(
        _PendingSetKey(grant.identity, grant.keyIndex, grant.key, false),
      ),
    );
  }

  /// Участник ушёл. [explicit] — уход сказан реле или видна смена членства
  /// (вышел, исключён, забанен, созвон закончен): ротация через 1,5 с с
  /// группировкой. Иначе пропал только транспорт LiveKit: ждём до 15 с и
  /// отменяем, если тот же участник вернулся.
  void onParticipantGone(String identity, {required bool explicit}) {
    if (_disposed) return;
    _remote.remove(identity);
    if (explicit) {
      _lossTimers.remove(identity)?.cancel();
      _scheduleRotation();
      return;
    }
    if (_lossTimers.containsKey(identity)) return;
    _lossTimers[identity] = Timer(_transportLossGrace, () {
      _lossTimers.remove(identity);
      if (_disposed) return;
      _scheduleRotation();
    });
  }

  /// Тот же участник снова на связи: ротация из-за его пропажи не нужна.
  void onParticipantBack(String identity) {
    _lossTimers.remove(identity)?.cancel();
  }

  bool get rotationPending =>
      (_rotationTimer?.isActive ?? false) || _lossTimers.isNotEmpty;

  void _scheduleRotation() {
    if (_rotationTimer?.isActive ?? false) return;
    _rotationTimer = Timer(_explicitLeaveCoalesce, () {
      if (_disposed) return;
      unawaited(() async {
        final rotated = await rotateOwnKey();
        if (_disposed) return;
        onOwnKeyRotated?.call(rotated);
      }());
    });
  }

  Future<void> _enqueueAndWait(_PendingSetKey item) {
    if (_disposed) return Future<void>.value();
    final completer = Completer<void>();
    // Свой ключ — вперёд очереди: без него не уходит ни один свой кадр.
    if (item.own) {
      _queue.addFirst(item);
    } else {
      _queue.addLast(item);
    }
    _waiters[item] = completer;
    unawaited(_drain());
    return completer.future;
  }

  final Map<_PendingSetKey, Completer<void>> _waiters =
      <_PendingSetKey, Completer<void>>{};

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final item = _queue.removeFirst();
        // Устаревший ключ собеседника (за ним в очереди или уже поставлен
        // новее) пропускаем: каждый лишний вызов — это PBKDF2.
        final skip = !item.own && _isSupersededRemote(item);
        if (!skip) {
          try {
            await _sink.setKey(item.participantId, item.index, item.key);
          } catch (_) {
            // Ошибку натива не прячем молча: ячейка без ключа даст
            // `missingKey`, и дорожка не включится (закрытый отказ).
          }
        }
        _waiters.remove(item)?.complete();
        // Отдать кадр интерфейсу между вызовами PBKDF2.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _draining = false;
    }
  }

  bool _isSupersededRemote(_PendingSetKey item) {
    final current = _remote[item.participantId];
    if (current == null) return true;
    return current.index != item.index || !_bytesEqual(current.key, item.key);
  }

  /// Конец созвона: таймеры стоп, копии ключей затёрты.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rotationTimer?.cancel();
    _switchTimer?.cancel();
    for (final t in _lossTimers.values) {
      t.cancel();
    }
    _lossTimers.clear();
    _own?.key.fillRange(0, kCallKeyLength, 0);
    for (final s in _remote.values) {
      s.key.fillRange(0, s.key.length, 0);
    }
    _remote.clear();
    for (final item in _queue) {
      item.key.fillRange(0, item.key.length, 0);
    }
    _queue.clear();
    for (final c in _waiters.values) {
      if (!c.isCompleted) c.complete();
    }
    _waiters.clear();
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
