// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert' show LineSplitter, utf8;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../security/backup_password_policy.dart';
import '../../../version/app_package_info.dart';
import '../../../calls/call_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../storage/cache_manager.dart';
import '../app/desktop_offline_lock.dart';
import '../../../sync/peer_history_service.dart';
import '../../../security/app_security_manager.dart'
    show AppSecurityManager, SecurityLockMethod, SecurityLockScope;
import '../../../l10n/app_localizations.dart';
import '../../security_lock_flow.dart' show ensureSecurityScopeUnlocked;
import '../app/desktop_app_view_model.dart';
import '../app/recovery_kit_export.dart';
import '../app/desktop_selector.dart';
import '../design/tokens.dart';
import 'media_devices_pane.dart';
import 'ringtone_card.dart';
import 'sound_picker.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_snackbar.dart';
import '../primitives/hover_listener.dart';
import '../primitives/desktop_text_field.dart';
import '../../widgets/support_badge.dart';
import '../services/desktop_app_lock_service.dart';
import '../services/desktop_login_item_service.dart';
import '../services/desktop_notification_service.dart';
import '../primitives/desktop_tooltip.dart';
import '../services/desktop_global_hotkey_service.dart';
import '../services/desktop_diag_file_log.dart';
import '../services/desktop_screen_privacy.dart';
import '../services/desktop_ui_prefs.dart';
import '../services/desktop_update_service.dart';
import '../services/desktop_window_activity.dart';
import '../app/desktop_media_send.dart' show pickDesktopAttachments;
import '../shell/shortcuts_help.dart' show ShortcutsList;
import 'support_attachment.dart';
import 'support_sent.dart';
import 'delivery_diagnostics.dart';
import 'appearance_pane.dart';
import 'settings_style.dart';
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
  // 🔴 Двойной щелчок открывал два окна, а два «Выйти» — два стирания разом
  // (30.09.2026). Замок — на контроллер: после перезапуска он новый.
  if (_signOutBusy[controller] == true) return;
  _signOutBusy[controller] = true;
  try {
    final ok = await DesktopDialog.show<bool>(
      context,
      title: l10n.desktopSettingsSignOutTitle,
      size: DDialogSize.small,
      body: _SignOutBody(controller: controller),
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
        message: l10n.desktopSettingsSignOutFailed(desktopErrorText(e)),
        kind: DSnackKind.error,
      );
    }
  } finally {
    _signOutBusy[controller] = null;
  }
}

/// Выход, который уже спрашивается или идёт.
final Expando<bool> _signOutBusy = Expando<bool>('signOutBusy');

/// Что останется после выхода — по тому, есть ли у аккаунта ДРУГИЕ устройства.
///
/// 🔴 ТЕКСТ ОБЕЩАЛ ТЕЛЕФОН ВСЕГДА (30.09.2026): «аккаунт и история на телефоне
/// не пострадают». Аккаунт, заведённый на самом компьютере, телефона не имеет,
/// и выход без набора восстановления теряет его насовсем. Устройства аккаунта
/// знает сервер ключей; пока он не ответил (или не ответит вовсе) — осторожный
/// текст про оба случая.
class _SignOutBody extends StatefulWidget {
  const _SignOutBody({required this.controller});

  final AppController controller;

  @override
  State<_SignOutBody> createState() => _SignOutBodyState();
}

class _SignOutBodyState extends State<_SignOutBody> {
  /// `null` — не знаем, `true` — есть другие устройства, `false` — только этот.
  bool? _others;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final me = widget.controller.deviceId.trim();
      final ids = (await widget.controller.listMyDeviceIds().timeout(
        const Duration(seconds: 8),
      )).map((id) => id.trim()).toList();
      final others = ids.any((id) => id.isNotEmpty && id != me)
          ? true
          // Себя в списке нет — ответу верить нельзя.
          : (ids.contains(me) ? false : null);
      if (mounted) setState(() => _others = others);
    } catch (_) {
      // Не узнали — остаётся осторожный текст.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final others = _others;
    return Text(
      others == null
          ? l10n.desktopSettingsSignOutBodyUnknown
          : (others
                ? l10n.desktopSettingsSignOutBody
                : l10n.desktopSettingsSignOutBodyOnlyDevice),
      style: DType.body.copyWith(
        color: others == false ? c.danger : c.textSecondary,
      ),
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
    // 🔴 СЕРАЯ ГАММА МАКЕТА — ДЛЯ ВСЕГО ОКНА НАСТРОЕК РАЗОМ (29.09.2026):
    // подмена палитры одна на все семнадцать разделов, см. [SettingsScope].
    return SettingsScope.wrap(
      context,
      child: WorkspaceLayout(
      title: AppLocalizations.of(context)!.desktopSettingsTitle,
      onClose: onClose,
      initialIndex: initial < 0 ? 0 : initial,
      sections: sections,
      // 🔴 ПОЧЕМУ У НАСТРОЕК ЕСТЬ ПРЕДЕЛ ШИРИНЫ, А У ПЕРЕПИСКИ НЕТ.
      //
      // Переписка от ширины ВЫИГРЫВАЕТ: больше сообщений видно разом. Строка
      // настройки не выигрывает ничего — у неё слева подпись, справа
      // переключатель, и всё, что даёт лишняя ширина, это расстояние между
      // ними. На мониторе владельца (3440 точек) оно доходило до полуметра:
      // подпись «Отправлять по Enter» у одного края, переключатель у другого,
      // и чтобы понять, что чем управляет, приходилось вести глазами по
      // пустоте. Отсюда и ощущение «страница выглядит огромной».
      //
      // 760 выбрано по двум измеримым вещам, а не на глаз. Первое: при боковых
      // полях по 20 точек остаётся 720 полезной ширины, и сетка обоев
      // «Оформления» (плитка не шире 200, зазор 8) держит ЧЕТЫРЕ колонки по
      // 174 — на 700 их остаётся три, и половина набора уезжает под прокрутку.
      // Второе: строка настройки при такой ширине читается одним движением
      // глаз, подпись и переключатель остаются в одном поле зрения.
      contentMaxWidth: 760,
      // 🔴 248, А НЕ 232 ИЗ МАКЕТА — ИЗ-ЗА УКРАИНСКОГО. Самая длинная
      // подпись раздела среди восьми языков — «Видалити обліковий запис»,
      // 24 знака; при 232 она обрывалась бы многоточием, а обрезанный «Удалить
      // аккаунт» — ровно та строка, которую нельзя оставлять недочитанной.
      // Измеряет `desktop_settings_layout_test`.
      sidebarWidth: 248,
      // 🔴 Единственный выход из аккаунта — здесь, внизу боковой колонки, как
      // в макете. Раньше он жил в двух разных панелях с разными текстами
      // подтверждения; см. [showSignOutDialog].
      footer: controller == null
          ? null
          : _SidebarFooter(controller: controller),
      ),
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
          tint: DIconTint.amber,
          icon: FluentIcons.settings_24_regular,
          label: l10n.desktopSettingsGeneralLabel,
          subtitle: l10n.desktopSettingsGeneralSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsGeneralKeywords),
          builder: (ctx) => _GeneralPane(controller: controller),
        ),
        WorkspaceSection(
          id: 'appearance',
          tint: DIconTint.orange,
          icon: FluentIcons.color_24_regular,
          label: l10n.desktopSettingsAppearanceLabel,
          subtitle: l10n.desktopSettingsAppearanceSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsAppearanceKeywords),
          // ◆ Макет владельца (29.09.2026): вкладки, готовые наборы и живой
          // предпросмотр справа — поэтому своя шапка и своя ширина.
          ownHeader: true,
          contentMaxWidth: kAppearancePaneMaxWidth,
          builder: (ctx) => DesktopAppearancePane(
            vm: vm,
            title: l10n.desktopSettingsAppearanceLabel,
            subtitle: l10n.desktopSettingsAppearanceSubtitle,
            icon: FluentIcons.color_24_regular,
            tint: DIconTint.orange,
          ),
        ),
        // 🔴 Справка о клавишах была доступна ТОЛЬКО комбинацией Cmd+/ — то
        // есть её видел лишь тот, кто эту комбинацию уже знает. Справка,
        // спрятанная за тем, что она объясняет. Тот же список теперь есть
        // разделом настроек; окно по Cmd+/ никуда не делось и рисует его же.
        WorkspaceSection(
          id: 'shortcuts',
          tint: DIconTint.purple,
          icon: FluentIcons.keyboard_24_regular,
          label: l10n.desktopSettingsShortcutsLabel,
          subtitle: l10n.desktopSettingsShortcutsSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsShortcutsKeywords),
          builder: (ctx) => const _ShortcutsPane(),
        ),
        WorkspaceSection(
          id: 'power',
          tint: DIconTint.green,
          icon: FluentIcons.flash_24_regular,
          label: l10n.desktopSettingsPowerLabel,
          subtitle: l10n.desktopSettingsPowerSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsPowerKeywords),
          builder: (ctx) => _PowerPane(vm: vm),
        ),
        WorkspaceSection(
          id: 'notifications',
          tint: DIconTint.red,
          icon: FluentIcons.alert_24_regular,
          label: l10n.desktopSettingsNotificationsLabel,
          subtitle: l10n.desktopSettingsNotificationsSubtitle,
          group: l10n.desktopSettingsGroupApp,
          keywords: _keywords(l10n.desktopSettingsNotificationsKeywords),
          // 🔴 ОТМЕТКА В СПИСКЕ, А НЕ ТОЛЬКО ВНУТРИ РАЗДЕЛА.
          //
          // Про запрет уведомлений человек узнаёт ровно тогда, когда открывает
          // «Уведомления», — а открывает он их только если уже заподозрил
          // неладное. То есть узнаёт последним и случайно. Точка в строке
          // видна сразу, как только он вообще зашёл в настройки.
          trailing: const _NotificationsAlertDot(),
          builder: (ctx) => _NotificationsPane(vm: vm),
        ),
        WorkspaceSection(
          id: 'calls',
          tint: DIconTint.cyan,
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
          tint: DIconTint.blue,
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
          tint: DIconTint.green,
          icon: FluentIcons.eye_24_regular,
          label: l10n.desktopSettingsPrivacyLabel,
          subtitle: l10n.desktopSettingsPrivacySubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsPrivacyKeywords),
          builder: (ctx) => _PrivacyPane(lockService: lockService, vm: vm),
        ),
        WorkspaceSection(
          id: 'security',
          tint: DIconTint.blue,
          icon: FluentIcons.shield_keyhole_24_regular,
          label: l10n.desktopSettingsSecurityLabel,
          subtitle: l10n.desktopSettingsSecuritySubtitle,
          group: l10n.desktopSettingsGroupPrivacy,
          keywords: _keywords(l10n.desktopSettingsSecurityKeywords),
          builder: (ctx) => _SecurityPane(vm: vm, lockService: lockService),
        ),
        WorkspaceSection(
          id: 'backup',
          tint: DIconTint.cyan,
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
          tint: DIconTint.red,
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
          tint: DIconTint.cyan,
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
          tint: DIconTint.blue,
          icon: FluentIcons.person_24_regular,
          label: l10n.desktopSettingsAccountLabel,
          subtitle: l10n.desktopSettingsAccountSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsAccountKeywords),
          builder: (ctx) => _AccountPane(vm: vm, onOpenProfile: onOpenProfile),
        ),
        WorkspaceSection(
          id: 'storage',
          tint: DIconTint.amber,
          icon: FluentIcons.database_24_regular,
          label: l10n.desktopSettingsStorageLabel,
          subtitle: l10n.desktopSettingsStorageSubtitle,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsStorageKeywords),
          builder: (ctx) => const _StoragePane(),
        ),
        WorkspaceSection(
          id: 'support',
          tint: DIconTint.orange,
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
          tint: DIconTint.purple,
          icon: FluentIcons.info_24_regular,
          label: l10n.desktopSettingsAboutLabel,
          group: l10n.desktopSettingsGroupAccount,
          keywords: _keywords(l10n.desktopSettingsAboutKeywords),
          builder: (ctx) => const _AboutPane(),
        ),
        WorkspaceSection(
          id: 'danger',
          // Не [DIconTint.red] «Уведомлений», а красный ОПАСНОСТИ окна: этот
          // же цвет стоит на кнопке «Удалить аккаунт» внутри раздела и на
          // строке «Выйти» внизу колонки. Совпадение цвета — обещание, что
          // строка ведёт туда, откуда нет возврата.
          tint: DColors.of(context).danger,
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

/// Низ боковой колонки: красный «Выйти» и под ним номер сборки.
///
/// 🔴 НОМЕР ЗДЕСЬ, А НЕ ТОЛЬКО В «О ПРОГРАММЕ». Первый вопрос поддержки — «что
/// у вас за версия», и до сих пор ответ лежал за двумя нажатиями в самом
/// нижнем разделе списка. Telegram держит его на виду внизу колонки ровно по
/// этой причине. Нажатие кладёт строку в буфер обмена: человеку не придётся
/// переписывать её с экрана в сообщение поддержке, а переписанная от руки
/// версия — это версия, которой можно ошибиться.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SignOutRow(controller: controller),
        const _VersionLine(),
      ],
    );
  }
}

