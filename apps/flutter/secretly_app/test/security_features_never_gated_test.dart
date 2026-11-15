// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Б15 (TZ_BEST_IN_MARKET_PROGRAM) / TZ_MONETIZE_01 Appendix B: security
// features are free forever and the entitlements module is never imported into
// them. A paywall on any of these would be a promise broken to every user, so
// the rule is checked by source, not left to review.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/feature_gate.dart';

/// Folders and files that implement Appendix B features.
const List<String> _securitySources = [
  'lib/crypto',
  'lib/ratchet',
  'lib/security',
  'lib/messages/disappearing_flags.dart',
  'lib/messages/privacy_flags.dart',
  'lib/ui/disappearing_messages_ui.dart',
  'lib/ui/verify_contact_screen.dart',
  'lib/ui/recovery_kit_screen.dart',
  'lib/ui/security_lock_flow.dart',
  'lib/ui/social_recovery_screen.dart',
];

final RegExp _billingImport = RegExp(
  r'''^\s*(import|export)\s+['"][^'"]*(entitlements/|billing/|paywall)''',
  multiLine: true,
);

/// Words that must never name a paid feature.
const List<String> _securityWords = [
  'disappear',
  'verif',
  'screenshot',
  'privacy',
  'pin',
  'lock',
  'recovery',
  'backup',
  'e2e',
  'encrypt',
  'block',
  'report',
];

/// AppController entry points of Appendix B features.
const List<String> _securityControllerMethods = [
  'canSetDisappearingForConvo',
  'disappearingVisibleForConvo',
  'setChatDisappearSeconds',
  'canSetDisappearingForRoom',
  'canManageRoomDisappearing',
  'disappearingVisibleForRoom',
  'setRoomDisappearSeconds',
];

final RegExp _gateReference = RegExp(
  r'FeatureGate|entitlement|GatedFeature|paywall',
  caseSensitive: false,
);

Iterable<File> _dartFiles(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.file) return [File(path)];
  expect(
    type,
    FileSystemEntityType.directory,
    reason: '$path is listed as a security source but does not exist — '
        'update the list, do not drop the check',
  );
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

/// The body of `name(` in [source], by brace matching from its first `{`.
String _methodBody(String source, String name) {
  final start = RegExp('\\b$name\\(').firstMatch(source);
  expect(start, isNotNull, reason: 'AppController.$name not found');
  final open = source.indexOf('{', start!.end);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return source.substring(open, i + 1);
  }
  fail('unbalanced braces after AppController.$name');
}

void main() {
  test('security sources never import entitlements, billing or paywall', () {
    final offenders = <String>[];
    for (final path in _securitySources) {
      for (final file in _dartFiles(path)) {
        final match = _billingImport.firstMatch(file.readAsStringSync());
        if (match != null) offenders.add('${file.path}: ${match.group(0)!.trim()}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('no gated feature is named after a security feature', () {
    for (final feature in GatedFeature.values) {
      final name = feature.name.toLowerCase();
      for (final word in _securityWords) {
        expect(name.contains(word), isFalse, reason: '$feature looks like "$word"');
      }
    }
  });

  test('disappearing-message controls never consult the paywall', () {
    final source = File('lib/app/app_controller.dart').readAsStringSync();
    for (final method in _securityControllerMethods) {
      final body = _methodBody(source, method);
      expect(
        _gateReference.hasMatch(body),
        isFalse,
        reason: 'AppController.$method references the paywall',
      );
    }
  });
}
