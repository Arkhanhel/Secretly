// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../security/backup_password_policy.dart';
import '../../../version/app_package_info.dart';
import '../../../calls/call_manager.dart';
import '../../../entitlements/cosmetic_catalog.dart' show kFreeBubbleStyleIds;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../storage/cache_manager.dart';
import '../app/desktop_offline_lock.dart';
import '../../../sync/peer_history_service.dart';
import '../../../security/app_security_manager.dart'
    show AppSecurityManager, SecurityLockMethod, SecurityLockScope;
import '../../chat_wallpapers.dart';
import '../../../l10n/app_localizations.dart';
import '../../security_lock_flow.dart' show ensureSecurityScopeUnlocked;
import '../../theme_presets.dart';
import '../app/desktop_app_view_model.dart';
import '../app/desktop_selector.dart';
import 'accent_color_picker.dart';
import '../design/theme_bridge.dart';
import '../design/tokens.dart';
import 'media_devices_pane.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/hover_listener.dart';
import '../primitives/desktop_text_field.dart';
import '../../recovery_kit_screen.dart';
import '../../widgets/support_badge.dart';
import '../services/desktop_app_lock_service.dart';
import '../services/desktop_notification_service.dart';
import '../primitives/desktop_segmented.dart';
import '../primitives/desktop_tooltip.dart';
import '../services/desktop_ui_prefs.dart';
import '../app/desktop_media_send.dart' show pickDesktopAttachments;
import '../shell/shortcuts_help.dart' show ShortcutsList;
import 'support_attachment.dart';
import 'support_sent.dart';
import 'workspace_layout.dart';

/// Settings workspace — INLINE in the content pane, NOT a modal.
/// Sections on the left, content on the right (Telegram desktop pattern).
///
/// [controller] is optional: when null (demo build), the devices pane shows
/// mock data; when present (production desktop), it lists real device IDs
/// from the keys server via [AppController.listMyDeviceIds].
/// Выход из аккаунта — ОДИН путь на всё окно.
///
/// 🔴 ПУТЕЙ БЫЛО ДВА, И КАЖДЫЙ ЗНАЛ ПОЛОВИНУ ПРАВДЫ.
///
/// «Сессии и устройства» спрашивали материальным `AlertDialog` («Выйти из
/// аккаунта на этом устройстве?») и — единственные — не давали выйти во время
/// звонка. «Аккаунт» спрашивал своим `DesktopDialog` («Выйти из аккаунта?») с
/// красной кнопкой, но про идущий звонок не знал ничего. Два текста об одном
/// необратимом действии — это два разных обещания, и человек не мог знать,
/// какое из них выполнится.
///
/// Здесь оба собраны вместе: вид окна свой (а не материальный), кнопка
/// красная, и проверка звонка сохранена — выходить посреди разговора нельзя.
Future<void> showSignOutDialog(
  BuildContext context,
  AppController controller,
) async {
  final l10n = AppLocalizations.of(context)!;
  final cm = CallManager.instance;
  if (cm != null && cm.state.value.isActive) {
    DesktopSnackbar.show(
      context,
      message: l10n.desktopSettingsEndCallFirst,
      kind: DSnackKind.info,
    );
    return;
  }
  final c = DColors.of(context);
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.desktopSettingsSignOutTitle,
    size: DDialogSize.small,
    body: Text(
      l10n.desktopSettingsSignOutBody,
      style: DType.body.copyWith(color: c.textSecondary),
    ),
    primary: DDialogAction(
      label: l10n.desktopSettingsSignOut,
      kind: DButtonKind.danger,
      onPressed: () => Navigator.of(context).maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => Navigator.of(context).maybePop(false),
    ),
  );
  if (ok != true) return;
  if (!context.mounted) return;
  try {
    await controller.resetProfileAndLocalData();
  } catch (e) {
    if (!context.mounted) return;
    DesktopSnackbar.show(
      context,
      message: l10n.desktopSettingsSignOutFailed('$e'),
      kind: DSnackKind.error,
    );
  }
}

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({
    super.key,
    this.onClose,
    this.vm,
    this.lockService,
    this.onOpenProfile,
    this.initialSectionId,
  });
  final VoidCallback? onClose;

  /// Открыть страницу профиля. `null` — строка «Имя, фото, статус» не
  /// рисуется вовсе.
  ///
  /// 🔴 Раньше она была и вела в НИКУДА: нажатие показывало всплывашку
  /// «Профиль — в левом нижнем углу, рядом с аватаром». Интерфейс объяснял
  /// словами то, что должно быть нажатием; строка с шевроном, которая ничего
  /// не открывает, учит не верить шевронам.
  final VoidCallback? onOpenProfile;

  /// Открыть настройки сразу на этом разделе (например 'devices').
  final String? initialSectionId;

  /// The controller seam. Null in the demo configuration, where panes fall
  /// back to mock data — see [DesktopAppViewModel].
  final DesktopAppViewModel? vm;
  final DesktopAppLockService? lockService;

  @override
  Widget build(BuildContext context) {
    final controller = vm?.controller;
    final sections = _sections(context, controller);
    final wanted = (initialSectionId ?? '').trim();
    final initial = wanted.isEmpty
        ? 0
        : sections.indexWhere((s) => s.id == wanted).clamp(0, sections.length - 1);
    return WorkspaceLayout(
      title: AppLocalizations.of(context)!.desktopSettingsTitle,
      onClose: onClose,
      initialIndex: initial < 0 ? 0 : initial,
      sections: sections,
      // 🔴 Единственный выход из аккаунта — здесь, внизу боковой колонки, как
      // в макете. Раньше он жил в двух разных панелях с разными текстами
      // подтверждения; см. [showSignOutDialog].
      footer: controller == null
          ? null
          : _SignOutRow(controller: controller),
    );
  }

  /// Слова для поиска по настройкам приходят из переводов одной строкой
  /// через запятую: держать в языковых файлах СПИСОК на каждый раздел —
  /// значит завести сотню ключей там, где хватает семнадцати.
  static List<String> _keywords(String csv) => <String>[
    for (final w in csv.split(',')) if (w.trim().isNotEmpty) w.trim(),
  ];

  List<WorkspaceSection> _sections(BuildContext context, dynamic controller) {
    final vm = this.vm;
    final l10n = AppLocalizations.of(context)!;
    return [
        // ── Приложение ───────────────────────────────────────────────
        WorkspaceSection(
          id: 'general',
          icon: FluentIcons.settings_24_regular,
          label: l10n.desktopSettingsGeneralLabel,
          subtitle: l10n.desktopSettingsGeneralSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsGeneralKeywords),
          builder: (ctx) => _GeneralPane(controller: controller),
        ),
        WorkspaceSection(
          id: 'appearance',
          icon: FluentIcons.color_24_regular,
          label: l10n.desktopSettingsAppearanceLabel,
          subtitle: l10n.desktopSettingsAppearanceSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsAppearanceKeywords),
          builder: (ctx) => _AppearancePane(vm: vm),
        ),
        // 🔴 Справка о клавишах была доступна ТОЛЬКО комбинацией Cmd+/ — то
        // есть её видел лишь тот, кто эту комбинацию уже знает. Справка,
        // спрятанная за тем, что она объясняет. Тот же список теперь есть
        // разделом настроек; окно по Cmd+/ никуда не делось и рисует его же.
        WorkspaceSection(
          id: 'shortcuts',
          icon: FluentIcons.keyboard_24_regular,
          label: l10n.desktopSettingsShortcutsLabel,
          subtitle: l10n.desktopSettingsShortcutsSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsShortcutsKeywords),
          builder: (ctx) => const _ShortcutsPane(),
        ),
        WorkspaceSection(
          id: 'power',
          icon: FluentIcons.flash_24_regular,
          label: l10n.desktopSettingsPowerLabel,
          subtitle: l10n.desktopSettingsPowerSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsPowerKeywords),
          builder: (ctx) => _PowerPane(vm: vm),
        ),
        WorkspaceSection(
          id: 'notifications',
          icon: FluentIcons.alert_24_regular,
          label: l10n.desktopSettingsNotificationsLabel,
          subtitle: l10n.desktopSettingsNotificationsSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsNotificationsKeywords),
          builder: (ctx) => const _NotificationsPane(),
        ),
        WorkspaceSection(
          id: 'calls',
          icon: FluentIcons.call_24_regular,
          label: l10n.desktopSettingsCallsLabel,
          subtitle: l10n.desktopSettingsCallsSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsCallsKeywords),
          builder: (ctx) => _CallsPane(vm: vm),
        ),
        // ◆ «ЗВУК И ВИДЕО» ИЗ МАКЕТА. Раздела не было, и причина была верной:
        // до 15.09.2026 движок не умел перечислять устройства, и пункт вышел
        // бы мёртвой панелью. Теперь умеет.
        WorkspaceSection(
          id: 'media',
          icon: FluentIcons.mic_24_regular,
          label: l10n.desktopSettingsMediaLabel,
          subtitle: l10n.desktopSettingsMediaSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsMediaKeywords),
          builder: (ctx) =>
              MediaDevicesPane(body: (children) => _PaneScaffold(children: children)),
        ),

        // ── Приватность и безопасность ───────────────────────────────
        WorkspaceSection(
          id: 'privacy',
          icon: FluentIcons.eye_24_regular,
          label: l10n.desktopSettingsPrivacyLabel,
          subtitle: l10n.desktopSettingsPrivacySubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsPrivacyKeywords),
          builder: (ctx) => _PrivacyPane(lockService: lockService, vm: vm),
        ),
        WorkspaceSection(
          id: 'security',
          icon: FluentIcons.shield_keyhole_24_regular,
          label: l10n.desktopSettingsSecurityLabel,
          subtitle: l10n.desktopSettingsSecuritySubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsSecurityKeywords),
          builder: (ctx) => _SecurityPane(vm: vm, lockService: lockService),
        ),
        WorkspaceSection(
          id: 'backup',
          icon: FluentIcons.cloud_arrow_up_24_regular,
          label: l10n.desktopSettingsBackupLabel,
          subtitle: l10n.desktopSettingsBackupSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsBackupKeywords),
          builder: (ctx) {
            final model = vm;
            return model == null
                ? const _PaneScaffold(children: [])
                : _BackupPane(vm: model);
          },
        ),
        WorkspaceSection(
          id: 'blocked',
          icon: FluentIcons.person_prohibited_24_regular,
          label: l10n.desktopSettingsBlockedLabel,
          subtitle: l10n.desktopSettingsBlockedSubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsBlockedKeywords),
          builder: (ctx) {
            final model = vm;
            return model == null
                ? const _PaneScaffold(children: [])
                : _BlockedPane(vm: model);
          },
        ),
        WorkspaceSection(
          id: 'devices',
          icon: FluentIcons.phone_laptop_24_regular,
          label: l10n.desktopSettingsDevicesLabel,
          subtitle: l10n.desktopSettingsDevicesSubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsDevicesKeywords),
          builder: (ctx) => _DevicesPane(controller: controller, vm: vm),
        ),

        // ── Аккаунт и данные ─────────────────────────────────────────
        WorkspaceSection(
          id: 'account',
          icon: FluentIcons.person_24_regular,
          label: l10n.desktopSettingsAccountLabel,
          subtitle: l10n.desktopSettingsAccountSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsAccountKeywords),
          builder: (ctx) => _AccountPane(vm: vm, onOpenProfile: onOpenProfile),
        ),
        WorkspaceSection(
          id: 'storage',
          icon: FluentIcons.database_24_regular,
          label: l10n.desktopSettingsStorageLabel,
          subtitle: l10n.desktopSettingsStorageSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsStorageKeywords),
          builder: (ctx) => const _StoragePane(),
        ),
        WorkspaceSection(
          id: 'support',
          icon: FluentIcons.chat_help_24_regular,
          label: l10n.desktopSettingsSupportLabel,
          subtitle: l10n.desktopSettingsSupportSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsSupportKeywords),
          trailing: controller == null
              ? null
              : SupportBadgeListener(controller: controller!, compact: true),
          builder: (ctx) {
            final ctrl = controller;
            return ctrl == null
                ? const _PaneScaffold(children: [])
                : _SupportPane(controller: ctrl);
          },
        ),
        WorkspaceSection(
          id: 'about',
          icon: FluentIcons.info_24_regular,
          label: l10n.desktopSettingsAboutLabel,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsAboutKeywords),
          builder: (ctx) => const _AboutPane(),
        ),
        WorkspaceSection(
          id: 'danger',
          icon: FluentIcons.delete_24_regular,
          label: l10n.desktopSettingsDangerLabel,
          // PR-F (bug 23): the danger pane was stateless and had no
          // `AppController` reference, so the "Удалить аккаунт" button was a
          // no-op (`onPressed: () {}`). Inject the controller so the new
          // stateful pane can call `deleteAccountEverywhere()`.
          builder: (ctx) => _DangerPane(controller: controller),
          dangerous: true,
        ),
    ];
  }
}

