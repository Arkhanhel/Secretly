// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// П1 (разбор медиа 15.11.2026): автозагрузка по мобильной сети.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/auto_download_policy.dart';

void main() {
  bool allows(
    CellularAutoDownload c, {
    bool? cellular = true,
    String mime = 'video/mp4',
    int size = 40 << 20,
    bool voice = false,
  }) => autoDownloadAllows(
    cellular: c,
    onCellularOnly: cellular,
    mime: mime,
    sizeBytes: size,
    isVoiceOrVideoNote: voice,
  );

  test('🔴 по умолчанию — всё, как было до 15.11', () {
    expect(cellularAutoDownloadFromPref(null), CellularAutoDownload.everything);
    expect(cellularAutoDownloadFromPref('будущий-вариант'),
        CellularAutoDownload.everything);
    expect(allows(CellularAutoDownload.everything), isTrue);
  });

  test('Wi-Fi или неизвестная сеть — всегда всё', () {
    for (final c in CellularAutoDownload.values) {
      expect(allows(c, cellular: false), isTrue);
      expect(allows(c, cellular: null), isTrue);
    }
  });

  test('голосовые и кружки — всегда', () {
    expect(allows(CellularAutoDownload.nothing, voice: true), isTrue);
  });

  test('варианты на мобильной сети', () {
    expect(allows(CellularAutoDownload.upTo15Mb, size: 14 << 20), isTrue);
    expect(allows(CellularAutoDownload.upTo15Mb, size: 16 << 20), isFalse);
    expect(allows(CellularAutoDownload.photosOnly, mime: 'image/jpeg'), isTrue);
    expect(allows(CellularAutoDownload.photosOnly), isFalse);
    expect(allows(CellularAutoDownload.nothing, mime: 'image/jpeg', size: 1),
        isFalse);
  });

  test('чем считается сеть', () {
    expect(isCellularOnly([ConnectivityResult.mobile]), isTrue);
    expect(
      isCellularOnly([ConnectivityResult.mobile, ConnectivityResult.wifi]),
      isFalse,
    );
    expect(isCellularOnly([ConnectivityResult.ethernet]), isFalse);
    expect(isCellularOnly([ConnectivityResult.vpn]), isNull);
    expect(isCellularOnly(const []), isNull);
  });
}
