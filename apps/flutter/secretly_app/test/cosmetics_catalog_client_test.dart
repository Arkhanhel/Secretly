// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/transport/cosmetics_catalog_client.dart';

void main() {
  group('RemoteCosmeticsManifest.fromJson', () {
    test('parses items and splits icons / wallpapers by kind', () {
      final m = RemoteCosmeticsManifest.fromJson({
        'schema_version': 1,
        'generated_at_ms': 123,
        'items': [
          {
            'id': 'icon_051',
            'kind': 'icon',
            'thumb_file': '051_thumb.webp',
            'full_file': '051.webp',
            'title': 'Rocket',
            'sha256_b64': 'abc',
            'size_bytes': 4096,
          },
          {
            'id': 'wp_beach',
            'kind': 'wallpaper',
            'thumb_file': 'beach_thumb.webp',
            'full_file': 'beach.webp',
          },
        ],
      });

      expect(m.items.length, 2);
      expect(m.icons.length, 1);
      expect(m.wallpapers.length, 1);
      expect(m.icons.first.id, 'icon_051');
      expect(m.icons.first.title, 'Rocket');
      expect(m.icons.first.sha256B64, 'abc');
      expect(m.icons.first.sizeBytes, 4096);
      expect(m.wallpapers.first.fullFile, 'beach.webp');
    });

    test('drops items missing id or kind', () {
      final m = RemoteCosmeticsManifest.fromJson({
        'schema_version': 1,
        'items': [
          {'id': '', 'kind': 'icon', 'thumb_file': 't', 'full_file': 'f'},
          {'id': 'x', 'kind': '', 'thumb_file': 't', 'full_file': 'f'},
          {'id': 'ok', 'kind': 'icon', 'thumb_file': 't', 'full_file': 'f'},
        ],
      });
      expect(m.items.length, 1);
      expect(m.items.first.id, 'ok');
    });

    test('tolerates a missing items list', () {
      final m = RemoteCosmeticsManifest.fromJson({'schema_version': 1});
      expect(m.items, isEmpty);
      expect(m.icons, isEmpty);
      expect(m.wallpapers, isEmpty);
    });

    test('empty constant has no items', () {
      expect(RemoteCosmeticsManifest.empty.items, isEmpty);
    });
  });
}
