// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

void validateRestoreIdentityPayload({
  required String payloadName,
  required String profileId,
  required String profileSecretB64,
  required String deviceId,
  required String deviceKeysMaterialJson,
  required String serverBinding,
}) {
  _validateRequiredString(
    payloadName: payloadName,
    fieldName: 'profile_id',
    value: profileId,
  );
  SecureSecrets.validateProfileSecretB64(profileSecretB64);
  _validateRequiredString(
    payloadName: payloadName,
    fieldName: 'device_id',
    value: deviceId,
  );
  DeviceKeys.validateMaterialJson(deviceKeysMaterialJson);
  _validateServerBinding(
    payloadName: payloadName,
    serverBinding: serverBinding,
  );
}

void validateServerBindingValue({
  required String payloadName,
  required String serverBinding,
}) {
  _validateServerBinding(
    payloadName: payloadName,
    serverBinding: serverBinding,
  );
}

/// Проверка снимка базы из копии.
///
/// 🔴 13.11.2026: незнакомая таблица или столбец больше НЕ отвергают копию
/// целиком. Это копия более новой версии приложения (новый столбец, новая
/// таблица), и раньше такая копия не восстанавливалась на более старой сборке
/// вовсе — человек терял историю из-за одного лишнего поля. Теперь незнакомое
/// пропускается здесь и отбрасывается перед импортом
/// ([sanitizeSafeBackupDbSnapshot]): в базу по-прежнему попадают только
/// известные столбцы известных таблиц. Строгими остаются форма снимка и
/// значения известных столбцов.
void validateSafeBackupDbSnapshot({
  required String payloadName,
  required Map<String, Object?>? dbSnapshot,
}) {
  if (dbSnapshot == null) {
    return;
  }
  for (final entry in dbSnapshot.entries) {
    final table = entry.key.trim();
    final rows = entry.value;
    if (table.isEmpty || rows is! List) {
      throw StateError('$payloadName invalid db_snapshot');
    }
    final allowedColumns = kSafeBackupSnapshotColumnsByTable[table];
    for (final row in rows) {
      if (row is! Map) {
        throw StateError('$payloadName invalid db_snapshot');
      }
      if (allowedColumns == null) continue; // таблица новой версии
      for (final cell in row.entries) {
        final column = cell.key.toString().trim();
        if (!allowedColumns.contains(column)) continue; // столбец новой версии
        if (!isValidSafeBackupSnapshotScalar(cell.value)) {
          throw StateError('$payloadName invalid db_snapshot');
        }
      }
    }
  }
}

/// Только известное этой сборке: незнакомые таблицы и столбцы (копия более
/// новой версии) отбрасываются. Вызывать после [validateSafeBackupDbSnapshot]
/// и перед импортом в базу.
Map<String, List<Map<String, Object?>>> sanitizeSafeBackupDbSnapshot(
  Map<String, List<Map<String, Object?>>> snapshot,
) {
  final out = <String, List<Map<String, Object?>>>{};
  snapshot.forEach((rawTable, rows) {
    final table = rawTable.trim();
    final allowed = kSafeBackupSnapshotColumnsByTable[table];
    if (allowed == null) return;
    out[table] = [
      for (final row in rows)
        <String, Object?>{
          for (final cell in row.entries)
            if (allowed.contains(cell.key.trim())) cell.key.trim(): cell.value,
        },
    ];
  });
  return out;
}

void validateSafeBackupFiles({
  required String payloadName,
  required Map<String, String>? filesB64ByRelativePath,
}) {
  if (filesB64ByRelativePath == null) {
    return;
  }

  final normalizedPaths = <String>{};
  for (final entry in filesB64ByRelativePath.entries) {
    final normalizedPath = normalizeSafeBackupRelativePath(entry.key);
    if (normalizedPath == null) {
      throw StateError('$payloadName invalid files_b64 path');
    }
    if (!normalizedPaths.add(normalizedPath)) {
      throw StateError('$payloadName duplicate files_b64 path');
    }
    _validateBase64Field(
      payloadName: payloadName,
      fieldName: 'files_b64[$normalizedPath]',
      value: entry.value,
    );
  }
}

String? normalizeSafeBackupRelativePath(String rawPath) {
  final candidate = rawPath.trim().replaceAll('\\', '/');
  if (candidate.isEmpty) {
    return null;
  }

  final normalized = p.posix.normalize(candidate);
  if (normalized.isEmpty ||
      normalized == '.' ||
      normalized == '..' ||
      normalized.contains(':') ||
      normalized.startsWith('../') ||
      p.posix.isAbsolute(normalized)) {
    return null;
  }

  return normalized;
}

void _validateRequiredString({
  required String payloadName,
  required String fieldName,
  required String value,
}) {
  if (value.trim().isEmpty) {
    throw StateError('$payloadName missing $fieldName');
  }
}

void _validateServerBinding({
  required String payloadName,
  required String serverBinding,
}) {
  final raw = serverBinding.trim();
  if (raw.isEmpty) {
    throw StateError('$payloadName missing server_binding');
  }

  String? keysRaw;
  String? relayRaw;
  for (final part in raw.split(';')) {
    final normalizedPart = part.trim();
    if (normalizedPart.startsWith('keys=')) {
      keysRaw = normalizedPart.substring('keys='.length).trim();
    } else if (normalizedPart.startsWith('relay=')) {
      relayRaw = normalizedPart.substring('relay='.length).trim();
    }
  }

  if (!_isValidHttpBaseUrl(keysRaw) || !_isValidHttpBaseUrl(relayRaw)) {
    throw StateError('$payloadName invalid server_binding');
  }
}

bool _isValidHttpBaseUrl(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return false;
  }

  return uri.scheme == 'http' || uri.scheme == 'https';
}

void _validateBase64Field({
  required String payloadName,
  required String fieldName,
  required String value,
}) {
  try {
    base64Decode(value.trim());
  } on FormatException {
    throw StateError('$payloadName invalid $fieldName');
  }
}