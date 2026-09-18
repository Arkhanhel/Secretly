// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_transcription.dart';
import '../wave1_l10n.dart';
import '../widgets/secretly_glass_sheet.dart';

const Color _kGold = Color(0xFFE8A33D);

/// One shared [SpeechToText] reused across every open of the dictation sheet.
///
/// The plugin documents that a single instance should be created and reused;
/// re-`new`-ing + re-`initialize()`-ing it on each open can make
/// `initialize()` return false (the native recognizer can get into a bad
/// state when bound/unbound repeatedly). Keeping one instance — and skipping a
/// redundant initialize() once it reports available — is the recommended
/// pattern and avoids a class of "unavailable" false-negatives.
final SpeechToText _sharedStt = SpeechToText();

/// SharedPreferences key for the persisted recognition locale id (e.g. `en_US`).
const String _kLocalePrefsKey = 'voice_dictation_locale_v1';

/// SharedPreferences key for the persisted OFFLINE (Whisper) transcription
/// language override — an ISO-639-1 code (e.g. `ru`). Kept separate from
/// [_kLocalePrefsKey] (which stores an STT locale id like `en_US`) so the two
/// pickers never collide. Absent until the user explicitly picks a language;
/// the offline default falls back to the app UI language.
const String _kOfflineLangPrefsKey = 'voice_dictation_offline_lang_v1';

/// Offline-mode language options shown in the picker: ISO-639-1 code → native
/// label. The user uses Russian; the app supports 'ru'/'en'. The list covers
/// the languages Whisper handles well and the app's likely user base.
const List<({String code, String label})> _kOfflineLanguages = [
  (code: 'ru', label: 'Русский'),
  (code: 'en', label: 'English'),
  (code: 'uk', label: 'Українська'),
  (code: 'de', label: 'Deutsch'),
  (code: 'fr', label: 'Français'),
  (code: 'es', label: 'Español'),
  (code: 'it', label: 'Italiano'),
  (code: 'pl', label: 'Polski'),
  (code: 'tr', label: 'Türkçe'),
  (code: 'zh', label: '中文'),
  (code: 'ar', label: 'العربية'),
  (code: 'ja', label: '日本語'),
];

/// Opens the on-device dictation sheet and returns the recognized text
/// (trimmed), or null if the user cancelled or nothing was recognized.
///
/// Recognition prefers on-device processing (the OS uses its local model when
/// one is installed) so the user's voice is turned into text on the phone —
/// consistent with the app's privacy stance. The recognition language can be
/// chosen via the language button in the top-right of the sheet and is
/// persisted across sessions.
Future<String?> showVoiceDictationSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceDictationSheet(),
  );
}

class _VoiceDictationSheet extends StatefulWidget {
  const _VoiceDictationSheet();

  @override
  State<_VoiceDictationSheet> createState() => _VoiceDictationSheetState();
}

class _VoiceDictationSheetState extends State<_VoiceDictationSheet> {
  // The shared, reused recognizer (see [_sharedStt] for why it's a singleton).
  SpeechToText get _stt => _sharedStt;

  String _finalText = '';
  String _partial = '';
  bool _initializing = true;
  bool _available = false;
  bool _listening = false;
  bool _finished = false; // user tapped Done/Cancel
  bool _error = false;
  bool _gotResult = false; // any recognition result this whole session
  double _level = 0; // mic sound level for the pulse

  // Android-only: the mic permission was denied (or permanently denied). When
  // permanently denied the only recovery is opening the OS app settings, so we
  // show a dedicated button. iOS keeps speech_to_text's own permission flow.
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;

  // Recognition language. Loaded from prefs on boot, else from systemLocale().
  String? _localeId; // e.g. 'en_US'; null until resolved
  String _localeLabel = ''; // short label shown next to the language button
  List<LocaleName> _locales = const []; // cached after first locales() call

  // User explicitly paused/finished — suppresses any auto-retry so retries can
  // never fight an intentional pause.
  bool _userPaused = false;

  // Transient-error auto-retry guard. Reset to 0 on every fresh (user-driven)
  // start; bumped on each retry so a flaky engine can't loop forever.
  int _retryCount = 0;
  static const int _kMaxTransientRetries = 1;
  Timer? _retryTimer;

  // Listen-hang watchdog. On Android `listen()` can return "started" yet the
  // engine never binds — no sound level, no result, no error — leaving the mic
  // button stuck on "listening" forever. After a successful start we arm this
  // timer; the FIRST sound level or result cancels it. If it fires we stop the
  // engine, drop out of the listening state, and surface a short retry hint so
  // the button is never frozen. A user re-tap re-arms it.
  Timer? _hangWatchdog;
  static const Duration _kHangTimeout = Duration(seconds: 8);
  // Short hint shown (in the ready state, while not listening) after the
  // watchdog fires. Cleared the moment the user re-taps the mic.
  String? _hangHint;

  // Android transient errors that are safe to silently retry once.
  static const Set<String> _kTransientErrors = {
    'error_no_match',
    'error_speech_timeout',
    'error_busy',
  };

  // ── Offline (Whisper) fallback ──────────────────────────────────────────
  // When speech_to_text is unavailable (mainly Android devices without a
  // working system RecognitionService, e.g. MIUI/Xiaomi) we fall back to the
  // app's on-device Whisper engine: record mic audio to a temp file, then run
  // VoiceTranscriptionService.transcribe() on it. Audio never leaves the phone.
  final AudioRecorder _recorder = AudioRecorder();
  bool _offlineRecording = false; // mic is currently capturing
  bool _offlineBusy = false; // start/stop in flight (debounce taps)
  bool _offlineTranscribing = false; // transcribe() running (after stop)
  bool _offlineDownloading = false; // model download in progress
  double? _offlineDownloadProgress; // mirror of downloadProgress (0..1)
  String? _offlineError; // soft "couldn't recognize" message
  String? _offlineResultText; // last recognized text, awaiting confirm/re-record
  // Mic permission was denied for the offline recorder. Shown inline in the
  // offline view (not via the STT permission screen) so the flow stays single.
  bool _offlinePermissionDenied = false;
  bool _offlinePermissionPermanentlyDenied = false;
  String? _offlineAudioPath; // temp file being recorded into
  Duration _offlineElapsed = Duration.zero;
  DateTime? _offlineStartedAt;
  Timer? _offlineTimer; // 1 Hz recording timer

