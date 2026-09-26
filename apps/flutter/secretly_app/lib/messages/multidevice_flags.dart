// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Выключатели мультиустройства: дополнительный блок `multidevice`
/// подписанного `/v1/config` (ТЗ 25.09.2026, §2).
///
/// **Все поля с первого дня.** Подписываемое сообщение заморожено: дописать
/// поле потом значит молча сломать подпись у всех выпущенных сборок. Новое
/// поле — только новым блоком `multidevice2`.
///
/// **Отказ.** Блок не пришёл, подпись не сошлась, в сборке нет ключа — всё
/// приводит к [defaults], где каждое поле 0. А 0 везде означает «как без
/// блока»: скачок ратчета — встроенный, доли — никому, дни — не
/// предупреждать и не отвязывать. «Не удалось проверить» — это НЕ «оставить
/// как было»: конфиг, переставший верифицироваться, возвращает всё к нулю.
///
/// **Приём никогда не за флагом.** Флагом включается только ОТПРАВКА
/// нового; сборка, умеющая прочитать новый провод, читает его всегда.
@immutable
class MultideviceFlags {
  const MultideviceFlags({
    this.ratchetJumpMobile = 0,
    this.ratchetJumpDesktop = 0,
    this.ephemeralOnlineOnlyPercent = 0,
    this.companionWarnDays = 0,
    this.companionUnlinkDays = 0,
    this.nackV2Percent = 0,
    this.sendJournalPercent = 0,
    this.deviceCheckPercent = 0,
  });

  /// Состояние «как без блока»: всё, что не удалось проверить, приводит сюда.
  static const MultideviceFlags defaults = MultideviceFlags();

  /// Пределы скачка ратчета (П-3), которые клиент принимает от сервера.
  /// Ниже 200 — старое поведение, выше 25 000 — эталон Signal
  /// (`MAX_FORWARD_JUMPS`) и дальше CPU на телефоне не окупается.
  static const int ratchetJumpMin = 200;
  static const int ratchetJumpMax = 25000;

  /// П-3: насколько номер провода может опережать цепочку. 0 — встроенное.
  final int ratchetJumpMobile;
  final int ratchetJumpDesktop;

  /// П-4: доля отправителей, шлющих «печатает» только устройствам на связи.
  final int ephemeralOnlineOnlyPercent;

  /// П-5: через сколько дней молчания ПК предупреждать и отвязывать. 0 — нет.
  final int companionWarnDays;
  final int companionUnlinkDays;

  /// П-2: доля устройств с новым повтором по заявке «не смог расшифровать».
  /// Проверка адресата (Н-1) действует ВСЕГДА, от этой доли не зависит.
  final int nackV2Percent;

  /// П-2, фаза 2: журнал правок и реакций для досылки.
  final int sendJournalPercent;

  /// П-1: доля отправителей со сверкой росписи устройств.
  final int deviceCheckPercent;

  /// Читает блок из ответа `/v1/config`.
  ///
  /// [verified] обязан быть результатом `verifyMultideviceSignature`: при
  /// false возвращается [defaults].
  static MultideviceFlags fromConfigResponse(
    Map<String, dynamic> configResponse, {
    required bool verified,
  }) {
    if (!verified) return defaults;
    final payload = configResponse['multidevice'];
    if (payload is! Map) return defaults;
    int field(String key) {
      final raw = payload[key];
      return raw is num ? raw.toInt() : 0;
    }

    // Зажимаем и здесь, хотя сервер уже зажал: клиент не обязан верить, что
    // на той стороне ничего не поменяется.
    int percent(String key) => field(key).clamp(0, 100);
    int days(String key) => field(key).clamp(0, 365);
    int jump(String key) => field(key).clamp(0, ratchetJumpMax);
    return MultideviceFlags(
      ratchetJumpMobile: jump('ratchet_jump_mobile'),
      ratchetJumpDesktop: jump('ratchet_jump_desktop'),
      ephemeralOnlineOnlyPercent: percent('ephemeral_online_only_percent'),
      companionWarnDays: days('companion_warn_days'),
      companionUnlinkDays: days('companion_unlink_days'),
      nackV2Percent: percent('nack_v2_percent'),
      sendJournalPercent: percent('send_journal_percent'),
      deviceCheckPercent: percent('device_check_percent'),
    );
  }

