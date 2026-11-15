// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Auto-download of incoming media over mobile data (media audit П1,
/// 15.11.2026).
///
/// Since 17.07 every incoming attachment is fetched the moment its message
/// arrives: the relay keeps a file for 7 days, and a photo that was never
/// opened in that time would be lost. That stays the DEFAULT — nobody's
/// behaviour changes until they pick something else. What is new is the
/// choice for mobile data; Wi-Fi and wired networks always fetch everything.
///
/// A postponed file is not lost: it is fetched as soon as the phone is on
/// Wi-Fi, or when the person opens it.
library;

import 'package:connectivity_plus/connectivity_plus.dart';

enum CellularAutoDownload {
  /// Everything, as before 15.11.2026. The default.
  everything,

  /// Photos, videos, music and files up to [kAutoDownloadMediaCapBytes].
  upTo15Mb,

  /// Photos only (any size a photo realistically has).
  photosOnly,

  /// Nothing but voice and video messages.
  nothing,
}

/// The cap for [CellularAutoDownload.upTo15Mb].
const int kAutoDownloadMediaCapBytes = 15 * 1024 * 1024;

/// Stored value ↔ enum. Unknown text (a future build's option) → default.
CellularAutoDownload cellularAutoDownloadFromPref(String? raw) {
  for (final v in CellularAutoDownload.values) {
    if (v.name == raw) return v;
  }
  return CellularAutoDownload.everything;
}

/// Is the phone on mobile data only? `null` — cannot tell (no answer, a
/// VPN only, a background isolate without the plugin): treated as Wi-Fi,
/// i.e. the old behaviour.
bool? isCellularOnly(List<ConnectivityResult> results) {
  if (results.isEmpty) return null;
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return false;
  }
  if (results.contains(ConnectivityResult.mobile)) return true;
  return null;
}

/// May this attachment be fetched in the background right now?
bool autoDownloadAllows({
  required CellularAutoDownload cellular,
  required bool? onCellularOnly,
  required String? mime,
  required int sizeBytes,
  required bool isVoiceOrVideoNote,
}) {
  if (onCellularOnly != true) return true;
  // Voice and round video messages are part of the conversation itself and
  // small — they always come.
  if (isVoiceOrVideoNote) return true;
  final m = (mime ?? '').toLowerCase();
  switch (cellular) {
    case CellularAutoDownload.everything:
      return true;
    case CellularAutoDownload.upTo15Mb:
      return sizeBytes > 0 && sizeBytes <= kAutoDownloadMediaCapBytes;
    case CellularAutoDownload.photosOnly:
      return m.startsWith('image/');
    case CellularAutoDownload.nothing:
      return false;
  }
}
