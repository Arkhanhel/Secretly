// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'secure_storage_options.dart';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'serialized_secure_storage.dart';

class DeviceKeys {
  DeviceKeys._(this._secureStorage);

  static DeviceKeys create() {
    return DeviceKeys._(
      const SerializedSecureStorage(
        aOptions: kSecretlyAndroidStorageOptions,
        // `first_unlock_this_device` (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        // — ключи устройства должны читаться после ПЕРВОЙ разблокировки с
        // момента загрузки, в том числе на ЗАБЛОКИРОВАННОМ устройстве (пробуждение
        // пушем, запуск до разблокировки). Значение по умолчанию (`whenUnlocked`)
        // давало errSecInteractionNotAllowed (-25308) и фатальный экран.
        //
        // 🔴 Суффикс `_this_device` добавлен 25.08.2026 (SEC-02): без него Apple
        // переносит запись на НОВОЕ устройство вместе с резервной копией, а наша
        // модель безопасности привязана к устройству — номер безопасности
        // принадлежит устройству, и новое обязано выглядеть новым. Момент
        // доступности при этом тот же, отличается только запрет переноса.
        // Перенос уже записанных значений делает KeychainAccessibilityMigration.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          useDataProtectionKeyChain: false,
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    );
  }

  static String validateMaterialJson(String rawJson) {
    final normalized = rawJson.trim();
    if (normalized.isEmpty) {
      throw StateError('device keys missing material json');
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        throw StateError('device keys material must be an object');
      }

      _DeviceKeyMaterialV1.fromJson(Map<String, dynamic>.from(decoded));
      return normalized;
    } on FormatException {
      throw StateError('device keys invalid material json');
    }
  }

  final FlutterSecureStorage _secureStorage;

  static String _storageKey({
    required String profileId,
    required String deviceId,
  }) {
    return 'secretly/device_keys_v1/$profileId/$deviceId';
  }

