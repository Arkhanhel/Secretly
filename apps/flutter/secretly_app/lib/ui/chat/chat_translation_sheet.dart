// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Окно «Перевод в этом чате» (22.11.2026, Т-4): режим, «с языка»,
// «на язык», сброс к общим настройкам. Каждое изменение сохраняется сразу
// (только на телефоне), окно возвращает итоговую настройку.

import 'package:flutter/material.dart';

import '../../translation/chat_translation_policy.dart';
import '../../translation/translation_languages.dart';
import '../icons/app_icons.dart';
import '../l10n.dart';
import '../motion/app_dialogs.dart' show appSheetAnimationStyle;

/// Показывает окно и возвращает настройку чата после закрытия.
Future<ChatTranslationSettings> showChatTranslationSheet({
  required BuildContext context,
  required String convoId,
  required ChatTranslationSettings initial,
  required GlobalTranslationSettings global,
  required String appLanguage,
}) async {
  var latest = initial;
  await showModalBottomSheet<void>(
    sheetAnimationStyle: appSheetAnimationStyle,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => ChatTranslationSheet(
      initial: initial,
      global: global,
      appLanguage: appLanguage,
      onChanged: (next) async {
        latest = next;
        try {
          await saveChatTranslationSettings(convoId, next);
        } catch (_) {
          // Не сохранилось — чат живёт по прежней настройке.
        }
      },
    ),
  );
  return latest;
}

class ChatTranslationSheet extends StatefulWidget {
  const ChatTranslationSheet({
    super.key,
    required this.initial,
    required this.global,
    required this.appLanguage,
    required this.onChanged,
  });

  final ChatTranslationSettings initial;
  final GlobalTranslationSettings global;
  final String appLanguage;
  final ValueChanged<ChatTranslationSettings> onChanged;

  @override
  State<ChatTranslationSheet> createState() => _ChatTranslationSheetState();
}

class _ChatTranslationSheetState extends State<ChatTranslationSheet> {
  late ChatTranslationSettings _s = widget.initial;

  void _set(ChatTranslationSettings next) {
    if (next == _s) return;
    setState(() => _s = next);
    widget.onChanged(next);
  }

  String _modeLabel(ChatTranslationMode m) {
    final l = context.l10n;
    return switch (m) {
      ChatTranslationMode.inherit => l.chatTranslateModeInherit,
      ChatTranslationMode.off => l.chatTranslateModeOff,
      ChatTranslationMode.button => l.chatTranslateModeButton,
      ChatTranslationMode.auto => l.chatTranslateModeAuto,
    };
  }

  String _sourceLabel(String? v) {
    final l = context.l10n;
    if (v == null) {
      return '${l.chatTranslateModeInherit} · ${_sourceLabel(widget.global.source.trim().isEmpty ? 'auto' : widget.global.source)}';
    }
    if (v == 'auto') return l.chatTranslateAutoDetect;
    return translationLanguageLabel(v);
  }

  String _targetLabel(String? v) {
    final l = context.l10n;
    if (v == null) {
      return '${l.chatTranslateModeInherit} · ${_targetLabel(widget.global.target)}';
    }
    if (v.isEmpty) return l.chatTranslateAppLanguage;
    return translationLanguageLabel(v);
  }

  Future<String?> _pickLanguage({required bool isSource}) async {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final current = isSource ? _s.source : _s.target;
    // Особые значения: «как в настройках» (null) и «авто» / «язык приложения».
    const inheritToken = '\u0000inherit';
    final special = isSource ? 'auto' : '';
    final picked = await showModalBottomSheet<String>(
      sheetAnimationStyle: appSheetAnimationStyle,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        Widget tile(String value, String leading, String title, bool sel) =>
            ListTile(
              leading: Text(leading, style: const TextStyle(fontSize: 22)),
              title: Text(title),
              trailing: sel
                  ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                  : null,
              onTap: () => Navigator.of(ctx).pop(value),
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                tile(
                  inheritToken,
                  '⚙️',
                  l.chatTranslateModeInherit,
                  current == null,
                ),
                tile(
                  special,
                  isSource ? '🌐' : '📱',
                  isSource ? l.chatTranslateAutoDetect : l.chatTranslateAppLanguage,
                  current == special,
                ),
                const Divider(height: 1),
                for (final lang in kPopularTranslationLanguages)
                  tile(lang.code, lang.flag, lang.name, current == lang.code),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    l.chatTranslateAllLanguages,
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final lang in kOtherTranslationLanguages)
                  tile(lang.code, lang.flag, lang.name, current == lang.code),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return null;
    return picked == inheritToken ? inheritToken : picked;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effective = resolveTranslationPolicy(
      global: widget.global,
      chat: _s,
      appLanguage: widget.appLanguage,
    );
    final samePair =
        effective.source != null && effective.source == effective.target;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l.chatTranslateSheetTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  l.chatTranslateModeLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              for (final m in ChatTranslationMode.values)
                ListTile(
                  key: ValueKey<String>('chat_translate_mode_${m.name}'),
                  title: Text(_modeLabel(m)),
                  trailing: _s.mode == m
                      ? Icon(AppIcons.checkCircleSolid, color: cs.primary)
                      : null,
                  onTap: () => _set(_s.copyWith(mode: m)),
                ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey<String>('chat_translate_from'),
                title: Text(l.chatTranslateFrom),
                subtitle: Text(_sourceLabel(_s.source)),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () async {
                  final v = await _pickLanguage(isSource: true);
                  if (v == null || !mounted) return;
                  _set(
                    _s.copyWith(
                      source: () => v == '\u0000inherit' ? null : v,
                    ),
                  );
                },
              ),
              ListTile(
                key: const ValueKey<String>('chat_translate_to'),
                title: Text(l.chatTranslateTo),
                subtitle: Text(_targetLabel(_s.target)),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () async {
                  final v = await _pickLanguage(isSource: false);
                  if (v == null || !mounted) return;
                  _set(
                    _s.copyWith(
                      target: () => v == '\u0000inherit' ? null : v,
                    ),
                  );
                },
              ),
              if (samePair)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    l.chatTranslateSameLanguagePair,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
                ),
              if (!_s.isDefault)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: TextButton(
                    key: const ValueKey<String>('chat_translate_reset'),
                    onPressed: () => _set(ChatTranslationSettings.inherit),
                    child: Text(l.chatTranslateReset),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  l.chatTranslatePrivacyNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
