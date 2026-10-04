// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// WINDOWS: ПРОИГРАТЬ ЗВУК В КОНКРЕТНОЕ УСТРОЙСТВО ВЫВОДА (waveOut, winmm).
///
/// Зачем именно waveOut, а не что-то новее: у него есть документированный
/// способ узнать для каждого устройства идентификатор конечной точки
/// (`DRV_QUERYFUNCTIONINSTANCEID`, раздел «Device Roles for Legacy Windows
/// Multimedia Applications»). Это та же строка, что отдаёт
/// `IMMDevice::GetId` — и тот же идентификатор, который звонки получают у
/// `flutter_webrtc` и хранят в настройках. Значит, проверочный звук идёт
/// ровно туда, куда пойдёт голос собеседника, — без своего кода в раннере и
/// без новых пакетов: функции winmm уже есть в `win32`.
///
/// Здесь только тонкая обёртка над вызовами. Решения (какое устройство, что
/// делать, если не открылось) — в `desktop_audio_output.dart`, их проверяют
/// тесты на любой системе.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win;

import 'desktop_audio_output.dart';
import 'desktop_call_devices.dart' show windowsDefaultAudioEndpointId;

/// `DRV_RESERVED + 17` и `+ 18` из mmddk.h: строка идентификатора конечной
/// точки и её размер в байтах (вместе с завершающим нулём).
const int _kDrvQueryFunctionInstanceId = 0x0800 + 17;
const int _kDrvQueryFunctionInstanceIdSize = 0x0800 + 18;

/// Буфер доигран (`WHDR_DONE`).
const int _kWhdrDone = 0x00000001;

WaveOutApi createWin32WaveOutApi() => _Win32WaveOutApi();

class _Win32WaveOutApi implements WaveOutApi {
  @override
  List<String?> endpointIds() {
    final count = win.waveOutGetNumDevs();
    return <String?>[for (var i = 0; i < count; i++) _endpointId(i)];
  }

  @override
  String? systemDefaultEndpointId() =>
      windowsDefaultAudioEndpointId(capture: false);

  /// Идентификатор конечной точки устройства номер [index]. Номер передаётся
  /// вместо дескриптора — так этот запрос и устроен.
  String? _endpointId(int index) {
    // Размер — `size_t`, то есть 8 байт на 64-битной системе: под меньший
    // буфер драйвер писал бы мимо.
    final size = calloc<Uint64>();
    try {
      final rc = win.waveOutMessage(
        index,
        _kDrvQueryFunctionInstanceIdSize,
        size.address,
        0,
      );
      final bytes = size.value;
      if (rc != win.MMSYSERR_NOERROR || bytes < 2 || bytes > 4096) {
        return null;
      }
      final buffer = calloc<Uint8>(bytes);
      try {
        final rc2 = win.waveOutMessage(
          index,
          _kDrvQueryFunctionInstanceId,
          buffer.address,
          bytes,
        );
        if (rc2 != win.MMSYSERR_NOERROR) return null;
        final id = buffer.cast<Utf16>().toDartString();
        return id.isEmpty ? null : id;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(size);
    }
  }

  @override
  WaveOutVoice? open({
    required int device,
    required Uint8List pcm,
    required int sampleRate,
  }) {
    if (pcm.isEmpty) return null;
    final handle = calloc<IntPtr>();
    final format = calloc<win.WAVEFORMATEX>();
    int hwo;
    try {
      format.ref
        ..wFormatTag = win.WAVE_FORMAT_PCM
        ..nChannels = 1
        ..nSamplesPerSec = sampleRate
        ..wBitsPerSample = 16
        ..nBlockAlign = 2
        ..nAvgBytesPerSec = sampleRate * 2
        ..cbSize = 0;
      final rc = win.waveOutOpen(
        handle,
        device,
        format,
        0,
        0,
        win.CALLBACK_NULL,
      );
      if (rc != win.MMSYSERR_NOERROR) return null;
      hwo = handle.value;
    } finally {
      calloc.free(format);
      calloc.free(handle);
    }
    // Отсчёты — в память, которую не сдвинет сборщик мусора: драйвер читает
    // её всё время проигрывания.
    final data = calloc<Uint8>(pcm.length);
    data.asTypedList(pcm.length).setAll(0, pcm);
    final header = calloc<win.WAVEHDR>();
    header.ref
      ..lpData = data.cast<Utf8>()
      ..dwBufferLength = pcm.length
      ..dwBytesRecorded = 0
      ..dwUser = 0
      ..dwFlags = 0
      ..dwLoops = 0;
    final voice = _Win32Voice(hwo, header, data);
    final headerSize = sizeOf<win.WAVEHDR>();
    if (win.waveOutPrepareHeader(hwo, header, headerSize) !=
        win.MMSYSERR_NOERROR) {
      voice.close(prepared: false);
      return null;
    }
    if (win.waveOutWrite(hwo, header, headerSize) != win.MMSYSERR_NOERROR) {
      voice.close();
      return null;
    }
    return voice;
  }
}

class _Win32Voice implements WaveOutVoice {
  _Win32Voice(this._hwo, this._header, this._data);

  final int _hwo;
  final Pointer<win.WAVEHDR> _header;
  final Pointer<Uint8> _data;
  bool _closed = false;

  @override
  bool get done => _closed || (_header.ref.dwFlags & _kWhdrDone) != 0;

  @override
  void close({bool prepared = true}) {
    if (_closed) return;
    _closed = true;
    // Сначала остановить: снимать подготовку с играющего буфера нельзя.
    win.waveOutReset(_hwo);
    if (prepared) {
      win.waveOutUnprepareHeader(_hwo, _header, sizeOf<win.WAVEHDR>());
    }
    win.waveOutClose(_hwo);
    calloc.free(_header);
    calloc.free(_data);
  }
}
