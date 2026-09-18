// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device message translation.
///
/// Privacy first: translation runs fully on the device via Google ML Kit — the
/// message plaintext NEVER leaves the phone, consistent with the app's E2EE
/// stance (no cloud translator). Language models (~30 MB each) download on
/// demand and are cached by ML Kit; translations are cached in-memory per
/// message so re-opening a chat is instant.
///
/// Everything fails SOFT (returns null) — a translation is a convenience layer
/// and must never throw into the chat UI.
class MessageTranslationService {
  MessageTranslationService._();
  static final MessageTranslationService instance =
      MessageTranslationService._();

  final LanguageIdentifier _languageId =
      LanguageIdentifier(confidenceThreshold: 0.5);
  final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators =
      <String, OnDeviceTranslator>{};

  /// Cache keyed by `<cacheKey>|<targetBcp>` so the same message isn't
  /// re-translated when a chat is reopened within a session.
  final Map<String, String> _cache = <String, String>{};

  /// Detects the BCP-47 language code of [text] (e.g. "ru"), or null when it
  /// can't be determined. Used to decide whether to offer a translate button.
  Future<String?> detectLanguage(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final code = await _languageId.identifyLanguage(text.trim());
      return (code == 'und' || code.isEmpty) ? null : code;
    } catch (_) {
      return null;
    }
  }

  /// True when the on-device model for [bcp] is already present (no download
  /// needed). Best-effort.
  Future<bool> isModelReady(String bcp) async {
    try {
      return await _models.isModelDownloaded(bcp);
    } catch (_) {
      return false;
    }
  }

  /// Translates [text] into [targetBcp] (e.g. "ru"). When [sourceBcp] is given
  /// (e.g. "en") it is used as the source language; otherwise the source is
  /// auto-detected. Returns null if: the source can't be determined, it already
  /// equals the target, the pair is unsupported by ML Kit, or anything fails.
  /// Caches the result by [cacheKey] (typically the message event id).
  Future<String?> translate({
    required String text,
    required String targetBcp,
    String? sourceBcp,
    String? cacheKey,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final ck = cacheKey == null
        ? null
        : '$cacheKey|$targetBcp|${sourceBcp ?? 'auto'}';
    if (ck != null) {
      final hit = _cache[ck];
      if (hit != null) return hit;
    }
    try {
      final target = BCP47Code.fromRawValue(targetBcp);
      if (target == null) return null;
      // Pinned source language wins; otherwise auto-detect from the text.
      final srcCode = (sourceBcp != null && sourceBcp.trim().isNotEmpty)
          ? sourceBcp.trim()
          : await detectLanguage(trimmed);
      if (srcCode == null) return null;
      final source = BCP47Code.fromRawValue(srcCode);
      if (source == null) return null;
      if (source == target) return null; // already in the target language

      // Ensure both models are present (idempotent; ~30 MB once per language).
      if (!await _models.isModelDownloaded(source.bcpCode)) {
        await _models.downloadModel(source.bcpCode, isWifiRequired: false);
      }
      if (!await _models.isModelDownloaded(target.bcpCode)) {
        await _models.downloadModel(target.bcpCode, isWifiRequired: false);
      }

      final key = '${source.bcpCode}->${target.bcpCode}';
      final translator = _translators.putIfAbsent(
        key,
        () => OnDeviceTranslator(
          sourceLanguage: source,
          targetLanguage: target,
        ),
      );
      final out = (await translator.translateText(trimmed)).trim();
      if (out.isEmpty) return null;
      if (ck != null) _cache[ck] = out;
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Releases native resources. The service is a process-long singleton, so this
  /// is mainly for tests/teardown.
  Future<void> dispose() async {
    for (final t in _translators.values) {
      try {
        await t.close();
      } catch (_) {}
    }
    _translators.clear();
    try {
      await _languageId.close();
    } catch (_) {}
  }
}
