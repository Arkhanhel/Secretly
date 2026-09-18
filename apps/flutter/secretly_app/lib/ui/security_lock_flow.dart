// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../app/app_controller.dart';
import '../security/app_security_manager.dart';
import 'animations/animations.dart';
import 'app_asset_paths.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';

String _securityLockLabel(
  BuildContext context, {
  required bool useRussian,
  required String ru,
  required String en,
}) {
  if (useRussian) return ru;
  final localeTag = wave1LocaleTagFromContext(context);
  if (localeTag == 'ru') return ru;
  if (localeTag == 'en') return en;

  final l10n = context.l10n;
  String scopedSuffix(String prefix) {
    final withoutPrefix = en.substring(prefix.length);
    return withoutPrefix.endsWith('.')
        ? withoutPrefix.substring(0, withoutPrefix.length - 1)
        : withoutPrefix;
  }

  if (en.startsWith('Enter your password to open ')) {
    return l10n.securityUnlockPasswordSubtitle(
      scopedSuffix('Enter your password to open '),
    );
  }
  if (en.startsWith('Draw your pattern to access ')) {
    return l10n.securityUnlockPatternSubtitle(
      scopedSuffix('Draw your pattern to access '),
    );
  }
  if (en.startsWith('Password for ')) {
    return l10n.securityPasswordSetupTitle(
      en.substring('Password for '.length),
    );
  }
  if (en.startsWith('Pattern lock for ')) {
    return l10n.securityPatternSetupTitle(
      en.substring('Pattern lock for '.length),
    );
  }

  switch (en) {
    case 'the app':
      return l10n.securityScopeAppObject;
    case 'Personal chats':
      return l10n.securityScopePersonalObject;
    case 'Unlock the app':
      return l10n.securityUnlockAppTitle;
    case 'Unlock Personal chats':
      return l10n.securityUnlockPersonalTitle;
    case 'Fingerprint unlock starts automatically. If needed, you can use your password below.':
      return l10n.securityUnlockFingerprintAutoSubtitle;
    case 'Native biometrics start automatically first. If needed, you can use your pattern below.':
      return l10n.securityUnlockBiometricPatternAutoSubtitle;
    case 'Confirm access with native device authentication.':
      return l10n.securityUnlockNativeSubtitle;
    case 'Confirm your identity with native device authentication.':
      return l10n.securityUnlockBiometricSubtitle;
    case 'Authenticate to unlock the app':
      return l10n.securityUnlockAppBiometricReason;
    case 'Authenticate to open Personal chats':
      return l10n.securityUnlockPersonalBiometricReason;
    case 'That password did not match. Try again.':
      return l10n.securityUnlockPasswordMismatch;
    case 'That pattern did not match.':
      return l10n.securityUnlockPatternMismatch;
    case 'Native authentication was not completed.':
      return l10n.securityUnlockNativeIncomplete;
    case 'Password':
      return l10n.password;
    case 'Enter your password to continue':
      return l10n.securityPasswordContinueHint;
    case 'Use fingerprint':
      return l10n.securityUseFingerprint;
    case 'Use password':
      return l10n.securityUsePassword;
    case 'Clear pattern':
      return l10n.securityClearPattern;
    case 'Close':
      return l10n.close;
    case 'Connect at least 4 dots.':
      return l10n.securityConnectFourDots;
    case 'Use at least 4 characters.':
      return l10n.securityPasswordMinFourChars;
    case 'The passwords do not match.':
      return l10n.securityPasswordsMismatchFull;
    case 'The password is stored only in the secure device store.':
      return l10n.securityPasswordSetupDescription;
    case 'New password':
      return l10n.securityNewPassword;
    case 'Repeat password':
      return l10n.securityRepeatPassword;
    case 'Save password':
      return l10n.securitySavePassword;
    case 'Draw a pattern with at least 4 dots.':
      return l10n.securityPatternSetupInstruction;
    case 'Repeat the pattern to confirm it.':
      return l10n.securityPatternSetupRepeat;
    case 'Use at least 4 dots.':
      return l10n.securityPatternMinFourDots;
    case 'The patterns did not match. Start again.':
      return l10n.securityPatternMismatchStartOver;
    case 'Start over':
      return l10n.securityStartOver;
    default:
      return en;
  }
}

