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
    final allowedColumns = kSafeBackupSnapshotColumnsByTable[table];
    if (table.isEmpty || allowedColumns == null || rows is! List) {
      throw StateError('$payloadName invalid db_snapshot');
    }
    for (final row in rows) {
      if (row is! Map) {
        throw StateError('$payloadName invalid db_snapshot');
      }
      for (final cell in row.entries) {
        final column = cell.key.toString().trim();
        if (column.isEmpty || !allowedColumns.contains(column)) {
          throw StateError('$payloadName invalid db_snapshot');
        }
        if (!isValidSafeBackupSnapshotScalar(cell.value)) {
          throw StateError('$payloadName invalid db_snapshot');
        }
      }
    }
  }
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