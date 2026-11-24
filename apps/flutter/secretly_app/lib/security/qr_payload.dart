// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import '../app/app_controller.dart'
    show
        buildProfileShareLink,
        kSecretlySupportedAppLinkHosts,
        tryParseProfileShareUri;

/// Содержимое QR-кода «Мой Secretly ID».
///
/// 🔴 ДВА ВИДА, И ОБА ДОЛЖНЫ ЧИТАТЬСЯ ВСЕГДА.
///
/// 1. Старый — простой текст `secretly_id=…\nkeys_base_url=…\ndevice_id=…
///    \nidentity_key_pub_b64=…[\nnickname=…]`. Такие коды уже напечатаны и
///    сохранены у людей, поэтому разбор старого вида не убирается никогда.
///
/// 2. Новый (с 23.11.2026) — ссылка
///    ```text
///    https://links.secretlyapp.com/profile/ID#v=1&secretly_id=ID
///      &device_id=DEV&identity_key_pub_b64=IK&keys_base_url=URL[&nn=НИК]
///    ```
///    (одной строкой). Системная камера (iOS, Android, Google Lens) видит в нём ссылку и
///    открывает приложение (или страницу скачивания). Всё после `#` на сервер
///    не уходит — ключи остаются у телефонов.
///
/// Почему ссылка устроена именно так — ради СТАРЫХ сборок, которые читают её
/// прежним разборщиком (режет по `&`/`\n`, ключ — до первого `=`, ничего не
/// раскодирует):
///  * первым после `#` стоит жертвенный `v=1`: первый кусок у старого
///    разборщика превращается в `https://…#v=1` и пропадает, поэтому
///    `secretly_id` первым стоять не может;
///  * `keys_base_url` и ключ (base64 с `+/=`) пишутся как есть, без
///    `%`-кодирования: старая сборка сравнила бы `https%3A%2F%2F…` со своим
///    сервером и сказала «другой сервер»;
///  * ник лежит под НОВЫМ ключом `nn` (UTF-8 в base64url без `=`): старый
///    разборщик этот ключ не знает и просто не покажет имя — вместо
///    кракозябр, которые он показал бы под `nickname`.
class QrPayload {
  const QrPayload({
    required this.secretlyId,
    required this.deviceId,
    required this.identityKeyPubB64,
    required this.nickname,
    required this.keysBaseUrl,
  });

  final String? secretlyId;
  final String? deviceId;
  final String? identityKeyPubB64;
  final String? nickname;
  final String? keysBaseUrl;

  static const QrPayload _empty = QrPayload(
    secretlyId: null,
    deviceId: null,
    identityKeyPubB64: null,
    nickname: null,
    keysBaseUrl: null,
  );

  /// Есть ли в коде то, чем можно сверить ключ устройства.
  bool get hasDeviceKey =>
      (deviceId ?? '').trim().isNotEmpty &&
      (identityKeyPubB64 ?? '').trim().isNotEmpty;

  /// Ссылка для QR-кода профиля (вид 2, см. описание класса).
  ///
  /// Пустая строка, если нет ID. Без [identityKeyPubB64] ключа устройства
  /// в ссылке нет — как и в старом тексте без ключа.
  static String buildContactLink({
    required String secretlyId,
    required String keysBaseUrl,
    required String deviceId,
    String? identityKeyPubB64,
    String? nickname,
  }) {
    final id = secretlyId.trim();
    final base = buildProfileShareLink(profileId: id);
    if (id.isEmpty || base.isEmpty) return '';
    final ik = (identityKeyPubB64 ?? '').trim();
    final dev = deviceId.trim();
    final keys = keysBaseUrl.trim();
    final nick = (nickname ?? '').replaceAll(RegExp(r'[\r\n]'), ' ').trim();
    final fragment = <String>[
      // Жертвенный первый ключ — см. описание класса.
      'v=1',
      'secretly_id=${_fragmentSafe(id)}',
      if (dev.isNotEmpty) 'device_id=${_fragmentSafe(dev)}',
      if (dev.isNotEmpty && ik.isNotEmpty) 'identity_key_pub_b64=$ik',
      if (keys.isNotEmpty) 'keys_base_url=$keys',
      if (nick.isNotEmpty) 'nn=${_encodeNick(nick)}',
    ];
    return '$base#${fragment.join('&')}';
  }

  static QrPayload tryParse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return _empty;

    final fromLink = _tryParseContactLink(s);
    if (fromLink != null) return fromLink;

