// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../primitives/desktop_button.dart';
import '../services/desktop_app_lock_service.dart';

/// Full-screen lock overlay shown over the entire desktop shell while
/// [DesktopAppLockService.locked] is true. Auto-prompts Touch ID once on
/// mount and exposes a manual unlock button as a retry path.
class DesktopLockOverlay extends StatefulWidget {
  const DesktopLockOverlay({super.key, required this.service});

  final DesktopAppLockService service;

  @override
  State<DesktopLockOverlay> createState() => _DesktopLockOverlayState();
}

class _DesktopLockOverlayState extends State<DesktopLockOverlay> {
  bool _busy = false;
  String? _error;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoPrompted) {
        _autoPrompted = true;
        unawaited(_unlock());
      }
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.service.requestUnlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        // F-17: tell the truth about WHY. A missing platform authenticator is
        // not a failed attempt, and repeating "could not verify" would send
        // the user in circles retrying something that can never succeed.
        // Advice must be actionable from where the user is STANDING. This
        // screen is a locked overlay: settings, and therefore the support
        // chat, are behind the very lock that is failing. Pointing at support
        // from here would send someone in a circle, so the way out named here
        // is the phone — which is reachable. The lock itself is NOT shared
        // with the phone (it lives in this computer's preferences), so the
        // phone is a way to reach support, not a switch (17.09.2026).
        _error = widget.service.unlockUnavailable.value
            ? 'Служба проверки личности недоступна на этом компьютере. '
                'Перезапустите Secretly или компьютер. Если не поможет — '
                'напишите в поддержку с телефона.'
            : 'Не удалось подтвердить личность.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final supported = widget.service.biometricSupported.value;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.bg.withValues(alpha: 0.85),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(DSpace.xl2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: c.elevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.borderSubtle),
                    ),
                    child: Icon(
                      FluentIcons.lock_closed_24_regular,
                      size: 30,
                      color: c.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: DSpace.xl),
                  Text(
                    'Secretly заблокирован',
                    style: DType.title.copyWith(color: c.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DSpace.s),
                  Text(
                    supported
                        ? 'Подтвердите личность через Touch ID, чтобы продолжить.'
                        : 'Подтвердите паролем устройства, чтобы продолжить.',
                    textAlign: TextAlign.center,
                    style: DType.body.copyWith(color: c.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: DSpace.m),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: DType.caption.copyWith(color: c.danger),
                    ),
                  ],
                  const SizedBox(height: DSpace.xl2),
                  DesktopButton(
                    label: _busy ? 'Ожидаем подтверждения…' : 'Разблокировать',
                    kind: DButtonKind.tonal,
                    // E13: never gate unlock on biometric support — requestUnlock
                    // uses biometricOnly:false, so it falls back to the device
                    // password. Disabling this when Touch ID is absent locked the
                    // user out of their own app with no recourse.
                    onPressed: _busy ? null : _unlock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