Future<bool> ensureSecurityScopeUnlocked({
  required BuildContext context,
  required AppController controller,
  required SecurityLockScope scope,
  bool forcePrompt = false,
}) async {
  final manager = controller.security;
  if (!manager.isEnabled(scope)) {
    return true;
  }
  if (!forcePrompt && !manager.isLocked(scope)) {
    return true;
  }
  final unlocked = await Navigator.of(context).push<bool>(
    SecretlyPageRoute<bool>(
      builder: (_) => SecurityUnlockScreen(
        controller: controller,
        scope: scope,
        canCancel: true,
      ),
    ),
  );
  return unlocked ?? false;
}

Future<String?> openPasswordSetupFlow({
  required BuildContext context,
  required SecurityLockScope scope,
}) {
  return Navigator.of(context).push<String>(
    SecretlyPageRoute<String>(
      builder: (_) => _PasswordSetupScreen(scope: scope),
    ),
  );
}

Future<List<int>?> openPatternSetupFlow({
  required BuildContext context,
  required SecurityLockScope scope,
}) {
  return Navigator.of(context).push<List<int>>(
    SecretlyPageRoute<List<int>>(
      builder: (_) => _PatternSetupScreen(scope: scope),
    ),
  );
}

class AppSecurityLockOverlay extends StatelessWidget {
  const AppSecurityLockOverlay({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SecurityScopeLockOverlay(
      controller: controller,
      scope: SecurityLockScope.app,
    );
  }
}

class SecurityScopeLockOverlay extends StatelessWidget {
  const SecurityScopeLockOverlay({
    super.key,
    required this.controller,
    required this.scope,
  });

  final AppController controller;
  final SecurityLockScope scope;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: _SecurityUnlockSurface(
          controller: controller,
          scope: scope,
          canCancel: false,
          onUnlocked: () {},
        ),
      ),
    );
  }
}

class SecurityUnlockScreen extends StatelessWidget {
  const SecurityUnlockScreen({
    super.key,
    required this.controller,
    required this.scope,
    required this.canCancel,
  });

  final AppController controller;
  final SecurityLockScope scope;
  final bool canCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _SecurityUnlockSurface(
        controller: controller,
        scope: scope,
        canCancel: canCancel,
        onUnlocked: () {
          if (canCancel && context.mounted) {
            Navigator.of(context).pop(true);
          }
        },
      ),
    );
  }
}

class _SecurityUnlockSurface extends StatefulWidget {
  const _SecurityUnlockSurface({
    required this.controller,
    required this.scope,
    required this.canCancel,
    required this.onUnlocked,
  });

  final AppController controller;
  final SecurityLockScope scope;
  final bool canCancel;
  final VoidCallback onUnlocked;

  @override
  State<_SecurityUnlockSurface> createState() => _SecurityUnlockSurfaceState();
}

