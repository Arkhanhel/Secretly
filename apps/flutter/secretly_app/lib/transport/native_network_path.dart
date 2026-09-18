// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Единственный на изолят поток событий канала `secretly/network_path`.
///
/// 🔴 N-2 (17.09.2026). У канала событий в Dart бывает только ОДИН обработчик
/// сообщений: каждый `receiveBroadcastStream()` на то же имя при подписке
/// ставит свой (`setMessageHandler`) и заново зовёт `listen` на платформе.
/// Приложение подписывалось первым, через мгновение менеджер звонков — и
/// забирал все события себе. Переподключение релея при смене одной сети на
/// другую той же породы (Wi-Fi → Wi-Fi, F9 от 16.05.2026) в поле не работало
/// ни разу. А отписка любого из двух (`CallManager.dispose`) глушила источник
/// для обоих.
///
/// Здесь поток один и широковещательный: платформа слушается, пока есть хоть
/// один подписчик, и все подписчики получают одно и то же.
///
/// 🔴 ПОЗДНИЙ ПОДПИСЧИК ПОЛУЧАЕТ ПОСЛЕДНИЙ СНИМОК. Платформа шлёт снимок сети
/// только в ответ на `listen`, а его забирает первый подписчик (приложение).
/// Менеджер звонков подписывается позже и без снимка не знал бы текущую сеть:
/// первая смена Wi-Fi → Wi-Fi во время звонка не считалась бы сменой. Когда
/// ушли все, снимок забывается — новый `listen` принесёт свежий.
class NativeNetworkPath {
  NativeNetworkPath._();

  static const EventChannel channel = EventChannel('secretly/network_path');

  static Stream<dynamic>? _source;
  static int _listeners = 0;
  static bool _hasLast = false;
  static Object? _last;

  static Stream<dynamic> get events => Stream<dynamic>.multi((controller) {
        final source = _source ??= channel.receiveBroadcastStream();
        if (_hasLast) controller.add(_last);
        _listeners++;
        final sub = source.listen(
          (event) {
            _last = event;
            _hasLast = true;
            controller.add(event);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = () {
          _listeners--;
          if (_listeners <= 0) {
            _listeners = 0;
            _hasLast = false;
            _last = null;
          }
          return sub.cancel();
        };
      });

  @visibleForTesting
  static void resetForTesting() {
    _source = null;
    _listeners = 0;
    _hasLast = false;
    _last = null;
  }
}
