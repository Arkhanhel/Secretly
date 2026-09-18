// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Synthesizes an authentic ringback ("гудки дозвона") tone for outgoing calls.
// Russian/European cadence: 425 Hz, 1 s on, 4 s off (5 s loop). Mono 16-bit PCM
// WAV at 22050 Hz with short fades to avoid clicks. just_audio loops the 5 s clip
// (LoopMode.one), giving the familiar "ту‑у‑у … [pause] … ту‑у‑у".
//   dart run tool/gen_ringback.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;
  const freq = 425.0; // Russian/European ringback frequency
  const toneSec = 1.0; // tone on
  const totalSec = 5.0; // 1 s on + 4 s off
  const amp = 0.6;
  final total = (sampleRate * totalSec).round();
  final toneSamples = (sampleRate * toneSec).round();
  final fade = (sampleRate * 0.008).round(); // 8 ms fade in/out

  final pcm = Int16List(total);
  for (int i = 0; i < total; i++) {
    double v = 0;
    if (i < toneSamples) {
      double env = amp;
      if (i < fade) {
        env *= i / fade;
      } else if (i > toneSamples - fade) {
        env *= (toneSamples - i) / fade;
      }
      v = env * sin(2 * pi * freq * (i / sampleRate));
    }
    pcm[i] = (v * 32767).round().clamp(-32768, 32767).toInt();
  }

  // host-endian == little-endian on macOS, matching WAV's required LE layout.
  final data = pcm.buffer.asUint8List();
  final b = BytesBuilder();
  void str(String x) => b.add(x.codeUnits);
  void u32(int x) => b.add([x & 0xff, (x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff]);
  void u16(int x) => b.add([x & 0xff, (x >> 8) & 0xff]);
  str('RIFF');
  u32(36 + data.length);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits
  str('data');
  u32(data.length);
  b.add(data);

  final out = File('assets/app_ui/sounds/call/ringback_ru.wav');
  out.writeAsBytesSync(b.toBytes());
  stdout.writeln(
      'wrote ${out.path} (${(b.length / 1024).round()} KB, ${totalSec}s @ ${sampleRate}Hz)');
}
