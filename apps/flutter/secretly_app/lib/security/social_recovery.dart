// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'recovery_kit.dart';
import 'shamir_gf256.dart';

/// Социальное восстановление личности (Э3 «Мессенджер без центра», 11.10.2026).
///
/// Владелец выбирает хранителей — проверенных контактов. Секрет личности
/// (тот же набор, что в наборе восстановления: профиль, его секрет, ключ
/// личности аккаунта, привязка к серверу) шифруется случайным ключом `K`
/// (XChaCha20-Poly1305), а `K` делится по Шамиру. Каждый хранитель получает
/// свою долю и копию зашифрованного блока. Любые `t` хранителей вместе
/// возвращают личность; `t − 1` не узнают о ней ничего.
///
/// Восстановление на новом устройстве: человек ставит приложение (это
/// временный профиль), показывает хранителям код с проверочными словами,
/// хранитель СВЕРЯЕТ слова голосом или лично и отправляет свою долю на
/// временный профиль. Набрав `t` долей, приложение собирает набор и
/// восстанавливается обычным путём набора восстановления.
///
/// 🔴 Главная атака — социальная: злоумышленник с кодом уговаривает `t`
/// хранителей. Техники против неё нет, есть только порядок: слова-проверка,
/// текст «подтвердите голосом», порог не меньше двух.
class SocialRecovery {
  SocialRecovery._();

  static const int formatVersion = 1;
  static const int minGuardians = 2;
  static const int maxGuardians = 5;
  static const int keyLength = 32;
  static const String _aadPrefix = 'secretly-social-recovery-v1';

  static final Xchacha20 _aead = Xchacha20.poly1305Aead();

  static List<int> _aad(String ownerProfileId, int version) =>
      utf8.encode('$_aadPrefix|$ownerProfileId|$version');

  /// Шифрует набор и делит ключ. [version] растёт при каждой смене состава —
  /// доли разных версий не смешиваются.
  static Future<SocialRecoverySetup> createSetup({
    required RecoveryKitPlainV1 kit,
    required int threshold,
    required int guardians,
    required int version,
    String? safeBackupAutoPassword,
    Random? random,
  }) async {
    if (guardians < minGuardians || guardians > maxGuardians) {
      throw ArgumentError('guardians must be in [$minGuardians, $maxGuardians]');
    }
    if (threshold < ShamirGf256.minThreshold || threshold > guardians) {
      throw ArgumentError('threshold must be in [2, $guardians]');
    }
    final rng = random ?? Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(keyLength, (_) => rng.nextInt(256)),
    );
    final nonce = Uint8List.fromList(
      List<int>.generate(24, (_) => rng.nextInt(256)),
    );
    final plain = <String, Object?>{
      'v': formatVersion,
      'kit': kit.toJson(),
      if ((safeBackupAutoPassword ?? '').isNotEmpty)
        'safe_backup_auto_password': safeBackupAutoPassword,
    };
    final box = await _aead.encrypt(
      utf8.encode(jsonEncode(plain)),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: _aad(kit.profileId, version),
    );
    final blob = Uint8List.fromList(<int>[
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    final shares = ShamirGf256.split(
      key,
      threshold: threshold,
      shares: guardians,
      random: rng,
    );
    return SocialRecoverySetup(
      ownerProfileId: kit.profileId,
      version: version,
      threshold: threshold,
      blobB64: base64Encode(blob),
      sharesB64: shares.map(base64Encode).toList(growable: false),
    );
  }

  /// Собирает набор из долей. Бросает [SocialRecoveryException] с понятной
  /// причиной: мало долей, разные версии, подмена (не сходится AEAD).
  static Future<SocialRecoveryResult> recover(
    List<GuardianRelease> releases,
  ) async {
    if (releases.isEmpty) {
      throw const SocialRecoveryException('no_shares');
    }
    final first = releases.first;
    final sameSet = releases.every(
      (r) =>
          r.ownerProfileId == first.ownerProfileId &&
          r.version == first.version &&
          r.threshold == first.threshold &&
          r.blobB64 == first.blobB64,
    );
    if (!sameSet) throw const SocialRecoveryException('mixed_sets');
    final unique = <int, Uint8List>{};
    for (final r in releases) {
      final share = base64Decode(r.shareB64);
      if (share.length != keyLength + 1) {
        throw const SocialRecoveryException('bad_share');
      }
      unique[share[0]] = share;
    }
    if (unique.length < first.threshold) {
      throw const SocialRecoveryException('not_enough_shares');
    }
    final key = ShamirGf256.combine(
      unique.values.take(first.threshold).toList(growable: false),
    );
    final blob = base64Decode(first.blobB64);
    if (blob.length < 24 + 16) throw const SocialRecoveryException('bad_blob');
    final nonce = blob.sublist(0, 24);
    final mac = blob.sublist(blob.length - 16);
    final cipher = blob.sublist(24, blob.length - 16);
    final List<int> clear;
    try {
      clear = await _aead.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: _aad(first.ownerProfileId, first.version),
      );
    } on SecretBoxAuthenticationError {
      throw const SocialRecoveryException('auth_failed');
    }
    final json = jsonDecode(utf8.decode(clear));
    if (json is! Map || json['v'] != formatVersion || json['kit'] is! Map) {
      throw const SocialRecoveryException('bad_payload');
    }
    final kit = RecoveryKitPlainV1.fromJson(
      (json['kit'] as Map).cast<String, Object?>(),
    );
    if (kit.profileId != first.ownerProfileId) {
      throw const SocialRecoveryException('owner_mismatch');
    }
    return SocialRecoveryResult(
      kit: kit,
      safeBackupAutoPassword: json['safe_backup_auto_password'] as String?,
    );
  }

