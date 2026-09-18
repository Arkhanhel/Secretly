// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'wave1_l10n.dart';

import '../calls/call_manager.dart';
import '../calls/call_state.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/system_bottom_fade.dart';

/// Full-screen incoming-call UI (WhatsApp style).
///
/// Displayed when a remote invite arrives. Shows avatar, caller name,
/// "Incoming audio/video call" label, and Accept / Decline buttons with
/// pulse animation.
/// Фон экрана входящего звонка — сверху вниз.
const List<Color> _kVideoCallBackdrop = <Color>[
  Color(0xFF0A1929),
  Color(0xFF0D2A3E),
  Color(0xFF103948),
];
const List<Color> _kAudioCallBackdrop = <Color>[
  Color(0xFF0B3D2E),
  Color(0xFF0A2E22),
  Color(0xFF071A14),
];

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.callManager});

  final CallManager callManager;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // If the call ends while this screen is open, pop automatically.
    widget.callManager.state.addListener(_onStateChange);
  }

  void _onStateChange() {
    final phase = widget.callManager.state.value.phase;
    if (phase == CallPhase.ended || phase == CallPhase.idle) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    widget.callManager.state.removeListener(_onStateChange);
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSystemFadeVisibility(
      enabled: false,
      child: PopScope(
        canPop: false,
        child: ValueListenableBuilder<CallState>(
          valueListenable: widget.callManager.state,
          builder: (context, state, _) {
            final isVideo = state.isVideo;
            return Scaffold(
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isVideo ? _kVideoCallBackdrop : _kAudioCallBackdrop,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                    const Spacer(flex: 2),
                    // ── Encrypted badge ───────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.lock, size: 14,
                          color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.callEncryptedBadge,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ── Avatar with pulse ────────────────
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: _CallerAvatar(
                        name: state.peerName,
                        seed: state.peerProfileId,
                        avatarPath: state.peerAvatarPath,
                        // Портрет лежит на середине градиента.
                        backdrop: (isVideo
                            ? _kVideoCallBackdrop
                            : _kAudioCallBackdrop)[1],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── Caller name ──────────────────────
                    Text(
                      state.peerName.trim().isNotEmpty
                          ? state.peerName
                          : wave1Text(
                              context,
                              ru: 'Входящий звонок',
                              en: 'Incoming call',
                              uk: 'Вхідний дзвінок',
                              es: 'Llamada entrante',
                              pt: 'Chamada recebida',
                              ptBr: 'Chamada recebida',
                              fr: 'Appel entrant',
                              de: 'Eingehender Anruf',
                            ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Call type label ──────────────────
                    Text(
                      isVideo ? l10n.incomingVideoCall : l10n.incomingVoiceCall,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(flex: 3),
                    // ── Action buttons ───────────────────
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _slideCtrl,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ActionButton(
                              icon: AppIcons.callEnd,
                              label: l10n.callDecline,
                              color: const Color(0xFFE53935),
                              onTap: () => widget.callManager.declineIncoming(),
                            ),
                            _ActionButton(
                              icon: isVideo
                                  ? AppIcons.video
                                  : AppIcons.call,
                              label: l10n.accept,
                              color: const Color(0xFF4CAF50),
                              onTap: () => widget.callManager.acceptIncoming(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Avatar circle (letter fallback when no photo)
// ═══════════════════════════════════════════════════════════════════════════

class _CallerAvatar extends StatelessWidget {
  const _CallerAvatar({
    required this.name,
    required this.seed,
    required this.backdrop,
    this.avatarPath,
  });

  final String name;

  /// Ключ цвета заглушки — профиль звонящего, тот же, что в списке чатов.
  final String seed;

  /// Цвет экрана под портретом: экран звонка тёмный в любой теме.
  final Color backdrop;

  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    const double size = 120;

    Widget avatar;
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.file(
          File(avatarPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterCircle(context, size),
        ),
      );
    } else {
      avatar = _letterCircle(context, size);
    }

    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      child: avatar,
    );
  }

  // 🔴 ЗАГЛУШКА — ОБЩАЯ С ОСТАЛЬНЫМ ПРИЛОЖЕНИЕМ И С КОМПЬЮТЕРОМ (17.09.2026).
  //
  // Здесь был свой оттенок из `name.hashCode` и одна буква `name[0]`. Цвет не
  // совпадал с тем, каким этот человек нарисован в списке чатов, а имя,
  // начинающееся с эмодзи, резалось посреди символа: половина суррогатной
  // пары не рисуется, и вместо буквы выходил пустой серый прямоугольник.
  // Теперь ключ, буквы ([AvatarInitials.label]) и цвета — те же, что везде.
  Widget _letterCircle(BuildContext context, double size) =>
      AvatarInitials.fallbackBubble(
        context: context,
        radius: size / 2,
        seed: seed.trim().isNotEmpty ? seed.trim() : name,
        displayName: name,
        background: backdrop,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//   Single action button (decline / accept)
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
