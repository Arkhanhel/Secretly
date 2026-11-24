// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../security/app_security_manager.dart';
import '../security/profile_space.dart';
import 'motion/app_dialogs.dart';
import 'motion/press_feedback.dart';
import 'security_duress_section.dart';
import 'social_recovery_screen.dart';
import 'animations/animations.dart';
import 'app_asset_paths.dart';
import 'l10n.dart';
import 'personal_chats_screen.dart';
import 'security_lock_flow.dart';
import 'settings_group.dart';
import 'wave1_l10n.dart';
import 'widgets/apple_menu.dart';
import 'widgets/frosted_top_bar.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';
import 'package:secretly_app/ui/apple_settings_row.dart';
import 'package:secretly_app/ui/apple_glass.dart';

Future<void> openSecuritySettings({
  required BuildContext context,
  required AppController controller,
}) {
  return Navigator.of(context).push(
    SecretlyPageRoute<void>(
      builder: (_) => SecuritySettingsScreen(controller: controller),
    ),
  );
}

Future<void> openSecurityScopeSettings({
  required BuildContext context,
  required AppController controller,
  required SecurityLockScope scope,
}) async {
  final shouldAuthenticate =
      scope == SecurityLockScope.personal &&
      controller.security.isEnabled(scope);
  if (shouldAuthenticate) {
    final unlocked = await ensureSecurityScopeUnlocked(
      context: context,
      controller: controller,
      scope: scope,
    );
    if (!unlocked || !context.mounted) {
      return;
    }
  }
  await Navigator.of(context).push(
    SecretlyPageRoute<void>(
      builder: (_) =>
          _SecurityScopeDetailScreen(controller: controller, scope: scope),
    ),
  );
}

/// Цвет раздела «Безопасность» — тот же, что у значка в главном списке.
const Color _securityAmber = Color(0xFFE0A43A);

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    return StreamBuilder<void>(
      stream: controller.security.changed,
      builder: (context, _) {
        final manager = controller.security;
        return FutureBuilder<SecurityBiometricStatus>(
          future: manager.biometricStatus(),
          builder: (context, snapshot) {
            final biometricStatus =
                snapshot.data ?? const SecurityBiometricStatus.unavailable();
            // Android (23.11.2026): те же группы строк, что на iPhone, —
            // вместо крупных карточек с плашками.
            if (settingsAndroidPanels) {
              return AppleSettingsPageTheme(
                child: Scaffold(
                  extendBodyBehindAppBar: true,
                  appBar: frostedAppBar(
                    title: Text(
                      _label(context, ru: 'Безопасность', en: 'Security'),
                    ),
                  ),
                  body: _AndroidSecurityList(
                    controller: controller,
                    manager: manager,
                    biometricStatus: biometricStatus,
                    topPad: topPad,
                    bottomPad: bottomPad,
                  ),
                ),
              );
            }
            // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: frostedAppBar(
                title: Text(
                  _label(context, ru: 'Безопасность', en: 'Security'),
                ),
              ),
              body: ListView(
                padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
                children: [
                  SettingsPageIntro(
                    icon: Image.asset(
                      '${AppAssetPaths.settingsIconsDir}/privat/w11-block.png',
                      color: _securityAmber,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    color: _securityAmber,
                    text: context.l10n.settingsIntroSecurity,
                    inset: 4,
                  ),
                  SettingsGroupHeader(
                    context.l10n.settingsGroupLock,
                    inset: 16,
                  ),
                  _SecuritySummaryCard(
                    title: _label(
                      context,
                      ru: 'Нативная аутентификация',
                      en: 'Native authentication',
                    ),
                    subtitle: _biometricLabel(context, biometricStatus),
                    trailingLabel: biometricStatus.isAvailable
                        ? _label(context, ru: 'Готово', en: 'Ready')
                        : _label(context, ru: 'Недоступно', en: 'Unavailable'),
                    icon: biometricStatus.hasFace
                        ? AdaptiveIcons.face_retouching_natural_rounded
                        : AdaptiveIcons.fingerprint_rounded,
                    description: biometricStatus.isAvailable
                        ? _label(
                            context,
                            ru: 'Используется для Face ID, отпечатка пальца и системной аутентификации устройства.',
                            en: 'Used for Face ID, fingerprint, and native device authentication.',
                          )
                        : _label(
                            context,
                            ru: 'На этом устройстве биометрия или системная аутентификация сейчас недоступны.',
                            en: 'Biometric or native device authentication is not available on this device right now.',
                          ),
                  ),
                  const SizedBox(height: 14),
                  _SecurityScopeCard(
                    title: _label(
                      context,
                      ru: 'Вход в приложение',
                      en: 'App lock',
                    ),
                    description: _label(
                      context,
                      ru: 'Блокирует вход в приложение и может срабатывать после скрытия приложения.',
                      en: 'Protects app entry and can relock after the app is hidden.',
                    ),
                    config: manager.scopeConfig(SecurityLockScope.app),
                    locked: manager.isLocked(SecurityLockScope.app),
                    onTap: () => openSecurityScopeSettings(
                      context: context,
                      controller: controller,
                      scope: SecurityLockScope.app,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SecurityScopeCard(
                    title: _label(
                      context,
                      ru: 'Личные чаты',
                      en: 'Personal chats',
                    ),
                    description: _label(
                      context,
                      ru: 'Защищает скрытую категорию Личные и вход в конкретные личные чаты.',
                      en: 'Protects the hidden Personal section and direct entry into personal chats.',
                    ),
                    config: manager.scopeConfig(SecurityLockScope.personal),
                    locked: manager.isLocked(SecurityLockScope.personal),
                    onTap: () => openSecurityScopeSettings(
                      context: context,
                      controller: controller,
                      scope: SecurityLockScope.personal,
                    ),
                  ),
                  // Перенесено из «Медиа и профиль» (макет владельца,
                  // 11.2026): вход в личную подборку стоит рядом с её
                  // защитой. Поведение прежнее — сперва проверка блокировки.
                  const SizedBox(height: 14),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(AdaptiveIcons.folder_special_rounded),
                      title: Text(context.l10n.settingsOpenPersonalChats),
                      subtitle: Text(context.l10n.settingsOpenPersonalChatsSub),
                      trailing: const Icon(AdaptiveIcons.chevron_right_rounded),
                      onTap: () async {
                        final unlocked = await ensureSecurityScopeUnlocked(
                          context: context,
                          controller: controller,
                          scope: SecurityLockScope.personal,
                        );
                        if (!context.mounted || !unlocked) return;
                        await Navigator.of(context).push(
                          SecretlyPageRoute<void>(
                            builder: (_) =>
                                PersonalChatsScreen(controller: controller),
                          ),
                        );
                      },
                    ),
                  ),
                  // Э3: социальное восстановление. В пространстве обманки
                  // не показывается — там нечего восстанавливать.
                  if (ProfileSpaceRuntime.active == ProfileSpace.main) ...[
                    SettingsGroupHeader(
                      context.l10n.settingsGroupRecovery,
                      inset: 16,
                    ),
                    SocialRecoveryEntryCard(controller: controller),
                  ],
                ],
              ),
            ),
    );
          },
        );
      },
    );
  }
}

