// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../calls/call_state.dart';
import '../../../rooms/room_call_manager.dart';
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';
import 'call_peer_label.dart';

/// Полоса идущего созвона — НАД ВСЕМ ОКНОМ, из любого раздела.
///
/// 🔴 СОЗВОН ТЕРЯЛСЯ, СТОИЛО УЙТИ ИЗ КОМНАТЫ (14.09.2026).
///
/// Плашка «Идёт обсуждение» жила ВНУТРИ ленты своей комнаты. Свернул окно
/// созвона, открыл другой чат, зашёл в настройки — и о том, что разговор
/// идёт, не напоминало ничто: ни полосы, ни кнопки возврата. Вернуться можно
/// было, только вспомнив, в какой комнате созвон, и дойдя до неё.
///
/// Это не украшение: человек, который во время разговора пишет коллеге, не
/// должен держать в голове дорогу назад.
///
/// Плашка внутри комнаты при этом ОСТАЁТСЯ и не дублирует эту: там она зовёт
/// ПРИСОЕДИНИТЬСЯ к чужому созвону, здесь — ВЕРНУТЬСЯ в свой. Полоса
/// показывается только когда я сам в созвоне.
///
/// Времени разговора здесь НЕТ намеренно: оно уже идёт в мини-окне и в
/// шапке звонка, а у полосы другая работа — вернуть человека туда, где оно и
/// так видно.
///
/// 🔴 МИКРОФОН И ЗВУК — ЗДЕСЬ, А НЕ НА РЕЙКЕ.
///
/// ТЗ просило поставить их внизу колонки пространства: замолчать, не
/// возвращаясь в окно созвона, — требование верное. Но рейка про РАЗДЕЛЫ
/// приложения, а не про идущий разговор, и кнопка микрофона на ней жила бы
/// третьим местом рядом с доком созвона и этой полосой.
///
/// ◆ ЗВОНОК ОДИН НА ОДИН — ТОЖЕ ЗДЕСЬ (24.09.2026). Раньше полоса знала только
/// комнатные созвоны: звонок один на один свернуть было нельзя, и полоса ему
/// была не нужна. Теперь он сворачивается в мини-окно, и полоса говорит о нём
/// то же, что о созвоне: идёт, с кем, замолчать, положить трубку, вернуться.
class DesktopActiveCallBar extends StatefulWidget {
  const DesktopActiveCallBar({
    super.key,
    required this.onReturn,
    required this.titleFor,
    required this.onToggleMic,
    this.onLeave,
    this.direct,
    this.onDirectReturn,
    this.onDirectToggleMic,
    this.onDirectEnd,
  });

  /// Вернуться в окно созвона: получает комнату и её имя.
  final void Function(String roomId, String title) onReturn;

  /// Имя комнаты по её идентификатору. Пусто — покажем полосу без имени.
  final String Function(String roomId) titleFor;

  /// Выключить/включить свой микрофон, не открывая окно созвона.
  final Future<void> Function() onToggleMic;

  /// Выйти из созвона, не открывая его окно. `null` — кнопки нет.
  final Future<void> Function()? onLeave;

  /// Звонок один на один. `null` — полоса о нём не знает.
  final ValueListenable<CallState>? direct;
  final VoidCallback? onDirectReturn;
  final Future<void> Function()? onDirectToggleMic;
  final VoidCallback? onDirectEnd;

  @override
  State<DesktopActiveCallBar> createState() => _DesktopActiveCallBarState();
}

class _DesktopActiveCallBarState extends State<DesktopActiveCallBar> {
  @override
  void initState() {
    super.initState();
    RoomCallManager.instance?.state.addListener(_onState);
    widget.direct?.addListener(_onDirect);
  }

  @override
  void didUpdateWidget(DesktopActiveCallBar old) {
    super.didUpdateWidget(old);
    if (old.direct != widget.direct) {
      old.direct?.removeListener(_onDirect);
      widget.direct?.addListener(_onDirect);
    }
  }

  @override
  void dispose() {
    RoomCallManager.instance?.state.removeListener(_onState);
    widget.direct?.removeListener(_onDirect);
    super.dispose();
  }

  /// 🔴 ИМЯ КОМНАТЫ ЗАПОМИНАЕТСЯ НА ВЕСЬ СОЗВОН.
  ///
  /// Оно приходит из складов выбора: пока открыта та самая комната, имя есть,
  /// а стоит уйти в другой раздел — склад её уже не держит, и полоса теряла
  /// имя посреди разговора. Проверено живьём: «Идёт созвон · тест 2»
  /// превращалось в «Идёт созвон» при переходе в «Чаты».
  ///
  /// Помним последнее НЕПУСТОЕ имя и сбрасываем его вместе с созвоном.
  String _rememberedTitle = '';

  /// Пока переключение летит на сервер — кнопка не принимает нажатий: иначе
  /// два быстрых нажатия разъедутся с ответом и состояние замигает.
  bool _busy = false;

  /// Выход тоже летит на сервер; второе нажатие ничего не добавит.
  bool _leaving = false;

