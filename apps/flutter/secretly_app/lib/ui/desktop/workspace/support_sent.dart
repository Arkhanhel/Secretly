// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// СВОИ ОТПРАВЛЕННЫЕ ПИСЬМА В ПОДДЕРЖКУ.
///
/// 🔴 ЗАЧЕМ. Панель показывала только ОТВЕТЫ. Отправленное исчезало: человек
/// не видел ни того, что написал, ни того, что вложил, и на «пришлите ещё
/// раз» ответить было нечем. На телефоне переписка видна целиком — здесь не
/// было и половины.
///
/// 🔴 ГДЕ ХРАНИМ. В зашифрованной базе приложения (`localValueGet/Set`), а не
/// в настройках рядом с флажками: текст обращения в поддержку — это то же
/// личное письмо, и класть его на диск открытым нельзя. Вложение не храним
/// вовсе, только имя: второй копии файла на диске никто не просил.
///
/// Храним последние [DesktopSupportSentStore.keep] писем: переписка с
/// поддержкой — не архив, а нить последних дней.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class DesktopSupportSent {
  const DesktopSupportSent({
    required this.text,
    required this.tsMs,
    this.attachmentName,
  });

  final String text;
  final int tsMs;
  final String? attachmentName;

  bool get hasAttachment => (attachmentName ?? '').isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        't': text,
        'ts': tsMs,
        if (hasAttachment) 'a': attachmentName,
      };

  static DesktopSupportSent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['t'];
    final ts = raw['ts'];
    if (text is! String || ts is! int) return null;
    final att = raw['a'];
    return DesktopSupportSent(
      text: text,
      tsMs: ts,
      attachmentName: att is String && att.trim().isNotEmpty ? att : null,
    );
  }
}

/// Читает и пишет через переданные действия, а не через контроллер напрямую:
/// так хранилище проверяется тестом без приложения целиком.
class DesktopSupportSentStore {
  const DesktopSupportSentStore({required this.read, required this.write});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  static const String storageKey = 'desktop_support_sent_v1';
  static const int keep = 50;

  Future<List<DesktopSupportSent>> load() async {
    String? raw;
    try {
      raw = await read(storageKey);
    } catch (_) {
      return const <DesktopSupportSent>[];
    }
    if (raw == null || raw.trim().isEmpty) return const <DesktopSupportSent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <DesktopSupportSent>[];
      return <DesktopSupportSent>[
        for (final item in decoded)
          if (DesktopSupportSent.fromJson(item) case final m?) m,
      ];
    } catch (_) {
      // Испорченная запись не повод показать пустую панель с ошибкой: это
      // список собственных писем, а не состояние переписки.
      return const <DesktopSupportSent>[];
    }
  }

  /// Дописывает письмо и возвращает нить целиком — той же, что показывать.
  Future<List<DesktopSupportSent>> append(DesktopSupportSent message) async {
    final all = <DesktopSupportSent>[...await load(), message];
    final kept = all.length <= keep ? all : all.sublist(all.length - keep);
    try {
      await write(
        storageKey,
        jsonEncode(kept.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Не записалось — письмо всё равно ушло; на экране оно есть.
    }
    return kept;
  }
}
