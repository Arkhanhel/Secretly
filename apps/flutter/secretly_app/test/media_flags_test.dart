// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Блок `media` подписанного конфига (15.11.2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/media_flags.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';

void main() {
  test('подписываемое сообщение — как Rust media_signing_message', () {
    expect(
      mediaSigningMessage(resumableUploadShare: 10, issuedAtMs: 1760000000123),
      'secretly-media-v1|10|1760000000123',
    );
  });

  test('🔴 непроверенный или отсутствующий блок — доля 0', () {
    final cfg = {
      'media': {'resumable_upload_share': 100, 'issued_at_ms': 1},
    };
    expect(MediaFlags.fromConfigResponse(cfg, verified: false), MediaFlags.defaults);
    expect(MediaFlags.fromConfigResponse(const {}, verified: true), MediaFlags.defaults);
    expect(
      MediaFlags.fromConfigResponse(cfg, verified: true).resumableUploadShare,
      100,
    );
  });

  test('доля: 0 — никто, 100 — все, расширение не выключает включённых', () {
    const ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
    expect(ids.where(const MediaFlags().resumableUploadFor), isEmpty);
    expect(
      ids.where(const MediaFlags(resumableUploadShare: 100).resumableUploadFor),
      ids,
    );
    final at10 = ids.where(
      const MediaFlags(resumableUploadShare: 10).resumableUploadFor,
    );
    final at50 = ids.where(
      const MediaFlags(resumableUploadShare: 50).resumableUploadFor,
    );
    expect(at50.toSet().containsAll(at10), isTrue);
    expect(const MediaFlags(resumableUploadShare: 100).resumableUploadFor(''), isFalse);
  });
}