  // Offline transcription language (ISO-639-1, e.g. 'ru'). Resolution order:
  //   1. the user's persisted override (_kOfflineLangPrefsKey), else
  //   2. the app UI language (Localizations.localeOf(context).languageCode).
  // Loaded lazily in the offline view's first build so it has a context. Passed
  // straight to VoiceTranscriptionService.transcribe(language:) — without it
  // Whisper auto-detected the wrong language.
  String? _offlineLang; // null until resolved
  bool _offlineLangLoading = false; // guards the one-shot prefs load
  bool _offlineLangLoaded = false; // prefs load completed (override applied)

  // ── ONE mode, decided ONCE up front ─────────────────────────────────────
  // The sheet is EITHER an online-STT flow OR an offline-Whisper flow — never a
  // sequence that visibly transitions between them. The choice is made here, in
  // initState, BEFORE the first build, so the user sees a single coherent UI
  // with a single language control from the very first frame.
  //
  // Android is the offline path: its system RecognitionService is unreliable
  // (absent/broken on MIUI/Xiaomi and many other ROMs), and even when
  // initialize() reports "available" listen() routinely hangs or errors — which
  // is exactly what produced the old "several windows in a row" experience
  // (Подготовка… → Слушаю… → unavailable → offline). Going straight to the
  // clean offline record→Whisper UI removes that flashing entirely.
  //
  // Online STT stays the path where it genuinely works (iOS, where on-device
  // dictation is built in and reliable).
  late final bool _offlineMode = Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    VoiceTranscriptionService.instance.downloadProgress.addListener(
      _onDownloadProgress,
    );
    if (_offlineMode) {
      // Offline-only: do NOT touch speech_to_text at all (no init, no listen,
      // no locale resolution) — that machinery is what flashed STT sub-states.
      // The offline view requests the mic permission itself when recording
      // starts. Nothing else to prepare.
      _initializing = false;
    } else {
      _boot();
    }
  }

  @override
  void dispose() {
    _finished = true;
    _retryTimer?.cancel();
    _hangWatchdog?.cancel();
    _offlineTimer?.cancel();
    VoiceTranscriptionService.instance.downloadProgress.removeListener(
      _onDownloadProgress,
    );
    // Stop+dispose the offline recorder and drop any temp audio (best-effort).
    () async {
      try {
        if (await _recorder.isRecording()) await _recorder.stop();
      } catch (_) {}
      try {
        await _recorder.dispose();
      } catch (_) {}
      _deleteTempAudio();
    }();
    try {
      // Cancel (don't dispose) — the recognizer is shared across opens.
      _stt.cancel();
    } catch (_) {}
    super.dispose();
  }

  /// Mirrors [VoiceTranscriptionService.downloadProgress] into local state so
  /// the offline UI can show «Загрузка офлайн-модели… NN%».
  void _onDownloadProgress() {
    if (!mounted) return;
    final v = VoiceTranscriptionService.instance.downloadProgress.value;
    setState(() {
      _offlineDownloading = v != null;
      _offlineDownloadProgress = v;
    });
  }

  Future<void> _boot() async {
    // PERMISSION RACE FIX (Android): speech_to_text's initialize() evaluates the
    // mic permission synchronously. If we call it before the OS grant dialog has
    // resolved, it sees "not granted", returns false, and the sheet is stuck on
    // "unavailable" even though the user just tapped Allow — and the engine then
    // never binds, so listen() hangs. So on Android we explicitly request the
    // mic permission first and only initialize() once it's actually granted.
    //
    // iOS is left exactly as before: speech_to_text drives its own
    // mic + speech-recognition permission prompts, which already works.
    if (Platform.isAndroid) {
      PermissionStatus status;
      try {
        status = await Permission.microphone.request();
      } catch (_) {
        // If the plugin call itself fails, fall through to initialize() so a
        // device/config quirk still gets the generic "unavailable" path rather
        // than a hard permission wall.
        status = PermissionStatus.granted;
      }
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() {
          _initializing = false;
          _available = false;
          _permissionDenied = true;
          _permissionPermanentlyDenied = status.isPermanentlyDenied;
        });
        return;
      }
    }

    bool ok = false;
    try {
      // The recognizer is shared and survives across sheet opens. If a previous
      // open already initialized it successfully, re-running initialize() is at
      // best wasteful and at worst flips it back to "unavailable" — so reuse it.
      // (Status/error callbacks always target the *current* sheet's handlers.)
      if (_stt.isAvailable) {
        ok = true;
      } else {
        ok = await _stt.initialize(
          onStatus: _onStatus,
          onError: _onError,
          // Some Android ROMs (e.g. MIUI/Xiaomi) report "no recognizer" from the
          // direct service check, so initialize() returns false and the sheet is
          // stuck on "unavailable". The intent-lookup fallback finds the speech
          // service via RecognizerIntent instead. No-op on iOS.
          options: [SpeechToText.androidIntentLookup],
        );
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _available = ok;
      _initializing = false;
      _error = !ok;
    });
    if (!ok) return;
    // Resolve the recognition language before the first listen so Android picks
    // it up immediately (Android needs an explicit locale far more than iOS).
    await _loadLocale();
    if (!mounted || _finished) return;
    await _startListening();
  }

  /// Re-requests the mic permission (after a denial) or, if it's permanently
  /// denied, opens the OS app-settings page. On a fresh grant it re-runs the
  /// normal boot path so dictation starts without reopening the sheet.
  Future<void> _retryPermission() async {
    if (_finished) return;
    if (_permissionPermanentlyDenied) {
      try {
        await openAppSettings();
      } catch (_) {}
      return;
    }
    setState(() {
      _permissionDenied = false;
      _initializing = true;
    });
    await _boot();
  }

  /// Resolves the language to use: persisted choice first, then the OS default,
  /// then the first available locale. Also caches the locale list and computes
  /// the short label for the language button.
  Future<void> _loadLocale() async {
    String? chosen;
    try {
      final prefs = await SharedPreferences.getInstance();
      chosen = prefs.getString(_kLocalePrefsKey);
    } catch (_) {}
    try {
      _locales = await _stt.locales();
    } catch (_) {
      _locales = const [];
    }
    // Validate the persisted id still exists; fall back if the pack was removed.
    if (chosen != null && !_locales.any((l) => l.localeId == chosen)) {
      chosen = null;
    }
    if (chosen == null) {
      try {
        chosen = (await _stt.systemLocale())?.localeId;
      } catch (_) {}
    }
    chosen ??= _locales.isNotEmpty ? _locales.first.localeId : null;
    if (!mounted) return;
    setState(() {
      _localeId = chosen;
      _localeLabel = _shortLocaleLabel(chosen);
    });
  }

  /// A compact label for the language button, e.g. `en_US` -> `EN`.
  String _shortLocaleLabel(String? localeId) {
    if (localeId == null || localeId.isEmpty) return '';
    final code = localeId.split(RegExp('[_-]')).first.trim();
    return code.isEmpty ? '' : code.toUpperCase();
  }

  /// Handles engine errors. Transient Android errors (no-match / timeout / busy)
  /// that arrive while the user still wants to dictate trigger a single delayed
  /// retry; permanent errors stop and flip into the offline fallback.
  void _onError(SpeechRecognitionError e) {
    if (!mounted || _finished) return;
    // The engine spoke up, so the "silent hang" watchdog is moot. Disarm it so
    // it can't later overwrite a real error code or resurrect the listening
    // state mid-retry.
    _disarmWatchdog();
    final msg = e.errorMsg;
    final permanent = e.permanent;
    // Substring match: Android occasionally decorates the code, so don't rely
    // on an exact equality with the bare error name.
    final transient =
        !permanent && _kTransientErrors.any((code) => msg.contains(code));

    if (transient && !_userPaused && _retryCount < _kMaxTransientRetries) {
      _retryCount++;
      setState(() => _listening = false);
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || _finished || _userPaused) return;
        // Retry without resetting the counter so it can fire at most once.
        _startListening(isRetry: true);
      });
      return;
    }

    // Permanent error, or transient with retries exhausted: stop and (for hard
    // errors) flip into the offline fallback so the user can still dictate.
    setState(() {
      _listening = false;
      if (permanent) _error = true;
    });
  }

  /// Starts (or resumes) a single recognition session. Crucially there is NO
  /// auto-restart on stop — the previous build restarted on every
  /// `notListening`/`done`, which thrashed start/stop many times a second and
  /// captured nothing. Now the engine listens until a real pause, then waits
  /// for the user to tap the mic to continue.
  Future<void> _startListening({bool isRetry = false}) async {
    if (_finished || !_available || _stt.isListening) return;
    // A fresh, user-driven start re-arms the transient-retry budget. A retry
    // keeps the (already-incremented) counter so it can only fire once.
    if (!isRetry) {
      _retryCount = 0;
      _userPaused = false;
      _retryTimer?.cancel();
      // A fresh user-driven start clears any stale hang hint.
      if (_hangHint != null && mounted) setState(() => _hangHint = null);
    }
    // Any new start invalidates a previous watchdog; it's re-armed below only on
    // a successful listen().
    _hangWatchdog?.cancel();
    try {
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: (lvl) {
          // First sound level proves the engine is actually bound — disarm the
          // hang watchdog and update the pulse.
          _disarmWatchdog();
          if (mounted) setState(() => _level = lvl);
        },
        listenOptions: SpeechListenOptions(
          // Pass the chosen recognition language. Android in particular needs an
          // explicit locale — without one the recognizer can stop immediately
          // and capture nothing. iOS already works with or without it.
          localeId: _localeId,
          // Use the system recognizer (do NOT force on-device): forcing
          // on-device fails outright on devices without an installed offline
          // language pack — which is exactly the "stops instantly on Android /
          // no text on iOS" symptom. The OS still prefers on-device when it has
          // a model (iOS dictation is on-device by default on modern devices).
          onDevice: false,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
          // Long windows so normal speaking pauses don't end the session.
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 6),
        ),
      );
      if (mounted) {
        setState(() {
          _listening = true;
        });
        // listen() returned "started" — but on Android the engine can still be
        // silently dead. Arm the watchdog; the first sound level or result
        // disarms it, otherwise it fires and unsticks the button.
        _armWatchdog();
      }
    } catch (_) {
      _hangWatchdog?.cancel();
      if (mounted) setState(() => _listening = false);
    }
  }

  /// Arms the listen-hang watchdog. If neither a sound level nor a result
  /// arrives within [_kHangTimeout], the engine is bound-but-silent (or hung):
  /// stop it, leave the listening state, and show a short retry hint.
  void _armWatchdog() {
    _hangWatchdog?.cancel();
    _hangWatchdog = Timer(_kHangTimeout, () async {
      if (!mounted || _finished) return;
      // A result already arrived → not hung, nothing to do.
      if (_gotResult) return;
      try {
        await _stt.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _listening = false;
        _hangHint = _hangHintText();
      });
    });
  }

  /// Cancels the hang watchdog. Called on the first sound level / result and on
  /// any pause / finish / dispose.
  void _disarmWatchdog() {
    _hangWatchdog?.cancel();
    _hangWatchdog = null;
  }

  /// Localized "couldn't start recognition" hint shown when the watchdog fires.
  String _hangHintText() {
    return wave1Text(
      context,
      ru: 'Не удалось начать распознавание — попробуйте ещё раз',
      en: 'Couldn’t start recognition — try again',
      uk: 'Не вдалося почати розпізнавання — спробуйте ще раз',
      es: 'No se pudo iniciar el reconocimiento; inténtalo de nuevo',
      pt: 'Não foi possível iniciar o reconhecimento — tente novamente',
      ptBr: 'Não foi possível iniciar o reconhecimento — tente novamente',
      fr: 'Impossible de démarrer la reconnaissance — réessayez',
      de: 'Erkennung konnte nicht gestartet werden – bitte erneut versuchen',
    );
  }

  void _onStatus(String status) {
    if (!mounted) return;
    // Reflect the engine state ONLY — never auto-restart here.
    setState(() => _listening = status == 'listening');
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    // A result proves the engine is alive — disarm the hang watchdog.
    _disarmWatchdog();
    setState(() {
      _gotResult = true;
      if (result.finalResult) {
        _finalText = _join(_finalText, result.recognizedWords);
        _partial = '';
      } else {
        _partial = result.recognizedWords;
      }
    });
  }

  String _join(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    if (x.isEmpty) return y;
    if (y.isEmpty) return x;
    return '$x $y';
  }

  String get _composed => _join(_finalText, _partial);

  /// Mic tap: pause when listening, resume when paused. The single source of
  /// (re)start, so the engine is only ever driven by an explicit user action.
  Future<void> _toggleMic() async {
    if (_finished || !_available) return;
    if (_stt.isListening) {
      // Explicit pause: block any in-flight transient retry from resuming and
      // disarm the hang watchdog so it can't fire after an intentional stop.
      _userPaused = true;
      _retryTimer?.cancel();
      _disarmWatchdog();
      try {
        await _stt.stop();
      } catch (_) {}
      if (mounted) setState(() => _listening = false);
    } else {
      await _startListening();
    }
  }

  Future<void> _finish({required bool accept}) async {
    if (_finished) return;
    _finished = true;
    _retryTimer?.cancel();
    _disarmWatchdog();
    final text = _composed.trim();
    try {
      await _stt.stop();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(accept && text.isNotEmpty ? text : null);
  }

  /// Opens the language picker, persists the choice, and (if currently
  /// listening) restarts recognition so the new language takes effect now.
  Future<void> _openLanguagePicker() async {
    if (_finished) return;
    // Ensure we have a locale list to show (boot may have failed to load it).
    if (_locales.isEmpty) {
      try {
        _locales = await _stt.locales();
      } catch (_) {}
    }
    if (!mounted || _finished) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LanguagePickerSheet(locales: _locales, selectedId: _localeId),
    );
    if (picked == null || picked == _localeId || !mounted || _finished) return;
    setState(() {
      _localeId = picked;
      _localeLabel = _shortLocaleLabel(picked);
      // A new language is a clean slate for the retry budget + error banner.
      _error = false;
      _retryCount = 0;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePrefsKey, picked);
    } catch (_) {}
    if (!mounted || _finished) return;
    // Restart with the new language if we were actively listening.
    final wasListening = _stt.isListening || _listening;
    try {
      await _stt.stop();
    } catch (_) {}
    if (!mounted || _finished) return;
    if (wasListening && !_userPaused) {
      await _startListening();
    } else if (mounted) {
      setState(() => _listening = false);
    }
  }

  // ── Offline (Whisper) fallback flow ─────────────────────────────────────

  /// The app UI language as an ISO-639-1 code (e.g. `ru`). This is the offline
  /// default — what Whisper transcribes in unless the user picks otherwise.
  String _appLanguageCode() {
    final code = Localizations.localeOf(context).languageCode.trim();
    return code.isEmpty ? 'en' : code.toLowerCase();
  }

  /// The effective offline language: the resolved value (override-or-app), or
  /// the app language until the one-shot prefs load runs in the offline view.
  String get _effectiveOfflineLang => _offlineLang ?? _appLanguageCode();

  /// Native label for [code], falling back to the upper-cased code when the
  /// language isn't in [_kOfflineLanguages].
  String _offlineLangLabel(String code) {
    for (final o in _kOfflineLanguages) {
      if (o.code == code) return o.label;
    }
    return code.toUpperCase();
  }

  /// One-shot load of the persisted offline-language override. Defaults to the
  /// app UI language when no override is stored. Runs on the offline view's
  /// first build (it needs a context for [Localizations.localeOf]).
  Future<void> _ensureOfflineLangLoaded() async {
    if (_offlineLangLoaded || _offlineLangLoading) return;
    _offlineLangLoading = true;
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_kOfflineLangPrefsKey);
    } catch (_) {}
    if (!mounted) {
      _offlineLangLoading = false;
      return;
    }
    final resolved = (saved != null && saved.trim().isNotEmpty)
        ? saved.trim().toLowerCase()
        : _appLanguageCode();
    setState(() {
      _offlineLang = resolved;
      _offlineLangLoaded = true;
      _offlineLangLoading = false;
    });
  }

  /// Opens the offline-language picker and persists the chosen ISO-639-1 code.
  /// The next transcription uses it. No engine restart is needed — the language
  /// is read per-transcription, so switching then re-recording (or re-recording
  /// after a wrong-language result) just works.
  Future<void> _openOfflineLanguagePicker() async {
    if (_finished) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OfflineLanguagePickerSheet(selectedCode: _effectiveOfflineLang),
    );
    if (picked == null || !mounted || _finished) return;
    setState(() => _offlineLang = picked);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOfflineLangPrefsKey, picked);
    } catch (_) {}
  }

  /// Deletes the current temp recording, if any (best-effort).
  void _deleteTempAudio() {
    final path = _offlineAudioPath;
    if (path == null) return;
    _offlineAudioPath = null;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Tap-to-start: begins recording mic audio into a temp .m4a file using the
  /// SAME encoder config as the app's voice-note recorder (aacLc / 128 kbps /
  /// 44.1 kHz). Mic permission was already requested in [_boot] on Android; if
  /// it was somehow revoked, surface the existing permission UI instead.
  Future<void> _startOfflineRecording() async {
    if (_finished || _offlineBusy || _offlineRecording || _offlineTranscribing) {
      return;
    }
    setState(() {
      _offlineBusy = true;
      _offlineError = null;
      _offlineResultText = null;
      _offlinePermissionDenied = false;
    });
    try {
      final granted = await _recorder.hasPermission();
      if (!mounted) return;
      if (!granted) {
        // Surface the denial INSIDE the offline view (its own inline message +
        // recovery button) rather than swapping to the STT permission screen —
        // keeping everything to one coherent flow. Distinguish permanent denial
        // so the recovery action can open OS settings.
        bool permanent = false;
        try {
          permanent = await Permission.microphone.isPermanentlyDenied;
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _offlineBusy = false;
          _offlinePermissionDenied = true;
          _offlinePermissionPermanentlyDenied = permanent;
        });
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'dictation_${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      // Mirror chat_screen.dart's voice-note recorder config exactly.
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      await _recorder.start(config, path: path);
      if (!mounted) {
        // Sheet went away mid-start — stop and clean up.
        try {
          await _recorder.stop();
        } catch (_) {}
        try {
          if (File(path).existsSync()) File(path).deleteSync();
        } catch (_) {}
        return;
      }
      _offlineAudioPath = path;
      _offlineStartedAt = DateTime.now();
      _offlineElapsed = Duration.zero;
      _offlineTimer?.cancel();
      _offlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final started = _offlineStartedAt;
        if (!mounted || started == null || !_offlineRecording) return;
        setState(() => _offlineElapsed = DateTime.now().difference(started));
      });
      setState(() {
        _offlineRecording = true;
        _offlineBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offlineRecording = false;
        _offlineBusy = false;
        _offlineError = _offlineFailedText();
      });
    }
  }

  /// Offline mic-permission recovery: when permanently denied the only path is
  /// the OS app-settings page; otherwise re-attempt recording (which re-prompts
  /// via `_recorder.hasPermission()`). Keeps recovery inside the single flow.
  Future<void> _retryOfflinePermission() async {
    if (_finished) return;
    if (_offlinePermissionPermanentlyDenied) {
      try {
        await openAppSettings();
      } catch (_) {}
      return;
    }
    await _startOfflineRecording();
  }

  /// Tap-to-stop: stops the recorder, then runs the on-device Whisper engine on
  /// the captured file. `transcribe()` downloads the ~140 MB model on first use
  /// (progress mirrored via [_onDownloadProgress]) and never throws. Result is
  /// staged for the user to confirm or re-record.
  Future<void> _stopOfflineRecordingAndTranscribe() async {
    if (_finished || _offlineBusy || !_offlineRecording) return;
    setState(() => _offlineBusy = true);
    _offlineTimer?.cancel();
    String? path = _offlineAudioPath;
    try {
      final stopped = await _recorder.stop();
      // Prefer the path the recorder reports back; fall back to ours.
      if (stopped != null && stopped.isNotEmpty) path = stopped;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _offlineRecording = false;
      _offlineBusy = false;
      _offlineTranscribing = true;
    });

    if (path == null || !File(path).existsSync()) {
      if (!mounted) return;
      setState(() {
        _offlineTranscribing = false;
        _offlineError = _offlineFailedText();
      });
      _deleteTempAudio();
      return;
    }

    String? text;
    try {
      text = await VoiceTranscriptionService.instance.transcribe(
        eventId: 'dictation_${DateTime.now().millisecondsSinceEpoch}',
        audioPath: path,
        // Force the recognition language (defaults to the app UI language)
        // instead of letting Whisper auto-detect — which produced the wrong
        // language for the user.
        language: _effectiveOfflineLang,
      );
    } catch (_) {
      text = null;
    }
    // Temp audio is no longer needed once transcription has run.
    _offlineAudioPath = path;
    _deleteTempAudio();
    if (!mounted) return;
    final clean = text?.trim() ?? '';
    setState(() {
      _offlineTranscribing = false;
      _offlineDownloading = false;
      _offlineDownloadProgress = null;
      if (clean.isEmpty) {
        _offlineError = _offlineFailedText();
        _offlineResultText = null;
      } else {
        _offlineError = null;
        _offlineResultText = clean;
      }
    });
  }

  /// Accepts the offline transcript — same return contract as the
  /// speech_to_text path: pop the recognized text back to the composer.
  void _confirmOfflineResult() {
    if (_finished) return;
    final text = _offlineResultText?.trim() ?? '';
    if (text.isEmpty) return;
    _finished = true;
    _offlineTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(text);
  }

  /// Localized soft failure used by the offline path.
  String _offlineFailedText() {
    return wave1Text(
      context,
      ru: 'Не удалось распознать — повторите',
      en: 'Couldn’t recognize — try again',
      uk: 'Не вдалося розпізнати — повторіть',
      es: 'No se pudo reconocer; inténtalo de nuevo',
      pt: 'Não foi possível reconhecer — tente novamente',
      ptBr: 'Não foi possível reconhecer — tente novamente',
      fr: 'Reconnaissance impossible — réessayez',
      de: 'Erkennung fehlgeschlagen – bitte erneut versuchen',
    );
  }

  String _fmtClock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SecretlyGlassSheetSurface(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(Theme.of(context).colorScheme),
                const SizedBox(height: 14),
                _buildContent(Theme.of(context).colorScheme),
                const SizedBox(height: 16),
                _buildActions(Theme.of(context).colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top row: the centered drag handle with a language button pinned top-right.
  ///
  /// The STT language button lives here ONLY in online mode. In offline mode
  /// the offline view (`_buildOfflineContent`) owns the sole language control,
  /// so this header shows just the drag handle — guaranteeing exactly one
  /// language button on screen, never two.
  Widget _buildHeader(ColorScheme cs) {
    final showLanguage = !_offlineMode && _available && !_initializing;
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: SecretlyGlassSheetHandle(),
            ),
          ),
          if (showLanguage)
            Align(
              alignment: Alignment.centerRight,
              child: _LanguageButton(
                label: _localeLabel,
                tooltip: wave1Text(
                  context,
                  ru: 'Язык распознавания',
                  en: 'Recognition language',
                  uk: 'Мова розпізнавання',
                  es: 'Idioma de reconocimiento',
                  pt: 'Idioma de reconhecimento',
                  ptBr: 'Idioma de reconhecimento',
                  fr: 'Langue de reconnaissance',
                  de: 'Erkennungssprache',
                ),
                onTap: _openLanguagePicker,
                cs: cs,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    // Offline mode is decided once up front (see [_offlineMode]) and routes
    // straight to the single clean offline view — no STT init/listen states,
    // no "unavailable" screen, no second sub-window. This is the first thing
    // the builder checks so the offline UI shows from the very first frame.
    if (_offlineMode) return _buildOfflineContent(cs);
    if (_initializing) {
      return _Status(
        spinner: true,
        text: wave1Text(
          context,
          ru: 'Подготовка…',
          en: 'Preparing…',
          uk: 'Підготовка…',
          es: 'Preparando…',
          pt: 'A preparar…',
          ptBr: 'Preparando…',
          fr: 'Préparation…',
          de: 'Wird vorbereitet…',
        ),
        cs: cs,
      );
    }
    if (_permissionDenied) {
      final text = _permissionPermanentlyDenied
          ? wave1Text(
              context,
              ru: 'Нет доступа к микрофону. Откройте настройки и разрешите доступ к микрофону для Secretly.',
              en: 'No microphone access. Open settings and allow microphone access for Secretly.',
              uk: 'Немає доступу до мікрофона. Відкрийте налаштування та дозвольте доступ до мікрофона для Secretly.',
              es: 'Sin acceso al micrófono. Abre los ajustes y permite el acceso al micrófono para Secretly.',
              pt: 'Sem acesso ao microfone. Abra as definições e permita o acesso ao microfone ao Secretly.',
              ptBr: 'Sem acesso ao microfone. Abra as configurações e permita o acesso ao microfone ao Secretly.',
              fr: "Pas d'accès au micro. Ouvrez les réglages et autorisez l'accès au micro pour Secretly.",
              de: 'Kein Mikrofonzugriff. Öffne die Einstellungen und erlaube Secretly den Mikrofonzugriff.',
            )
          : wave1Text(
              context,
              ru: 'Для распознавания речи нужен доступ к микрофону.',
              en: 'Speech recognition needs microphone access.',
              uk: 'Для розпізнавання мовлення потрібен доступ до мікрофона.',
              es: 'El reconocimiento de voz necesita acceso al micrófono.',
              pt: 'O reconhecimento de voz precisa de acesso ao microfone.',
              ptBr: 'O reconhecimento de voz precisa de acesso ao microfone.',
              fr: "La reconnaissance vocale a besoin de l'accès au micro.",
              de: 'Die Spracherkennung benötigt Mikrofonzugriff.',
            );
      final buttonLabel = _permissionPermanentlyDenied
          ? wave1Text(
              context,
              ru: 'Открыть настройки',
              en: 'Open settings',
              uk: 'Відкрити налаштування',
              es: 'Abrir ajustes',
              pt: 'Abrir definições',
              ptBr: 'Abrir configurações',
              fr: 'Ouvrir les réglages',
              de: 'Einstellungen öffnen',
            )
          : wave1Text(
              context,
              ru: 'Разрешить',
              en: 'Allow',
              uk: 'Дозволити',
              es: 'Permitir',
              pt: 'Permitir',
              ptBr: 'Permitir',
              fr: 'Autoriser',
              de: 'Erlauben',
            );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Status(icon: Icons.mic_off_rounded, text: text, cs: cs),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _retryPermission,
            style: FilledButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    if (_error || !_available) {
      // speech_to_text is unavailable (mainly Android without a working system
      // recognizer). Instead of a dead end, fall back to the on-device Whisper
      // engine: record → transcribe, fully offline.
      return _buildOfflineContent(cs);
    }
    // Ready — interactive mic + live text.
    final hasText = _composed.trim().isNotEmpty;
    final glow = (_level.clamp(0, 10)) / 10;
    final statusText = _listening
        ? wave1Text(
            context,
            ru: 'Слушаю…',
            en: 'Listening…',
            uk: 'Слухаю…',
            es: 'Escuchando…',
            pt: 'A ouvir…',
            ptBr: 'Ouvindo…',
            fr: "J'écoute…",
            de: 'Höre zu…',
          )
        // Watchdog fired: show the retry hint until the user taps the mic again.
        : (_hangHint != null)
        ? _hangHint!
        : (hasText || _gotResult)
        ? wave1Text(
            context,
            ru: 'Пауза · нажмите микрофон, чтобы продолжить',
            en: 'Paused · tap the mic to continue',
            uk: 'Пауза · натисніть мікрофон, щоб продовжити',
            es: 'En pausa · toca el micrófono para continuar',
            pt: 'Em pausa · toque no micro para continuar',
            ptBr: 'Em pausa · toque no microfone para continuar',
            fr: 'En pause · appuyez sur le micro pour continuer',
            de: 'Pausiert · tippe auf das Mikro, um fortzufahren',
          )
        : wave1Text(
            context,
            ru: 'Нажмите микрофон и говорите',
            en: 'Tap the mic and speak',
            uk: 'Натисніть мікрофон і говоріть',
            es: 'Toca el micrófono y habla',
            pt: 'Toque no micro e fale',
            ptBr: 'Toque no microfone e fale',
            fr: 'Appuyez sur le micro et parlez',
            de: 'Tippe auf das Mikro und sprich',
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GestureDetector(
            onTap: _toggleMic,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening
                    ? _kGold.withValues(alpha: 0.16)
                    : cs.surface.withValues(alpha: 0.4),
                boxShadow: _listening
                    ? [
                        BoxShadow(
                          color: _kGold.withValues(alpha: 0.18 + 0.32 * glow),
                          blurRadius: 16 + 26 * glow,
                          spreadRadius: 1 + 6 * glow,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 34,
                color: _listening ? _kGold : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 180),
          child: SingleChildScrollView(
            reverse: true,
            child: Text(
              hasText
                  ? _composed
                  : wave1Text(
                      context,
                      ru: 'Текст появится здесь',
                      en: 'Your text appears here',
                      uk: 'Текст з’явиться тут',
                      es: 'Tu texto aparecerá aquí',
                      pt: 'O seu texto aparece aqui',
                      ptBr: 'Seu texto aparece aqui',
                      fr: 'Votre texte apparaît ici',
                      de: 'Dein Text erscheint hier',
                    ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                height: 1.35,
                color: hasText
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Offline (Whisper) fallback content: a record→transcribe flow shown when
  /// speech_to_text can't initialize. Self-contained — it owns its own title
  /// and action buttons (the default Cancel/Done row is suppressed for it).
  Widget _buildOfflineContent(ColorScheme cs) {
    // Resolve the offline language (persisted override, else app UI language)
    // the first time the offline view renders — needs a context for the locale.
    if (!_offlineLangLoaded && !_offlineLangLoading) {
      // Defer to after this frame so we don't setState() during build.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureOfflineLangLoaded(),
      );
    }
    final title = wave1Text(
      context,
      ru: 'Голосовой ввод (офлайн)',
      en: 'Voice input (offline)',
      uk: 'Голосове введення (офлайн)',
      es: 'Entrada de voz (sin conexión)',
      pt: 'Entrada de voz (offline)',
      ptBr: 'Entrada de voz (offline)',
      fr: 'Saisie vocale (hors ligne)',
      de: 'Spracheingabe (offline)',
    );
    // A new language can always be chosen — except while transcribing/downloading
    // (the in-flight job already captured a language).

    // Status line under the title, reflecting the current offline phase.
    final String status;
    if (_offlinePermissionDenied) {
      status = _offlinePermissionPermanentlyDenied
          ? wave1Text(
              context,
              ru: 'Нет доступа к микрофону. Откройте настройки и разрешите доступ к микрофону для Secretly.',
              en: 'No microphone access. Open settings and allow microphone access for Secretly.',
              uk: 'Немає доступу до мікрофона. Відкрийте налаштування та дозвольте доступ до мікрофона для Secretly.',
              es: 'Sin acceso al micrófono. Abre los ajustes y permite el acceso al micrófono para Secretly.',
              pt: 'Sem acesso ao microfone. Abra as definições e permita o acesso ao microfone ao Secretly.',
              ptBr: 'Sem acesso ao microfone. Abra as configurações e permita o acesso ao microfone ao Secretly.',
              fr: "Pas d'accès au micro. Ouvrez les réglages et autorisez l'accès au micro pour Secretly.",
              de: 'Kein Mikrofonzugriff. Öffne die Einstellungen und erlaube Secretly den Mikrofonzugriff.',
            )
          : wave1Text(
              context,
              ru: 'Для голосового ввода нужен доступ к микрофону.',
              en: 'Voice input needs microphone access.',
              uk: 'Для голосового введення потрібен доступ до мікрофона.',
              es: 'La entrada de voz necesita acceso al micrófono.',
              pt: 'A entrada de voz precisa de acesso ao microfone.',
              ptBr: 'A entrada de voz precisa de acesso ao microfone.',
              fr: "La saisie vocale a besoin de l'accès au micro.",
              de: 'Die Spracheingabe benötigt Mikrofonzugriff.',
            );
    } else if (_offlineDownloading) {
      final pct = ((_offlineDownloadProgress ?? 0) * 100).clamp(0, 100).round();
      status = wave1Text(
        context,
        ru: 'Загрузка офлайн-модели распознавания… $pct%',
        en: 'Downloading offline recognition model… $pct%',
        uk: 'Завантаження офлайн-моделі розпізнавання… $pct%',
        es: 'Descargando el modelo de reconocimiento sin conexión… $pct%',
        pt: 'A transferir o modelo de reconhecimento offline… $pct%',
        ptBr: 'Baixando o modelo de reconhecimento offline… $pct%',
        fr: 'Téléchargement du modèle de reconnaissance hors ligne… $pct%',
        de: 'Offline-Erkennungsmodell wird geladen… $pct%',
      );
    } else if (_offlineTranscribing) {
      status = wave1Text(
        context,
        ru: 'Распознавание…',
        en: 'Recognizing…',
        uk: 'Розпізнавання…',
        es: 'Reconociendo…',
        pt: 'A reconhecer…',
        ptBr: 'Reconhecendo…',
        fr: 'Reconnaissance…',
        de: 'Erkennung…',
      );
    } else if (_offlineRecording) {
      status = wave1Text(
        context,
        ru: 'Идёт запись · ${_fmtClock(_offlineElapsed)}',
        en: 'Recording · ${_fmtClock(_offlineElapsed)}',
        uk: 'Триває запис · ${_fmtClock(_offlineElapsed)}',
        es: 'Grabando · ${_fmtClock(_offlineElapsed)}',
        pt: 'A gravar · ${_fmtClock(_offlineElapsed)}',
        ptBr: 'Gravando · ${_fmtClock(_offlineElapsed)}',
        fr: 'Enregistrement · ${_fmtClock(_offlineElapsed)}',
        de: 'Aufnahme · ${_fmtClock(_offlineElapsed)}',
      );
    } else if (_offlineResultText != null) {
      status = wave1Text(
        context,
        ru: 'Проверьте текст и нажмите «Готово»',
        en: 'Check the text and tap “Done”',
        uk: 'Перевірте текст і натисніть «Готово»',
        es: 'Revisa el texto y toca «Listo»',
        pt: 'Verifique o texto e toque em «Concluído»',
        ptBr: 'Verifique o texto e toque em «Concluído»',
        fr: 'Vérifiez le texte et appuyez sur « Terminé »',
        de: 'Text prüfen und auf „Fertig“ tippen',
      );
    } else if (_offlineError != null) {
      status = _offlineError!;
    } else {
      status = wave1Text(
        context,
        ru: 'Нажмите запись и говорите',
        en: 'Tap record and speak',
        uk: 'Натисніть запис і говоріть',
        es: 'Toca grabar y habla',
        pt: 'Toque em gravar e fale',
        ptBr: 'Toque em gravar e fale',
        fr: 'Appuyez sur enregistrer et parlez',
        de: 'Auf Aufnahme tippen und sprechen',
      );
    }

    final busyPhase = _offlineTranscribing || _offlineDownloading;
    final result = _offlineResultText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title centered, with a language button pinned top-right (mirrors the
        // STT header). The button shows the current offline language and opens
        // the offline-language picker.
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              top: -4,
              right: 0,
              child: _LanguageButton(
                label: _offlineLangLabel(_effectiveOfflineLang),
                tooltip: wave1Text(
                  context,
                  ru: 'Язык распознавания',
                  en: 'Recognition language',
                  uk: 'Мова розпізнавання',
                  es: 'Idioma de reconocimiento',
                  pt: 'Idioma de reconhecimento',
                  ptBr: 'Idioma de reconhecimento',
                  fr: 'Langue de reconnaissance',
                  de: 'Erkennungssprache',
                ),
                onTap: busyPhase ? null : _openOfflineLanguagePicker,
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Record button (or a spinner while transcribing/downloading).
        Center(
          child: busyPhase
              ? const SizedBox(
                  width: 76,
                  height: 76,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              : GestureDetector(
                  onTap: _offlineBusy
                      ? null
                      : (_offlinePermissionDenied
                            ? _retryOfflinePermission
                            : _offlineRecording
                            ? _stopOfflineRecordingAndTranscribe
                            : _startOfflineRecording),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _offlineRecording
                          ? _kGold.withValues(alpha: 0.16)
                          : cs.surface.withValues(alpha: 0.4),
                      boxShadow: _offlineRecording
                          ? [
                              BoxShadow(
                                color: _kGold.withValues(alpha: 0.34),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _offlinePermissionDenied
                          ? Icons.mic_off_rounded
                          : _offlineRecording
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      size: 34,
                      color: _offlineRecording ? _kGold : cs.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          status,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (_offlineDownloading) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _offlineDownloadProgress,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
            ),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 180),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.35,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        // Actions: Cancel always. The primary button is context-aware —
        //  • a confirmed result  → «Готово» (pop the text back),
        //  • currently recording → «Стоп» (stop + transcribe),
        //  • otherwise           → «Запись» (start recording).
        // After a result the mic circle above still re-records (clears it).
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: busyPhase ? null : _finishOffline,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: cs.onSurfaceVariant,
                ),
                child: Text(
                  wave1Text(
                    context,
                    ru: 'Отмена',
                    en: 'Cancel',
                    uk: 'Скасувати',
                    es: 'Cancelar',
                    pt: 'Cancelar',
                    ptBr: 'Cancelar',
                    fr: 'Annuler',
                    de: 'Abbrechen',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildOfflinePrimaryButton(cs, result, busyPhase)),
          ],
        ),
      ],
    );
  }

  /// The context-aware primary button for the offline flow.
  Widget _buildOfflinePrimaryButton(
    ColorScheme cs,
    String? result,
    bool busyPhase,
  ) {
    final String label;
    final VoidCallback? onPressed;
    if (_offlinePermissionDenied) {
      label = _offlinePermissionPermanentlyDenied
          ? wave1Text(
              context,
              ru: 'Открыть настройки',
              en: 'Open settings',
              uk: 'Відкрити налаштування',
              es: 'Abrir ajustes',
              pt: 'Abrir definições',
              ptBr: 'Abrir configurações',
              fr: 'Ouvrir les réglages',
              de: 'Einstellungen öffnen',
            )
          : wave1Text(
              context,
              ru: 'Разрешить',
              en: 'Allow',
              uk: 'Дозволити',
              es: 'Permitir',
              pt: 'Permitir',
              ptBr: 'Permitir',
              fr: 'Autoriser',
              de: 'Erlauben',
            );
      onPressed = _offlineBusy ? null : _retryOfflinePermission;
    } else if (result != null) {
      label = wave1Text(
        context,
        ru: 'Готово',
        en: 'Done',
        uk: 'Готово',
        es: 'Listo',
        pt: 'Concluído',
        ptBr: 'Concluído',
        fr: 'Terminé',
        de: 'Fertig',
      );
      onPressed = busyPhase ? null : _confirmOfflineResult;
    } else if (_offlineRecording) {
      label = wave1Text(
        context,
        ru: 'Стоп',
        en: 'Stop',
        uk: 'Стоп',
        es: 'Detener',
        pt: 'Parar',
        ptBr: 'Parar',
        fr: 'Arrêter',
        de: 'Stopp',
      );
      onPressed = (busyPhase || _offlineBusy)
          ? null
          : _stopOfflineRecordingAndTranscribe;
    } else {
      label = wave1Text(
        context,
        ru: 'Запись',
        en: 'Record',
        uk: 'Запис',
        es: 'Grabar',
        pt: 'Gravar',
        ptBr: 'Gravar',
        fr: 'Enregistrer',
        de: 'Aufnehmen',
      );
      onPressed = (busyPhase || _offlineBusy) ? null : _startOfflineRecording;
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _kGold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: _kGold.withValues(alpha: 0.30),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// Cancels out of the offline flow (no text returned).
  void _finishOffline() {
    if (_finished) return;
    _finished = true;
    _offlineTimer?.cancel();
    () async {
      try {
        if (await _recorder.isRecording()) await _recorder.stop();
      } catch (_) {}
      _deleteTempAudio();
    }();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildActions(ColorScheme cs) {
    // The offline view renders its own Cancel/primary actions inside
    // _buildOfflineContent, so the shared STT action row is suppressed for it.
    if (_offlineMode || _error || !_available) return const SizedBox.shrink();
    final canAccept = _available && !_error && _composed.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => _finish(accept: false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: cs.onSurfaceVariant,
            ),
            child: Text(
              wave1Text(
                context,
                ru: 'Отмена',
                en: 'Cancel',
                uk: 'Скасувати',
                es: 'Cancelar',
                pt: 'Cancelar',
                ptBr: 'Cancelar',
                fr: 'Annuler',
                de: 'Abbrechen',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: canAccept ? () => _finish(accept: true) : null,
            style: FilledButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _kGold.withValues(alpha: 0.30),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              wave1Text(
                context,
                ru: 'Готово',
                en: 'Done',
                uk: 'Готово',
                es: 'Listo',
                pt: 'Concluído',
                ptBr: 'Concluído',
                fr: 'Terminé',
                de: 'Fertig',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.text,
    required this.cs,
    this.icon,
    this.spinner = false,
  });

  final String text;
  final ColorScheme cs;
  final IconData? icon;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Center(
            child: spinner
                ? const CircularProgressIndicator(strokeWidth: 2.4)
                : Icon(icon, size: 34, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Small pill-shaped language affordance: globe icon + short locale label.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final String tooltip;
  // Nullable so the button can be disabled (e.g. while the offline engine is
  // transcribing/downloading and the language is already locked in).
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 18, color: cs.onSurfaceVariant),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable, scrollable list of recognition languages. Pops the chosen
/// `localeId` (or null when dismissed).
class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.locales, required this.selectedId});

  final List<LocaleName> locales;
  final String? selectedId;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LocaleName> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.locales;
    return widget.locales
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.localeId.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SecretlyGlassSheetSurface(
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SecretlyGlassSheetHandle()),
                  const SizedBox(height: 12),
                  Text(
                    wave1Text(
                      context,
                      ru: 'Язык распознавания',
                      en: 'Recognition language',
                      uk: 'Мова розпізнавання',
                      es: 'Idioma de reconocimiento',
                      pt: 'Idioma de reconhecimento',
                      ptBr: 'Idioma de reconhecimento',
                      fr: 'Langue de reconnaissance',
                      de: 'Erkennungssprache',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: wave1Text(
                        context,
                        ru: 'Поиск языка',
                        en: 'Search language',
                        uk: 'Пошук мови',
                        es: 'Buscar idioma',
                        pt: 'Procurar idioma',
                        ptBr: 'Buscar idioma',
                        fr: 'Rechercher une langue',
                        de: 'Sprache suchen',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              wave1Text(
                                context,
                                ru: 'Ничего не найдено',
                                en: 'No results',
                                uk: 'Нічого не знайдено',
                                es: 'Sin resultados',
                                pt: 'Sem resultados',
                                ptBr: 'Sem resultados',
                                fr: 'Aucun résultat',
                                de: 'Keine Ergebnisse',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final l = filtered[i];
                              final selected = l.localeId == widget.selectedId;
                              return ListTile(
                                dense: true,
                                title: Text(l.name),
                                subtitle: Text(
                                  l.localeId,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: _kGold,
                                      )
                                    : null,
                                onTap: () =>
                                    Navigator.of(context).pop(l.localeId),
                              );
                            },
                          ),
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

/// Selectable list of OFFLINE (Whisper) transcription languages, shown with
/// NATIVE labels. Pops the chosen ISO-639-1 code (or null when dismissed). The
/// current selection is highlighted; the list is the fixed [_kOfflineLanguages]
/// set (Whisper takes an ISO-639-1 code, not an STT locale id).
class _OfflineLanguagePickerSheet extends StatelessWidget {
  const _OfflineLanguagePickerSheet({required this.selectedCode});

  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SecretlyGlassSheetSurface(
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SecretlyGlassSheetHandle()),
                  const SizedBox(height: 12),
                  Text(
                    wave1Text(
                      context,
                      ru: 'Язык распознавания',
                      en: 'Recognition language',
                      uk: 'Мова розпізнавання',
                      es: 'Idioma de reconocimiento',
                      pt: 'Idioma de reconhecimento',
                      ptBr: 'Idioma de reconhecimento',
                      fr: 'Langue de reconnaissance',
                      de: 'Erkennungssprache',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _kOfflineLanguages.length,
                      itemBuilder: (context, i) {
                        final o = _kOfflineLanguages[i];
                        final selected = o.code == selectedCode;
                        return ListTile(
                          dense: true,
                          title: Text(
                            o.label,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected ? _kGold : cs.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            o.code,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded, color: _kGold)
                              : null,
                          onTap: () => Navigator.of(context).pop(o.code),
                        );
                      },
                    ),
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