  Future<_DeviceKeyMaterialV1> _loadOrCreateMaterial({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final existingRaw = await _secureStorage.read(key: key);
    final material = existingRaw == null || existingRaw.isEmpty
        ? _DeviceKeyMaterialV1.createNew()
        : _DeviceKeyMaterialV1.fromJson(
            jsonDecode(existingRaw) as Map<String, dynamic>,
          );
    if (existingRaw == null || existingRaw.isEmpty) {
      await _secureStorage.write(
        key: key,
        value: jsonEncode(material.toJson()),
      );
    }
    return material;
  }

  Future<SimpleKeyPair> loadIdentityKeyPair({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return Ed25519().newKeyPairFromSeed(material.identitySeed);
  }

  /// С-2 (24.09.2026): ключ личности ТОЛЬКО если он уже есть.
  ///
  /// 🔴 [loadIdentityKeyPair] при отсутствии материала молча СОЗДАЁТ новый и
  /// записывает его. Для подписи рукопожатия это недопустимо: не тот профиль в
  /// вызове породил бы чужой ключ, и им подписались бы как «своим». Здесь
  /// отсутствие или порча материала — `null`, и ничего не пишется.
  Future<SimpleKeyPair?> loadIdentityKeyPairIfPresent({
    required String profileId,
    required String deviceId,
  }) async {
    if (profileId.trim().isEmpty || deviceId.trim().isEmpty) return null;
    try {
      final raw = await _secureStorage.read(
        key: _storageKey(profileId: profileId, deviceId: deviceId),
      );
      if (raw == null || raw.isEmpty) return null;
      final material = _DeviceKeyMaterialV1.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return Ed25519().newKeyPairFromSeed(material.identitySeed);
    } catch (_) {
      return null;
    }
  }

  /// iOS NSE (2026-07-17): base64 of the raw Ed25519 identity SEED, mirrored
  /// into the App Group so the Notification Service Extension can sign
  /// GET /v1/pending in the background. This is the device auth key, NOT a
  /// message-decryption key. Callers must only hand it to the App-Group
  /// bridge, never the network.
  Future<String> loadIdentitySeedB64({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return base64Encode(material.identitySeed);
  }

  Future<SimpleKeyPair> loadSignedPrekeyKeyPair({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return X25519().newKeyPairFromSeed(material.signedPrekeySeed);
  }

  /// Б5 (24.10.2026): every read-modify-write of the material goes through
  /// here. The material is ONE secure-storage record; two writers each reading
  /// it and writing back would silently drop the other's change — a lost OTK
  /// seed that keys has already handed out breaks that handshake. The queue is
  /// per record and shared by all instances (callers create a new
  /// [DeviceKeys] each time).
  static final Map<String, Future<void>> _materialLocks = <String, Future<void>>{};

  static Future<T> _withMaterialLock<T>(String key, Future<T> Function() body) {
    final previous = _materialLocks[key] ?? Future<void>.value();
    final run = previous.then((_) => body());
    final tail = run.then<void>((_) {}, onError: (Object _) {});
    _materialLocks[key] = tail;
    tail.whenComplete(() {
      if (identical(_materialLocks[key], tail)) _materialLocks.remove(key);
    });
    return run;
  }

  /// Б5 (24.10.2026): signed prekeys to try for an incoming handshake, in
  /// order. A sender that names a number other than 1 gets exactly that key
  /// (if we still hold it); 1 — what every build before Б5 sends whatever key
  /// it used — means "try the current one, then the previous ones, newest
  /// first". Never more than [maxCandidates]. Until a device rotates this is
  /// always the single current key, exactly as before.
  Future<List<SignedPrekeyCandidate>> loadSignedPrekeyCandidates({
    required String profileId,
    required String deviceId,
    int? signedPrekeyId,
    int maxCandidates = 1 + _DeviceKeyMaterialV1.maxPreviousSpks,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    final x = X25519();
    final ordered = <(int, Uint8List)>[
      (material.signedPrekeyId, material.signedPrekeySeed),
      for (final p in material.previousSpks) (p.id, p.seed),
    ];
    final named = signedPrekeyId != null && signedPrekeyId != 1
        ? ordered.where((e) => e.$1 == signedPrekeyId).toList()
        : const <(int, Uint8List)>[];
    final pick = named.isNotEmpty ? named : ordered;
    final out = <SignedPrekeyCandidate>[];
    for (final (id, seed) in pick.take(maxCandidates)) {
      out.add(SignedPrekeyCandidate(id, await x.newKeyPairFromSeed(seed)));
    }
    return out;
  }

  /// Б5 Э3 (24.10.2026, flag `spk_rotate_share`): rotate the signed prekey
  /// when it is [rotateEveryMs] old and forget previous ones nobody can still
  /// name. Returns whether it rotated; the caller then publishes the new key.
  ///
  /// The new key gets the next number; the old one moves to the front of
  /// `previous_spks`. A previous key is dropped only when at least two newer
  /// keys exist AND it was retired [retainMs] ago (30 days — longer than an
  /// envelope lives on the relay); at most [_DeviceKeyMaterialV1.maxPreviousSpks]
  /// are kept. A key from before Б5 has no creation time and rotates at once.
  Future<bool> maintainSignedPrekey({
    required String profileId,
    required String deviceId,
    required int nowMs,
    required int rotateEveryMs,
    int retainMs = 30 * 24 * 60 * 60 * 1000,
  }) {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    return _withMaterialLock(key, () async {
      final raw = await _secureStorage.read(key: key);
      if (raw == null || raw.isEmpty) return false;
      final material = _DeviceKeyMaterialV1.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      var changed = false;
      final created = material.signedPrekeyCreatedMs;
      final rotate = created == null || nowMs - created >= rotateEveryMs;
      if (rotate) {
        final usedIds = <int>[
          material.signedPrekeyId,
          for (final p in material.previousSpks) p.id,
        ];
        material.previousSpks.insert(
          0,
          _PreviousSpk(
            id: material.signedPrekeyId,
            seed: material.signedPrekeySeed,
            createdMs: created ?? 0,
            retiredMs: nowMs,
          ),
        );
        material.signedPrekeySeed = _randomBytes(32);
        material.signedPrekeyId = usedIds.reduce(max) + 1;
        material.signedPrekeyCreatedMs = nowMs;
        changed = true;
      }
      final kept = <_PreviousSpk>[];
      for (var i = 0; i < material.previousSpks.length; i++) {
        final p = material.previousSpks[i];
        final newer = i + 1; // the current key and every earlier entry
        final expired = newer >= 2 && nowMs - p.retiredMs >= retainMs;
        if (!expired && kept.length < _DeviceKeyMaterialV1.maxPreviousSpks) {
          kept.add(p);
        }
      }
      if (kept.length != material.previousSpks.length) {
        material.previousSpks
          ..clear()
          ..addAll(kept);
        changed = true;
      }
      if (changed) {
        await _secureStorage.write(
            key: key, value: jsonEncode(material.toJson()));
      }
      return rotate;
    });
  }

  /// Б5 (24.10.2026): remember when an incoming handshake first used one-time
  /// prekey [prekeyId]. Э1 only records it; deleting the seed 48 h later is Э2,
  /// behind its own flag. Writes only when something changes.
  Future<void> markOneTimePrekeyUsed({
    required String profileId,
    required String deviceId,
    required int prekeyId,
    required int nowMs,
  }) {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    return _withMaterialLock(key, () async {
      final raw = await _secureStorage.read(key: key);
      if (raw == null || raw.isEmpty) return;
      final material = _DeviceKeyMaterialV1.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final id = '$prekeyId';
      if (!material.otkSeedById.containsKey(id)) return;
      if (material.otkUsedMsById.containsKey(id)) return;
      material.otkUsedMsById[id] = nowMs;
      await _secureStorage.write(key: key, value: jsonEncode(material.toJson()));
    });
  }

  /// Б5 Э2 (24.10.2026, flag `otk_hygiene_share`): forget private halves of
  /// one-time prekeys that can no longer be needed.
  ///
  /// * Used by an incoming handshake at least [usedGraceMs] ago (48 h): a
  ///   redelivery inside that window still opens; after it the sender's
  ///   `forceSpkOnly` retry takes over.
  /// * Handed out or dropped by keys — number below [minRemainingId], or below
  ///   the next number when keys has none left ([otkRemaining] == 0) — and
  ///   allocated at least [handedOutMaxAgeMs] ago (60 days, longer than an
  ///   envelope lives on the relay). Keys from before Б5 carry no allocation
  ///   time; they count from the first recorded batch, so they go 60 days after
  ///   this build first allocated.
  ///
  /// With [otkRemaining] `null` (keys did not say) only the first rule runs.
  /// Returns how many were removed; writes only when something was.
  Future<int> pruneOneTimePrekeySeeds({
    required String profileId,
    required String deviceId,
    required int nowMs,
    required int? otkRemaining,
    required int? minRemainingId,
    int usedGraceMs = 48 * 60 * 60 * 1000,
    int handedOutMaxAgeMs = 60 * 24 * 60 * 60 * 1000,
  }) {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    return _withMaterialLock(key, () async {
      final raw = await _secureStorage.read(key: key);
      if (raw == null || raw.isEmpty) return 0;
      final material = _DeviceKeyMaterialV1.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final int? handedOutBelow = otkRemaining == null
          ? null
          : (otkRemaining > 0 ? minRemainingId : material.nextOtkId);
      final firstMarkMs =
          material.otkAllocMarks.isEmpty ? null : material.otkAllocMarks.first[1];
      final remove = <String>[];
      for (final idStr in material.otkSeedById.keys) {
        final used = material.otkUsedMsById[idStr];
        if (used != null && nowMs - used >= usedGraceMs) {
          remove.add(idStr);
          continue;
        }
        final id = int.tryParse(idStr);
        if (id == null || handedOutBelow == null || id >= handedOutBelow) {
          continue;
        }
        final allocated = material.otkAllocatedMs(id) ?? firstMarkMs;
        if (allocated != null && nowMs - allocated >= handedOutMaxAgeMs) {
          remove.add(idStr);
        }
      }
      if (remove.isEmpty) return 0;
      for (final idStr in remove) {
        material.otkSeedById.remove(idStr);
        material.otkUsedMsById.remove(idStr);
      }
      // Marks of batches with no seed left are dead weight — keep the last
      // mark at or below the lowest remaining id so its age stays known.
      final lowest = material.otkSeedById.keys
          .map(int.tryParse)
          .whereType<int>()
          .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
      if (lowest != null) {
        var keepFrom = 0;
        for (var i = 0; i < material.otkAllocMarks.length; i++) {
          if (material.otkAllocMarks[i][0] <= lowest) keepFrom = i;
        }
        if (keepFrom > 0) material.otkAllocMarks.removeRange(0, keepFrom);
      }
      await _secureStorage.write(key: key, value: jsonEncode(material.toJson()));
      return remove.length;
    });
  }

  Future<SimpleKeyPair?> loadOneTimePrekeyKeyPair({
    required String profileId,
    required String deviceId,
    required int prekeyId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    final b64 = material.otkSeedById['$prekeyId'];
    if (b64 == null || b64.isEmpty) return null;
    final seed = Uint8List.fromList(base64Decode(b64));
    return X25519().newKeyPairFromSeed(seed);
  }

  Future<DeviceKeyBundleV1> createOrLoadAndAllocateOtk({
    required String profileId,
    required String deviceId,
    required int allocateOneTimePrekeys,
  }) async {
    if (allocateOneTimePrekeys < 0) {
      throw ArgumentError.value(
        allocateOneTimePrekeys,
        'allocateOneTimePrekeys',
        'must be >= 0',
      );
    }

    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    return _withMaterialLock(key, () async {
      final existingRaw = await _secureStorage.read(key: key);
      final material = existingRaw == null || existingRaw.isEmpty
          ? _DeviceKeyMaterialV1.createNew()
          : _DeviceKeyMaterialV1.fromJson(
              jsonDecode(existingRaw) as Map<String, dynamic>,
            );

      final ed = Ed25519();
      final x = X25519();

      final identitySeed = material.identitySeed;
      final signedPrekeySeed = material.signedPrekeySeed;

      final identityKeyPair = await ed.newKeyPairFromSeed(identitySeed);
      final identityPub = await identityKeyPair.extractPublicKey();

      final signedPrekeyKeyPair = await x.newKeyPairFromSeed(signedPrekeySeed);
      final signedPrekeyPub = await signedPrekeyKeyPair.extractPublicKey();

      final signature = await ed.sign(
        signedPrekeyPub.bytes,
        keyPair: identityKeyPair,
      );

      final allocated = <Map<String, Object?>>[];
      var nextId = material.nextOtkId;

      for (var i = 0; i < allocateOneTimePrekeys; i++) {
        final id = nextId;
        nextId++;

        final seed = _randomBytes(32);
        final kp = await x.newKeyPairFromSeed(seed);
        final pub = await kp.extractPublicKey();

        material.otkSeedById['$id'] = base64Encode(seed);
        allocated.add({
          'prekey_id': id,
          'prekey_pub_b64': base64Encode(pub.bytes),
        });
      }

      if (allocated.isNotEmpty) {
        material.noteOtkAllocation(
          firstId: material.nextOtkId,
          atMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      material.nextOtkId = nextId;

      final encoded = jsonEncode(material.toJson());
      await _secureStorage.write(key: key, value: encoded);

      return DeviceKeyBundleV1(
        identityKeyPubB64: base64Encode(identityPub.bytes),
        signedPrekeyPubB64: base64Encode(signedPrekeyPub.bytes),
        signedPrekeySigB64: base64Encode(signature.bytes),
        oneTimePrekeys: allocated,
        signedPrekeyId: material.signedPrekeyId,
        materialBytes: utf8.encode(encoded).length,
        oneTimePrekeySeedCount: material.otkSeedById.length,
      );
    });
  }

  Future<void> debugDumpPresence({
    required String profileId,
    required String deviceId,
  }) async {
    if (!kDebugMode) return;
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final raw = await _secureStorage.read(key: key);
    debugPrint('DeviceKeys: material=${raw == null ? 'missing' : 'set'}');
  }

  Future<void> deleteMaterial({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    await _secureStorage.delete(key: key);
  }

  Future<String?> exportMaterialJson({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final raw = await _secureStorage.read(key: key);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> importMaterialJson({
    required String profileId,
    required String deviceId,
    required String rawJson,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    await _secureStorage.write(key: key, value: validateMaterialJson(rawJson));
  }
}

class DeviceKeyBundleV1 {
  const DeviceKeyBundleV1({
    required this.identityKeyPubB64,
    required this.signedPrekeyPubB64,
    required this.signedPrekeySigB64,
    required this.oneTimePrekeys,
    this.signedPrekeyId = 1,
    this.materialBytes = 0,
    this.oneTimePrekeySeedCount = 0,
  });

  final String identityKeyPubB64;
  final String signedPrekeyPubB64;
  final String signedPrekeySigB64;
  final List<Map<String, Object?>> oneTimePrekeys;

  /// Б5 (24.10.2026): number of the current signed prekey (1 until rotation).
  final int signedPrekeyId;

  /// Б5 диагностика: size of the stored material and how many OTK private
  /// halves it holds — the numbers Э2 is meant to bring down.
  final int materialBytes;
  final int oneTimePrekeySeedCount;
}

/// Б5 (24.10.2026): one signed prekey this device may have published.
class SignedPrekeyCandidate {
  const SignedPrekeyCandidate(this.id, this.keyPair);

  final int id;
  final SimpleKeyPair keyPair;
}

/// Б5: a signed prekey that is no longer current but may still be named by
/// handshakes in flight.
class _PreviousSpk {
  const _PreviousSpk({
    required this.id,
    required this.seed,
    required this.createdMs,
    required this.retiredMs,
  });

  final int id;
  final Uint8List seed;
  final int createdMs;
  final int retiredMs;

  static _PreviousSpk? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final seedB64 = raw['seed_b64'];
    if (id is! num || id.toInt() < 1 || seedB64 is! String) return null;
    try {
      final seed = base64Decode(seedB64);
      if (seed.length != 32) return null;
      return _PreviousSpk(
        id: id.toInt(),
        seed: Uint8List.fromList(seed),
        createdMs: (raw['created_ms'] as num?)?.toInt() ?? 0,
        retiredMs: (raw['retired_ms'] as num?)?.toInt() ?? 0,
      );
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'seed_b64': base64Encode(seed),
        'created_ms': createdMs,
        'retired_ms': retiredMs,
      };
}

/// Б5 (24.10.2026), format v2: the v1 fields are untouched and keep their
/// meaning — `signed_prekey_seed_b64` is ALWAYS the current signed prekey — so a
/// build from before Б5 reads a v2 record and goes on working (it drops the new
/// fields on its next write; previous signed prekeys are then lost and the
/// handshakes that named them recover through `forceSpkOnly`). The new fields
/// are optional and parsed leniently: a damaged one is ignored, never fatal —
/// failing here would leave the device without its keys.
class _DeviceKeyMaterialV1 {
  _DeviceKeyMaterialV1({
    required this.identitySeed,
    required this.signedPrekeySeed,
    required this.nextOtkId,
    required this.otkSeedById,
    this.signedPrekeyId = 1,
    this.signedPrekeyCreatedMs,
    List<_PreviousSpk>? previousSpks,
    List<List<int>>? otkAllocMarks,
    Map<String, int>? otkUsedMsById,
  })  : previousSpks = previousSpks ?? <_PreviousSpk>[],
        otkAllocMarks = otkAllocMarks ?? <List<int>>[],
        otkUsedMsById = otkUsedMsById ?? <String, int>{};

  /// At most this many allocation marks are kept (one per publish that adds
  /// keys: about a year at the current pace).
  static const int _maxAllocMarks = 512;

  /// Б5 Э3: previous signed prekeys kept; with weekly rotation and 30 days of
  /// retention four are needed, one spare.
  static const int maxPreviousSpks = 5;

  factory _DeviceKeyMaterialV1.createNew() {
    return _DeviceKeyMaterialV1(
      identitySeed: _randomBytes(32),
      signedPrekeySeed: _randomBytes(32),
      nextOtkId: 1,
      otkSeedById: <String, String>{},
    );
  }

  factory _DeviceKeyMaterialV1.fromJson(Map<String, dynamic> json) {
    Uint8List readSeed(String key) {
      final v = json[key] as String?;
      if (v == null || v.isEmpty) throw StateError('device keys missing $key');
      try {
        final bytes = base64Decode(v);
        if (bytes.length != 32) {
          throw StateError('device keys invalid $key');
        }
        return Uint8List.fromList(bytes);
      } on FormatException {
        throw StateError('device keys invalid $key');
      }
    }

    final next = (json['next_otk_id'] as num?)?.toInt() ?? 1;
    final otkRaw = json['otk_seed_by_id'];
    final otk = <String, String>{};
    if (otkRaw is Map) {
      otkRaw.forEach((key, value) {
        final prekeyId = key.toString().trim();
        if (prekeyId.isEmpty || value is! String || value.isEmpty) {
          throw StateError('device keys invalid otk_seed_by_id');
        }
        try {
          final bytes = base64Decode(value);
          if (bytes.length != 32) {
            throw StateError('device keys invalid otk_seed_by_id');
          }
        } on FormatException {
          throw StateError('device keys invalid otk_seed_by_id');
        }
        otk[prekeyId] = value;
      });
    } else if (otkRaw != null) {
      throw StateError('device keys invalid otk_seed_by_id');
    }

    final spkIdRaw = json['signed_prekey_id'];
    final spkId =
        spkIdRaw is num && spkIdRaw.toInt() >= 1 ? spkIdRaw.toInt() : 1;
    final spkCreatedRaw = json['signed_prekey_created_ms'];
    final spkCreated =
        spkCreatedRaw is num && spkCreatedRaw > 0 ? spkCreatedRaw.toInt() : null;
    final previous = <_PreviousSpk>[];
    final previousRaw = json['previous_spks'];
    if (previousRaw is List) {
      for (final entry in previousRaw) {
        final p = _PreviousSpk.tryParse(entry);
        if (p != null && p.id != spkId) previous.add(p);
      }
    }
    final marks = <List<int>>[];
    final marksRaw = json['otk_alloc_marks'];
    if (marksRaw is List) {
      for (final m in marksRaw) {
        if (m is List && m.length == 2 && m[0] is num && m[1] is num) {
          marks.add(<int>[(m[0] as num).toInt(), (m[1] as num).toInt()]);
        }
      }
    }
    final used = <String, int>{};
    final usedRaw = json['otk_used_ms_by_id'];
    if (usedRaw is Map) {
      usedRaw.forEach((k, v) {
        if (v is num) used[k.toString()] = v.toInt();
      });
    }

    return _DeviceKeyMaterialV1(
      identitySeed: readSeed('identity_seed_b64'),
      signedPrekeySeed: readSeed('signed_prekey_seed_b64'),
      nextOtkId: next,
      otkSeedById: otk,
      signedPrekeyId: spkId,
      signedPrekeyCreatedMs: spkCreated,
      previousSpks: previous,
      otkAllocMarks: marks,
      otkUsedMsById: used,
    );
  }

  Uint8List identitySeed;
  Uint8List signedPrekeySeed;
  int nextOtkId;
  final Map<String, String> otkSeedById;

  /// Б5: number of [signedPrekeySeed]; 1 until the first rotation.
  int signedPrekeyId;

  /// Б5 Э3: when [signedPrekeySeed] became current; `null` before the first
  /// rotation (its age is unknown, so the first rotation is immediate).
  int? signedPrekeyCreatedMs;

  /// Б5: earlier signed prekeys, newest first.
  final List<_PreviousSpk> previousSpks;

  /// Б5: `[first OTK id of a batch, when it was allocated]`, oldest first. OTK
  /// ids only grow, so the batch of any id is the last mark at or below it.
  final List<List<int>> otkAllocMarks;

  /// Б5: when an incoming handshake first used an OTK.
  final Map<String, int> otkUsedMsById;

  void noteOtkAllocation({required int firstId, required int atMs}) {
    otkAllocMarks.add(<int>[firstId, atMs]);
    if (otkAllocMarks.length > _maxAllocMarks) {
      otkAllocMarks.removeRange(0, otkAllocMarks.length - _maxAllocMarks);
    }
  }

  /// When OTK [id] was allocated, or `null` for keys from before Б5.
  int? otkAllocatedMs(int id) {
    int? at;
    for (final m in otkAllocMarks) {
      if (m[0] > id) break;
      at = m[1];
    }
    return at;
  }

  Map<String, Object?> toJson() {
    return {
      'identity_seed_b64': base64Encode(identitySeed),
      'signed_prekey_seed_b64': base64Encode(signedPrekeySeed),
      'next_otk_id': nextOtkId,
      'otk_seed_by_id': otkSeedById,
      // Б5: written only when they carry something, so a device that never
      // rotates keeps a v1-shaped record.
      if (signedPrekeyId != 1) 'signed_prekey_id': signedPrekeyId,
      if (signedPrekeyCreatedMs != null)
        'signed_prekey_created_ms': signedPrekeyCreatedMs,
      if (previousSpks.isNotEmpty)
        'previous_spks': [for (final p in previousSpks) p.toJson()],
      if (otkAllocMarks.isNotEmpty) 'otk_alloc_marks': otkAllocMarks,
      if (otkUsedMsById.isNotEmpty) 'otk_used_ms_by_id': otkUsedMsById,
    };
  }
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < out.length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}