/// Страница «Безопасность» на Android (23.11.2026, владелец: «доделай все
/// категории, половина на старом стиле»): цветные значки, название, серое
/// пояснение и значение справа — те же сведения и те же нажатия, что у
/// карточек iPhone ниже.
class _AndroidSecurityList extends StatelessWidget {
  const _AndroidSecurityList({
    required this.controller,
    required this.manager,
    required this.biometricStatus,
    required this.topPad,
    required this.bottomPad,
  });

  final AppController controller;
  final AppSecurityManager manager;
  final SecurityBiometricStatus biometricStatus;
  final double topPad;
  final double bottomPad;

  static const Color _green = Color(0xFF34C759);
  static const Color _grey = Color(0xFF8E8E93);
  static const Color _blue = Color(0xFF0A84FF);
  static const Color _indigo = Color(0xFF5E5CE6);
  static const Color _purple = Color(0xFFAF52DE);

  Widget _scopeRow(
    BuildContext context, {
    required SecurityLockScope scope,
    required String title,
    required String description,
    required IconData icon,
    required Color tint,
  }) {
    final config = manager.scopeConfig(scope);
    final locked = manager.isLocked(scope);
    // Плашки карточки iPhone — второй строкой пояснения.
    final status = !config.isEnabled
        ? _label(context, ru: 'Выключено', en: 'Off')
        : locked
        ? _label(context, ru: 'Заблокировано', en: 'Locked')
        : _label(context, ru: 'Разблокировано', en: 'Unlocked');
    final parts = <String>[
      status,
      if (config.isEnabled && config.relockOnBackground)
        config.backgroundGraceSeconds <= 0
            ? _label(context, ru: 'Сразу после скрытия', en: 'After hide')
            : _label(
                context,
                ru: 'Задержка ${config.backgroundGraceSeconds}с',
                en: 'Grace ${config.backgroundGraceSeconds}s',
              ),
    ];
    return AppleSettingsRow(
      leading: AppleRowIcon(tint: tint, icon: icon),
      title: title,
      subtitle: '$description\n${parts.join(' · ')}',
      trailing: _valueChevron(context, _modeLabel(context, config)),
      onTap: () => openSecurityScopeSettings(
        context: context,
        controller: controller,
        scope: scope,
      ),
    );
  }

