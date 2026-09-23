// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_controller.dart';
import '../app/desktop_app_view_model.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';

/// Real QR-link onboarding for fresh desktop installs.
///
/// Flow:
/// 1. On first frame, asks [AppController.createDesktopLinkRequest] to mint a
///    new server-backed identity for this desktop and return a
///    [DesktopLinkRequest] (or surface a [DesktopLinkFailure]).
/// 2. Renders the request's QR payload (built via
///    [AppController.buildDesktopLinkQrPayload]) so the user can scan it on
///    their phone.
/// 3. Rebuilds on the shared controller tick to reflect status transitions
///    (pending → scanned → applied) and to surface errors. Once the controller
///    accepts a sync bundle and clears [AppController.requiresDesktopProfileSelection],
///    [DesktopProductionApp] swaps this screen out for the shell — no action
///    needed here beyond rebuilding.
class DesktopOnboardingScreen extends StatefulWidget {
  const DesktopOnboardingScreen({super.key, required this.vm, this.onBack});

  /// Вернуться к выбору способа входа. `null` — выбора нет и возвращаться
  /// некуда (так было до 23.09.2026, когда привязка была единственным входом).
  ///
  /// 🔴 Сам экран привязки при этом НЕ ТРОНУТ: он был единственным рабочим
  /// входом, и переделывать его ради нового выбора значило бы поставить под
  /// удар то, что работает.
  final VoidCallback? onBack;

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;

  @override
  State<DesktopOnboardingScreen> createState() =>
      _DesktopOnboardingScreenState();
}

class _DesktopOnboardingScreenState extends State<DesktopOnboardingScreen> {
  /// Подписи экрана. Короткая дорога: `AppLocalizations.of(context)!` в
  /// каждой строке читался бы хуже самой подписи.
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  DesktopLinkRequest? _request;
  String? _qrPayload;
  String? _errorMessage;
  bool _busy = false;

  /// A link request is valid for ten minutes. Nothing used to notice when that
  /// ran out: the screen kept showing the dead QR, the refresh button reads
  /// «Ожидаем подтверждения…» and is disabled while waiting, so the user was
  /// left scanning a code that could never work and got no feedback at all.
  /// Field report: "отсканировал, но подключения нет" — the QR on screen had
  /// expired four minutes earlier.
  Timer? _ticker;

  /// Time left on the current request. A [ValueNotifier] rather than
  /// `setState` so the once-a-second countdown repaints only the caption —
  /// rebuilding the whole subtree would re-encode the QR bitmap every tick.
  final ValueNotifier<Duration> _timeLeft =
      ValueNotifier<Duration>(Duration.zero);