  Future<void> _toggleMic() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onToggleMic();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final leave = widget.onLeave;
    if (leave == null || _leaving) return;
    setState(() => _leaving = true);
    try {
      await leave();
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  void _onState() {
    if (!mounted) return;
    if (_joinedRoomId == null) _rememberedTitle = '';
    setState(() {});
  }

  void _onDirect() {
    if (mounted) setState(() {});
  }

  /// Комната, в созвоне которой Я СЕЙЧАС нахожусь. `null` — полосы нет.
  String? get _joinedRoomId {
    final state = RoomCallManager.instance?.state.value;
    if (state == null || !state.hasActiveSession) return null;
    final self = state.session?.selfParticipant;
    if (self == null || !self.isJoined) return null;
    final roomId = state.roomId.trim();
    return roomId.isEmpty ? null : roomId;
  }

  @override
  Widget build(BuildContext context) {
    final direct = _directRow(context);
    final room = _roomRow(context);
    if (direct == null) return room;
    return Column(mainAxisSize: MainAxisSize.min, children: [direct, room]);
  }

  /// Строка звонка один на один. `null` — такого звонка нет или он ещё
  /// звонит (входящий показывает своя всплывашка).
  Widget? _directRow(BuildContext context) {
    final s = widget.direct?.value;
    if (s == null || !s.isActive || s.phase == CallPhase.ringingIncoming) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = desktopCallPeerKnownName(s);
    final end = widget.onDirectEnd;
    final toggleMic = widget.onDirectToggleMic;
    return _BarFrame(
      icon: FluentIcons.call_24_filled,
      text: name.isEmpty
          ? l10n.contactDetailsCall
          : l10n.desktopCallDirectWith(name),
      actions: [
        if (toggleMic != null) ...[
          _BarIconButton(
            icon: s.isMuted
                ? FluentIcons.mic_off_24_filled
                : FluentIcons.mic_24_filled,
            tooltip: s.isMuted ? l10n.desktopCallMicOn : l10n.desktopCallMicOff,
            danger: s.isMuted,
            onTap: () => toggleMic(),
          ),
          const SizedBox(width: 6),
        ],
        if (end != null) ...[
          _BarIconButton(
            icon: FluentIcons.call_end_24_filled,
            tooltip: l10n.callControlEnd,
            solid: true,
            onTap: end,
          ),
          const SizedBox(width: 6),
        ],
        _ReturnButton(onTap: widget.onDirectReturn),
      ],
    );
  }

  Widget _roomRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roomId = _joinedRoomId;
    if (roomId == null) return const SizedBox.shrink();
    final fresh = widget.titleFor(roomId).trim();
    if (fresh.isNotEmpty) _rememberedTitle = fresh;
    final title = fresh.isNotEmpty ? fresh : _rememberedTitle;
    final muted =
        RoomCallManager.instance?.state.value.session?.selfParticipant?.muted ??
        false;
    return _BarFrame(
      icon: FluentIcons.person_voice_20_filled,
      text: title.isEmpty
          ? l10n.desktopCallInProgress
          : l10n.desktopCallInProgressWith(title),
      actions: [
        // Состояние микрофона берём у СЕССИИ, а не у своего поля: окно
        // созвона меняет его тем же путём, и два места не должны спорить.
        _BarIconButton(
          icon: muted
              ? FluentIcons.mic_off_24_filled
              : FluentIcons.mic_24_filled,
          tooltip: muted ? l10n.desktopCallMicOn : l10n.desktopCallMicOff,
          // Выключенный микрофон тревожит, включённый — нет: красим только
          // отказ, как и в доке созвона.
          danger: muted,
          onTap: _busy ? null : _toggleMic,
        ),
        const SizedBox(width: 6),
        if (widget.onLeave != null) ...[
          _BarIconButton(
            icon: FluentIcons.call_end_24_filled,
            tooltip: l10n.desktopCallLeaveCall,
            solid: true,
            onTap: _leaving ? null : _leave,
          ),
          const SizedBox(width: 6),
        ],
        _ReturnButton(onTap: () => widget.onReturn(roomId, title)),
      ],
    );
  }
}

/// Сама полоса: значок, подпись и кнопки справа.
class _BarFrame extends StatelessWidget {
  const _BarFrame({
    required this.icon,
    required this.text,
    required this.actions,
  });

  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
      decoration: BoxDecoration(
        color: c.voice.withValues(alpha: 0.14),
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: c.voice),
          const SizedBox(width: 8),
          // 🔴 `Expanded`, а не `Flexible` с распоркой. Подпись и распорка
          // делили свободное место пополам, и кнопки полосы стояли у середины
          // окна, а не у правого края, где их ищут.
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.tiny.copyWith(color: c.voice),
            ),
          ),
          const SizedBox(width: DSpace.s),
          ...actions,
        ],
      ),
    );
  }
}

/// «Вернуться» — развернуть звонок обратно.
class _ReturnButton extends StatelessWidget {
  const _ReturnButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.voice.withValues(alpha: hovered ? 0.34 : 0.22),
          borderRadius: BorderRadius.circular(DRadii.r9),
        ),
        child: Text(
          l10n.desktopCallReturn,
          style: DType.tiny.copyWith(
            fontSize: 10.5,
            color: c.voice,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Кнопка в полосе созвона: 24×24, радиус 9.
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.solid = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  /// Красная заливка — «положить трубку». Отличается от «микрофон
  /// выключен» (красный значок на бледном), чтобы две красные кнопки рядом
  /// не читались одной.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final tone = (danger || solid) ? c.danger : c.voice;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: HoverListener(
          onTap: onTap,
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          builder: (ctx, hovered, pressed) => Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              width: solid ? 30 : 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: solid
                    ? tone.withValues(alpha: hovered ? 1 : 0.88)
                    : tone.withValues(alpha: hovered ? 0.30 : 0.18),
                borderRadius: BorderRadius.circular(DRadii.r9),
              ),
              child: Icon(
                icon,
                size: 13,
                color: solid ? Colors.white : tone,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
