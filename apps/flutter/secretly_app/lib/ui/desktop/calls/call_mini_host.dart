// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../calls/call_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rooms/room_call_manager.dart';
import '../../../rooms/room_call_media_controller.dart';
import '../../../rooms/room_call_media_state.dart';
import '../../../rooms/room_call_state.dart';
import '../../../rooms/room_models.dart';
import '../../../transport/relay_client.dart'
    show RelayRoomCallMediaBackendKind;
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../services/desktop_ui_prefs.dart';
import 'call_mini_window.dart';
import 'call_presence.dart';
import 'call_stage_pick.dart';
import 'one_to_one_call_screen.dart';

/// Мини-окна свёрнутых звонков — всё, что плавает поверх приложения.
///
/// Сам следит за звонками: за звонком один на один (через
/// [DesktopDirectCall]) и за комнатным созвоном (через [RoomCallManager]).
/// Корню остаётся положить его поверх оболочки и дать ему руки: что делать
/// по кнопкам. Своих шагов звонка здесь нет ни одного — только вызовы тех
/// же путей, что у полосы и окон звонка.
class DesktopCallMiniHost extends StatefulWidget {
  const DesktopCallMiniHost({
    super.key,
    required this.direct,
    required this.onDirectEnd,
    required this.loadRoomMembers,
    required this.loadRoomCall,
    required this.roomTitleFor,
    required this.onRoomToggleMic,
    required this.onRoomToggleCamera,
    required this.onRoomLeave,
    required this.onRoomExpand,
    this.selfProfileId = '',
  });

  /// Звонок один на один. `null` — звонков нет (приложение ещё не готово).
  final DesktopDirectCall? direct;
  final VoidCallback onDirectEnd;

  final Future<List<RoomMember>> Function(String roomId) loadRoomMembers;
  final Future<CachedRoomCall?> Function(String roomId) loadRoomCall;
  final String Function(String roomId) roomTitleFor;
  final Future<void> Function() onRoomToggleMic;
  final Future<void> Function(bool enable) onRoomToggleCamera;
  final Future<void> Function() onRoomLeave;
  final void Function(String roomId, String title) onRoomExpand;
  final String selfProfileId;

  @override
  State<DesktopCallMiniHost> createState() => _DesktopCallMiniHostState();
}

class _DesktopCallMiniHostState extends State<DesktopCallMiniHost> {
  final DesktopCallPresence _presence = DesktopCallPresence.instance;

