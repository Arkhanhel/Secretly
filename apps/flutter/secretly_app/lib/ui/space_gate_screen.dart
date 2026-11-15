// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../security/app_security_manager.dart';
import '../security/space_gate.dart';

/// Экран PIN до старта приложения (Э2).
///
/// Намеренно не зависит от контроллера: он показывается раньше, чем тот
/// существует. Подписи берутся из общих локализаций, а язык — из системной
/// локали (своё разрешение, с откатом на английский, как в main.dart).
/// Внешне экран один и тот же для настоящего кода и кода принуждения.
class SpaceGateApp extends StatelessWidget {
  const SpaceGateApp({
    super.key,
    required this.manager,
    required this.onDecided,
  });

  final AppSecurityManager manager;
  final ValueChanged<SpaceGateDecision> onDecided;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: Color(0xFF22C55E)),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        useMaterial3: true,
      ),
      locale: _systemGateLocale(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SpaceGateScreen(manager: manager, onDecided: onDecided),
    );
  }
}

class SpaceGateScreen extends StatefulWidget {
  const SpaceGateScreen({
    super.key,
    required this.manager,
    required this.onDecided,
  });

  final AppSecurityManager manager;
  final ValueChanged<SpaceGateDecision> onDecided;

  @override
  State<SpaceGateScreen> createState() => _SpaceGateScreenState();
}

class _SpaceGateScreenState extends State<SpaceGateScreen> {
  final TextEditingController _code = TextEditingController();
  StreamSubscription<AppLockEmergency>? _emergencySub;
  Timer? _countdown;
  Duration _lockout = Duration.zero;
  bool _submitting = false;
  bool _decided = false;
  bool _biometricsAvailable = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _emergencySub = widget.manager.emergencies.listen(_onEmergency);
    unawaited(_refreshLockout());
    unawaited(_probeBiometrics());
  }

  @override
  void dispose() {
    _emergencySub?.cancel();
    _countdown?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _probeBiometrics() async {
    if (!widget.manager.canOfferBiometricUnlock(SecurityLockScope.app)) return;
    try {
      final status = await widget.manager.biometricStatus();
      if (!mounted) return;
      setState(() => _biometricsAvailable = status.isAvailable);
    } catch (_) {}
  }

  Future<void> _refreshLockout() async {
    final remaining = await widget.manager.lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockout = remaining);
    _countdown?.cancel();
    if (remaining > Duration.zero) {
      _countdown = Timer(const Duration(seconds: 1), _refreshLockout);
    }
  }

  void _onEmergency(AppLockEmergency event) {
    if (_decided) return;
    switch (event.kind) {
      case AppLockEmergencyKind.duress:
        _decide(
          SpaceGateDecision(SpaceGateOutcome.duress, wipeMain: event.wipeMain),
        );
      case AppLockEmergencyKind.wipeAll:
        _decide(const SpaceGateDecision(SpaceGateOutcome.wipeAll));
    }
  }

  void _decide(SpaceGateDecision decision) {
    if (_decided) return;
    _decided = true;
    widget.onDecided(decision);
  }

  Future<void> _submit() async {
    if (_submitting || _decided) return;
    final l10n = AppLocalizations.of(context)!;
    final code = _code.text;
    if (code.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    final result = await widget.manager.unlockApp(password: code);
    if (!mounted) return;
    switch (result.outcome) {
      case AppUnlockOutcome.unlocked:
        _decide(const SpaceGateDecision(SpaceGateOutcome.real));
        return;
      case AppUnlockOutcome.duress:
        // Решение придёт событием; экран молчит, как при верном коде.
        return;
      case AppUnlockOutcome.lockedOut:
        setState(() => _submitting = false);
        await _refreshLockout();
        return;
      case AppUnlockOutcome.failed:
        _code.clear();
        setState(() {
          _submitting = false;
          _error = l10n.spaceGateWrongCode;
        });
        await _refreshLockout();
    }
  }

  Future<void> _biometric() async {
    if (_submitting || _decided) return;
    setState(() => _submitting = true);
    final ok = await widget.manager.authenticateWithBiometrics(
      scope: SecurityLockScope.app,
      reason: AppLocalizations.of(context)!.spaceGateBiometricReason,
    );
    if (!mounted) return;
    if (ok) {
      _decide(const SpaceGateDecision(SpaceGateOutcome.real));
      return;
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lockedOut = _lockout > Duration.zero;
    final seconds = _lockout.inSeconds + (_lockout.inMilliseconds % 1000 > 0 ? 1 : 0);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n.spaceGateEnterCode,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey<String>('space_gate_code'),
                    controller: _code,
                    autofocus: true,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    enabled: !_submitting && !lockedOut,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(128),
                    ],
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 20,
                    child: Text(
                      lockedOut ? l10n.spaceGateWaitSeconds(seconds) : _error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey<String>('space_gate_submit'),
                    onPressed: _submitting || lockedOut ? null : _submit,
                    child: Text(l10n.spaceGateUnlock),
                  ),
                  if (_biometricsAvailable) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _submitting ? null : _biometric,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(l10n.spaceGateUseBiometrics),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Разрешение языка без контроллера: первый совпавший язык системы, иначе
/// английский (НЕ supportedLocales.first, как сделал бы Flutter сам).
///
/// 🔴 ВЫБРАННЫЙ ЧЕЛОВЕКОМ ЯЗЫК ЗДЕСЬ НЕДОСТУПЕН, И ЭТО НЕ УПУЩЕНИЕ. Выбор
/// языка хранится ВНУТРИ пространства профиля, а пространство на этом экране
/// ещё не выбрано: именно его и определяет введённый код. Читать настройку
/// настоящего профиля до ввода кода — значит показывать обманке след
/// настоящего профиля. Поэтому экран входа говорит на языке системы, даже
/// если в приложении выбран другой.
Locale _systemGateLocale() {
  for (final device in WidgetsBinding.instance.platformDispatcher.locales) {
    final deviceCode = device.languageCode.toLowerCase();
    final deviceCountry = device.countryCode?.toUpperCase();
    Locale? exactMatch;
    Locale? languageMatch;
    for (final candidate in AppLocalizations.supportedLocales) {
      if (candidate.languageCode.toLowerCase() != deviceCode) continue;
      if ((candidate.countryCode?.toUpperCase()) == deviceCountry) {
        exactMatch = candidate;
        break;
      }
      languageMatch ??= candidate;
    }
    final match = exactMatch ?? languageMatch;
    if (match != null) return match;
  }
  return const Locale('en');
}