  /// Значение серым и «›» — как у строки iOS со значением.
  static Widget _valueChevron(BuildContext context, String value) {
    final secondary = AppleGlass.secondaryLabel(
      Theme.of(context).brightness == Brightness.dark,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: secondary),
          ),
        ),
        const SizedBox(width: 2),
        Icon(AdaptiveIcons.chevron_right_rounded, size: 24, color: secondary),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppleGlass.secondaryLabel(
      Theme.of(context).brightness == Brightness.dark,
    );
    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      children: [
        SettingsPageIntro(
          icon: Image.asset(
            '${AppAssetPaths.settingsIconsDir}/privat/w11-block.png',
            color: _securityAmber,
            colorBlendMode: BlendMode.srcIn,
          ),
          color: _securityAmber,
          text: context.l10n.settingsIntroSecurity,
        ),
        SettingsGroupHeader(context.l10n.settingsGroupLock),
        settingsRowsGroup([
          AppleSettingsRow(
            leading: AppleRowIcon(
              tint: biometricStatus.isAvailable ? _green : _grey,
              icon: biometricStatus.hasFace
                  ? AdaptiveIcons.face_retouching_natural_rounded
                  : AdaptiveIcons.fingerprint_rounded,
            ),
            title: _label(
              context,
              ru: 'Нативная аутентификация',
              en: 'Native authentication',
            ),
            subtitle: _biometricLabel(context, biometricStatus),
            trailing: Text(
              biometricStatus.isAvailable
                  ? _label(context, ru: 'Готово', en: 'Ready')
                  : _label(context, ru: 'Недоступно', en: 'Unavailable'),
              style: TextStyle(fontSize: 15, color: secondary),
            ),
          ),
        ]),
        SettingsGroupCaption(
          biometricStatus.isAvailable
              ? _label(
                  context,
                  ru: 'Используется для Face ID, отпечатка пальца и системной аутентификации устройства.',
                  en: 'Used for Face ID, fingerprint, and native device authentication.',
                )
              : _label(
                  context,
                  ru: 'На этом устройстве биометрия или системная аутентификация сейчас недоступны.',
                  en: 'Biometric or native device authentication is not available on this device right now.',
                ),
        ),
        const SizedBox(height: 12),
        settingsRowsGroup([
          _scopeRow(
            context,
            scope: SecurityLockScope.app,
            title: _label(context, ru: 'Вход в приложение', en: 'App lock'),
            description: _label(
              context,
              ru: 'Блокирует вход в приложение и может срабатывать после скрытия приложения.',
              en: 'Protects app entry and can relock after the app is hidden.',
            ),
            icon: AdaptiveIcons.lock_rounded,
            tint: _blue,
          ),
          _scopeRow(
            context,
            scope: SecurityLockScope.personal,
            title: _label(context, ru: 'Личные чаты', en: 'Personal chats'),
            description: _label(
              context,
              ru: 'Защищает скрытую категорию Личные и вход в конкретные личные чаты.',
              en: 'Protects the hidden Personal section and direct entry into personal chats.',
            ),
            icon: AdaptiveIcons.shield_rounded,
            tint: _indigo,
          ),
          // Вход в личную подборку — рядом с её защитой, сперва проверка
          // блокировки (как у карточки iPhone).
          AppleSettingsRow(
            leading: const AppleRowIcon(
              tint: _purple,
              icon: AdaptiveIcons.folder_special_rounded,
            ),
            title: context.l10n.settingsOpenPersonalChats,
            subtitle: context.l10n.settingsOpenPersonalChatsSub,
            onTap: () async {
              final unlocked = await ensureSecurityScopeUnlocked(
                context: context,
                controller: controller,
                scope: SecurityLockScope.personal,
              );
              if (!context.mounted || !unlocked) return;
              await Navigator.of(context).push(
                SecretlyPageRoute<void>(
                  builder: (_) => PersonalChatsScreen(controller: controller),
                ),
              );
            },
          ),
        ]),
        if (ProfileSpaceRuntime.active == ProfileSpace.main) ...[
          SettingsGroupHeader(context.l10n.settingsGroupRecovery),
          SocialRecoveryEntryCard(controller: controller),
        ],
      ],
    );
  }
}

class _SecurityScopeDetailScreen extends StatefulWidget {
  const _SecurityScopeDetailScreen({
    required this.controller,
    required this.scope,
  });

  final AppController controller;
  final SecurityLockScope scope;

  @override
  State<_SecurityScopeDetailScreen> createState() =>
      _SecurityScopeDetailScreenState();
}