  /// Четыре слова из запроса — их хранитель сверяет с человеком голосом.
  /// Слова берутся из хэша кода, поэтому подделать код незаметно нельзя.
  static Future<List<String>> checkWords(String requestCode) async {
    final digest = await Sha256().hash(utf8.encode('secretly-guardian-words|$requestCode'));
    final b = digest.bytes;
    return List<String>.generate(4, (i) {
      final idx = ((b[i * 2] << 8) | b[i * 2 + 1]) % _words.length;
      return _words[idx];
    });
  }

  // 256 коротких различимых слов (латиница — одинаково читаются на всех
  // языках интерфейса).
  static const List<String> _words = <String>[
    'acorn', 'amber', 'anchor', 'apple', 'arrow', 'aspen', 'atlas', 'badge',
    'bamboo', 'banjo', 'basil', 'beacon', 'berry', 'birch', 'bison', 'blaze',
    'bloom', 'bolt', 'bonsai', 'bramble', 'brick', 'bridge', 'brook', 'cabin',
    'cactus', 'camel', 'candle', 'canoe', 'canyon', 'cargo', 'cedar', 'chalk',
    'cherry', 'chess', 'cider', 'cinder', 'clover', 'cobalt', 'comet', 'coral',
    'cotton', 'crane', 'crater', 'creek', 'cricket', 'crown', 'cypress', 'daisy',
    'delta', 'denim', 'desert', 'dolphin', 'dove', 'dune', 'eagle', 'ember',
    'falcon', 'fern', 'fiddle', 'fjord', 'flame', 'flint', 'forest', 'fossil',
    'fox', 'frost', 'galaxy', 'garnet', 'gecko', 'geyser', 'ginger', 'glacier',
    'globe', 'granite', 'grape', 'gravel', 'harbor', 'hazel', 'heron', 'hickory',
    'honey', 'horizon', 'husky', 'iceberg', 'indigo', 'island', 'ivory', 'jade',
    'jaguar', 'jasmine', 'jelly', 'jungle', 'juniper', 'kayak', 'kelp', 'kettle',
    'kiwi', 'koala', 'lagoon', 'lantern', 'lark', 'lava', 'lemon', 'lilac',
    'lily', 'linen', 'lizard', 'llama', 'lotus', 'lumber', 'lunar', 'magnet',
    'mango', 'maple', 'marble', 'meadow', 'melon', 'mesa', 'meteor', 'mint',
    'mirror', 'mist', 'moose', 'mosaic', 'moss', 'nectar', 'nickel', 'nimbus',
    'nutmeg', 'oasis', 'ocean', 'olive', 'onyx', 'opal', 'orbit', 'orchid',
    'osprey', 'otter', 'oyster', 'paddle', 'panda', 'papaya', 'parrot', 'peach',
    'pebble', 'pelican', 'pepper', 'piano', 'pine', 'pixel', 'planet', 'plum',
    'polar', 'pony', 'poppy', 'prairie', 'prism', 'puffin', 'quartz', 'quill',
    'rabbit', 'radar', 'raven', 'reef', 'ribbon', 'ridge', 'river', 'robin',
    'rocket', 'rose', 'ruby', 'saddle', 'saffron', 'salmon', 'sapphire', 'satin',
    'sequoia', 'shadow', 'shell', 'sierra', 'silver', 'sky', 'slate', 'sparrow',
    'spruce', 'squid', 'stone', 'storm', 'summit', 'sunset', 'swan', 'tango',
    'thistle', 'thunder', 'tiger', 'timber', 'topaz', 'tulip', 'tundra', 'turtle',
    'umber', 'valley', 'velvet', 'violet', 'walnut', 'walrus', 'wave', 'willow',
    'wolf', 'yarrow', 'zebra', 'zephyr', 'zinc', 'acacia', 'alpine', 'azure',
    'bayou', 'bluff', 'caramel', 'cascade', 'citrus', 'cliff', 'copper', 'crimson',
    'dawn', 'drift', 'echo', 'elm', 'fable', 'fig', 'garden', 'gust',
    'harvest', 'hollow', 'inlet', 'iris', 'kernel', 'lime', 'marsh', 'nova',
    'oak', 'pearl', 'pond', 'quest', 'rain', 'sage', 'tide', 'vista',
    'beach', 'cloud', 'field', 'grove', 'lake', 'peak', 'reed', 'wind',
  ];
}

