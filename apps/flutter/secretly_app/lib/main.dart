// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:secretly_app/legal/third_party_licenses.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'push/background_worker.dart';
import 'push/push_wake_service.dart';
import 'ui/app_shell.dart';
import 'ui/widgets/island_backdrop.dart';
import 'ui/active_call_screen.dart';
import 'ui/chat_screen.dart';
import 'ui/devices_auth_screen.dart';
import 'ui/wave1_l10n.dart';
import 'ui/call_bubble_overlay.dart';
import 'ui/app_asset_paths.dart';
import 'ui/onboarding_flow.dart';
import 'ui/root_messenger.dart';
import 'ui/room_invite_join_screen.dart';
import 'ui/security_lock_flow.dart';
import 'app/app_controller.dart';
import 'security/secure_secrets.dart';
import 'billing/billing_service.dart';
import 'app/onboarding_state.dart';
import 'app/platform_share_target.dart';
import 'calls/call_manager.dart';
import 'diagnostics/diag_log.dart';
import 'rooms/room_call_manager.dart';
import 'ui/attachment_error_text.dart';
import 'ui/share_target_sheet.dart';
import 'security/app_security_manager.dart';
import 'sync/peer_history_service.dart';
import 'ui/theme_presets.dart';
import 'ui/theme_transition.dart';
import 'ui/widgets/system_bottom_fade.dart';
import 'ui/widgets/app_background.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'ui/liquid_glass_flags.dart';
import 'ui/thermal_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Лицензии вшитых шрифтов — обе требуют, чтобы текст ехал вместе с
  // дистрибутивом. Flutter собирает экран лицензий только по пакетам из `pub`
  // и ассетов не видит, поэтому шрифты заявляются здесь. Вызов дешёвый:
  // добавляет замыкание в список, а сам текст читается лишь когда человек
  // откроет экран. См. `lib/legal/third_party_licenses.dart`.
  registerThirdPartyLicenses();
  // PERF(cache): cap the in-memory decoded-image cache above the 100 MB
  // default. Full-resolution camera photos (~48 MB ARGB) would otherwise evict
  // the cache after a couple of images and force constant re-decodes while
  // scrolling chats/galleries. One-time, invisible — has no effect on layout or
  // behaviour, only on how many decoded frames stay resident. Safe here because
  // ensureInitialized() above has already created the PaintingBinding.
  // Android gets a smaller cap: a flat 256 MB on 3–4 GB devices invites
  // memory-pressure kills of the backgrounded app ("the app keeps
  // restarting"), which costs far more UX than the occasional re-decode.
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      (Platform.isAndroid ? 128 : 256) * 1024 * 1024;
  // PERF(refresh-rate): several Android OEMs (Samsung/OnePlus/Xiaomi) pin
  // Flutter apps to 60 Hz even on 90/120 Hz panels. Ask for the highest mode
  // once at startup. Fire-and-forget: failure (old Android, plugin missing on
  // this platform) must never block or crash startup. Android-only API.
  if (Platform.isAndroid) {
    unawaited(
      FlutterDisplayMode.setHighRefreshRate().catchError((Object _) {}),
    );
  }
  unawaited(PushWakeService.initialize());
  // ANDROID DELIVERY RELIABILITY (2026-07-17): register the periodic
  // background sync (outbox flush + inbound top-up) so a Doze-frozen /
  // backgrounded / killed sender still delivers. iOS uses the NSE. Idempotent
  // (relay msg_id dedup), gated off while the foreground app is active.
  // 🔴 НЕ НА ЗАПУСКЕ (20.08.2026, Play Console: ANR
  // `workmanager.SharedPreferenceHelper.prefs`, версия 531).
  //
  // `unawaited` здесь не спасал: он отпускает только сторону Dart, а нативная
  // сторона плагина читает SharedPreferences СИНХРОННО и делает это на главном
  // потоке Android — ровно в те миллисекунды, когда система ждёт первый кадр.
  // На занятом диске это «Input dispatching timed out».
  //
  // Регистрация периодической задачи ничего не теряет от задержки в один кадр:
  // её период — пятнадцать минут, а политика `keep` делает вызов идемпотентным.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(BackgroundWorker.ensureRegistered());
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // Liquid glass nav bar — iOS ONLY (Android keeps the classic bar; owner's
  // decision, spike V4). Pre-warm the glass shaders so the first frame is not
  // a jank, wrap the app in the adaptive-quality scope (startup benchmark
  // steps quality down on weaker GPUs), and start the thermal governor so a
  // hot device drops to the classic bar live instead of feeding the heat.
  // Restore the user's own glass switch BEFORE the first frame, so the app
  // never paints one material and then flips to the other.
  if (kLiquidGlassNavBar && Platform.isIOS) {
    try {
      await GlassPrefs.load(await SharedPreferences.getInstance());
    } catch (_) {
      // Default (on) already applies.
    }
  }
  final liquidGlass = kLiquidGlassNavBar && Platform.isIOS;
  if (liquidGlass) {
    ThermalGuard.start();
    // Shaders are warmed even when the user has the switch off: flipping it on
    // must not cost a first-frame stall, and it is a no-op otherwise.
    await LiquidGlassWidgets.initialize();
  }
  runApp(
    // Every island reads PanelPrefs.frostedEnabled at build time, so the whole
    // tree has to rebuild when it flips — otherwise screens already on the
    // stack keep their old surface and the app is half blurred, half flat.
    ValueListenableBuilder<bool>(
      valueListenable: PanelPrefs.frostedEnabled,
      builder: (_, __, ___) =>
    // The switch rebuilds the whole app rather than a subtree: geometry
    // (bar footprint, FAB offsets, reserved insets) follows the material, so a
    // partial rebuild would leave the two disagreeing.
    // FROSTED PANELS (2026-08-01): the same treatment the glass switch gets.
    // Islands read PanelPrefs.frostedEnabled directly, so without a rebuild
    // here an already-built screen keeps its old surface and the app ends up
    // half blurred, half flat.
    liquidGlass
        // EVALUATION PIN (2026-07-19): adaptiveQuality OFF. Its startup
        // benchmark ran on a phone still hot from repeated USB builds, graded
        // the GPU "weak" and silently dropped the whole shader layer to
        // minimal — "эффект везде пропал". The look must be deterministic
        // while it is being judged; re-enable for production rollout.
        ? ValueListenableBuilder<bool>(
            // Rebuilds the shell when the user flips the switch. MyApp keeps
            // its State (same type, same position), so the controller and the
            // session are untouched — only the material and the geometry that
            // depends on it are rebuilt.
            valueListenable: GlassPrefs.enabled,
            builder: (_, __, ___) => LiquidGlassWidgets.wrap(
              child: const MyApp(),
              adaptiveQuality: false,
            ),
          )
        : const MyApp(),
    ),
  );
}

class _StartupLoadingSurface extends StatefulWidget {
  const _StartupLoadingSurface();

  @override
  State<_StartupLoadingSurface> createState() => _StartupLoadingSurfaceState();
}