  /// Скачок ратчета (П-3) для платформы: 0 → [builtIn]; иначе значение
  /// сервера, зажатое в [ratchetJumpMin]..[ratchetJumpMax].
  int ratchetJumpFor({required bool desktop, required int builtIn}) {
    final value = desktop ? ratchetJumpDesktop : ratchetJumpMobile;
    if (value <= 0) return builtIn;
    return value.clamp(ratchetJumpMin, ratchetJumpMax);
  }

  bool ephemeralOnlineOnlyFor(String deviceId) => inRollout(
    'ephemeral_online_only_percent',
    ephemeralOnlineOnlyPercent,
    deviceId,
  );

  bool nackV2For(String deviceId) =>
      inRollout('nack_v2_percent', nackV2Percent, deviceId);

  bool sendJournalFor(String deviceId) =>
      inRollout('send_journal_percent', sendJournalPercent, deviceId);

  bool deviceCheckFor(String deviceId) =>
      inRollout('device_check_percent', deviceCheckPercent, deviceId);

  /// Попадает ли устройство в долю [percent] поля [field].
  ///
  /// Детерминированно: sha256('multidevice-<поле>-v1|' + device_id), первые
  /// два байта, остаток от деления на 100. Соль своя у каждого поля — одни и
  /// те же 10 % устройств не получают все новинки разом. Пустой device_id —
  /// не в доле, и эта проверка идёт РАНЬШЕ ветки «сто процентов»: иначе
  /// «неизвестно» засчитывалось бы за «включено» (урок `HandshakeFlags`).
  static bool inRollout(String field, int percent, String deviceId) {
    if (percent <= 0) return false;
    final id = deviceId.trim();
    if (id.isEmpty) return false;
    if (percent >= 100) return true;
    return rolloutBucket(field, id) < percent;
  }

  @visibleForTesting
  static int rolloutBucket(String field, String deviceId) {
    final digest = sha256
        .convert(utf8.encode('multidevice-$field-v1|$deviceId'))
        .bytes;
    return ((digest[0] << 8) | digest[1]) % 100;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultideviceFlags &&
          other.ratchetJumpMobile == ratchetJumpMobile &&
          other.ratchetJumpDesktop == ratchetJumpDesktop &&
          other.ephemeralOnlineOnlyPercent == ephemeralOnlineOnlyPercent &&
          other.companionWarnDays == companionWarnDays &&
          other.companionUnlinkDays == companionUnlinkDays &&
          other.nackV2Percent == nackV2Percent &&
          other.sendJournalPercent == sendJournalPercent &&
          other.deviceCheckPercent == deviceCheckPercent;

  @override
  int get hashCode => Object.hash(
    ratchetJumpMobile,
    ratchetJumpDesktop,
    ephemeralOnlineOnlyPercent,
    companionWarnDays,
    companionUnlinkDays,
    nackV2Percent,
    sendJournalPercent,
    deviceCheckPercent,
  );

  /// Для журнала: только числа, ничего личного.
  Map<String, Object> toLogFields() => <String, Object>{
    'jump_m': ratchetJumpMobile,
    'jump_d': ratchetJumpDesktop,
    'eph_pct': ephemeralOnlineOnlyPercent,
    'warn_d': companionWarnDays,
    'unlink_d': companionUnlinkDays,
    'nack2_pct': nackV2Percent,
    'journal_pct': sendJournalPercent,
    'check_pct': deviceCheckPercent,
  };

  @override
  String toString() => 'MultideviceFlags(${toLogFields()})';
}