class SocialRecoverySetup {
  const SocialRecoverySetup({
    required this.ownerProfileId,
    required this.version,
    required this.threshold,
    required this.blobB64,
    required this.sharesB64,
  });

  final String ownerProfileId;
  final int version;
  final int threshold;
  final String blobB64;
  final List<String> sharesB64;

  int get guardians => sharesB64.length;
}

class SocialRecoveryResult {
  const SocialRecoveryResult({required this.kit, this.safeBackupAutoPassword});
  final RecoveryKitPlainV1 kit;
  final String? safeBackupAutoPassword;
}

class SocialRecoveryException implements Exception {
  const SocialRecoveryException(this.code);
  final String code;
  @override
  String toString() => 'SocialRecoveryException($code)';
}

/// Доля у хранителя — то, что он получил от владельца и хранит.
class GuardianShare {
  const GuardianShare({
    required this.ownerProfileId,
    required this.ownerName,
    required this.version,
    required this.threshold,
    required this.guardians,
    required this.shareB64,
    required this.blobB64,
    required this.receivedAtMs,
  });

  final String ownerProfileId;
  final String ownerName;
  final int version;
  final int threshold;
  final int guardians;
  final String shareB64;
  final String blobB64;
  final int receivedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'v': SocialRecovery.formatVersion,
    'owner_profile_id': ownerProfileId,
    'owner_name': ownerName,
    'version': version,
    't': threshold,
    'n': guardians,
    'share_b64': shareB64,
    'blob_b64': blobB64,
    'received_at_ms': receivedAtMs,
  };

  static GuardianShare? tryParse(Map<String, Object?> json) {
    final owner = (json['owner_profile_id'] as String?)?.trim() ?? '';
    final share = (json['share_b64'] as String?)?.trim() ?? '';
    final blob = (json['blob_b64'] as String?)?.trim() ?? '';
    final version = (json['version'] as num?)?.toInt() ?? 0;
    final t = (json['t'] as num?)?.toInt() ?? 0;
    final n = (json['n'] as num?)?.toInt() ?? 0;
    if (owner.isEmpty || share.isEmpty || blob.isEmpty || version <= 0) {
      return null;
    }
    if (t < ShamirGf256.minThreshold || n < t || n > SocialRecovery.maxGuardians) {
      return null;
    }
    if (share.length > 200 || blob.length > 64 * 1024) return null;
    return GuardianShare(
      ownerProfileId: owner,
      ownerName: ((json['owner_name'] as String?) ?? '').trim(),
      version: version,
      threshold: t,
      guardians: n,
      shareB64: share,
      blobB64: blob,
      receivedAtMs: (json['received_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Доля, которую хранитель отдаёт восстанавливающемуся устройству.
class GuardianRelease {
  const GuardianRelease({
    required this.requestNonce,
    required this.ownerProfileId,
    required this.version,
    required this.threshold,
    required this.shareB64,
    required this.blobB64,
  });

  final String requestNonce;
  final String ownerProfileId;
  final int version;
  final int threshold;
  final String shareB64;
  final String blobB64;

  Map<String, Object?> toJson() => <String, Object?>{
    'v': SocialRecovery.formatVersion,
    'nonce': requestNonce,
    'owner_profile_id': ownerProfileId,
    'version': version,
    't': threshold,
    'share_b64': shareB64,
    'blob_b64': blobB64,
  };

  static GuardianRelease? tryParse(Map<String, Object?> json) {
    final share = GuardianShare.tryParse(<String, Object?>{
      ...json,
      'n': SocialRecovery.maxGuardians,
    });
    final nonce = (json['nonce'] as String?)?.trim() ?? '';
    if (share == null || nonce.isEmpty || nonce.length > 64) return null;
    return GuardianRelease(
      requestNonce: nonce,
      ownerProfileId: share.ownerProfileId,
      version: share.version,
      threshold: share.threshold,
      shareB64: share.shareB64,
      blobB64: share.blobB64,
    );
  }
}

/// Код восстановления, который показывает новое устройство: куда слать доли
/// и одноразовая метка запроса.
class RecoveryRequestCode {
  const RecoveryRequestCode({required this.profileId, required this.nonce});

  static const String scheme = 'secretly';
  static const String host = 'recover';

  final String profileId;
  final String nonce;

  /// `secretly://recover#<profileId>.<nonce>`
  String encode() => '$scheme://$host#$profileId.$nonce';

  static RecoveryRequestCode generate(String profileId, {Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(12, (_) => rng.nextInt(256));
    return RecoveryRequestCode(
      profileId: profileId,
      nonce: base64Url.encode(bytes).replaceAll('=', ''),
    );
  }

  static RecoveryRequestCode? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host != host) return null;
    final frag = uri.fragment.trim();
    final dot = frag.lastIndexOf('.');
    if (dot <= 0 || dot == frag.length - 1) return null;
    final pid = frag.substring(0, dot);
    final nonce = frag.substring(dot + 1);
    if (pid.length > 128 || !RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(nonce)) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(pid)) return null;
    return RecoveryRequestCode(profileId: pid, nonce: nonce);
  }
}

/// Хранитель в настройке владельца.
class SocialRecoveryGuardianEntry {
  const SocialRecoveryGuardianEntry({
    required this.profileId,
    required this.status,
    required this.updatedAtMs,
  });

  final String profileId;

  /// `sent` — доля ушла, `accepted` — хранитель подтвердил, `failed` — не
  /// удалось отправить (нет устройств или сети).
  final String status;
  final int updatedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'profile_id': profileId,
    'status': status,
    'updated_at_ms': updatedAtMs,
  };

  static SocialRecoveryGuardianEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final pid = (raw['profile_id'] as String?)?.trim() ?? '';
    if (pid.isEmpty) return null;
    return SocialRecoveryGuardianEntry(
      profileId: pid,
      status: (raw['status'] as String?) ?? 'sent',
      updatedAtMs: (raw['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Настройка владельца: версия, порог и хранители.
class SocialRecoveryGuardiansState {
  const SocialRecoveryGuardiansState({
    required this.version,
    required this.threshold,
    required this.guardians,
    required this.updatedAtMs,
  });

  final int version;
  final int threshold;
  final List<SocialRecoveryGuardianEntry> guardians;
  final int updatedAtMs;

  int get accepted => guardians.where((g) => g.status == 'accepted').length;

  /// Восстановление возможно, когда подтвердили не меньше порога.
  bool get ready => accepted >= threshold;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    't': threshold,
    'guardians': guardians.map((g) => g.toJson()).toList(),
    'updated_at_ms': updatedAtMs,
  };

  static SocialRecoveryGuardiansState fromJson(Map<String, Object?> json) =>
      SocialRecoveryGuardiansState(
        version: (json['version'] as num?)?.toInt() ?? 0,
        threshold: (json['t'] as num?)?.toInt() ?? 2,
        guardians: ((json['guardians'] as List?) ?? const [])
            .map(SocialRecoveryGuardianEntry.tryParse)
            .whereType<SocialRecoveryGuardianEntry>()
            .toList(),
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}
