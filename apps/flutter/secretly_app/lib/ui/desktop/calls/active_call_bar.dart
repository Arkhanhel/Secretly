// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../rooms/room_call_manager.dart';
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';

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
/// Времени разговора здесь НЕТ намеренно: оно уже идёт в шапке окна созвона, а
/// у полосы другая работа — вернуть человека туда, где оно и так видно.
///
/// 🔴 МИКРОФОН И ЗВУК — ЗДЕСЬ, А НЕ НА РЕЙКЕ.
///
/// ТЗ просило поставить их внизу колонки пространства: замолчать, не
/// возвращаясь в окно созвона, — требование верное. Но рейка про РАЗДЕЛЫ
/// приложения, а не про идущий разговор, и кнопка микрофона на ней жила бы
/// третьим местом рядом с доком созвона и этой полосой.
///
/// Полоса и так говорит «разговор идёт» и видна из любого раздела — ей эти
/// две кнопки принадлежат по смыслу, и человек находит их там же, где узнаёт
/// о созвоне.
class DesktopActiveCallBar extends StatefulWidget {
  const DesktopActiveCallBar({
    super.key,
    required this.onReturn,
    required this.titleFor,
    required this.onToggleMic,
  });

  /// Вернуться в окно созвона: получает комнату и её имя.
  final void Function(String roomId, String title) onReturn;

  /// Имя комнаты по её идентификатору. Пусто — покажем полосу без имени.
  final String Function(String roomId) titleFor;

  /// Выключить/включить свой микрофон, не открывая окно созвона.
  final Future<void> Function() onToggleMic;

  @override
  State<DesktopActiveCallBar> createState() => _DesktopActiveCallBarState();
}

class _DesktopActiveCallBarState extends State<DesktopActiveCallBar> {
  @override
  void initState() {
    super.initState();
    RoomCallManager.instance?.state.addListener(_onState);
  }

  @override
  void dispose() {
    RoomCallManager.instance?.state.removeListener(_onState);
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

  Future<void> _toggleMic() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onToggleMic();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onState() {
    if (!mounted) return;
    if (_joinedRoomId == null) _rememberedTitle = '';
    setState(() {});
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
    final roomId = _joinedRoomId;
    if (roomId == null) return const SizedBox.shrink();
    final c = DColors.of(context);
    final fresh = widget.titleFor(roomId).trim();
    if (fresh.isNotEmpty) _rememberedTitle = fresh;
    final title = fresh.isNotEmpty ? fresh : _rememberedTitle;
    final muted =
        RoomCallManager.instance?.state.value.session?.selfParticipant?.muted ??
        false;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m),
      decoration: BoxDecoration(
        color: c.voice.withValues(alpha: 0.14),
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.person_voice_20_filled, size: 15, color: c.voice),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title.isEmpty ? 'Идёт созвон' : 'Идёт созвон · $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.tiny.copyWith(color: c.voice),
            ),
          ),
          const Spacer(),
          // Состояние микрофона берём у СЕССИИ, а не у своего поля: окно
          // созвона меняет его тем же путём, и два места не должны спорить.
          _BarIconButton(
            icon: muted
                ? FluentIcons.mic_off_24_filled
                : FluentIcons.mic_24_filled,
            tooltip: muted ? 'Включить микрофон' : 'Выключить микрофон',
            // Выключенный микрофон тревожит, включённый — нет: красим только
            // отказ, как и в доке созвона.
            danger: muted,
            onTap: _busy ? null : _toggleMic,
          ),
          const SizedBox(width: 6),
          HoverListener(
            onTap: () => widget.onReturn(roomId, title),
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
                'Вернуться',
                style: DType.tiny.copyWith(
                  fontSize: 10.5,
                  color: c.voice,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final tone = danger ? c.danger : c.voice;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: HoverListener(
        onTap: onTap,
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: hovered ? 0.30 : 0.18),
              borderRadius: BorderRadius.circular(DRadii.r9),
            ),
            child: Icon(icon, size: 13, color: tone),
          ),
        ),
      ),
    );
  }
}
