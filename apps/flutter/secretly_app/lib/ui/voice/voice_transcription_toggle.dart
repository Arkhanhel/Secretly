// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../billing/show_paywall.dart';
import '../../entitlements/feature_gate.dart';
import '../widgets/premium_glass.dart' show kPremiumGold;
import '../chat_screen_l10n.dart';
import '../paywall_screen.dart' show PaywallTrigger;
import 'voice_transcription.dart';

/// Telegram-style voice-to-text affordance.
///
/// Split into a controller + two views on purpose: the TRIGGER lives OUTSIDE the
/// bubble (a bare icon beside it) while the TRANSCRIPT renders INSIDE, under the
/// waveform. They are in different parts of the widget tree, so the state they
/// share — the text, whether it is expanded, whether a transcription is running
/// — cannot live in either of them and is held here instead.
///
/// Own one per message (keyed by eventId) and dispose it with the screen.
enum VoiceTxState { idle, working, shown, failed }

class VoiceTranscriptionController extends ChangeNotifier {
  VoiceTranscriptionController({
    required this.eventId,
    required this.appController,
    required this.resolveAudioFile,
  }) {
    // Surface a previously-cached transcript (collapsed) so re-opening a chat
    // never re-transcribes.
    _svc.cachedTranscript(eventId).then((t) {
      if (_disposed || t == null) return;
      _text = t;
      _state = VoiceTxState.shown;
      _expanded = false;
      notifyListeners();
    });
  }

  /// Stable per-message id used as the transcript cache key.
  final String eventId;
  final AppController appController;

  /// Lazily resolves the decrypted/cached voice file (only called on demand).
  final Future<File> Function() resolveAudioFile;

  final VoiceTranscriptionService _svc = VoiceTranscriptionService.instance;
  bool _disposed = false;

  VoiceTxState _state = VoiceTxState.idle;
  String? _text;
  bool _expanded = false;

  VoiceTxState get state => _state;
  String? get text => _text;
  bool get expanded => _expanded;
  ValueListenable<double?> get downloadProgress => _svc.downloadProgress;

  bool get unlocked => FeatureGate.isUnlocked(
    appController.entitlementStateNow,
    GatedFeature.voiceToText,
  );

  /// Tap on the trigger. Needs a context only for the paywall.
  Future<void> onTap(BuildContext context) async {
    if (_state == VoiceTxState.working) return;
    if (_text != null) {
      _expanded = !_expanded;
      notifyListeners();
      return;
    }
    if (!unlocked) {
      await showPaywall(context, PaywallTrigger.general);
      if (_disposed || !unlocked) return;
    }
    _state = VoiceTxState.working;
    notifyListeners();
    String? text;
    try {
      final file = await resolveAudioFile();
      text = await _svc.transcribe(eventId: eventId, audioPath: file.path);
    } catch (_) {
      text = null;
    }
    if (_disposed) return;
    _text = text;
    _state = text != null ? VoiceTxState.shown : VoiceTxState.failed;
    _expanded = text != null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The trigger, parked OUTSIDE the bubble: a bare icon, no label, no plate, no
/// background — it must read as a quiet affordance next to the bubble rather
/// than compete with it. While transcribing it becomes a small spinner (with the
/// model-download progress, which can take a while on first use); the wordy
/// states the old inline version showed are gone by design.
class VoiceTranscriptionIconButton extends StatelessWidget {
  const VoiceTranscriptionIconButton({
    super.key,
    required this.tx,
    required this.color,
  });

  final VoiceTranscriptionController tx;

  /// Tint to blend with — the bubble's foreground colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tx,
      builder: (context, _) {
        final muted = color.withValues(alpha: 0.55);
        if (tx.state == VoiceTxState.working) {
          return Padding(
            padding: const EdgeInsets.all(4),
            child: ValueListenableBuilder<double?>(
              valueListenable: tx.downloadProgress,
              builder: (context, progress, _) => SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: muted,
                  value: progress?.clamp(0.0, 1.0),
                ),
              ),
            ),
          );
        }
        final IconData icon;
        final String tooltip;
        if (tx.text != null) {
          icon = tx.expanded
              ? Icons.expand_less_rounded
              : Icons.subtitles_outlined;
          tooltip = tx.expanded
              ? chatText(context, ru: 'Скрыть текст', en: 'Hide text', uk: 'Сховати текст', es: 'Ocultar texto', pt: 'Ocultar texto', ptBr: 'Ocultar texto', fr: 'Masquer le texte', de: 'Text ausblenden')
              : chatText(context, ru: 'Показать текст', en: 'Show text', uk: 'Показати текст', es: 'Mostrar texto', pt: 'Mostrar texto', ptBr: 'Mostrar texto', fr: 'Afficher le texte', de: 'Text anzeigen');
        } else if (tx.state == VoiceTxState.failed) {
          icon = Icons.error_outline_rounded;
          tooltip = chatText(context, ru: 'Не удалось распознать', en: "Couldn't transcribe", uk: 'Не вдалося розпізнати', es: 'No se pudo transcribir', pt: 'Não foi possível transcrever', ptBr: 'Não foi possível transcrever', fr: 'Transcription impossible', de: 'Transkription fehlgeschlagen');
        } else {
          icon = Icons.subtitles_outlined;
          tooltip = chatText(context, ru: 'Показать текст', en: 'Show text', uk: 'Показати текст', es: 'Mostrar texto', pt: 'Mostrar texto', ptBr: 'Mostrar texto', fr: 'Afficher le texte', de: 'Text anzeigen');
        }
        return Semantics(
          button: true,
          label: tooltip,
          child: Tooltip(
            message: tooltip,
            child: InkResponse(
              onTap: () => tx.onTap(context),
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 16, color: muted),
                    // Premium hint for free users who have not unlocked
                    // on-device voice-to-text. A gold padlock — the app's
                    // established "locked behind Premium" mark (see the
                    // cosmetics screen) — rather than a star, which reads as
                    // "premium user" elsewhere. Never gates an existing
                    // transcript.
                    if (tx.text == null && !tx.unlocked)
                      const Positioned(
                        right: -3,
                        top: -3,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 9,
                          color: kPremiumGold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The transcript itself, rendered INSIDE the bubble under the waveform, where
/// it has the full bubble width to wrap into. Collapsed → nothing at all.
class VoiceTranscriptionBody extends StatelessWidget {
  const VoiceTranscriptionBody({
    super.key,
    required this.tx,
    required this.color,
  });

  final VoiceTranscriptionController tx;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tx,
      builder: (context, _) {
        final text = tx.text;
        if (text == null || !tx.expanded) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color.withValues(alpha: 0.92),
                fontSize: 13.5,
                height: 1.32,
              ),
            ),
          ),
        );
      },
    );
  }
}