class _SecurityUnlockSurfaceState extends State<_SecurityUnlockSurface> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  int _patternResetToken = 0;
  String _errorText = '';
  bool _submitting = false;
  bool _autoBiometricAttempted = false;

  AppSecurityManager get _manager => widget.controller.security;

  bool get _useRussian {
    return wave1LocaleIsRussian(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final config = _manager.scopeConfig(widget.scope);
      if (config.method == SecurityLockMethod.password &&
          !config.allowsBiometricUnlock) {
        _passwordFocusNode.requestFocus();
      }
      if (config.allowsBiometricUnlock) {
        _attemptBiometric(autoTriggered: true);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String _label({required String ru, required String en}) {
    return _securityLockLabel(context, useRussian: _useRussian, ru: ru, en: en);
  }

  String _scopeName(SecurityLockScope scope) {
    switch (scope) {
      case SecurityLockScope.app:
        return _label(ru: 'приложение', en: 'the app');
      case SecurityLockScope.personal:
        return _label(ru: 'Личные', en: 'Personal chats');
    }
  }

  String _title() {
    switch (widget.scope) {
      case SecurityLockScope.app:
        return _label(ru: 'Разблокируйте приложение', en: 'Unlock the app');
      case SecurityLockScope.personal:
        return _label(ru: 'Разблокируйте Личные', en: 'Unlock Personal chats');
    }
  }

  String _subtitle(SecurityScopeConfig config) {
    if (config.allowsBiometricUnlock) {
      switch (config.method) {
        case SecurityLockMethod.password:
          return _label(
            ru: 'Вход по отпечатку запускается автоматически. Если нужно, ниже можно сразу использовать пароль.',
            en: 'Fingerprint unlock starts automatically. If needed, you can use your password below.',
          );
        case SecurityLockMethod.pattern:
          return _label(
            ru: 'Сначала запускается нативная биометрия. Если нужно, ниже можно открыть экран графического ключа.',
            en: 'Native biometrics start automatically first. If needed, you can use your pattern below.',
          );
        case SecurityLockMethod.biometric:
          return _label(
            ru: 'Подтвердите вход через нативную аутентификацию устройства.',
            en: 'Confirm access with native device authentication.',
          );
        case SecurityLockMethod.none:
          return '';
      }
    }
    switch (config.method) {
      case SecurityLockMethod.password:
        return _label(
          ru: 'Введите пароль, чтобы открыть ${_scopeName(widget.scope)}.',
          en: 'Enter your password to open ${_scopeName(widget.scope)}.',
        );
      case SecurityLockMethod.pattern:
        return _label(
          ru: 'Нарисуйте графический ключ для доступа к ${_scopeName(widget.scope)}.',
          en: 'Draw your pattern to access ${_scopeName(widget.scope)}.',
        );
      case SecurityLockMethod.biometric:
        return _label(
          ru: 'Подтвердите личность через нативную биометрию устройства.',
          en: 'Confirm your identity with native device authentication.',
        );
      case SecurityLockMethod.none:
        return '';
    }
  }

  String _biometricReason() {
    switch (widget.scope) {
      case SecurityLockScope.app:
        return _label(
          ru: 'Подтвердите личность для входа в приложение',
          en: 'Authenticate to unlock the app',
        );
      case SecurityLockScope.personal:
        return _label(
          ru: 'Подтвердите личность для доступа к Личным',
          en: 'Authenticate to open Personal chats',
        );
    }
  }

  Future<void> _submitPassword() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = '';
    });
    final success = await _manager.unlockWithPassword(
      scope: widget.scope,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _errorText = success
          ? ''
          : _label(
              ru: 'Пароль не совпадает. Попробуйте еще раз.',
              en: 'That password did not match. Try again.',
            );
    });
    if (success) {
      widget.onUnlocked();
    }
  }

  Future<void> _submitPattern(List<int> pattern) async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = '';
    });
    final success = await _manager.unlockWithPattern(
      scope: widget.scope,
      pattern: pattern,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _patternResetToken += 1;
      _errorText = success
          ? ''
          : _label(
              ru: 'Графический ключ не совпадает.',
              en: 'That pattern did not match.',
            );
    });
    if (success) {
      widget.onUnlocked();
    }
  }

  Future<void> _attemptBiometric({bool autoTriggered = false}) async {
    if (_submitting) {
      return;
    }
    if (autoTriggered && _autoBiometricAttempted) {
      return;
    }
    _autoBiometricAttempted = _autoBiometricAttempted || autoTriggered;
    setState(() {
      _submitting = true;
      _errorText = '';
    });
    final success = await _manager.authenticateWithBiometrics(
      scope: widget.scope,
      reason: _biometricReason(),
    );
    if (!mounted) {
      return;
    }
    final config = _manager.scopeConfig(widget.scope);
    final showFailureState =
        !success &&
        !autoTriggered &&
        config.method == SecurityLockMethod.biometric;
    setState(() {
      _submitting = false;
      _errorText = success || !showFailureState
          ? ''
          : _label(
              ru: 'Нативная аутентификация не завершена.',
              en: 'Native authentication was not completed.',
            );
    });
    if (success) {
      widget.onUnlocked();
    }
  }

  Future<void> _handlePasswordAction() async {
    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorText = '';
      });
      _passwordFocusNode.requestFocus();
      return;
    }
    await _submitPassword();
  }

  void _clearPasswordError() {
    if (_errorText.isEmpty) {
      return;
    }
    setState(() {
      _errorText = '';
    });
  }

  Widget _buildHeroBanner(ThemeData theme, ColorScheme scheme, Size size) {
    final bannerHeight = size.width < 380 ? 172.0 : 196.0;
    return Container(
      height: bannerHeight,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.98),
            scheme.surface.withValues(alpha: 0.90),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Lottie.asset(
                AppAssetPaths.securityUnlockLottie,
                repeat: true,
                animate: true,
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.fingerprint_rounded,
                  size: 86,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, ColorScheme scheme) {
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.done,
      onChanged: (_) => _clearPasswordError(),
      onSubmitted: (_) => _handlePasswordAction(),
      decoration: InputDecoration(
        labelText: _label(ru: 'Пароль', en: 'Password'),
        hintText: _label(
          ru: 'Введите пароль для входа',
          en: 'Enter your password to continue',
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.primary),
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.66),
      ),
    );
  }

  Widget _buildActionButtonRow({
    required List<Widget> children,
    double spacing = 12,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBiometricActionButton({
    required ThemeData theme,
    required bool filled,
    String? labelOverride,
  }) {
    final child = _submitting
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.primary,
            ),
          )
        : Icon(
            Icons.fingerprint_rounded,
            size: 20,
            color: filled
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.primary,
          );
    final label = Text(
      labelOverride ?? _label(ru: 'Войти с отпечатком', en: 'Use fingerprint'),
      textAlign: TextAlign.center,
      maxLines: 2,
    );
    if (filled) {
      return FilledButton.tonalIcon(
        onPressed: _submitting ? null : _attemptBiometric,
        icon: child,
        label: label,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _submitting ? null : _attemptBiometric,
      icon: child,
      label: label,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildPasswordActionButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _submitting ? null : _handlePasswordAction,
      icon: _submitting
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              Icons.password_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
      label: Text(
        _label(ru: 'Войти с помощью пароля', en: 'Use password'),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildPasswordActions(ThemeData theme, SecurityScopeConfig config) {
    if (config.allowsBiometricUnlock) {
      return _buildActionButtonRow(
        children: [
          _buildBiometricActionButton(theme: theme, filled: true),
          _buildPasswordActionButton(theme),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _submitting ? null : _handlePasswordAction,
      icon: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.password_rounded),
      label: Text(_label(ru: 'Войти с помощью пароля', en: 'Use password')),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildPatternActions(ThemeData theme, SecurityScopeConfig config) {
    final clearButton = OutlinedButton.icon(
      onPressed: _submitting
          ? null
          : () {
              setState(() {
                _patternResetToken += 1;
                _errorText = '';
              });
            },
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(
        _label(ru: 'Сбросить ключ', en: 'Clear pattern'),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
    if (!config.allowsBiometricUnlock) {
      return clearButton;
    }
    return _buildActionButtonRow(
      children: [
        _buildBiometricActionButton(theme: theme, filled: true),
        clearButton,
      ],
    );
  }

  Widget _buildBiometricActions(ThemeData theme) {
    return _buildBiometricActionButton(theme: theme, filled: true);
  }

  Widget _buildActionSection(ThemeData theme, SecurityScopeConfig config) {
    switch (config.method) {
      case SecurityLockMethod.password:
        return _buildPasswordActions(theme, config);
      case SecurityLockMethod.pattern:
        return _buildPatternActions(theme, config);
      case SecurityLockMethod.biometric:
        return _buildBiometricActions(theme);
      case SecurityLockMethod.none:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = _manager.scopeConfig(widget.scope);
    final size = MediaQuery.sizeOf(context);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.48),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Stack(
            children: [
              if (widget.canCancel)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: _label(ru: 'Закрыть', en: 'Close'),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface.withValues(alpha: 0.82),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroBanner(theme, scheme, size),
                  const SizedBox(height: 24),
                  Text(
                    _title(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _subtitle(config),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (config.method == SecurityLockMethod.password) ...[
                    const SizedBox(height: 22),
                    _buildPasswordField(theme, scheme),
                  ],
                  if (config.method == SecurityLockMethod.pattern) ...[
                    const SizedBox(height: 22),
                    Text(
                      _label(
                        ru: 'Соедините минимум 4 точки.',
                        en: 'Connect at least 4 dots.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: PatternLockPad(
                        resetToken: _patternResetToken,
                        enabled: !_submitting,
                        onComplete: _submitPattern,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _buildActionSection(theme, config),
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: size.width < 480 ? size.width - 40 : null,
                child: body,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordSetupScreen extends StatefulWidget {
  const _PasswordSetupScreen({required this.scope});

  final SecurityLockScope scope;

  @override
  State<_PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<_PasswordSetupScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String _errorText = '';

  bool get _useRussian {
    return wave1LocaleIsRussian(context);
  }

  String _label({required String ru, required String en}) {
    return _securityLockLabel(context, useRussian: _useRussian, ru: ru, en: en);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 4) {
      setState(() {
        _errorText = _label(
          ru: 'Минимум 4 символа.',
          en: 'Use at least 4 characters.',
        );
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _errorText = _label(
          ru: 'Пароли не совпадают.',
          en: 'The passwords do not match.',
        );
      });
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeName = widget.scope == SecurityLockScope.app
        ? _label(ru: 'приложения', en: 'the app')
        : _label(ru: 'Личных', en: 'Personal chats');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _label(ru: 'Пароль для $scopeName', en: 'Password for $scopeName'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _label(
                ru: 'Пароль хранится только в защищенном хранилище устройства.',
                en: 'The password is stored only in the secure device store.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _label(ru: 'Новый пароль', en: 'New password'),
                prefixIcon: const Icon(Icons.password_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _label(
                  ru: 'Повторите пароль',
                  en: 'Repeat password',
                ),
                prefixIcon: const Icon(Icons.verified_user_rounded),
              ),
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _errorText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_label(ru: 'Сохранить пароль', en: 'Save password')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternSetupScreen extends StatefulWidget {
  const _PatternSetupScreen({required this.scope});

  final SecurityLockScope scope;

  @override
  State<_PatternSetupScreen> createState() => _PatternSetupScreenState();
}

class _PatternSetupScreenState extends State<_PatternSetupScreen> {
  List<int>? _firstPattern;
  int _resetToken = 0;
  String _errorText = '';

  bool get _useRussian {
    return wave1LocaleIsRussian(context);
  }

  String _label({required String ru, required String en}) {
    return _securityLockLabel(context, useRussian: _useRussian, ru: ru, en: en);
  }

  String get _instruction {
    if (_firstPattern == null) {
      return _label(
        ru: 'Нарисуйте графический ключ минимум из 4 точек.',
        en: 'Draw a pattern with at least 4 dots.',
      );
    }
    return _label(
      ru: 'Повторите графический ключ для подтверждения.',
      en: 'Repeat the pattern to confirm it.',
    );
  }

  Future<void> _handlePattern(List<int> pattern) async {
    if (pattern.length < 4) {
      setState(() {
        _errorText = _label(ru: 'Минимум 4 точки.', en: 'Use at least 4 dots.');
        _resetToken += 1;
      });
      return;
    }
    if (_firstPattern == null) {
      setState(() {
        _firstPattern = List<int>.from(pattern);
        _errorText = '';
        _resetToken += 1;
      });
      return;
    }
    final matches =
        _firstPattern!.length == pattern.length &&
        List.generate(
          pattern.length,
          (index) => pattern[index] == _firstPattern![index],
        ).every((matches) => matches);
    if (!matches) {
      setState(() {
        _firstPattern = null;
        _errorText = _label(
          ru: 'Ключи не совпали. Начните заново.',
          en: 'The patterns did not match. Start again.',
        );
        _resetToken += 1;
      });
      return;
    }
    Navigator.of(context).pop(pattern);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeName = widget.scope == SecurityLockScope.app
        ? _label(ru: 'приложения', en: 'the app')
        : _label(ru: 'Личных', en: 'Personal chats');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _label(
            ru: 'Графический ключ для $scopeName',
            en: 'Pattern lock for $scopeName',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_instruction, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Center(
              child: PatternLockPad(
                resetToken: _resetToken,
                onComplete: _handlePattern,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _firstPattern = null;
                  _resetToken += 1;
                  _errorText = '';
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_label(ru: 'Начать заново', en: 'Start over')),
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PatternLockPad extends StatefulWidget {
  const PatternLockPad({
    super.key,
    required this.onComplete,
    this.resetToken = 0,
    this.enabled = true,
  });

  final Future<void> Function(List<int> pattern) onComplete;
  final int resetToken;
  final bool enabled;

  @override
  State<PatternLockPad> createState() => _PatternLockPadState();
}

class _PatternLockPadState extends State<PatternLockPad> {
  final List<int> _selected = <int>[];
  final Set<int> _visited = <int>{};
  Offset? _currentPointer;
  Size _layoutSize = Size.zero;

  @override
  void didUpdateWidget(covariant PatternLockPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _clear();
    }
  }

  void _clear() {
    setState(() {
      _selected.clear();
      _visited.clear();
      _currentPointer = null;
    });
  }

  List<Offset> _points(Size size) {
    final cell = size.width / 3;
    return List<Offset>.generate(9, (index) {
      final row = index ~/ 3;
      final column = index % 3;
      return Offset((column + 0.5) * cell, (row + 0.5) * cell);
    });
  }

  int? _hitTest(Offset localPosition) {
    final points = _points(_layoutSize);
    for (var index = 0; index < points.length; index++) {
      if ((points[index] - localPosition).distance <= 34) {
        return index;
      }
    }
    return null;
  }

  int? _intermediatePoint(int from, int to) {
    final fromRow = from ~/ 3;
    final fromColumn = from % 3;
    final toRow = to ~/ 3;
    final toColumn = to % 3;
    final deltaRow = toRow - fromRow;
    final deltaColumn = toColumn - fromColumn;
    if (deltaRow.abs() == 2 && deltaColumn == 0) {
      return ((fromRow + toRow) ~/ 2) * 3 + fromColumn;
    }
    if (deltaColumn.abs() == 2 && deltaRow == 0) {
      return fromRow * 3 + ((fromColumn + toColumn) ~/ 2);
    }
    if (deltaRow.abs() == 2 && deltaColumn.abs() == 2) {
      return ((fromRow + toRow) ~/ 2) * 3 + ((fromColumn + toColumn) ~/ 2);
    }
    return null;
  }

  void _appendPoint(int index) {
    if (_visited.contains(index)) {
      return;
    }
    if (_selected.isNotEmpty) {
      final previous = _selected.last;
      final midpoint = _intermediatePoint(previous, index);
      if (midpoint != null && !_visited.contains(midpoint)) {
        _selected.add(midpoint);
        _visited.add(midpoint);
      }
    }
    HapticFeedback.selectionClick();
    _selected.add(index);
    _visited.add(index);
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enabled) {
      return;
    }
    final index = _hitTest(details.localPosition);
    setState(() {
      _selected.clear();
      _visited.clear();
      _currentPointer = details.localPosition;
      if (index != null) {
        _appendPoint(index);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }
    final index = _hitTest(details.localPosition);
    setState(() {
      _currentPointer = details.localPosition;
      if (index != null) {
        _appendPoint(index);
      }
    });
  }

  Future<void> _handlePanEnd() async {
    if (!widget.enabled) {
      return;
    }
    final pattern = List<int>.from(_selected);
    setState(() {
      _currentPointer = null;
    });
    if (pattern.isEmpty) {
      return;
    }
    await widget.onComplete(pattern);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(220.0, 320.0)
            : 280.0;
        _layoutSize = Size.square(side);
        return GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: (_) => _handlePanEnd(),
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _PatternPainter(
                colorScheme: scheme,
                selected: _selected,
                currentPointer: _currentPointer,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.colorScheme,
    required this.selected,
    required this.currentPointer,
  });

  final ColorScheme colorScheme;
  final List<int> selected;
  final Offset? currentPointer;

  @override
  void paint(Canvas canvas, Size size) {
    final points = List<Offset>.generate(9, (index) {
      final row = index ~/ 3;
      final column = index % 3;
      final cell = size.width / 3;
      return Offset((column + 0.5) * cell, (row + 0.5) * cell);
    });

    final linePaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final outerPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final innerPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    final inactiveOuter = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final inactiveInner = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.fill;

    if (selected.length >= 2) {
      for (var index = 1; index < selected.length; index++) {
        canvas.drawLine(
          points[selected[index - 1]],
          points[selected[index]],
          linePaint,
        );
      }
    }
    if (selected.isNotEmpty && currentPointer != null) {
      canvas.drawLine(points[selected.last], currentPointer!, linePaint);
    }

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final isSelected = selected.contains(index);
      canvas.drawCircle(point, 23, isSelected ? outerPaint : inactiveOuter);
      canvas.drawCircle(point, 18, inactiveInner);
      canvas.drawCircle(
        point,
        isSelected ? 8 : 6,
        isSelected ? innerPaint : inactiveOuter,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.currentPointer != currentPointer ||
        oldDelegate.colorScheme != colorScheme;
  }
}