    return _fromMap(_parseKeyValues(s));
  }

  /// Ссылка `https://<наш хост>/profile/<id>[#…]` (или `secretly://profile/…`).
  /// `null`, если это не ссылка на профиль Secretly — тогда текст разбирается
  /// старым способом, как и раньше.
  static QrPayload? _tryParseContactLink(String s) {
    final lower = s.toLowerCase();
    if (!lower.startsWith('https://') &&
        !lower.startsWith('http://') &&
        !lower.startsWith('secretly://')) {
      return null;
    }
    final Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'secretly' &&
        !kSecretlySupportedAppLinkHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final pathId = (tryParseProfileShareUri(uri) ?? '').trim();
    if (pathId.isEmpty) return null;

    // Хвост после `#` берётся из исходной строки, а не через
    // `Uri.queryParameters`: там `+` в base64 превратился бы в пробел.
    final hashAt = s.indexOf('#');
    final map = hashAt < 0
        ? const <String, String>{}
        : _parseKeyValues(s.substring(hashAt + 1));
    final fragmentId = _decodeOrSelf((map['secretly_id'] ?? '').trim());
    if (fragmentId.isNotEmpty && fragmentId != pathId) {
      // Путь и хвост называют разных людей — такую ссылку собрали руками.
      // Ключам из хвоста не верим: открываем только профиль из пути.
      return QrPayload(
        secretlyId: pathId,
        deviceId: null,
        identityKeyPubB64: null,
        nickname: null,
        keysBaseUrl: null,
      );
    }
    final parsed = _fromMap(map);
    return QrPayload(
      secretlyId: pathId,
      deviceId: parsed.deviceId == null
          ? null
          : _decodeOrSelf(parsed.deviceId!),
      identityKeyPubB64: parsed.identityKeyPubB64,
      nickname: parsed.nickname,
      keysBaseUrl: parsed.keysBaseUrl,
    );
  }

  /// Прежний разбор: `key=value` через `\n` или `&`, ключ — до первого `=`,
  /// значения как есть (без `%`-раскодирования).
  static Map<String, String> _parseKeyValues(String s) {
    final parts = s.split(RegExp(r'[\n&]+'));
    final map = <String, String>{};
    for (final p in parts) {
      final idx = p.indexOf('=');
      if (idx <= 0) continue;
      final k = p.substring(0, idx).trim().toLowerCase();
      final v = p.substring(idx + 1).trim();
      if (k.isEmpty || v.isEmpty) continue;
      map[k] = v;
    }
    return map;
  }

  static QrPayload _fromMap(Map<String, String> map) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    String? nickname = pick(['nickname', 'name', 'display_name', 'displayname']);
    if (nickname == null) {
      final nn = pick(['nn']);
      if (nn != null) {
        final decoded = (_decodeNick(nn) ?? '').trim();
        nickname = decoded.isEmpty ? null : decoded;
      }
    }

    return QrPayload(
      secretlyId: pick(['secretly_id', 'secretlyid', 'profile_id', 'profileid']),
      deviceId: pick(['device_id', 'deviceid']),
      identityKeyPubB64: pick(['identity_key_pub_b64', 'identitykeypubb64', 'ik_b64']),
      nickname: nickname,
      keysBaseUrl: pick(['keys_base_url', 'keysbaseurl', 'server', 'srv']),
    );
  }

  /// ID и устройство — короткие строки из букв, цифр и `-_.:`; они идут как
  /// есть. Если вдруг попадётся что-то, что разломало бы ссылку (`&`, `#`,
  /// пробел, `%`…), такой символ кодируется — старым сборкам он и раньше
  /// не встречался.
  /// Ник для `nn`: UTF-8 → base64url без `=`. Для кириллицы это втрое
  /// короче `%`-кодировки (2,7 знака на букву против 6), а QR от длины
  /// мельчает; знаки `A–Z a–z 0–9 - _` ссылку не ломают.
  static String _encodeNick(String nick) =>
      base64Url.encode(utf8.encode(nick)).replaceAll('=', '');

  static String? _decodeNick(String value) {
    try {
      final v = value.trim();
      final padded = v.padRight(v.length + (4 - v.length % 4) % 4, '=');
      return utf8.decode(base64Url.decode(padded));
    } catch (_) {
      return null;
    }
  }

  static String _decodeOrSelf(String value) {
    if (!value.contains('%')) return value;
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  static String _fragmentSafe(String value) {
    if (RegExp(r'^[A-Za-z0-9\-_.:~]+$').hasMatch(value)) return value;
    return Uri.encodeComponent(value);
  }
}
