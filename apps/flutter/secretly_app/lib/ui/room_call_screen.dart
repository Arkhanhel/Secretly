// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'scroll_feel.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/app_controller.dart';
import '../calls/call_audio_route.dart';
import '../rooms/room_call_manager.dart';
import '../rooms/room_call_media_controller.dart';
import '../rooms/room_call_media_state.dart';
import '../rooms/room_call_state.dart';
import 'android_picture_in_picture.dart';
import 'icons/app_icons.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/system_bottom_fade.dart';
import 'widgets/broken_media_box.dart';

// ── Dark call-screen colour palette ──────────────────────────────────────────
const _kCallBg = Color(0xFF0D0D0D);
const _kCallTileBg = Color(0xFF1C1C1E);
const _kCallTileBgAlt = Color(0xFF2C2C2E);
const _kCallSpeakGreen = Color(0xFF34C759);
const _kCallLeaveRed = Color(0xFFFF3B30);
const _kCallControlBg = Color(0xFF2C2C2E);
const _kCallControlBgActive = Color(0xFF3A3A3C);
const _kCallTextPrimary = Colors.white;
// Slightly brighter secondary than iOS' 8E8E93 — against the flat #0D0D0D
// call background the stock grey read as washed-out/pale.
const _kCallTextSecondary = Color(0xFF9C9CA3);
const _kCallTileMetaBg = Color(0xCC11131A);

String _roomCallText(
  BuildContext context, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}

class RoomCallScreen extends StatefulWidget {
  const RoomCallScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.initialTitle,
  });

  final AppController controller;
  final String groupId;
  final String initialTitle;

  @override
  State<RoomCallScreen> createState() => _RoomCallScreenState();
}