class _VersionLine extends StatefulWidget {
  const _VersionLine();
  @override
  State<_VersionLine> createState() => _VersionLineState();
}

class _VersionLineState extends State<_VersionLine> {
  // Читается один раз: строка стоит внизу колонки всё время, пока открыты
  // настройки, и перечитывать её на каждой перерисовке не за чем.
  late final Future<AppPackageInfo> _pkg = AppPackageInfo.load();

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<AppPackageInfo>(
      future: _pkg,
      builder: (ctx, snap) {
        final info = snap.data;
        // Пока не прочитано — пустая строка ТОЙ ЖЕ высоты, иначе низ колонки
        // дёргался бы на первой отрисовке.
        final text = info == null
            ? ''
            : '${info.version} (${info.buildNumber})';
        return HoverListener(
          onTap: info == null
              ? null
              : () {
                  unawaited(Clipboard.setData(ClipboardData(text: text)));
                  DesktopSnackbar.show(
                    context,
                    message: l10n.copied,
                    kind: DSnackKind.success,
                  );
                },
          cursor: info == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          // Макет: моноширинный 11, третьим тоном, поля 6 8 0 под строкой
          // «Выйти» и 12 до низа колонки.
          builder: (ctx, hovered, pressed) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.mono.copyWith(
                fontSize: 11,
                color: hovered ? c.textSecondary : c.textTertiary,
              ),
            ),
          ),
        );
      },
    );
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
      // Макет: та же строка, что у разделов (поля 7 8, скругление 6, знак 19
      // и подпись 14), только красная и отдельно внизу колонки.
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: pressed
              ? c.danger.withValues(alpha: 0.16)
              : (hovered ? c.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(FluentIcons.sign_out_24_regular, size: 19, color: c.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.desktopSettingsSignOut,
                style: DType.body.copyWith(color: c.danger),
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

/// Прокрутка раздела. Поля — из макета (`padding: 4px 32px 96px`): бока
/// те же 32, что у шапки, — заголовок стоит ровно над карточками; сверху 4,
/// потому что у каждого раздела страницы свои 20 сверху; снизу 96 — последняя
/// карточка не прилипает к краю окна.
class _PaneScaffold extends StatelessWidget {
  const _PaneScaffold({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 96),
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
  @override
  void initState() {
    super.initState();
    // Состояние автозапуска живёт в СИСТЕМЕ: человек мог отменить его в
    // «Объектах входа», пока окно было закрыто. Спрашиваем при каждом
    // открытии раздела, а не помним своё.
    unawaited(DesktopLoginItemService.instance.refresh());
  }

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

  /// Включить или выключить автозапуск. Отказ системы говорится словами:
  /// молчаливый возврат переключателя выглядит как «он не нажимается».
  Future<void> _setLaunchAtLogin(bool value) async {
    final svc = DesktopLoginItemService.instance;
    svc.startMinimized = DesktopUiPrefs.startMinimized.value;
    final ok = await svc.setEnabled(value);
    if (!mounted || ok) return;
    DesktopSnackbar.show(
      context,
      message: svc.lastError ?? AppLocalizations.of(context)!.contactActionGeneric,
      kind: DSnackKind.error,
    );
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
              // 🔴 АВТОЗАПУСК — УСЛОВИЕ ДОСТАВКИ, А НЕ УДОБСТВО.
              //
              // Окно живёт в трее, и сообщения приходят, пока приложение
              // ЗАПУЩЕНО. Не запущенное не получает ничего — человек узнаёт о
              // разговоре тогда, когда сам вспомнит открыть Secretly. На
              // телефоне за доставку отвечает система; на компьютере — мы.
              //
              // Строки нет вовсе там, где система этого не умеет (macOS
              // старше 13, Windows): переключатель, который притворяется
              // работающим, хуже отсутствующего.
              ValueListenableBuilder<bool>(
                valueListenable: DesktopLoginItemService.instance.available,
                builder: (ctx, available, _) {
                  if (!available) return const SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: DesktopLoginItemService.instance.enabled,
                    builder: (ctx, on, _) => ValueListenableBuilder<bool>(
                      valueListenable:
                          DesktopLoginItemService.instance.needsApproval,
                      builder: (ctx, needsApproval, _) => Column(
                        children: [
                          WorkspaceRow(
                            label: l10n.desktopGeneralLaunchAtLogin,
                            description: needsApproval
                                ? (Platform.isWindows
                                    ? l10n.desktopGeneralLaunchNeedsApprovalWindows
                                    : l10n.desktopGeneralLaunchNeedsApproval)
                                : (on
                                    ? l10n.desktopGeneralLaunchAtLoginOn
                                    : l10n.desktopGeneralLaunchAtLoginOff),
                            icon: FluentIcons.power_24_regular,
                            trailing: WorkspaceSwitch(
                              value: on,
                              onChanged: (v) =>
                                  unawaited(_setLaunchAtLogin(v)),
                            ),
                          ),
                          // Windows: при автозапуске — сразу в трей, без окна
                          // (строка автозапуска с `--minimized`).
                          if (Platform.isWindows && on)
                            ValueListenableBuilder<bool>(
                              valueListenable: DesktopUiPrefs.startMinimized,
                              builder: (ctx, minimized, _) => WorkspaceRow(
                                label: l10n.desktopGeneralStartMinimized,
                                description:
                                    l10n.desktopGeneralStartMinimizedHint,
                                icon: FluentIcons.arrow_minimize_24_regular,
                                trailing: WorkspaceSwitch(
                                  value: minimized,
                                  onChanged: (v) async {
                                    await DesktopUiPrefs.setStartMinimized(v);
                                    await _setLaunchAtLogin(true);
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // 🔴 КРЕСТИК: СПРЯТАТЬ ИЛИ ЗАКРЫТЬ (28.09.2026). Как у Telegram —
              // по умолчанию прячет в трей, чтобы сообщения и звонки
              // продолжали приходить; выключенное — закрывает приложение.
              // Строки нет, где значка в трее нет: прятать было бы некуда.
              if (DesktopWindowActivity.trayReady)
                ValueListenableBuilder<bool>(
                  valueListenable: DesktopUiPrefs.closeToTray,
                  builder: (ctx, closeToTray, _) => WorkspaceRow(
                    label: l10n.desktopGeneralCloseToTray,
                    description: closeToTray
                        ? l10n.desktopGeneralCloseToTrayOn
                        : l10n.desktopGeneralCloseToTrayOff,
                    icon: FluentIcons.window_arrow_up_24_regular,
                    trailing: WorkspaceSwitch(
                      value: closeToTray,
                      onChanged: (v) =>
                          unawaited(DesktopUiPrefs.setCloseToTray(v)),
                    ),
                  ),
                ),
              // Карточку ссылки готовит отправитель — значит, страницу
              // открывает это окно. Выключатель, как в Signal.
              ValueListenableBuilder<bool>(
                valueListenable: DesktopUiPrefs.doubleClickReply,
                builder: (ctx, on, _) => WorkspaceRow(
                  label: l10n.desktopGeneralDoubleClickReply,
                  description: l10n.desktopGeneralDoubleClickReplyHint,
                  trailing: WorkspaceSwitch(
                    value: on,
                    onChanged: (v) =>
                        unawaited(DesktopUiPrefs.setDoubleClickReply(v)),
                  ),
                ),
              ),
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
        // D-1: shown since 19.09.2026, when the desktop strings finished
        // moving into ARB (TZ §5, L-2 and L-3) and [kDesktopUiLocalized] was
        // turned on.
        //
        // The row was hidden, not deleted, for a year: the picker itself always
        // worked — it calls setAppLocalePreference and the app rebuilds in the
        // chosen locale — but there was nothing to translate, so choosing
        // English gave an English "Cancel" inside an entirely Russian app.
        // Offering that choice was worse than not offering it, because it
        // looked like it worked.
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

class _NotificationsPane extends StatefulWidget {
  const _NotificationsPane({this.vm});

  /// Подписка — для замков на платных звуках; без профиля можно всё.
  final DesktopAppViewModel? vm;
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

  /// Открыть системные настройки уведомлений.
  ///
  /// Два адреса, а не один: с macOS 13 раздел переехал на
  /// `com.apple.Notifications-Settings.extension`, а прежний
  /// `com.apple.preference.notifications` на новых системах открывает не то
  /// или ничего. Пробуем сперва новый; если система его не знает — старый.
  /// Молча не получиться здесь нельзя: кнопка, которая ничего не открывает,
  /// оставляет человека ровно там же, где он был.
  Future<void> _openSystemNotificationSettings() async {
    const urls = <String>[
      'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
      'x-apple.systempreferences:com.apple.preference.notifications',
    ];
    for (final u in urls) {
      try {
        if (await launchUrl(Uri.parse(u),
            mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Следующий адрес.
      }
    }
    if (!mounted) return;
    // Общая строка «не удалось открыть» — своей заводить не за чем: человеку
    // важно, что не открылось, а не какой именно из двух адресов не подошёл.
    DesktopSnackbar.show(
      context,
      message: AppLocalizations.of(context)!.devicesLinkOpenFailed,
      kind: DSnackKind.error,
    );
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
        // 🔴 ПЕРВЫМ ДЕЛОМ — НЕ НАСТРОЙКИ, А ОТКАЗ СИСТЕМЫ, ЕСЛИ ОН ЕСТЬ.
        //
        // Все переключатели ниже управляют тем, ЧТО показывать. Если система
        // не пропускает уведомления вовсе, они управляют ничем — и при этом
        // выглядят включёнными и рабочими. Человек листает исправную с виду
        // страницу и делает единственный доступный ему вывод: «Secretly не
        // доставляет сообщения». Поэтому отказ стоит выше всего остального.
        if (svc != null)
          ValueListenableBuilder<bool?>(
            valueListenable: svc.systemAllowed,
            builder: (ctx, allowed, _) => allowed == false
                ? _SystemNotificationsBlockedCard(
                    onOpenSettings: () =>
                        unawaited(_openSystemNotificationSettings()),
                  )
                : const SizedBox.shrink(),
          ),
        WorkspaceCard(
          title: l10n.desktopSettingsNotificationsLabel,
          description: svc == null ? l10n.desktopNotifUnavailableHere : null,
          child: Column(
            children: [
              WorkspaceRow(
                label: l10n.desktopNotifShowPreview,
                description: l10n.desktopNotifInSystem,
                trailing: WorkspaceSelect<int>(
                  value: previewLevel,
                  values: _previewLevels,
                  labelOf: (level) => _previewLevelLabel(level, l10n),
                  onChanged: svc == null
                      ? null
                      : (v) {
                          final s = _svc;
                          if (s == null) return;
                          unawaited(s.setPreviewLevel(v));
                          setState(() {});
                        },
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
              // Р1, этап 5 (29.09.2026): свои окошки в углу экрана, как у
              // Telegram. Только Windows — на macOS системные уведомления и
              // есть привычный путь.
              if (Platform.isWindows)
                ValueListenableBuilder<bool>(
                  valueListenable: DesktopUiPrefs.customNotifications,
                  builder: (ctx, own, _) => WorkspaceRow(
                    label: l10n.desktopNotifOwnWindows,
                    description: l10n.desktopNotifOwnWindowsHint,
                    trailing: WorkspaceSwitch(
                      value: own,
                      onChanged: (v) =>
                          unawaited(DesktopUiPrefs.setCustomNotifications(v)),
                    ),
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
              // Как в Telegram: окно в фокусе молчит только об открытом чате.
              WorkspaceRow(
                label: l10n.desktopNotifWhileFocused,
                description: l10n.desktopNotifWhileFocusedHint,
                trailing: WorkspaceSwitch(
                  value: svc?.notifyWhileFocused ?? true,
                  onChanged: (v) {
                    final s = _svc;
                    if (s == null) return;
                    unawaited(s.setNotifyWhileFocused(v));
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
        // 🔴 ВЫБОР ЗВУКОВ (01.10.2026, владелец: «человек должен выбирать
        // звуки и слышать их»). Сразу под «Звуком»: выключен он — карточки
        // говорят, что выбранному не звучать.
        DesktopMessageSoundCard(
          soundOn: sound,
          entitlement: () => widget.vm?.controller.entitlementStateNow,
        ),
        DesktopInChatSoundCard(soundOn: sound),
      ],
    );
  }
}

/// Точка тревоги у строки «Уведомления» в боковой колонке.
///
/// Ничего не рисует, пока система уведомления пропускает, — и не рисует, пока
/// ответа нет: точка «на всякий случай» обесценила бы точку настоящую.
class _NotificationsAlertDot extends StatelessWidget {
  const _NotificationsAlertDot();

  @override
  Widget build(BuildContext context) {
    final svc = DesktopNotificationService.instance;
    if (svc == null) return const SizedBox.shrink();
    final c = DColors.of(context);
    return ValueListenableBuilder<bool?>(
      valueListenable: svc.systemAllowed,
      builder: (ctx, allowed, _) {
        if (allowed != false) return const SizedBox.shrink();
        return DesktopTooltip(
          message: AppLocalizations.of(ctx)!.desktopNotifBlockedTitle,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}

/// Плашка «система не пропускает уведомления».
///
/// Тревожного цвета и с одним действием — кнопкой в системные настройки. Без
/// кнопки это было бы сообщение «у вас сломано, разбирайтесь сами»: путь к
/// нужному разделу macOS помнит не каждый, а искать его в чужом интерфейсе
/// посреди чужой ошибки — худший момент для поиска.
class _SystemNotificationsBlockedCard extends StatelessWidget {
  const _SystemNotificationsBlockedCard({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.xl),
      child: Container(
        padding: const EdgeInsets.all(DSpace.l),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: c.isDark ? 0.12 : 0.10),
          border: Border.all(color: c.warning.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FluentIcons.alert_urgent_24_regular,
              size: 22,
              color: c.warning,
            ),
            const SizedBox(width: DSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.desktopNotifBlockedTitle,
                    style: DType.body.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DSpace.xs),
                  Text(
                    l10n.desktopNotifBlockedBody,
                    style: DType.label
                        .copyWith(color: c.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: DSpace.m),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DesktopButton(
                      label: l10n.desktopNotifBlockedAction,
                      kind: DButtonKind.tonal,
                      icon: FluentIcons.settings_24_regular,
                      onPressed: onOpenSettings,
                    ),
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
const List<String> _kAudienceCategories = [
  'last_seen',
  'photo',
  'forwards',
  'calls',
  'voice_messages',
  'messages',
];

/// Подпись категории. Ключ остаётся ключом — по нему сверяются с телефоном.
String _audienceTitle(String key, AppLocalizations l10n) => switch (key) {
  'last_seen' => l10n.desktopPrivacyLastSeen,
  'photo' => l10n.desktopPrivacyProfilePhoto,
  'forwards' => l10n.desktopPrivacyForwarding,
  'calls' => l10n.desktopPrivacyCalls,
  'voice_messages' => l10n.desktopPrivacyVoice,
  _ => l10n.desktopPrivacyMessages,
};

class _PrivacyPaneState extends State<_PrivacyPane> {
  /// Включить или выключить защиту от снимков экрана. Отказ системы — не
  /// «включено»: контроллер тогда не сохраняет настройку, а человек видит
  /// причину, почему переключатель вернулся.
  Future<void> _setScreenPrivacy(AppController ctrl, bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context, rootOverlay: true);
    final palette = DColors.maybeOf(context);
    final ok = await ctrl.setScreenPrivacy(on);
    if (mounted) setState(() {});
    if (ok) return;
    DesktopSnackbar.showIn(
      overlay,
      message: l10n.desktopPrivacyScreenCaptureFailed,
      kind: DSnackKind.error,
      palette: palette,
    );
  }

  String _audienceLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'nobody':
        return l10n.desktopPrivacyNobody;
      case 'everyone':
        return l10n.desktopPrivacyEverybody;
      default:
        return l10n.desktopPrivacyContacts;
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
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopPrivacyEncryption,
          description:
              l10n.desktopPrivacyEncryptionHint,
          // Honest status instead of a dead «verify» nav — per-contact
          // fingerprint verification lives in each contact's details.
          child: WorkspaceRow(
            label: l10n.desktopPrivacyE2eeActive,
            icon: FluentIcons.shield_checkmark_24_regular,
          ),
        ),
        if (widget.lockService != null)
          _AppLockCard(service: widget.lockService!),
        // «Отчёты о прочтении» / «Индикатор набора» toggles removed: neither
        // gated a real feature (sendTypingState and read receipts always fire
        // unconditionally) — a switch with zero effect is a false sense of
        // control, not a setting. Re-add only once a real on/off exists.
        //
        // «Защита от снимков экрана» вернулась 01.10.2026 — теперь за ней
        // настоящий выключатель: раннер отвечает на `secretly/screen_privacy`
        // (см. [DesktopScreenPrivacy]).
        if (ctrl != null && DesktopScreenPrivacy.isSupported)
          WorkspaceCard(
            title: l10n.desktopPrivacyScreenCaptureTitle,
            // Честно: это просьба к системе, а не замок, и наша собственная
            // демонстрация экрана окна тоже не покажет.
            description: l10n.desktopPrivacyScreenCaptureHint,
            child: WorkspaceRow(
              label: l10n.desktopPrivacyScreenCaptureSwitch,
              icon: FluentIcons.camera_off_24_regular,
              trailing: WorkspaceSwitch(
                value: ctrl.screenPrivacy,
                onChanged: (v) => unawaited(_setScreenPrivacy(ctrl, v)),
              ),
            ),
          ),
        if (ctrl != null) ...[
          WorkspaceCard(
            title: l10n.desktopPrivacyWhoSees,
            description:
                l10n.desktopPrivacyWhoSeesHint,
            child: Column(
              children: [
                // Черты между строками ставит сама карточка: свои
                // `Divider` здесь давали двойные линии.
                for (final key in _kAudienceCategories)
                  WorkspaceRow(
                    label: _audienceTitle(key, l10n),
                    trailing: WorkspaceSelect<String>(
                      value: ctrl.privacyAudience[key] ?? 'contacts',
                      values: const ['nobody', 'contacts', 'everyone'],
                      labelOf: (v) => _audienceLabel(v, l10n),
                      onChanged: (v) =>
                          unawaited(ctrl.setPrivacyAudience(key, v)),
                    ),
                  ),
              ],
            ),
          ),
          WorkspaceCard(
            title: l10n.desktopPrivacyVisibility,
            child: Column(
              children: [
                WorkspaceRow(
                  label: l10n.desktopPrivacyByNickname,
                  description: l10n.desktopPrivacyByNicknameHint,
                  trailing: WorkspaceSwitch(
                    value: ctrl.discoverableByNickname,
                    onChanged: (v) =>
                        unawaited(ctrl.setDiscoverableByNickname(v)),
                  ),
                ),
                WorkspaceRow(
                  label: l10n.desktopPrivacySuggest,
                  trailing: WorkspaceSwitch(
                    value: ctrl.allowNicknameLookup,
                    onChanged: (v) => unawaited(ctrl.setAllowNicknameLookup(v)),
                  ),
                ),
              ],
            ),
          ),
          WorkspaceCard(
            title: l10n.desktopPrivacyStrangers,
            child: WorkspaceRow(
              label: l10n.desktopPrivacyStrangersHint,
              trailing: WorkspaceSwitch(
                value: ctrl.privacyArchiveUnknownChats,
                onChanged: (v) =>
                    unawaited(ctrl.setPrivacyArchiveUnknownChats(v)),
              ),
            ),
          ),
          WorkspaceCard(
            title: l10n.desktopPrivacyAutoDelete,
            description:
                l10n.desktopPrivacyAutoDeleteHint,
            child: WorkspaceRow(
              label: l10n.desktopPrivacyIfAbsent,
              description: _deleteMonthsLabel(ctrl.privacyDeleteAccountMonths, l10n),
              icon: FluentIcons.timer_24_regular,
              trailing: WorkspaceSelect<int>(
                value:
                    _kDeleteMonthOptions.contains(
                      ctrl.privacyDeleteAccountMonths,
                    )
                    ? ctrl.privacyDeleteAccountMonths
                    : _kDeleteMonthOptions.last,
                values: _kDeleteMonthOptions,
                labelOf: (m) => _deleteMonthsLabel(m, l10n),
                onChanged: (v) =>
                    unawaited(ctrl.setPrivacyDeleteAccountMonths(v)),
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

String _deleteMonthsLabel(int months, AppLocalizations l10n) {
  switch (months) {
    case 1:
      return l10n.desktopPrivacyIn1Month;
    case 3:
      return l10n.desktopPrivacyIn3Months;
    case 6:
      return l10n.desktopPrivacyIn6Months;
    case 12:
      return l10n.desktopPrivacyIn1Year;
    default:
      return l10n.desktopPrivacyIn2Years;
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

  String _graceLabel(int s, AppLocalizations l10n) {
    if (s == 0) return l10n.desktopLockImmediately;
    if (s < 60) return l10n.desktopLockSeconds('$s');
    if (s < 3600) return l10n.desktopLockMinutes('${s ~/ 60}');
    return l10n.desktopLockHours('${s ~/ 3600}');
  }

  /// Applies the lock toggle and explains it when the change does not stick.
  ///
  /// [DesktopAppLockService.setEnabled] arms the lock only after a successful
  /// authentication (F-17: proving the unlock path works is what prevents an
  /// unopenable app). A refusal therefore means the user cancelled, or this
  /// machine has no authenticator at all — the switch must stay off AND say
  /// why, instead of silently snapping back.
  Future<void> _toggleLock(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final svc = widget.service;
    final applied = await svc.setEnabled(
      value,
      armReason: l10n.desktopEnableLockPrompt,
    );
    if (!mounted || applied || !value) return;
    DesktopSnackbar.show(
      context,
      message: svc.unlockUnavailable.value
          ? l10n.desktopLockNoIdentityService
          : l10n.desktopLockNotConfirmed,
      kind: DSnackKind.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final svc = widget.service;
    final supported = svc.biometricSupported.value;
    final enabled = svc.enabled.value;
    final grace = svc.graceSeconds.value;
    return WorkspaceCard(
      title: l10n.desktopLockTitle,
      description: supported
          ? l10n.desktopLockTouchIdHint
          : l10n.desktopLockPasswordHint,
      child: Column(
        children: [
          WorkspaceRow(
            // F-17: enabling is NOT gated on biometrics. Unlocking uses
            // `biometricOnly: false`, so a Mac without Touch ID authenticates
            // with the device password — gating the switch on biometric
            // support made the lock unavailable to those machines entirely.
            label: supported ? l10n.desktopLockEnableTouchId : l10n.desktopLockEnableLock,
            description: supported ? null : l10n.desktopLockDevicePassword,
            trailing: WorkspaceSwitch(
              value: enabled,
              onChanged: (v) => unawaited(_toggleLock(v)),
            ),
          ),
          if (enabled)
            WorkspaceRow(
              label: l10n.desktopLockAfter,
              description: _graceLabel(grace, l10n),
              trailing: WorkspaceSelect<int>(
                value: _graceOptions.contains(grace)
                    ? grace
                    : _graceOptions.first,
                values: _graceOptions,
                labelOf: (s) => _graceLabel(s, l10n),
                onChanged: (v) => unawaited(svc.setGraceSeconds(v)),
              ),
            ),
          if (enabled)
            WorkspaceRow(
              label: l10n.desktopLockNow,
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

  /// `null` — демонстрационная сборка без контроллера.
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
        _error = desktopErrorText(e);
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
    final l10n = AppLocalizations.of(ctx)!;
    final controller = widget.controller;
    if (controller == null) return;
    if (_endingDeviceId != null) return;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(l10n.desktopDevicesEndSessionTitle),
          content: Text(
            l10n.desktopDevicesEndSessionBody(_shortId(targetDeviceId)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.desktopDevicesEnd),
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
      // 🔴 `false` — это НЕ «завершён» (01.10.2026). Ответ отбрасывался, и
      // окно говорило «Сеанс устройства завершён» про устройство, которое
      // сервер так и не снял.
      final ended = await controller.endDeviceSession(
        targetDeviceId: targetDeviceId,
      );
      if (!ended) errorMsg = l10n.desktopDevicesEndNotConfirmed;
    } catch (e) {
      errorMsg = desktopErrorText(e);
    } finally {
      if (mounted) {
        setState(() {
          _endingDeviceId = null;
        });
      }
    }
    if (!mounted) return;
    // 🔴 Своя плашка окна, а не материальная (30.09.2026): материальная
    // рисовалась ПОД слоем настроек, и ответ «сеанс завершён / не удалось»
    // не видел никто.
    DesktopSnackbar.show(
      context,
      message: errorMsg != null
          ? l10n.desktopDevicesEndFailed(errorMsg)
          : l10n.desktopDevicesEnded,
      kind: errorMsg != null ? DSnackKind.error : DSnackKind.success,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            title: l10n.desktopDevicesActiveSessions,
            description:
                l10n.desktopDevicesDemoHint,
            child: Column(
              children: [
                WorkspaceRow(
                  label: l10n.desktopDevicesThisComputer,
                  description: l10n.desktopDevicesDemoMac,
                  icon: FluentIcons.laptop_24_regular,
                ),
                WorkspaceRow(
                  label: 'iPhone 15 Pro',
                  description: l10n.desktopDevicesDemoIphone,
                  icon: FluentIcons.phone_24_regular,
                ),
                WorkspaceRow(
                  label: 'iPad Air',
                  description: l10n.desktopDevicesDemoIpad,
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
          label: isThis ? l10n.desktopDevicesThisDevice : _shortId(id),
          description: isThis
              ? '${Platform.operatingSystem} · ${_shortId(id)}'
              : l10n.desktopDevicesRemoteDevice,
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
                        label: l10n.desktopDevicesDisconnect,
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
              ? l10n.desktopDevicesTitle
              : l10n.desktopDevicesTitleCount(_deviceIds.length),
          description:
              l10n.desktopDevicesHint,
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
                  label: l10n.desktopDevicesLoadFailed,
                  description: _error!,
                  icon: FluentIcons.warning_24_regular,
                  trailing: DesktopButton(
                    label: l10n.desktopDevicesRetry,
                    kind: DButtonKind.tonal,
                    onPressed: _load,
                  ),
                )
              else if (rows.isEmpty)
                WorkspaceRow(
                  label: l10n.desktopDevicesNone,
                  description: l10n.desktopDevicesNotLinked,
                  icon: FluentIcons.phone_laptop_24_regular,
                )
              else
                ...rows,
            ],
          ),
        ),
        WorkspaceCard(
          child: WorkspaceRow(
            label: l10n.desktopDevicesRefresh,
            icon: FluentIcons.arrow_clockwise_24_regular,
            onTap: _loading ? null : _load,
          ),
        ),
        // 🔴 «ПОДКЛЮЧИТЬ УСТРОЙСТВО» ОТСЮДА УБРАНО (30.09.2026). Карточка звала
        // вход НЕпривязанного компьютера: он взводит запрет входа, и уже
        // вошедший компьютер оказывался на экране выбора входа — и после
        // перезапуска тоже, а вернуться можно было только новой привязкой со
        // стиранием базы. QR при этом нёс личность ЭТОГО компьютера. Компьютер
        // подключают с телефона — об этом и говорит строка.
        WorkspaceCard(
          child: WorkspaceRow(
            label: l10n.desktopDevicesAddComputerTitle,
            description: l10n.desktopDevicesAddComputerHint,
            icon: FluentIcons.laptop_multiple_24_regular,
          ),
        ),
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
    final l10n = AppLocalizations.of(context)!;
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
        _feedback = l10n.desktopSyncPulled(delta);
      } else if (service.requestsRejected > 0 &&
          service.requestsCompleted == 0) {
        _feedback = l10n.desktopSyncTooOften;
      } else {
        _feedback = l10n.desktopSyncNothingNew;
      }
    });
  }

  /// PR7: rehydrate attachment blobs across all conversations. Walks
  /// recent events per convo and downloads any [AttachmentEventV1] blob
  /// that isn't on disk yet. Safe to spam — `ensureCachedAttachmentFile`
  /// short-circuits if the file already exists.
  Future<void> _triggerRehydrate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_rehydrating) return;
    final controller = widget.controller;
    if (controller == null) {
      setState(() {
        _rehydrateFeedback = l10n.desktopSyncDemoUnavailable;
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
          _rehydrateFeedback = l10n.desktopSyncBlobsPulled(
            result.blobsDownloaded,
            result.convosScanned,
          );
        } else {
          _rehydrateFeedback =
              l10n.desktopSyncNoBlobs(result.convosScanned);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rehydrating = false;
        _rehydrateFeedback = l10n.desktopFailedWith(desktopErrorText(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceCard(
      title: l10n.desktopSyncTitle,
      description: l10n.desktopSyncHint,
      child: Column(
        children: [
          WorkspaceRow(
            label: _running ? l10n.desktopSyncRunning : l10n.desktopSyncAskHistory,
            description: _feedback,
            icon: FluentIcons.history_24_regular,
            trailing: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : DesktopButton(
                    label: l10n.desktopSyncAsk,
                    kind: DButtonKind.tonal,
                    onPressed: _trigger,
                  ),
          ),
          WorkspaceRow(
            label: _rehydrating ? l10n.desktopSyncBlobsRunning : l10n.desktopSyncBlobsAction,
            description:
                _rehydrateFeedback ?? l10n.desktopSyncBlobsHint,
            icon: FluentIcons.cloud_arrow_down_24_regular,
            trailing: _rehydrating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : DesktopButton(
                    label: l10n.desktopSyncBlobsShort,
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

/// Пароль копии — с повтором и проверкой по политике. Одно окно на весь
/// раздел: ручная копия на сервер и автоматическая спрашивают одинаково
/// (01.10.2026 — раньше автоматическая не спрашивала вовсе).
Future<String?> promptDesktopBackupPassword(
  BuildContext context, {
  required String actionLabel,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final pw = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    // 🔴 Поля освобождает само окно, когда его маршрут УШЁЛ (01.10.2026).
    // Раньше `dispose()` звучал сразу после `showDialog` — пока окно ещё
    // уезжало с экрана и его поля читали уже освобождённые контроллеры.
    builder: (dialogCtx) => _DisposeWithRoute(
      controllers: [pw, confirm],
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          void submit() {
            final a = pw.text;
            final b = confirm.text;
            final validation = BackupPasswordPolicy.validate(a);
            if (!validation.isValid) {
              // Перевод по языку ОКНА, а не жёстко по-русски: раньше
              // немец и испанец читали причину отказа кириллицей ровно в
              // тот момент, когда пароль не приняли.
              setLocal(
                () => error = desktopPasswordProblems(l10n, validation),
              );
              return;
            }
            if (a != b) {
              setLocal(() => error = l10n.desktopBackupPasswordsDiffer);
              return;
            }
            Navigator.of(ctx).pop(a);
          }

          return AlertDialog(
            title: Text(l10n.desktopServerBackupPassword),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.desktopServerBackupPasswordHint,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pw,
                  autofocus: true,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.password),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: l10n.desktopServerBackupRepeat,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error ?? desktopPasswordRequirements(l10n),
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
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(actionLabel),
              ),
            ],
          );
        },
      ),
    ),
  );
  return result;
}

/// «Заменить копию на сервере?» — перед всем, что кладёт копию на сервер с
/// этого компьютера.
///
/// 🔴 Сервер держит ОДНУ копию на аккаунт, и у телефона с компьютером аккаунт
/// общий. Копия отсюда молча затирала копию телефона — а в ней обычно больше
/// истории, чем на компьютере (01.10.2026).
Future<bool> confirmDesktopServerBackupReplace(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.desktopServerBackupReplaceTitle,
    size: DDialogSize.small,
    body: Text(
      l10n.desktopServerBackupReplaceBody,
      style: DType.body.copyWith(
        color: DColors.of(context).textSecondary,
        height: 1.45,
      ),
    ),
    primary: DDialogAction(
      label: l10n.desktopServerBackupReplaceConfirm,
      onPressed: () => Navigator.of(context).maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => Navigator.of(context).maybePop(false),
    ),
  );
  return ok == true;
}

/// Освобождает контроллеры полей, когда окно, которому они принадлежат,
/// действительно ушло: `State.dispose` маршрута звучит ПОСЛЕ анимации ухода.
/// Освобождать их сразу за `await showDialog(...)` — значит отнять их у полей,
/// которые ещё рисуются на уезжающем окне.
class _DisposeWithRoute extends StatefulWidget {
  const _DisposeWithRoute({
    required this.controllers,
    required this.child,
  });

  final List<ChangeNotifier> controllers;
  final Widget child;

  @override
  State<_DisposeWithRoute> createState() => _DisposeWithRouteState();
}

class _DisposeWithRouteState extends State<_DisposeWithRoute> {
  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    if (controller == null || _running) return;

    // 🔴 Копия на сервере ОДНА на аккаунт (01.10.2026): созданная здесь молча
    // затирала копию телефона. Сначала — сказать об этом и спросить.
    if (!await confirmDesktopServerBackupReplace(context) || !context.mounted) {
      return;
    }
    final password = await promptDesktopBackupPassword(
      context,
      actionLabel: l10n.desktopServerBackupCreate,
    );
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
        _feedback = l10n.desktopServerBackupOk(
          stamp,
          result.payloadKilobytes.toStringAsFixed(0),
          result.profileId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _ok = false;
        _feedback = l10n.desktopFailedWith(_short(e));
      });
    }
  }

  String _short(Object e) => desktopErrorText(e);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceCard(
      title: l10n.desktopServerBackupTitle,
      description: l10n.desktopServerBackupHint,
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
    final l10n = AppLocalizations.of(context)!;
    return WorkspaceRow(
        label: _running ? l10n.desktopServerBackupLoading : l10n.desktopServerBackupCreateOnServer,
        description: _feedback,
        icon: FluentIcons.cloud_arrow_up_24_regular,
        trailing: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : DesktopButton(
                label: _ok ? l10n.desktopServerBackupUpdate : l10n.desktopListCreate,
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
      title: l10n.desktopStorageDeleteModelTitle,
      size: DDialogSize.small,
      body: Text(
        l10n.desktopStorageDeleteModelBody,
        style: DType.body.copyWith(color: DColors.of(context).textSecondary),
      ),
      primary: DDialogAction(
        label: l10n.delete,
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
        message: l10n.desktopStorageModelDeleted,
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopStorageDeleteFailed(desktopErrorText(e)),
        kind: DSnackKind.error,
      );
    }
  }

  static String fmtBytes(int bytes, AppLocalizations l10n) {
    if (bytes <= 0) return l10n.desktopStorageKb('0');
    if (bytes < 1024 * 1024) return l10n.desktopStorageKb((bytes / 1024).toStringAsFixed(0));
    if (bytes < 1024 * 1024 * 1024) {
      return l10n.desktopStorageMb((bytes / (1024 * 1024)).toStringAsFixed(1));
    }
    return l10n.desktopStorageGb((bytes / (1024 * 1024 * 1024)).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = _usage;
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopStorageUsage,
          description: l10n.desktopStorageUsageHint,
          child: _StorageBar(usage: usage),
        ),
        WorkspaceCard(
          // Say what survives. "Clear cache" that quietly keeps some files is
          // fine engineering and bad communication: a user freeing space needs
          // to know why the number did not drop as far as they expected.
          description: usage == null
              ? null
              : l10n.desktopStorageClearHint(fmtBytes(usage.clearableBytes, l10n)),
          child: WorkspaceRow(
            label: l10n.desktopStorageClear,
            description: usage == null
                ? l10n.desktopStorageCounting
                : fmtBytes(usage.clearableBytes, l10n),
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
            title: l10n.desktopStorageSpeechModel,
            description:
                l10n.desktopStorageSpeechModelHint,
            child: WorkspaceRow(
              label: l10n.desktopStorageDeleteModel,
              description: fmtBytes(usage?.whisperModelBytes ?? 0, l10n),
              icon: FluentIcons.mic_off_24_regular,
              trailing: DesktopButton(
                label: l10n.delete,
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
    final l10n = AppLocalizations.of(context)!;
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
            _legend(c.accentPrimary, l10n.desktopStorageMedia(f(media, l10n))),
            _legend(c.warning, l10n.desktopStorageVoice(f(voice, l10n))),
            _legend(c.success, l10n.desktopStorageOther(f(other, l10n))),
            _legend(
              c.borderDivider,
              u == null ? l10n.desktopStorageFree : l10n.desktopStorageTotal(f(u.total, l10n)),
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
class _ShortcutsPane extends StatefulWidget {
  const _ShortcutsPane();

  @override
  State<_ShortcutsPane> createState() => _ShortcutsPaneState();
}

class _ShortcutsPaneState extends State<_ShortcutsPane> {
  // 🔴 Общий экземпляр, загруженный при запуске (`main_desktop.dart`). Свой
  // экземпляр раздела означал, что ⌥⌘S оживало только после его открытия; и
  // освобождать общий, уходя из раздела, нельзя — он живёт с приложением.
  final DesktopGlobalHotKeyService _hotkey =
      DesktopGlobalHotKeyService.instance;

  @override
  void initState() {
    super.initState();
    // Повторный вызов ничего не повторяет — отдаёт загрузку запуска.
    unawaited(_hotkey.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return _PaneScaffold(
      children: [
        if (_hotkey.supported)
          WorkspaceCard(
            title: l10n.desktopHotkeyGlobalShow,
            description: l10n.desktopHotkeyGlobalHint,
            // Внутри — строка со своими полями, карточка их не удваивает.
            padding: EdgeInsets.zero,
            child: ValueListenableBuilder<bool>(
              valueListenable: _hotkey.enabled,
              builder: (ctx, on, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceRow(
                    label: l10n.desktopHotkeyGlobalShow,
                    // Сочетание показано прямо в подписи: настройка, которая не
                    // говорит, ЧТО нажимать, бесполезна.
                    description: '⌥⌘S',
                    icon: FluentIcons.keyboard_24_regular,
                    trailing: WorkspaceSwitch(
                      value: on,
                      onChanged: (v) async {
                        final ok = await _hotkey.setEnabled(v);
                        if (!ok && mounted) setState(() {});
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _hotkey.taken,
                    builder: (ctx2, taken, _) => taken
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DSpace.l,
                              0,
                              DSpace.l,
                              DSpace.m,
                            ),
                            // 🔴 Занятое сочетание — НЕ наша ошибка и не повод
                            // молчать: переключатель вернулся назад, и человек
                            // должен знать почему, иначе решит, что сломались мы.
                            child: Text(
                              l10n.desktopHotkeyGlobalTaken,
                              style: DType.label.copyWith(color: c.danger),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        const ShortcutsList(),
      ],
    );
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

  /// 🔴 AGPL-3.0 ТРЕБУЕТ ПРЕДЛОЖИТЬ ИСХОДНЫЙ КОД тому, кто получил программу
  /// (30.09.2026). Лицензия была названа в подписи, а куда идти за кодом —
  /// нигде; адрес теперь и кнопкой, и текстом (его видно, даже если браузер
  /// не открылся).
  static const String _sourceUrl = 'https://github.com/Arkhanhel/Secretly';

  Future<void> _openSource() async {
    try {
      await launchUrl(
        Uri.parse(_sourceUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          // Не строки настроек, а визитка: без черт между строчками текста.
          rows: false,
          padding: const EdgeInsets.all(18),
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
                    l10n.desktopAboutVersion(info.version, info.buildNumber),
                    style: DType.label.copyWith(color: c.textSecondary),
                  );
                },
              ),
              const SizedBox(height: DSpace.m),
              Text(
                l10n.desktopAboutTagline,
                style: DType.body.copyWith(color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: DSpace.s),
              SelectableText(
                l10n.desktopAboutLicenseLine(_sourceUrl),
                style: DType.label.copyWith(color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: DSpace.l),
              Wrap(
                spacing: DSpace.s,
                runSpacing: DSpace.s,
                children: [
                  DesktopButton(
                    label: l10n.desktopAboutLicences,
                    kind: DButtonKind.tonal,
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Secretly',
                    ),
                  ),
                  DesktopButton(
                    label: l10n.desktopAboutSourceCode,
                    kind: DButtonKind.ghost,
                    icon: FluentIcons.code_24_regular,
                    onPressed: () => unawaited(_openSource()),
                  ),
                  DesktopButton(
                    label: l10n.desktopAboutWebsite,
                    kind: DButtonKind.ghost,
                    icon: FluentIcons.open_24_regular,
                    onPressed: () => unawaited(_openWebsite()),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 🔴 НЕУДАВШЕЕСЯ ОБНОВЛЕНИЕ ВИДНО ЗДЕСЬ (01.10.2026). Итог попытки
        // служба знала с 30.09, но показывала его только кнопкой «Скачать с
        // сайта» внизу — и то до перезапуска; установщик, не сумевший встать,
        // и вовсе не оставлял следа на экране. Теперь — причина словами и
        // «Повторить». Итог пишет только путь Windows; на Mac обновляет
        // Sparkle со своими окнами, и строки здесь не бывает.
        ValueListenableBuilder<DesktopUpdateAttempt?>(
          valueListenable: DesktopUpdateService.instance.lastAttempt,
          builder: (ctx, attempt, _) {
            final failure = attempt?.failure;
            if (failure == null) return const SizedBox.shrink();
            return WorkspaceCard(
              rows: false,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.desktopUpdateAttemptFailed(
                      desktopUpdateFailureText(l10n, failure),
                    ),
                    style: DType.body.copyWith(color: c.danger, height: 1.4),
                  ),
                  const SizedBox(height: DSpace.m),
                  DesktopButton(
                    label: l10n.desktopUpdateRetry,
                    kind: DButtonKind.tonal,
                    icon: FluentIcons.arrow_clockwise_24_regular,
                    onPressed: () =>
                        unawaited(DesktopUpdateService.instance.retry()),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Причина неудавшегося обновления — словами, для строки «Обновление не
/// установилось: …».
@visibleForTesting
String desktopUpdateFailureText(
  AppLocalizations l10n,
  DesktopUpdateFailure failure,
) =>
    switch (failure) {
      DesktopUpdateFailure.download => l10n.desktopUpdateFailureDownload,
      DesktopUpdateFailure.verification =>
        l10n.desktopUpdateFailureVerification,
      DesktopUpdateFailure.launch => l10n.desktopUpdateFailureLaunch,
      DesktopUpdateFailure.notInstalled =>
        l10n.desktopUpdateFailureNotInstalled,
    };

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
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    if (controller == null) return;

    // Capture the root overlay + root navigator before any await — avoids
    // `use_build_context_synchronously` lint and survives the spinner-dialog
    // tear-down (the spinner's BuildContext gets pop'd mid-flow).
    // 🔴 Плашка — своя, в корневом слое (30.09.2026): материальная
    // рисовалась ПОД слоем настроек, и отказ удаления не видел никто.
    final overlay = Overlay.of(context, rootOverlay: true);
    final palette = DColors.maybeOf(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    // Refuse while a call is active — the call socket+CallKit/Telecom would
    // be torn down mid-flight and leave the OS-level call UI orphaned.
    final cm = CallManager.instance;
    if (cm != null && cm.state.value.isActive) {
      DesktopSnackbar.showIn(
        overlay,
        message: l10n.desktopSettingsEndCallFirst,
        palette: palette,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: navigator.context,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(l10n.desktopDangerTitle),
          content: Text(l10n.desktopDangerBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.error,
                foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.delete),
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
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.desktopDangerDeleting)),
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
      DesktopSnackbar.showIn(
        overlay,
        message: l10n.desktopDangerFailed(desktopErrorText(error)),
        kind: DSnackKind.error,
        palette: palette,
      );
    }
    // On success `deleteAccountEverywhere` fires `restartRequested`, which
    // `DesktopProductionApp` already wires to `_restart()` — that returns the
    // app to the onboarding/QR screen and discards the settings workspace.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    if (controller == null) {
      // Demo (controller-less) mode: render the same layout but mark the
      // button as permanently disabled so users don't tap dead handlers.
      return _PaneScaffold(
        children: [
          WorkspaceCard(
            title: l10n.desktopDangerSection,
            description:
                l10n.desktopDangerDemo,
            rows: false,
            child: Column(
              children: [
                DesktopTextField(
                  hintText: l10n.desktopDangerEnterId,
                ),
                const SizedBox(height: DSpace.m),
                Align(
                  alignment: Alignment.centerRight,
                  child: DesktopButton(
                    label: l10n.desktopDangerAction,
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
        ? l10n.desktopDangerEnterId
        : l10n.desktopDangerEnterIdExact(pid);

    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: l10n.desktopDangerSection,
          description:
              l10n.desktopDangerIrreversible,
          rows: false,
          child: Column(
            children: [
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
                        label: l10n.desktopDangerAction,
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
          title: l10n.desktopSecurityE2ee,
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
                  l10n.desktopSecurityE2eeHint,
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
            title: l10n.desktopSecurityVerifiedDevices,
            description:
                // SEC-06: оговорка про группы обязана быть — привратник в них
                // не работает. Текст переписан, а не дополнен: ратчет
                // `desktop_l10n_ratchet_test` держит число зашитых русских
                // литералов, и две новые строки его подняли бы. Литералов
                // по-прежнему четыре.
                l10n.desktopSecurityVerifiedHint,
            child: WorkspaceRow(
              label: l10n.desktopSecurityOnlyVerified,
              description: ctrl.blockUnverified
                  ? l10n.desktopSecurityBlocked
                  : l10n.desktopSecurityAllDevices,
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
            title: l10n.desktopSecurityAppEntry,
            // Замки хранятся на каждом устройстве отдельно — «общая с
            // телефоном» было неправдой (17.09.2026).
            description:
                l10n.desktopSecurityAppEntryHint,
          ),
          // Строка несёт свои поля сама — карточка кладёт её вплотную.
          const WorkspaceCard(padding: EdgeInsets.zero, child: _OfflineLockRow()),
          _ScopeLockCard(
            controller: ctrl,
            scope: SecurityLockScope.personal,
            title: l10n.desktopNotifDirectChats,
            description:
                l10n.desktopSecurityPersonalScopeHint,
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
      trailing: WorkspaceSelect<int>(
        value: _days,
        values: DesktopOfflineLock.choices,
        labelOf: (days) => _label(l10n, days),
        onChanged: (v) => unawaited(_save(v)),
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
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    if (ctrl == null) return const _PaneScaffold(children: []);
    return _PaneScaffold(
      children: [
        // 🔴 УСТРОЙСТВА — ПРЯМО В «ЗВОНКАХ» (28.09.2026, владелец: «в
        // настройках в разделе „Звонки“ нет настроек устройств»). Как у
        // Telegram и Discord: микрофон, динамики и камера — первым делом там,
        // где их ищут. Раздел «Звук и видео» показывает те же карточки: одна
        // настройка, два входа.
        MediaDevicesPane(
          body: (cards) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopPrivacyCalls,
          child: Column(
            children: [
              WorkspaceRow(
                label: l10n.desktopCallsInApp,
                description: l10n.desktopCallsInAppHint,
                trailing: WorkspaceSwitch(
                  value: ctrl.callsEnabled,
                  onChanged: (v) => unawaited(ctrl.setCallsEnabled(v)),
                ),
              ),
              WorkspaceRow(
                label: l10n.desktopCallsAccept,
                description: ctrl.callsEnabled
                    ? l10n.desktopCallsAcceptHint
                    : l10n.desktopCallsDisabledHint,
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
              // Р1 (29.09.2026): звонок — своим окном ОС, которое можно
              // закрепить поверх всех. Выключено — как раньше, поверх
              // главного окна.
              if (Platform.isWindows || Platform.isMacOS)
                ValueListenableBuilder<bool>(
                  valueListenable: DesktopUiPrefs.callInOwnWindow,
                  builder: (ctx, own, _) => WorkspaceRow(
                    label: l10n.desktopCallsOwnWindow,
                    description: l10n.desktopCallsOwnWindowHint,
                    trailing: WorkspaceSwitch(
                      value: own,
                      onChanged: (v) =>
                          unawaited(DesktopUiPrefs.setCallInOwnWindow(v)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Громкость мелодии входящего (30.09.2026, ТЗ §1.4 «Входящие») — сразу
        // под «Принимать входящие».
        DesktopRingtoneCard(entitlement: () => ctrl.entitlementStateNow),
        WorkspaceCard(
          title: l10n.desktopCallsScreenShare,
          description:
              l10n.desktopCallsScreenShareHint,
          child: WorkspaceRow(
            label: l10n.desktopCallsAcceptScreenShare,
            trailing: WorkspaceSwitch(
              value: ctrl.incomingScreenShareEnabled,
              onChanged: (v) =>
                  unawaited(ctrl.setIncomingScreenShareEnabled(v)),
            ),
          ),
        ),
        WorkspaceCard(
          title: l10n.desktopCallsSystemTitle,
          child: WorkspaceRow(
            label: l10n.desktopCallsSystemSound,
            description: l10n.desktopCallsSystemSoundHint,
            trailing: DesktopButton(
              label: l10n.desktopCallsOpenSystem,
              kind: DButtonKind.tonal,
              size: DButtonSize.small,
              onPressed: () => unawaited(openSystemSoundSettings()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Системные настройки звука: громкость, устройство по умолчанию, доступ к
/// микрофону. На macOS два адреса — раздел переехал в macOS 13.
Future<void> openSystemSoundSettings() async {
  final urls = Platform.isWindows
      ? const <String>['ms-settings:sound']
      : const <String>[
          'x-apple.systempreferences:com.apple.Sound-Settings.extension',
          'x-apple.systempreferences:com.apple.preference.sound',
        ];
  for (final u in urls) {
    try {
      if (await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Следующий адрес.
    }
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
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;
    if (ctrl == null) return;
    await Clipboard.setData(ClipboardData(text: ctrl.profileId));
    if (!mounted) return;
    DesktopSnackbar.show(
      context,
      message: l10n.desktopAccountIdCopied,
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
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final ctrl = widget.controller;
    if (ctrl == null) return const _PaneScaffold(children: []);
    return _PaneScaffold(
      children: [
        WorkspaceCard(
          title: 'Secretly ID',
          description:
              l10n.desktopAccountIdHint,
          child: WorkspaceRow(
            label: ctrl.profileId,
            icon: FluentIcons.fingerprint_24_regular,
            trailing: DesktopButton(
              label: l10n.desktopAccountCopy,
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
            title: l10n.desktopAccountProfile,
            child: WorkspaceRow(
              label: l10n.desktopAccountProfileHint,
              description: l10n.desktopAccountOpenProfile,
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
    final l10n = AppLocalizations.of(context)!;
    final password = await _promptPassword(
      title: l10n.desktopScopePasswordFor(widget.title),
      hint: l10n.desktopScopeMin4,
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
        message: l10n.desktopScopeOn,
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopScopeOnFailed(desktopErrorText(e)),
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _disable() async {
    final l10n = AppLocalizations.of(context)!;
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
        message: l10n.desktopScopeOff,
        kind: DSnackKind.info,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopScopeOffFailed(desktopErrorText(e)),
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
      // Поля освобождает окно, когда его маршрут ушёл, — см. [_DisposeWithRoute].
      body: _DisposeWithRoute(
        controllers: [first, second],
        child: StatefulBuilder(
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
                  hintText: l10n.desktopServerBackupRepeat,
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
                label: l10n.saveAction,
                expand: true,
                onPressed: () {
                  final a = first.text;
                  final b = second.text;
                  if (a.length < 4) {
                    setLocal(() => error = l10n.desktopScopeMin4);
                    return;
                  }
                  if (confirm && a != b) {
                    setLocal(() => error = l10n.desktopScopePasswordsDiffer);
                    return;
                  }
                  Navigator.of(ctx).maybePop(a);
                },
              ),
            ],
          ),
        ),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final enabled = _sec.isEnabled(widget.scope);
    final cfg = _sec.scopeConfig(widget.scope);
    return WorkspaceCard(
      title: widget.title,
      description: widget.description,
      child: Column(
        children: [
          WorkspaceRow(
            label: l10n.desktopScopeTitle,
            description: enabled
                ? (cfg.method == SecurityLockMethod.password
                      ? l10n.desktopScopeOnWithPassword
                      : l10n.desktopScopeEnabled)
                : l10n.desktopScopeDisabled,
            trailing: WorkspaceSwitch(
              value: enabled,
              onChanged: (v) => unawaited(v ? _enable() : _disable()),
            ),
          ),
          if (enabled) ...[
            WorkspaceRow(
              label: l10n.desktopScopeChangePassword,
              icon: FluentIcons.key_24_regular,
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.textSecondary,
              ),
              onTap: () => unawaited(_changePassword()),
            ),
            WorkspaceRow(
              label: l10n.desktopLockNow,
              icon: FluentIcons.lock_closed_24_regular,
              trailing: DesktopButton(
                label: l10n.desktopScopeLockNow,
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
        message: l10n.desktopBlockedUnblocked(name),
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: l10n.desktopBlockedUnblockFailed(desktopErrorText(e)),
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
    final l10n = AppLocalizations.of(context)!;
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
          title: l10n.desktopBlockedTitle,
          description: ids.isEmpty
              ? l10n.desktopBlockedEmptyHint
              : l10n.desktopBlockedHint,
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
                        l10n.desktopBlockedNone,
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
                          label: l10n.desktopUnblockAction,
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
/// Причины сбоя автоматической копии, которые пишет общий контроллер. Он
/// пишет их по-английски (телефон переводит их сам), поэтому здесь — те же
/// строки дословно; `desktop_backup_honesty_test.dart` сверяет их с
/// контроллером, чтобы перевод не отвалился молча.
const String kDesktopBackupNoPasswordError = 'Auto-backup password is not set';
const String kDesktopBackupWeakPasswordError =
    'Auto-backup password does not meet the current policy';

@visibleForTesting
bool desktopBackupAutoErrorIsPassword(String raw) =>
    raw == kDesktopBackupNoPasswordError ||
    raw == kDesktopBackupWeakPasswordError;

/// Причина сбоя — на языке окна, если она известна; иначе как есть.
@visibleForTesting
String desktopBackupAutoErrorText(AppLocalizations l10n, String raw) =>
    switch (raw) {
      kDesktopBackupNoPasswordError => l10n.desktopBackupAutoPasswordMissing,
      kDesktopBackupWeakPasswordError => l10n.desktopBackupAutoPasswordWeak,
      _ => raw,
    };

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
        final raw = widget.controller.safeBackupLastAutoError;
        return (
          text: raw.isNotEmpty
              ? l10n.desktopBackupLastFailedWith(
                  desktopBackupAutoErrorText(l10n, raw),
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

  bool _autoBusy = false;

  /// Включить или выключить автоматическую копию.
  ///
  /// 🔴 БЕЗ ПАРОЛЯ НЕ ВКЛЮЧАЕТСЯ (01.10.2026). Переключатель включался сразу,
  /// а первая же копия падала с английским «Auto-backup password is not set»:
  /// защита, которая выглядит включённой и не работает. Теперь пароль
  /// спрашивается ДО включения тем же окном, что у ручной копии; отказался от
  /// окна — переключатель остаётся выключенным. И раз копия уйдёт на сервер —
  /// сначала сказать, что она заменит копию телефона.
  Future<void> _setAuto(bool on) async {
    final ctrl = widget.controller;
    if (!on) {
      await ctrl.setSafeBackupAutoEnabled(false);
      return;
    }
    if (_autoBusy) return;
    _autoBusy = true;
    try {
      if (ctrl.safeBackupAutoServerEnabled &&
          !await confirmDesktopServerBackupReplace(context)) {
        return;
      }
      if (!mounted) return;
      if (!await ctrl.hasSafeBackupAutoPassword()) {
        if (!mounted) return;
        if (!await _askAutoPassword()) return;
      }
      await ctrl.setSafeBackupAutoEnabled(true);
    } finally {
      _autoBusy = false;
    }
  }

  /// «Выгружать на сервер» при уже включённой автоматической копии — та же
  /// замена копии телефона, значит, тот же вопрос.
  Future<void> _setAutoServer(bool on) async {
    if (on && !await confirmDesktopServerBackupReplace(context)) return;
    await widget.controller.setSafeBackupAutoServerEnabled(on);
  }

  /// Спросить пароль автоматической копии и сохранить его. `false` — окно
  /// закрыли или пароль не приняли (причина показана плашкой).
  Future<bool> _askAutoPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context, rootOverlay: true);
    final palette = DColors.maybeOf(context);
    final pw = await promptDesktopBackupPassword(
      context,
      actionLabel: l10n.saveAction,
    );
    if (pw == null) return false;
    try {
      await widget.controller.setSafeBackupAutoPassword(pw);
      return true;
    } catch (e) {
      DesktopSnackbar.showIn(
        overlay,
        message: l10n.desktopFailedWith(desktopErrorText(e)),
        kind: DSnackKind.error,
        palette: palette,
      );
      return false;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              // Копия стоит из-за пароля (включали до 01.10.2026, когда пароль
              // ещё не спрашивался) — выход прямо здесь, а не только причина.
              if (auto &&
                  desktopBackupAutoErrorIsPassword(ctrl.safeBackupLastAutoError))
                Padding(
                  padding: const EdgeInsets.only(top: DSpace.m),
                  child: DesktopButton(
                    label: l10n.desktopBackupSetPassword,
                    kind: DButtonKind.tonal,
                    icon: FluentIcons.key_24_regular,
                    onPressed: () => unawaited(_askAutoPassword()),
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
                  onChanged: (v) => unawaited(_setAuto(v)),
                ),
              ),
              if (auto) ...[
                WorkspaceRow(
                  label: l10n.desktopBackupUploadServer,
                  description: l10n.desktopBackupUploadServerHint,
                  trailing: WorkspaceSwitch(
                    value: ctrl.safeBackupAutoServerEnabled,
                    onChanged: (v) => unawaited(_setAutoServer(v)),
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
                  trailing: WorkspaceSelect<int>(
                    value: _intervals.contains(ctrl.safeBackupAutoIntervalMin)
                        ? ctrl.safeBackupAutoIntervalMin
                        : _intervals[2],
                    values: _intervals,
                    labelOf: (m) => _intervalLabel(m, l10n),
                    onChanged: (v) =>
                        unawaited(ctrl.setSafeBackupAutoIntervalMinutes(v)),
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
        // 🔴 НАБОР ВОССТАНОВЛЕНИЯ — ЕДИНСТВЕННОЕ, ЧТО СПАСАЕТ ПРИ ПОТЕРЕ ВСЕГО.
        //
        // На десктопе его не было НИ ОДНОЙ точки входа, хотя резервные копии
        // здесь есть давно. Разница между ними существенная: копия это данные,
        // а набор — способ вернуть себе САМ ПРОФИЛЬ, когда устройств не
        // осталось. Человек, у которого есть копия и нет набора, не
        // восстановит ничего.
        //
        // 🔴 НАЗВАНИЕ ОДНО НА ВСЁ ОКНО (23.09.2026). Здесь стояло «ключ
        // восстановления», а на экране входа — «набор восстановления», при том
        // что обе кнопки зовут ОДНУ функцию `runRecoveryKitExport`. Человеку
        // при входе говорили «сохраните набор», а через месяц он искал это в
        // настройках и видел «ключ» — и не был уверен, то же ли это. Для
        // единственного, что спасает профиль, такая неуверенность недопустима.
        // Выбрано «набор»: это перевод телефонного «Recovery Kit», а «ключ»
        // вдобавок обещал строку, тогда как отдаётся целый набор.
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

  /// Набор восстановления — ОБЩИМ путём, одним на всё окно.
  ///
  /// Свой здесь был копией: пароль с подтверждением, проверка по политике,
  /// показ ключа. С 23.09.2026 тот же путь нужен при создании аккаунта на
  /// компьютере, а две копии
  /// разошлись бы текстами и проверками — и это тот самый ключ, которым
  /// человек однажды будет возвращать себе аккаунт.
  ///
  /// 🔴 Заодно перевод: своя копия показывала требования к паролю ВСЕГДА
  /// по-русски (`isRu: true` жёстко), то есть немец и испанец читали их на
  /// чужом языке ровно в тот момент, когда пароль не приняли.
  Future<void> _exportRecoveryKit() =>
      runRecoveryKitExport(context: context, vm: widget.vm);
}

/// «Приложить журнал?» — размер словами, «Посмотреть» и явное согласие.
/// `true` — человек согласился приложить.
@visibleForTesting
Future<bool> confirmDesktopSupportLog(
  BuildContext context,
  List<int> bytes, {
  required String sizeText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await DesktopDialog.show<bool>(
    context,
    title: l10n.desktopSupportLogConfirmTitle,
    size: DDialogSize.small,
    body: Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.desktopSupportLogConfirmBody(sizeText),
            style: DType.body.copyWith(
              color: DColors.of(ctx).textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: DSpace.m),
          DesktopButton(
            label: l10n.desktopSupportLogView,
            kind: DButtonKind.tonal,
            icon: FluentIcons.document_search_24_regular,
            onPressed: () => unawaited(
              showDesktopSupportLogText(
                ctx,
                utf8.decode(bytes, allowMalformed: true),
              ),
            ),
          ),
        ],
      ),
    ),
    primary: DDialogAction(
      label: l10n.desktopSupportLogAttachConfirm,
      onPressed: () => Navigator.of(context).maybePop(true),
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => Navigator.of(context).maybePop(false),
    ),
  );
  return ok == true;
}

/// Текст журнала — ровно то, что уйдёт. Построчно и лениво: сотни
/// килобайт одним полем текста окно раскладывало бы секундами.
@visibleForTesting
Future<void> showDesktopSupportLogText(BuildContext context, String text) {
  final l10n = AppLocalizations.of(context)!;
  final lines = const LineSplitter().convert(text);
  return DesktopDialog.show<void>(
    context,
    title: l10n.desktopSupportLogViewTitle,
    size: DDialogSize.large,
    body: Builder(
      builder: (ctx) {
        final c = DColors.of(ctx);
        return SizedBox(
          height: 440,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.chatList,
              borderRadius: BorderRadius.circular(DRadii.md),
              border: Border.all(color: c.borderSubtle),
            ),
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(DSpace.m),
                itemCount: lines.length,
                itemBuilder: (_, i) => Text(
                  lines[i],
                  style: DType.caption.copyWith(
                    color: c.textPrimary,
                    fontFamily: DType.monoFamily,
                    fontFamilyFallback: DType.monoFallback,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
    primary: DDialogAction(
      label: l10n.close,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
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
        _error = desktopErrorText(e);
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
    // 🔴 `_attaching` снимается в ЛЮБОМ исходе (30.09.2026): исключение из
    // разбора картинки оставляло кнопки вложений погашенными навсегда.
    DesktopSupportAttachmentResult? res;
    try {
      final paths = await pickDesktopAttachments(media: false);
      if (paths.isNotEmpty) {
        res = await prepareDesktopSupportAttachment(paths.first);
      }
    } catch (_) {
      res = const DesktopSupportAttachmentResult.failed(
        DesktopSupportAttachmentProblem.unreadable,
      );
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
    final picked = res;
    if (!mounted || picked == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (picked.ok) {
        _attachment = picked.file;
        return;
      }
      _error = picked.problem == DesktopSupportAttachmentProblem.tooLarge
          ? l10n.desktopSupportTooLarge(_sizeText(context, _limitBytes))
          : l10n.desktopSupportUnreadable;
    });
  }

  Future<void> _attachLog() async {
    final bytes = await DesktopDiagFileLog.recentBytes();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = l10n.desktopSupportLogEmpty);
      return;
    }
    // 🔴 Сначала — что и сколько уходит (01.10.2026). Кнопка прикладывала
    // до 900 КБ журнала молча: ни размера, ни способа заглянуть внутрь, а
    // журнал уходит чужим людям вместе с письмом.
    final ok = await confirmDesktopSupportLog(
      context,
      bytes,
      sizeText: _sizeText(context, bytes.length),
    );
    if (!ok || !mounted) return;
    final stamp = DateTime.now().toUtc().toIso8601String().split('.').first;
    setState(() {
      _error = null;
      _attachment = DesktopSupportAttachment(
        name: 'secretly-desktop-log-${stamp.replaceAll(':', '-')}.txt',
        mime: 'text/plain',
        bytes: bytes,
        originalBytes: bytes.length,
        shrunk: false,
      );
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
    final l10n = AppLocalizations.of(context)!;
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
        message: l10n.desktopSupportSent,
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
        _error = l10n.desktopSupportSendFailed;
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
            title: l10n.desktopSupportUnavailable,
            child: Text(
              l10n.desktopSupportUnavailableHint,
                style: DType.label.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ),
          // 🔴 Диагностика показывается ДАЖЕ когда канал обращений недоступен.
          // Очередь стоит независимо от того, можем ли мы принять письмо, — и
          // как раз тогда человеку нужнее всего увидеть, что происходит, и
          // получить сводку, которую можно передать нам любым другим путём.
          DesktopDeliveryDiagnostics(
            healthLoader: widget.controller.deliveryHealthCounters,
          ),
        ],
      );
    }
    final thread = _thread();
    return _PaneScaffold(
      children: [
        DesktopDeliveryDiagnostics(
          healthLoader: widget.controller.deliveryHealthCounters,
        ),
        WorkspaceCard(
          title: l10n.desktopSupportThread,
          description:
              l10n.desktopSupportThreadHint,
          rows: false,
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
                    l10n.desktopSupportNoReplies,
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
          title: l10n.desktopSupportWrite,
          description:
              l10n.desktopSupportWriteHint,
          rows: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopTextField(
                controller: _text,
                hintText: l10n.desktopSupportDescribe,
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
                label: _sending ? l10n.desktopSupportSending : l10n.desktopSupportSend,
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
          Wrap(
            spacing: DSpace.s,
            children: [
              DesktopButton(
                label: l10n.desktopSupportAttach,
                icon: FluentIcons.attach_24_regular,
                kind: DButtonKind.ghost,
                onPressed: (_attaching || _sending)
                    ? null
                    : () => unawaited(_pickAttachment()),
              ),
              // 🔴 ЖУРНАЛ — ОДНОЙ КНОПКОЙ (28.09.2026). Обрыв звонка «с
              // ошибкой связи» по серверу не разобрать: нужен журнал самого
              // компьютера. В нём события звонков и доставки, номера урезаны,
              // текста сообщений нет.
              DesktopButton(
                label: l10n.desktopSupportAttachLog,
                icon: FluentIcons.document_text_24_regular,
                kind: DButtonKind.ghost,
                onPressed: (_attaching || _sending)
                    ? null
                    : () => unawaited(_attachLog()),
              ),
            ],
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