class _SecurityScopeDetailScreenState
    extends State<_SecurityScopeDetailScreen> {
  static const List<int> _graceOptionsSeconds = <int>[0, 15, 30, 60, 300];

  late SecurityLockMethod _selectedMethod;
  late bool _relockOnBackground;
  late int _backgroundGraceSeconds;
  late bool _allowBiometricUnlock;
  bool _saving = false;
  String _errorText = '';

  AppSecurityManager get _manager => widget.controller.security;

  @override
  void initState() {
    super.initState();
    final config = _manager.scopeConfig(widget.scope);
    _selectedMethod = config.method;
    _relockOnBackground = config.relockOnBackground;
    _backgroundGraceSeconds = config.backgroundGraceSeconds;
    _allowBiometricUnlock = config.allowBiometricUnlock;
  }

  String _label({required String ru, required String en}) {
    return _settingsLabel(context, ru: ru, en: en);
  }

  String _scopeTitle() {
    switch (widget.scope) {
      case SecurityLockScope.app:
        return _label(ru: 'Вход в приложение', en: 'App lock');
      case SecurityLockScope.personal:
        return _label(ru: 'Личные чаты', en: 'Personal chats');
    }
  }

  String _biometricReason({bool confirmation = false}) {
    switch (widget.scope) {
      case SecurityLockScope.app:
        return confirmation
            ? _label(
                ru: 'Подтвердите биометрию для включения входа в приложение',
                en: 'Authenticate to enable app lock',
              )
            : _label(
                ru: 'Подтвердите биометрию для изменения настроек безопасности',
                en: 'Authenticate to change security settings',
              );
      case SecurityLockScope.personal:
        return confirmation
            ? _label(
                ru: 'Подтвердите биометрию для защиты Личных',
                en: 'Authenticate to protect Personal chats',
              )
            : _label(
                ru: 'Подтвердите биометрию для изменения защиты Личных',
                en: 'Authenticate to change Personal chats protection',
              );
    }
  }

  SecurityScopeConfig get _editedConfig {
    return SecurityScopeConfig(
      scope: widget.scope,
      enabled: _selectedMethod != SecurityLockMethod.none,
      method: _selectedMethod,
      relockOnBackground: _relockOnBackground,
      backgroundGraceSeconds: _backgroundGraceSeconds,
      allowBiometricUnlock: _allowBiometricUnlock,
    ).normalized();
  }

  Future<void> _save(SecurityBiometricStatus biometricStatus) async {
    if (_saving) {
      return;
    }
    final current = _manager.scopeConfig(widget.scope);
    if (_selectedMethod == SecurityLockMethod.none && current.isEnabled) {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (context) => SecretlyAlertDialog(
          title: Text(
            _label(ru: 'Отключить защиту?', en: 'Turn off protection?'),
          ),
          content: Text(
            _label(
              ru: 'Доступ к этому разделу больше не будет запрашивать пароль, графический ключ или биометрию.',
              en: 'Access to this section will no longer require a password, pattern, or biometric check.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_label(ru: 'Отмена', en: 'Cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_label(ru: 'Отключить', en: 'Turn off')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _errorText = '';
    });

    try {
      switch (_selectedMethod) {
        case SecurityLockMethod.none:
          await _manager.disableLock(widget.scope);
          break;
        case SecurityLockMethod.biometric:
          if (!biometricStatus.isAvailable) {
            throw AppSecurityException(
              _label(
                ru: 'Нативная аутентификация недоступна на этом устройстве.',
                en: 'Native authentication is unavailable on this device.',
              ),
            );
          }
          final confirmed = await _manager.authenticateDevice(
            reason: _biometricReason(confirmation: true),
          );
          if (!confirmed) {
            throw AppSecurityException(
              _label(
                ru: 'Подтверждение биометрии отменено.',
                en: 'Biometric confirmation was cancelled.',
              ),
            );
          }
          await _manager.setBiometricLock(
            scope: widget.scope,
            relockOnBackground: _relockOnBackground,
            backgroundGraceSeconds: _backgroundGraceSeconds,
          );
          break;
        case SecurityLockMethod.password:
          if (current.isEnabled &&
              current.method == SecurityLockMethod.password) {
            await _manager.updateScopeConfig(_editedConfig);
          } else {
            final password = await openPasswordSetupFlow(
              context: context,
              scope: widget.scope,
            );
            if (!mounted || password == null) {
              setState(() {
                _saving = false;
              });
              return;
            }
            await _manager.setPasswordLock(
              scope: widget.scope,
              password: password,
              relockOnBackground: _relockOnBackground,
              backgroundGraceSeconds: _backgroundGraceSeconds,
              allowBiometricUnlock: _allowBiometricUnlock,
            );
          }
          break;
        case SecurityLockMethod.pattern:
          if (current.isEnabled &&
              current.method == SecurityLockMethod.pattern) {
            await _manager.updateScopeConfig(_editedConfig);
          } else {
            final pattern = await openPatternSetupFlow(
              context: context,
              scope: widget.scope,
            );
            if (!mounted || pattern == null) {
              setState(() {
                _saving = false;
              });
              return;
            }
            await _manager.setPatternLock(
              scope: widget.scope,
              pattern: pattern,
              relockOnBackground: _relockOnBackground,
              backgroundGraceSeconds: _backgroundGraceSeconds,
              allowBiometricUnlock: _allowBiometricUnlock,
            );
          }
          break;
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on AppSecurityException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = error.message;
      });
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = error.toString();
      });
      return;
    }
  }

  Future<void> _changeCredential() async {
    final current = _manager.scopeConfig(widget.scope);
    if (!current.isEnabled) {
      return;
    }
    setState(() {
      _saving = true;
      _errorText = '';
    });
    try {
      if (current.method == SecurityLockMethod.password) {
        final password = await openPasswordSetupFlow(
          context: context,
          scope: widget.scope,
        );
        if (!mounted || password == null) {
          setState(() {
            _saving = false;
          });
          return;
        }
        await _manager.setPasswordLock(
          scope: widget.scope,
          password: password,
          relockOnBackground: _relockOnBackground,
          backgroundGraceSeconds: _backgroundGraceSeconds,
          allowBiometricUnlock: _allowBiometricUnlock,
        );
      } else if (current.method == SecurityLockMethod.pattern) {
        final pattern = await openPatternSetupFlow(
          context: context,
          scope: widget.scope,
        );
        if (!mounted || pattern == null) {
          setState(() {
            _saving = false;
          });
          return;
        }
        await _manager.setPatternLock(
          scope: widget.scope,
          pattern: pattern,
          relockOnBackground: _relockOnBackground,
          backgroundGraceSeconds: _backgroundGraceSeconds,
          allowBiometricUnlock: _allowBiometricUnlock,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
    } on AppSecurityException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    return FutureBuilder<SecurityBiometricStatus>(
      future: _manager.biometricStatus(),
      builder: (context, snapshot) {
        final biometricStatus =
            snapshot.data ?? const SecurityBiometricStatus.unavailable();
        final canOfferBiometricQuickUnlock =
            biometricStatus.isAvailable &&
            (_selectedMethod == SecurityLockMethod.password ||
                _selectedMethod == SecurityLockMethod.pattern);
        if (!canOfferBiometricQuickUnlock && _allowBiometricUnlock) {
          // Don't mutate state during build — schedule the correction for
          // right after this frame so dependents actually see the change.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _allowBiometricUnlock) {
              setState(() => _allowBiometricUnlock = false);
            }
          });
        }
        // Android (23.11.2026): карточки — панели групп, как на остальных
        // страницах настроек; на iPhone — прежние карточки.
        Widget panel(Widget child) => settingsAndroidPanels
            ? AppleSettingsGroup(margin: EdgeInsets.zero, children: [child])
            : Card(child: child);
        // iPhone: строки, разделители и группы — как в «Настройках» iOS.
    return AppleSettingsPageTheme(
      child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: frostedAppBar(title: Text(_scopeTitle())),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
            children: [
              _SecuritySummaryCard(
                title: _label(ru: 'Режим защиты', en: 'Protection mode'),
                subtitle: _label(
                  ru: 'Выберите, чем блокировать доступ.',
                  en: 'Choose how access should be protected.',
                ),
                trailingLabel: null,
                icon: AdaptiveIcons.shield_rounded,
                description: _label(
                  ru: 'Пароль и графический ключ хранятся только как стойкие хэши в secure storage. Биометрия использует нативный системный экран.',
                  en: 'Passwords and patterns are stored only as strong hashes in secure storage. Biometrics use the native system prompt.',
                ),
              ),
              const SizedBox(height: 14),
              panel(
                RadioGroup<SecurityLockMethod>(
                  groupValue: _selectedMethod,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedMethod = value;
                    });
                  },
                  child: Column(
                    children: [
                      RadioListTile<SecurityLockMethod>.adaptive(
                        value: SecurityLockMethod.none,
                        title: Text(_label(ru: 'Выключено', en: 'Off')),
                        subtitle: Text(
                          _label(
                            ru: 'Доступ без дополнительной защиты.',
                            en: 'Access without extra protection.',
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      RadioListTile<SecurityLockMethod>.adaptive(
                        value: SecurityLockMethod.password,
                        title: Text(_label(ru: 'Пароль', en: 'Password')),
                        subtitle: Text(
                          _label(
                            ru: 'Собственный пароль для разблокировки.',
                            en: 'A dedicated password to unlock access.',
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      RadioListTile<SecurityLockMethod>.adaptive(
                        value: SecurityLockMethod.pattern,
                        title: Text(
                          _label(ru: 'Графический ключ', en: 'Pattern lock'),
                        ),
                        subtitle: Text(
                          _label(
                            ru: 'Рисунок из точек, как на Android.',
                            en: 'A dot pattern similar to Android lock patterns.',
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      RadioListTile<SecurityLockMethod>.adaptive(
                        value: SecurityLockMethod.biometric,
                        title: Text(_biometricLabel(context, biometricStatus)),
                        subtitle: Text(
                          _label(
                            ru: 'Нативный системный экран Face ID, отпечатка или системной аутентификации устройства.',
                            en: 'The native Face ID, fingerprint, or system device authentication prompt.',
                          ),
                        ),
                        enabled: biometricStatus.isAvailable,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              panel(
                Column(
                  children: [
                    SecretlySwitchListTile(
                      value: _relockOnBackground,
                      onChanged: _selectedMethod == SecurityLockMethod.none
                          ? null
                          : (value) {
                              setState(() {
                                _relockOnBackground = value;
                              });
                            },
                      title: Text(
                        _label(
                          ru: 'Перезапрашивать после скрытия приложения',
                          en: 'Relock after the app is hidden',
                        ),
                      ),
                      subtitle: Text(
                        _label(
                          ru: 'Если выключить, защита будет срабатывать только после полного перезапуска приложения.',
                          en: 'If disabled, protection only returns after a full app restart.',
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled:
                          _selectedMethod != SecurityLockMethod.none &&
                          _relockOnBackground,
                      title: Text(
                        _label(
                          ru: 'Задержка перед повторной блокировкой',
                          en: 'Grace period before relock',
                        ),
                      ),
                      subtitle: Text(
                        _selectedMethod == SecurityLockMethod.none ||
                                !_relockOnBackground
                            ? _label(
                                ru: 'Недоступно при выключенной автоблокировке.',
                                en: 'Unavailable while background relock is off.',
                              )
                            : _graceLabel(_backgroundGraceSeconds),
                      ),
                      trailing: AppDropdownButton<int>(
                        value:
                            _graceOptionsSeconds.contains(
                              _backgroundGraceSeconds,
                            )
                            ? _backgroundGraceSeconds
                            : 0,
                        onChanged:
                            _selectedMethod == SecurityLockMethod.none ||
                                !_relockOnBackground
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _backgroundGraceSeconds = value;
                                });
                              },
                        items: _graceOptionsSeconds
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(_graceLabel(value)),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    if (canOfferBiometricQuickUnlock) ...[
                      const Divider(height: 1),
                      SecretlySwitchListTile(
                        value: _allowBiometricUnlock,
                        onChanged: (value) {
                          setState(() {
                            _allowBiometricUnlock = value;
                          });
                        },
                        title: Text(
                          _label(
                            ru: 'Разрешить быструю разблокировку через ${biometricStatus.label(useRussian: true)}',
                            en: 'Allow quick unlock with ${_biometricLabel(context, biometricStatus)}',
                          ),
                        ),
                        subtitle: Text(
                          _label(
                            ru: 'Оставляет пароль или графический ключ как основной резервный способ.',
                            en: 'Keeps the password or pattern as the main fallback method.',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_manager.scopeConfig(widget.scope).isEnabled &&
                  (_manager.scopeConfig(widget.scope).method ==
                          SecurityLockMethod.password ||
                      _manager.scopeConfig(widget.scope).method ==
                          SecurityLockMethod.pattern)) ...[
                const SizedBox(height: 14),
                panel(
                  ListTile(
                    leading: const Icon(AdaptiveIcons.key_rounded),
                    title: Text(
                      _manager.scopeConfig(widget.scope).method ==
                              SecurityLockMethod.password
                          ? _label(ru: 'Сменить пароль', en: 'Change password')
                          : _label(
                              ru: 'Сменить графический ключ',
                              en: 'Change pattern',
                            ),
                    ),
                    subtitle: Text(
                      _label(
                        ru: 'Текущая защита обновится сразу после подтверждения нового секрета.',
                        en: 'The current protection will be updated as soon as the new secret is confirmed.',
                      ),
                    ),
                    onTap: _saving ? null : _changeCredential,
                  ),
                ),
              ],
              // Код принуждения (Э2): только основное пространство и только
              // парольный замок приложения. В обманке раздела нет.
              if (widget.scope == SecurityLockScope.app &&
                  ProfileSpaceRuntime.active == ProfileSpace.main &&
                  _manager.scopeConfig(widget.scope).isEnabled &&
                  _manager.scopeConfig(widget.scope).method ==
                      SecurityLockMethod.password) ...[
                const SizedBox(height: 14),
                SecurityDuressSection(
                  manager: _manager,
                  enabled: !_saving,
                  onError: (message) => setState(() => _errorText = message),
                ),
              ],
              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _errorText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PressFeedback(child: OutlinedButton.icon(
                      onPressed:
                          _saving ||
                              !_manager.scopeConfig(widget.scope).isEnabled
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _manager.lockNow(widget.scope);
                              if (!mounted) {
                                return;
                              }
                              messenger.showSnackBar(
                                SecretlySnackBar(
                                  content: Text(
                                    _label(
                                      ru: 'Защита активирована сразу.',
                                      en: 'Protection was activated immediately.',
                                    ),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(AdaptiveIcons.lock_clock_rounded),
                      label: Text(
                        _label(ru: 'Заблокировать сейчас', en: 'Lock now'),
                      ),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressFeedback(child: FilledButton(
                      onPressed: _saving ? null : () => _save(biometricStatus),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: SecretlySpinner(strokeWidth: 2),
                            )
                          : Text(_label(ru: 'Сохранить', en: 'Save changes')),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
      },
    );
  }

  String _graceLabel(int seconds) {
    if (seconds <= 0) {
      return _label(ru: 'Сразу', en: 'Immediately');
    }
    if (seconds < 60) {
      return _label(ru: 'Через $seconds сек', en: 'After ${seconds}s');
    }
    final minutes = seconds ~/ 60;
    return _label(ru: 'Через $minutes мин', en: 'After ${minutes}m');
  }
}

class _SecuritySummaryCard extends StatelessWidget {
  const _SecuritySummaryCard({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.icon,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String? trailingLabel;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Android (23.11.2026): строка группы со значком и пояснением под ней
    // вместо крупной карточки с плашкой.
    if (settingsAndroidPanels) {
      final secondary = AppleGlass.secondaryLabel(
        theme.brightness == Brightness.dark,
      );
      return AppleSettingsGroup(
        margin: EdgeInsets.zero,
        children: [
          AppleSettingsRow(
            leading: AppleRowIcon(tint: const Color(0xFF0A84FF), icon: icon),
            title: title,
            subtitle: subtitle,
            trailing: trailingLabel == null
                ? null
                : Text(
                    trailingLabel!,
                    style: TextStyle(fontSize: 15, color: secondary),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              description,
              style: TextStyle(fontSize: 13, height: 1.35, color: secondary),
            ),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailingLabel!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityScopeCard extends StatelessWidget {
  const _SecurityScopeCard({
    required this.title,
    required this.description,
    required this.config,
    required this.locked,
    required this.onTap,
  });

  final String title;
  final String description;
  final SecurityScopeConfig config;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = _modeLabel(context, config);
    final status = !config.isEnabled
        ? _label(context, ru: 'Выключено', en: 'Off')
        : locked
        ? _label(context, ru: 'Заблокировано', en: 'Locked')
        : _label(context, ru: 'Разблокировано', en: 'Unlocked');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(AdaptiveIcons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(label: summary),
                  _StatusPill(label: status),
                  if (config.isEnabled && config.relockOnBackground)
                    _StatusPill(
                      label: config.backgroundGraceSeconds <= 0
                          ? _label(
                              context,
                              ru: 'Сразу после скрытия',
                              en: 'After hide',
                            )
                          : _label(
                              context,
                              ru: 'Задержка ${config.backgroundGraceSeconds}с',
                              en: 'Grace ${config.backgroundGraceSeconds}s',
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _modeLabel(BuildContext context, SecurityScopeConfig config) {
  if (!config.isEnabled) {
    return _label(context, ru: 'Без защиты', en: 'No protection');
  }
  switch (config.method) {
    case SecurityLockMethod.password:
      return _label(context, ru: 'Пароль', en: 'Password');
    case SecurityLockMethod.pattern:
      return _label(context, ru: 'Графический ключ', en: 'Pattern lock');
    case SecurityLockMethod.biometric:
      return _label(context, ru: 'Нативная биометрия', en: 'Native biometrics');
    case SecurityLockMethod.none:
      return _label(context, ru: 'Без защиты', en: 'No protection');
  }
}

String _label(BuildContext context, {required String ru, required String en}) {
  return _settingsLabel(context, ru: ru, en: en);
}

String _settingsLabel(
  BuildContext context, {
  required String ru,
  required String en,
}) {
  if (_isRussian(context)) return ru;
  final localeTag = wave1LocaleTagFromContext(context);
  if (localeTag == 'en') return en;

  final l10n = context.l10n;
  if (en.startsWith('Allow quick unlock with ')) {
    return l10n.securityAllowQuickUnlockWith(
      en.substring('Allow quick unlock with '.length),
    );
  }
  if (en.startsWith('After ') && en.endsWith('s')) {
    final seconds = int.tryParse(
      en.substring('After '.length, en.length - 's'.length),
    );
    if (seconds != null) return l10n.securityGraceAfterSeconds(seconds);
  }
  if (en.startsWith('After ') && en.endsWith('m')) {
    final minutes = int.tryParse(
      en.substring('After '.length, en.length - 'm'.length),
    );
    if (minutes != null) return l10n.securityGraceAfterMinutes(minutes);
  }
  if (en.startsWith('Grace ') && en.endsWith('s')) {
    final seconds = int.tryParse(
      en.substring('Grace '.length, en.length - 's'.length),
    );
    if (seconds != null) return l10n.securityGracePill(seconds);
  }

  switch (en) {
    case 'Security':
      return l10n.securityTitle;
    case 'Native authentication':
      return l10n.securityNativeAuthentication;
    case 'Ready':
      return l10n.securityReady;
    case 'Unavailable':
      return l10n.securityUnavailable;
    case 'Used for Face ID, fingerprint, and native device authentication.':
      return l10n.securityNativeAvailableDescription;
    case 'Biometric or native device authentication is not available on this device right now.':
      return l10n.securityNativeUnavailableDescription;
    case 'App lock':
      return l10n.securityAppLockTitle;
    case 'Protects app entry and can relock after the app is hidden.':
      return l10n.securityAppLockDescription;
    case 'Personal chats':
      return l10n.securityPersonalChatsTitle;
    case 'Protects the hidden Personal section and direct entry into personal chats.':
      return l10n.securityPersonalChatsDescription;
    case 'Authenticate to enable app lock':
      return l10n.securityAuthEnableAppLockReason;
    case 'Authenticate to change security settings':
      return l10n.securityAuthChangeSettingsReason;
    case 'Authenticate to protect Personal chats':
      return l10n.securityAuthProtectPersonalReason;
    case 'Authenticate to change Personal chats protection':
      return l10n.securityAuthChangePersonalReason;
    case 'Native authentication is unavailable on this device.':
      return l10n.securityNativeUnavailableError;
    case 'Biometric confirmation was cancelled.':
      return l10n.securityBiometricCancelled;
    case 'Protection mode':
      return l10n.securityProtectionMode;
    case 'Choose how access should be protected.':
      return l10n.securityProtectionModeSubtitle;
    case 'Passwords and patterns are stored only as strong hashes in secure storage. Biometrics use the native system prompt.':
      return l10n.securityProtectionModeDescription;
    case 'Off':
      return l10n.securityProtectionOff;
    case 'Access without extra protection.':
      return l10n.securityProtectionOffDescription;
    case 'Password':
      return l10n.password;
    case 'A dedicated password to unlock access.':
      return l10n.securityPasswordModeDescription;
    case 'Pattern lock':
      return l10n.securityPatternModeTitle;
    case 'A dot pattern similar to Android lock patterns.':
      return l10n.securityPatternModeDescription;
    case 'The native Face ID, fingerprint, or system device authentication prompt.':
      return l10n.securityNativePromptDescription;
    case 'Relock after the app is hidden':
      return l10n.securityRelockAfterHidden;
    case 'If disabled, protection only returns after a full app restart.':
      return l10n.securityRelockAfterHiddenDescription;
    case 'Grace period before relock':
      return l10n.securityGracePeriod;
    case 'Unavailable while background relock is off.':
      return l10n.securityGraceUnavailable;
    case 'Keeps the password or pattern as the main fallback method.':
      return l10n.securityQuickUnlockSubtitle;
    case 'Change password':
      return l10n.securityChangePassword;
    case 'Change pattern':
      return l10n.securityChangePattern;
    case 'The current protection will be updated as soon as the new secret is confirmed.':
      return l10n.securityChangeCredentialSubtitle;
    case 'Protection was activated immediately.':
      return l10n.securityProtectionActivated;
    case 'Lock now':
      return l10n.securityLockNow;
    case 'Save changes':
      return l10n.securitySaveChanges;
    case 'Immediately':
      return l10n.securityGraceImmediately;
    case 'Locked':
      return l10n.securityStatusLocked;
    case 'Unlocked':
      return l10n.securityStatusUnlocked;
    case 'After hide':
      return l10n.securityAfterHide;
    case 'No protection':
      return l10n.securityNoProtection;
    case 'Native biometrics':
      return l10n.securityNativeBiometrics;
    default:
      return en;
  }
}

String _biometricLabel(BuildContext context, SecurityBiometricStatus status) {
  if (_isRussian(context)) {
    return status.label(useRussian: true);
  }
  final localeTag = wave1LocaleTagFromContext(context);
  if (localeTag == 'en') {
    return status.label(useRussian: false);
  }
  final l10n = context.l10n;
  if (status.hasFace && status.hasFingerprint) {
    return l10n.securityBiometricFaceFingerprint;
  }
  if (status.hasFace) {
    return 'Face ID';
  }
  if (status.hasFingerprint) {
    return l10n.securityBiometricFingerprint;
  }
  if (status.supportsDeviceCredentials || status.isSupported) {
    return l10n.securityBiometricNativeDeviceAuthentication;
  }
  return l10n.securityUnavailable;
}

bool _isRussian(BuildContext context) {
  return wave1LocaleIsRussian(context);
}
