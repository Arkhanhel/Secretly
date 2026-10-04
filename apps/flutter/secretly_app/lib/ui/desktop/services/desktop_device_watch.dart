// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Замечает, что устройства подключили или отключили, пока открыт раздел
/// настроек звонков.
///
/// 🔴 ЗАЧЕМ (ТЗ §1.4). Список устройств читался один раз при открытии
/// раздела: воткнул гарнитуру — её нет в списке, пока не уйдёшь из раздела и
/// не вернёшься. Человек решал, что гарнитура не определилась.
///
/// 🔴 ОПРОС, А НЕ `navigator.mediaDevices.ondevicechange`. Это ОДНА ячейка на
/// весь процесс, и её уже делят двое: звук звонка
/// (`CallAudioRouteController`, ставит свой обработчик на время звонка и
/// восстанавливает прежний) и `Hardware` из LiveKit (ставит свой при первом
/// созвоне, ни с кем не делясь). Третий хозяин, открывающийся и закрывающийся
/// вместе с разделом, рвал бы им цепочку: закрылся раньше звонка — вернул в
/// ячейку устаревший обработчик. К тому же о камерах эта ячейка не сообщает
/// вовсе: и на macOS, и на Windows её зовёт только модуль звука. Опрос раз в
/// несколько секунд, пока раздел на экране, ни у кого ничего не отнимает.
class DesktopDeviceWatcher {
  DesktopDeviceWatcher({
    required this.onChanged,
    Future<List<MediaDeviceInfo>> Function()? enumerate,
    this.interval = const Duration(seconds: 3),
  }) : _enumerate = enumerate ?? _systemDevices;

  /// Список изменился (кроме самого первого прочтения).
  final VoidCallback onChanged;

  /// Как часто спрашивать. Перечисление — обращение к системе (на Windows
  /// камеры ищутся заново каждый раз), поэтому не чаще раза в пару секунд.
  final Duration interval;

  final Future<List<MediaDeviceInfo>> Function() _enumerate;

  Timer? _timer;
  String? _last;
  bool _busy = false;
  bool _disposed = false;

  static Future<List<MediaDeviceInfo>> _systemDevices() =>
      navigator.mediaDevices.enumerateDevices();

  bool get running => _timer != null;

  /// Начать следить. Первое прочтение запоминается без [onChanged].
  void start() {
    if (_disposed || _timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  /// Перестать следить (раздел ушёл с экрана). Запомненный список остаётся:
  /// вернулись — изменения за время отсутствия тоже будут замечены.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Спросить систему один раз.
  @visibleForTesting
  Future<void> check() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final signature = desktopDeviceSignature(await _enumerate());
      if (_disposed) return;
      final previous = _last;
      _last = signature;
      if (previous != null && previous != signature) onChanged();
    } catch (_) {
      // Система не ответила — спросим в следующий раз.
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}

/// Отпечаток списка устройств: вид, идентификатор и имя каждого, по порядку.
/// Чистая функция.
///
/// Имя входит нарочно: пока нет разрешения, система отдаёт устройства без
/// имён, а после разрешения имена появляются при тех же идентификаторах — и
/// список в настройках должен это показать.
String desktopDeviceSignature(Iterable<MediaDeviceInfo> devices) => [
  for (final d in devices) '${d.kind}|${d.deviceId}|${d.label}',
].join('\n');
