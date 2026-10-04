// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ЗВУК ПРОВЕРОК В НАСТРОЙКАХ ЗВОНКОВ: уровень микрофона, проверочный сигнал
/// динамиков, обёртка WAV.
///
/// Всё здесь — чистые функции над байтами PCM 16 бит, моно, little-endian:
/// их проверяют тесты без звуковой карты, микрофона и платформы.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Частота всего звука проверок.
///
/// 48 кГц — родная частота почти всех микрофонов и звуковых карт. Windows
/// читает микрофон через Media Foundation (пакет `record`), и просить у неё
/// другую частоту значит заставлять пересчитывать; голосовые сообщения ПК
/// пишутся на тех же 48 кГц и работают на обеих системах.
const int kDesktopCheckSampleRate = 48000;

/// Пик фрагмента PCM 16 бит, 0…1. Пустой или битый фрагмент — тишина.
double pcm16Peak(Uint8List bytes) {
  final samples = bytes.length ~/ 2;
  if (samples == 0) return 0;
  final data = ByteData.sublistView(bytes, 0, samples * 2);
  var peak = 0;
  for (var i = 0; i < samples; i++) {
    final v = data.getInt16(i * 2, Endian.little).abs();
    if (v > peak) peak = v;
  }
  return math.min(1.0, peak / 32767.0);
}

/// Пик → положение полоски индикатора, 0…1.
///
/// 🔴 ШКАЛА В ДЕЦИБЕЛАХ, А НЕ ЛИНЕЙНАЯ. Обычная речь у микрофона — это
/// −30…−20 дБ, то есть 3–10 % от предела. В линейной шкале полоска от голоса
/// едва шевелилась бы, и человек решил бы, что микрофон не работает, — ровно
/// то, что индикатор должен опровергать. От −60 дБ (тишина комнаты) до 0.
double levelFromPeak(double peak, {double floorDb = -60}) {
  if (!(peak > 0)) return 0;
  final db = 20 * math.log(peak) / math.ln10;
  if (db <= floorDb) return 0;
  if (db >= 0) return 1;
  return (db - floorDb) / -floorDb;
}

/// Сглаживание индикатора: вверх — сразу, вниз — плавно, как стрелка
/// прибора. Иначе полоска дрожала бы на каждом слоге и читалась хуже.
double smoothLevel(double previous, double next, {double release = 0.8}) {
  if (!next.isFinite) return 0;
  final n = next.clamp(0.0, 1.0);
  return n >= previous ? n : math.max(n, previous * release);
}

/// Сколько байт PCM 16 бит моно занимает [length] звука.
int pcm16MonoBytes(Duration length, int sampleRate) =>
    (length.inMicroseconds * sampleRate ~/ Duration.microsecondsPerSecond) * 2;

/// Длительность PCM 16 бит моно из [bytes] байт.
Duration pcm16MonoDuration(int bytes, int sampleRate) {
  if (sampleRate <= 0) return Duration.zero;
  return Duration(
    microseconds:
        (bytes ~/ 2) * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}

/// Проверочный сигнал для динамиков: два мягких удара колокольчика, ля и ми
/// (880 и 659 Гц), около полутора секунд.
///
/// Почему колокольчик, а не ровный писк: ровный тон на полной громкости
/// неприятен и в наушниках пугает. Затухающий удар узнаётся сразу, а по
/// второй ноте слышно, что звук не оборвался на полуслове. Пик — половина
/// предела (−6 дБ): проверка громкости не должна оглушать.
Uint8List buildSpeakerTestTone({int sampleRate = kDesktopCheckSampleRate}) {
  const notes = <({double hz, double start})>[
    (hz: 880.0, start: 0.0),
    (hz: 659.25, start: 0.45),
  ];
  const noteLength = 1.0; // секунд
  const total = 1.5; // секунд
  const peak = 0.5;
  const fadeIn = 0.006; // без щелчка на атаке
  const fadeOut = 0.05; // и без щелчка в конце
  final count = (total * sampleRate).round();
  final data = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    var v = 0.0;
    for (final n in notes) {
      final local = t - n.start;
      if (local < 0 || local > noteLength) continue;
      final attack = math.min(1.0, local / fadeIn);
      final decay = math.exp(-local / 0.22);
      // Вторая гармоника тише основной — отсюда «колокольчик», а не свисток.
      final wave = math.sin(2 * math.pi * n.hz * local) +
          0.25 * math.sin(2 * math.pi * 2 * n.hz * local);
      v += wave / 1.25 * attack * decay;
    }
    final tail = math.min(1.0, (total - t) / fadeOut);
    final sample = (v * peak * tail).clamp(-1.0, 1.0);
    data.setInt16(i * 2, (sample * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// PCM 16 бит моно → файл WAV целиком, в памяти.
///
/// Нужен там, где проигрыватель системы принимает только файл, а не голые
/// отсчёты (macOS: `AVAudioPlayer`).
Uint8List pcm16MonoWav(Uint8List pcm, int sampleRate) {
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // размер блока fmt
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // моно
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // байт в секунду
  header.setUint16(32, 2, Endian.little); // байт на отсчёт
  header.setUint16(34, 16, Endian.little); // бит на отсчёт
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  final out = Uint8List(44 + pcm.length);
  out.setAll(0, header.buffer.asUint8List());
  out.setAll(44, pcm);
  return out;
}
