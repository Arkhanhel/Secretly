// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../wave1_l10n.dart';
import '../widgets/frosted_header_island.dart';

/// Result of a finished video-note recording (квадратик). Returned by
/// [showVideoNoteRecorder] when the user releases / sends a valid take.
class VideoNoteRecorderResult {
  const VideoNoteRecorderResult({required this.filePath, required this.durationMs});

  /// Temp `.mp4` path (path_provider temp dir). Caller is responsible for
  /// uploading/deleting it.
  final String filePath;

  /// Playback length in milliseconds (used for the bubble + payload).
  final int durationMs;
}

/// One captured lens-session clip plus the lens it came from. `isFront` decides
/// whether the final encode horizontally flips this segment so the front
/// (selfie) footage shows the same orientation the user saw in the mirrored
/// preview.
class _VideoSegment {
  const _VideoSegment(this.path, {required this.isFront});

  final String path;
  final bool isFront;
}

/// Drives the full-screen video-note recorder from the *composer* button.
///
/// The recorder starts capturing the moment it opens, then **auto-locks itself
/// into a self-contained session** the instant the first segment begins rolling
/// (see [_VideoNoteRecorderOverlayState._lock]). From that moment the recording
/// is a continuous take that can ONLY be ended by the on-screen Cancel / Send
/// buttons (or the max-duration cap) — never by a finger lift and never by a
/// second finger.
///
/// The composer keeps ownership of the raw press gesture (its existing
/// `Listener`) and forwards intent here, but every one of these is treated as a
/// *hint from the single primary pointer* and is deliberately INERT once the
/// session has self-locked, so multi-touch (tapping camera-switch / flashlight
/// with a 2nd finger, or the 1st finger drifting during the camera swap) can
/// never stop, cancel, or finalize the take:
///  * [updateDrag]   — live "slide left to cancel" affordance; ignored after
///                     self-lock (the on-screen Cancel button takes over).
///  * [signalLock]   — finger dragged up → hands-free. Redundant now that the
///                     session auto-locks, but kept for back-compat.
///  * [signalCancel] — finger-lift *cancel* gesture. Ignored after self-lock so
///                     a stray 2nd-finger pointer-cancel can't discard the take.
///  * [signalRelease]— finger lifted. Ignored after self-lock so lifting the
///                     finger (the normal case once recording owns itself, and
///                     the multi-touch case) never finalizes — only the
///                     explicit Send button does.
///
/// All are no-ops once the recorder has resolved.
class VideoNoteRecorderController {
  _VideoNoteRecorderOverlayState? _state;

  bool get isAttached => _state != null;

  void _attach(_VideoNoteRecorderOverlayState state) => _state = state;
  void _detach(_VideoNoteRecorderOverlayState state) {
    if (identical(_state, state)) _state = null;
  }

  /// Live drag offset from the press origin, so the overlay can render the
  /// "slide left to cancel" affordance while the finger is still down.
  void updateDrag({required double dx, required double dy}) =>
      _state?._onDrag(dx: dx, dy: dy);

  void signalLock() => _state?._lock();

  /// Explicit cancel / teardown — ALWAYS discards the take and releases the
  /// camera. The composer calls this both for the swipe-left cancel intent and,
  /// crucially, from its own `dispose()` when the user leaves the chat
  /// mid-recording, so it must NOT be gated on the lock state (otherwise a
  /// self-locked session would leak the camera on teardown). Multi-touch is a
  /// non-issue here: the composer only forwards a pointer-cancel for its single
  /// primary pointer (a 2nd finger's cancel is filtered out upstream), so a
  /// button tap can never reach this.
  void signalCancel() => _state?._cancelAndClose();

  /// Finger lift from the composer gesture. Honoured ONLY while the session has
  /// not yet self-locked; afterwards it is a no-op so neither lifting the
  /// holding finger nor a stray second-finger pointer-up can finalize the take.
  void signalRelease() => _state?._releaseFromGesture();
}

