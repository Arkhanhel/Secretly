// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

/// Обезличенный отчёт о путях доставки (Э1, решение §4 ТЗ: включены по
/// умолчанию, с выключателем).
///
/// 🔴 Что в нём ЕСТЬ: сборка, платформа, тип сети, каким путём дошло, какие
/// пути падали за сутки, страна из системной локали. Чего в нём НЕТ и быть не
/// может: идентификаторов профиля и устройства, адресов, имён сетей, времени
/// точнее суток. Сторож в тестах проверяет набор ключей, а не намерение.
class TransportReport {
  const TransportReport({
    required this.build,
    required this.platform,
    required this.netKind,
    required this.pathUsed,
    required this.pathsFailed,
    required this.countryHint,
  });

  static const Set<String> allowedKeys = <String>{
    'build',
    'platform',
    'net_kind',
    'path_used',
    'paths_failed',
    'country_hint',
  };

  final int build;
  final String platform;
  final String netKind;
  final String pathUsed;
  final List<String> pathsFailed;
  final String countryHint;

  Map<String, Object?> toJson() => <String, Object?>{
    'build': build,
    'platform': platform,
    'net_kind': netKind,
    'path_used': pathUsed,
    'paths_failed': pathsFailed,
    'country_hint': countryHint,
  };

  /// Сутки от эпохи по UTC — чтобы слать не чаще раза в день.
  static int dayIndex(int nowMs) => nowMs ~/ 86400000;

  /// Тип сети из снимка платформы (`wifi`, `cellular`, `ethernet`, `vpn`…).
  static String netKindFrom(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.contains('wifi') || v == 'wlan') return 'wifi';
    if (v.contains('cell') || v.contains('mobile')) return 'cellular';
    if (v.contains('ether') || v.contains('wired')) return 'ethernet';
    if (v.contains('vpn')) return 'vpn';
    return 'other';
  }

  /// Страна только из локали (две буквы), никогда из сети.
  static String countryFromLocale(String? countryCode) {
    final c = (countryCode ?? '').trim().toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(c) ? c : '';
  }

  /// Пути, падавшие за последние сутки на этой сети, из памяти библиотеки.
  static List<String> failedKindsFromMemory({
    required String memoryJson,
    required String networkId,
    required List<Object?> paths,
    required int nowMs,
  }) {
    try {
      final memory = jsonDecode(memoryJson) as Map<String, dynamic>;
      final nets = memory['networks'] as Map<String, dynamic>? ?? const {};
      final net = nets[networkId] as Map<String, dynamic>?;
      if (net == null) return const <String>[];
      final failed = net['failed_at_ms'] as Map<String, dynamic>? ?? const {};
      final out = <String>{};
      failed.forEach((idx, at) {
        final i = int.tryParse(idx);
        final atMs = at is num ? at.toInt() : 0;
        if (i == null || i < 0 || i >= paths.length) return;
        if (nowMs - atMs > 86400000) return;
        final p = paths[i];
        if (p is Map && p['kind'] is String) out.add(p['kind'] as String);
      });
      return out.toList()..sort();
    } catch (_) {
      return const <String>[];
    }
  }
}
