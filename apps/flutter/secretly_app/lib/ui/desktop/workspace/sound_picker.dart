// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ВЫБОР ЗВУКА В НАСТРОЙКАХ ПК (01.10.2026): список звуков, у каждого —
/// «Послушать», у выбранного — галочка, у платного без подписки — замок.
///
/// Послушать можно любой звук, в том числе платный: услышать до покупки —
/// честно. Выбрать платный без подписки нельзя: ПК говорит об этом своей
/// плашкой (подписка оформляется на телефоне), телефонную витрину не
/// открывает — на ПК ею не воспользоваться.
///
/// Звонок начался — «Послушать» смолкает и до конца звонка недоступно:
/// звук поверх разговора — шум у собеседника в ухе.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../entitlements/entitlement_models.dart' show EntitlementState;
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_call_activity.dart';
import '../services/desktop_sounds.dart';
import 'settings_kit.dart';
import 'settings_style.dart';
import 'workspace_layout.dart';

/// Список звуков вида [kind].
class DesktopSoundList extends StatefulWidget {
  const DesktopSoundList({
    super.key,
    required this.kind,
    this.entitlement,
    this.callActive,
    this.previewEnabled = true,
  });

  final DesktopSoundKind kind;

  /// Подписка сейчас; `null` или ответ `null` — не известна, и тогда можно всё.
  final EntitlementState? Function()? entitlement;

  /// Идёт ли звонок; `null` — следить за настоящими.
  final ValueListenable<bool>? callActive;

  /// Можно ли слушать (у мелодии звонка на нулевой громкости слушать нечего).
  final bool previewEnabled;

  @override
  State<DesktopSoundList> createState() => _DesktopSoundListState();
}

class _DesktopSoundListState extends State<DesktopSoundList> {
  final DesktopSoundPreview _preview = DesktopSoundPreview.instance;
  DesktopCallActivity? _ownActivity;
  late final ValueListenable<bool> _callActive =
      widget.callActive ?? (_ownActivity = DesktopCallActivity());
  String? _selected;