  @override
  void initState() {
    super.initState();
    // Rebuild on the shared, debounced tick rather than a subscription of
    // this screen's own.
    //
    // NOT diffed, deliberately: this screen is what the user stares at while a
    // phone scans the QR, and the transitions it must catch (request accepted,
    // profile appears, auth state moves) are exactly the ones a signature
    // could get wrong. Stranding someone on a dead QR is the failure this
    // screen already had once — see the field report above.
    widget.vm.ticks.addListener(_onTick_);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRequest());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timeLeft.dispose();
    widget.vm.ticks.removeListener(_onTick_);
    super.dispose();
  }

  /// Controller tick: something moved, redraw the pairing state.
  ///
  /// Named with a trailing underscore to stay clear of [_onTick], which is the
  /// once-a-second countdown and a different thing entirely.
  void _onTick_() {
    if (mounted) setState(() {});
  }

  /// Keeps the countdown honest and replaces the code the moment it dies.
  void _onTick() {
    if (!mounted) return;
    final req = _request;
    if (req == null) {
      _timeLeft.value = Duration.zero;
      return;
    }
    final leftMs = req.expiresAtMs - DateTime.now().millisecondsSinceEpoch;
    _timeLeft.value = Duration(milliseconds: leftMs > 0 ? leftMs : 0);
    if (leftMs > 0 || _busy) return;

    // Expired. Do NOT mint a replacement while a pairing is actually in
    // flight — the phone has already scanned and is waiting on confirmation,
    // and minting would cancel the very request it is answering.
    final state = widget.controller.authFlowState;
    if (state == AuthFlowState.qrScannedWaitConfirm ||
        state == AuthFlowState.bundleApplying) {
      return;
    }
    unawaited(_startRequest());
  }

  Future<void> _startRequest() async {
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
      // Seed the countdown immediately so the caption never shows a stale
      // value for the first second of a brand-new code.
      final leftMs =
          request.expiresAtMs - DateTime.now().millisecondsSinceEpoch;
      _timeLeft.value = Duration(milliseconds: leftMs > 0 ? leftMs : 0);
    } on DesktopLinkFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = failure.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 🔴 НЕ `e.toString()`.
        //
        // Так на экран человеку попадал текст исключения Dart — например
        // «Bad state: publishKeys returned ok=false» прямо под надписью «QR
        // недоступен». Понять из этого нельзя ничего, а сделать тем более:
        // человек видит слово «ошибка» и не знает, ждать ему, перезапускать
        // или звать на помощь.
        //
        // Известные причины приходят сюда типизированными
        // ([DesktopLinkFailure]) и показываются своим текстом выше. Всё
        // остальное — это «мы сами не знаем», и честнее сказать именно так,
        // добавив то единственное, что человек может сделать. Подробность
        // остаётся в журнале, где ей и место.
        _errorMessage = _l10n.desktopPairingPrepareFailed;
      });
    }
  }

  Future<void> _cancelAndRetry() async {
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
    await _startRequest();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final extraError = _extraError;
    return Container(
      color: c.bg,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(DSpace.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: DesktopButton(
                    label: _l10n.desktopAuthBack,
                    kind: DButtonKind.ghost,
                    size: DButtonSize.small,
                    icon: FluentIcons.chevron_left_24_regular,
                    onPressed: widget.onBack,
                  ),
                ),
              _headerIcon(c),
              const SizedBox(height: DSpace.xl),
              Text(
                _l10n.desktopPairingTitle,
                style: DType.title.copyWith(color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DSpace.s),
              Text(
                _l10n.desktopPairingHowTo,
                textAlign: TextAlign.center,
                style: DType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DSpace.xl2),
              _qrCard(c),
              const SizedBox(height: DSpace.s),
              _validityLine(c),
              const SizedBox(height: DSpace.m),
              _statusLine(c),
              // The status line ALREADY renders `controller.authFlowError`
              // whenever the flow is in `authError`, and `_errorMessage` is
              // set from the very same failure — so an evicted desktop showed
              // the sentence «This desktop device was removed from your
              // Secretly ID» twice, one line under the other, in the exact
              // moment the user needs one clear instruction. Seen on a live
              // account 08.09.2026. Show the second copy only when it says
              // something the status line does not.
              if (extraError != null) ...[
                const SizedBox(height: DSpace.s),
                Text(
                  extraError,
                  textAlign: TextAlign.center,
                  style: DType.caption.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: DSpace.xl2),
              _actionButton(),
              if (widget.controller.desktopDeviceRemovedFromAccount) ...[
                const SizedBox(height: DSpace.m),
                _recoveryBlock(c),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIcon(DColorSet c) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: c.elevated,
          shape: BoxShape.circle,
          border: Border.all(color: c.borderSubtle),
        ),
        child: Icon(
          FluentIcons.qr_code_24_regular,
          size: 30,
          color: c.accentPrimary,
        ),
      );

  Widget _qrCard(DColorSet c) {
    final payload = _qrPayload;
    final size = 240.0;
    return Container(
      width: size + 32,
      height: size + 32,
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
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    FluentIcons.qr_code_24_regular,
                    size: 48,
                    color: c.textSecondary,
                  ),
                const SizedBox(height: DSpace.s),
                Text(
                  _busy
                      ? _l10n.desktopPairingPreparingQr
                      : _l10n.desktopPairingQrUnavailable,
                  style: DType.caption.copyWith(color: Colors.black54),
                ),
              ],
            )
          : QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: size,
              backgroundColor: Colors.white,
            ),
    );
  }

  /// Countdown under the code. Without it an expired QR is indistinguishable
  /// from a live one, which is exactly how a user ends up scanning a dead
  /// code over and over.
  Widget _validityLine(DColorSet c) {
    return ValueListenableBuilder<Duration>(
      valueListenable: _timeLeft,
      builder: (ctx, left, _) {
        if (_request == null) return const SizedBox.shrink();
        if (left <= Duration.zero) {
          return Text(
            _l10n.desktopPairingCodeExpired,
            textAlign: TextAlign.center,
            style: DType.caption.copyWith(color: c.warning),
          );
        }
        final m = left.inMinutes;
        final s = left.inSeconds % 60;
        final expiringSoon = left.inSeconds <= 60;
        return Text(
          _l10n.desktopPairingCodeValidFor(
            '$m:${s.toString().padLeft(2, '0')}',
          ),
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(
            color: expiringSoon ? c.warning : c.textSecondary,
          ),
        );
      },
    );
  }

  /// [_errorMessage], unless the status line is already saying it.
  ///
  /// Compared by text rather than by state, because the duplication is a
  /// property of the two STRINGS coinciding — the flow can reach `authError`
  /// through paths that set a different `_errorMessage`, and that one is worth
  /// showing.
  String? get _extraError {
    final message = _errorMessage;
    if (message == null || message.trim().isEmpty) return null;
    final status = _authFlowLabel(widget.controller.authFlowState);
    return message.trim() == status.trim() ? null : message;
  }

  Widget _statusLine(DColorSet c) {
    final state = widget.controller.authFlowState;
    final label = _authFlowLabel(state);
    Color color = c.textSecondary;
    if (state == AuthFlowState.authError) color = c.danger;
    if (state == AuthFlowState.bundleApplying ||
        state == AuthFlowState.qrScannedWaitConfirm) {
      color = c.accentPrimary;
    }
    return Text(
      label,
      textAlign: TextAlign.center,
      style: DType.caption.copyWith(color: color),
    );
  }

  /// Shown only when this desktop's device id is gone from the account.
  ///
  /// Without it the screen is a dead end: generating a QR calls keys-setup,
  /// keys-setup refuses because the device was removed, and the instruction
  /// above ("scan from your phone") cannot be followed because no code is ever
  /// produced. This is the way out — and it is a separate, explicit button
  /// rather than something the retry does silently, because it discards this
  /// desktop's device identity.
  Widget _recoveryBlock(DColorSet c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _l10n.desktopPairingRevoked,
          textAlign: TextAlign.center,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DSpace.s),
        DesktopButton(
          label: _repairing
              ? _l10n.desktopPairingPreparingNew
              : _l10n.desktopPairingConnectAsNew,
          kind: DButtonKind.filled,
          onPressed: (_repairing || _busy) ? null : _resetIdentityAndRetry,
        ),
      ],
    );
  }

  bool _repairing = false;

  Future<void> _resetIdentityAndRetry() async {
    if (_repairing) return;
    setState(() {
      _repairing = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.resetDesktopDeviceIdentityForRepair();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _repairing = false;
        // Не текст исключения — см. пояснение в [_startRequest].
        _errorMessage = _l10n.desktopPairingIdentityResetFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _repairing = false);
    // The identity is fresh; ask for a code with it.
    await _startRequest();
  }

  Widget _actionButton() {
    final state = widget.controller.authFlowState;
    // Only a pairing that is genuinely mid-flight should lock the button.
    // It used to be disabled in every "waiting" state, so once the code
    // expired the user had a dead QR and no way to ask for a new one.
    final pairingInFlight = state == AuthFlowState.qrScannedWaitConfirm ||
        state == AuthFlowState.bundleApplying;
    final canRetry = !_busy && !pairingInFlight;
    return DesktopButton(
      label: pairingInFlight
          ? _l10n.desktopPairingWaitingConfirm
          : (_busy
                ? _l10n.desktopPairingPreparingQr
                : _l10n.desktopPairingNewQr),
      kind: DButtonKind.tonal,
      onPressed: canRetry ? _cancelAndRetry : null,
    );
  }

  String _authFlowLabel(AuthFlowState s) {
    switch (s) {
      case AuthFlowState.unauthenticated:
        return _busy
            ? _l10n.desktopPairingCreatingRequest
            : _l10n.desktopPairingReadyToScan;
      case AuthFlowState.qrSessionPending:
        return _l10n.desktopPairingWaitingScan;
      case AuthFlowState.qrScannedWaitConfirm:
        return _l10n.desktopPairingScannedConfirmOnPhone;
      case AuthFlowState.bundleApplying:
        return _l10n.desktopPairingFetchingProfile;
      case AuthFlowState.authenticated:
        return _l10n.desktopPairingConnectedLoading;
      case AuthFlowState.authError:
        return widget.controller.authFlowError ??
            _l10n.desktopPairingConnectionError;
    }
  }

}