/// Красная строка «Выйти», прижатая к низу боковой колонки настроек.
class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return HoverListener(
      onTap: () => unawaited(showSignOutDialog(context, controller)),
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        margin: const EdgeInsets.fromLTRB(DSpace.s, DSpace.s, DSpace.s, DSpace.m),
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.s,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: hovered || pressed
              ? c.danger.withValues(alpha: pressed ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DRadii.sm),
        ),
        child: Row(
          children: [
            Icon(FluentIcons.sign_out_24_regular, size: 18, color: c.danger),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Text(
                l10n.desktopSettingsSignOut,
                style: DType.label.copyWith(
                  color: c.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Зелёная плашка «активно» у СВОЕГО устройства в списке.
///
/// В макете она стоит там, где у чужих устройств кнопка «Отключить»: место
/// одно, и по тому, что в нём лежит, видно, своя это строка или чужая.
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.desktopSettingsActive,
            style: DType.tiny.copyWith(
              fontWeight: FontWeight.w700,
              color: HSLColor.fromColor(c.success).withLightness(0.72).toColor(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneScaffold extends StatelessWidget {
  const _PaneScaffold({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DSpace.xl,
        DSpace.l,
        DSpace.xl,
        DSpace.xl,
      ),
      children: children,
    );
  }
}

class _GeneralPane extends StatefulWidget {
  const _GeneralPane({this.controller});
  final AppController? controller;
  @override
  State<_GeneralPane> createState() => _GeneralPaneState();
}

/// General settings.
///
/// Every row here used to be a dead affordance: the two switches wrote to a
/// local `bool` that nothing read and that reset on restart, and the language
/// row swapped its own caption between «Русский» and «English» **without
/// changing the app language** — the worst kind, because it looked like it
/// worked.
///
/// What survives now persists and takes effect. Two rows were removed rather
/// than left lying: launch-at-login needs a platform package that is not a
/// dependency, and Flutter's spell check is Android/iOS only, so neither could
/// be honoured on macOS today.
class _GeneralPaneState extends State<_GeneralPane> {
  /// Interface languages, in the order they are offered. Keys are the
  /// controller's locale-preference format; '' means "follow the system".
  ///
  /// 🔴 НАЗВАНИЯ ЯЗЫКОВ НЕ ПЕРЕВОДЯТСЯ. «Deutsch» остаётся «Deutsch» на любом
  /// языке окна: человек ищет СВОЙ язык в списке и узнаёт его по родному
  /// написанию, а не по переводу. Пустая подпись — «как в системе», её и
  /// переводим.
  static const List<({String pref, String label})> _languages = [
    (pref: '', label: ''),
    (pref: 'ru', label: 'Русский'),
    (pref: 'en', label: 'English'),
    (pref: 'uk', label: 'Українська'),
    (pref: 'de', label: 'Deutsch'),
    (pref: 'es', label: 'Español'),
    (pref: 'fr', label: 'Français'),
    (pref: 'pt', label: 'Português'),
    (pref: 'pt_BR', label: 'Português (Brasil)'),
  ];

  /// Подпись выбранного языка. Пустая в списке — «как в системе»: её берём из
  /// переводов, остальные остаются самоназваниями.
  String _labelForPref(String pref, AppLocalizations l10n) {
    for (final l in _languages) {
      if (l.pref == pref) {
        return l.label.isEmpty ? l10n.desktopGeneralSystemLanguage : l.label;
      }
    }
    return l10n.desktopGeneralSystemLanguage;
  }

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    if (ctrl == null) return;
    final current = ctrl.appLocalePreference;
    final picked = await DesktopDialog.show<String>(
      context,
      title: l10n.desktopGeneralInterfaceLanguage,
      size: DDialogSize.small,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in _languages)
            Padding(
              padding: const EdgeInsets.only(bottom: DSpace.xs),
              child: DesktopButton(
                label: l.label.isEmpty
                    ? l10n.desktopGeneralSystemLanguage
                    : l.label,
                kind: l.pref == current
                    ? DButtonKind.filled
                    : DButtonKind.tonal,
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(l.pref),
              ),
            ),
        ],
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    if (picked == null || !mounted) return;
    // The controller persists it and fires `changed`, which rebuilds the app
    // with the new locale — the same path mobile settings use.
    await ctrl.setAppLocalePreference(picked);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopGeneralBehaviour,
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: DesktopUiPrefs.enterToSend,
                builder: (ctx, enterToSend, _) => WorkspaceRow(
                  label: l10n.desktopGeneralEnterSends,
                  description: enterToSend
                      ? l10n.desktopGeneralShiftEnterNewline
                      : l10n.desktopGeneralEnterNewline,
                  trailing: WorkspaceSwitch(
                    value: enterToSend,
                    onChanged: (v) =>
                        unawaited(DesktopUiPrefs.setEnterToSend(v)),
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: DesktopUiPrefs.messageHoverBar,
                builder: (ctx, on, _) => WorkspaceRow(
                  label: l10n.desktopGeneralHoverMenu,
                  description: on
                      ? l10n.desktopGeneralHoverMenuOn
                      : l10n.desktopGeneralHoverMenuOff,
                  trailing: WorkspaceSwitch(
                    value: on,
                    onChanged: (v) =>
                        unawaited(DesktopUiPrefs.setMessageHoverBar(v)),
                  ),
                ),
              ),
              // Карточку ссылки готовит отправитель — значит, страницу
              // открывает это окно. Выключатель, как в Signal.
              ValueListenableBuilder<bool>(
                valueListenable: DesktopUiPrefs.linkPreviews,
                builder: (ctx, on, _) => WorkspaceRow(
                  label: l10n.desktopGeneralLinkPreviews,
                  description: on
                      ? l10n.desktopGeneralLinkPreviewsOn
                      : l10n.desktopGeneralLinkPreviewsOff,
                  trailing: WorkspaceSwitch(
                    value: on,
                    onChanged: (v) =>
                        unawaited(DesktopUiPrefs.setLinkPreviews(v)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // D-1: hidden until the desktop strings are actually translated.
        //
        // The picker itself works — it calls setAppLocalePreference and the
        // app rebuilds in the chosen locale. The problem is there is nothing
        // to translate: the desktop tree carries ~800 hardcoded Russian
        // literals against 4 l10n lookups, so choosing English produced an
        // English "Cancel" button inside an entirely Russian app. Offering the
        // choice was worse than not offering it — it looked like it worked.
        //
        // Flip [kDesktopUiLocalized] once the strings are in ARB (TZ §5, L-2
        // and L-3) and this row comes back with nothing else to change.
        if (ctrl != null && kDesktopUiLocalized)
          WorkspaceCard(
            title: l10n.desktopGeneralInterfaceLanguage,
            child: WorkspaceRow(
              label: _labelForPref(ctrl.appLocalePreference, l10n),
              description: l10n.desktopGeneralAppliesAtOnce,
              icon: FluentIcons.local_language_24_regular,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => unawaited(_pickLanguage()),
            ),
          ),
      ],
    );
  }
}

/// Energy settings — the desktop counterpart of mobile's Power screen.
///
/// Desktop deliberately has no glass bubbles or frosted panels (the flat design
/// decision), so the one toggle that carries over is the expensive one:
/// animated premium frames and emoji statuses. It is a shared controller
/// preference, so turning it off here turns it off on the phone too.
class _PowerPane extends StatefulWidget {
  const _PowerPane({this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;
  AppController? get controller => vm?.controller;
  @override
  State<_PowerPane> createState() => _PowerPaneState();
}

class _PowerPaneState extends State<_PowerPane> {
  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    final c = DColors.of(context);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopPowerAnimations,
          description: l10n.desktopPowerAnimationsHint,
          child: Column(
            children: [
              WorkspaceRow(
                label: l10n.desktopPowerFramesTitle,
                description: l10n.desktopPowerFramesHint,
                trailing: WorkspaceSwitch(
                  value: ctrl?.peerCosmeticAnimEnabled ?? true,
                  onChanged: (v) {
                    if (ctrl == null) return;
                    unawaited(ctrl.setPeerCosmeticAnimEnabled(v));
                  },
                ),
              ),
              // The remaining two are shared with mobile and are honoured by
              // shared widgets. Desktop is flat by design, so they change
              // little here — but they are the SAME profile preference, and
              // hiding them would silently desync the phone.
              WorkspaceRow(
                label: l10n.desktopPowerGlassBubbles,
                description: l10n.desktopPowerGlassBubblesHint,
                trailing: WorkspaceSwitch(
                  value: ctrl?.bubbleGlassEnabled ?? true,
                  onChanged: (v) {
                    if (ctrl == null) return;
                    unawaited(ctrl.setBubbleGlassEnabled(v));
                  },
                ),
              ),
              WorkspaceRow(
                label: l10n.desktopPowerMattePanels,
                description: l10n.desktopPowerMattePanelsHint,
                trailing: WorkspaceSwitch(
                  value: ctrl?.frostedPanelsEnabled ?? true,
                  onChanged: (v) {
                    if (ctrl == null) return;
                    unawaited(ctrl.setFrostedPanelsEnabled(v));
                  },
                ),
              ),
            ],
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopPowerNotAffectedTitle,
          child: Text(
            l10n.desktopPowerNotAffectedHint,
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _AppearancePane extends StatefulWidget {
  const _AppearancePane({this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;
  AppController? get controller => vm?.controller;
  @override
  State<_AppearancePane> createState() => _AppearancePaneState();
}

class _AppearancePaneState extends State<_AppearancePane> {
  static String _animModeLabel(ChatWallpaperAnimMode m, AppLocalizations l10n) {
    switch (m) {
      case ChatWallpaperAnimMode.continuous:
        return l10n.desktopWallAnimContinuous;
      case ChatWallpaperAnimMode.onEnter:
        return l10n.desktopWallAnimOnEnter;
      case ChatWallpaperAnimMode.tap:
        return l10n.desktopWallAnimTap;
      case ChatWallpaperAnimMode.off:
        return l10n.desktopWallAnimOff;
    }
  }

  /// Wallpaper choices, DERIVED from the shared catalogue.
  ///
  /// This used to be a hand-written list of six. The catalogue ships ten
  /// (five dark, five light) and is the same list mobile offers, so a
  /// hardcoded copy meant desktop silently lacked four wallpapers and would
  /// have missed any future addition. Names come from the basename so a new
  /// asset needs no desktop edit at all.
  /// 🔴 НАЗВАНИЯ ОБОЕВ ПЕРЕВОДЯТСЯ — в отличие от названий языков. «Слива» и
  /// «Бирюза» описывают ЦВЕТ, и человеку, который не читает по-русски, они не
  /// говорят ничего; «Deutsch» же на любом языке остаётся «Deutsch».
  static String _wallpaperTitle(String basename, AppLocalizations l10n) {
    switch (basename) {
      case 'wallpaper_dark_navy.jpg':
        return l10n.desktopWallpaperNavy;
      case 'wallpaper_dark_graphite.jpg':
        return l10n.desktopWallpaperGraphite;
      case 'wallpaper_dark_teal.jpg':
        return l10n.desktopWallpaperTeal;
      case 'wallpaper_dark_plum.jpg':
        return l10n.desktopWallpaperPlum;
      case 'wallpaper_dark_wine.jpg':
        return l10n.desktopWallpaperWine;
      case 'wallpaper_light_mint.jpg':
        return l10n.desktopWallpaperMint;
      case 'wallpaper_light_lavender.jpg':
        return l10n.desktopWallpaperLavender;
      case 'wallpaper_light_sunset.jpg':
        return l10n.desktopWallpaperSunset;
      case 'wallpaper_light_peach.jpg':
        return l10n.desktopWallpaperPeach;
      case 'wallpaper_light_sky.jpg':
        return l10n.desktopWallpaperSky;
      default:
        return basename;
    }
  }

  static List<_WallpaperChoice> _wallpaperChoicesFor(AppLocalizations l10n) {
    final out = <_WallpaperChoice>[
      // `default` resolves to the navy asset; keep it first and named, since
      // it is what a fresh profile is already on.
      _WallpaperChoice(
        id: 'default',
        title: l10n.desktopWallpaperNavy,
        assetPath: '${kBundledChatWallpaperAssetRoot}wallpaper_dark_navy.jpg',
      ),
      _WallpaperChoice(
        id: 'midnight',
        title: l10n.desktopWallpaperMidnight,
        assetPath: null,
      ),
    ];
    for (final base in kFeaturedChatWallpaperBasenames) {
      // Skip navy: it is already present above as `default`, and offering the
      // same picture twice under two ids would let the selection highlight
      // land on the row the user did not click.
      if (base == 'wallpaper_dark_navy.jpg') continue;
      final path = '$kBundledChatWallpaperAssetRoot$base';
      out.add(
        _WallpaperChoice(
          id: encodeAssetChatWallpaperId(path),
          title: _wallpaperTitle(base, l10n),
          assetPath: path,
        ),
      );
    }
    return out;
  }

  Future<void> _selectPreset(String id) async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    // ◆ Нажатие по схеме СНИМАЕТ свой цвет. Иначе плитка схемы выглядела бы
    // выбранной, а окно оставалось бы прежнего цвета — выбор без последствий.
    await DesktopUiPrefs.setCustomAccent(0);
    await ctrl.setAppThemePresetId(id);
    if (mounted) setState(() {});
  }

  /// ◆ Пятая плитка полосы: свой цвет.
  Future<void> _pickCustomAccent(BuildContext context) async {
    final ctrl = widget.controller;
    final dark = ctrl?.darkMode ?? true;
    final current = DesktopUiPrefs.customAccentArgb.value;
    final argb = await showAccentColorPicker(
      context,
      // Открываем на том цвете, который окно носит сейчас: свой, если он
      // выбран, иначе акцент текущей схемы — так первое движение мышью
      // подправляет знакомое, а не начинает с чужого красного.
      initial: current != 0
          ? Color(current)
          : (dark
                ? resolveAppThemePreset(
                    ctrl?.appThemePresetId ?? kAppThemePresets.first.id,
                  ).darkPrimary
                : resolveAppThemePreset(
                    ctrl?.appThemePresetId ?? kAppThemePresets.first.id,
                  ).lightPrimary),
      dark: dark,
    );
    if (argb == null) return;
    await DesktopUiPrefs.setCustomAccent(argb);
    if (mounted) setState(() {});
  }

  Future<void> _selectWallpaper(String id) async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    await ctrl.setDefaultChatWallpaperId(id);
    if (mounted) setState(() {});
  }

  Future<void> _selectBubbleStyle(String id) async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    // Premium bubble styles mirror mobile's free-set gate. Desktop never
    // sells (free companion app) — a locked swatch just stays locked here;
    // the account unlocks it by upgrading on the phone, which then syncs via
    // refreshEntitlementsNow().
    if (!kFreeBubbleStyleIds.contains(id) && !ctrl.myPremiumBadge) return;
    await ctrl.setChatBubbleStylePresetId(id);
    if (mounted) setState(() {});
  }

  Future<void> _selectNicknameStyle(String id) async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    await ctrl.setNicknameStylePresetId(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    final c = DColors.of(context);
    final currentPresetId = ctrl?.appThemePresetId ?? kAppThemePresets.first.id;
    final currentWallpaperId = ctrl?.defaultChatWallpaperId ?? 'default';
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopAppearanceTitle,
          description:
              l10n.desktopAppearanceHint,
          child: WorkspaceRow(
            label: l10n.desktopAppearanceScheme,
            description: l10n.desktopAppearanceSchemeHint,
            icon: FluentIcons.weather_moon_24_regular,
            // 🔴 ТРИ ЗНАЧЕНИЯ, А НЕ ТУМБЛЕР.
            //
            // Тумблер отвечает «да/нет», а здесь значений три: «Авто» — это
            // не «включено» и не «выключено», это «решай сам по системе».
            // Прежний тумблер третьего значения не имел вовсе, и следовать
            // системной теме окно не умело.
            trailing: ValueListenableBuilder<String>(
              valueListenable: DesktopUiPrefs.themeMode,
              builder: (ctx, mode, _) => DesktopSegmented<String>(
                values: const ['dark', 'light', 'auto'],
                labels: [
                  l10n.desktopAppearanceDark,
                  l10n.desktopAppearanceLight,
                  l10n.desktopAppearanceAuto,
                ],
                value: mode,
                onChanged: (v) {
                  unawaited(DesktopUiPrefs.setThemeMode(v));
                  if (ctrl == null || v == 'auto') return;
                  unawaited(ctrl.setDarkMode(v == 'dark'));
                },
              ),
            ),
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopAppearanceAccent,
          description: l10n.desktopAppearanceAccentHint,
          // 🔴 ПОЛОСА ПЛИТОК, А НЕ СЕТКА КАРТОЧЕК.
          //
          // Одиннадцать пресетов лежали сеткой три в ряд, каждый — карточка с
          // названием и обводкой: почти четыре сотни точек высоты на выбор
          // цвета. В макете это ОДНА строка квадратных плиток: цвет выбирают
          // глазами, а не по названию, и название рядом с пятном ничего не
          // добавляет — «Аврора» не говорит, какая она.
          //
          // Имя остаётся в подсказке: тому, кто захочет назвать свой цвет
          // другому человеку, оно понадобится.
          child: ValueListenableBuilder<int>(
            valueListenable: DesktopUiPrefs.customAccentArgb,
            builder: (ctx, custom, _) => Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final preset in kAppThemePresets)
                  _PresetTile(
                    preset: preset,
                    selected: custom == 0 && preset.id == currentPresetId,
                    onTap: ctrl == null ? null : () => _selectPreset(preset.id),
                  ),
                // ◆ ПЯТАЯ ПЛИТКА МАКЕТА — СВОЙ ЦВЕТ (пунктир + пипетка).
                //
                // Одиннадцать схем закрывают вкусы, но не все: цвет компании
                // или просто цвет, который человек узнаёт своим, в списке не
                // предусмотрен.
                _CustomAccentTile(
                  color: custom == 0 ? null : Color(custom),
                  onTap: ctrl == null
                      ? null
                      : () => unawaited(_pickCustomAccent(ctx)),
                ),
              ],
            ),
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopAppearanceWallpaper,
          // D-4: this used to promise a per-chat override via the details
          // drawer. No such override exists anywhere in the desktop tree — the
          // background is always the profile default. Claim removed rather
          // than left standing (P-5 extends to promises, not just controls).
          description: l10n.desktopAppearanceWallpaperHint,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _wallpaperChoicesFor(l10n).length,
            // 🔴 Плитки по МАКСИМАЛЬНОЙ ширине, а не «три в ряд».
            //
            // Три в ряд на широком окне настроек давали превью по 340 точек:
            // двенадцать обоев занимали четыре экрана, и выбрать фон значило
            // прокрутить их все. Обои узнают с первого взгляда, им хватает
            // двух сотен точек. Ограничение по ширине, а не по числу колонок,
            // — чтобы на узком окне плитки не сплющивались, а колонок стало
            // меньше.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: DSpace.s,
              crossAxisSpacing: DSpace.s,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (ctx, i) {
              final choice = _wallpaperChoicesFor(l10n)[i];
              // For the "midnight" option, paint the deep solid as a swatch.
              final isMidnight = choice.id == 'midnight';
              return _WallpaperCard(
                title: choice.title,
                selected: choice.id == currentWallpaperId,
                onTap: ctrl == null ? null : () => _selectWallpaper(choice.id),
                swatchColor: isMidnight ? kDarkSolidChatWallpaperColor : null,
                assetPath: isMidnight ? null : choice.assetPath,
              );
            },
          ),
        ),
        // Animated styles, generated from the SHARED catalogue rather than a
        // desktop copy — a style added on mobile shows up here for free.
        WorkspaceCard(
          title: l10n.desktopAppearanceLiveWallpaper,
          description:
              l10n.desktopAppearanceLiveWallpaperHint,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: WallpaperStyles.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DSpace.m,
              crossAxisSpacing: DSpace.m,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (ctx, i) {
              final style = WallpaperStyles.all[i];
              final id = encodeAnimatedChatWallpaperId(style.key);
              return _WallpaperCard(
                title: style.name,
                selected: id == currentWallpaperId,
                onTap: ctrl == null ? null : () => _selectWallpaper(id),
                // A live preview per tile would run one shader each; the
                // style's own first colour reads the mood at a glance and
                // costs nothing.
                swatchColor: style.colors.first,
                assetPath: null,
              );
            },
          ),
        ),
        if (ctrl != null) ...[
          WorkspaceCard(
            title: l10n.desktopAppearanceAnimBehaviour,
            description: l10n.desktopAppearanceAnimBehaviourHint,
            child: Column(
              children: [
                for (final m in ChatWallpaperAnimMode.values)
                  WorkspaceRow(
                    label: _animModeLabel(m, l10n),
                    trailing: WorkspaceSwitch(
                      value: ctrl.chatWallpaperAnimMode == m,
                      onChanged: (v) {
                        if (!v) return; // a mode is chosen, never un-chosen
                        unawaited(ctrl.setChatWallpaperAnimMode(m));
                      },
                    ),
                  ),
              ],
            ),
          ),
          WorkspaceCard(
            title: l10n.desktopAppearanceWallPulse,
            description: l10n.desktopAppearanceWallPulseHint,
            child: WorkspaceRow(
              label: l10n.desktopAppearanceEnable,
              description: l10n.desktopAppearanceLiveOnly,
              trailing: WorkspaceSwitch(
                value: ctrl.chatWallpaperConduct,
                onChanged: (v) => unawaited(ctrl.setChatWallpaperConduct(v)),
              ),
            ),
          ),
        ],
        WorkspaceCard(
          title: l10n.desktopAppearanceBubbleStyle,
          description: l10n.desktopAppearanceBubbleStyleHint,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kChatBubbleStylePresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DSpace.m,
              crossAxisSpacing: DSpace.m,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (ctx, i) {
              final preset = kChatBubbleStylePresets[i];
              final locked =
                  ctrl != null &&
                  !kFreeBubbleStyleIds.contains(preset.id) &&
                  !ctrl.myPremiumBadge;
              return _BubbleStyleCard(
                preset: preset,
                selected:
                    preset.id ==
                    (ctrl?.chatBubbleStylePresetId ?? 'flutter_dash'),
                locked: locked,
                onTap: ctrl == null
                    ? null
                    : () => _selectBubbleStyle(preset.id),
              );
            },
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopAppearanceSenderColour,
          description: l10n.desktopAppearanceSenderColourHint,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kNicknameStylePresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DSpace.m,
              crossAxisSpacing: DSpace.m,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (ctx, i) {
              final preset = kNicknameStylePresets[i];
              return _NicknameStyleCard(
                preset: preset,
                selected:
                    preset.id == (ctrl?.nicknameStylePresetId ?? 'accent'),
                onTap: ctrl == null
                    ? null
                    : () => _selectNicknameStyle(preset.id),
              );
            },
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopAppearanceIndicatorColour,
          description: l10n.desktopAppearanceIndicatorColourHint,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kIndicatorColorPresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DSpace.m,
              crossAxisSpacing: DSpace.m,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (ctx, i) {
              final preset = kIndicatorColorPresets[i];
              final dark = ctrl?.darkMode ?? true;
              final c = DColors.of(ctx);
              return _IndicatorSwatchCard(
                label: preset.nameRu,
                // `followsTheme` presets have no colour of their own — showing
                // the live accent is what they will actually look like.
                color: preset.followsTheme
                    ? c.accentPrimary
                    : (dark ? preset.darkPrimary : preset.lightPrimary),
                selected:
                    preset.id == (ctrl?.indicatorColorPresetId ?? 'theme'),
                onTap: ctrl == null
                    ? null
                    : () =>
                          unawaited(ctrl.setIndicatorColorPresetId(preset.id)),
              );
            },
          ),
        ),
        if (ctrl == null)
          WorkspaceCard(
            title: l10n.desktopAppearanceDemoMode,
            description:
                l10n.desktopAppearanceDemoHint,
            child: const SizedBox.shrink(),
          ),
        WorkspaceCard(
          title: l10n.desktopAppearanceCurrentChoice,
          child: Row(
            children: [
              Icon(
                FluentIcons.color_24_regular,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: DSpace.s),
              Text(
                l10n.desktopAppearanceThemeIs(resolveAppThemePreset(currentPresetId).nameRu),
                style: DType.body.copyWith(color: c.textPrimary),
              ),
              const Spacer(),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.accentPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.borderSubtle),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lightweight value class for the small built-in wallpaper grid we render
/// in the desktop settings. The mobile pickers load the full bundled list
/// via `loadBundledChatWallpaperAssets`; on desktop we curate a short
/// shortlist to keep the settings page focused.
class _WallpaperChoice {
  const _WallpaperChoice({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String? assetPath;
}

/// Плитка акцента: квадрат 36 с градиентом схемы, у выбранного — двойное
/// кольцо (провал цветом фона, затем акцент), как в макете.
class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: preset.nameRu,
      child: HoverListener(
        onTap: onTap,
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [preset.darkPrimary, preset.darkSecondary],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (selected) ...[
                // Провал цветом карточки, затем кольцо акцента: так выбранная
                // плитка читается кольцом, а не просто «чуть ярче».
                BoxShadow(color: c.elevated, spreadRadius: 2),
                BoxShadow(color: preset.darkPrimary, spreadRadius: 4),
              ] else if (hovered)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18),
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ◆ Плитка «свой цвет»: пунктирный квадрат с пипеткой, пока цвета нет, и
/// сам цвет, когда он выбран.
///
/// Пунктир — это «здесь пока пусто, и заполнить должен ты»: сплошная рамка
/// читалась бы как ещё одна готовая схема, только бесцветная.
class _CustomAccentTile extends StatelessWidget {
  const _CustomAccentTile({required this.color, required this.onTap});

  /// Выбранный цвет или `null`, если окно живёт на схеме.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final picked = color;
    return DesktopTooltip(
      message: picked == null ? 'Свой цвет' : 'Свой цвет — изменить',
      child: HoverListener(
        onTap: onTap,
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) {
          final tile = AnimatedContainer(
            duration: DMotion.fast,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: picked == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [picked, desktopAccentAlt(picked)],
                    ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (picked != null) ...[
                  BoxShadow(color: c.elevated, spreadRadius: 2),
                  BoxShadow(color: picked, spreadRadius: 4),
                ] else if (hovered)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: picked != null
                ? null
                : Icon(
                    FluentIcons.eyedropper_24_regular,
                    size: 18,
                    color: c.textTertiary,
                  ),
          );
          // Пунктир рисуем только пустой плитке: поверх выбранного цвета он
          // спорил бы с кольцом выбора.
          return picked == null
              ? CustomPaint(
                  painter: _DashedSquarePainter(
                    color: Colors.white.withValues(alpha: 0.18),
                    radius: 12,
                  ),
                  child: tile,
                )
              : tile;
        },
      ),
    );
  }
}

/// Пунктирная рамка скруглённого квадрата: во Flutter такой границы нет.
class _DashedSquarePainter extends CustomPainter {
  const _DashedSquarePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Штрих 3 через 3 — по макету: `1.5px dashed`.
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + 3).clamp(0.0, metric.length)),
          paint,
        );
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSquarePainter old) =>
      old.color != color || old.radius != radius;
}

class _BubbleStyleCard extends StatelessWidget {
  const _BubbleStyleCard({
    required this.preset,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ChatBubbleStylePreset preset;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: DMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: DSpace.s,
        ),
        decoration: BoxDecoration(
          color: selected ? c.selected : c.thread,
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(
            color: selected ? c.accentPrimary : c.borderSubtle,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DRadii.sm),
                    gradient: LinearGradient(
                      colors: [preset.darkTop, preset.darkBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.elevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.borderSubtle),
                      ),
                      child: Icon(
                        FluentIcons.lock_closed_12_filled,
                        size: 9,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Text(
                preset.nameRu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.bodyStrong.copyWith(
                  color: locked ? c.textSecondary : c.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                size: 18,
                color: c.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

class _NicknameStyleCard extends StatelessWidget {
  const _NicknameStyleCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final NicknameStylePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: DSpace.s,
        ),
        decoration: BoxDecoration(
          color: selected ? c.selected : c.thread,
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(
            color: selected ? c.accentPrimary : c.borderSubtle,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: preset.incoming,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: preset.outgoing,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.thread, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Text(
                preset.nameRu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ),
            if (selected)
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                size: 18,
                color: c.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

/// One indicator-colour choice: a dot in the colour, its name, and a ring when
/// selected. Deliberately not the theme swatch — that one carries a two-colour
/// preset, and an indicator has exactly one.
class _IndicatorSwatchCard extends StatelessWidget {
  const _IndicatorSwatchCard({
    required this.label,
    required this.color,
    required this.selected,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: DSpace.s,
        ),
        decoration: BoxDecoration(
          color: selected
              ? c.accentPrimary.withValues(alpha: 0.14)
              : (hovered ? c.hover : c.elevated),
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(
            color: selected ? c.accentPrimary : c.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.caption.copyWith(
                  color: c.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _WallpaperCard extends StatelessWidget {
  const _WallpaperCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.assetPath,
    this.swatchColor,
  });

  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final String? assetPath;
  final Color? swatchColor;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DMotion.fast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(
            color: selected ? c.accentPrimary : c.borderSubtle,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (assetPath != null)
              // D-3: decode at thumbnail size, not source size. These assets
              // are 1440×2560 ≈ 14.75 MB decoded each; six tiles built at once
              // (shrinkWrap grid, no lazy viewport) came to ~74 MB against
              // Flutter's 100 MB image cache, so opening Appearance evicted
              // every avatar and media thumbnail in the app and forced them all
              // to re-decode. Same helper mobile uses — "~0.4 MB instead of
              // 14 MB".
              Image.asset(
                assetPath!,
                fit: BoxFit.cover,
                cacheWidth: chatWallpaperDecodeWidth(context, preview: true),
                errorBuilder: (_, __, ___) =>
                    Container(color: swatchColor ?? c.chatList),
              )
            else
              Container(color: swatchColor ?? c.chatList),
            // Bottom gradient + label.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: DSpace.s,
              right: DSpace.s,
              bottom: DSpace.s,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.label.copyWith(color: Colors.white),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      FluentIcons.checkmark_circle_24_filled,
                      size: 16,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsPane extends StatefulWidget {
  const _NotificationsPane();
  @override
  State<_NotificationsPane> createState() => _NotificationsPaneState();
}

class _NotificationsPaneState extends State<_NotificationsPane> {
  static const List<int> _previewLevels = [0, 1, 2];

  DesktopNotificationService? get _svc => DesktopNotificationService.instance;

  String _previewLevelLabel(int level, AppLocalizations l10n) {
    switch (level) {
      case 0:
        return l10n.desktopNotifHidden;
      case 1:
        return l10n.desktopNotifSenderOnly;
      default:
        return l10n.desktopNotifSenderAndText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final svc = _svc;
    // No live service yet (e.g. not on a native desktop OS, or booting) —
    // show the same rows disabled rather than silently-fake local state.
    final previewLevel = svc?.previewLevel ?? 1;
    final sound = svc?.soundEnabled ?? true;
    final doNotDisturb = svc?.doNotDisturb ?? false;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Уведомления',
          description: svc == null ? l10n.desktopNotifUnavailableHere : null,
          child: Column(
            children: [
              WorkspaceRow(
                label: l10n.desktopNotifShowPreview,
                description: l10n.desktopNotifInSystem,
                trailing: DropdownButton<int>(
                  value: previewLevel,
                  underline: const SizedBox.shrink(),
                  onChanged: svc == null
                      ? null
                      : (v) {
                          final s = _svc;
                          if (v == null || s == null) return;
                          unawaited(s.setPreviewLevel(v));
                          setState(() {});
                        },
                  items: [
                    for (final level in _previewLevels)
                      DropdownMenuItem(
                        value: level,
                        child: Text(_previewLevelLabel(level, l10n)),
                      ),
                  ],
                ),
              ),
              // Rooms and direct chats mute independently — the one control
              // that makes desktop notifications survivable when a busy room
              // would otherwise drown out everything else. Shared with the
              // phone, so the choice follows the profile.
              WorkspaceRow(
                label: l10n.desktopNotifDirectChats,
                description: l10n.desktopNotifDirectChatsHint,
                trailing: WorkspaceSwitch(
                  value: _svc?.privateChatsEnabled ?? true,
                  onChanged: (v) {
                    final s = _svc;
                    if (s == null) return;
                    unawaited(s.setPrivateChatsEnabled(v));
                    setState(() {});
                  },
                ),
              ),
              WorkspaceRow(
                label: l10n.desktopNotifRooms,
                description: l10n.desktopNotifRoomsHint,
                trailing: WorkspaceSwitch(
                  value: _svc?.groupsEnabled ?? true,
                  onChanged: (v) {
                    final s = _svc;
                    if (s == null) return;
                    unawaited(s.setGroupsEnabled(v));
                    setState(() {});
                  },
                ),
              ),
              WorkspaceRow(
                label: l10n.desktopNotifSound,
                trailing: WorkspaceSwitch(
                  value: sound,
                  onChanged: (v) {
                    final s = _svc;
                    if (s == null) return;
                    unawaited(s.setSoundEnabled(v));
                    setState(() {});
                  },
                ),
              ),
              WorkspaceRow(
                label: l10n.desktopNotifDnd,
                description: l10n.desktopNotifDndHint,
                trailing: WorkspaceSwitch(
                  value: doNotDisturb,
                  onChanged: (v) {
                    final s = _svc;
                    if (s == null) return;
                    unawaited(s.setDoNotDisturb(v));
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyPane extends StatefulWidget {
  const _PrivacyPane({this.lockService, this.vm});
  final DesktopAppLockService? lockService;

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;
  AppController? get controller => vm?.controller;
  @override
  State<_PrivacyPane> createState() => _PrivacyPaneState();
}

/// Privacy-audience categories — mirrors mobile's settings_screen.dart 1:1 so
/// "who can see this" means the same thing on both platforms. Keys + default
/// fallback match AppController._privacyAudienceKeys.
const List<(String key, String title)> _kAudienceCategories = [
  ('last_seen', 'Время захода'),
  ('photo', 'Фотографии профиля'),
  ('forwards', 'Пересылка сообщений'),
  ('calls', 'Звонки'),
  ('voice_messages', 'Голосовые сообщения'),
  ('messages', 'Сообщения'),
];

class _PrivacyPaneState extends State<_PrivacyPane> {
  String _audienceLabel(String value) {
    switch (value) {
      case 'nobody':
        return 'Никто';
      case 'everyone':
        return 'Все';
      default:
        return 'Контакты';
    }
  }

  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ctrl = widget.controller;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Шифрование',
          description:
              'Все сообщения и звонки защищены сквозным шифрованием. '
              'Ключи находятся только на ваших устройствах.',
          // Honest status instead of a dead «verify» nav — per-contact
          // fingerprint verification lives in each contact's details.
          child: const WorkspaceRow(
            label: 'Сквозное шифрование активно',
            icon: FluentIcons.shield_checkmark_24_regular,
          ),
        ),
        if (widget.lockService != null)
          _AppLockCard(service: widget.lockService!),
        // «Отчёты о прочтении» / «Индикатор набора» / «Защита от скриншотов»
        // toggles removed: none of them gated a real feature on either
        // platform (sendTypingState and read receipts always fire
        // unconditionally; window_manager has no content-protection API) —
        // a switch with zero effect is a false sense of control, not a
        // setting. Re-add only once a real on/off exists to back it.
        if (ctrl != null) ...[
          WorkspaceCard(
            title: 'Кто видит',
            description:
                'Те же настройки видимости, что и в мобильном приложении.',
            child: Column(
              children: [
                for (final (key, title) in _kAudienceCategories) ...[
                  if (key != _kAudienceCategories.first.$1)
                    const Divider(height: 1),
                  WorkspaceRow(
                    label: title,
                    trailing: DropdownButton<String>(
                      value: ctrl.privacyAudience[key] ?? 'contacts',
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final v in const [
                          'nobody',
                          'contacts',
                          'everyone',
                        ])
                          DropdownMenuItem(
                            value: v,
                            child: Text(_audienceLabel(v)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        unawaited(ctrl.setPrivacyAudience(key, v));
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          WorkspaceCard(
            title: 'Видимость',
            child: Column(
              children: [
                WorkspaceRow(
                  label: 'Видимость по никнейму',
                  description: 'Позволить находить вас по никнейму',
                  trailing: WorkspaceSwitch(
                    value: ctrl.discoverableByNickname,
                    onChanged: (v) =>
                        unawaited(ctrl.setDiscoverableByNickname(v)),
                  ),
                ),
                const Divider(height: 1),
                WorkspaceRow(
                  label: 'Подсказка людей при поиске',
                  trailing: WorkspaceSwitch(
                    value: ctrl.allowNicknameLookup,
                    onChanged: (v) => unawaited(ctrl.setAllowNicknameLookup(v)),
                  ),
                ),
              ],
            ),
          ),
          WorkspaceCard(
            title: 'Новые чаты с незнакомцами',
            child: WorkspaceRow(
              label: 'В архив и без уведомлений',
              trailing: WorkspaceSwitch(
                value: ctrl.privacyArchiveUnknownChats,
                onChanged: (v) =>
                    unawaited(ctrl.setPrivacyArchiveUnknownChats(v)),
              ),
            ),
          ),
          WorkspaceCard(
            title: 'Удалить мой аккаунт',
            description:
                'Если вы не заходите дольше выбранного срока, аккаунт и все '
                'сообщения удаляются автоматически. Отсчёт сбрасывается при '
                'каждом входе.',
            child: WorkspaceRow(
              label: 'Если не захожу',
              description: _deleteMonthsLabel(ctrl.privacyDeleteAccountMonths),
              icon: FluentIcons.timer_24_regular,
              trailing: DropdownButton<int>(
                value:
                    _kDeleteMonthOptions.contains(
                      ctrl.privacyDeleteAccountMonths,
                    )
                    ? ctrl.privacyDeleteAccountMonths
                    : _kDeleteMonthOptions.last,
                underline: const SizedBox.shrink(),
                items: [
                  for (final m in _kDeleteMonthOptions)
                    DropdownMenuItem(
                      value: m,
                      child: Text(_deleteMonthsLabel(m)),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  unawaited(ctrl.setPrivacyDeleteAccountMonths(v));
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inactivity windows offered for automatic account deletion, in months.
const List<int> _kDeleteMonthOptions = <int>[1, 3, 6, 12, 24];

String _deleteMonthsLabel(int months) {
  switch (months) {
    case 1:
      return 'Через 1 месяц';
    case 3:
      return 'Через 3 месяца';
    case 6:
      return 'Через 6 месяцев';
    case 12:
      return 'Через год';
    default:
      return 'Через 2 года';
  }
}

class _AppLockCard extends StatefulWidget {
  const _AppLockCard({required this.service});
  final DesktopAppLockService service;
  @override
  State<_AppLockCard> createState() => _AppLockCardState();
}

class _AppLockCardState extends State<_AppLockCard> {
  static const _graceOptions = <int>[0, 60, 300, 900, 3600];

  @override
  void initState() {
    super.initState();
    widget.service.enabled.addListener(_onChange);
    widget.service.graceSeconds.addListener(_onChange);
    widget.service.biometricSupported.addListener(_onChange);
    unawaited(widget.service.refreshBiometricSupport());
  }

  @override
  void dispose() {
    widget.service.enabled.removeListener(_onChange);
    widget.service.graceSeconds.removeListener(_onChange);
    widget.service.biometricSupported.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _graceLabel(int s) {
    if (s == 0) return 'Сразу при потере фокуса';
    if (s < 60) return '$s сек.';
    if (s < 3600) return '${s ~/ 60} мин.';
    return '${s ~/ 3600} ч.';
  }

  /// Applies the lock toggle and explains it when the change does not stick.
  ///
  /// [DesktopAppLockService.setEnabled] arms the lock only after a successful
  /// authentication (F-17: proving the unlock path works is what prevents an
  /// unopenable app). A refusal therefore means the user cancelled, or this
  /// machine has no authenticator at all — the switch must stay off AND say
  /// why, instead of silently snapping back.
  Future<void> _toggleLock(bool value) async {
    final svc = widget.service;
    final applied = await svc.setEnabled(value);
    if (!mounted || applied || !value) return;
    DesktopSnackbar.show(
      context,
      message: svc.unlockUnavailable.value
          ? 'Служба проверки личности недоступна — блокировка не включена.'
          : 'Блокировка не включена: подтверждение не пройдено.',
      kind: DSnackKind.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final supported = svc.biometricSupported.value;
    final enabled = svc.enabled.value;
    final grace = svc.graceSeconds.value;
    return WorkspaceCard(
      title: 'Блокировка приложения',
      description: supported
          ? 'Запрашивать Touch ID для входа после потери фокуса.'
          : 'Запрашивать пароль устройства для входа после потери фокуса.',
      child: Column(
        children: [
          WorkspaceRow(
            // F-17: enabling is NOT gated on biometrics. Unlocking uses
            // `biometricOnly: false`, so a Mac without Touch ID authenticates
            // with the device password — gating the switch on biometric
            // support made the lock unavailable to those machines entirely.
            label: supported ? 'Включить Touch ID' : 'Включить блокировку',
            description: supported ? null : 'Пароль устройства',
            trailing: WorkspaceSwitch(
              value: enabled,
              onChanged: (v) => unawaited(_toggleLock(v)),
            ),
          ),
          if (enabled)
            WorkspaceRow(
              label: 'Блокировать через',
              description: _graceLabel(grace),
              trailing: DropdownButton<int>(
                value: _graceOptions.contains(grace)
                    ? grace
                    : _graceOptions.first,
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in _graceOptions)
                    DropdownMenuItem(value: s, child: Text(_graceLabel(s))),
                ],
                onChanged: (v) {
                  if (v != null) unawaited(svc.setGraceSeconds(v));
                },
              ),
            ),
          if (enabled)
            WorkspaceRow(
              label: 'Заблокировать сейчас',
              icon: FluentIcons.lock_closed_24_regular,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: svc.lock,
            ),
        ],
      ),
    );
  }
}

class _DevicesPane extends StatefulWidget {
  const _DevicesPane({this.controller, this.vm});
  final AppController? controller;

  /// Only needed to hand down to the pairing sheet, which binds to the shared
  /// tick instead of opening its own subscription.
  final DesktopAppViewModel? vm;

  @override
  State<_DevicesPane> createState() => _DevicesPaneState();
}

class _DevicesPaneState extends State<_DevicesPane> {
  List<String> _deviceIds = const [];
  bool _loading = false;
  String? _error;
  // PR-C: per-row spinner while end-session is in flight. Tracks the target
  // device id so multi-row UI can stay responsive.
  String? _endingDeviceId;
  // PR-F (bug 22): in-flight flag for the new "Sign out on this device" row.

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await widget.controller!.listMyDeviceIds();
      if (!mounted) return;
      setState(() {
        _deviceIds = ids;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  /// PR-C: confirmation flow for «Завершить сеанс» on desktop. Same
  /// AppController.endDeviceSession entry point as mobile.
  Future<void> _promptEndSession(
    BuildContext ctx,
    String targetDeviceId,
  ) async {
    final controller = widget.controller;
    if (controller == null) return;
    if (_endingDeviceId != null) return;
    // Capture messenger BEFORE any await so the post-await snackbar isn't
    // flagged by `use_build_context_synchronously`.
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Завершить сеанс?'),
          content: Text(
            'Устройство ${_shortId(targetDeviceId)} будет отключено от вашего профиля. '
            'Чтобы вернуть доступ, потребуется повторное сканирование QR. Продолжить?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Завершить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _endingDeviceId = targetDeviceId;
    });
    String? errorMsg;
    try {
      await controller.endDeviceSession(targetDeviceId: targetDeviceId);
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _endingDeviceId = null;
        });
      }
    }
    if (!mounted) return;
    if (errorMsg != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Не удалось завершить сеанс: $errorMsg')),
      );
    } else {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Сеанс устройства завершён.')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // `controller` is `vm?.controller` at the call site, so guarding on the
    // view model gives both without a bang operator.
    final vm = widget.vm;
    final controller = vm?.controller;
    if (vm == null || controller == null) {
      // Demo (controller-less) mode: render the same shape as production but
      // mark rows as non-interactive so users don't tap dead handlers. The
      // rows below intentionally have NO onTap — WorkspaceRow renders them
      // as a static info card.
      return _PaneScaffold(
        children: [
          WorkspaceCard(
            title: 'Активные сессии',
            description:
                'Демо-режим · реальные устройства появятся после подключения профиля',
            child: Column(
              children: const [
                WorkspaceRow(
                  label: 'macOS · Этот компьютер',
                  description: 'MacBook Pro · Сейчас активен',
                  icon: FluentIcons.laptop_24_regular,
                ),
                WorkspaceRow(
                  label: 'iPhone 15 Pro',
                  description: 'iOS 18.2 · 2 часа назад (демо)',
                  icon: FluentIcons.phone_24_regular,
                ),
                WorkspaceRow(
                  label: 'iPad Air',
                  description: 'iPadOS 18 · вчера (демо)',
                  icon: FluentIcons.tablet_24_regular,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final myDid = controller.deviceId;
    final rows = <Widget>[];
    for (final id in _deviceIds) {
      final isThis = id == myDid;
      final isBusy = _endingDeviceId == id;
      rows.add(
        WorkspaceRow(
          label: isThis ? 'Это устройство' : _shortId(id),
          description: isThis
              ? '${Platform.operatingSystem} · ${_shortId(id)}'
              : 'Удалённое устройство',
          icon: isThis
              ? (Platform.isMacOS
                    ? FluentIcons.laptop_24_regular
                    : Platform.isWindows
                    ? FluentIcons.desktop_24_regular
                    : Platform.isLinux
                    ? FluentIcons.desktop_24_regular
                    : FluentIcons.phone_24_regular)
              : FluentIcons.phone_laptop_24_regular,
          // PR-C: end-session button on every non-self row. Disabled while
          // ANY end-session is in flight to prevent click-storms.
          // 🔴 У СВОЕГО устройства теперь есть плашка «активно», а у чужих —
          // КРАСНАЯ кнопка. Прежняя нейтральная «Завершить сеанс» выглядела
          // как «обновить»: отключение чужого устройства необратимо, и цвет
          // обязан это говорить. Своя строка раньше не отличалась ничем, и
          // человек искал, на какой из трёх одинаковых строк он сейчас.
          trailing: isThis
              ? const _ActiveBadge()
              : (isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : DesktopButton(
                        label: 'Отключить',
                        kind: DButtonKind.danger,
                        onPressed: _endingDeviceId != null
                            ? null
                            : () => _promptEndSession(context, id),
                      )),
        ),
      );
    }

    return _PaneScaffold(
      children: [
        WorkspaceCard(
          // Счётчик в заголовке из макета: «сколько у меня устройств» — это
          // вопрос безопасности, и ответ на него должен быть виден до того,
          // как человек начнёт считать строки глазами.
          title: _deviceIds.isEmpty
              ? 'Устройства'
              : 'Устройства · ${_deviceIds.length}',
          description:
              'Список устройств, привязанных к этому профилю на сервере ключей.',
          child: Column(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: DSpace.l),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else if (_error != null)
                WorkspaceRow(
                  label: 'Не удалось загрузить',
                  description: _error!,
                  icon: FluentIcons.warning_24_regular,
                  trailing: DesktopButton(
                    label: 'Повторить',
                    kind: DButtonKind.tonal,
                    onPressed: _load,
                  ),
                )
              else if (rows.isEmpty)
                WorkspaceRow(
                  label: 'Устройств не найдено',
                  description: 'Профиль ещё не привязан к серверу.',
                  icon: FluentIcons.phone_laptop_24_regular,
                )
              else
                ...rows,
            ],
          ),
        ),
        WorkspaceCard(
          child: WorkspaceRow(
            label: 'Обновить список',
            icon: FluentIcons.arrow_clockwise_24_regular,
            onTap: _loading ? null : _load,
          ),
        ),
        // PR8 hotfix: пользователь жаловался, что подключить второе устройство
        // из Settings невозможно — QR показывается только в onboarding-экране.
        // Эта карточка вызывает тот же createDesktopLinkRequest +
        // buildDesktopLinkQrPayload пайплайн в bottom-sheet'е.
        _PairNewDeviceCard(vm: vm, onPaired: _load),
        // PR6: manual «Sync History» trigger. Asks one of the user's other
        // devices (typically the mobile that paired this desktop) to ship
        // a recent-history window over the existing e2ee ratchet. The
        // service rate-limits + dedupes, so spamming the button is safe.
        // PR7: + «Подкачать вложения» row for blob rehydrate.
        _HistorySyncCard(controller: widget.controller),
        // 2026-07-05: desktop can hold a standalone profile (own device +
        // profile-secret), so it CAN create a server Safe Backup — the UI just
        // never exposed it (profile_workspace only said "do it on the phone").
        // This card runs the verified upload so the user gets proof the copy
        // actually landed on the server.
        _ServerBackupCard(controller: widget.controller),
        // PR-F (bug 22): "Sign out on this device". This was the missing
        // counterpart to mobile's settings → "Выйти". The button used to live
        // nowhere on desktop, leaving users with no way to leave the account
        // short of `rm -rf ~/Library/Application Support/Secretly`.
      ],
    );
  }
}

/// Settings → Devices → «Подключить устройство».
///
/// Reuses the same `createDesktopLinkRequest` + `buildDesktopLinkQrPayload`
/// pipeline that `DesktopOnboardingScreen` uses for the first-pair flow.
/// The difference: this is invoked from an already-authenticated desktop, so
/// the resulting QR is meant to be scanned by **another** new desktop (or
/// presented to a freshly-installed mobile). The mobile-side QR scanner
/// (`devices_auth_screen.dart`) accepts the same payload format.
class _PairNewDeviceCard extends StatelessWidget {
  const _PairNewDeviceCard({required this.vm, this.onPaired});
  final DesktopAppViewModel vm;
  final VoidCallback? onPaired;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      child: WorkspaceRow(
        label: 'Подключить устройство',
        description:
            'Покажите QR-код на новом устройстве или отсканируйте его с телефона',
        icon: FluentIcons.qr_code_24_regular,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          // `showDialog` (вместо showModalBottomSheet) — это самый надёжный
          // путь поверх _modalOverlay-стека в DesktopProductionApp. Использует
          // root navigator, поэтому диалог всегда оказывается выше любого
          // _modalOverlay в Stack'е.
          await showDialog<void>(
            context: context,
            useRootNavigator: true,
            barrierDismissible: true,
            barrierColor: Colors.black.withValues(alpha: 0.55),
            builder: (_) => _PairDeviceDialog(vm: vm),
          );
          // Re-load the device list on close — newly-paired device should now
          // show up.
          onPaired?.call();
        },
      ),
    );
  }
}

/// Wraps the QR sheet in a Dialog so it overlays cleanly on top of the
/// DesktopProductionApp `_modalOverlay` Stack. Uses root navigator.
class _PairDeviceDialog extends StatelessWidget {
  const _PairDeviceDialog({required this.vm});
  final DesktopAppViewModel vm;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Center(
      child: Material(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.lg),
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
          child: _PairDeviceSheet(vm: vm),
        ),
      ),
    );
  }
}

class _PairDeviceSheet extends StatefulWidget {
  const _PairDeviceSheet({required this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  @override
  State<_PairDeviceSheet> createState() => _PairDeviceSheetState();
}

class _PairDeviceSheetState extends State<_PairDeviceSheet> {
  DesktopLinkRequest? _request;
  String? _qrPayload;
  String? _errorMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    final req = _request;
    if (req != null) {
      // Best-effort cleanup so the request doesn't linger in storage.
      // Ignore errors — request may already have transitioned.
      unawaited(widget.controller.cancelDesktopLinkRequest(req.requestId));
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final request = await widget.controller.createDesktopLinkRequest(
        deviceLabel: 'Secretly Desktop',
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _qrPayload = widget.controller.buildDesktopLinkQrPayload(request);
        _busy = false;
      });
    } on DesktopLinkFailure catch (failure) {
      if (!mounted) return;
      final msg = failure.message;
      setState(() {
        _busy = false;
        _errorMessage = (msg.isNotEmpty)
            ? msg
            : 'Не удалось создать запрос на подключение';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Не текст исключения: человеку показывали «Bad state: publishKeys
        // returned ok=false». Известные причины приходят типизированными и
        // печатаются своим текстом выше; остальное честнее назвать общим
        // словом и оставить подробность журналу.
        _errorMessage =
            'Не удалось подготовить код. Проверьте подключение к '
            'интернету и попробуйте ещё раз.';
      });
    }
  }

  Future<void> _retry() async {
    final req = _request;
    if (req != null) {
      try {
        await widget.controller.cancelDesktopLinkRequest(req.requestId);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _request = null;
      _qrPayload = null;
    });
    await _start();
  }

  Future<void> _copyPayload() async {
    final payload = _qrPayload;
    if (payload == null) return;
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Содержимое QR скопировано')));
  }

  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm.ticks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = DColors.of(context);
    final payload = _qrPayload;
    return Padding(
      padding: const EdgeInsets.all(DSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.bg,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Icon(
                FluentIcons.qr_code_24_regular,
                size: 26,
                color: c.accentPrimary,
              ),
            ),
            const SizedBox(height: DSpace.l),
            Text(
              'Подключить новое устройство',
              style: DType.title.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DSpace.s),
            Text(
              'На новом устройстве откройте Secretly и выберите '
              '«Подключиться по QR». Затем отсканируйте код ниже.',
              style: DType.body.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DSpace.xl),
            Container(
              width: 264,
              height: 264,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DRadii.lg),
                border: Border.all(color: c.borderSubtle),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(DSpace.m),
              child: payload == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy)
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        else
                          const Icon(
                            FluentIcons.qr_code_24_regular,
                            size: 48,
                            color: Colors.black45,
                          ),
                        const SizedBox(height: DSpace.s),
                        Text(
                          _busy ? 'Готовим QR…' : 'QR недоступен',
                          style: DType.caption.copyWith(color: Colors.black54),
                        ),
                      ],
                    )
                  : QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: DSpace.m),
              Text(
                _errorMessage!,
                style: DType.caption.copyWith(color: c.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: DSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DesktopButton(
                  label: 'Закрыть',
                  kind: DButtonKind.tonal,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                DesktopButton(
                  label: 'Скопировать код',
                  kind: DButtonKind.tonal,
                  onPressed: payload == null ? null : _copyPayload,
                ),
                DesktopButton(
                  label: 'Обновить QR',
                  kind: DButtonKind.filled,
                  onPressed: _busy ? null : _retry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySyncCard extends StatefulWidget {
  const _HistorySyncCard({this.controller});
  final AppController? controller;
  @override
  State<_HistorySyncCard> createState() => _HistorySyncCardState();
}

class _HistorySyncCardState extends State<_HistorySyncCard> {
  bool _running = false;
  String? _feedback;
  bool _rehydrating = false;
  String? _rehydrateFeedback;

  Future<void> _trigger() async {
    if (_running) return;
    setState(() {
      _running = true;
      _feedback = null;
    });
    final service = PeerHistoryService.instance;
    final before = service.backfilledCount;
    try {
      await service.triggerManualSync();
    } catch (_) {
      // Service swallows errors — fall through and show a generic
      // "не удалось" message if nothing landed.
    }
    if (!mounted) return;
    final after = service.backfilledCount;
    final delta = after - before;
    setState(() {
      _running = false;
      if (delta > 0) {
        _feedback = 'Подгружено новых событий: $delta';
      } else if (service.requestsRejected > 0 &&
          service.requestsCompleted == 0) {
        _feedback = 'Слишком частые запросы — попробуйте позже';
      } else {
        _feedback = 'Готово · новых событий нет';
      }
    });
  }

  /// PR7: rehydrate attachment blobs across all conversations. Walks
  /// recent events per convo and downloads any [AttachmentEventV1] blob
  /// that isn't on disk yet. Safe to spam — `ensureCachedAttachmentFile`
  /// short-circuits if the file already exists.
  Future<void> _triggerRehydrate() async {
    if (_rehydrating) return;
    final controller = widget.controller;
    if (controller == null) {
      setState(() {
        _rehydrateFeedback = 'Недоступно в демо-режиме';
      });
      return;
    }
    setState(() {
      _rehydrating = true;
      _rehydrateFeedback = null;
    });
    try {
      final result = await controller.prefetchAttachmentsForAllConvos();
      if (!mounted) return;
      setState(() {
        _rehydrating = false;
        if (result.blobsDownloaded > 0) {
          _rehydrateFeedback =
              'Подгружено вложений: ${result.blobsDownloaded} '
              '(чатов: ${result.convosScanned})';
        } else {
          _rehydrateFeedback =
              'Готово · новых вложений нет (чатов: ${result.convosScanned})';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rehydrating = false;
        _rehydrateFeedback = 'Не удалось: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      title: 'История с других устройств',
      description:
          'Запросить недавнюю историю чатов у мобильного устройства. '
          'Используется, если десктоп был офлайн дольше 7 дней или только '
          'что был привязан по QR-коду.',
      child: Column(
        children: [
          WorkspaceRow(
            label: _running ? 'Синхронизация…' : 'Запросить историю',
            description: _feedback,
            icon: FluentIcons.history_24_regular,
            trailing: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : DesktopButton(
                    label: 'Запросить',
                    kind: DButtonKind.tonal,
                    onPressed: _trigger,
                  ),
          ),
          WorkspaceRow(
            label: _rehydrating ? 'Загрузка вложений…' : 'Подкачать вложения',
            description:
                _rehydrateFeedback ??
                'Скачивает медиа из недавних чатов, если файлы '
                    'отсутствуют локально (после повторной привязки '
                    'или долгого офлайна).',
            icon: FluentIcons.cloud_arrow_down_24_regular,
            trailing: _rehydrating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : DesktopButton(
                    label: 'Подкачать',
                    kind: DButtonKind.tonal,
                    onPressed: widget.controller == null
                        ? null
                        : _triggerRehydrate,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Settings → Devices → «Резервная копия на сервер».
///
/// Creates a password-protected Safe Backup and uploads it to the keys server,
/// then PROVES it landed (read-back + SHA compare) via
/// [AppController.uploadSafeBackupToServerVerified]. Restorable on any device by
/// entering the same Secretly ID + password in onboarding → «Восстановить с
/// сервера».
class _ServerBackupCard extends StatefulWidget {
  const _ServerBackupCard({this.controller});
  final AppController? controller;
  @override
  State<_ServerBackupCard> createState() => _ServerBackupCardState();
}

class _ServerBackupCardState extends State<_ServerBackupCard> {
  bool _running = false;
  String? _feedback;
  bool _ok = false;

  Future<void> _run(BuildContext context) async {
    final controller = widget.controller;
    if (controller == null || _running) return;

    final password = await _promptPassword(context);
    if (password == null || !mounted) return;

    setState(() {
      _running = true;
      _feedback = null;
      _ok = false;
    });
    try {
      final result = await controller.uploadSafeBackupToServerVerified(
        password: password,
      );
      if (!mounted) return;
      final when = DateTime.fromMillisecondsSinceEpoch(
        result.serverUpdatedAtMs,
      ).toLocal();
      final stamp =
          '${when.day.toString().padLeft(2, '0')}.'
          '${when.month.toString().padLeft(2, '0')}.${when.year} '
          '${when.hour.toString().padLeft(2, '0')}:'
          '${when.minute.toString().padLeft(2, '0')}';
      setState(() {
        _running = false;
        _ok = true;
        _feedback =
            'Копия на сервере ✓ · $stamp · '
            '${result.payloadKilobytes.toStringAsFixed(0)} КБ · '
            'профиль ${result.profileId}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _ok = false;
        _feedback = 'Не удалось: ${_short(e)}';
      });
    }
  }

  String _short(Object e) {
    var s = e.toString();
    if (s.startsWith('Bad state: ')) s = s.substring('Bad state: '.length);
    if (s.startsWith('StateError: ')) s = s.substring('StateError: '.length);
    return s;
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final pw = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final a = pw.text;
              final b = confirm.text;
              final validation = BackupPasswordPolicy.validate(a);
              if (!validation.isValid) {
                setLocal(() => error = validation.problemText(isRu: true));
                return;
              }
              if (a != b) {
                setLocal(() => error = l10n.desktopBackupPasswordsDiffer);
                return;
              }
              Navigator.of(ctx).pop(a);
            }

            return AlertDialog(
              title: const Text('Пароль резервной копии'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Этим паролем копия шифруется и восстанавливается на любом '
                    'устройстве. Запомните его — без пароля копия бесполезна, '
                    'восстановить его нельзя.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pw,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error ?? BackupPasswordPolicy.requirementsText(isRu: true),
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: error != null
                          ? Theme.of(ctx).colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Создать копию'),
                ),
              ],
            );
          },
        );
      },
    );
    pw.dispose();
    confirm.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      title: 'Резервная копия на сервер',
      description:
          'Зашифрованная копия аккаунта на сервере Secretly. '
          'Восстанавливается на любом устройстве через '
          '«Восстановить с сервера» по вашему Secretly ID и паролю.',
      child: Column(
        children: [
          // SEC-01, как на телефоне (`a00ae2a7`): копия на сервере без опоры
          // токена доступа — предложить пересохранить. Тон спокойный: данные
          // зашифрованы паролем в любом случае (17.09.2026).
          if (!_running &&
              (widget.controller?.serverBackupNeedsAccessUpgrade ?? false))
            WorkspaceRow(
              label: AppLocalizations.of(context)!.backupAccessUpgradeTitle,
              description:
                  AppLocalizations.of(context)!.backupAccessUpgradeBody,
              icon: FluentIcons.lock_closed_24_regular,
              trailing: DesktopButton(
                label: AppLocalizations.of(context)!.backupAccessUpgradeAction,
                kind: DButtonKind.tonal,
                onPressed: () => _run(context),
              ),
            ),
          _serverBackupRow(context),
        ],
      ),
    );
  }

  Widget _serverBackupRow(BuildContext context) {
    return WorkspaceRow(
        label: _running ? 'Загрузка…' : 'Создать копию на сервере',
        description: _feedback,
        icon: FluentIcons.cloud_arrow_up_24_regular,
        trailing: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : DesktopButton(
                label: _ok ? 'Обновить копию' : 'Создать',
                kind: DButtonKind.tonal,
                icon: FluentIcons.cloud_arrow_up_24_regular,
                onPressed: widget.controller == null
                    ? null
                    : () => _run(context),
              ),
    );
  }
}

/// PR §D: this pane used to be a pure mock — hardcoded "420 МБ" with no `onTap`.
/// It now reports real on-disk usage from [CacheManager.computeUsage] and the
/// «Очистить кеш» row really runs [CacheManager.clearMediaCache] (re-fetchable
/// caches only — never the DB, keys, chats or the user's own gallery).
class _StoragePane extends StatefulWidget {
  const _StoragePane();
  @override
  State<_StoragePane> createState() => _StoragePaneState();
}

class _StoragePaneState extends State<_StoragePane> {
  CacheUsage? _usage;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final usage = await CacheManager.instance.computeUsage();
    if (!mounted) return;
    setState(() => _usage = usage);
  }

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await CacheManager.instance.clearMediaCache();
      await _refresh();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  /// Removes the on-device speech model. Separate from «Очистить кеш» because
  /// clearMediaCache deliberately never touches it: it is ~140 MB and
  /// re-downloading is a deliberate act, not a side effect of tidying up.
  Future<void> _deleteVoiceModel() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await DesktopDialog.show<bool>(
      context,
      title: 'Удалить модель распознавания?',
      size: DDialogSize.small,
      body: Text(
        'Расшифровка голосовых сообщений перестанет работать, пока модель не '
        'скачается заново.',
        style: DType.body.copyWith(color: DColors.of(context).textSecondary),
      ),
      primary: DDialogAction(
        label: 'Удалить',
        kind: DButtonKind.danger,
        onPressed: () => Navigator.of(context).maybePop(true),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(false),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CacheManager.instance.deleteWhisperModel();
      await _refresh();
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Модель удалена',
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось удалить: $e',
        kind: DSnackKind.error,
      );
    }
  }

  static String fmtBytes(int bytes) {
    if (bytes <= 0) return '0 КБ';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Использование',
          description: 'Кеш и медиа на этом устройстве',
          child: _StorageBar(usage: usage),
        ),
        WorkspaceCard(
          // Say what survives. "Clear cache" that quietly keeps some files is
          // fine engineering and bad communication: a user freeing space needs
          // to know why the number did not drop as far as they expected.
          description: usage == null
              ? null
              : 'Освободится ${fmtBytes(usage.clearableBytes)}. '
                    'Сообщения, отправленные вами файлы и «недавние» не '
                    'удаляются — их неоткуда восстановить.',
          child: WorkspaceRow(
            label: 'Очистить кеш',
            description: usage == null
                ? 'Подсчёт…'
                : fmtBytes(usage.clearableBytes),
            icon: FluentIcons.broom_24_regular,
            trailing: _clearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : null,
            onTap: _clearing ? null : _clear,
          ),
        ),
        if ((usage?.whisperModelBytes ?? 0) > 0)
          WorkspaceCard(
            title: 'Модель распознавания речи',
            description:
                'Используется для расшифровки голосовых сообщений на этом '
                'компьютере, без отправки звука куда-либо. Обычная очистка '
                'кеша её НЕ удаляет — она большая и качается отдельно.',
            child: WorkspaceRow(
              label: 'Удалить модель',
              description: fmtBytes(usage?.whisperModelBytes ?? 0),
              icon: FluentIcons.mic_off_24_regular,
              trailing: DesktopButton(
                label: 'Удалить',
                kind: DButtonKind.tonal,
                size: DButtonSize.small,
                onPressed: () => unawaited(_deleteVoiceModel()),
              ),
            ),
          ),
      ],
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({this.usage});
  final CacheUsage? usage;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final u = usage;
    final media = u?.mediaBytes ?? 0;
    final voice = (u?.voiceTranscriptsBytes ?? 0) + (u?.whisperModelBytes ?? 0);
    final other =
        (u?.stickersBytes ?? 0) +
        (u?.profileMediaBytes ?? 0) +
        (u?.recentAttachmentsBytes ?? 0) +
        (u?.notoEmojiBytes ?? 0);
    // Proportional widths; +1 keeps every present segment visible. When usage
    // is still loading everything collapses into the neutral "free" track.
    final mediaFlex = u == null ? 0 : (media == 0 ? 0 : media ~/ 1024 + 1);
    final voiceFlex = u == null ? 0 : (voice == 0 ? 0 : voice ~/ 1024 + 1);
    final otherFlex = u == null ? 0 : (other == 0 ? 0 : other ~/ 1024 + 1);
    final used = mediaFlex + voiceFlex + otherFlex;
    final freeFlex = used == 0 ? 1 : (used * 0.6).round() + 1;
    final f = _StoragePaneState.fmtBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DRadii.pill),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (mediaFlex > 0)
                  Expanded(
                    flex: mediaFlex,
                    child: Container(color: c.accentPrimary),
                  ),
                if (voiceFlex > 0)
                  Expanded(
                    flex: voiceFlex,
                    child: Container(color: c.warning),
                  ),
                if (otherFlex > 0)
                  Expanded(
                    flex: otherFlex,
                    child: Container(color: c.success),
                  ),
                Expanded(
                  flex: freeFlex,
                  child: Container(color: c.borderDivider),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DSpace.s),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legend(c.accentPrimary, 'Медиа · ${f(media)}'),
            _legend(c.warning, 'Голос · ${f(voice)}'),
            _legend(c.success, 'Прочее · ${f(other)}'),
            _legend(
              c.borderDivider,
              u == null ? 'Свободно' : 'Всего · ${f(u.total)}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color col, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          t,
          style: const TextStyle(
            fontFamily: DType.family,
            fontSize: 12,
            color: Color(0xFF9CA0A8),
          ),
        ),
      ],
    );
  }
}

/// Раздел «Горячие клавиши» — тот же список, что в окне по Cmd+/.
///
/// Своей таблицы здесь НЕТ намеренно: она одна, в `shortcuts_help.dart`. Две
/// таблицы про одни и те же клавиши разошлись бы на первой же новой
/// комбинации, и тогда одна из них начала бы врать.
class _ShortcutsPane extends StatelessWidget {
  const _ShortcutsPane();

  @override
  Widget build(BuildContext context) {
    return const _PaneScaffold(children: [ShortcutsList()]);
  }
}

class _AboutPane extends StatefulWidget {
  const _AboutPane();
  @override
  State<_AboutPane> createState() => _AboutPaneState();
}

class _AboutPaneState extends State<_AboutPane> {
  // Cached so the FutureBuilder doesn't reload on every rebuild.
  late final Future<AppPackageInfo> _pkgFuture = AppPackageInfo.load();

  Future<void> _openWebsite() async {
    try {
      await launchUrl(
        Uri.parse('https://www.secretlyapp.com'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Secretly',
                style: DType.display.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              // Real version — was hard-coded «1.1.1 · сборка 35».
              FutureBuilder<AppPackageInfo>(
                future: _pkgFuture,
                builder: (ctx, snap) {
                  final info = snap.data ?? AppPackageInfo.fallback;
                  return Text(
                    'Версия ${info.version} · сборка ${info.buildNumber}',
                    style: DType.label.copyWith(color: c.textSecondary),
                  );
                },
              ),
              const SizedBox(height: DSpace.m),
              Text(
                'Защищённый мессенджер с end-to-end шифрованием. Без облака. '
                'Без рекламы. Открытый исходный код.',
                style: DType.body.copyWith(color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: DSpace.l),
              Row(
                children: [
                  DesktopButton(
                    label: 'Лицензии',
                    kind: DButtonKind.tonal,
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Secretly',
                    ),
                  ),
                  const SizedBox(width: DSpace.s),
                  DesktopButton(
                    label: 'Сайт',
                    kind: DButtonKind.ghost,
                    icon: FluentIcons.open_24_regular,
                    onPressed: () => unawaited(_openWebsite()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// PR-F (bug 23): "Delete account" used to be a literal no-op
/// (`onPressed: () {}`) — the pane was stateless, had no controller reference,
/// and no text-controller for the confirmation field. This rewrite mirrors the
/// mobile flow in `settings_screen.dart::_confirmAndDeleteAccount`:
///
///   1. User types their Secretly ID into the confirm field.
///   2. The danger button stays disabled until the typed text matches
///      `controller.profileId` (case-sensitive, trimmed).
///   3. Tap → AlertDialog confirm → blocking spinner →
///      `controller.deleteAccountEverywhere()` (which itself emits
///      `restartRequested`, causing `DesktopProductionApp._restart()` to drop
///      the user back to the onboarding/QR screen).
class _DangerPane extends StatefulWidget {
  const _DangerPane({this.controller});
  final AppController? controller;

  @override
  State<_DangerPane> createState() => _DangerPaneState();
}

class _DangerPaneState extends State<_DangerPane> {
  late final TextEditingController _confirm;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _confirm = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _confirm
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  bool get _canDelete {
    final controller = widget.controller;
    if (controller == null) return false;
    if (_deleting) return false;
    final typed = _confirm.text.trim();
    final pid = controller.profileId.trim();
    if (typed.isEmpty) return false;
    // Local-only/test profiles can still be deleted — confirm against the
    // current pid in either case. `profileId` returns 'unknown' when no
    // profile is bound; refuse delete in that state.
    if (pid.isEmpty || pid == 'unknown') return false;
    return typed == pid;
  }

  Future<void> _runDelete(BuildContext context) async {
    final controller = widget.controller;
    if (controller == null) return;

    // Capture messenger + root navigator before any await — avoids
    // `use_build_context_synchronously` lint and survives the spinner-dialog
    // tear-down (the spinner's BuildContext gets pop'd mid-flow).
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    // Refuse while a call is active — the call socket+CallKit/Telecom would
    // be torn down mid-flight and leave the OS-level call UI orphaned.
    final cm = CallManager.instance;
    if (cm != null && cm.state.value.isActive) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Сначала завершите активный звонок.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: navigator.context,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Удалить аккаунт безвозвратно?'),
          content: const Text(
            'Профиль, ключи, локальные данные и история сообщений будут '
            'удалены на этом и других устройствах. Восстановление невозможно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.error,
                foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    // Show a blocking progress dialog so the user can't double-tap or close
    // the workspace mid-delete. Uses root navigator so it sits above the
    // settings overlay.
    unawaited(
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Удаление аккаунта…')),
              ],
            ),
          ),
        ),
      ),
    );

    Object? error;
    try {
      await controller.deleteAccountEverywhere();
    } catch (e) {
      error = e;
    } finally {
      // Dismiss spinner regardless of outcome.
      try {
        navigator.pop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _deleting = false);

    if (error != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Не удалось удалить аккаунт: $error')),
      );
    }
    // On success `deleteAccountEverywhere` fires `restartRequested`, which
    // `DesktopProductionApp` already wires to `_restart()` — that returns the
    // app to the onboarding/QR screen and discards the settings workspace.
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) {
      // Demo (controller-less) mode: render the same layout but mark the
      // button as permanently disabled so users don't tap dead handlers.
      return _PaneScaffold(
        children: [
          WorkspaceCard(
            title: 'Удаление аккаунта',
            description:
                'Демо-режим · удаление недоступно без подключённого профиля.',
            child: Column(
              children: [
                const SizedBox(height: DSpace.s),
                const DesktopTextField(
                  hintText: 'Введите ваш Secretly ID для подтверждения',
                ),
                const SizedBox(height: DSpace.m),
                Align(
                  alignment: Alignment.centerRight,
                  child: DesktopButton(
                    label: 'Удалить аккаунт',
                    kind: DButtonKind.danger,
                    icon: FluentIcons.delete_24_regular,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final pid = controller.profileId.trim();
    final hint = pid.isEmpty || pid == 'unknown'
        ? 'Введите ваш Secretly ID для подтверждения'
        : 'Введите $pid для подтверждения';

    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Удаление аккаунта',
          description:
              'Это действие необратимо. Удалятся все ваши данные, '
              'история сообщений и ключи. Восстановление невозможно.',
          child: Column(
            children: [
              const SizedBox(height: DSpace.s),
              DesktopTextField(controller: _confirm, hintText: hint),
              const SizedBox(height: DSpace.m),
              Align(
                alignment: Alignment.centerRight,
                child: _deleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : DesktopButton(
                        label: 'Удалить аккаунт',
                        kind: DButtonKind.danger,
                        icon: FluentIcons.delete_24_regular,
                        onPressed: _canDelete
                            ? () => _runDelete(context)
                            : null,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Security — the settings that change what the app will accept, not how it
/// looks. Never gated, never hidden behind a tier (principle P-4).
class _SecurityPane extends StatefulWidget {
  const _SecurityPane({this.vm, this.lockService});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;
  AppController? get controller => vm?.controller;
  final DesktopAppLockService? lockService;
  @override
  State<_SecurityPane> createState() => _SecurityPaneState();
}

class _SecurityPaneState extends State<_SecurityPane> {
  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final ctrl = widget.controller;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Сквозное шифрование',
          child: Row(
            children: [
              Icon(
                FluentIcons.lock_closed_24_filled,
                size: 18,
                color: c.success,
              ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Text(
                  'Все сообщения, звонки и файлы шифруются на вашем устройстве. '
                  'Ключи не покидают ваши устройства — сервер видит только шифртекст.',
                  style: DType.label.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (ctrl != null)
          WorkspaceCard(
            title: 'Проверенные устройства',
            description:
                // SEC-06: оговорка про группы обязана быть — привратник в них
                // не работает. Текст переписан, а не дополнен: ратчет
                // `desktop_l10n_ratchet_test` держит число зашитых русских
                // литералов, и две новые строки его подняли бы. Литералов
                // по-прежнему четыре.
                'Пока настройка включена, сообщения не уходят на '
                'неподтверждённые устройства собеседника. Это защита от '
                'подмены, но сообщение может не дойти, пока он не подтвердит '
                'новое. Только личная переписка: на группы не действует.',
            child: WorkspaceRow(
              label: 'Только проверенные устройства',
              description: ctrl.blockUnverified
                  ? 'Непроверенные устройства блокируются'
                  : 'Сообщения уходят на все устройства собеседника',
              trailing: WorkspaceSwitch(
                value: ctrl.blockUnverified,
                onChanged: (v) => unawaited(ctrl.setBlockUnverified(v)),
              ),
            ),
          ),
        if (ctrl != null) ...[
          _ScopeLockCard(
            controller: ctrl,
            scope: SecurityLockScope.app,
            title: 'Вход в приложение',
            // Замки хранятся на каждом устройстве отдельно — «общая с
            // телефоном» было неправдой (17.09.2026).
            description:
                'Пароль при открытии Secretly и после того, как окно было '
                'скрыто дольше минуты. Действует на этом компьютере.',
          ),
          const WorkspaceCard(child: _OfflineLockRow()),
          _ScopeLockCard(
            controller: ctrl,
            scope: SecurityLockScope.personal,
            title: l10n.desktopNotifDirectChats,
            description:
                'Отдельный пароль на категорию «Личные». Без него личные чаты '
                'открыты любому, у кого есть доступ к разблокированному '
                'компьютеру.',
          ),
        ],
        // Touch ID gate for THIS Mac only — deliberately separate from the
        // profile-wide scopes above: it protects this window, not the account.
        if (widget.lockService != null)
          _AppLockCard(service: widget.lockService!),
      ],
    );
  }
}

/// Срок без связи, после которого при запуске спрашивают пароль входа.
///
/// 🔴 Потерянный компьютер команду «отключить» не получит: она приходит с
/// сервера, а он до сервера не доходит. Срок же наступает сам.
class _OfflineLockRow extends StatefulWidget {
  const _OfflineLockRow();

  @override
  State<_OfflineLockRow> createState() => _OfflineLockRowState();
}

class _OfflineLockRowState extends State<_OfflineLockRow> {
  int _days = DesktopOfflineLock.defaultDays;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = DesktopOfflineLock.normalizeDays(
        prefs.getInt(DesktopOfflineLock.prefsDaysKey),
      );
      if (mounted) setState(() => _days = value);
    } catch (_) {
      // Настройка не прочиталась — остаётся значение по умолчанию.
    }
  }

  Future<void> _save(int days) async {
    setState(() => _days = days);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(DesktopOfflineLock.prefsDaysKey, days);
    } catch (_) {}
  }

  String _label(AppLocalizations l10n, int days) {
    switch (days) {
      case 0:
        return l10n.desktopOfflineLockNever;
      case 7:
        return l10n.desktopOfflineLockDays7;
      case 30:
        return l10n.desktopOfflineLockDays30;
      default:
        return l10n.desktopOfflineLockDays14;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceRow(
      label: l10n.desktopOfflineLockTitle,
      description: l10n.desktopOfflineLockDescription,
      trailing: DropdownButton<int>(
        value: _days,
        underline: const SizedBox.shrink(),
        onChanged: (v) {
          if (v == null) return;
          unawaited(_save(v));
        },
        items: [
          for (final days in DesktopOfflineLock.choices)
            DropdownMenuItem(value: days, child: Text(_label(l10n, days))),
        ],
      ),
    );
  }
}

/// Calls — who may reach you, and whether a screen share is accepted at all.
class _CallsPane extends StatefulWidget {
  const _CallsPane({this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;
  AppController? get controller => vm?.controller;
  @override
  State<_CallsPane> createState() => _CallsPaneState();
}

class _CallsPaneState extends State<_CallsPane> {
  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ctrl = widget.controller;
    if (ctrl == null) return const _PaneScaffold(children: []);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Звонки',
          child: Column(
            children: [
              WorkspaceRow(
                label: 'Звонки в приложении',
                description: 'Выключите, чтобы полностью отключить звонки',
                trailing: WorkspaceSwitch(
                  value: ctrl.callsEnabled,
                  onChanged: (v) => unawaited(ctrl.setCallsEnabled(v)),
                ),
              ),
              WorkspaceRow(
                label: 'Принимать входящие',
                description: ctrl.callsEnabled
                    ? 'Вам смогут звонить'
                    : 'Недоступно, пока звонки выключены',
                trailing: WorkspaceSwitch(
                  value: ctrl.incomingCallsEnabled && ctrl.callsEnabled,
                  onChanged: (v) {
                    // Nothing to accept when calls are off — flipping this
                    // would be a switch that visibly changes nothing.
                    if (!ctrl.callsEnabled) return;
                    unawaited(ctrl.setIncomingCallsEnabled(v));
                  },
                ),
              ),
              // SEC-10③, как на телефоне (`a4e3cf2e`): звонок только через
              // сервер, и собеседник не видит IP-адрес. Цена названа в
              // подписи. Настройка своя у каждого устройства (17.09.2026).
              WorkspaceRow(
                label: AppLocalizations.of(context)!.callsHideAddressTitle,
                description:
                    AppLocalizations.of(context)!.callsHideAddressSubtitle,
                trailing: WorkspaceSwitch(
                  value: ctrl.hideAddressInCalls,
                  onChanged: (v) => unawaited(ctrl.setHideAddressInCalls(v)),
                ),
              ),
            ],
          ),
        ),
        WorkspaceCard(
          title: 'Демонстрация экрана',
          description:
              'Приём чужой демонстрации — отдельное разрешение: на экране может '
              'оказаться то, чего вы не ожидали увидеть.',
          child: WorkspaceRow(
            label: 'Принимать демонстрацию экрана',
            trailing: WorkspaceSwitch(
              value: ctrl.incomingScreenShareEnabled,
              onChanged: (v) =>
                  unawaited(ctrl.setIncomingScreenShareEnabled(v)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Account — the profile fields plus the two ways out.
class _AccountPane extends StatefulWidget {
  const _AccountPane({this.vm, this.onOpenProfile});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel? vm;

  /// Открыть страницу профиля — см. [SettingsWorkspace.onOpenProfile].
  final VoidCallback? onOpenProfile;
  AppController? get controller => vm?.controller;
  @override
  State<_AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends State<_AccountPane> {
  Future<void> _copyId() async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    await Clipboard.setData(ClipboardData(text: ctrl.profileId));
    if (!mounted) return;
    DesktopSnackbar.show(
      context,
      message: 'Secretly ID скопирован',
      kind: DSnackKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm?.ticks ?? kDesktopNoTicks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = DColors.of(context);
    final ctrl = widget.controller;
    if (ctrl == null) return const _PaneScaffold(children: []);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Secretly ID',
          description:
              'Этим идентификатором делятся, чтобы вас нашли. Он не содержит '
              'ни номера телефона, ни почты.',
          child: WorkspaceRow(
            label: ctrl.profileId,
            icon: FluentIcons.fingerprint_24_regular,
            trailing: DesktopButton(
              label: 'Копировать',
              kind: DButtonKind.ghost,
              icon: FluentIcons.copy_24_regular,
              size: DButtonSize.small,
              onPressed: () => unawaited(_copyId()),
            ),
          ),
        ),
        // 🔴 Строка ОТКРЫВАЕТ профиль, а не рассказывает, где он.
        //
        // Здесь стояла всплывашка «Профиль — в левом нижнем углу, рядом с
        // аватаром»: строка с шевроном, которая ничего не открывает. Одна
        // такая строка учит не верить всем остальным шевронам в окне.
        //
        // Нет обработчика — нет и строки: указатель в никуда хуже отсутствия
        // указателя.
        if (widget.onOpenProfile != null)
          WorkspaceCard(
            title: 'Профиль',
            child: WorkspaceRow(
              label: 'Имя, фото, статус',
              description: 'Открыть страницу профиля',
              icon: FluentIcons.person_24_regular,
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.textSecondary,
              ),
              onTap: widget.onOpenProfile,
            ),
          ),
      ],
    );
  }
}

/// Configures one lock scope through the SHARED [AppSecurityManager].
///
/// Desktop had its own `DesktopAppLockService` — a boolean plus a grace timer,
/// with no scopes and no method choice. That left two real holes: the
/// personal-chats scope could not be turned ON from desktop at all (so a
/// profile that never configured it on the phone had personal chats ungated
/// here), and a lock configured on the phone was invisible in desktop settings.
///
/// This card drives the shared manager, so both devices see one state.
/// Password is the method offered: a pattern grid is a touch affordance, and
/// biometric alone is available through the existing Touch ID card.
class _ScopeLockCard extends StatefulWidget {
  const _ScopeLockCard({
    required this.controller,
    required this.scope,
    required this.title,
    required this.description,
  });

  final AppController controller;
  final SecurityLockScope scope;
  final String title;
  final String description;

  @override
  State<_ScopeLockCard> createState() => _ScopeLockCardState();
}

class _ScopeLockCardState extends State<_ScopeLockCard> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.security.changed.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  AppSecurityManager get _sec => widget.controller.security;

  Future<void> _enable() async {
    final password = await _promptPassword(
      title: 'Пароль для «${widget.title}»',
      hint: 'Минимум 4 символа',
      confirm: true,
    );
    if (password == null || !mounted) return;
    try {
      await _sec.setPasswordLock(
        scope: widget.scope,
        password: password,
        // Desktop hides to the tray rather than quitting, so a lock that only
        // re-armed on quit would effectively never re-arm.
        relockOnBackground: true,
        backgroundGraceSeconds: 60,
        allowBiometricUnlock: true,
      );
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Защита включена',
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось включить: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _disable() async {
    // Turning protection OFF must prove you can already get IN — otherwise
    // anyone at an unlocked desktop could strip the lock from the phone too,
    // since the scope config is shared.
    final ok = await ensureSecurityScopeUnlocked(
      context: context,
      controller: widget.controller,
      scope: widget.scope,
      forcePrompt: true,
    );
    if (!ok || !mounted) return;
    try {
      await _sec.disableLock(widget.scope);
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Защита выключена',
        kind: DSnackKind.info,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось выключить: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _changePassword() async {
    final ok = await ensureSecurityScopeUnlocked(
      context: context,
      controller: widget.controller,
      scope: widget.scope,
      forcePrompt: true,
    );
    if (!ok || !mounted) return;
    await _enable();
  }

  Future<String?> _promptPassword({
    required String title,
    required String hint,
    bool confirm = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final result = await DesktopDialog.show<String>(
      context,
      title: title,
      size: DDialogSize.small,
      body: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopTextField(
              controller: first,
              hintText: hint,
              obscureText: true,
              autofocus: true,
            ),
            if (confirm) ...[
              const SizedBox(height: DSpace.s),
              DesktopTextField(
                controller: second,
                hintText: 'Повторите пароль',
                obscureText: true,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: DSpace.s),
              Text(
                error!,
                style: DType.caption.copyWith(color: DColors.of(ctx).danger),
              ),
            ],
            const SizedBox(height: DSpace.m),
            DesktopButton(
              label: 'Сохранить',
              expand: true,
              onPressed: () {
                final a = first.text;
                final b = second.text;
                if (a.length < 4) {
                  setLocal(() => error = 'Минимум 4 символа');
                  return;
                }
                if (confirm && a != b) {
                  setLocal(() => error = 'Пароли не совпадают');
                  return;
                }
                Navigator.of(ctx).maybePop(a);
              },
            ),
          ],
        ),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final enabled = _sec.isEnabled(widget.scope);
    final cfg = _sec.scopeConfig(widget.scope);
    return WorkspaceCard(
      title: widget.title,
      description: widget.description,
      child: Column(
        children: [
          WorkspaceRow(
            label: 'Защита паролем',
            description: enabled
                ? (cfg.method == SecurityLockMethod.password
                      ? 'Включена — пароль'
                      : 'Включена')
                : 'Выключена',
            trailing: WorkspaceSwitch(
              value: enabled,
              onChanged: (v) => unawaited(v ? _enable() : _disable()),
            ),
          ),
          if (enabled) ...[
            WorkspaceRow(
              label: 'Сменить пароль',
              icon: FluentIcons.key_24_regular,
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.textSecondary,
              ),
              onTap: () => unawaited(_changePassword()),
            ),
            WorkspaceRow(
              label: 'Заблокировать сейчас',
              icon: FluentIcons.lock_closed_24_regular,
              trailing: DesktopButton(
                label: 'Заблокировать',
                kind: DButtonKind.tonal,
                size: DButtonSize.small,
                onPressed: () => unawaited(_sec.lockNow(widget.scope)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Blocked profiles — the list, and the way back out of it.
///
/// Desktop had no blocked-users surface at all: you could block someone from a
/// chat's context menu and then had no way to see who was blocked or to undo
/// it. A block you cannot review is a setting the user cannot audit, which is
/// the wrong property for a safety feature.
class _BlockedPane extends StatefulWidget {
  const _BlockedPane({required this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  @override
  State<_BlockedPane> createState() => _BlockedPaneState();
}

class _BlockedPaneState extends State<_BlockedPane> {
  final Map<String, String> _titles = <String, String>{};

  /// The blocked list, reloaded once per settled burst of controller ticks and
  /// republished only when it differs.
  ///
  /// This used to re-run `listBlockedProfiles()` plus a title lookup per id on
  /// EVERY `changed` tick — a database read and N name resolutions for a list
  /// that changes when someone is blocked, which is approximately never.
  late final DesktopSelector<List<String>> _blocked;

  @override
  void initState() {
    super.initState();
    _blocked = widget.vm.select<List<String>>(
      debugName: 'blockedProfiles',
      initial: const <String>[],
      load: _loadBlocked,
      signature: (ids) => ids.join(','),
    );
  }

  @override
  void dispose() {
    _blocked.dispose();
    super.dispose();
  }

  Future<List<String>> _loadBlocked() async {
    final ids = await widget.controller.listBlockedProfiles();
    // Resolve display names so the list is people, not opaque identifiers.
    // Cached per id: a name that fails to resolve falls back to the id and is
    // still cached, matching the previous behaviour.
    for (final id in ids) {
      if (_titles.containsKey(id)) continue;
      try {
        _titles[id] = await widget.controller.resolveConvoTitle(id);
      } catch (_) {
        _titles[id] = id;
      }
    }
    return ids;
  }

  Future<void> _unblock(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _titles[id] ?? id;
    final ok = await DesktopDialog.show<bool>(
      context,
      title: l10n.desktopUnblockTitle(name),
      size: DDialogSize.small,
      body: Text(
        l10n.desktopUnblockBody,
        style: DType.body.copyWith(color: DColors.of(context).textSecondary),
      ),
      primary: DDialogAction(
        label: l10n.desktopUnblockAction,
        onPressed: () => Navigator.of(context).maybePop(true),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(false),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.controller.setProfileBlocked(
        profileId: id,
        blocked: false,
        // Unblocking must never delete anything — the destructive option
        // belongs to blocking, not to undoing it.
        deleteChatHistory: false,
      );
      // Don't wait out the debounce for a change the user just made.
      await _blocked.refresh();
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: '$name разблокирован',
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось разблокировать: $e',
        kind: DSnackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _blocked,
      builder: (context, ids, _) => _buildBody(context, ids),
    );
  }

  Widget _buildBody(BuildContext context, List<String> ids) {
    final c = DColors.of(context);
    // An empty list before the first load means "still reading", not "nobody
    // is blocked" — saying the latter would be untrue for the length of the
    // query.
    if (!_blocked.hasLoaded) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(c.accentPrimary),
          ),
        ),
      );
    }
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Заблокированные',
          description: ids.isEmpty
              ? 'Список пуст. Заблокировать можно из меню чата.'
              : 'Эти люди не могут писать вам и звонить.',
          child: ids.isEmpty
              ? Row(
                  children: [
                    Icon(
                      FluentIcons.checkmark_circle_24_regular,
                      size: 18,
                      color: c.success,
                    ),
                    const SizedBox(width: DSpace.m),
                    Expanded(
                      child: Text(
                        'Никто не заблокирован',
                        style: DType.label.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final id in ids)
                      WorkspaceRow(
                        label: _titles[id] ?? id,
                        description: (_titles[id] ?? id) == id ? null : id,
                        icon: FluentIcons.person_prohibited_24_regular,
                        trailing: DesktopButton(
                          label: 'Разблокировать',
                          kind: DButtonKind.tonal,
                          size: DButtonSize.small,
                          onPressed: () => unawaited(_unblock(id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Safe Backup — the only mechanism that can restore message history.
///
/// Desktop previously exposed just the server-copy password, so the settings
/// that decide WHETHER a backup happens at all — auto on/off, where it goes,
/// how often, whether media is included — were invisible here. Worse, the
/// health of that backup was invisible too: a user could sit for weeks on a
/// failing backup and only discover it when they needed to restore.
///
/// Health is therefore the FIRST thing in this pane, stated plainly, and it
/// leads with the bad news when there is any.
class _BackupPane extends StatefulWidget {
  const _BackupPane({required this.vm});

  /// The controller seam. `controller` below is derived from it, so every
  /// `widget.controller` use site in this pane keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  @override
  State<_BackupPane> createState() => _BackupPaneState();
}

class _BackupPaneState extends State<_BackupPane> {
  static const List<int> _intervals = <int>[360, 720, 1440, 10080];

  static String _intervalLabel(int minutes, AppLocalizations l10n) {
    switch (minutes) {
      case 360:
        return l10n.desktopBackupEvery6h;
      case 720:
        return l10n.desktopBackupEvery12h;
      case 1440:
        return l10n.desktopBackupDaily;
      default:
        return l10n.desktopBackupWeekly;
    }
  }

  ({String text, Color color, IconData icon}) _health(
    DColorSet c,
    AppLocalizations l10n,
  ) {
    switch (widget.controller.safeBackupHealth) {
      case SafeBackupHealth.off:
        return (
          text: l10n.desktopBackupOffWarning,
          color: c.warning,
          icon: FluentIcons.warning_24_filled,
        );
      case SafeBackupHealth.pending:
        return (
          text: l10n.desktopBackupNeverRan,
          color: c.textSecondary,
          icon: FluentIcons.clock_24_regular,
        );
      case SafeBackupHealth.failing:
        return (
          text: widget.controller.safeBackupLastAutoError.isNotEmpty
              ? l10n.desktopBackupLastFailedWith(
                  widget.controller.safeBackupLastAutoError,
                )
              : l10n.desktopBackupLastFailed,
          color: c.danger,
          icon: FluentIcons.error_circle_24_filled,
        );
      case SafeBackupHealth.stale:
        return (
          text: l10n.desktopBackupStale,
          color: c.warning,
          icon: FluentIcons.warning_24_regular,
        );
      case SafeBackupHealth.ok:
        return (
          text: l10n.desktopBackupFresh,
          color: c.success,
          icon: FluentIcons.checkmark_circle_24_filled,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // One rebuild per settled burst of controller ticks, through the shared
    // hub, instead of this pane owning a `changed` subscription and rebuilding
    // on every tick — `changed` fires constantly on a paired client. See
    // [DesktopSelectorHub.ticks].
    return ValueListenableBuilder<int>(
      valueListenable: widget.vm.ticks,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final ctrl = widget.controller;
    final h = _health(c, l10n);
    final auto = ctrl.safeBackupAutoEnabled;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopBackupState,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(h.icon, size: 18, color: h.color),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Text(
                  h.text,
                  style: DType.label.copyWith(
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopBackupAutomatic,
          description:
              l10n.desktopBackupAutomaticHint,
          child: Column(
            children: [
              WorkspaceRow(
                label: l10n.desktopBackupCreateAuto,
                trailing: WorkspaceSwitch(
                  value: auto,
                  onChanged: (v) => unawaited(ctrl.setSafeBackupAutoEnabled(v)),
                ),
              ),
              if (auto) ...[
                WorkspaceRow(
                  label: l10n.desktopBackupUploadServer,
                  description: l10n.desktopBackupUploadServerHint,
                  trailing: WorkspaceSwitch(
                    value: ctrl.safeBackupAutoServerEnabled,
                    onChanged: (v) =>
                        unawaited(ctrl.setSafeBackupAutoServerEnabled(v)),
                  ),
                ),
                WorkspaceRow(
                  label: l10n.desktopBackupKeepLocal,
                  description: l10n.desktopBackupKeepLocalHint,
                  trailing: WorkspaceSwitch(
                    value: ctrl.safeBackupAutoDeviceEnabled,
                    onChanged: (v) =>
                        unawaited(ctrl.setSafeBackupAutoDeviceEnabled(v)),
                  ),
                ),
                WorkspaceRow(
                  label: l10n.desktopBackupIncludeMedia,
                  description: l10n.desktopBackupIncludeMediaHint,
                  trailing: WorkspaceSwitch(
                    value: ctrl.safeBackupIncludeMedia,
                    onChanged: (v) =>
                        unawaited(ctrl.setSafeBackupIncludeMedia(v)),
                  ),
                ),
                WorkspaceRow(
                  label: l10n.desktopBackupFrequency,
                  description: _intervalLabel(ctrl.safeBackupAutoIntervalMin, l10n),
                  icon: FluentIcons.timer_24_regular,
                  trailing: DropdownButton<int>(
                    value: _intervals.contains(ctrl.safeBackupAutoIntervalMin)
                        ? ctrl.safeBackupAutoIntervalMin
                        : _intervals[2],
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in _intervals)
                        DropdownMenuItem(
                          value: m,
                          child: Text(_intervalLabel(m, l10n)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      unawaited(ctrl.setSafeBackupAutoIntervalMinutes(v));
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (auto &&
            !ctrl.safeBackupAutoServerEnabled &&
            !ctrl.safeBackupAutoDeviceEnabled)
          WorkspaceCard(
            title: l10n.desktopBackupNowhereTitle,
            child: Row(
              children: [
                Icon(FluentIcons.warning_24_filled, size: 18, color: c.warning),
                const SizedBox(width: DSpace.m),
                Expanded(
                  child: Text(
                    l10n.desktopBackupNowhereHint,
                    style: DType.label.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: DSpace.m),
        // 🔴 КЛЮЧ ВОССТАНОВЛЕНИЯ — ЕДИНСТВЕННОЕ, ЧТО СПАСАЕТ ПРИ ПОТЕРЕ ВСЕГО.
        //
        // На десктопе его не было НИ ОДНОЙ точки входа, хотя резервные копии
        // здесь есть давно. Разница между ними существенная: копия это данные,
        // а ключ — способ вернуть себе САМ ПРОФИЛЬ, когда устройств не
        // осталось. Человек, у которого есть копия и нет ключа, не восстановит
        // ничего.
        //
        // Экран показа ключа берём у телефона целиком: там уже продуманы
        // предупреждения и вид «бумажного» ключа, а сверх этого экран ничего не
        // делает — ему передают готовую строку.
        WorkspaceCard(
          title: l10n.desktopBackupRecoveryKey,
          child: WorkspaceRow(
            icon: FluentIcons.key_24_regular,
            label: l10n.desktopBackupCreateRecoveryKey,
            description: l10n.desktopBackupRecoveryKeyHint,
            onTap: () => unawaited(_exportRecoveryKit()),
          ),
        ),
      ],
    );
  }

  /// Создаёт ключ восстановления и показывает его мобильным экраном.
  ///
  /// Последовательность повторяет телефон: пароль с подтверждением →
  /// `createRecoveryKitPayload` → показ. Пароль здесь не тот, что от
  /// приложения: им шифруется сам ключ, и без него ключ бесполезен.
  Future<void> _exportRecoveryKit() async {
    final l10n = AppLocalizations.of(context)!;
    final password = await _promptRecoveryPassword();
    if (password == null || password.isEmpty || !mounted) return;
    String payload;
    try {
      payload = await widget.controller.createRecoveryKitPayload(
        password: password,
      );
    } catch (e) {
      if (!mounted) return;
      // «Bad state: …» человеку ничего не сообщает — снимаем техническую
      // приставку, как это уже делает панель серверной копии.
      var text = e.toString();
      for (final prefix in const ['Bad state: ', 'StateError: ']) {
        if (text.startsWith(prefix)) text = text.substring(prefix.length);
      }
      DesktopSnackbar.show(
        context,
        message: l10n.desktopBackupKeyFailed(text),
        kind: DSnackKind.error,
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecoveryKitScreen(payload: payload),
      ),
    );
  }

  /// Пароль для ключа — с подтверждением и ПРОВЕРКОЙ ПО ОБЩЕЙ ПОЛИТИКЕ.
  ///
  /// 🔴 Первая версия проверки не делала вовсе — и живая проверка это сразу
  /// показала: слабый пароль принимался окном, а отказ прилетал потом сырой
  /// английской строкой «Bad state: Password must be at least 8 characters».
  /// То есть требования человек узнавал ПОСЛЕ отказа и на чужом языке.
  ///
  /// Требования те же, что у резервной копии (`BackupPasswordPolicy`): ключ и
  /// копия защищают одно и то же, и разные правила для них были бы просто
  /// разными правилами без причины.
  ///
  /// 🔴 Подтверждение обязательно. Опечатка здесь не всплывёт никогда: ключ
  /// создастся, человек его сохранит, и узнает о расхождении в тот
  /// единственный момент, когда ключ понадобится, — когда устройств уже не
  /// осталось.
  Future<String?> _promptRecoveryPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final first = TextEditingController();
    final again = TextEditingController();
    String? error;

    final result = await DesktopDialog.show<String>(
      context,
      title: l10n.desktopBackupKeyPassword,
      size: DDialogSize.small,
      body: StatefulBuilder(
        builder: (ctx, setLocal) {
          final c = DColors.of(ctx);
          void submit() {
            final a = first.text;
            final b = again.text;
            final validation = BackupPasswordPolicy.validate(a);
            if (!validation.isValid) {
              setLocal(() => error = validation.problemText(isRu: true));
              return;
            }
            if (a != b) {
              setLocal(() => error = l10n.desktopBackupPasswordsDiffer);
              return;
            }
            Navigator.of(ctx).maybePop(a);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.desktopBackupKeyPasswordHint,
                style: DType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DSpace.m),
              DesktopTextField(
                controller: first,
                hintText: l10n.password,
                obscureText: true,
                autofocus: true,
              ),
              const SizedBox(height: DSpace.s),
              DesktopTextField(
                controller: again,
                hintText: l10n.desktopBackupPasswordAgain,
                obscureText: true,
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: DSpace.s),
              // Требования видны СРАЗУ, а не после отказа: человек подбирает
              // пароль один раз, а не угадывает правила.
              Text(
                error ?? BackupPasswordPolicy.requirementsText(isRu: true),
                style: DType.caption.copyWith(
                  color: error != null ? c.danger : c.textDisabled,
                ),
              ),
              const SizedBox(height: DSpace.m),
              Align(
                alignment: Alignment.centerRight,
                child: DesktopButton(
                  label: l10n.desktopListCreate,
                  kind: DButtonKind.filled,
                  onPressed: submit,
                ),
              ),
            ],
          );
        },
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    first.dispose();
    again.dispose();
    return result;
  }
}

/// End-to-end encrypted support chat.
///
/// Desktop had no support surface at all, while its own lock screen tells a
/// stuck user to «обратиться в поддержку» — advice that led nowhere. The
/// crypto (SupportSeal) and the whole controller API are platform-neutral, so
/// this is UI only: the relay stores ciphertext, and replies are decrypted
/// here with a seed that never leaves the device.
class _SupportPane extends StatefulWidget {
  const _SupportPane({required this.controller});
  final AppController controller;
  @override
  State<_SupportPane> createState() => _SupportPaneState();
}

/// Одна запись нити: моё письмо или ответ поддержки.
typedef _SupportEntry = ({
  bool mine,
  String text,
  int tsMs,
  String? attachment,
});

class _SupportPaneState extends State<_SupportPane> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final DesktopSupportSentStore _store = DesktopSupportSentStore(
    read: widget.controller.localValueGet,
    write: widget.controller.localValueSet,
  );

  List<({String text, int tsMs, int seq})> _replies = const [];

  /// Свои письма — из зашифрованной базы, см. [DesktopSupportSentStore].
  List<DesktopSupportSent> _sent = const <DesktopSupportSent>[];

  int _cursor = 0;
  bool _loading = true;
  bool _sending = false;
  bool _attaching = false;
  Timer? _poll;
  String? _error;
  DesktopSupportAttachment? _attachment;

  @override
  void initState() {
    super.initState();
    // Кнопка «Отправить» должна гаснуть на пустом поле, а не молча ничего не
    // делать: молчание читается как поломка.
    _text.addListener(_onTextChanged);
    _load();
    // Ответ приходит, пока панель открыта, и до перезахода его не видно —
    // человек сидит перед ним и ждёт. Телефон опрашивает так же.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_sending) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final mine = await _store.load();
    if (mounted) setState(() => _sent = mine);
    try {
      final res = await widget.controller.fetchSupportReplies(_cursor);
      if (!mounted) return;
      setState(() {
        // The cursor advances even past an undecryptable reply, so appending
        // is safe: the same message can never arrive twice.
        _replies = [..._replies, ...res.replies];
        _cursor = res.cursor;
        _loading = false;
      });
      // Reading the thread here is what clears the unread badge — otherwise
      // the badge would keep pointing at a conversation the user is looking at.
      await widget.controller.markSupportRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Нить целиком, по времени: своё и ответы вперемешку, как в переписке.
  List<_SupportEntry> _thread() {
    final items = <_SupportEntry>[
      for (final m in _sent)
        (
          mine: true,
          text: m.text,
          tsMs: m.tsMs,
          attachment: m.attachmentName,
        ),
      for (final r in _replies)
        (mine: false, text: r.text, tsMs: r.tsMs, attachment: null),
    ]..sort((a, b) => a.tsMs.compareTo(b.tsMs));
    return items;
  }

  Future<void> _pickAttachment() async {
    if (_attaching || _sending) return;
    setState(() {
      _attaching = true;
      _error = null;
    });
    final paths = await pickDesktopAttachments(media: false);
    if (!mounted) return;
    if (paths.isEmpty) {
      setState(() => _attaching = false);
      return;
    }
    final res = await prepareDesktopSupportAttachment(paths.first);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _attaching = false;
      if (res.ok) {
        _attachment = res.file;
        return;
      }
      _error = res.problem == DesktopSupportAttachmentProblem.tooLarge
          ? l10n.desktopSupportTooLarge(_sizeText(context, _limitBytes))
          : l10n.desktopSupportUnreadable;
    });
  }

  static const int _limitBytes = kDesktopSupportAttachmentMaxBytes;

  /// «1,4 МБ» — разделитель берётся из языка окна, единица из перевода.
  String _sizeText(BuildContext context, int bytes) {
    final l10n = AppLocalizations.of(context)!;
    final mb = bytes / (1024 * 1024);
    final whole = mb >= 10 || mb == mb.roundToDouble();
    final fmt = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: whole ? 0 : 1,
    );
    return l10n.desktopSupportMegabytes(fmt.format(mb));
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final att = _attachment;
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.controller.submitSupportMessage(
        text,
        attachmentName: att?.name,
        attachmentMime: att?.mime,
        attachmentBytes: att?.bytes,
      );
      await widget.controller.noteSupportMessageSent();
      final saved = await _store.append(
        DesktopSupportSent(
          text: text,
          tsMs: DateTime.now().millisecondsSinceEpoch,
          attachmentName: att?.name,
        ),
      );
      if (!mounted) return;
      _text.clear();
      setState(() {
        _sending = false;
        _sent = saved;
        _attachment = null;
      });
      DesktopSnackbar.show(
        context,
        message: 'Сообщение отправлено',
        kind: DSnackKind.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        // `submitSupportMessage` throws StateError when support is switched
        // off server-side or the relay is unreachable — say which, rather
        // than leaving the message apparently sent.
        _error = 'Не удалось отправить. Проверьте подключение.';
      });
    }
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final available = widget.controller.supportConfig.isUsable;
    if (!available) {
      return _PaneScaffold(
        children: [
          WorkspaceCard(
            title: 'Поддержка недоступна',
            child: Text(
              'Служба поддержки сейчас отключена. Попробуйте позже или '
              'напишите с телефона.',
              style: DType.label.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ),
        ],
      );
    }
    final thread = _thread();
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Переписка с поддержкой',
          description:
              'Сообщения шифруются на вашем устройстве. Сервер хранит только '
              'шифртекст — прочитать переписку может лишь поддержка.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DSpace.l),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                      ),
                    ),
                  ),
                )
              else if (thread.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DSpace.m),
                  child: Text(
                    'Ответов пока нет. Опишите проблему — ответ придёт сюда.',
                    style: DType.label.copyWith(color: c.textSecondary),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    itemCount: thread.length,
                    itemBuilder: (ctx, i) => _bubble(thread[i], c, l10n),
                  ),
                ),
            ],
          ),
        ),
        WorkspaceCard(
          title: 'Написать в поддержку',
          description:
              'К сообщению автоматически прикладываются версия сборки и '
              'идентификатор устройства — без них воспроизвести проблему почти '
              'невозможно.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopTextField(
                controller: _text,
                hintText: 'Опишите, что произошло',
                maxLines: 6,
                minLines: 3,
              ),
              const SizedBox(height: DSpace.m),
              _attachmentRow(c, l10n),
              if (_error != null) ...[
                const SizedBox(height: DSpace.s),
                Text(_error!, style: DType.caption.copyWith(color: c.danger)),
              ],
              const SizedBox(height: DSpace.m),
              DesktopButton(
                label: _sending ? 'Отправляем…' : 'Отправить',
                icon: FluentIcons.send_24_regular,
                onPressed: (_sending || _text.text.trim().isEmpty)
                    ? null
                    : () => unawaited(_send()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Пузырь нити. Своё письмо — цветом отклика, ответ — как карточка.
  Widget _bubble(_SupportEntry e, DColorSet c, AppLocalizations l10n) {
    final mine = e.mine;
    return Container(
      margin: const EdgeInsets.only(bottom: DSpace.s),
      padding: const EdgeInsets.all(DSpace.m),
      decoration: BoxDecoration(
        color: mine ? c.accentPrimary.withValues(alpha: 0.10) : c.elevated,
        borderRadius: BorderRadius.circular(DRadii.md),
        border: Border.all(
          color: mine ? c.accentPrimary.withValues(alpha: 0.35) : c.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                l10n.desktopSupportYou,
                style: DType.caption.copyWith(
                  color: c.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(e.text, style: DType.body.copyWith(color: c.textPrimary)),
          if ((e.attachment ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.attach_24_regular,
                  size: 14,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    e.attachment!,
                    overflow: TextOverflow.ellipsis,
                    style: DType.caption.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _time(e.tsMs),
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Вложение: кнопка «прикрепить», а когда файл выбран — он сам и «убрать».
  Widget _attachmentRow(DColorSet c, AppLocalizations l10n) {
    final att = _attachment;
    if (att == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopButton(
            label: l10n.desktopSupportAttach,
            icon: FluentIcons.attach_24_regular,
            kind: DButtonKind.ghost,
            onPressed: (_attaching || _sending)
                ? null
                : () => unawaited(_pickAttachment()),
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            l10n.desktopSupportAttachHint(_sizeText(context, _limitBytes)),
            style: DType.caption.copyWith(color: c.textSecondary, height: 1.35),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: DSpace.s,
          ),
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(DRadii.sm),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                att.isImage
                    ? FluentIcons.image_24_regular
                    : FluentIcons.document_24_regular,
                size: 16,
                color: c.textSecondary,
              ),
              const SizedBox(width: DSpace.s),
              Expanded(
                child: Text(
                  att.name,
                  overflow: TextOverflow.ellipsis,
                  style: DType.label.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(width: DSpace.s),
              Text(
                _sizeText(context, att.bytes.length),
                style: DType.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(width: DSpace.s),
              DesktopTooltip(
                message: l10n.desktopSupportRemoveAttachment,
                child: HoverListener(
                  onTap: _sending ? null : () => setState(() => _attachment = null),
                  builder: (ctx, hovered, pressed) => Icon(
                    FluentIcons.dismiss_24_regular,
                    size: 16,
                    color: hovered ? c.danger : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (att.shrunk) ...[
          const SizedBox(height: DSpace.xs),
          Text(
            l10n.desktopSupportShrunk,
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}
