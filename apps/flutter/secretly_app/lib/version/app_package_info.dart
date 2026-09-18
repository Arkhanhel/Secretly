// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart' show rootBundle;

class AppPackageInfo {
  const AppPackageInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  static const AppPackageInfo fallback = AppPackageInfo(
    appName: 'Secretly',
    version: '1.0.0',
    buildNumber: '1',
  );

  static const String _appNameEnv = String.fromEnvironment(
    'SECRETLY_APP_NAME',
  );
  static const String _appVersionEnv = String.fromEnvironment(
    'SECRETLY_APP_VERSION',
  );
  static const String _appBuildNumberEnv = String.fromEnvironment(
    'SECRETLY_APP_BUILD_NUMBER',
  );
  static final RegExp _namePattern = RegExp(
    r'^name:\s*([^\r\n#]+)',
    multiLine: true,
  );
  static final RegExp _versionPattern = RegExp(
    r'^version:\s*([^\r\n#]+)',
    multiLine: true,
  );

  final String appName;
  final String version;
  final String buildNumber;

  /// Номер сборки, известный БЕЗ асинхронной загрузки: он приходит из
  /// dart-define релизного скрипта. Нужен там, где ждать нельзя — например в
  /// справочном заголовке к реле, который ставится на каждый запрос.
  ///
  /// Пустая строка означает «не знаем» — заголовок тогда просто не ставится,
  /// и на сервере это честно видно как «(неизвестно)».
  static String get buildNumberFromEnv =>
      _normalizeValue(_appBuildNumberEnv) ?? '';

  static Future<AppPackageInfo> load() async {
    try {
      final rawPubspec = await rootBundle.loadString('pubspec.yaml');
      return AppPackageInfo.fromPubspec(rawPubspec)._withEnvironmentOverrides();
    } catch (_) {
      return fallback._withEnvironmentOverrides();
    }
  }

  factory AppPackageInfo.fromPubspec(String rawPubspec) {
    final rawName = _extractValue(_namePattern, rawPubspec);
    final rawVersion = _extractValue(_versionPattern, rawPubspec);
    final versionParts = rawVersion.split('+');
    final resolvedVersion = versionParts.first.trim();
    final resolvedBuildNumber = versionParts.length > 1
        ? versionParts[1].trim()
        : '';

    return AppPackageInfo(
      appName: _resolveAppName(rawName),
      version: resolvedVersion.isEmpty ? fallback.version : resolvedVersion,
      buildNumber: resolvedBuildNumber.isEmpty
          ? fallback.buildNumber
          : resolvedBuildNumber,
    );
  }

  AppPackageInfo _withEnvironmentOverrides() {
    return AppPackageInfo(
      appName: _normalizeValue(_appNameEnv) ?? appName,
      version: _normalizeValue(_appVersionEnv) ?? version,
      buildNumber: _normalizeValue(_appBuildNumberEnv) ?? buildNumber,
    );
  }

  static String _extractValue(RegExp pattern, String rawPubspec) {
    final match = pattern.firstMatch(rawPubspec);
    if (match == null) {
      return '';
    }
    return _stripWrappingQuotes(match.group(1) ?? '');
  }

  static String _resolveAppName(String rawName) {
    final normalized = _normalizeValue(rawName);
    if (normalized == null) {
      return fallback.appName;
    }
    if (normalized == 'secretly_app') {
      return fallback.appName;
    }
    return normalized
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalizeWord)
        .join(' ');
  }

  static String _capitalizeWord(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _stripWrappingQuotes(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
        return trimmed.substring(1, trimmed.length - 1).trim();
      }
    }
    return trimmed;
  }

  static String? _normalizeValue(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}