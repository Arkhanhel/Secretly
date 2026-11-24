// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Переводчик в отдельном чате (22.11.2026, Т-4): «как в настройках» /
// выключен / кнопка / автоперевод, свои «с языка» и «на язык».
//
// Хранится ТОЛЬКО на телефоне: `chat_translation_v1_<чат>` в настройках
// телефона, никому не рассылается. Нет записи или запись испорчена — чат
// живёт по общим настройкам, как до этой правки. Выключатель —
// [kChatTranslationOverride]: false — настройка чата не читается и не
// показывается.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../build_variant.dart';

/// Выключатель настройки перевода в чате.
const bool kChatTranslationOverride = true;

const String kChatTranslationPrefsPrefix = 'chat_translation_v1_';

enum ChatTranslationMode { inherit, off, button, auto }

class ChatTranslationSettings {
  const ChatTranslationSettings({
    this.mode = ChatTranslationMode.inherit,
    this.source,
    this.target,
  });

  final ChatTranslationMode mode;

  /// null — как в настройках; 'auto' — определять; иначе код языка.
  final String? source;

  /// null — как в настройках; '' — язык приложения; иначе код языка.
  final String? target;

  static const ChatTranslationSettings inherit = ChatTranslationSettings();

  bool get isDefault =>
      mode == ChatTranslationMode.inherit && source == null && target == null;

  ChatTranslationSettings copyWith({
    ChatTranslationMode? mode,
    String? Function()? source,
    String? Function()? target,
  }) => ChatTranslationSettings(
    mode: mode ?? this.mode,
    source: source == null ? this.source : source(),
    target: target == null ? this.target : target(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    if (source != null) 'source': source,
    if (target != null) 'target': target,
  };

  /// Разбирает сохранённое; мусор — «как в настройках».
  static ChatTranslationSettings fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return inherit;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return inherit;
      final modeName = decoded['mode'];
      var mode = ChatTranslationMode.inherit;
      for (final m in ChatTranslationMode.values) {
        if (m.name == modeName) mode = m;
      }
      String? lang(Object? v, {required bool allowEmpty, String? special}) {
        if (v is! String) return null;
        final t = v.trim().toLowerCase();
        if (t.isEmpty) return allowEmpty ? '' : null;
        if (special != null && t == special) return t;
        return RegExp(r'^[a-z]{2,3}$').hasMatch(t) ? t : null;
      }

      return ChatTranslationSettings(
        mode: mode,
        source: lang(decoded['source'], allowEmpty: false, special: 'auto'),
        target: lang(decoded['target'], allowEmpty: true),
      );
    } catch (_) {
      return inherit;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChatTranslationSettings &&
      other.mode == mode &&
      other.source == source &&
      other.target == target;

  @override
  int get hashCode => Object.hash(mode, source, target);
}

/// Общие настройки перевода (Настройки → Язык).
class GlobalTranslationSettings {
  const GlobalTranslationSettings({
    this.buttonEnabled = false,
    this.autoEnabled = false,
    this.source = 'auto',
    this.target = '',
  });

  final bool buttonEnabled;

  /// Сохранённый переключатель «переводить чаты целиком». Действует только
  /// при включённой кнопке (Т-2): в настройках он неактивен без неё, но
  /// прежнее значение в памяти телефона оставалось и включало автоперевод.
  final bool autoEnabled;
  final String source;
  final String target;
}

/// Что действует в чате на самом деле.
class EffectiveTranslationPolicy {
  const EffectiveTranslationPolicy({
    required this.showButton,
    required this.auto,
    required this.source,
    required this.target,
  });

  static const EffectiveTranslationPolicy disabled = EffectiveTranslationPolicy(
    showButton: false,
    auto: false,
    source: null,
    target: '',
  );

  final bool showButton;
  final bool auto;

  /// null — определять язык каждого сообщения.
  final String? source;

  /// Код языка перевода (уже с подставленным языком приложения).
  final String target;

  @override
  bool operator ==(Object other) =>
      other is EffectiveTranslationPolicy &&
      other.showButton == showButton &&
      other.auto == auto &&
      other.source == source &&
      other.target == target;

  @override
  int get hashCode => Object.hash(showButton, auto, source, target);

  @override
  String toString() =>
      'EffectiveTranslationPolicy(button: $showButton, auto: $auto, '
      'source: $source, target: $target)';
}

/// Сводит общие настройки и настройку чата. [available] — есть ли
/// переводчик в сборке (облегчённая — нет), [overrideEnabled] —
/// выключатель настройки чата.
EffectiveTranslationPolicy resolveTranslationPolicy({
  required GlobalTranslationSettings global,
  ChatTranslationSettings chat = ChatTranslationSettings.inherit,
  required String appLanguage,
  bool available = kTranslationAvailable,
  bool overrideEnabled = kChatTranslationOverride,
}) {
  if (!available) return EffectiveTranslationPolicy.disabled;
  final c = overrideEnabled ? chat : ChatTranslationSettings.inherit;
  final bool showButton;
  final bool auto;
  switch (c.mode) {
    case ChatTranslationMode.inherit:
      showButton = global.buttonEnabled;
      auto = global.buttonEnabled && global.autoEnabled;
    case ChatTranslationMode.off:
      showButton = false;
      auto = false;
    case ChatTranslationMode.button:
      showButton = true;
      auto = false;
    case ChatTranslationMode.auto:
      showButton = true;
      auto = true;
  }
  final rawSource = (c.source ?? global.source).trim().toLowerCase();
  final source = (rawSource.isEmpty || rawSource == 'auto') ? null : rawSource;
  final rawTarget = (c.target ?? global.target).trim().toLowerCase();
  final app = appLanguage.trim().toLowerCase().split(RegExp('[-_]')).first;
  final target = rawTarget.isEmpty ? app : rawTarget;
  return EffectiveTranslationPolicy(
    showButton: showButton,
    auto: auto,
    source: source,
    target: target,
  );
}

String chatTranslationPrefsKey(String convoId) =>
    '$kChatTranslationPrefsPrefix${convoId.trim()}';

Future<ChatTranslationSettings> loadChatTranslationSettings(
  String convoId,
) async {
  if (!kChatTranslationOverride || convoId.trim().isEmpty) {
    return ChatTranslationSettings.inherit;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    return ChatTranslationSettings.fromJsonString(
      prefs.getString(chatTranslationPrefsKey(convoId)),
    );
  } catch (_) {
    return ChatTranslationSettings.inherit;
  }
}

/// Сохраняет настройку чата; «как в настройках» — запись стирается.
Future<void> saveChatTranslationSettings(
  String convoId,
  ChatTranslationSettings settings,
) async {
  if (convoId.trim().isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = chatTranslationPrefsKey(convoId);
  if (settings.isDefault) {
    await prefs.remove(key);
  } else {
    await prefs.setString(key, jsonEncode(settings.toJson()));
  }
}
