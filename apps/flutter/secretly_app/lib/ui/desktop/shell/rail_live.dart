// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../app/desktop_app_view_model.dart';
import '../app/desktop_selector.dart';
export 'sidebar.dart' show RailSnapshot, RailSpace;

import 'sidebar.dart';

/// Рейка, подключённая к живым данным.
///
/// 🔴 ПОЧЕМУ ЭТО ОТДЕЛЬНЫЙ ВИДЖЕТ, А НЕ ПАРАМЕТРЫ КОРНЯ.
///
/// Корень десктопа намеренно НЕ перерисовывается на тике контроллера: `changed`
/// бьёт постоянно на подключённом устройстве — насос исходящих, сторож службы,
/// биения присутствия, квитанции, — и перерисовка всего дерева на каждом из них
/// держала растровый поток занятым непрерывно (замер: ~22 % ядра на холостом
/// ходу против ~2 % после). Считать счётчики и закреплённые комнаты в корне
/// значило бы вернуть ровно это.
///
/// Поэтому рейка подписывается сама и через общий шов
/// ([DesktopAppViewModel.select]): запрос идёт с общей задержкой, а перерисовка
/// случается, только когда её собственная подпись изменилась.
///
/// 🔴 Контроллер сюда НЕ приходит: снимок собирает тот, у кого шов уже есть.
class DesktopLiveRail extends StatefulWidget {
  const DesktopLiveRail({
    super.key,
    required this.vm,
    required this.load,
    required this.active,
    required this.onSelect,
    required this.connectionStatus,
    this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenSpace,
    this.onAddFavourite,
    this.activeSpaceConvoId,
  });

  final DesktopAppViewModel vm;

  /// Собирает снимок рейки. Ходит к приложению не рейка, а тот, кто её строит.
  final Future<RailSnapshot> Function() load;

  final DesktopSection active;
  final ValueChanged<DesktopSection> onSelect;
  final ConnectionStatus connectionStatus;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenProfile;
  final ValueChanged<String>? onOpenSpace;
  final VoidCallback? onAddFavourite;
  final String? activeSpaceConvoId;

  @override
  State<DesktopLiveRail> createState() => _DesktopLiveRailState();
}

class _DesktopLiveRailState extends State<DesktopLiveRail> {
  late final DesktopSelector<RailSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.vm.select<RailSnapshot>(
      debugName: 'rail',
      initial: const RailSnapshot(),
      load: widget.load,
      signature: (snap) => snap.signature,
    )..addListener(_onTick);
  }

  @override
  void dispose() {
    _snapshot.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot.value;
    return DesktopSidebar(
      active: widget.active,
      onSelect: widget.onSelect,
      onOpenSettings: widget.onOpenSettings,
      onOpenProfile: widget.onOpenProfile,
      connectionStatus: widget.connectionStatus,
      unreadByTab: <DesktopSection, int>{
        DesktopSection.chats: snap.directUnread,
        DesktopSection.rooms: snap.roomUnread,
      },
      spaces: snap.spaces,
      activeSpaceConvoId: widget.activeSpaceConvoId,
      onOpenSpace: widget.onOpenSpace,
      onAddFavourite: widget.onAddFavourite,
      selfName: snap.selfName,
      selfAvatarPath: snap.selfAvatarPath,
      selfFrameId: snap.selfFrameId,
    );
  }
}