  @override
  void initState() {
    super.initState();
    _preview.playing.addListener(_onPreview);
    _callActive.addListener(_onCallActivity);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = DesktopSounds.readId(prefs, widget.kind);
      if (mounted) setState(() => _selected = id);
    } catch (_) {
      if (mounted) {
        setState(() => _selected = DesktopSounds.defaultIdOf(widget.kind));
      }
    }
  }

  void _onPreview() {
    if (mounted) setState(() {});
  }

  void _onCallActivity() {
    if (_callActive.value) unawaited(_preview.stop());
    if (mounted) setState(() {});
  }

  bool _allowed(String id) =>
      DesktopSounds.isAllowed(widget.kind, widget.entitlement?.call(), id);

  Future<void> _select(String id) async {
    if (!_allowed(id)) {
      // 🔴 ПЛАТНОЕ БЕЗ ПОДПИСКИ — СКАЗАТЬ СРАЗУ, А НЕ ПРИНЯТЬ МОЛЧА: выбор,
      // который «сохранился», но не звучит, — худшее, что может сделать
      // настройка. Та же плашка, что у платного оформления.
      DesktopSnackbar.show(
        context,
        message: AppLocalizations.of(context)!.desktopAppearancePremiumOnly,
      );
      return;
    }
    if (id == _selected) return;
    setState(() => _selected = id);
    await DesktopSounds.save(widget.kind, id);
  }

  @override
  void dispose() {
    _preview.playing.removeListener(_onPreview);
    _callActive.removeListener(_onCallActivity);
    _ownActivity?.dispose();
    // Ушли со страницы — её звук смолкает.
    if (_preview.isPlayingKind(widget.kind)) unawaited(_preview.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canListen = widget.previewEnabled && !_callActive.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in DesktopSounds.idsOf(widget.kind))
          _SoundRow(
            key: ValueKey<String>('desktop-sound-${widget.kind.name}-$id'),
            kind: widget.kind,
            id: id,
            name: DesktopSounds.nameOf(l10n, id),
            selected: id == _selected,
            locked: !_allowed(id),
            playing: _preview.isPlaying(widget.kind, id),
            onSelect: () => unawaited(_select(id)),
            onPreview: canListen || _preview.isPlaying(widget.kind, id)
                ? () => unawaited(_preview.toggle(widget.kind, id))
                : null,
          ),
      ],
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    super.key,
    required this.kind,
    required this.id,
    required this.name,
    required this.selected,
    required this.locked,
    required this.playing,
    required this.onSelect,
    required this.onPreview,
  });

  final DesktopSoundKind kind;
  final String id;
  final String name;
  final bool selected;
  final bool locked;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final app = SettingsScope.appColorsOf(context);
    // Строка — одна ячейка дерева доступности с названием звука: щелчок по
    // строке и есть выбор, и без подписи экранный диктор назвал бы её пустой
    // кнопкой.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: name,
      child: HoverListener(
        onTap: onSelect,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, _) => AnimatedContainer(
          duration: DMotion.fast,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          color: hovered ? p.hover : Colors.transparent,
          child: Row(
            children: [
              // Своя ячейка дерева доступности: иначе кнопка слилась бы с
              // названием строки, и «Послушать» пропало бы для экранного диктора.
              Semantics(
                container: true,
                child: SettingsSoftButton(
                  key: ValueKey<String>('desktop-sound-play-${kind.name}-$id'),
                  label: playing
                      ? l10n.desktopMediaCheckStop
                      : l10n.desktopRingtoneListen,
                  icon: playing
                      ? FluentIcons.stop_24_regular
                      : FluentIcons.play_24_regular,
                  iconOnly: true,
                  small: true,
                  onTap: onPreview,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: DType.family,
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: p.head,
                          ),
                        ),
                      ),
                      // Как у платного оформления: галочка у выбранного, замок —
                      // у недоступного.
                      if (selected)
                        Icon(
                          FluentIcons.checkmark_circle_16_filled,
                          size: 17,
                          color: app.accentPrimary,
                        )
                      else if (locked)
                        Icon(
                          FluentIcons.lock_closed_12_filled,
                          size: 13,
                          color: p.faint,
                        ),
                    ],
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

/// Строка-пояснение под заголовком карточки, когда «Звук» уведомлений
/// выключен: выбор есть, а звучать ему не дадут.
String? _mutedNote(AppLocalizations l10n, bool soundOn) =>
    soundOn ? null : l10n.desktopSoundMutedNote;

/// Карточка «Звук сообщений».
class DesktopMessageSoundCard extends StatelessWidget {
  const DesktopMessageSoundCard({
    super.key,
    required this.soundOn,
    this.entitlement,
    this.callActive,
  });

  /// Включён ли «Звук» уведомлений.
  final bool soundOn;
  final EntitlementState? Function()? entitlement;
  final ValueListenable<bool>? callActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceCard(
      title: l10n.desktopSoundMessagesTitle,
      description: _mutedNote(l10n, soundOn) ?? l10n.desktopSoundMessagesHint,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DesktopSoundList(
        kind: DesktopSoundKind.message,
        entitlement: entitlement,
        callActive: callActive,
      ),
    );
  }
}

/// Карточка «Звук в открытом чате»: включатель и список.
class DesktopInChatSoundCard extends StatefulWidget {
  const DesktopInChatSoundCard({
    super.key,
    required this.soundOn,
    this.callActive,
  });

  final bool soundOn;
  final ValueListenable<bool>? callActive;

  @override
  State<DesktopInChatSoundCard> createState() => _DesktopInChatSoundCardState();
}

class _DesktopInChatSoundCardState extends State<DesktopInChatSoundCard> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = DesktopSounds.readInChatEnabled(prefs);
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {}
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    if (!value &&
        DesktopSoundPreview.instance.isPlayingKind(DesktopSoundKind.inChat)) {
      unawaited(DesktopSoundPreview.instance.stop());
    }
    await DesktopSounds.setInChatEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceCard(
      title: l10n.desktopSoundInChatTitle,
      description: _mutedNote(l10n, widget.soundOn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceRow(
            label: l10n.desktopSoundInChatSwitch,
            description: l10n.desktopSoundInChatHint,
            trailing: WorkspaceSwitch(
              value: _enabled,
              onChanged: (v) => unawaited(_setEnabled(v)),
            ),
          ),
          // Выключено — список не нужен: выбирать звук, которому не звучать,
          // незачем (как у телефона, где выбор тогда недоступен).
          if (_enabled)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: DesktopSoundList(
                kind: DesktopSoundKind.inChat,
                callActive: widget.callActive,
              ),
            ),
        ],
      ),
    );
  }
}