  /// Раз в секунду — ради времени разговора и признака речи.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _presence.directMinimized.addListener(_changed);
    _presence.roomWindowOpen.addListener(_changed);
    DesktopUiPrefs.callMiniCorner.addListener(_changed);
    RoomCallManager.instance?.state.addListener(_changed);
    widget.direct?.state.addListener(_changed);
    _syncTicker();
  }

  @override
  void didUpdateWidget(DesktopCallMiniHost old) {
    super.didUpdateWidget(old);
    if (old.direct != widget.direct) {
      old.direct?.state.removeListener(_changed);
      widget.direct?.state.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _presence.directMinimized.removeListener(_changed);
    _presence.roomWindowOpen.removeListener(_changed);
    DesktopUiPrefs.callMiniCorner.removeListener(_changed);
    RoomCallManager.instance?.state.removeListener(_changed);
    widget.direct?.state.removeListener(_changed);
    _ticker?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
  }

  /// Часы идут, только пока есть что показывать: без звонка окно не должно
  /// перерисовываться каждую секунду.
  void _syncTicker() {
    final want = _directVisible || _roomVisible != null;
    if (want && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!want && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool get _directVisible {
    final s = widget.direct?.state.value;
    if (s == null || !s.isActive || s.phase == CallPhase.ringingIncoming) {
      return false;
    }
    return _presence.directMinimized.value;
  }

  /// Комната, чей созвон показать мини-окном. `null` — показывать нечего:
  /// я не в созвоне или его окно открыто.
  String? get _roomVisible {
    final state = RoomCallManager.instance?.state.value;
    if (state == null || !state.hasActiveSession) return null;
    final self = state.session?.selfParticipant;
    if (self == null || !self.isJoined) return null;
    final roomId = state.roomId.trim();
    if (roomId.isEmpty) return null;
    if (_presence.roomWindowOpen.value == roomId) return null;
    return roomId;
  }

  @override
  Widget build(BuildContext context) {
    final entries = <DesktopCallMiniEntry>[];
    final direct = widget.direct;
    if (direct != null && _directVisible) {
      final s = direct.state.value;
      entries.add(
        DesktopCallMiniEntry(
          id: 'direct',
          size: OneToOneCallMini.sizeFor(s),
          child: OneToOneCallMini(
            call: direct,
            peerName: s.peerName.trim(),
            peerImage: Avatar.fileImage(s.peerAvatarPath),
            onExpand: _presence.expandDirect,
            onEnd: widget.onDirectEnd,
          ),
        ),
      );
    }
    final roomId = _roomVisible;
    if (roomId != null) {
      final title = _titleFor(roomId);
      final video = _RoomMini.hasStage();
      entries.add(
        DesktopCallMiniEntry(
          id: 'room',
          size: DesktopCallMiniSize.of(video: video),
          child: _RoomMini(
            roomId: roomId,
            title: title,
            video: video,
            selfProfileId: widget.selfProfileId,
            loadMembers: widget.loadRoomMembers,
            loadCall: widget.loadRoomCall,
            onToggleMic: widget.onRoomToggleMic,
            onToggleCamera: widget.onRoomToggleCamera,
            onLeave: widget.onRoomLeave,
            onExpand: () => widget.onRoomExpand(roomId, title),
          ),
        ),
      );
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return DColors(
      colors: kDColorsDark,
      child: DesktopCallMiniLayer(
        entries: entries,
        corner: desktopCallMiniCornerFrom(DesktopUiPrefs.callMiniCorner.value),
        onCornerChanged: (c) =>
            unawaited(DesktopUiPrefs.setCallMiniCorner(c.name)),
      ),
    );
  }

  String _titleFor(String roomId) {
    final fresh = widget.roomTitleFor(roomId).trim();
    if (fresh.isNotEmpty) {
      _presence.rememberRoomTitle(roomId, fresh);
      return fresh;
    }
    return _presence.roomTitle(roomId);
  }
}

/// Мини-окно комнатного созвона: кто на сцене, сколько в эфире, свои
/// микрофон и камера, развернуть, выйти.
class _RoomMini extends StatefulWidget {
  const _RoomMini({
    required this.roomId,
    required this.title,
    required this.video,
    required this.selfProfileId,
    required this.loadMembers,
    required this.loadCall,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onLeave,
    required this.onExpand,
  });

  final String roomId;
  final String title;

  /// Высокое мини-окно — с картинкой. Решает хозяин: от этого зависит место,
  /// которое он под мини-окно держит.
  final bool video;
  final String selfProfileId;
  final Future<List<RoomMember>> Function(String roomId) loadMembers;
  final Future<CachedRoomCall?> Function(String roomId) loadCall;
  final Future<void> Function() onToggleMic;
  final Future<void> Function(bool enable) onToggleCamera;
  final Future<void> Function() onLeave;
  final VoidCallback onExpand;

  static RoomCallRuntimeState? get _runtime =>
      RoomCallManager.instance?.state.value;

  static RoomCallMediaController? get _media =>
      RoomCallManager.instance?.mediaController;

  /// Те, чей вид камеры УЖЕ готов к показу, в порядке участников.
  static List<String> _cameras() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>[];
    return [
      for (final p in runtime.participants)
        if (p.publishVideo && media.hasParticipantCameraView(p.deviceId))
          p.deviceId,
    ];
  }

  static List<String> _screens() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>[];
    return [
      for (final p in runtime.participants)
        if (p.publishScreenShare &&
            media.hasParticipantScreenShareView(p.deviceId))
          p.deviceId,
    ];
  }

  static Set<String> _speaking() {
    final media = _media;
    final runtime = _runtime;
    if (media == null || runtime == null) return const <String>{};
    return {
      for (final p in runtime.participants)
        if (media.isParticipantSpeaking(p.deviceId)) p.deviceId,
    };
  }

  /// Есть ли картинка для сцены — от этого зависит высота мини-окна.
  static bool hasStage() => _screens().isNotEmpty || _cameras().isNotEmpty;

  @override
  State<_RoomMini> createState() => _RoomMiniState();
}

class _RoomMiniState extends State<_RoomMini> {
  List<RoomMember> _members = const <RoomMember>[];
  CachedRoomCall? _call;
  String _loadedCallId = '';

  /// Кто говорил последним — та же память сцены, что у окна созвона: без
  /// неё картинка гасла бы в каждую паузу разговора.
  String? _lastSpeaker;

  /// Действие летит на сервер — его кнопка не принимает нажатий.
  String? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
    unawaited(_loadCall());
  }

  @override
  void didUpdateWidget(_RoomMini old) {
    super.didUpdateWidget(old);
    if (old.roomId != widget.roomId) {
      _members = const <RoomMember>[];
      _call = null;
      _loadedCallId = '';
      _lastSpeaker = null;
      unawaited(_loadMembers());
    }
    final callId = _RoomMini._runtime?.callId ?? '';
    if (callId != _loadedCallId) unawaited(_loadCall());
  }

  Future<void> _loadMembers() async {
    try {
      final list = await widget.loadMembers(widget.roomId);
      if (mounted) setState(() => _members = list);
    } catch (_) {
      // Имена — украшение: без них сцена подписана не будет, созвон от
      // этого не ломается.
    }
  }

  Future<void> _loadCall() async {
    final callId = _RoomMini._runtime?.callId ?? '';
    _loadedCallId = callId;
    try {
      final call = await widget.loadCall(widget.roomId);
      if (!mounted || _loadedCallId != callId) return;
      setState(() => _call = call);
    } catch (_) {
      // Без снимка нет только времени разговора.
    }
  }

  Future<void> _run(String tag, Future<void> Function() body) async {
    if (_busy != null) return;
    setState(() => _busy = tag);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _nameFor(String profileId, AppLocalizations l10n) {
    if (profileId == widget.selfProfileId) return l10n.desktopSupportYou;
    for (final m in _members) {
      if (m.profileId == profileId) return m.displayName.trim();
    }
    return '';
  }

  RoomMember? _memberFor(String profileId) {
    for (final m in _members) {
      if (m.profileId == profileId) return m;
    }
    return null;
  }

  bool get _mediaBackendReady {
    final backend = RoomCallManager.instance?.session?.backend;
    if (backend == null) return true;
    return backend.kind == RelayRoomCallMediaBackendKind.livekit &&
        backend.isConfigured;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final runtime = _RoomMini._runtime;
    final media = _RoomMini._media;
    final participants = [
      for (final p in runtime?.participants ?? const <RoomCallParticipantRuntimeState>[])
        if (p.isJoined) p,
    ];
    final cameras = _RoomMini._cameras();
    final speaking = _RoomMini._speaking();
    _lastSpeaker = nextLastSpeaker(
      speaking: speaking,
      cameras: cameras,
      previous: _lastSpeaker,
    );
    final pick = pickStageVideo(
      screenShares: _RoomMini._screens(),
      cameras: cameras,
      speaking: speaking,
      lastSpeaker: _lastSpeaker,
    );

    RoomCallParticipantRuntimeState? self;
    for (final p in participants) {
      if (p.isSelf) self = p;
    }
    final muted =
        runtime?.session?.selfParticipant?.muted ?? false;
    final videoOn =
        self != null &&
        self.publishVideo &&
        (media?.hasParticipantCameraView(self.deviceId) ?? false);

    final started = _call?.startedAtMs;
    final count = participants.isEmpty
        ? (_call?.joinedParticipantCount ?? 0)
        : participants.length;
    final status = started == null
        ? l10n.desktopCallInProgress
        : l10n.desktopCallDurationOnAir(desktopCallMiniDuration(started), count);
    final title = widget.title.trim().isEmpty
        ? l10n.desktopCallDiscussion
        : l10n.desktopCallDiscussionOf(widget.title.trim());

    Widget? view;
    RoomCallParticipantRuntimeState? onStage;
    if (pick != null && media != null) {
      for (final p in participants) {
        if (p.deviceId == pick.deviceId) onStage = p;
      }
      if (onStage != null) {
        view = media.buildParticipantVideoView(
          deviceId: pick.deviceId,
          mirror: onStage.isSelf && !pick.screenShare,
          kind: pick.screenShare
              ? RoomCallVideoKind.screenShare
              : RoomCallVideoKind.camera,
        );
      }
    }

    final Widget stage;
    if (widget.video && view != null && onStage != null) {
      final who = _nameFor(onStage.profileId, l10n);
      final caption = pick!.screenShare
          ? (who.isEmpty ? '' : l10n.desktopCallSharingScreen(who))
          : who;
      stage = Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: kDesktopCallMiniStage, child: view),
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            // Без замка: групповой созвон пока не сквозной (см. подсказку в
            // окне созвона). Замок вернётся вместе с E2EE созвонов.
            child: Row(
              children: [DesktopCallMiniChip(label: status, secure: false)],
            ),
          ),
          if (caption.isNotEmpty)
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ),
        ],
      );
    } else {
      stage = _VoiceStage(
        title: title,
        status: status,
        faces: [
          // Говорящие — вперёд: в мини-окне видно три лица, и это должны
          // быть те, кто сейчас держит слово.
          for (final p in [
            ...participants.where((p) => speaking.contains(p.deviceId)),
            ...participants.where((p) => !speaking.contains(p.deviceId)),
          ].take(3))
            (
              name: _nameFor(p.profileId, l10n),
              seed: p.profileId,
              image: Avatar.fileImage(_memberFor(p.profileId)?.avatarPath),
              speaking: speaking.contains(p.deviceId),
            ),
        ],
      );
    }

    return DesktopCallMiniCard(
      video: widget.video,
      stage: stage,
      semanticLabel: '$title · $status',
      onExpand: widget.onExpand,
      expandTooltip: l10n.desktopCallExpand,
      controls: [
        DesktopCallMiniButton(
          icon: muted ? FluentIcons.mic_off_20_filled : FluentIcons.mic_20_filled,
          tooltip: muted ? l10n.desktopCallMicOn : l10n.desktopCallMicOff,
          tone: muted ? DesktopCallMiniTone.off : DesktopCallMiniTone.normal,
          onTap: _busy != null
              ? null
              : () => unawaited(_run('mic', widget.onToggleMic)),
        ),
        DesktopCallMiniButton(
          icon: videoOn
              ? FluentIcons.video_20_filled
              : FluentIcons.video_off_20_filled,
          tooltip: _mediaBackendReady
              ? (videoOn ? l10n.desktopCallCamOff : l10n.desktopCallCamOn)
              : l10n.desktopCallNoMediaVideo,
          onTap: (_busy != null || !_mediaBackendReady)
              ? null
              : () => unawaited(
                  _run('camera', () => widget.onToggleCamera(!videoOn)),
                ),
        ),
      ],
      // Выйти можно всегда — даже когда другое действие ещё летит: выход из
      // разговора не может зависеть от того, ответил ли сервер на другое.
      end: DesktopCallMiniButton(
        icon: FluentIcons.call_end_20_filled,
        tooltip: l10n.desktopCallLeaveCall,
        tone: DesktopCallMiniTone.end,
        onTap: _busy == 'leave'
            ? null
            : () {
                setState(() => _busy = 'leave');
                unawaited(
                  widget.onLeave().whenComplete(() {
                    if (mounted) setState(() => _busy = null);
                  }),
                );
              },
      ),
    );
  }
}

typedef _Face = ({String name, String seed, ImageProvider? image, bool speaking});

/// Сцена созвона без картинки: лица, имя комнаты, время и сколько в эфире.
class _VoiceStage extends StatelessWidget {
  const _VoiceStage({
    required this.title,
    required this.status,
    required this.faces,
  });

  final String title;
  final String status;
  final List<_Face> faces;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    const size = 36.0;
    const step = 24.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (faces.isNotEmpty) ...[
            SizedBox(
              width: size + step * (faces.length - 1) + 4,
              height: size + 4,
              child: Stack(
                children: [
                  // Первым рисуется последнее лицо: первое, самое важное,
                  // ложится сверху.
                  for (var i = faces.length - 1; i >= 0; i--)
                    Positioned(
                      left: step * i,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: faces[i].speaking
                              ? c.success
                              : kDesktopCallMiniStage,
                        ),
                        child: Avatar(
                          name: faces[i].name,
                          seed: faces[i].seed,
                          image: faces[i].image,
                          size: size,
                          background: kDesktopCallMiniStage,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DType.bodyStrong.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DType.tiny.copyWith(
                    color: c.success,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
