// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

/// Превью ссылки, которое готовит ОТПРАВИТЕЛЬ и которое едет внутри
/// зашифрованного сообщения (`MsgEventV1.linkPreview`).
///
/// 🔴 ЗАЧЕМ ТАК, А НЕ «ПОЛУЧАТЕЛЬ СХОДИТ ПО ССЫЛКЕ САМ» (решение владельца
/// 16.09.2026).
///
/// Если превью грузит получатель, любой собеседник может прислать ссылку на
/// свой сервер и узнать IP получателя в тот момент, когда тот откроет чат, —
/// ни на что не нажимая. Для мессенджера про приватность это недопустимо. Так
/// делает Signal: страницу открывает устройство отправителя (он сам выбрал
/// ссылку), а получатель видит готовую карточку и в сеть не ходит.
///
/// 🔴 ДАННЫЕ ПРИШЛИ ОТ ДРУГОГО ЧЕЛОВЕКА — ЗНАЧИТ, НЕ ДОВЕРЯЕМ ИМ.
///
/// [fromJson] не бросает никогда: испорченное превью просто отбрасывается, а
/// сообщение показывается без него. Тексты обрезаются, управляющие символы и
/// знаки смены направления письма вырезаются (иначе заголовок мог бы
/// «перевернуть» соседний текст), миниатюра принимается только ограниченного
/// размера и только с подписью настоящего изображения. Что превью относится
/// к ссылке ИЗ САМОГО СООБЩЕНИЯ, проверяет `acceptIncomingLinkPreview`.
class LinkPreviewV1 {
  const LinkPreviewV1({
    required this.url,
    required this.siteName,
    this.title,
    this.description,
    this.thumbnail,
  });

  static const int maxUrlChars = 2048;
  static const int maxSiteChars = 120;
  static const int maxTitleChars = 300;
  static const int maxDescriptionChars = 600;

  /// Потолок миниатюры. Сообщение целиком ограничено реле (256 КБ в base64),
  /// и миниатюра не должна отнимать у текста его место.
  static const int maxThumbnailBytes = 48 * 1024;

  /// Адрес страницы — ровно та ссылка, что стоит в тексте сообщения.
  final String url;

  /// Сайт, как его показывает карточка, — всегда из самого адреса
  /// ([displayHost]).
  final String siteName;
  final String? title;
  final String? description;

  /// Уменьшенная картинка страницы (JPEG), уже внутри сообщения.
  final Uint8List? thumbnail;

  /// Показывать нечего: ни заголовка, ни описания, ни картинки.
  bool get isEmpty =>
      (title ?? '').isEmpty &&
      (description ?? '').isEmpty &&
      (thumbnail == null || thumbnail!.isEmpty);

  /// Та же карточка без картинки — когда вместе с ней сообщение не влезает.
  LinkPreviewV1 withoutThumbnail() => LinkPreviewV1(
    url: url,
    siteName: siteName,
    title: title,
    description: description,
  );

  Map<String, Object?> toJson() => {
    'url': url,
    'site': siteName,
    if ((title ?? '').isNotEmpty) 'title': title,
    if ((description ?? '').isNotEmpty) 'desc': description,
    if (thumbnail != null && thumbnail!.isNotEmpty)
      'thumb': base64Encode(thumbnail!),
  };

  /// Разбор приехавшего превью. Никогда не бросает; всё сомнительное — `null`.
  static LinkPreviewV1? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = cleanText(raw['url'], maxUrlChars);
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    // Поле `site` отправителя не читаем: см. [displayHost].
    final site = cleanText(displayHost(uri), maxSiteChars) ?? uri.host;
    final title = cleanText(raw['title'], maxTitleChars);
    final description = cleanText(raw['desc'], maxDescriptionChars);
    final thumbnail = _decodeThumbnail(raw['thumb']);
    final preview = LinkPreviewV1(
      url: url,
      siteName: site,
      title: title,
      description: description,
      thumbnail: thumbnail,
    );
    return preview.isEmpty ? null : preview;
  }

  static Uint8List? _decodeThumbnail(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    // Длину проверяем ДО разбора: огромная строка не должна даже
    // раскодироваться.
    if (raw.length > (maxThumbnailBytes * 4) ~/ 3 + 4) return null;
    final Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty || bytes.length > maxThumbnailBytes) return null;
    return looksLikeImage(bytes) ? bytes : null;
  }

  /// Сайт для карточки — из САМОГО адреса.
  ///
  /// 🔴 НЕ СО СТРАНИЦЫ И НЕ ОТ ОТПРАВИТЕЛЯ. И `og:site_name`, и поле `site`
  /// в сообщении пишет тот, кому нужно, чтобы карточке поверили: страница
  /// мошенника назовёт себя банком. Адрес подделать нельзя — по нему
  /// страница и откроется. Так показывает и Signal.
  ///
  /// Национальный домен выводится буквами, только если он целиком
  /// кириллический (`пример.рф`). Смесь алфавитов — «раураl.com» с русскими
  /// «р» и «а» — классическая подделка, и такой адрес остаётся в
  /// закодированном виде: он выглядит странно, и это правильно.
  static String displayHost(Uri uri) {
    var host = uri.host.trim().toLowerCase();
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    if (host.startsWith('www.')) host = host.substring(4);
    if (!host.contains('%')) return host;
    final String decoded;
    try {
      decoded = Uri.decodeComponent(host).toLowerCase();
    } catch (_) {
      return host;
    }
    final cyrillicOnly = decoded.runes.every(
      (r) =>
          r == 0x2E || // .
          r == 0x2D || // -
          (r >= 0x30 && r <= 0x39) || // 0-9
          (r >= 0x0430 && r <= 0x044F) || // а-я
          r == 0x0451, // ё
    );
    return cyrillicOnly ? decoded : host;
  }

  /// Начало файла — подпись JPEG, PNG или WebP.
  static bool looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    final jpeg = b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
    final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final webp =
        b[0] == 0x52 && // R
        b[1] == 0x49 && // I
        b[2] == 0x46 && // F
        b[3] == 0x46 && // F
        b[8] == 0x57 && // W
        b[9] == 0x45 && // E
        b[10] == 0x42 && // B
        b[11] == 0x50; // P
    return jpeg || png || webp;
  }

  /// Управляющие символы и знаки смены направления письма — прочь.
  ///
  /// Знаки направления (U+202A…U+202E, U+2066…U+2069, U+200E/U+200F) в
  /// чужом заголовке могли бы развернуть соседний текст карточки — классический
  /// приём подделки адреса.
  static final RegExp _unsafeChars = RegExp(
    '[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  /// Чистый однострочный текст не длиннее [maxChars] символов; пустой —
  /// `null`.
  static String? cleanText(Object? value, int maxChars) {
    if (value is! String) return null;
    final flat = value
        .replaceAll(_unsafeChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (flat.isEmpty) return null;
    final runes = flat.runes;
    if (runes.length <= maxChars) return flat;
    // По кодовым точкам, а не по UTF-16: обрезка посреди суррогатной пары
    // дала бы битый символ в конце.
    return String.fromCharCodes(runes.take(maxChars)).trimRight();
  }
}
