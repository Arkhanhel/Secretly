// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// П12 (разбор медиа 15.11.2026): скорость ролика в просмотрщике.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/media_viewer.dart';

void main() {
  test('скорость по кругу и подпись', () {
    expect(nextVideoPlaybackSpeed(1.0), 1.5);
    expect(nextVideoPlaybackSpeed(1.5), 2.0);
    expect(nextVideoPlaybackSpeed(2.0), 0.5);
    expect(nextVideoPlaybackSpeed(0.5), 1.0);
    expect(nextVideoPlaybackSpeed(1.25), 1.0, reason: 'чужая — к обычной');
    expect(videoPlaybackSpeedLabel(1.0), '1×');
    expect(videoPlaybackSpeedLabel(1.5), '1.5×');
  });
}
