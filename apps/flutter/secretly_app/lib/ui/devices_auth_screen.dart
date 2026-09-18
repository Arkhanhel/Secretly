// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:lottie/lottie.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../diagnostics/diag_log.dart';
import 'app_asset_paths.dart';
import 'l10n.dart';
import 'qr_scan_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';
import 'paywall_screen.dart';
import '../billing/show_paywall.dart';

class DevicesAuthScreen extends StatefulWidget {
  const DevicesAuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DevicesAuthScreen> createState() => _DevicesAuthScreenState();
}

class _DevicesAuthScreenState extends State<DevicesAuthScreen> {
  static const String _secretlyDesktopUrl =
      'https://www.secretlyapp.com/secretly-for-desktop';

  bool _busy = false;
  Timer? _desktopLinkTicker;
  late final TapGestureRecognizer _desktopInfoLinkRecognizer;

  // PR-C (Bug 11): mobile «Управление устройствами» now shows the live list
  // of devices registered to this profile on the keys server, with «Это
  // устройство» badge + «Завершить сеанс» action on the others. Loaded once
  // on mount and refreshed after any end-session.
  List<String> _mobileDeviceIds = const [];
  bool _mobileDevicesLoading = false;
  String? _mobileDevicesError;
  String? _mobileEndingDeviceId;

  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    final localeTag = wave1LocaleTagFromContext(context);
    if (localeTag == 'ru') return ru;
    if (localeTag == 'en') return en;

    final l10n = context.l10n;
    if (en.startsWith('Device: ') &&
        en.endsWith('. Approval is allowed from primary phone only.')) {
      final name = en.substring(
        'Device: '.length,
        en.length - '. Approval is allowed from primary phone only.'.length,
      );
      return l10n.devicesApprovalDeviceOnly(name);
    }
    if (en.startsWith('QR expires in ')) {
      return l10n.devicesQrExpiresIn(en.substring('QR expires in '.length));
    }