/// Opens the rounded-square camera recorder overlay and resolves with a
/// [VideoNoteRecorderResult] on send, or `null` if the take was cancelled /
/// too short / permission denied.
///
/// Recording begins immediately and **auto-locks into a self-contained session**
/// once the first segment is rolling — from then on the take is one continuous
/// recording that only the on-screen Cancel / Send buttons (or the max-duration
/// cap) can end. Switching the camera or toggling the flashlight (including the
/// 2nd-finger taps that drive them) never interrupts, segments-and-drops, or
/// finalizes the recording. The caller's [controller] still forwards the press
/// gesture, but those signals are inert after self-lock. If [controller] is
/// omitted the overlay runs in the same locked mode (Stop/Send button only).
Future<VideoNoteRecorderResult?> showVideoNoteRecorder(
  BuildContext context, {
  VideoNoteRecorderController? controller,
}) {
  final completer = Completer<VideoNoteRecorderResult?>();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _VideoNoteRecorderOverlay(
      controller: controller,
      onResolved: (result) {
        if (!completer.isCompleted) completer.complete(result);
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _VideoNoteRecorderOverlay extends StatefulWidget {
  const _VideoNoteRecorderOverlay({
    required this.controller,
    required this.onResolved,
  });

  final VideoNoteRecorderController? controller;
  final ValueChanged<VideoNoteRecorderResult?> onResolved;

  @override
  State<_VideoNoteRecorderOverlay> createState() =>
      _VideoNoteRecorderOverlayState();
}

class _VideoNoteRecorderOverlayState extends State<_VideoNoteRecorderOverlay>
    with TickerProviderStateMixin {
  static const Duration _maxDuration = Duration(seconds: 60);
  static const Duration _minDuration = Duration(milliseconds: 600);
  static const double _cancelThresholdPx = 110;

  CameraController? _camera;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;
  // The two lenses the recorder toggles between: the MAIN 1× back lens and the
  // primary front lens. Resolved ONCE in [_boot] from [availableCameras] so the
  // camera-switch button always flips main-back ⇄ front and never lands on an
  // ultra-wide / telephoto back lens (the device may expose several). −1 means
  // "no lens of that facing on this device".
  int _backCameraIndex = -1;
  int _frontCameraIndex = -1;
  // BACK camera: real hardware torch. FRONT camera: there is no torch LED, so
  // the same button instead lights a full opaque-white surround around the
  // square preview to illuminate the face.
  bool _torchOn = false;
  bool _frontFlashOn = false;
  bool _unavailable = false;
  bool _recording = false;
  bool _locked = false;
  bool _resolved = false;
  bool _finishing = false;
  bool _switchingCamera = false;
  // Completes when an in-flight camera swap (the async stop-old → dispose →
  // init-new → start-new dance in [_flipCamera]) settles. Finalize/cancel await
  // this BEFORE touching `_camera`/`_segments`, so a Send tap or the max-timer
  // that lands mid-swap can never race the swap and drop a segment.
  Completer<void>? _switchSettled;

  // Segmented recording: the `camera` plugin cannot switch lens on a live
  // recording controller, so each lens session is captured into its own file
  // and the finished segments are concatenated on FINAL stop. The on-screen
  // timer counts CUMULATIVE time across flips (it never resets to 0).
  //
  // Each segment also remembers whether it was captured on the FRONT lens. The
  // front camera records a NON-mirrored frame (the opposite of the mirrored
  // selfie preview the user saw), so front segments must be horizontally
  // flipped (`hflip`) in the final encode to match what the user expects.
  final List<_VideoSegment> _segments = <_VideoSegment>[];
  Duration _completedSegments = Duration.zero;

  String? _recordPath;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  Timer? _maxTimer;

  // Drag affordance (mirrors the voice recorder).
  double _dragDx = 0;
  double _cancelProgress = 0;

  late final AnimationController _pulse;

  bool get _isFront =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    unawaited(_boot());
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _ticker?.cancel();
    _maxTimer?.cancel();
    _pulse.dispose();
    final cam = _camera;
    _camera = null;
    if (cam != null) unawaited(cam.dispose());
    // If the overlay was torn down without a clean finish/cancel, drop any
    // leftover segment temp files so they don't accumulate.
    final leftovers = _segments.map((s) => s.path).toList();
    _segments.clear();
    for (final seg in leftovers) {
      unawaited(_deleteIfAny(seg));
    }
    super.dispose();
  }

  Future<void> _boot() async {
    // Permission-first: camera + mic, exactly like voice dictation.
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      _resolve(null);
      return;
    }
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const <CameraDescription>[];
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _unavailable = true);
      return;
    }
    // Resolve the two lenses we toggle between ONCE: the MAIN 1× back lens and
    // the primary front lens. A device can expose several back lenses
    // (ultra-wide / telephoto in addition to the main wide-angle 1×); we must
    // pick the MAIN one, never the ultra-wide, so a video note frames like the
    // normal camera does.
    _backCameraIndex = _pickMainBackCamera();
    _frontCameraIndex = _pickPrimaryFrontCamera();
    // Prefer the FRONT camera for a video note (selfie), like Telegram. Fall
    // back to the main back lens, then to the first camera if neither resolved.
    _cameraIndex = _frontCameraIndex >= 0
        ? _frontCameraIndex
        : (_backCameraIndex >= 0 ? _backCameraIndex : 0);
    await _initController(startRecording: true);
  }

  /// The index of the MAIN 1× back lens in [_cameras].
  ///
  /// Conventionally the FIRST back camera reported by `availableCameras()` is
  /// the main wide-angle (1×) lens — both `camera_android_camerax`
  /// (`getAvailableCameraInfos` order) and `camera_avfoundation` (which lists
  /// `.builtInWideAngleCamera` before `.builtInUltraWideCamera`) put it first.
  /// We additionally honour the `lensType` hint when present: prefer an
  /// explicit `CameraLensType.wide` back lens and explicitly skip
  /// `CameraLensType.ultraWide`, so even if a device ever reported ultra-wide
  /// first we still land on the main 1×. Returns −1 if the device has no back
  /// lens.
  int _pickMainBackCamera() {
    final backs = <int>[];
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.back) backs.add(i);
    }
    if (backs.isEmpty) return -1;
    // 1) An explicit wide-angle (1×) back lens wins.
    for (final i in backs) {
      if (_cameras[i].lensType == CameraLensType.wide) return i;
    }
    // 2) Otherwise the first back lens that is NOT ultra-wide / telephoto.
    for (final i in backs) {
      final t = _cameras[i].lensType;
      if (t != CameraLensType.ultraWide && t != CameraLensType.telephoto) {
        return i;
      }
    }
    // 3) No lens-type info to disambiguate → the first back lens, which is the
    // main 1× by platform convention.
    return backs.first;
  }

  /// The index of the primary FRONT lens (first front camera; prefer the
  /// wide-angle one if `lensType` is reported). Returns −1 if none.
  int _pickPrimaryFrontCamera() {
    final fronts = <int>[];
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) fronts.add(i);
    }
    if (fronts.isEmpty) return -1;
    for (final i in fronts) {
      if (_cameras[i].lensType == CameraLensType.wide) return i;
    }
    return fronts.first;
  }

  /// The lens to switch to from the current one: toggles MAIN-back ⇄ front.
  /// Falls back to a plain wrap only if one of the two facings is missing.
  int _nextToggleCameraIndex() {
    final haveBoth = _backCameraIndex >= 0 && _frontCameraIndex >= 0;
    if (haveBoth) {
      return _cameraIndex == _frontCameraIndex
          ? _backCameraIndex
          : _frontCameraIndex;
    }
    if (_cameras.isEmpty) return 0;
    return (_cameraIndex + 1) % _cameras.length;
  }

  Future<void> _initController({bool startRecording = false}) async {
    if (_cameras.isEmpty) return;
    try {
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _camera;
      // Never leave a previous controller recording while we swap it out — stop
      // its take first, then fully dispose it (two live controllers contend for
      // the camera/encoder and hang).
      if (previous != null && previous.value.isRecordingVideo) {
        try {
          final file = await previous.stopVideoRecording();
          await _deleteIfAny(file.path);
        } catch (_) {}
      }
      setState(() {
        _camera = controller;
        _unavailable = false;
        _torchOn = false;
      });
      if (previous != null) {
        try {
          await previous.dispose();
        } catch (_) {}
      }
      if (startRecording) await _startRecording();
    } catch (_) {
      if (mounted) {
        setState(() => _unavailable = true);
      }
    }
  }

  /// Cumulative elapsed time = time banked in already-finished segments plus
  /// the live segment currently running. Used by the ticker and final stop so
  /// the timer keeps counting straight through a camera flip.
  Duration _currentElapsed() {
    final started = _startedAt;
    final live = (started == null || !_recording)
        ? Duration.zero
        : DateTime.now().difference(started);
    return _completedSegments + live;
  }

  Future<void> _startRecording() async {
    final controller = _camera;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo) {
      return;
    }
    try {
      await controller.startVideoRecording();
      if (!mounted) {
        unawaited(controller.stopVideoRecording().catchError((_) => XFile('')));
        return;
      }
      HapticFeedback.selectionClick();
      // New segment's wall-clock anchor. Banked time from earlier segments
      // stays in [_completedSegments], so the displayed timer is continuous.
      _startedAt = DateTime.now();
      setState(() {
        _recording = true;
        _elapsed = _completedSegments;
      });
      // Self-lock the moment the FIRST segment is rolling. From here the take
      // is a self-contained session: finger lifts and 2nd-finger button taps
      // can no longer stop/cancel/finalize it — only the on-screen Send/Cancel
      // buttons (or the max-duration cap) can. Idempotent, so re-arming a new
      // segment after a camera flip is a harmless no-op.
      _lock();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (!mounted || _startedAt == null || !_recording) return;
        setState(() => _elapsed = _currentElapsed());
      });
      _maxTimer?.cancel();
      // Cap on the CUMULATIVE recording, not just the current segment.
      final remaining = _maxDuration - _completedSegments;
      _maxTimer = Timer(
        remaining > Duration.zero ? remaining : Duration.zero,
        () => unawaited(_finishAndClose(send: true)),
      );
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  // ── Gesture intents forwarded from the composer ────────────────────────
  // NOTE: the session self-locks the instant the first segment rolls (see
  // _startRecording → _lock), so in practice these gesture hints are only ever
  // honoured during the brief pre-lock warm-up window. Once locked they are
  // INERT — this is what makes the take immune to finger lifts and 2nd-finger
  // button taps (multi-touch). The on-screen Cancel / Send buttons own the
  // lifecycle from then on.
  void _onDrag({required double dx, required double dy}) {
    if (!mounted || _locked || !_recording) return;
    setState(() {
      _dragDx = dx;
      _cancelProgress = (-dx / _cancelThresholdPx).clamp(0.0, 1.0);
    });
    if (dx <= -_cancelThresholdPx) {
      _cancelAndClose();
    }
  }

  /// Finger lift forwarded from the composer gesture. Inert once the session
  /// has self-locked: lifting the holding finger — or any second-finger
  /// pointer-up — does NOT finalize the recording. Only the explicit on-screen
  /// Send button (or the max-duration cap) finalizes. Before lock, a lift means
  /// the user let go during warm-up before anything was captured, so we cancel
  /// rather than send an empty take.
  void _releaseFromGesture() {
    if (_locked) {
      // Locked, self-contained session — ignore the finger lift entirely. The
      // recording keeps rolling until the Send/Cancel button is pressed.
      return;
    }
    // Not locked yet → nothing has been captured; treat a lift as a cancel.
    unawaited(_cancelAndClose());
  }

  void _lock() {
    if (!mounted || _locked || _resolved) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _locked = true;
      _dragDx = 0;
      _cancelProgress = 0;
    });
  }

  Future<void> _flipCamera() async {
    // (a) Ignore re-entrant taps and bail while finishing / unmounted. The
    // re-entrancy guard alone makes a 2nd-finger double-tap on the switch
    // button safe; the completer below makes a concurrent Send/cancel safe.
    if (_cameras.length < 2) return;
    if (_switchingCamera || _finishing || !mounted) return;
    _switchingCamera = true;
    final settled = Completer<void>();
    _switchSettled = settled;

    final wasRecording = _recording;
    try {
      // (b) Stop the timers so no tick fires against a half-torn-down camera.
      _ticker?.cancel();
      _ticker = null;
      _maxTimer?.cancel();
      _maxTimer = null;

      final old = _camera;
      final segmentStartedAt = _startedAt;
      // Lens of the segment we are about to close (BEFORE the flip below), so
      // the concat encode can mirror front-lens clips.
      final closingSegmentIsFront = _isFront;

      // (c) If a take is in progress, stop it and KEEP the clip — the `camera`
      // plugin can't continue one recording across a lens switch, so we close
      // this lens's segment and append it to the segment list. Its wall-clock
      // duration is banked so the on-screen timer keeps counting (never resets
      // to 0). We do NOT flip _recording off here, so _currentElapsed keeps
      // attributing live time until the new segment opens — but we null the
      // ticker above so there is no setState against the torn-down camera.
      if (old != null && old.value.isRecordingVideo) {
        try {
          final file = await old.stopVideoRecording();
          if (file.path.isNotEmpty && await File(file.path).exists()) {
            _segments.add(
              _VideoSegment(file.path, isFront: closingSegmentIsFront),
            );
            if (segmentStartedAt != null) {
              _completedSegments += DateTime.now().difference(segmentStartedAt);
            }
          }
        } catch (_) {}
      }
      _startedAt = null;

      // (d) FULLY dispose the old controller before touching the new lens, so
      // two controllers never contend for the camera/encoder (the freeze).
      // Drop the preview to a spinner while we swap. Keep _elapsed pinned at
      // the banked total so the timer pill shows continuous time during the
      // brief swap, and reset BOTH flash modes (new lens starts dark).
      if (mounted) {
        setState(() {
          _camera = null;
          _recording = false;
          _torchOn = false;
          _frontFlashOn = false;
          _elapsed = _completedSegments;
        });
      } else {
        _camera = null;
        _recording = false;
        _torchOn = false;
        _frontFlashOn = false;
      }
      if (old != null) {
        try {
          await old.dispose();
        } catch (_) {}
      }

      if (!mounted || _finishing) return;

      // (e) Flip between the MAIN 1× back lens and the primary front lens — NOT
      // a blind `+1 % length` cycle, which on a multi-back-lens device would
      // step onto the ultra-wide / telephoto back camera. If only one facing
      // resolved (e.g. front-only device) fall back to the simple wrap.
      _cameraIndex = _nextToggleCameraIndex();

      // (f) Create + initialize the new controller.
      final next = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await next.initialize();
      if (!mounted || _finishing) {
        try {
          await next.dispose();
        } catch (_) {}
        return;
      }
      setState(() {
        _camera = next;
        _unavailable = false;
        _torchOn = false;
        _frontFlashOn = false;
      });

      // (g) Immediately open a NEW segment on the new lens. The recording
      // visibly continues; _startRecording re-anchors _startedAt and resumes
      // the cumulative timer from _completedSegments.
      if (wasRecording) await _startRecording();
    } catch (_) {
      if (mounted) setState(() => _unavailable = true);
    } finally {
      _switchingCamera = false;
      if (identical(_switchSettled, settled)) _switchSettled = null;
      if (!settled.isCompleted) settled.complete();
    }
  }

  /// Flash button. The button is ALWAYS tappable:
  ///  * BACK lens  → toggle the REAL hardware torch (FlashMode.torch ⇄ off).
  ///  * FRONT lens → there is no front torch LED, so toggle a full opaque
  ///    bright-white surround behind/around the square to light up the face.
  ///    No hardware torch call is made on the front.
  Future<void> _toggleFlash() async {
    final controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isFront) {
      HapticFeedback.selectionClick();
      setState(() => _frontFlashOn = !_frontFlashOn);
      return;
    }
    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {}
  }

  Future<void> _cancelAndClose() async {
    if (_resolved || _finishing) return;
    // Set _finishing FIRST: an in-flight _flipCamera observes it and stops
    // opening a new segment, then settles. We await that so we don't race the
    // swap while it mutates _camera / _segments.
    _finishing = true;
    _ticker?.cancel();
    _maxTimer?.cancel();
    final swap = _switchSettled;
    if (swap != null && !swap.isCompleted) {
      try {
        await swap.future;
      } catch (_) {}
    }
    final controller = _camera;
    String? path;
    if (controller != null && controller.value.isRecordingVideo) {
      try {
        final file = await controller.stopVideoRecording();
        path = file.path;
      } catch (_) {}
    }
    await _deleteIfAny(path);
    // Discard any banked segments from earlier lens switches too.
    for (final seg in _segments) {
      await _deleteIfAny(seg.path);
    }
    _segments.clear();
    _resolve(null);
  }

  Future<void> _finishAndClose({required bool send}) async {
    if (_resolved || _finishing) return;
    // Set _finishing FIRST so an in-flight _flipCamera stops opening a NEW
    // segment (it already banked the segment it just closed). Then await the
    // swap to settle so we never read _camera / _segments mid-mutation — this
    // is what guarantees EVERY segment across one or more camera flips is in
    // _segments before we concat, instead of racing the swap and shipping only
    // the last piece.
    _finishing = true;
    _ticker?.cancel();
    _maxTimer?.cancel();
    final swap = _switchSettled;
    if (swap != null && !swap.isCompleted) {
      try {
        await swap.future;
      } catch (_) {}
    }
    // Cumulative length across every segment (banked + the live one). Computed
    // AFTER the swap settles so the banked total is final.
    final elapsed = _currentElapsed();

    // Close the live segment and append it to the segment list. Together with
    // any earlier banked segments (from camera flips) this is the full take.
    // (_currentElapsed already read _startedAt above, so it's safe to clear.)
    // Capture the live lens BEFORE stopping so the segment is flagged front/back
    // for the concat mirror.
    final liveSegmentIsFront = _isFront;
    final controller = _camera;
    _startedAt = null;
    if (controller != null && controller.value.isRecordingVideo) {
      try {
        final file = await controller.stopVideoRecording();
        if (file.path.isNotEmpty && await File(file.path).exists()) {
          _segments.add(
            _VideoSegment(file.path, isFront: liveSegmentIsFront),
          );
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _recording = false);
    // Fallback to the legacy single-shot path if no segment was captured but a
    // record path is around (defensive — _recordPath is presently unused).
    if (_segments.isEmpty && (_recordPath?.isNotEmpty ?? false)) {
      _segments.add(_VideoSegment(_recordPath!, isFront: liveSegmentIsFront));
    }

    final tooShort = _segments.isEmpty || elapsed < _minDuration;
    if (!send || tooShort) {
      for (final seg in _segments) {
        await _deleteIfAny(seg.path);
      }
      _segments.clear();
      // Released too early — usually before the camera finished warming up.
      // Tell the user to hold longer instead of closing silently (which read
      // as "tap → blink → nothing happened").
      if (send && tooShort && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              wave1Text(
                context,
                ru: 'Слишком коротко — удерживайте дольше',
                en: 'Too short — hold longer',
                uk: 'Занадто коротко — утримуйте довше',
                es: 'Demasiado corto — mantén pulsado',
                pt: 'Curto demais — segure mais',
                ptBr: 'Curto demais — segure mais',
                fr: 'Trop court — maintenez plus longtemps',
                de: 'Zu kurz — länger halten',
              ),
            ),
          ),
        );
      }
      _resolve(null);
      return;
    }

    // Single segment (no lens switch):
    //  * BACK  → use it directly (fast copy). CameraX/AVFoundation already
    //    embed the correct rotation matrix, so the bubble's cover-crop shows a
    //    true square — no re-encode needed.
    //  * FRONT → the raw front clip is NOT mirrored (opposite of the selfie
    //    preview) and a copy wouldn't fix that, so re-encode through the
    //    square + `hflip` path so it shows correctly mirrored and 1:1.
    // Multiple segments (one or more camera flips mid-recording): concatenate
    // them into ONE continuous mp4 with the ffmpeg concat FILTER, normalising
    // each segment to a TRUE square (auto-rotate → center-crop → fixed square →
    // setsar=1 → common fps) and `hflip`-ing the front-lens segments. The cheap
    // `-c copy` demuxer can't be used (front/back differ in resolution /
    // orientation and need the mirror), so the filter re-encodes.
    String? produced;
    if (_segments.length == 1) {
      final only = _segments.first;
      produced = only.isFront
          ? await _encodeSquareSingle(only)
          : await _persistSingleSegment(only.path);
    } else {
      produced = await _concatSegments(_segments);
    }

    // Clean up all the raw segment temp files now that we have the output
    // (the output lives under a different name). Skip deleting the file we are
    // about to return, just in case the single-segment path reused it.
    for (final seg in _segments) {
      if (produced == null || p.normalize(seg.path) != p.normalize(produced)) {
        await _deleteIfAny(seg.path);
      }
    }
    _segments.clear();

    if (produced == null || produced.isEmpty) {
      _resolve(null);
      return;
    }

    _resolve(
      VideoNoteRecorderResult(
        filePath: produced,
        durationMs: elapsed.inMilliseconds,
      ),
    );
  }

  /// Copies a single recorded segment into the app temp dir under a stable
  /// `video_note_*.mp4` name so the caller can move/upload it. Returns the
  /// destination path (or the original on copy failure).
  Future<String> _persistSingleSegment(String path) async {
    try {
      final dir = await getTemporaryDirectory();
      final dest = p.join(
        dir.path,
        'video_note_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      final src = File(path);
      if (await src.exists() && p.normalize(path) != p.normalize(dest)) {
        await src.copy(dest);
        // Caller-facing copy made; the raw segment is cleaned up by the loop in
        // _finishAndClose.
        return dest;
      }
    } catch (_) {}
    return path;
  }

  /// Fixed square edge (px) every re-encoded video note is normalised to. Even
  /// (H.264-safe) and matches the square preview / in-chat bubble.
  static const int _kSquareEdge = 480;

  /// The per-segment video filter chain that turns ANY source frame into a
  /// TRUE [_kSquareEdge]² square with a common fps and square pixels:
  ///   (hflip if front,) center-crop to the largest square, scale to NxN,
  ///   setsar=1, fps.
  ///
  /// ffmpeg auto-rotates inputs that carry a rotate/display-matrix tag BY
  /// DEFAULT (modern ffmpeg ≥5), so by the time `crop` runs the frame is
  /// already upright — `crop=min(iw,ih):min(iw,ih)` (centered) then yields a
  /// square regardless of whether the source was stored portrait or landscape.
  /// This is the fix for the Android "rectangular 9:16 inside the square" bug:
  /// the old chain probed the *un-rotated* stored dimensions and letterboxed
  /// onto a non-square canvas. FRONT footage is recorded NON-mirrored, so we
  /// `hflip` it first to match the mirrored selfie preview the user saw.
  String _squareVideoChain(_VideoSegment seg) {
    final flip = seg.isFront ? 'hflip,' : '';
    return '${flip}crop=min(iw\\,ih):min(iw\\,ih),'
        'scale=$_kSquareEdge:$_kSquareEdge,setsar=1,fps=30';
  }

  /// Re-encodes a SINGLE segment into a square mp4 (used for a front-only note:
  /// the raw front clip is not mirrored and a plain copy can't fix that, so it
  /// must go through the square + `hflip` chain). Returns the output path, or
  /// falls back to a plain copy on failure so the user still gets the clip.
  Future<String?> _encodeSquareSingle(_VideoSegment seg) async {
    final dir = await getTemporaryDirectory();
    final out = p.join(
      dir.path,
      'video_note_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await _deleteIfAny(out);
    final cmd =
        '-y -i "${seg.path}" '
        '-vf "${_squareVideoChain(seg)}" '
        '-c:v libx264 -preset veryfast -pix_fmt yuv420p '
        '-c:a aac -movflags +faststart '
        '"$out"';
    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && File(out).existsSync()) {
        return out;
      }
    } catch (_) {}
    await _deleteIfAny(out);
    return _persistSingleSegment(seg.path);
  }

  /// Concatenates [segments] (recorded across camera flips, so potentially of
  /// different WxH / orientation / lens) into ONE continuous SQUARE mp4 using
  /// the ffmpeg concat FILTER. Each segment is independently normalised to a
  /// true [_kSquareEdge]² square via [_squareVideoChain] (auto-rotate →
  /// center-crop → fixed square → setsar=1 → common fps, plus `hflip` for front
  /// segments), then the streams are joined. The concat filter re-encodes, so
  /// mismatched inputs join cleanly (unlike `-c copy`). Returns the output mp4
  /// path, or null on failure.
  Future<String?> _concatSegments(List<_VideoSegment> segments) async {
    if (segments.isEmpty) return null;
    if (segments.length == 1) {
      final only = segments.first;
      return only.isFront
          ? _encodeSquareSingle(only)
          : _persistSingleSegment(only.path);
    }

    final dir = await getTemporaryDirectory();
    final out = p.join(
      dir.path,
      'video_note_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await _deleteIfAny(out);

    // Build: -i seg0 -i seg1 ... -filter_complex
    //   "[0:v]<square chain>[v0];[0:a]anull[a0];
    //    [1:v]<square chain>[v1];[1:a]anull[a1];
    //    [v0][a0][v1][a1]concat=n=N:v=1:a=1[outv][outa]"
    //   -map [outv] -map [outa] ... out.mp4
    // Every [i:v] is forced to the SAME NxN square (so the concat filter's
    // strict same-dimension requirement holds and the output is square), and
    // front segments are mirrored. anull normalizes audio so the concat
    // filter's a-pads always have a stream even if a segment lost audio.
    final n = segments.length;
    final inputs = StringBuffer();
    final filter = StringBuffer();
    final concatRefs = StringBuffer();
    for (var i = 0; i < n; i++) {
      inputs.write('-i "${segments[i].path}" ');
      filter.write(
        '[$i:v]${_squareVideoChain(segments[i])}[v$i];'
        '[$i:a]anull[a$i];',
      );
      concatRefs.write('[v$i][a$i]');
    }
    filter.write('${concatRefs}concat=n=$n:v=1:a=1[outv][outa]');

    final cmd =
        '-y ${inputs.toString().trim()} '
        '-filter_complex "${filter.toString()}" '
        '-map "[outv]" -map "[outa]" '
        '-c:v libx264 -preset veryfast -pix_fmt yuv420p '
        '-c:a aac -movflags +faststart '
        '"$out"';

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && File(out).existsSync()) {
        return out;
      }
    } catch (_) {}
    // Concat failed — degrade gracefully to a square re-encode of the first
    // segment so the user at least gets the opening portion (correctly square /
    // mirrored) rather than nothing.
    await _deleteIfAny(out);
    final first = segments.first;
    return first.isFront
        ? _encodeSquareSingle(first)
        : _persistSingleSegment(first.path);
  }

  Future<void> _deleteIfAny(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _resolve(VideoNoteRecorderResult? result) {
    if (_resolved) return;
    _resolved = true;
    widget.onResolved(result);
  }

  String _timerLabel(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final tenths = (d.inMilliseconds % 1000) ~/ 100;
    return '$minutes:${seconds.toString().padLeft(2, '0')},$tenths';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = math.min(media.size.width, media.size.height);
    final square = (size * 0.74).clamp(220.0, 360.0);
    final controller = _camera;
    final hasPreview = controller != null && controller.value.isInitialized;
    final showGlow = _isFront && hasPreview;
    // FRONT-camera "flash": phones have no front torch LED, so light the entire
    // area AROUND the square preview with opaque bright white to illuminate the
    // face. Only meaningful on the front lens with a live preview.
    final frontFlash = _isFront && hasPreview && _frontFlashOn;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop: normally a dim scrim; when the FRONT-camera flash is on,
          // a full opaque bright-white fill that surrounds the square preview
          // and bounces light back onto the face.
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            color: frontFlash ? const Color(0xFFFFFFFF) : const Color(0xE6000000),
          ),
          // Front-camera selfie glow: a big soft white radial behind the square.
          // Suppressed while the full white surround is active (it would be
          // invisible on white and just waste a layer).
          if (showGlow && !frontFlash)
            Center(
              child: Container(
                width: square * 2.0,
                height: square * 2.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          // The rounded-square camera preview, center-cropped to 1:1.
          Center(
            child: _SquarePreview(
              size: square,
              child: hasPreview
                  ? _CroppedCameraPreview(controller: controller)
                  : Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: _unavailable
                          ? Text(
                              wave1Text(
                                context,
                                ru: 'Камера недоступна',
                                en: 'Camera unavailable',
                                uk: 'Камера недоступна',
                                es: 'Camara no disponible',
                                pt: 'Camara indisponivel',
                                ptBr: 'Camera indisponivel',
                                fr: 'Camera indisponible',
                                de: 'Kamera nicht verfugbar',
                              ),
                              style: const TextStyle(color: Colors.white70),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                    ),
            ),
          ),
          // Timer pill + red dot above the square.
          Positioned(
            top: media.padding.top + 24,
            left: 0,
            right: 0,
            child: Center(
              child: FrostedHeaderIsland(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => Opacity(
                        opacity: 0.45 + 0.55 * (1 - (_pulse.value - 0.5).abs() * 2),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timerLabel(_elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Left island controls: switch camera + torch.
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IslandIconButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: _cameras.length >= 2 ? _flipCamera : null,
                  ),
                  const SizedBox(height: 14),
                  // Flash button — ALWAYS tappable when a preview is live:
                  //  * BACK lens  → real hardware torch (flash_on/flash_off).
                  //  * FRONT lens → white-surround "flash" (no LED): a distinct
                  //    icon (lightbulb) so users see it's the screen-light mode.
                  _IslandIconButton(
                    icon: _isFront
                        ? (_frontFlashOn
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded)
                        : (_torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded),
                    active: _isFront ? _frontFlashOn : _torchOn,
                    onTap: hasPreview ? _toggleFlash : null,
                  ),
                ],
              ),
            ),
          ),
          // Bottom hint / lock + Stop-Send.
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 36,
            child: Center(
              child: _locked
                  ? _LockedControls(
                      onCancel: _cancelAndClose,
                      onSend: () => unawaited(_finishAndClose(send: true)),
                      cancelLabel: wave1Text(
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
                    )
                  : Opacity(
                      opacity: (1.0 - _cancelProgress).clamp(0.35, 1.0),
                      child: Transform.translate(
                        offset: Offset(_dragDx.clamp(-120.0, 0.0) * 0.4, 0),
                        child: FrostedHeaderIsland(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                wave1Text(
                                  context,
                                  ru: 'Влево — отмена',
                                  en: 'Left to cancel',
                                  uk: 'Вліво — скасувати',
                                  es: 'Izquierda para cancelar',
                                  pt: 'Esquerda para cancelar',
                                  ptBr: 'Esquerda para cancelar',
                                  fr: 'Gauche pour annuler',
                                  de: 'Links zum Abbrechen',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square frame with a thin recording ring around the camera preview.
class _SquarePreview extends StatelessWidget {
  const _SquarePreview({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Match the in-chat bubble's much-softer rounded-square look (≥2×).
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: child,
      ),
    );
  }
}

/// Center-crops the (rectangular) camera stream to a 1:1 square via cover-fit.
class _CroppedCameraPreview extends StatelessWidget {
  const _CroppedCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) {
      return CameraPreview(controller);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // previewSize is landscape-oriented; swap for portrait display.
          width: preview.height,
          height: preview.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _IslandIconButton extends StatelessWidget {
  const _IslandIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: FrostedHeaderIsland(
        radius: 24,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                color: active ? const Color(0xFFFFD24A) : Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hands-free controls shown after the recording is locked.
class _LockedControls extends StatelessWidget {
  const _LockedControls({
    required this.onCancel,
    required this.onSend,
    required this.cancelLabel,
  });

  final VoidCallback onCancel;
  final VoidCallback onSend;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FrostedHeaderIsland(
          radius: 22,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Text(
                  cancelLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Material(
          color: const Color(0xFF34C759),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSend,
            child: const SizedBox(
              width: 60,
              height: 60,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ],
    );
  }
}