class _RoomCallScreenState extends State<RoomCallScreen>
    with WidgetsBindingObserver {
  String? _pendingAction;
  Timer? _tickTimer;
  String _roomMediaBootstrapKey = '';
  bool _showAudioRouteChoices = false;
  bool? _lastAndroidPipEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tick every second so the elapsed timer re-renders in real time.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    unawaited(AndroidPictureInPicture.setAutoEnterEnabled(enabled: false));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused) {
      return;
    }
    if (_lastAndroidPipEnabled == true) {
      unawaited(AndroidPictureInPicture.enter());
    }
  }

  String _t({required String ru, required String en}) {
    return _roomCallText(context, ru: ru, en: en);
  }

  Future<_RoomCallVm> _load() async {
    final conversations = await widget.controller.listConversations();
    final convo = conversations
        .where((conversation) => conversation.convoId == widget.groupId)
        .cast<Conversation?>()
        .firstOrNull;
    final members = await widget.controller.listRoomMembersDetailed(
      widget.groupId,
    );
    final policy = await widget.controller.getRoomPolicyState(
      widget.groupId,
      profileIdOverride: widget.controller.profileId,
    );
    final activeCall = await widget.controller.getCachedRoomCall(
      widget.groupId,
    );
    final title = (convo?.title ?? widget.initialTitle).trim();
    return _RoomCallVm(
      groupId: widget.groupId,
      title: title.isEmpty ? _t(ru: 'Комната', en: 'Room') : title,
      members: members,
      policy: policy,
      activeCall: activeCall != null && activeCall.isActive ? activeCall : null,
      myProfileId: widget.controller.profileId,
    );
  }

  Future<void> _runAction(
    String actionId,
    Future<bool> Function() action,
  ) async {
    if (_pendingAction != null) {
      return;
    }
    setState(() {
      _pendingAction = actionId;
    });
    try {
      final ok = await action();
      if (!mounted || ok) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _roomCallText(
              context,
              ru: 'Сейчас не удалось применить действие room call.',
              en: 'Could not apply the room call action right now.',
              uk: 'Зараз не вдалося застосувати дію room call.',
              es: 'No se pudo aplicar la accion de llamada de sala ahora.',
              pt: 'Nao foi possivel aplicar a acao da chamada da sala agora.',
              ptBr: 'Nao foi possivel aplicar a acao da chamada da sala agora.',
              fr: 'Impossible d appliquer cette action d appel de salon maintenant.',
              de: 'Die Raum-Anrufaktion konnte gerade nicht angewendet werden.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _pendingAction = null;
        });
      }
    }
  }

  Future<void> _handleAudioRoutePrimaryAction(
    CallAudioRouteState routeState,
    RoomCallRuntimeState runtimeState,
  ) async {
    final manager = RoomCallManager.instance;
    if (manager == null) {
      return;
    }
    // 🔴 ТА ЖЕ ЛОВУШКА, ЧТО В ЗВОНКЕ 1:1 (12.08.2026). Здесь стояло
    // `if (hasMultipleChoices) { показать список; return; }` — и кнопка громкой
    // при трёх маршрутах переставала быть переключателем. Жалоба пришла по
    // личным звонкам, но допущение выполнялось и здесь. Выбор маршрута переехал
    // на долгое нажатие.
    final isSpeakerSelected =
        routeState.isSpeakerSelected ||
        (routeState.selectedRoute == null &&
            runtimeState.localMedia.speakerEnabled);
    await manager.setSpeakerEnabled(!isSpeakerSelected);
    if (!mounted) {
      return;
    }
    setState(() {
      _showAudioRouteChoices = false;
    });
  }

  Future<void> _selectAudioRoute(String routeId) async {
    final manager = RoomCallManager.instance;
    if (manager == null) {
      return;
    }
    await manager.selectAudioRoute(routeId);
    if (!mounted) {
      return;
    }
    setState(() {
      _showAudioRouteChoices = false;
    });
  }

  Future<void> _startOrJoinCall(
    _RoomCallVm vm, {
    required String mediaType,
    required bool videoEnabled,
    required bool muted,
  }) {
    return _runAction('join:$mediaType:$videoEnabled:$muted', () async {
      final effectiveMediaType = vm.activeCall?.mediaType ?? mediaType;
      final result = await widget.controller.joinRelayRoomCall(
        roomId: widget.groupId,
        mediaType: effectiveMediaType,
        supportsVideo: true,
        supportsScreenShare: true,
        muted: muted,
        deafened: false,
        videoEnabled: videoEnabled,
        screenShareEnabled: false,
      );
      if (result != null) {
        await RoomCallManager.instance?.ensureJoined(
          roomId: widget.groupId,
          callId: result.call.callId,
          forceRefresh: true,
        );
      }
      return result != null;
    });
  }

  Future<void> _updateSelfParticipant(
    _RoomCallVm vm, {
    bool? reconnecting,
    bool? muted,
    bool? deafened,
    bool? videoEnabled,
    bool? screenShareEnabled,
    bool? speaking,
  }) {
    final activeCall = vm.activeCall;
    final selfParticipant = vm.selfParticipant;
    if (activeCall == null || selfParticipant == null) {
      return Future<void>.value();
    }
    return _runAction('self-update', () async {
      final result = await widget.controller.updateRelayRoomCallParticipant(
        roomId: widget.groupId,
        callId: activeCall.callId,
        reconnecting: reconnecting ?? selfParticipant.isReconnecting,
        muted: muted ?? selfParticipant.muted,
        deafened: deafened ?? selfParticipant.deafened,
        videoEnabled: videoEnabled ?? selfParticipant.videoEnabled,
        screenShareEnabled:
            screenShareEnabled ?? selfParticipant.screenShareEnabled,
        speaking: speaking ?? selfParticipant.speaking,
      );
      if (result != null && (result.selfParticipant?.isJoined ?? false)) {
        unawaited(
          RoomCallManager.instance?.ensureJoined(
                roomId: widget.groupId,
                callId: activeCall.callId,
                forceRefresh: true,
              ) ??
              Future<void>.value(),
        );
      }
      return result != null;
    });
  }

  Future<void> _leaveCall(_RoomCallVm vm) {
    final activeCall = vm.activeCall;
    if (activeCall == null) {
      return Future<void>.value();
    }
    return _runAction('leave', () async {
      final result = await widget.controller.leaveRelayRoomCall(
        roomId: widget.groupId,
        callId: activeCall.callId,
      );
      if (result != null) {
        await RoomCallManager.instance?.clearIfMatches(
          roomId: widget.groupId,
          callId: activeCall.callId,
        );
        if (mounted) Navigator.of(context).pop();
      }
      return result != null;
    });
  }

  Future<void> _removeParticipant(
    _RoomCallVm vm,
    _ResolvedParticipant participant,
  ) async {
    final activeCall = vm.activeCall;
    if (activeCall == null || participant.isSelf) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _roomCallText(
              context,
              ru: 'Удалить из звонка?',
              en: 'Remove from room call?',
              uk: 'Видалити із дзвінка кімнати?',
              es: 'Quitar de la llamada de sala?',
              pt: 'Remover da chamada da sala?',
              ptBr: 'Remover da chamada da sala?',
              fr: 'Retirer de l appel du salon ?',
              de: 'Aus dem Raum-Anruf entfernen?',
            ),
          ),
          content: Text(
            _roomCallText(
              context,
              ru: 'Участник ${participant.displayName} будет удален из активного звонка комнаты.',
              en: '${participant.displayName} will be removed from the active room call.',
              uk: 'Учасника ${participant.displayName} буде видалено з активного дзвінка кімнати.',
              es: '${participant.displayName} se quitara de la llamada de sala activa.',
              pt: '${participant.displayName} sera removido da chamada ativa da sala.',
              ptBr:
                  '${participant.displayName} sera removido da chamada ativa da sala.',
              fr: '${participant.displayName} sera retire de l appel actif du salon.',
              de: '${participant.displayName} wird aus dem aktiven Raum-Anruf entfernt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_roomCallText(context, ru: 'Отмена', en: 'Cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_roomCallText(context, ru: 'Удалить', en: 'Remove')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction('remove:${participant.deviceId}', () async {
      final result = await widget.controller.removeRelayRoomCallParticipant(
        roomId: widget.groupId,
        callId: activeCall.callId,
        participantDeviceId: participant.deviceId,
      );
      return result != null;
    });
  }

  Future<void> _endCall(_RoomCallVm vm) async {
    final activeCall = vm.activeCall;
    if (activeCall == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _roomCallText(
              context,
              ru: 'Завершить room call?',
              en: 'End room call?',
              uk: 'Завершити дзвінок кімнати?',
              es: 'Finalizar llamada de sala?',
              pt: 'Terminar chamada da sala?',
              ptBr: 'Encerrar chamada da sala?',
              fr: 'Terminer l appel du salon ?',
              de: 'Raum-Anruf beenden?',
            ),
          ),
          content: Text(
            _roomCallText(
              context,
              ru: 'Активный звонок комнаты завершится для всех участников.',
              en: 'The active room call will end for every participant.',
              uk: 'Активний дзвінок кімнати завершиться для всіх учасників.',
              es: 'La llamada de sala activa terminara para todos.',
              pt: 'A chamada ativa da sala vai terminar para todos.',
              ptBr: 'A chamada ativa da sala sera encerrada para todos.',
              fr: 'L appel actif du salon prendra fin pour tous les participants.',
              de: 'Der aktive Raum-Anruf wird fur alle Teilnehmer beendet.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_roomCallText(context, ru: 'Отмена', en: 'Cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                _roomCallText(context, ru: 'Завершить', en: 'End call'),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction('end', () async {
      final result = await widget.controller.endRelayRoomCall(
        roomId: widget.groupId,
        callId: activeCall.callId,
      );
      if (result != null) {
        await RoomCallManager.instance?.clearIfMatches(
          roomId: widget.groupId,
          callId: activeCall.callId,
        );
      }
      return result != null;
    });
  }

  void _reconcileRoomMediaBootstrap(_RoomCallVm vm) {
    final activeCall = vm.activeCall;
    final selfParticipant = vm.selfParticipant;
    final manager = RoomCallManager.instance;
    if (manager == null) {
      return;
    }
    if (activeCall == null || !(selfParticipant?.isJoined ?? false)) {
      _roomMediaBootstrapKey = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          manager.clearIfMatches(
            roomId: widget.groupId,
            callId: activeCall?.callId,
          ),
        );
      });
      return;
    }
    final nextKey = [
      activeCall.callId,
      activeCall.stateVersion.toString(),
      selfParticipant!.joinState,
      selfParticipant.muted ? '1' : '0',
      selfParticipant.deafened ? '1' : '0',
      selfParticipant.videoEnabled ? '1' : '0',
      selfParticipant.screenShareEnabled ? '1' : '0',
    ].join(':');
    if (_roomMediaBootstrapKey == nextKey) {
      return;
    }
    _roomMediaBootstrapKey = nextKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        manager.ensureJoined(
          roomId: widget.groupId,
          callId: activeCall.callId,
          forceRefresh: true,
        ),
      );
    });
  }

  static String _formatElapsed(int deltaMs) {
    final totalSecs = (deltaMs / 1000).floor().clamp(0, 86399);
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BottomSystemFadeVisibility(
      enabled: false,
      child: Scaffold(
        backgroundColor: _kCallBg,
        body: StreamBuilder<void>(
          stream: widget.controller.changed,
          builder: (context, _) {
            return FutureBuilder<_RoomCallVm>(
              future: _load(),
              builder: (context, snapshot) {
                final vm = snapshot.data;
                if (vm == null) return const _CallLoadingView();
                final manager = RoomCallManager.instance;
                if (manager == null) {
                  return _buildCallBody(vm, const RoomCallRuntimeState.idle());
                }
                return ValueListenableBuilder<RoomCallRuntimeState>(
                  valueListenable: manager.state,
                  builder: (context, runtimeState, _) {
                    return _buildCallBody(vm, runtimeState);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCallBody(_RoomCallVm vm, RoomCallRuntimeState runtimeState) {
    _syncAndroidPictureInPicture(vm);
    _reconcileRoomMediaBootstrap(vm);
    final resolvedParticipants = _resolveParticipants(vm, runtimeState);
    return ColoredBox(
      // Flat neutral background (Discord-style) — the video/avatar tiles are
      // the only colour on screen, not a decorative wash behind them.
      color: _kCallBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(vm, runtimeState, resolvedParticipants),
            Expanded(
              child: vm.activeCall == null
                  ? _buildNoCallContent(vm)
                  : _buildParticipantStage(vm, resolvedParticipants),
            ),
            if (vm.policy.isMember && vm.activeCall != null)
              if (RoomCallManager.instance case final manager?)
                ValueListenableBuilder<CallAudioRouteState>(
                  valueListenable: manager.audioRouteState,
                  builder: (context, routeState, _) {
                    return _buildBottomBar(vm, runtimeState, routeState);
                  },
                )
              else
                _buildBottomBar(
                  vm,
                  runtimeState,
                  const CallAudioRouteState.idle(),
                ),
          ],
        ),
      ),
    );
  }

  void _syncAndroidPictureInPicture(_RoomCallVm vm) {
    final enabled = vm.activeCall?.mediaType == 'video' && vm.selfJoined;
    if (_lastAndroidPipEnabled == enabled) {
      return;
    }
    _lastAndroidPipEnabled = enabled;
    unawaited(AndroidPictureInPicture.setAutoEnterEnabled(enabled: enabled));
  }

  Widget _buildTopBar(
    _RoomCallVm vm,
    RoomCallRuntimeState runtimeState,
    List<_ResolvedParticipant> participants,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = vm.activeCall != null
        ? _formatElapsed(now - vm.activeCall!.startedAtMs)
        : null;
    final mediaStatus = _roomMediaStatusText(context, runtimeState);
    final joinedCount = participants
        .where((participant) => participant.isJoined)
        .length;
    final metaParts = <String>[
      if (elapsed != null) elapsed,
      if (vm.activeCall != null && joinedCount > 0)
        _roomCallText(
          context,
          ru: '$joinedCount в эфире',
          en: '$joinedCount live',
          uk: '$joinedCount в ефірі',
          es: '$joinedCount en directo',
          pt: '$joinedCount ao vivo',
          ptBr: '$joinedCount ao vivo',
          fr: '$joinedCount en direct',
          de: '$joinedCount live',
        ),
      if (mediaStatus != null) mediaStatus,
    ];
    final metaText = metaParts.join(' • ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          _CallChromeButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CallGlassIsland(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vm.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kCallTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (metaText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kCallTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (vm.canModerateCall) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              color: _kCallTileBgAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (value) {
                if (value == 'end') unawaited(_endCall(vm));
              },
              child: const _CallChromeButton(icon: Icons.more_horiz_rounded),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'end',
                  child: Text(
                    _roomCallText(
                      context,
                      ru: 'Завершить для всех',
                      en: 'End for everyone',
                      uk: 'Завершити для всіх',
                      es: 'Finalizar para todos',
                      pt: 'Terminar para todos',
                      ptBr: 'Encerrar para todos',
                      fr: 'Terminer pour tous',
                      de: 'Fur alle beenden',
                    ),
                    style: const TextStyle(color: _kCallLeaveRed),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoCallContent(_RoomCallVm vm) {
    if (!vm.policy.isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _roomCallText(
              context,
              ru: 'Только участники комнаты могут входить в звонок.',
              en: 'Only room members can join the call.',
              uk: 'Лише учасники кімнати можуть приєднатися до дзвінка.',
              es: 'Solo los miembros de la sala pueden unirse a la llamada.',
              pt: 'So membros da sala podem entrar na chamada.',
              ptBr: 'Somente membros da sala podem entrar na chamada.',
              fr: 'Seuls les membres du salon peuvent rejoindre l appel.',
              de: 'Nur Raummitglieder konnen dem Anruf beitreten.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kCallTextSecondary, fontSize: 15),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kCallControlBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.callAlt,
                color: _kCallTextSecondary,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _roomCallText(
                context,
                ru: 'Нет активного звонка',
                en: 'No active call',
              ),
              style: const TextStyle(
                color: _kCallTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _roomCallText(
                context,
                ru: 'Начните голосовой или видеозвонок',
                en: 'Start a voice or video call',
                uk: 'Почніть голосовий або відеодзвінок',
                es: 'Inicia una llamada de voz o video',
                pt: 'Inicie uma chamada de voz ou video',
                ptBr: 'Inicie uma chamada de voz ou video',
                fr: 'Demarrez un appel vocal ou video',
                de: 'Starte einen Sprach- oder Videoanruf',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kCallTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _CallControlButton(
                    icon: AppIcons.callAlt,
                    label: _roomCallText(context, ru: 'Голос', en: 'Voice'),
                    bgColor: const Color(0xFF2FA66A),
                    onTap: _pendingAction == null
                        ? () => unawaited(
                            _startOrJoinCall(
                              vm,
                              mediaType: 'audio',
                              videoEnabled: false,
                              muted: false,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CallControlButton(
                    icon: AppIcons.video,
                    label: _roomCallText(context, ru: 'Видео', en: 'Video'),
                    bgColor: _kCallControlBg,
                    onTap: _pendingAction == null
                        ? () => unawaited(
                            _startOrJoinCall(
                              vm,
                              mediaType: 'video',
                              videoEnabled: true,
                              muted: false,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinHint(_RoomCallVm vm) {
    final isVideo = vm.activeCall!.mediaType == 'video';
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Dark glass (white call text needs a dark plate) but lifted like the
          // app's islands: brighter rim + a soft drop shadow.
          color: _kCallTileMetaBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kCallSpeakGreen.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? AppIcons.video : AppIcons.callAlt,
                color: _kCallSpeakGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVideo
                        ? _roomCallText(
                            context,
                            ru: 'Идёт видеозвонок',
                            en: 'Video call in progress',
                            uk: 'Триває відеодзвінок',
                            es: 'Videollamada en curso',
                            pt: 'Chamada de video em curso',
                            ptBr: 'Chamada de video em andamento',
                            fr: 'Appel video en cours',
                            de: 'Videoanruf lauft',
                          )
                        : _roomCallText(
                            context,
                            ru: 'Идёт голосовой звонок',
                            en: 'Voice call in progress',
                            uk: 'Триває голосовий дзвінок',
                            es: 'Llamada de voz en curso',
                            pt: 'Chamada de voz em curso',
                            ptBr: 'Chamada de voz em andamento',
                            fr: 'Appel vocal en cours',
                            de: 'Sprachanruf lauft',
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kCallTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roomCallText(
                      context,
                      ru: '${vm.joinedParticipantCount} участников уже в эфире',
                      en: '${vm.joinedParticipantCount} people are already live',
                      uk: '${vm.joinedParticipantCount} учасників вже в ефірі',
                      es: '${vm.joinedParticipantCount} personas ya estan en directo',
                      pt: '${vm.joinedParticipantCount} pessoas ja estao ao vivo',
                      ptBr:
                          '${vm.joinedParticipantCount} pessoas ja estao ao vivo',
                      fr: '${vm.joinedParticipantCount} personnes sont deja en direct',
                      de: '${vm.joinedParticipantCount} Personen sind bereits live',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kCallTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _pendingAction == null
                  ? () => unawaited(
                      _startOrJoinCall(
                        vm,
                        mediaType: vm.activeCall!.mediaType,
                        videoEnabled: vm.activeCall!.mediaType == 'video',
                        muted: false,
                      ),
                    )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kCallSpeakGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _roomCallText(context, ru: 'Войти', en: 'Join'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantStage(
    _RoomCallVm vm,
    List<_ResolvedParticipant> participants,
  ) {
    final mediaController = RoomCallManager.instance?.mediaController;
    final activeParticipants = participants
        .where(
          (participant) =>
              participant.isJoined ||
              participant.isReconnecting ||
              participant.isSelf,
        )
        .toList(growable: false);
    final displayParticipants = activeParticipants.isEmpty
        ? participants
        : activeParticipants;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Stack(
        children: [
          Positioned.fill(
            child: _ParticipantStage(
              participants: displayParticipants,
              canModerate: vm.canModerateCall,
              mediaController: mediaController,
              onRemoveParticipant: _pendingAction == null
                  ? (_ResolvedParticipant participant) =>
                        unawaited(_removeParticipant(vm, participant))
                  : null,
            ),
          ),
          if (!vm.selfJoined)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _buildJoinHint(vm),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    _RoomCallVm vm,
    RoomCallRuntimeState runtimeState,
    CallAudioRouteState routeState,
  ) {
    final self = vm.selfParticipant;
    final joined = vm.selfJoined;
    final isVideo = vm.activeCall?.mediaType == 'video';
    final showVideoControl = isVideo || (self?.supportsVideo ?? false);
    final videoControlActive = self?.videoEnabled ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: _CallGlassIsland(
        radius: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showAudioRouteChoices && routeState.hasMultipleChoices)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final route in routeState.availableRoutes)
                      _RoomAudioRouteChoiceButton(
                        icon: _roomAudioRouteIcon(route.kind),
                        label: _roomAudioRouteLabel(context, route),
                        active: route.deviceId == routeState.selectedRouteId,
                        onTap: joined && _pendingAction == null
                            ? () => unawaited(_selectAudioRoute(route.deviceId))
                            : null,
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallControlButton(
                  icon: AppIcons.callEnd,
                  label: _roomCallText(context, ru: 'Выйти', en: 'Leave'),
                  filled: true,
                  bgColor: _kCallLeaveRed,
                  showLabel: false,
                  size: 48,
                  onTap: joined && _pendingAction == null
                      ? () => unawaited(_leaveCall(vm))
                      : null,
                ),
                _CallControlButton(
                  icon: (self?.muted ?? true) ? AppIcons.micOff : AppIcons.mic,
                  label: (self?.muted ?? true)
                      ? _roomCallText(
                          context,
                          ru: 'Включить микрофон',
                          en: 'Unmute',
                        )
                      : _roomCallText(
                          context,
                          ru: 'Выключить микрофон',
                          en: 'Mute',
                        ),
                  // Muted is the notable "you can't be heard" state — that's
                  // the one worth flagging with a filled circle.
                  filled: self?.muted ?? true,
                  showLabel: false,
                  size: 48,
                  onTap: joined && _pendingAction == null
                      ? () => unawaited(
                          _updateSelfParticipant(
                            vm,
                            muted: !(self?.muted ?? false),
                          ),
                        )
                      : null,
                ),
                if (showVideoControl)
                  _CallControlButton(
                    icon: videoControlActive
                        ? AppIcons.video
                        : AppIcons.videoOff,
                    label: isVideo
                        ? _roomCallText(context, ru: 'Камера', en: 'Camera')
                        : _roomCallText(context, ru: 'Видео', en: 'Video'),
                    // Broadcasting video is the notable state here.
                    filled: videoControlActive,
                    showLabel: false,
                    size: 48,
                    onTap: joined && _pendingAction == null
                        ? () => unawaited(
                            _updateSelfParticipant(
                              vm,
                              videoEnabled: !videoControlActive,
                            ),
                          )
                        : null,
                    onLongPress:
                        joined &&
                            _pendingAction == null &&
                            runtimeState.localMedia.videoCaptureActive
                        ? () => unawaited(
                            RoomCallManager.instance?.switchCamera() ??
                                Future<void>.value(),
                          )
                        : null,
                  ),
                _CallControlButton(
                  icon: _roomAudioRouteIcon(routeState.selectedRouteKind),
                  label: _roomCallText(context, ru: 'Аудио', en: 'Audio'),
                  // Обычное нажатие ПЕРЕКЛЮЧАЕТ громкую; выбор маршрута — долгим.
                  // Раньше кнопка при трёх маршрутах только разворачивала список
                  // и звук не меняла.
                  showLabel: false,
                  size: 48,
                  onTap: joined && _pendingAction == null
                      ? () => unawaited(
                          _handleAudioRoutePrimaryAction(
                            routeState,
                            runtimeState,
                          ),
                        )
                      : null,
                  onLongPress:
                      joined &&
                          _pendingAction == null &&
                          routeState.hasMultipleChoices
                      ? () => setState(() {
                          _showAudioRouteChoices = !_showAudioRouteChoices;
                        })
                      : null,
                ),
                if (self?.supportsScreenShare ?? false)
                  _CallControlButton(
                    icon: (self?.screenShareEnabled ?? false)
                        ? AppIcons.screenShare
                        : AppIcons.screenShareOff,
                    label: _roomCallText(context, ru: 'Экран', en: 'Share'),
                    // Actively sharing your screen is the notable state.
                    filled: self?.screenShareEnabled ?? false,
                    showLabel: false,
                    size: 48,
                    onTap: joined && _pendingAction == null
                        ? () => unawaited(
                            _updateSelfParticipant(
                              vm,
                              screenShareEnabled:
                                  !(self?.screenShareEnabled ?? false),
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _roomAudioRouteIcon(CallAudioRouteKind kind) {
  switch (kind) {
    case CallAudioRouteKind.bluetooth:
      return AppIcons.bluetoothAudio;
    case CallAudioRouteKind.wiredHeadset:
      return AppIcons.headphones;
    case CallAudioRouteKind.earpiece:
      return AppIcons.call;
    case CallAudioRouteKind.speaker:
      return AppIcons.volumeUp;
    case CallAudioRouteKind.unknown:
      return AppIcons.volumeDown;
  }
}

String _roomAudioRouteLabel(BuildContext context, CallAudioRouteOption route) {
  switch (route.kind) {
    case CallAudioRouteKind.bluetooth:
      return route.label.isNotEmpty ? route.label : 'Bluetooth';
    case CallAudioRouteKind.wiredHeadset:
      return _roomCallText(context, ru: 'Наушники', en: 'Headset');
    case CallAudioRouteKind.earpiece:
      return _roomCallText(context, ru: 'Телефон', en: 'Earpiece');
    case CallAudioRouteKind.speaker:
      return _roomCallText(context, ru: 'Динамик', en: 'Speaker');
    case CallAudioRouteKind.unknown:
      return route.label.isNotEmpty
          ? route.label
          : _roomCallText(context, ru: 'Аудио', en: 'Audio');
  }
}

class _RoomAudioRouteChoiceButton extends StatelessWidget {
  const _RoomAudioRouteChoiceButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _kCallTextPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _kCallTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantStage extends StatefulWidget {
  const _ParticipantStage({
    required this.participants,
    required this.canModerate,
    required this.mediaController,
    this.onRemoveParticipant,
  });

  final List<_ResolvedParticipant> participants;
  final bool canModerate;
  final RoomCallMediaController? mediaController;
  final ValueChanged<_ResolvedParticipant>? onRemoveParticipant;

  @override
  State<_ParticipantStage> createState() => _ParticipantStageState();
}

class _ParticipantStageState extends State<_ParticipantStage> {
  // deviceId of the participant expanded to fullscreen (tap a video tile), or
  // null while showing the normal grid/split stage. Tapping the expanded tile
  // collapses back.
  String? _spotlightDeviceId;

  // Only a participant actually showing a video/screen-share surface can be
  // expanded — matches the ask of "tap a tile whose owner turned video on".
  // An audio-only tile keeps its previous no-op tap behaviour.
  static bool _participantHasVideo(_ResolvedParticipant p) =>
      p.videoEnabled ||
      p.screenShareEnabled ||
      p.publishVideo ||
      p.publishScreenShare;

  void _enterSpotlight(_ResolvedParticipant p) {
    if (!_participantHasVideo(p) || _spotlightDeviceId == p.deviceId) return;
    setState(() => _spotlightDeviceId = p.deviceId);
  }

  void _exitSpotlight() {
    if (_spotlightDeviceId == null) return;
    setState(() => _spotlightDeviceId = null);
  }

  @override
  Widget build(BuildContext context) {
    final orderedParticipants = _sortParticipantsForStage(widget.participants);

    // Resolve the spotlighted participant; if they left the call or dropped
    // their video, fall back to the grid and clear the stale selection.
    _ResolvedParticipant? spotlight;
    if (_spotlightDeviceId != null) {
      for (final p in orderedParticipants) {
        if (p.deviceId == _spotlightDeviceId && _participantHasVideo(p)) {
          spotlight = p;
          break;
        }
      }
      if (spotlight == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _spotlightDeviceId != null) {
            setState(() => _spotlightDeviceId = null);
          }
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final isPortrait = size.height >= size.width;
        const gap = 10.0;

        String shapeKey;
        Widget child;

        if (spotlight != null) {
          // One participant expanded to fullscreen; tap to collapse back.
          shapeKey = 'spotlight-${spotlight.deviceId}';
          child = _buildTile(
            spotlight,
            isPrimary: true,
            onTap: _exitSpotlight,
          );
        } else if (orderedParticipants.isEmpty) {
          shapeKey = 'empty';
          child = const SizedBox.shrink();
        } else if (orderedParticipants.length == 1) {
          shapeKey = 'single';
          child = _buildTile(orderedParticipants.first, isPrimary: true);
        } else if (isPortrait && orderedParticipants.length == 2) {
          shapeKey = 'portrait2';
          child = Column(
            children: [
              Expanded(
                child: _buildTile(orderedParticipants[0], isPrimary: true),
              ),
              const SizedBox(height: gap),
              Expanded(child: _buildTile(orderedParticipants[1])),
            ],
          );
        } else if (isPortrait && orderedParticipants.length == 3) {
          shapeKey = 'portrait3';
          child = Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildTile(orderedParticipants[0])),
                    const SizedBox(width: gap),
                    Expanded(child: _buildTile(orderedParticipants[1])),
                  ],
                ),
              ),
              const SizedBox(height: gap),
              Expanded(child: _buildTile(orderedParticipants[2])),
            ],
          );
        } else {
          final spec = _participantGridSpecForCount(
            orderedParticipants.length,
            size,
          );
          final usableWidth = math.max(
            1.0,
            size.width - gap * (spec.columns - 1),
          );
          final usableHeight = math.max(
            1.0,
            size.height - gap * (spec.targetRows - 1),
          );
          final tileWidth = usableWidth / spec.columns;
          final tileHeight = usableHeight / spec.targetRows;
          final childAspectRatio = spec.scrollable
              ? spec.scrollAspectRatio
              : tileWidth / tileHeight;
          // Keyed by shape (columns×rows), not participant count — adding one
          // more tile within the SAME grid shape (e.g. a scrollable grid
          // gaining a row) shouldn't cross-fade the whole stage, only a
          // genuine shape change (e.g. 3×2 -> 4×3) should.
          shapeKey = 'grid-${spec.columns}x${spec.targetRows}';
          child = GridView.builder(
            key: ValueKey('$shapeKey-items'),
            padding: EdgeInsets.zero,
            physics: spec.scrollable
                ? secretlyListPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: orderedParticipants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: spec.columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              return _buildTile(orderedParticipants[index]);
            },
          );
        }

        // A stage-shape change (1-up -> split -> grid) is infrequent (only on
        // join/leave) but was previously an instant snap — cross-fade it so
        // it reads as a deliberate transition instead of a jarring jump.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (widget, animation) =>
              FadeTransition(opacity: animation, child: widget),
          child: KeyedSubtree(key: ValueKey(shapeKey), child: child),
        );
      },
    );
  }

  Widget _buildTile(
    _ResolvedParticipant participant, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    // Grid tiles expand to fullscreen on tap (video participants only); the
    // spotlight tile passes an explicit onTap that collapses back.
    final resolvedOnTap =
        onTap ??
        (_participantHasVideo(participant)
            ? () => _enterSpotlight(participant)
            : null);
    Widget tile = _CallParticipantTile(
      participant: participant,
      canModerate: widget.canModerate,
      mediaController: widget.mediaController,
      isPrimary: isPrimary,
      onRemove:
          widget.canModerate &&
              !participant.isSelf &&
              widget.onRemoveParticipant != null
          ? () => widget.onRemoveParticipant!(participant)
          : null,
    );
    if (resolvedOnTap != null) {
      // The remove button is a descendant GestureDetector and still wins taps
      // within its own bounds, so it keeps working over this overlay.
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: resolvedOnTap,
        child: tile,
      );
    }
    return tile;
  }
}

class _CallParticipantTile extends StatelessWidget {
  const _CallParticipantTile({
    required this.participant,
    required this.canModerate,
    required this.mediaController,
    this.isPrimary = false,
    this.onRemove,
  });

  final _ResolvedParticipant participant;
  final bool canModerate;
  final RoomCallMediaController? mediaController;
  final bool isPrimary;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        participant.avatarPath != null &&
        participant.avatarPath!.isNotEmpty &&
        File(participant.avatarPath!).existsSync();
    final participantVideoView = mediaController?.buildParticipantVideoView(
      deviceId: participant.deviceId,
      mirror:
          participant.runtimeKind ==
              RoomCallParticipantRuntimeKind.localPreview &&
          !participant.publishScreenShare,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final compact = shortestSide < 138;
        final large = shortestSide > 220 || isPrimary;
        final hasVideoSurface = participantVideoView != null;
        final showBadges = !compact || participant.isReconnecting;
        // Яркий оттенок участника — подложка плитки, а не портрет: у плитки
        // без камеры цвет и есть узнаваемость.
        final accent = AvatarInitials.accentColor(seed: participant.profileId);
        final radius = large
            ? 28.0
            : compact
            ? 18.0
            : 22.0;
        final padding = compact ? 10.0 : 14.0;
        final avatarSize = large
            ? 112.0
            : compact
            ? 56.0
            : 74.0;
        final displayName = participant.isSelf
            ? '${participant.displayName} (${_roomCallText(context, ru: 'Вы', en: 'You')})'
            : participant.displayName;
        // Screen-share status intentionally has no chip here — the
        // capabilities row at the bottom already shows a screen-share icon,
        // and showing both was a duplicated signal for the same fact.
        final badgeChildren = <Widget>[
          if (participant.isSelf && !compact)
            _ParticipantStatusChip(
              label: _roomCallText(context, ru: 'Вы', en: 'You'),
            ),
          if (participant.isReconnecting)
            _ParticipantStatusChip(
              icon: Icons.sync_problem_rounded,
              label: compact
                  ? ''
                  : _roomCallText(context, ru: 'Сеть', en: 'Network'),
              tint: const Color(0xFFFFB84D),
            ),
        ];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: participant.speaking
                  ? _kCallSpeakGreen
                  : Colors.white.withValues(
                      alpha: hasVideoSurface ? 0.10 : 0.06,
                    ),
              width: participant.speaking ? 2.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              if (participant.speaking)
                BoxShadow(
                  color: _kCallSpeakGreen.withValues(alpha: 0.22),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 0.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasVideoSurface)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black,
                      child: participantVideoView,
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      // Richer, longer colour ramp: full-strength accent at
                      // the top blending INTO the dark tile rather than
                      // dropping to flat grey halfway — the previous mix
                      // read as pale/washed-out on the flat call background.
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent,
                          Color.alphaBlend(
                            accent.withValues(alpha: 0.45),
                            _kCallTileBgAlt,
                          ),
                          _kCallTileBg,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                // Subtle bottom gradient only for video tiles (for name legibility)
                if (hasVideoSurface)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!hasVideoSurface)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasAvatar
                              ? Image.file(
                                  File(participant.avatarPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 18, rounded: true, onDarkSurface: true),
                                )
                              : Center(
                                  child: Text(
                                    AvatarInitials.label(
                                      displayName: participant.displayName,
                                      fallbackId: participant.profileId,
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: compact ? 18 : 24,
                                    ),
                                  ),
                                ),
                        ),
                        if (!compact) SizedBox(height: 10),
                        if (!compact)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _kCallTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: large ? 15 : 13,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (showBadges && badgeChildren.isNotEmpty)
                  Positioned(
                    top: padding,
                    left: padding,
                    right: onRemove != null ? padding + 38 : null,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: badgeChildren,
                    ),
                  ),
                if (canModerate &&
                    !participant.isSelf &&
                    participant.isJoined &&
                    onRemove != null)
                  Positioned(
                    top: padding,
                    right: padding,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: compact ? 28 : 30,
                        height: compact ? 28 : 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.54),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          AppIcons.block,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                // Minimal name label — only for video tiles (audio shows name below avatar)
                if (hasVideoSurface)
                  Positioned(
                    left: padding,
                    right: padding,
                    bottom: padding / 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _kCallTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 11 : 13,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 6),
                                Shadow(color: Colors.black54, blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ParticipantCapabilitiesRow(
                          participant: participant,
                          alignment: MainAxisAlignment.end,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                // For compact audio tiles, show name at bottom as minimal text
                if (!hasVideoSurface && compact)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kCallTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallLoadingView extends StatelessWidget {
  const _CallLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

/// Dark "glass island" for call chrome — the same visual recipe as the app's
/// [FrostedHeaderIsland] (backdrop blur + translucent gradient fill + top
/// specular highlight), but tuned for the always-dark call screen instead of
/// following the theme brightness.
class _CallGlassIsland extends StatelessWidget {
  const _CallGlassIsland({
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return CustomPaint(
      foregroundPainter: GlassHighlightBorderPainter(
        radius: radius,
        strokeWidth: 1.1,
        color: Colors.white.withValues(alpha: 0.20),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.11),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: br,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _CallChromeButton extends StatelessWidget {
  const _CallChromeButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, color: _kCallTextPrimary, size: 20),
        ),
      ),
    );
  }
}

/// Discord-style control: a plain ghost icon button by default (no colour —
/// this is ordinary chrome, not a call to action), filling in solid colour
/// ONLY for the destructive Leave button and for a genuinely notable toggled
/// state (muted, camera broadcasting, screen sharing). Reserving colour for
/// those few moments is what makes them actually stand out.
class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    this.filled = false,
    this.bgColor = _kCallControlBgActive,
    this.showLabel = true,
    this.size = 52,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color bgColor;
  final bool showLabel;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: filled ? bgColor : Colors.transparent,
                shape: BoxShape.circle,
                border: filled
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: Icon(
                icon,
                color: filled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85),
                size: 24,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: _kCallTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantStatusChip extends StatelessWidget {
  const _ParticipantStatusChip({
    this.icon,
    required this.label,
    this.tint = Colors.white,
  });

  final IconData? icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label.isEmpty ? 7 : 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tint),
            if (label.isNotEmpty) const SizedBox(width: 5),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: tint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Obsolete helpers that old build used — kept for _participantSubtitle callers
// but old hero/section/notice widgets removed.
// ---------------------------------------------------------------------------

// (Removed: _RoomCallHeroCard, _SectionCard, _MiniAvatar, _ParticipantStateIcon, _StateNoticeCard)
// (Removed: _roomCallHeroStatus, _roomCallHeroSubtitle — not used by new UI)

// ---------------------------------------------------------------------------
// Data classes (unchanged)
// ---------------------------------------------------------------------------

class _RoomCallVm {
  const _RoomCallVm({
    required this.groupId,
    required this.title,
    required this.members,
    required this.policy,
    required this.activeCall,
    required this.myProfileId,
  });

  final String groupId;
  final String title;
  final List<RoomMember> members;
  final RoomPolicyState policy;
  final CachedRoomCall? activeCall;
  final String myProfileId;

  CachedRoomCallParticipant? get selfParticipant => activeCall?.selfParticipant;

  bool get selfJoined => selfParticipant?.isJoined ?? false;

  bool get canModerateCall => policy.canRemoveMembers;

  int get joinedParticipantCount =>
      activeCall?.participants
          .where((participant) => participant.isJoined)
          .length ??
      0;
}

class _ParticipantGridSpec {
  const _ParticipantGridSpec({
    required this.columns,
    required this.targetRows,
    this.scrollable = false,
    this.scrollAspectRatio = 1.0,
  });

  final int columns;
  final int targetRows;
  final bool scrollable;
  final double scrollAspectRatio;
}

class _ResolvedParticipant {
  const _ResolvedParticipant({
    required this.profileId,
    required this.deviceId,
    required this.displayName,
    required this.avatarPath,
    required this.joinState,
    required this.supportsVideo,
    required this.supportsScreenShare,
    required this.role,
    required this.isSelf,
    required this.isJoined,
    required this.isReconnecting,
    required this.isOnline,
    required this.muted,
    required this.deafened,
    required this.videoEnabled,
    required this.screenShareEnabled,
    required this.speaking,
    required this.joinedAtMs,
    required this.runtimeKind,
    required this.runtimeErrorMessage,
    required this.publishAudio,
    required this.publishVideo,
    required this.publishScreenShare,
    required this.showLocalPreview,
  });

  final String profileId;
  final String deviceId;
  final String displayName;
  final String? avatarPath;
  final String joinState;
  final bool supportsVideo;
  final bool supportsScreenShare;
  final RoomMemberRole role;
  final bool isSelf;
  final bool isJoined;
  final bool isReconnecting;
  final bool isOnline;
  final bool muted;
  final bool deafened;
  final bool videoEnabled;
  final bool screenShareEnabled;
  final bool speaking;
  final int joinedAtMs;
  final RoomCallParticipantRuntimeKind runtimeKind;
  final String? runtimeErrorMessage;
  final bool publishAudio;
  final bool publishVideo;
  final bool publishScreenShare;
  final bool showLocalPreview;
}

List<_ResolvedParticipant> _resolveParticipants(
  _RoomCallVm vm,
  RoomCallRuntimeState runtimeState,
) {
  final call = vm.activeCall;
  if (call == null) {
    return const <_ResolvedParticipant>[];
  }
  final memberByProfileId = <String, RoomMember>{
    for (final member in vm.members) member.profileId: member,
  };
  final runtimeByDeviceId = <String, RoomCallParticipantRuntimeState>{
    for (final participant in runtimeState.participants)
      participant.deviceId: participant,
  };
  final resolved = call.participants
      .map((participant) {
        final member = memberByProfileId[participant.profileId];
        final runtime = runtimeByDeviceId[participant.deviceId];
        return _ResolvedParticipant(
          profileId: participant.profileId,
          deviceId: participant.deviceId,
          displayName: member?.displayName.trim().isNotEmpty == true
              ? member!.displayName
              : participant.profileId,
          avatarPath: member?.avatarPath,
          joinState: participant.joinState,
          supportsVideo: participant.supportsVideo,
          supportsScreenShare: participant.supportsScreenShare,
          role: member?.role ?? RoomMemberRole.member,
          isSelf:
              participant.profileId == vm.myProfileId ||
              participant.deviceId == vm.activeCall?.selfParticipant?.deviceId,
          isJoined: participant.isJoined,
          isReconnecting: participant.isReconnecting,
          isOnline: member?.isOnline ?? false,
          muted: participant.muted,
          deafened: participant.deafened,
          videoEnabled: participant.videoEnabled,
          screenShareEnabled: participant.screenShareEnabled,
          // Live VAD comes from the media runtime (LiveKit active speakers);
          // the relay-cached flag has no real signal behind it.
          speaking: runtime?.speaking ?? participant.speaking,
          joinedAtMs: participant.joinedAtMs,
          runtimeKind:
              runtime?.kind ??
              (participant.isReconnecting
                  ? RoomCallParticipantRuntimeKind.reconnecting
                  : participant.screenShareEnabled
                  ? RoomCallParticipantRuntimeKind.awaitingRemoteScreenShare
                  : participant.videoEnabled
                  ? RoomCallParticipantRuntimeKind.awaitingRemoteVideo
                  : participant.isJoined
                  ? RoomCallParticipantRuntimeKind.audioOnly
                  : RoomCallParticipantRuntimeKind.none),
          runtimeErrorMessage: runtime?.errorMessage,
          publishAudio: runtime?.publishAudio ?? participant.isJoined,
          publishVideo: runtime?.publishVideo ?? participant.videoEnabled,
          publishScreenShare:
              runtime?.publishScreenShare ?? participant.screenShareEnabled,
          showLocalPreview:
              runtime?.isSelf == true &&
              (runtime!.kind == RoomCallParticipantRuntimeKind.localPreview ||
                  runtime.kind ==
                      RoomCallParticipantRuntimeKind.localScreenSharePreview),
        );
      })
      .toList(growable: false);
  resolved.sort((a, b) {
    if (a.isSelf != b.isSelf) {
      return a.isSelf ? -1 : 1;
    }
    if (a.isJoined != b.isJoined) {
      return a.isJoined ? -1 : 1;
    }
    if (a.isReconnecting != b.isReconnecting) {
      return a.isReconnecting ? -1 : 1;
    }
    final roleCompare = a.role.sortPriority.compareTo(b.role.sortPriority);
    if (roleCompare != 0) {
      return roleCompare;
    }
    final joinedCompare = a.joinedAtMs.compareTo(b.joinedAtMs);
    if (joinedCompare != 0) {
      return joinedCompare;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return resolved;
}

_ParticipantGridSpec _participantGridSpecForCount(int count, Size size) {
  final isWide = size.width > size.height;
  if (isWide) {
    if (count <= 2) {
      return const _ParticipantGridSpec(columns: 2, targetRows: 1);
    }
    if (count <= 4) {
      return const _ParticipantGridSpec(columns: 2, targetRows: 2);
    }
    if (count <= 6) {
      return const _ParticipantGridSpec(columns: 3, targetRows: 2);
    }
    if (count <= 8) {
      return const _ParticipantGridSpec(
        columns: 4,
        targetRows: 2,
        scrollAspectRatio: 1.08,
      );
    }
    if (count <= 12) {
      return const _ParticipantGridSpec(
        columns: 4,
        targetRows: 3,
        scrollAspectRatio: 1.0,
      );
    }
    return const _ParticipantGridSpec(
      columns: 4,
      targetRows: 3,
      scrollable: true,
      scrollAspectRatio: 1.0,
    );
  }

  if (count <= 4) {
    return const _ParticipantGridSpec(columns: 2, targetRows: 2);
  }
  if (count <= 6) {
    return const _ParticipantGridSpec(columns: 2, targetRows: 3);
  }
  if (count <= 9) {
    return const _ParticipantGridSpec(
      columns: 3,
      targetRows: 3,
      scrollAspectRatio: 0.82,
    );
  }
  if (count <= 12) {
    return const _ParticipantGridSpec(
      columns: 3,
      targetRows: 4,
      scrollAspectRatio: 0.78,
    );
  }
  return const _ParticipantGridSpec(
    columns: 3,
    targetRows: 4,
    scrollable: true,
    scrollAspectRatio: 0.78,
  );
}

// Grid position is STABLE — it only depends on structural facts (joined,
// screen-sharing, join order), never on moment-to-moment activity like
// speaking or camera on/off. Reordering the grid every time someone starts
// talking is disorienting; Discord keeps tiles in place and only highlights
// the active speaker via the per-tile border (see _kCallSpeakGreen usage
// below), which is the sole "who's talking" signal in this redesign.
List<_ResolvedParticipant> _sortParticipantsForStage(
  List<_ResolvedParticipant> participants,
) {
  final sorted = List<_ResolvedParticipant>.from(participants);
  sorted.sort((a, b) {
    final priorityCompare = _participantStagePriority(
      b,
    ).compareTo(_participantStagePriority(a));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    if (a.isSelf != b.isSelf) {
      return a.isSelf ? 1 : -1;
    }
    final joinedCompare = a.joinedAtMs.compareTo(b.joinedAtMs);
    if (joinedCompare != 0) {
      return joinedCompare;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return sorted;
}

int _participantStagePriority(_ResolvedParticipant participant) {
  var score = 0;
  if (participant.isJoined) {
    score += 220;
  }
  // Screen-share is the one deliberate, infrequent event worth pinning to the
  // front — matches Discord's own "focus the presenter" behaviour.
  if (_participantHasScreenShareStatus(participant)) {
    score += 700;
  }
  if (!participant.isSelf) {
    score += 40;
  }
  if (participant.isReconnecting) {
    score -= 80;
  }
  if (participant.runtimeKind == RoomCallParticipantRuntimeKind.failed) {
    score -= 140;
  }
  return score;
}

bool _participantHasCameraStatus(_ResolvedParticipant participant) {
  switch (participant.runtimeKind) {
    case RoomCallParticipantRuntimeKind.localPreview:
    case RoomCallParticipantRuntimeKind.remoteVideo:
    case RoomCallParticipantRuntimeKind.awaitingRemoteVideo:
      return true;
    default:
      return participant.supportsVideo ||
          participant.publishVideo ||
          participant.videoEnabled ||
          participant.showLocalPreview;
  }
}

bool _participantHasScreenShareStatus(_ResolvedParticipant participant) {
  switch (participant.runtimeKind) {
    case RoomCallParticipantRuntimeKind.localScreenSharePreview:
    case RoomCallParticipantRuntimeKind.remoteScreenShare:
    case RoomCallParticipantRuntimeKind.awaitingRemoteScreenShare:
      return true;
    default:
      return participant.supportsScreenShare ||
          participant.publishScreenShare ||
          participant.screenShareEnabled;
  }
}

/// Short status text for the call meta line — ONLY for states the user needs
/// to know about (connecting, reconnecting, a real error, or waiting on
/// mic/camera permission). Every "things are working normally" branch
/// returns null: internal state-machine labels like "session authority
/// ready" or "runtime connected" are developer diagnostics, not something a
/// user should ever see in call chrome.
String? _roomMediaStatusText(BuildContext context, RoomCallRuntimeState runtimeState) {
  switch (runtimeState.phase) {
    case RoomCallRuntimePhase.idle:
      return null;
    case RoomCallRuntimePhase.bootstrapping:
      return _roomCallText(context, ru: 'Подключение…', en: 'Connecting…');
    case RoomCallRuntimePhase.failed:
      return runtimeState.errorMessage ??
          _roomCallText(
            context,
            ru: 'Не удалось подключиться',
            en: 'Couldn\'t connect',
          );
    case RoomCallRuntimePhase.bootstrapReady:
      if (runtimeState.localMedia.runtimeReconnecting) {
        return _roomCallText(
          context,
          ru: 'Переподключение…',
          en: 'Reconnecting…',
        );
      }
      switch (runtimeState.localMedia.phase) {
        case RoomCallLocalMediaPhase.acquiring:
          return _roomCallText(
            context,
            ru: 'Подготовка микрофона/камеры',
            en: 'Preparing microphone/camera',
          );
        case RoomCallLocalMediaPhase.failed:
          return runtimeState.localMedia.errorMessage ??
              _roomCallText(
                context,
                ru: 'Ошибка микрофона/камеры',
                en: 'Microphone/camera error',
              );
        case RoomCallLocalMediaPhase.idle:
        case RoomCallLocalMediaPhase.ready:
          final errorMessage = runtimeState.localMedia.errorMessage?.trim();
          if (errorMessage != null && errorMessage.isNotEmpty) {
            return errorMessage;
          }
          return null;
      }
  }
}

class _ParticipantCapabilitiesRow extends StatelessWidget {
  const _ParticipantCapabilitiesRow({
    required this.participant,
    this.alignment = MainAxisAlignment.center,
    this.compact = false,
  });

  final _ResolvedParticipant participant;
  final MainAxisAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final showMic =
        participant.isJoined ||
        participant.isReconnecting ||
        participant.publishAudio ||
        participant.isSelf;
    final cameraLive =
        participant.publishVideo ||
        participant.videoEnabled ||
        participant.runtimeKind ==
            RoomCallParticipantRuntimeKind.localPreview ||
        participant.runtimeKind == RoomCallParticipantRuntimeKind.remoteVideo ||
        participant.runtimeKind ==
            RoomCallParticipantRuntimeKind.awaitingRemoteVideo;
    final showCamera = _participantHasCameraStatus(participant);
    final screenShareLive =
        participant.publishScreenShare || participant.screenShareEnabled;
    final showScreenShare = _participantHasScreenShareStatus(participant);

    if (showMic) {
      items.add(
        _ParticipantCapabilityIcon(
          icon: participant.muted ? AppIcons.micOff : AppIcons.mic,
          active:
              participant.isJoined &&
              participant.publishAudio &&
              !participant.muted,
          compact: compact,
        ),
      );
    }
    if (showCamera) {
      items.add(
        _ParticipantCapabilityIcon(
          icon: cameraLive ? AppIcons.video : AppIcons.videoOff,
          active: cameraLive,
          compact: compact,
        ),
      );
    }
    if (showScreenShare) {
      items.add(
        _ParticipantCapabilityIcon(
          icon: screenShareLive
              ? AppIcons.screenShare
              : AppIcons.screenShareOff,
          active: screenShareLive,
          compact: compact,
        ),
      );
    }
    if (items.isEmpty) {
      return compact ? const SizedBox.shrink() : const SizedBox(height: 12);
    }
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.max,
      children: [
        for (int index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          items[index],
        ],
      ],
    );
  }
}

class _ParticipantCapabilityIcon extends StatelessWidget {
  const _ParticipantCapabilityIcon({
    required this.icon,
    required this.active,
    this.compact = false,
  });

  final IconData icon;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 18.0 : 20.0;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: active
            ? Colors.white10
            : Colors.black.withValues(alpha: compact ? 0.14 : 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: compact ? 11 : 12,
        color: active
            ? _kCallTextPrimary
            : icon == AppIcons.micOff
            ? _kCallLeaveRed
            : _kCallTextSecondary,
      ),
    );
  }
}