    switch (en) {
      case 'Could not open the link in a browser.':
        return l10n.devicesLinkOpenFailed;
      case 'You can sign in to the ':
        return l10n.devicesDesktopDescriptionPrefix;
      case 'Secretly desktop app':
        return l10n.devicesDesktopAppLink;
      case ' using a QR code.':
        return l10n.devicesDesktopDescriptionSuffix;
      case 'Transport is blocked for the current server. Switch phone and desktop to the same server and retry.':
        return l10n.devicesFailureTransportBlocked;
      case 'Desktop identity is not server-backed yet. Retry in a few seconds.':
        return l10n.devicesFailureIdentityNotServerBacked;
      case 'Desktop profile is not visible on the server yet. Keep the app open and retry.':
        return l10n.devicesFailureProfileUnavailable;
      case 'Desktop device is not visible on the server yet. Keep the app open, refresh the QR, and retry.':
        return l10n.devicesFailureDeviceUnavailable;
      case 'Desktop companion access is not enabled for this profile. Activate it on the primary phone and retry.':
        return l10n.devicesFailureCompanionRequired;
      case 'Desktop companion limit is already in use for this profile. Remove an old desktop device or increase available seats.':
        return l10n.devicesFailureCompanionLimit;
      case 'Create the main account on a phone first, then link desktop with QR.':
        return l10n.devicesFailurePrimaryRequired;
      case 'This QR is not a device authorization code.':
        return l10n.devicesFailureInvalidQr;
      case 'QR code expired. Generate a new one on desktop.':
        return l10n.devicesFailureQrExpired;
      case 'This QR belongs to a different server. Switch phone and desktop to the same server and retry.':
        return l10n.devicesFailureServerMismatch;
      case 'Sync bundle targets a different profile. Generate a new QR and retry.':
        return l10n.devicesFailureProfileMismatch;
      case 'Desktop sync request was not found or already expired. Generate a new QR.':
        return l10n.devicesFailureRequestNotFound;
      case 'QR session expired. Generate a new QR and retry.':
        return l10n.devicesFailureSessionExpired;
      case 'QR session validation failed. Generate a new QR and retry.':
        return l10n.devicesFailureSessionValidation;
      case 'Sync request state no longer matches. Generate a new QR and retry.':
        return l10n.devicesFailureStateMismatch;
      case 'Sync bundle targets a different device. Generate a new QR and retry.':
        return l10n.devicesFailureDeviceMismatch;
      case 'Sign-in was declined on the primary phone. Generate a new QR to retry.':
        return l10n.devicesFailureDeclined;
      case 'Invalid desktop sync payload. Generate a new QR and retry.':
        return l10n.devicesFailureInvalidPayload;
      case 'Secure sync was interrupted before completion. Generate a new QR and retry.':
        return l10n.devicesFailureInterrupted;
      case 'New user':
        return l10n.devicesNewUser;
      case 'Clear local data and prepare this desktop device for QR sign-in from the primary phone?':
        return l10n.devicesNewUserDesktopConfirm;
      case 'Clear current local profile and register a new user on this device?':
        return l10n.devicesNewUserMobileConfirm;
      case 'Cancel':
        return l10n.cancel;
      case 'Continue':
        return l10n.continueAction;
      case 'Create':
        return l10n.devicesCreateAction;
      case 'Scan device QR':
        return l10n.devicesScanDeviceQr;
      case 'Request approved. Sync package sent to desktop.':
        return l10n.devicesRequestApproved;
      case 'Request declined. Desktop remains unauthenticated.':
        return l10n.devicesRequestDeclined;
      case 'Approve sign-in on this device?':
        return l10n.devicesApproveSignInTitle;
      case 'Confirm sync from the primary device (phone).':
        return l10n.devicesConfirmSyncPrimary;
      case 'Sync chats':
        return l10n.devicesSyncChats;
      case 'Sync settings':
        return l10n.devicesSyncSettings;
      case 'Sync media':
        return l10n.devicesSyncMedia;
      case 'Close':
        return l10n.close;
      case 'Decline sign-in':
        return l10n.devicesDeclineSignIn;
      case 'Approve':
        return l10n.devicesApprove;
      case 'Devices':
        return l10n.devicesTitle;
      case 'Connect device':
        return l10n.devicesConnectDevice;
      case 'This is the primary device':
        return l10n.devicesPrimaryDeviceTitle;
      case 'Permission for chat/settings/media sync is granted only here.':
        return l10n.devicesPrimaryDeviceSubtitle;
      case 'QR session expired. Generate a new code.':
        return l10n.devicesQrSessionExpiredNewCode;
      case 'Waiting for QR scan on phone.':
        return l10n.devicesWaitingQrScan;
      case 'QR scanned. Confirm sign-in on phone.':
        return l10n.devicesQrScannedConfirm;
      case 'Applying secure sync bundle…':
        return l10n.devicesApplyingSecureBundle;
      case 'Authorization failed. Please retry.':
        return l10n.devicesAuthorizationFailed;
      case 'You are not authenticated. Choose an action below.':
        return l10n.devicesUnauthenticatedChooseAction;
      case 'Device is authenticated.':
        return l10n.devicesAuthenticated;
      case 'Desktop/Web authorization':
        return l10n.devicesDesktopWebAuthorization;
      case 'Choose mode: register a new user or sign in via QR with phone approval.':
        return l10n.devicesDesktopModeDescription;
      case 'Cancel QR':
        return l10n.devicesCancelQr;
      case 'Refresh QR':
        return l10n.devicesRefreshQr;
      case 'Sign in via QR':
        return l10n.devicesSignInViaQr;
      case 'Open Secretly on primary phone → Settings → Devices → Connect device.':
        return l10n.devicesOpenPrimaryInstruction;
      default:
        return en;
    }
  }

  @override
  void initState() {
    super.initState();
    _desktopInfoLinkRecognizer = TapGestureRecognizer()
      ..onTap = () {
        unawaited(_openSecretlyDesktopPage());
      };
    if (_isDesktopOrWeb) {
      _desktopLinkTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(widget.controller.expireDesktopLinkRequestsIfNeeded());
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      // PR-C: only the mobile path renders the device list — desktop builds
      // own list inside DesktopProductionApp → Settings → Devices.
      unawaited(_loadMobileDevices());
    }
  }

  /// Loads the list of devices registered to the current profile on the
  /// keys server and refreshes the UI. Used by the mobile «Управление
  /// устройствами» card. Errors are surfaced inline (not thrown) so the
  /// card can show a Retry row instead of an empty list.
  Future<void> _loadMobileDevices() async {
    if (!mounted) return;
    setState(() {
      _mobileDevicesLoading = true;
      _mobileDevicesError = null;
    });
    try {
      final ids = await widget.controller.listMyDeviceIds();
      if (!mounted) return;
      setState(() {
        _mobileDeviceIds = ids;
        _mobileDevicesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileDevicesError = e.toString();
        _mobileDevicesLoading = false;
      });
    }
  }

  /// Trims a device id for display so a 32+ char hash doesn't blow up the
  /// row. We still copy the full id to telemetry / clipboard if needed.
  String _shortDeviceId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  /// Confirmation flow for «Завершить сеанс». Shows an AlertDialog, then
  /// — if confirmed — calls [AppController.endDeviceSession] and reloads
  /// the list. Errors surface as a SnackBar; the UI stays interactive.
  Future<void> _promptEndDeviceSession(BuildContext context, String id) async {
    final tdid = id.trim();
    if (tdid.isEmpty || _mobileEndingDeviceId != null) return;

    // Capture messenger BEFORE the first await so the post-await snackbar
    // doesn't trip `use_build_context_synchronously` and stays valid even
    // if the host widget is rebuilt mid-flight.
    final messenger = ScaffoldMessenger.of(context);
    final failurePrefixRu = 'Не удалось завершить сеанс: ';
    final failurePrefixEn = 'Could not end session: ';
    final successTextRu = 'Сеанс устройства завершён.';
    final successTextEn = 'Device session ended.';
    final useRu = _label(context, ru: 'ru', en: 'en') == 'ru';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            _label(
              context,
              ru: 'Завершить сеанс?',
              en: 'End session?',
            ),
          ),
          content: Text(
            _label(
              context,
              ru: 'Это устройство будет отключено от вашего профиля. Чтобы вернуть доступ, потребуется повторное сканирование QR. Продолжить?',
              en: 'This device will be disconnected from your profile. To restore access, scan the QR again. Continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(_label(context, ru: 'Отмена', en: 'Cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                _label(context, ru: 'Завершить', en: 'End session'),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _mobileEndingDeviceId = tdid;
    });
    String? errorMsg;
    try {
      await widget.controller.endDeviceSession(targetDeviceId: tdid);
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _mobileEndingDeviceId = null;
        });
      }
    }

    if (!mounted) return;
    if (errorMsg != null) {
      final prefix = useRu ? failurePrefixRu : failurePrefixEn;
      messenger.showSnackBar(
        SecretlySnackBar(content: Text('$prefix$errorMsg')),
      );
      DiagLog.event('devices', 'end_session_fail', {'reason': errorMsg});
    } else {
      messenger.showSnackBar(
        SecretlySnackBar(
          content: Text(useRu ? successTextRu : successTextEn),
        ),
      );
    }
    await _loadMobileDevices();
  }

  @override
  void dispose() {
    _desktopInfoLinkRecognizer.dispose();
    _desktopLinkTicker?.cancel();
    super.dispose();
  }

  Future<void> _openSecretlyDesktopPage() async {
    final uri = Uri.tryParse(_secretlyDesktopUrl);
    if (uri == null) {
      return;
    }
    try {
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (opened || !mounted) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          _label(
            context,
            ru: 'Не удалось открыть ссылку в браузере.',
            en: 'Could not open the link in a browser.',
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLinkDescription(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final cs = Theme.of(context).colorScheme;
    final linkStyle = bodyStyle?.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
    );
    return Text.rich(
      TextSpan(
        style: bodyStyle,
        children: [
          TextSpan(
            text: _label(
              context,
              ru: 'Вы можете зайти в приложение ',
              en: 'You can sign in to the ',
            ),
          ),
          TextSpan(
            text: _label(
              context,
              ru: 'Secretly на компьютере',
              en: 'Secretly desktop app',
            ),
            style: linkStyle,
            recognizer: _desktopInfoLinkRecognizer,
          ),
          TextSpan(
            text: _label(
              context,
              ru: ' с помощью QR кода.',
              en: ' using a QR code.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateDesktopQr() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.createDesktopLinkRequest(
        deviceLabel: _desktopDeviceLabel(),
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(_desktopLinkErrorText(context, e))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _desktopDeviceLabel() {
    if (kIsWeb) return 'Web Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Windows Desktop';
      case TargetPlatform.macOS:
        return 'macOS Desktop';
      case TargetPlatform.linux:
        return 'Linux Desktop';
      default:
        return 'Desktop/Web';
    }
  }

  String _desktopLinkFailureLabel(
    BuildContext context,
    DesktopLinkFailure failure,
  ) {
    switch (failure.code) {
      case DesktopLinkFailureCode.targetTransportBlocked:
        return _label(
          context,
          ru: 'Транспорт заблокирован для текущего сервера. Переключите телефон и desktop на один сервер и повторите.',
          en: 'Transport is blocked for the current server. Switch phone and desktop to the same server and retry.',
        );
      case DesktopLinkFailureCode.targetIdentityNotServerBacked:
        return _label(
          context,
          ru: 'Desktop-профиль еще не зарегистрирован на сервере. Повторите попытку через несколько секунд.',
          en: 'Desktop identity is not server-backed yet. Retry in a few seconds.',
        );
      case DesktopLinkFailureCode.targetProfileUnavailable:
        return _label(
          context,
          ru: 'Профиль desktop пока не виден на сервере. Держите приложение открытым и повторите попытку.',
          en: 'Desktop profile is not visible on the server yet. Keep the app open and retry.',
        );
      case DesktopLinkFailureCode.targetDeviceUnavailable:
        return _label(
          context,
          ru: 'Устройство desktop пока не видно на сервере. Держите приложение открытым, затем обновите QR и повторите.',
          en: 'Desktop device is not visible on the server yet. Keep the app open, refresh the QR, and retry.',
        );
      case DesktopLinkFailureCode.keysPublishRejected:
        return _label(
          context,
          ru: 'Сервер отклонил связку ключей компьютера, поэтому подключение '
              'не начинается. Проверьте, что на компьютере включены '
              'автоматические дата и время, и обновите QR.',
          en: 'The server refused the computer key bundle, so pairing cannot '
              'start. Make sure the computer date and time are set '
              'automatically, then refresh the QR.',
        );
      case DesktopLinkFailureCode.desktopCompanionEntitlementRequired:
        return _label(
          context,
          ru: 'Для этого профиля не включён desktop companion. Активируйте доступ на основном телефоне и повторите попытку.',
          en: 'Desktop companion access is not enabled for this profile. Activate it on the primary phone and retry.',
        );
      case DesktopLinkFailureCode.desktopCompanionLimitReached:
        return _label(
          context,
          ru: 'Лимит desktop-устройств для этого профиля исчерпан. Удалите старое desktop-устройство или увеличьте доступные места.',
          en: 'Desktop companion limit is already in use for this profile. Remove an old desktop device or increase available seats.',
        );
      case DesktopLinkFailureCode.desktopPrimaryDeviceRequired:
        return _label(
          context,
          ru: 'Основной аккаунт нужно создать на телефоне, а desktop подключать через QR.',
          en: 'Create the main account on a phone first, then link desktop with QR.',
        );
      case DesktopLinkFailureCode.invalidQrPayload:
        return _label(
          context,
          ru: 'Это не QR для авторизации устройства.',
          en: 'This QR is not a device authorization code.',
        );
      case DesktopLinkFailureCode.qrExpired:
        return _label(
          context,
          ru: 'Срок действия QR истёк. Создайте новый код на desktop.',
          en: 'QR code expired. Generate a new one on desktop.',
        );
      case DesktopLinkFailureCode.serverBindingMismatch:
        return _label(
          context,
          ru: 'Этот QR относится к другому серверу. Переключите телефон и desktop на один сервер и повторите.',
          en: 'This QR belongs to a different server. Switch phone and desktop to the same server and retry.',
        );
      case DesktopLinkFailureCode.syncTargetProfileMismatch:
        return _label(
          context,
          ru: 'Пакет синхронизации относится к другому профилю. Создайте новый QR и повторите.',
          en: 'Sync bundle targets a different profile. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.syncRequestNotFound:
        return _label(
          context,
          ru: 'Запрос синхронизации не найден или уже истёк. Создайте новый QR.',
          en: 'Desktop sync request was not found or already expired. Generate a new QR.',
        );
      case DesktopLinkFailureCode.syncSessionExpired:
        return _label(
          context,
          ru: 'Сессия QR истекла. Создайте новый QR и повторите.',
          en: 'QR session expired. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.syncNonceMismatch:
        return _label(
          context,
          ru: 'Проверка QR-сессии не прошла. Создайте новый QR и повторите.',
          en: 'QR session validation failed. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.syncRequestStateMismatch:
        return _label(
          context,
          ru: 'Состояние запроса синхронизации больше не актуально. Создайте новый QR и повторите.',
          en: 'Sync request state no longer matches. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.syncTargetDeviceMismatch:
        return _label(
          context,
          ru: 'Пакет синхронизации относится к другому устройству. Создайте новый QR и повторите.',
          en: 'Sync bundle targets a different device. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.decisionDeclined:
        return _label(
          context,
          ru: 'Вход был отклонён на основном телефоне. Создайте новый QR и повторите попытку.',
          en: 'Sign-in was declined on the primary phone. Generate a new QR to retry.',
        );
      case DesktopLinkFailureCode.invalidSyncPayload:
        return _label(
          context,
          ru: 'Получен некорректный пакет синхронизации. Создайте новый QR и повторите.',
          en: 'Invalid desktop sync payload. Generate a new QR and retry.',
        );
      case DesktopLinkFailureCode.syncInterrupted:
        return _label(
          context,
          ru: 'Защищённая синхронизация была прервана. Создайте новый QR и повторите.',
          en: 'Secure sync was interrupted before completion. Generate a new QR and retry.',
        );
    }
  }

  String _desktopLinkErrorText(BuildContext context, Object error) {
    if (error is DesktopLinkFailure) {
      return _desktopLinkFailureLabel(context, error);
    }
    return error.toString();
  }

  Future<void> _resetForNewUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_label(context, ru: 'Новый пользователь', en: 'New user')),
        content: Text(
          _label(
            context,
            ru: _isDesktopOrWeb
                ? 'Очистить локальные данные и подготовить это desktop-устройство для входа через QR с основного телефона?'
                : 'Очистить текущий локальный профиль и зарегистрировать нового пользователя на этом устройстве?',
            en: _isDesktopOrWeb
                ? 'Clear local data and prepare this desktop device for QR sign-in from the primary phone?'
                : 'Clear current local profile and register a new user on this device?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_label(context, ru: 'Отмена', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _label(
                context,
                ru: _isDesktopOrWeb ? 'Продолжить' : 'Создать',
                en: _isDesktopOrWeb ? 'Continue' : 'Create',
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.controller.createNewServerProfileForCurrentDevice();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(_desktopLinkErrorText(context, error))),
      );
    }
  }

  Future<void> _scanDesktopQrOnPhone() async {
    if (_busy) return;
    // Diag hotfix 2026-05-19: instrument QR pairing flow on mobile so release
    // builds can be diagnosed via logcat. Every checkpoint emits a Sly/Diag
    // event so we can prove where the flow stops when the user reports
    // "ничего не происходит" after scan.
    DiagLog.event('qr_pair', 'scan_open');
    final raw = await QrScanScreen.scan(
      context,
      title: _label(
        context,
        ru: 'Сканировать QR устройства',
        en: 'Scan device QR',
      ),
    );
    DiagLog.event('qr_pair', 'scan_close', {
      'has_raw': raw != null && raw.trim().isNotEmpty,
      'raw_len': raw?.length ?? 0,
      'mounted': mounted,
    });
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    final payload = DesktopLinkQrPayload.tryParse(raw);
    DiagLog.event('qr_pair', 'parse', {
      'ok': payload != null,
      'target_pid': DiagLog.pfx(payload?.targetProfileId),
      'target_did': DiagLog.pfx(payload?.targetDeviceId),
    });
    if (payload == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _label(
              context,
              ru: 'Это не QR для авторизации устройства.',
              en: 'This QR is not a device authorization code.',
            ),
          ),
        ),
      );
      return;
    }

    final decision = await _showApproveDialog(payload);
    DiagLog.event('qr_pair', 'dialog_decision', {
      'is_null': decision == null,
      'approved': decision?.isApproved,
      'sync_chats': decision?.syncChats,
      'sync_settings': decision?.syncSettings,
      'sync_media': decision?.syncMedia,
    });
    if (decision == null) return;

    setState(() => _busy = true);
    try {
      if (decision.isApproved) {
        DiagLog.event('qr_pair', 'approve_call_start');
        await widget.controller.approveDesktopLinkFromQr(
          rawPayload: raw,
          syncChats: decision.syncChats,
          syncSettings: decision.syncSettings,
          syncMedia: decision.syncMedia,
        );
        DiagLog.event('qr_pair', 'approve_call_done');
      } else {
        DiagLog.event('qr_pair', 'reject_call_start');
        await widget.controller.rejectDesktopLinkFromQr(rawPayload: raw);
        DiagLog.event('qr_pair', 'reject_call_done');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            decision.isApproved
                ? _label(
                    context,
                    ru: 'Запрос подтверждён. Синхронизация отправлена на компьютер.',
                    en: 'Request approved. Sync package sent to desktop.',
                  )
                : _label(
                    context,
                    ru: 'Запрос отклонён. Desktop останется неавторизованным.',
                    en: 'Request declined. Desktop remains unauthenticated.',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // §C-3b: a Free profile can't link a companion device. Offer the upgrade
      // (desktop paywall) instead of a dead-end error — this runs on the phone
      // approving the desktop, where in-app purchase is available. The server
      // already enforces this; the paywall is inert while monetization is off.
      if (e is DesktopLinkFailure &&
          e.code ==
              DesktopLinkFailureCode.desktopCompanionEntitlementRequired) {
        await showPaywall(context, PaywallTrigger.desktop);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(_desktopLinkErrorText(context, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDesktopQr(String requestId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.cancelDesktopLinkRequest(requestId);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<_ApprovalDecision?> _showApproveDialog(
    DesktopLinkQrPayload payload,
  ) async {
    bool syncChats = true;
    bool syncSettings = true;
    bool syncMedia = false;
    final name = payload.deviceLabel.trim();

    return showModalBottomSheet<_ApprovalDecision>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(
                        context,
                        ru: 'Разрешить вход на устройстве?',
                        en: 'Approve sign-in on this device?',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isEmpty
                          ? _label(
                              context,
                              ru: 'Подтвердите синхронизацию с основного устройства (телефон).',
                              en: 'Confirm sync from the primary device (phone).',
                            )
                          : _label(
                              context,
                              ru: 'Устройство: $name. Подтверждение выполняется только с основного телефона.',
                              en: 'Device: $name. Approval is allowed from primary phone only.',
                            ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: syncChats,
                      title: Text(
                        _label(
                          context,
                          ru: 'Синхронизировать чаты',
                          en: 'Sync chats',
                        ),
                      ),
                      onChanged: (v) {
                        setModalState(() {
                          syncChats = v;
                          if (!syncChats) syncMedia = false;
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: syncSettings,
                      title: Text(
                        _label(
                          context,
                          ru: 'Синхронизировать настройки',
                          en: 'Sync settings',
                        ),
                      ),
                      onChanged: (v) => setModalState(() => syncSettings = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: syncMedia,
                      title: Text(
                        _label(
                          context,
                          ru: 'Синхронизировать медиа',
                          en: 'Sync media',
                        ),
                      ),
                      onChanged: syncChats
                          ? (v) => setModalState(() => syncMedia = v)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: Text(
                              _label(context, ru: 'Закрыть', en: 'Close'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(const _ApprovalDecision.decline()),
                            icon: const Icon(Icons.block_rounded),
                            label: Text(
                              _label(
                                context,
                                ru: 'Отклонить вход',
                                en: 'Decline sign-in',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (!syncChats && !syncSettings)
                                ? null
                                : () => Navigator.of(context).pop(
                                    _ApprovalDecision.approve(
                                      syncChats: syncChats,
                                      syncSettings: syncSettings,
                                      syncMedia: syncMedia,
                                    ),
                                  ),
                            child: Text(
                              _label(context, ru: 'Разрешить', en: 'Approve'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(_label(context, ru: 'Устройства', en: 'Devices')),
      ),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.only(
              top: topInset,
              bottom: 112 + bottomInset,
              left: 16,
              right: 16,
            ),
            children: _isDesktopOrWeb
                ? _buildDesktopContent(context)
                : _buildMobileContent(context),
          );
        },
      ),
    );
  }

  List<Widget> _buildMobileContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return [
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 140,
                child: Center(
                  child: Lottie.asset(
                    AppAssetPaths.devicesAuthSyncLottie,
                    repeat: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDesktopLinkDescription(context),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _scanDesktopQrOnPhone,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    _label(
                      context,
                      ru: 'Подключить устройство',
                      en: 'Connect device',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: Icon(Icons.fingerprint, color: cs.primary),
          title: Text(
            _label(
              context,
              ru: 'Это основное устройство',
              en: 'This is the primary device',
            ),
          ),
          subtitle: Text(
            _label(
              context,
              ru: 'Разрешение на синхронизацию чатов, настроек и медиа выдаётся только здесь.',
              en: 'Permission for chat/settings/media sync is granted only here.',
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // PR-C (Bug 11): live list of devices registered to this profile on
      // the keys server. The «Это устройство» row marks the current handset;
      // every other row gets a «Завершить сеанс» trailing button gated by
      // an AlertDialog. End-session calls AppController.endDeviceSession
      // which signs the request with this handset's identity key and the
      // keys server verifies that requester+target share the same profile.
      _MobileDevicesCard(
        myDeviceId: widget.controller.deviceId,
        deviceIds: _mobileDeviceIds,
        loading: _mobileDevicesLoading,
        error: _mobileDevicesError,
        endingDeviceId: _mobileEndingDeviceId,
        onRetry: _loadMobileDevices,
        onRefresh: _loadMobileDevices,
        onEndSession: (id) => _promptEndDeviceSession(context, id),
        shortId: _shortDeviceId,
        labelThisDevice: _label(
          context,
          ru: 'Это устройство',
          en: 'This device',
        ),
        labelOtherDevice: _label(
          context,
          ru: 'Подключённое устройство',
          en: 'Linked device',
        ),
        labelEndSession: _label(
          context,
          ru: 'Завершить сеанс',
          en: 'End session',
        ),
        labelLoadingRow: _label(
          context,
          ru: 'Загрузка списка устройств…',
          en: 'Loading devices…',
        ),
        labelEmpty: _label(
          context,
          ru: 'Профиль ещё не зарегистрирован на сервере.',
          en: 'Profile is not yet registered on the server.',
        ),
        labelRefresh: _label(
          context,
          ru: 'Обновить список',
          en: 'Refresh list',
        ),
        labelRetry: _label(context, ru: 'Повторить', en: 'Retry'),
        labelErrorTitle: _label(
          context,
          ru: 'Не удалось загрузить список',
          en: 'Could not load devices',
        ),
        labelCardTitle: _label(
          context,
          ru: 'Активные сессии',
          en: 'Active sessions',
        ),
        labelCardSubtitle: _label(
          context,
          ru: 'Список устройств, привязанных к этому профилю.',
          en: 'Devices currently linked to this profile.',
        ),
        accentColor: cs.primary,
      ),
    ];
  }

  List<Widget> _buildDesktopContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final req = widget.controller.activeDesktopLinkRequest;
    final qrData = req == null
        ? null
        : widget.controller.buildDesktopLinkQrPayload(req);
    final flowState = widget.controller.authFlowState;
    final flowError = widget.controller.authFlowError;
    final flowFailure = widget.controller.authFlowFailure;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    String? expiryText() {
      if (req == null) return null;
      final remainingMs = req.expiresAtMs - nowMs;
      if (remainingMs <= 0) {
        return _label(
          context,
          ru: 'Срок действия QR истёк. Сгенерируйте новый код.',
          en: 'QR session expired. Generate a new code.',
        );
      }
      final remainingSeconds = (remainingMs / 1000).ceil();
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      return _label(
        context,
        ru: 'QR действует ещё ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        en: 'QR expires in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      );
    }

    String statusText() {
      switch (flowState) {
        case AuthFlowState.qrSessionPending:
          return _label(
            context,
            ru: 'Ожидание сканирования QR на телефоне.',
            en: 'Waiting for QR scan on phone.',
          );
        case AuthFlowState.qrScannedWaitConfirm:
          return _label(
            context,
            ru: 'QR отсканирован. Подтвердите вход на телефоне.',
            en: 'QR scanned. Confirm sign-in on phone.',
          );
        case AuthFlowState.bundleApplying:
          return _label(
            context,
            ru: 'Применяем защищённый пакет синхронизации…',
            en: 'Applying secure sync bundle…',
          );
        case AuthFlowState.authError:
          if (flowFailure != null) {
            return _desktopLinkFailureLabel(context, flowFailure);
          }
          return flowError?.trim().isNotEmpty == true
              ? flowError!
              : _label(
                  context,
                  ru: 'Ошибка авторизации. Повторите попытку.',
                  en: 'Authorization failed. Please retry.',
                );
        case AuthFlowState.unauthenticated:
          return _label(
            context,
            ru: 'Вы не авторизованы. Выберите действие ниже.',
            en: 'You are not authenticated. Choose an action below.',
          );
        case AuthFlowState.authenticated:
          return _label(
            context,
            ru: 'Устройство авторизовано.',
            en: 'Device is authenticated.',
          );
      }
    }

    return [
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                child: Center(
                  child: Lottie.asset(
                    AppAssetPaths.devicesAuthSyncLottie,
                    repeat: true,
                  ),
                ),
              ),
              Text(
                _label(
                  context,
                  ru: 'Авторизация на Desktop/Web',
                  en: 'Desktop/Web authorization',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _label(
                  context,
                  ru: 'Выберите режим: зарегистрировать нового пользователя или войти через QR с подтверждением на телефоне.',
                  en: 'Choose mode: register a new user or sign in via QR with phone approval.',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusText(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: flowState == AuthFlowState.authError
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
              if (expiryText() != null) ...[
                const SizedBox(height: 6),
                Text(
                  expiryText()!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : (req != null
                                ? () => _cancelDesktopQr(req.requestId)
                                : _resetForNewUser),
                      icon: Icon(
                        req != null
                            ? Icons.close_rounded
                            : Icons.person_add_alt_1_rounded,
                      ),
                      label: Text(
                        req != null
                            ? _label(
                                context,
                                ru: 'Отменить QR',
                                en: 'Cancel QR',
                              )
                            : _label(
                                context,
                                ru: 'Новый пользователь',
                                en: 'New user',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _generateDesktopQr,
                      icon: Icon(
                        req != null
                            ? Icons.refresh_rounded
                            : Icons.qr_code_2_rounded,
                      ),
                      label: Text(
                        req != null
                            ? _label(
                                context,
                                ru: 'Обновить QR',
                                en: 'Refresh QR',
                              )
                            : _label(
                                context,
                                ru: 'Войти по QR',
                                en: 'Sign in via QR',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              if (qrData != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _label(
                          context,
                          ru: 'Откройте Secretly на основном телефоне → Настройки → Устройства → Подключить устройство.',
                          en: 'Open Secretly on primary phone → Settings → Devices → Connect device.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}

class _ApprovalDecision {
  const _ApprovalDecision.approve({
    required this.syncChats,
    required this.syncSettings,
    required this.syncMedia,
  }) : isApproved = true;

  const _ApprovalDecision.decline()
    : isApproved = false,
      syncChats = false,
      syncSettings = false,
      syncMedia = false;

  final bool isApproved;
  final bool syncChats;
  final bool syncSettings;
  final bool syncMedia;
}

/// PR-C: stateless devices-list card rendered inside mobile «Управление
/// устройствами». All state lives in [_DevicesAuthScreenState] — this widget
/// is a pure renderer + delegate hub so the parent's `setState` reliably
/// drives row spinners, error rows, etc.
class _MobileDevicesCard extends StatelessWidget {
  const _MobileDevicesCard({
    required this.myDeviceId,
    required this.deviceIds,
    required this.loading,
    required this.error,
    required this.endingDeviceId,
    required this.onRetry,
    required this.onRefresh,
    required this.onEndSession,
    required this.shortId,
    required this.labelThisDevice,
    required this.labelOtherDevice,
    required this.labelEndSession,
    required this.labelLoadingRow,
    required this.labelEmpty,
    required this.labelRefresh,
    required this.labelRetry,
    required this.labelErrorTitle,
    required this.labelCardTitle,
    required this.labelCardSubtitle,
    required this.accentColor,
  });

  final String myDeviceId;
  final List<String> deviceIds;
  final bool loading;
  final String? error;
  final String? endingDeviceId;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String deviceId) onEndSession;
  final String Function(String id) shortId;
  final String labelThisDevice;
  final String labelOtherDevice;
  final String labelEndSession;
  final String labelLoadingRow;
  final String labelEmpty;
  final String labelRefresh;
  final String labelRetry;
  final String labelErrorTitle;
  final String labelCardTitle;
  final String labelCardSubtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final body = <Widget>[];

    if (loading && deviceIds.isEmpty && error == null) {
      body.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(labelLoadingRow, style: tt.bodyMedium),
              ),
            ],
          ),
        ),
      );
    } else if (error != null && deviceIds.isEmpty) {
      body.add(
        ListTile(
          leading: Icon(Icons.error_outline_rounded, color: cs.error),
          title: Text(labelErrorTitle),
          subtitle: Text(error!, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: TextButton(
            onPressed: loading ? null : () => unawaited(onRetry()),
            child: Text(labelRetry),
          ),
        ),
      );
    } else if (deviceIds.isEmpty) {
      body.add(
        ListTile(
          leading: Icon(
            Icons.phonelink_off_rounded,
            color: cs.onSurfaceVariant,
          ),
          title: Text(labelEmpty),
        ),
      );
    } else {
      final myDid = myDeviceId.trim();
      for (var i = 0; i < deviceIds.length; i++) {
        final id = deviceIds[i];
        final isThis = id == myDid;
        final isBusy = endingDeviceId == id;
        body.add(
          ListTile(
            leading: Icon(
              isThis
                  ? Icons.smartphone_rounded
                  : Icons.devices_other_rounded,
              color: isThis ? accentColor : cs.onSurfaceVariant,
            ),
            title: Text(
              isThis ? labelThisDevice : labelOtherDevice,
              style: tt.bodyLarge?.copyWith(
                fontWeight: isThis ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              shortId(id),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: isThis
                ? null
                : (isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : TextButton(
                          onPressed: endingDeviceId != null
                              ? null
                              : () => unawaited(onEndSession(id)),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          child: Text(labelEndSession),
                        )),
          ),
        );
        if (i != deviceIds.length - 1) {
          body.add(const Divider(height: 1));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelCardTitle,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelCardSubtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...body,
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            title: Text(labelRefresh),
            onTap: loading ? null : () => unawaited(onRefresh()),
          ),
        ),
      ],
    );
  }
}