class _StartupLoadingSurfaceState extends State<_StartupLoadingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fingerprintController;

  @override
  void initState() {
    super.initState();
    _fingerprintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _fingerprintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.045),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: Lottie.asset(
                  AppAssetPaths.fingerprintLottie,
                  controller: _fingerprintController,
                  fit: BoxFit.contain,
                  frameRate: FrameRate.max,
                  onLoaded: (composition) {
                    _fingerprintController
                      ..duration = composition.duration
                      ..repeat();
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Secretly',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppController _controller = AppController();
  CallManager? _callManager;
  RoomCallManager? _roomCallManager;
  StreamSubscription? _restartSub;
  StreamSubscription? _deepLinkSub;
  StreamSubscription<PlatformSharePayload>? _shareTargetSub;
  StreamSubscription<String>? _pushTokenRefreshSub;
  Uri? _pendingDeepLinkUri;
  // De-dupe guard: the same deep link can arrive twice in a tight window — via
  // getInitialLink() AND the uriLinkStream on cold start, or an OS double-emit
  // on warm start — which otherwise opens the target, flickers, and opens it
  // again on top.
  Uri? _lastHandledDeepLinkUri;
  int _lastHandledDeepLinkAtMs = 0;
  OneToOneCallWakeHint? _pendingCallWakeHint;
  int _startupGeneration = 0;
  // Tracks the brightness last pushed to the system status/nav bar so we can
  // re-apply it imperatively when the theme flips. Some OEM Android builds in
  // edge-to-edge mode ignore the AnnotatedRegion overlay and honor only the
  // imperative SystemChrome call, which left light-theme status icons white.
  bool? _appliedStatusBarDark;
  // Native bridge to force status/nav-bar icon contrast on OEMs (MIUI/HyperOS)
  // that ignore Flutter's SystemUiOverlayStyle in edge-to-edge mode.
  static const MethodChannel _systemUiChannel = MethodChannel(
    'secretly/system_ui',
  );
  bool _ready = false;
  bool _onboardingComplete = true; // optimistic; corrected in _init
  String _error = '';
  // Startup was deferred because the iOS/macOS Keychain was locked (-25308).
  // We show the neutral loading splash instead of a fatal error and retry init
  // on the next app resume (device unlocked).
  bool _awaitingKeychainUnlock = false;
  // ZOMBIE-DB LAUNCH FIX (2026-07-18, user screenshot: black
  // "Error: DatabaseException(error database_closed)" screen on open):
  // when init() dies on a closed-out-from-under DB handle, the controller —
  // and with it the 3s watchdog self-heal — never comes up, so the error
  // screen used to be TERMINAL until the user swipe-killed the app. Treat it
  // like the keychain-locked case instead: keep the neutral splash and
  // auto-_restart() with bounded backoff (a fresh AppController re-opens the
  // DB exactly like the manual kill-and-reopen did).
  int _dbClosedInitRetries = 0;
  static const int _dbClosedInitRetryMax = 5;
  Timer? _initRetryTimer;

  bool get _isDesktopRuntime =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static Color _onColor(Color color) {
    return color.computeLuminance() > 0.5
        ? const Color(0xFF15181D)
        : Colors.white;
  }

  static EdgeInsets _topSnackBarInsetPadding(MediaQueryData media) {
    final visibleHeight = math.max(
      240.0,
      media.size.height - media.viewInsets.bottom,
    );
    final topAnchor = media.padding.top + kToolbarHeight + 18;
    const estimatedSnackHeight = 72.0;
    final bottom = math.max(
      16.0,
      visibleHeight - topAnchor - estimatedSnackHeight,
    );
    return EdgeInsets.fromLTRB(14, 0, 14, bottom);
  }

  ThemeData _buildTheme(
    Brightness brightness, {
    required AppThemePreset appPreset,
    required ChatBubbleStylePreset bubblePreset,
    required NicknameStylePreset nicknamePreset,
    required IndicatorColorPreset indicatorPreset,
  }) {
    final isDark = brightness == Brightness.dark;
    final useGraphitePageSurfaces = appPreset.id == 'flutter_dash';
    // flutter_dash uses its OWN preset colours for surface/background (Telegram
    // dark navy). It still keeps the NEUTRAL (un-tinted) card/input treatment
    // gated on `useGraphitePageSurfaces` below, so cards read as plain navy.
    final surfacePreset = appPreset;
    // PR-J: when the user picks a custom indicator colour, it overrides the
    // theme's own primary so buttons, switches, FABs, badges, etc. adopt the
    // chosen accent. 'theme' (default) keeps the theme-derived primary so
    // existing behaviour is unchanged.
    final indicatorOverride = indicatorPreset.followsTheme
        ? null
        : (isDark ? indicatorPreset.darkPrimary : indicatorPreset.lightPrimary);
    final basePrimary =
        indicatorOverride ??
        (isDark ? appPreset.darkPrimary : appPreset.lightPrimary);
    final baseSecondary = isDark
        ? appPreset.darkSecondary
        : appPreset.lightSecondary;
    final baseSurface = isDark
        ? surfacePreset.darkSurface
        : surfacePreset.lightSurface;
    final primary = isDark
        ? basePrimary
        : _mix(basePrimary, Colors.white, 0.10);
    final secondary = isDark
        ? baseSecondary
        : _mix(baseSecondary, Colors.white, 0.14);
    final surface = isDark
        ? baseSurface
        : _mix(baseSurface, Colors.white, 0.72);
    final tertiary = _mix(primary, secondary, isDark ? 0.45 : 0.35);
    // Pure neutral text — no primary/secondary tint (Telegram-style readability)
    // flutter_dash matches the Telegram dark profile: bright-white primary text/
    // icons (#FFFFFF) and a muted blue-gray for secondary/placeholders (#7D8B99).
    final onSurface = isDark
        ? (useGraphitePageSurfaces
              ? const Color(0xFFFFFFFF)
              : const Color(0xFFE2E6EA))
        : const Color(0xFF111418);
    final onSurfaceVariant = isDark
        ? (useGraphitePageSurfaces
              ? const Color(0xFF7D8B99)
              : const Color(0xFF8394A3))
        : const Color(0xFF536272);
    final outlineBase = isDark
        ? const Color(0xFF3C4854)
        : const Color(0xFF9FAFBE);
    final outline = _mix(outlineBase, secondary, isDark ? 0.18 : 0.15);
    final outlineVariant = _mix(surface, outline, isDark ? 0.45 : 0.42);
    final neutralSurfaceAccent = useGraphitePageSurfaces
        ? (isDark ? surfacePreset.darkSecondary : surfacePreset.lightSecondary)
        : secondary;
    final surfaceContainerHigh = _mix(
      surface,
      neutralSurfaceAccent,
      isDark ? 0.07 : 0.05,
    );
    final surfaceContainerHighest = _mix(
      surface,
      neutralSurfaceAccent,
      isDark ? 0.10 : 0.07,
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: appPreset.seed,
          brightness: brightness,
          primary: primary,
          secondary: secondary,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: _onColor(primary),
          primaryContainer: _mix(primary, surface, isDark ? 0.42 : 0.76),
          onPrimaryContainer: isDark
              ? _mix(primary, Colors.white, 0.72)
              : _mix(primary, Colors.black, 0.58),
          secondary: secondary,
          onSecondary: _onColor(secondary),
          secondaryContainer: _mix(secondary, surface, isDark ? 0.48 : 0.78),
          onSecondaryContainer: isDark
              ? _mix(secondary, Colors.white, 0.7)
              : _mix(secondary, Colors.black, 0.56),
          tertiary: tertiary,
          onTertiary: _onColor(tertiary),
          tertiaryContainer: _mix(tertiary, surface, isDark ? 0.5 : 0.79),
          onTertiaryContainer: isDark
              ? _mix(tertiary, Colors.white, 0.68)
              : _mix(tertiary, Colors.black, 0.58),
          error: isDark ? const Color(0xFFC9647A) : const Color(0xFFC1002A),
          onError: isDark ? const Color(0xFF2C1117) : Colors.white,
          errorContainer: isDark
              ? const Color(0xFFB73856)
              : const Color(0xFFE8C6D0),
          onErrorContainer: isDark
              ? const Color(0xFFF3D7DF)
              : const Color(0xFF372C33),
          surface: surface,
          onSurface: onSurface,
          surfaceContainerHigh: surfaceContainerHigh,
          surfaceContainerHighest: surfaceContainerHighest,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          outlineVariant: outlineVariant,
          shadow: Colors.black,
        );
    final cardTint = useGraphitePageSurfaces
        ? neutralSurfaceAccent
        : scheme.secondary;
    final inputTint = useGraphitePageSurfaces
        ? (isDark ? surfacePreset.darkPrimary : surfacePreset.lightPrimary)
        : scheme.primary;
    final cardBg = isDark
        ? Color.alphaBlend(
            cardTint.withValues(alpha: useGraphitePageSurfaces ? 0.14 : 0.16),
            surfacePreset.darkSurface.withValues(alpha: 0.86),
          )
        : Color.alphaBlend(
            cardTint.withValues(alpha: useGraphitePageSurfaces ? 0.05 : 0.055),
            surface.withValues(alpha: 0.985),
          );
    final inputBg = isDark
        ? Color.alphaBlend(
            inputTint.withValues(alpha: useGraphitePageSurfaces ? 0.11 : 0.13),
            surfacePreset.darkSurface.withValues(alpha: 0.8),
          )
        : Color.alphaBlend(
            inputTint.withValues(alpha: useGraphitePageSurfaces ? 0.04 : 0.045),
            surface.withValues(alpha: 0.99),
          );
    final placeholderColor = isDark
        ? scheme.onSurfaceVariant.withValues(alpha: 0.82)
        : scheme.onSurfaceVariant.withValues(alpha: 0.9);
    return ThemeData(
      useMaterial3: true,
      // flutter_dash mirrors Telegram Android, which uses Roboto. On Android
      // 'Roboto' resolves to the system font (no bundling). Other themes: Inter.
      fontFamily: appPreset.id == 'flutter_dash' ? 'Roboto' : 'Inter',
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
        ),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.4),
        labelSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withValues(alpha: 0.9),
        textColor: scheme.onSurface,
        tileColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        hintStyle: TextStyle(
          color: placeholderColor,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(color: placeholderColor),
        floatingLabelStyle: TextStyle(
          color: scheme.primary.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: placeholderColor,
        suffixIconColor: placeholderColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
        // No coloured focus ring: keep the same neutral border on focus so
        // search fields (and other inputs) don't light up with an accent
        // outline when activated.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.35),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color.alphaBlend(
          scheme.secondary.withValues(alpha: isDark ? 0.16 : 0.08),
          scheme.surface.withValues(alpha: 0.96),
        ),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        insetPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      extensions: [
        ChatVisualsThemeExtension(
          bubbleTop: isDark ? bubblePreset.darkTop : bubblePreset.lightTop,
          bubbleBottom: isDark
              ? bubblePreset.darkBottom
              : bubblePreset.lightBottom,
          bubbleMid: isDark ? bubblePreset.darkMid : bubblePreset.lightMid,
          shadowTop: isDark
              ? bubblePreset.darkShadowTop
              : bubblePreset.lightShadowTop,
          shadowBottom: isDark
              ? bubblePreset.darkShadowBottom
              : bubblePreset.lightShadowBottom,
          outgoingNickname: nicknamePreset.outgoing,
          incomingNickname: nicknamePreset.incoming,
          actionTop:
              indicatorOverride ??
              (isDark
                  ? appPreset.darkActionBottom
                  : appPreset.lightActionBottom),
          actionBottom: indicatorOverride == null
              ? (isDark ? appPreset.darkActionTop : appPreset.lightActionTop)
              : _mix(
                  indicatorOverride,
                  isDark ? Colors.black : Colors.white,
                  isDark ? 0.22 : 0.10,
                ),
          topBarTop: resolveThemeTopBarTop(
            darkMode: isDark,
            themePreset: appPreset,
            colorScheme: scheme,
          ),
          topBarBottom: resolveThemeTopBarBottom(
            darkMode: isDark,
            themePreset: appPreset,
            colorScheme: scheme,
          ),
          topBarBorder: resolveThemeTopBarBorder(
            darkMode: isDark,
            themePreset: appPreset,
            colorScheme: scheme,
          ),
          chatWallpaperDeepColor: resolveChatWallpaperDeepColor(appPreset),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inForeground = state == AppLifecycleState.resumed;
    _controller.setAppInForeground(inForeground);
    if (!inForeground && Platform.isAndroid) {
      // HALF-SCREEN FIX (2026-07-12): Android `adjustResize` reports the
      // soft-keyboard height as MediaQuery.viewInsets.bottom. On Pixel/Gboard the
      // "insets → 0" clear can be dropped when the FlutterView pauses during the
      // app-switch, latching a ~45% phantom inset that squeezes every Scaffold
      // body into the top half on return (dead grey below the fold; only the top
      // scrolls; heals ONLY by killing from recents). Dismiss the IME the moment
      // we leave the foreground so the inset returns to 0 while the view is still
      // active and can never latch. Safe: unfocus is a no-op when nothing is
      // focused. Fires early (inactive/hidden precede paused) so the clear is
      // delivered before the view suspends.
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (inForeground) {
      // If startup was deferred because the Keychain was locked (-25308), the
      // device is now unlocked (we're resumed/active) — retry init so we drop the
      // loading splash and continue instead of stranding on it until a manual
      // kill+reopen.
      if (_awaitingKeychainUnlock && !_ready) {
        _awaitingKeychainUnlock = false;
        unawaited(_init());
      }
      // 🔴 Пропущенные звонки, прозвонившие НАТИВНОЙ плашкой при убитой
      // Activity (08.08.2026). Вычерпывать обязательно ЗДЕСЬ, а не только в
      // `CallManager.start()`: тот выполняется один раз за жизнь изолята, а
      // процесс на MIUI переживает смахивание из недавних. Тогда плашку
      // показывает FCM-служба, след пишется — и без этого вызова его никто
      // никогда не подберёт. Метод сам защищён от повторного захода.
      unawaited(_callManager?.drainMissedCallTrail() ?? Future<void>.value());
      // 🔴 Сигналы звонка, принятые ФОНОВЫМ изолятом (14.08.2026). Тот же довод,
      // что строкой выше: `CallManager.start()` выполняется один раз за жизнь
      // изолята, а процесс переживает смахивание из недавних — тогда приглашение
      // приняло бы фоновое пробуждение, а вычерпать очередь было бы некому.
      unawaited(
        _callManager?.drainPersistedCallSignalQueue() ?? Future<void>.value(),
      );
      // Re-assert native status-bar icon contrast — MIUI/HyperOS (Android) can
      // reset it on resume, and iOS can revert to the system appearance.
      final dark = _appliedStatusBarDark;
      if (dark != null && (Platform.isAndroid || Platform.isIOS)) {
        unawaited(
          _systemUiChannel.invokeMethod<void>('setLightStatusBar', {
            'light': !dark,
          }).catchError((Object _) {}),
        );
      }
      unawaited(_controller.refreshPushRegistrationDiagnostics());
      // Consume any wake hints accumulated while the app was backgrounded so
      // the flag doesn't persist until the next cold start.
      unawaited(() async {
        try {
          final wakeHint = await PushWakeService.consumeWakeHint();
          final callHint = wakeHint.oneToOneCallHint;
          // 🔴 ЗВОНОК ИДЁТ ПЕРВЫМ (Ш-3, 13.08.2026). Приглашение звонка едет
          // обычным сообщением через ящик, а звонящий бросает трубку через
          // десять секунд. Раньше выборка стояла ПОСЛЕ общей синхронизации
          // пробуждения, которая сначала лечит базу и обновляет значок
          // поддержки, — в поле приглашение опоздало на восемь секунд.
          // 🔴 ЭКРАН — ПЕРВЫМ, ящик — следом (22.08.2026). Порядок был обратный:
          // сначала сетевая выборка, и только потом показ. Выборка нужна ради
          // ПРЕДЛОЖЕНИЯ соединения, а экран строится из самого пуша, так что
          // ждать её незачем — на плохой сети это и превращалось в «взял трубку,
          // а десять секунд пустая главная».
          if (callHint != null) {
            await _callManager?.processStartupCallHint(callHint);
          }
          if (callHint != null && !callHint.isStale) {
            unawaited(_controller.pumpInboxForCallWake());
          }
          if (wakeHint.hasWakeHint) {
            await _controller.triggerPushWakeSync(
              roomCallRoomIds: wakeHint.roomCallRoomIds,
            );
          }
        } catch (_) {
          // ignore — setAppInForeground already triggers a triggerPushWakeSync
        }
      }());
    }
    _controller.security.onAppLifecycleStateChanged(state);
    _callManager?.onAppLifecycleStateChanged(state);
    _roomCallManager?.onAppLifecycleStateChanged(state);
  }

  Future<void> _init() async {
    final generation = ++_startupGeneration;
    try {
      await _controller.init();
      final onboardingDone = _isDesktopRuntime
          ? true
          : await isOnboardingComplete();
      if (!mounted || generation != _startupGeneration) return;
      if (mounted) setState(() => _onboardingComplete = onboardingDone);
      _callManager?.dispose();
      await _roomCallManager?.dispose();
      _callManager = CallManager(controller: _controller)..start();
      CallManager.instance = _callManager;
      unawaited(_maybeRequestIgnoreBatteryOptimizationsOnce());
      _roomCallManager = RoomCallManager(controller: _controller)..start();
      RoomCallManager.instance = _roomCallManager;
      // §C-2: start billing early so pending iOS transactions are finished on
      // launch. No-op on platforms/stores without IAP. The verifier redeems each
      // purchase via keys /v1/entitlements/redeem (S-2) then refreshes the
      // entitlement; it fails soft and is inert while monetization is disabled.
      // Отложенная оплата: магазин создал заказ и ждёт доплаты. Раньше об этом
      // не узнавал никто — событие уходило в поток без слушателей, и покупатель
      // оставался без премиума И без объяснения (прод 24.07.2026).
      BillingService.instance.onPendingPurchase =
          _controller.notePendingPurchase;
      BillingService.instance.onPendingResolved =
          _controller.clearPendingPurchaseNotice;
      BillingService.instance.pendingNoticeReader =
          _controller.pendingPurchaseNotice;
      BillingService.instance.pendingToastMarker =
          _controller.markPendingPurchaseToastShown;
      unawaited(
        BillingService.instance.start(
          verify: _controller.verifyAndApplyPurchase,
          refreshEntitlement: _controller.refreshEntitlementsNow,
        ),
      );
      _restartSub?.cancel();
      _restartSub = _controller.restartRequested.listen((_) {
        _restart();
      });
      if (!mounted || generation != _startupGeneration) return;
      // Healthy boot → re-arm the zombie-DB launch retry budget.
      _dbClosedInitRetries = 0;
      _initRetryTimer?.cancel();
      _initRetryTimer = null;
      setState(() {
        _ready = true;
        _error = '';
      });
      // Subscribe to deep links once (not on every restart).
      if (_deepLinkSub == null) {
        _deepLinkSub = AppLinks().uriLinkStream.listen(
          _handleDeepLink,
          onError: (_) {},
        );
        // Handle any link that launched the app cold.
        AppLinks()
            .getInitialLink()
            .then((uri) {
              if (uri != null && mounted) _handleDeepLink(uri);
            })
            .catchError((_) {});
      }
      // Open any deep-link that arrived while the app was still loading.
      if (_pendingDeepLinkUri != null) {
        final pendingUri = _pendingDeepLinkUri!;
        _pendingDeepLinkUri = null;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleDeepLink(pendingUri),
        );
      }
      _registerNotificationTapHandler();
      _registerPlatformShareTargetHandler();
      _schedulePushRuntimeSync(generation, _controller);
      // PR7: mobile-as-requester for the reinstall / restore-from-backup
      // flow. Desktop wires the same service eagerly from
      // `DesktopProductionApp._boot()`; mobile is more conservative —
      // we only ever fire when this device has *never* synced before
      // (i.e. `kPrefsPeerHistoryLastSyncAtMs` is missing), so a normal
      // mobile install never hits the relay for history. Token-bucket
      // + 25s response timeout inside the service make a no-peer scenario
      // a silent no-op.
      if (!_isDesktopRuntime) {
        unawaited(_maybeRunMobilePeerHistoryBootSync());
      }
    } catch (e) {
      if (!mounted) return;
      // iOS/macOS Keychain locked (errSecInteractionNotAllowed, -25308): the app
      // was launched or woken while the device was still locked, so the secure
      // store couldn't be read. This is transient — keep the neutral loading
      // splash (NOT a fatal "Error:" screen) and retry once the device is
      // unlocked, on the next app resume (see didChangeAppLifecycleState).
      final msg = e.toString();
      final isKeychainLocked =
          msg.contains('-25308') ||
          msg.toLowerCase().contains('interactionnotallowed') ||
          // A locked device reports the DB passphrase as simply ABSENT rather
          // than erroring. That is transient: hold the splash and retry on
          // unlock — re-keying here is what emptied an account (2026-07-20).
          e is DbPassphraseUnavailable;
      // ZOMBIE-DB LAUNCH FIX (2026-07-18): a closed-out-from-under sqflite
      // handle at init is TRANSIENT — a clean re-init opens a fresh handle
      // (that is precisely what the user's manual kill-and-reopen did). Keep
      // the splash and retry with backoff instead of the dead-end screen.
      final isDbClosed = msg.toLowerCase().contains('database_closed');
      setState(() {
        _ready = false;
        if (isKeychainLocked) {
          _awaitingKeychainUnlock = true;
          _error = '';
        } else if (isDbClosed && _dbClosedInitRetries < _dbClosedInitRetryMax) {
          _error = ''; // stay on the neutral splash while we self-heal
        } else {
          _error = msg;
        }
      });
      if (isDbClosed && _dbClosedInitRetries < _dbClosedInitRetryMax) {
        _dbClosedInitRetries += 1;
        DiagLog.event('db', 'init_closed_retry', {
          'attempt': _dbClosedInitRetries,
        });
        _initRetryTimer?.cancel();
        _initRetryTimer = Timer(
          Duration(seconds: 1 << (_dbClosedInitRetries - 1).clamp(0, 4)),
          () {
            if (mounted && !_ready) unawaited(_restart());
          },
        );
      }
    }
  }

  void _registerNotificationTapHandler() {
    _controller.setOnNotificationTap((convoId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openConvoById(convoId),
      );
    });
  }

  void _registerPlatformShareTargetHandler() {
    if (!Platform.isAndroid || _shareTargetSub != null) return;
    _shareTargetSub = PlatformShareTarget.stream.listen(
      (payload) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_handleIncomingSharePayload(payload));
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        DiagLog.event('share_target', 'listen_error', {
          'error': error.toString(),
        });
      },
    );
  }

  void _schedulePushRuntimeSync(int generation, AppController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _startupGeneration) return;
      unawaited(_finishPushRuntimeSync(generation, controller));
    });
  }

  Future<void> _finishPushRuntimeSync(
    int generation,
    AppController controller,
  ) async {
    try {
      await _initPushRuntime(controller);
      if (!mounted || generation != _startupGeneration) return;
      _registerNotificationTapHandler();
      final pendingCallHint = _pendingCallWakeHint;
      _pendingCallWakeHint = null;
      if (pendingCallHint != null) {
        unawaited(_callManager?.processStartupCallHint(pendingCallHint));
      }
    } catch (_) {
      // Push wake diagnostics should never block the first visible frame.
    }
  }

  static const _batteryChannel = MethodChannel('secretly/battery');
  static const _prefsBatteryOptPromptedKey = 'battery_opt_prompted_v1';

  // Prompts the user once (per install) to disable battery optimization for
  // the app. Without this exemption, MIUI/HyperOS/Samsung's Doze can suspend
  // the FCM service before incoming-call notifications are shown — matching
  // WhatsApp/Telegram behavior on aggressive Android skins.
  Future<void> _maybeRequestIgnoreBatteryOptimizationsOnce() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsBatteryOptPromptedKey) ?? false) return;
      final ignoring = await _batteryChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      if (ignoring == true) {
        await prefs.setBool(_prefsBatteryOptPromptedKey, true);
        return;
      }
      await _batteryChannel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      await prefs.setBool(_prefsBatteryOptPromptedKey, true);
    } catch (_) {
      // Non-fatal; user can grant manually in Android settings.
    }
  }

  Future<void> _initPushRuntime(AppController controller) async {
    // 🔴 ЭКРАН ЗВОНКА ПОДНИМАЕТСЯ ДО ВСЕГО ОСТАЛЬНОГО (22.08.2026).
    //
    // Правило «звонок идёт первым» стояло здесь и раньше (14.08), но касалось
    // лишь порядка ДВУХ сетевых шагов между собой. Сам показ экрана всё это
    // время оставался последним в очереди: сначала Firebase и токен, потом
    // выборка ящика, потом общая синхронизация — и только затем подсказка
    // попадала в [_pendingCallWakeHint], который разбирается ПОСЛЕ возврата
    // отсюда. Три сетевых ожидания подряд перед тем, как человек увидит, кому
    // он поднял трубку.
    //
    // Замер поля 22.08: пуш ушёл в 15:47:54, устройство впервые обратилось к
    // реле в 15:48:27 — тридцать три секунды. Человек в это время смотрел на
    // главную страницу и не понимал, соединяется ли звонок.
    //
    // Подсказка лежит в SharedPreferences: ей не нужны ни Firebase, ни сеть.
    // Поэтому читаем её первой и сразу поднимаем состояние — `_seedIncomingFromHint`
    // строит экран из самого пуша, ящик ему не нужен по построению (см. Ш-1 в
    // call_manager.dart: приглашение не несёт ничего, чего нет в пуше, а
    // `acceptIncoming` умеет работать без предложения и сам просит его заново).
    final wakeHint = await PushWakeService.consumeWakeHint();
    final coldStartCallHint = wakeHint.oneToOneCallHint;
    final callManager = _callManager;
    // Видно ли звонок на старте вообще. Без этой строки отсутствие экрана и
    // отсутствие подсказки выглядят одинаково — молчанием.
    DiagLog.event('push', 'cold_start_call_hint', <String, Object?>{
      'present': coldStartCallHint != null,
      'stale': coldStartCallHint?.isStale ?? false,
      'manager_ready': callManager != null,
    });
    if (coldStartCallHint != null && callManager != null) {
      // Здесь await уместен: это локальная работа (состояние + нативный вызов
      // при устаревшей подсказке), сети в ней нет.
      await callManager.processStartupCallHint(coldStartCallHint);
      _pendingCallWakeHint = null;
    } else {
      // Менеджера ещё нет — оставляем прежний путь: подсказку разберут после
      // возврата отсюда. Без этого запасного пути холодный старт, обогнавший
      // создание менеджера, потерял бы звонок совсем.
      _pendingCallWakeHint = coldStartCallHint;
    }

    // Предложение соединения приезжает отдельным сигналом через ящик. Оно нужно
    // для СОЕДИНЕНИЯ, но не для показа экрана, поэтому качаем без ожидания:
    // экран уже поднят, а `acceptIncoming` при отсутствии предложения запросит
    // его восстановление сам.
    if (coldStartCallHint != null && !coldStartCallHint.isStale) {
      unawaited(controller.pumpInboxForCallWake());
    }

    await PushWakeService.initialize();
    await controller.refreshPushRegistrationDiagnostics();

    final token = await PushWakeService.currentToken();
    if (token != null && token.trim().isNotEmpty) {
      controller.setRuntimePushToken(token.trim());
      DiagLog.event('push', 'token_initial', {
        'token_len': token.trim().length,
        'present': true,
      });
    } else {
      DiagLog.event('push', 'token_initial', const <String, Object?>{
        'token_len': 0,
        'present': false,
      });
    }

    await _pushTokenRefreshSub?.cancel();
    _pushTokenRefreshSub = PushWakeService.onTokenRefresh.listen((token) {
      final t = token.trim();
      if (t.isEmpty) return;
      DiagLog.event('push', 'token_refresh', {'token_len': t.length});
      controller.setRuntimePushToken(t);
    });

    // Общая синхронизация пробуждения — последней: она лечит базу и обновляет
    // значки, и на пути звонка ей делать нечего (Ш-3 ТЗ от 13.08).
    if (wakeHint.hasWakeHint) {
      await controller.triggerPushWakeSync(
        roomCallRoomIds: wakeHint.roomCallRoomIds,
      );
    }
  }

  Future<void> _restart() async {
    _startupGeneration++;
    setState(() {
      _ready = false;
      _error = '';
    });

    // ZOMBIE-DB HARDENING (2026-07-18): each teardown step is individually
    // best-effort. A single throwing dispose used to abort the WHOLE block —
    // in particular skipping `_controller.dispose()`, which leaves the OLD
    // controller (and its background futures) alive next to the NEW one.
    // With sqflite's singleInstance that stale twin can close the database
    // out from under the fresh controller — the "database_closed on launch"
    // black screen.
    try {
      await _restartSub?.cancel();
    } catch (_) {}
    try {
      await _callManager?.dispose();
    } catch (_) {}
    try {
      await _roomCallManager?.dispose();
    } catch (_) {}
    _callManager = null;
    _roomCallManager = null;
    try {
      // PR7: drop the peer-history binding before the controller goes
      // so the service doesn't hold a stale reference across a relogin.
      PeerHistoryService.instance.detach();
    } catch (_) {}
    try {
      await _controller.dispose();
    } catch (_) {}

    _controller = AppController();
    await _init();
  }

  /// PR7: gated boot-time peer-history sync for mobile. Fires *once* per
  /// install — after the first cycle stamps `kPrefsPeerHistoryLastSyncAtMs`
  /// we never re-enter on subsequent boots. Failure modes are silent
  /// because mobile has the relay-mailbox fallback (PR4) and is the
  /// primary source-of-truth in normal operation.
  Future<void> _maybeRunMobilePeerHistoryBootSync() async {
    try {
      final pid = _controller.profileId;
      if (pid.isEmpty || pid == 'unknown') return;
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(kPrefsPeerHistoryLastSyncAtMs) ?? 0;
      if (lastMs > 0) return; // already synced at least once on this install
      // Hand the controller to the singleton and run one cycle. Service
      // re-checks staleness + rate-limit itself; the gates here just
      // narrow the call site to fresh installs.
      PeerHistoryService.instance.attach(_controller);
      await PeerHistoryService.instance.maybeSyncOnBoot();
    } catch (_) {
      // Best-effort — surfaces in DebugConsole metric panel.
    }
  }

  void _handleDeepLink(Uri uri) {
    if (!_ready || !mounted) {
      _pendingDeepLinkUri = uri;
      return;
    }
    // Drop a duplicate emission of the same link within a short window so the
    // target screen opens exactly once (no flicker / stacked duplicate).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastHandledDeepLinkUri == uri &&
        nowMs - _lastHandledDeepLinkAtMs < 1500) {
      return;
    }
    _lastHandledDeepLinkUri = uri;
    _lastHandledDeepLinkAtMs = nowMs;
    final profileId = tryParseProfileShareUri(uri);
    if (profileId != null) {
      unawaited(_openProfileChat(profileId));
      return;
    }
    final roomInviteTarget = tryParseRoomInviteUri(uri);
    if (roomInviteTarget != null) {
      _openRoomInvite(roomInviteTarget);
      return;
    }
    if (uri.scheme != 'secretly') return;
    if (uri.host == 'room') {
      final convoId = uri.pathSegments.firstOrNull?.trim();
      if (convoId == null || convoId.isEmpty) return;
      _openConvoById(convoId);
      return;
    }
  }

  Future<void> _openProfileChat(String profileId) async {
    final nav = CallManager.navigatorKey.currentState;
    if (nav == null) return;
    try {
      final convoId = await _controller.prepareSharedProfileConversation(
        profileId,
      );
      if (!mounted) return;
      if (convoId == null || convoId.isEmpty) {
        final l10n = AppLocalizations.of(nav.context);
        final message =
            l10n?.contactActionProfileNotFound ?? 'Profile not found';
        ScaffoldMessenger.of(
          nav.context,
        ).showSnackBar(SecretlySnackBar(content: Text(message)));
        return;
      }
      await _openConvoById(convoId);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(nav.context);
      final message = l10n?.contactActionProfileNotFound ?? 'Profile not found';
      ScaffoldMessenger.of(
        nav.context,
      ).showSnackBar(SecretlySnackBar(content: Text(message)));
    }
  }

  Future<void> _handleIncomingSharePayload(PlatformSharePayload payload) async {
    if (!_ready || !mounted || payload.isEmpty) return;
    final nav = CallManager.navigatorKey.currentState;
    if (nav == null) return;
    final context = nav.context;
    final unlocked = await ensureSecurityScopeUnlocked(
      context: context,
      controller: _controller,
      scope: SecurityLockScope.app,
    );
    if (!unlocked || !mounted || !context.mounted) return;

    final conversation = await showShareTargetConversationSheet(
      context: context,
      controller: _controller,
      payload: payload,
    );
    if (conversation == null || !mounted) return;
    await _sendIncomingSharePayload(payload, conversation);
  }

  Future<void> _sendIncomingSharePayload(
    PlatformSharePayload payload,
    Conversation conversation,
  ) async {
    final nav = CallManager.navigatorKey.currentState;
    if (nav == null) return;
    final context = nav.context;
    var dialogOpen = false;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  wave1Text(
                    context,
                    ru: 'Отправка...',
                    en: 'Sending...',
                    uk: 'Надсилання...',
                    es: 'Enviando...',
                    pt: 'A enviar...',
                    ptBr: 'Enviando...',
                    fr: 'Envoi...',
                    de: 'Senden...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    dialogOpen = true;

    try {
      final isGroup = conversation.convoId.startsWith('group:');
      // Not payload.text: a file share often carries the file's own name as the
      // subject, and posting it as a message put a separate bubble with the
      // filename next to the image. meaningfulText drops a filename-only subject
      // when files are present but keeps a real caption.
      final text = payload.meaningfulText;
      if (payload.files.isNotEmpty) {
        final requests = payload.files
            .map(
              (file) => AttachmentFileSendRequest(
                filePath: file.path,
                mime: file.resolvedMime,
                // 🔴 ИМЯ ОТ СИСТЕМЫ ЗДЕСЬ ВЫБРАСЫВАЛОСЬ (14.08.2026).
                //
                // ЗАМЕР: `attachment_export_name has_filename=false` — файл,
                // присланный владельцем, НЕ ИМЕЛ ИМЕНИ ВООБЩЕ, и потому уезжал
                // дальше как `.bin`. Имя у нас было: система отдаёт его вместе
                // с файлом, а мы клали в запрос только путь и тип.
                //
                // Запасной вариант «взять имя из пути» здесь не работает: путь
                // у такого файла временный (`…/cache/share_…`), и имени в нём
                // нет.
                fileName: file.name,
              ),
            )
            .toList(growable: false);
        if (isGroup) {
          await _controller.sendGroupAttachmentFiles(
            groupId: conversation.convoId,
            files: requests,
          );
        } else {
          final peerProfileId =
              conversation.peerProfileId ?? conversation.convoId;
          await _controller.sendAttachmentFiles(
            peerProfileId: peerProfileId,
            files: requests,
          );
        }
      }
      if (text != null && text.isNotEmpty) {
        if (isGroup) {
          await _controller.sendGroupMessage(
            groupId: conversation.convoId,
            text: text,
          );
        } else {
          final peerProfileId =
              conversation.peerProfileId ?? conversation.convoId;
          await _controller.sendMessage(
            peerProfileId: peerProfileId,
            text: text,
          );
        }
      }
      if (!mounted || !context.mounted) return;
      if (dialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      await _openConvoById(conversation.convoId);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            wave1Text(
              context,
              ru: 'Отправлено',
              en: 'Sent',
              uk: 'Надіслано',
              es: 'Enviado',
              pt: 'Enviado',
              ptBr: 'Enviado',
              fr: 'Envoyé',
              de: 'Gesendet',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      if (dialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            attachmentErrorText(AppLocalizations.of(context)!, error),
          ),
        ),
      );
    }
  }

  void _openRoomInvite(RoomInviteTarget target) {
    final nav = CallManager.navigatorKey.currentState;
    if (nav == null) return;
    // If a room-invite screen is already open (double link emission on cold
    // start), bring it to the front instead of stacking another identical one;
    // otherwise collapse to the home shell and open it once.
    const inviteRouteName = 'room-invite';
    var alreadyOpen = false;
    nav.popUntil((route) {
      if (route.settings.name == inviteRouteName) {
        alreadyOpen = true;
        return true;
      }
      return route.isFirst;
    });
    if (alreadyOpen) return;
    nav.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: inviteRouteName),
        builder: (_) =>
            RoomInviteJoinScreen(controller: _controller, target: target),
      ),
    );
  }

  Future<void> _openConvoById(String convoId) async {
    final nav = CallManager.navigatorKey.currentState;
    if (nav == null) return;
    final normalizedConvoId = convoId.startsWith('req:')
        ? convoId.substring(4)
        : convoId;
    final isPersonalChat = _controller.isPersonalChat(normalizedConvoId);
    if (isPersonalChat) {
      final context = nav.context;
      final unlocked = await ensureSecurityScopeUnlocked(
        context: context,
        controller: _controller,
        scope: SecurityLockScope.personal,
        forcePrompt: true,
      );
      if (!unlocked) {
        return;
      }
    }

    // Resolve proper display name instead of raw convoId.
    final title = await _controller.resolveConvoTitle(normalizedConvoId);

    // Determine if this is a request that needs accept/block UX.
    final isRequest = await _controller.isContactRequest(normalizedConvoId);
    final isGroup = normalizedConvoId.startsWith('group:');
    final effectiveConvoId = isRequest && !convoId.startsWith('req:')
        ? 'req:$normalizedConvoId'
        : convoId;
    final requestProfileId = isRequest
        ? (convoId.startsWith('req:')
              ? convoId.substring(4)
              : normalizedConvoId)
        : null;

    // Single-instance navigation (Telegram-style): collapse back to the home
    // shell before opening the target, so chats never stack on top of each
    // other when arriving via a notification or deep link. Back from the chat
    // then lands on the home list, not another chat underneath.
    nav.popUntil((route) => route.isFirst);
    await nav.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: chatRouteName(effectiveConvoId)),
        builder: (_) => ChatScreen(
          controller: _controller,
          convoId: effectiveConvoId,
          title: title,
          requestProfileId: requestProfileId,
          peerProfileIdForSend: isGroup || isRequest ? null : normalizedConvoId,
        ),
      ),
    );
    if (isPersonalChat) {
      await _controller.security.lockNow(SecurityLockScope.personal);
    }
  }

  bool get _shouldShowAppLockOverlay {
    if (_isDesktopRuntime) {
      return false;
    }
    if (!_ready || _controller.requiresDesktopProfileSelection) {
      return false;
    }
    if (!_controller.security.isLocked(SecurityLockScope.app)) {
      return false;
    }
    final callState = _callManager?.state.value;
    if (callState != null && (callState.isActive || callState.isRinging)) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restartSub?.cancel();
    _deepLinkSub?.cancel();
    _initRetryTimer?.cancel();
    _shareTargetSub?.cancel();
    _pushTokenRefreshSub?.cancel();
    _callManager?.dispose();
    _roomCallManager?.dispose();
    // PR7: release peer-history singleton binding. Harmless on desktop
    // because desktop's `_boot()` re-attaches the same singleton on its
    // own; on mobile this is the only place we detach.
    PeerHistoryService.instance.detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _controller.changed,
      builder: (context, _) {
        final appPreset = resolveAppThemePreset(_controller.appThemePresetId);
        final bubblePreset = resolveChatBubbleStylePreset(
          _controller.chatBubbleStylePresetId,
        );
        final nicknamePreset = resolveNicknameStylePreset(
          _controller.nicknameStylePresetId,
        );
        final indicatorPreset = resolveIndicatorColorPreset(
          _controller.indicatorColorPresetId,
        );
        final light = _buildTheme(
          Brightness.light,
          appPreset: appPreset,
          bubblePreset: bubblePreset,
          nicknamePreset: nicknamePreset,
          indicatorPreset: indicatorPreset,
        );
        final dark = _buildTheme(
          Brightness.dark,
          appPreset: appPreset,
          bubblePreset: bubblePreset,
          nicknamePreset: nicknamePreset,
          indicatorPreset: indicatorPreset,
        );
        final mode = _controller.darkMode ? ThemeMode.dark : ThemeMode.light;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: CallManager.navigatorKey,
          // 🔴 Ключ единственного `ScaffoldMessenger` (15.09.2026).
          //
          // Через него сообщение показывается даже тогда, когда экран,
          // который его заказал, уже закрылся: длинные операции — запрос
          // резервной копии, восстановление — переживают свою страницу. См.
          // `ui/root_messenger.dart`, там же найденный по этому поводу отказ.
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          // Read-receipt scope (2026-07-18): lets a ChatScreen learn when it
          // becomes visible again after a pushed sub-screen is popped, so it
          // can mark-read only while genuinely on screen.
          navigatorObservers: [chatRouteObserver],
          locale: _controller.appLocaleOverride,
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appTitle ?? 'Secretly',
          onGenerateRoute: (settings) {
            final cm = _callManager;
            if (cm != null) {
              if (settings.name == '/call') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => ActiveCallScreen(callManager: cm),
                );
              }
            }
            // Default: show the main shell (or loading/error).
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _ready
                    ? (_isDesktopRuntime || _onboardingComplete
                          ? (_isDesktopRuntime ||
                                    !_controller.requiresDesktopProfileSelection
                                ? AppShell(
                                    key: const ValueKey('app-shell'),
                                    controller: _controller,
                                  )
                                : DevicesAuthScreen(
                                    key: const ValueKey('desktop-auth-gate'),
                                    controller: _controller,
                                  ))
                          : OnboardingFlow(
                              key: const ValueKey('onboarding'),
                              controller: _controller,
                              onComplete: () =>
                                  setState(() => _onboardingComplete = true),
                            ))
                    // 🔴 Заставка БЕЗ нижнего затемнения (отчёт 03.08.2026:
                    // «на экране загрузки внизу есть затемнение под системную
                    // панель»). Затемнение рисуется глобально под каждым
                    // маршрутом и задумано, чтобы растворять содержимое страницы
                    // в её же фоне. На сплошной чёрной заставке растворять
                    // нечего — остаётся видимая полоса поперёк экрана.
                    : BottomSystemFadeVisibility(
                        enabled: false,
                        child: Scaffold(
                          key: const ValueKey('app-loading'),
                          backgroundColor: Colors.black,
                          body: Center(
                            child: _error.isEmpty
                                ? const _StartupLoadingSurface()
                                : Text(
                                    'Error: $_error',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                          ),
                        ),
                      ),
              ),
            );
          },
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // flutter_dash draws its page gradient from its OWN preset (Telegram
            // dark navy), not graphite's near-black.
            final backgroundPreset = appPreset;
            final lightBgTop = _mix(
              backgroundPreset.lightBgTop ??
                  _mix(
                    backgroundPreset.lightSurface,
                    backgroundPreset.lightSecondary,
                    0.08,
                  ),
              Colors.white,
              0.48,
            );
            final lightBgMid = _mix(
              backgroundPreset.lightBgMid ??
                  _mix(
                    backgroundPreset.lightSurface,
                    backgroundPreset.lightPrimary,
                    0.1,
                  ),
              Colors.white,
              0.40,
            );
            final lightBgBottom = _mix(
              backgroundPreset.lightBgBottom ??
                  _mix(
                    backgroundPreset.lightSurface,
                    backgroundPreset.lightSecondary,
                    0.14,
                  ),
              Colors.white,
              0.32,
            );
            final darkBackgroundColors = appPreset.id == 'graphite'
                ? const [
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                  ]
                : [
                    backgroundPreset.darkBgBottom,
                    backgroundPreset.darkBgMid,
                    backgroundPreset.darkBgTop,
                  ];
            final overlayStyle = SystemUiOverlayStyle(
              // Transparent bars so the edge-to-edge content shows through and
              // Android honors the icon-brightness below (a non-transparent or
              // stale bar colour can make some OEMs ignore the icon brightness).
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            );
            // Re-apply imperatively whenever the effective brightness flips:
            // some OEM Android builds ignore the AnnotatedRegion overlay in
            // edge-to-edge mode and only honor the imperative SystemChrome call.
            if (_appliedStatusBarDark != isDark) {
              _appliedStatusBarDark = isDark;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                SystemChrome.setSystemUIOverlayStyle(overlayStyle);
                // Drive the status bar NATIVELY too: MIUI/HyperOS (Android)
                // ignores the Flutter overlay in edge-to-edge, and iOS ignores
                // it when the system appearance differs from the in-app theme.
                // light == !isDark ⇒ light bars ⇒ DARK status icons (light theme).
                if (Platform.isAndroid || Platform.isIOS) {
                  unawaited(
                    _systemUiChannel.invokeMethod<void>('setLightStatusBar', {
                      'light': !isDark,
                    }).catchError((Object _) {}),
                  );
                }
              });
            }
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: ThemeTransitionLayer(
                onToggle: (v) => _controller.setDarkMode(v),
                child: Builder(
                  builder: (context) {
                    final appGradient = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? darkBackgroundColors
                          : [lightBgTop, lightBgMid, lightBgBottom],
                    );
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      decoration: BoxDecoration(gradient: appGradient),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          snackBarTheme: Theme.of(context).snackBarTheme
                              .copyWith(
                                insetPadding: _topSnackBarInsetPadding(
                                  MediaQuery.of(context),
                                ),
                              ),
                        ),
                        // Expose the gradient so pushed routes can paint it
                        // themselves and slide it in opaquely (no
                        // bleed-through / background pop on transitions).
                        //
                        // NAV-FADE COLOR FIX (2026-07-17): AppBackground wraps
                        // the WHOLE overlay stack, not just the navigator. The
                        // global bottom fade used to be a SIBLING of
                        // AppBackground, so `AppBackground.maybeOf` returned
                        // null inside it and `scrimColorOf` fell back to
                        // `colorScheme.surface` — the island/placeholder tone,
                        // visibly LIGHTER than the real gradient bottom in
                        // every theme. In scope it now dissolves into the
                        // actual page background colour.
                        child: AppBackground(
                          gradient: appGradient,
                          child: Stack(
                            children: [
                              child ?? const SizedBox.shrink(),
                              // Soft fade overlaying the bottom of the route so
                              // scrolling content "disappears into infinity"
                              // near the system nav bar. Pages that own a
                              // bottom panel (AppShell pill, chat composer)
                              // disable this global overlay via
                              // BottomSystemFadeVisibility and host their own
                              // copy in the correct z-position — BEHIND their
                              // panel — so the fade never overlays the panel
                              // itself.
                              const Positioned.fill(child: _GlobalBottomFade()),
                              // Floating call bubble — appears when call is
                              // minimized.
                              if (_callManager != null)
                                CallBubbleOverlay(callManager: _callManager!),
                              if (_shouldShowAppLockOverlay)
                                AppSecurityLockOverlay(controller: _controller),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 1),
          themeAnimationCurve: Curves.easeInOutCubic,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // An unsupported device language must fall back to ENGLISH — never to
          // supportedLocales.first (de) or a country/script "nearest language"
          // guess, which Flutter's default basicLocaleListResolution would pick.
          // Delegated to the controller so this matches the locale used for the
          // controller's own strings (single source of truth). Note: when
          // `locale:` (appLocaleOverride) is non-null Flutter uses it directly
          // and skips this callback, so an explicit user choice still wins.
          localeListResolutionCallback: (deviceLocales, supportedLocales) =>
              _controller.resolveAppUiLocale(
                (deviceLocales == null || deviceLocales.isEmpty)
                    ? WidgetsBinding.instance.platformDispatcher.locales
                    : deviceLocales,
              ),
        );
      },
    );
  }
}

/// Bottom system-nav fade that lives behind every route. Toggled off via
/// [bottomSystemFadeEnabled] (call screens, onboarding) so it doesn't
/// overlay full-bleed UI like the active call or welcome flow.
class _GlobalBottomFade extends StatelessWidget {
  const _GlobalBottomFade();

  @override
  Widget build(BuildContext context) {
    final navInset = MediaQuery.paddingOf(context).bottom;
    if (navInset <= 0) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: bottomSystemFadeEnabled,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: navInset + 48,
              width: double.infinity,
              child: const SystemBottomFadeLayer(),
            ),
          ),
        );
      },
    );
  }
}
