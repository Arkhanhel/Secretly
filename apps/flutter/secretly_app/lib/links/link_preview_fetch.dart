// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/link_preview_v1.dart';

/// Превью ссылки на устройстве ОТПРАВИТЕЛЯ — см. [LinkPreviewV1].
///
/// Разбор страницы повторяет прежний телефонный (`_fetchLinkPreview` в
/// `chat_screen.dart`): те же заголовки, тот же предел в 384 КБ и 5 секунд,
/// те же правила «безопасного адреса». Сверху — две защиты, которых раньше
/// не требовалось.
///
/// 🔴 ЧТО ОТКРЫЛ ОТПРАВИТЕЛЬ, ТО УЕЗЖАЕТ СОБЕСЕДНИКУ. Раньше карточку видел
/// только тот, кто её загрузил. Теперь заголовок, описание и картинка
/// страницы уходят в сообщение — и страница из ВНУТРЕННЕЙ сети отправителя
/// (роутер, рабочий портал) отдала бы её содержимое собеседнику. Поэтому:
///   • адрес проверяется и по буквам, и по тому, КУДА он указывает (DNS):
///     имя, ведущее во внутреннюю сеть, отвергается;
///   • переадресации не выполняются вслепую — каждая следующая ступень
///     проходит ту же проверку.
class LinkPreviewFetcher {
  LinkPreviewFetcher._();

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxHtmlBytes = 384 * 1024;
  static const int _maxImageBytes = 3 * 1024 * 1024;
  static const int _maxRedirects = 3;

  /// Наибольшая ширина миниатюры.
  ///
  /// Карточка на телефоне — около 250 точек при тройной плотности экрана, то
  /// есть до 750 пикселей; 320 выглядели бы мутно. Если 640 не влезают в
  /// предел, пробуем уже, см. [makeThumbnail].
  static const int thumbnailWidth = 640;
  static const List<int> _widthLadder = [thumbnailWidth, 480, 320];

  /// Подмена поиска адресов — для тестов.
  @visibleForTesting
  static Future<List<InternetAddress>> Function(String host)? lookupOverride;

  /// Превью для [uri]: страница, её заголовок и описание, уменьшенная
  /// картинка. `null` — показывать нечего или страницу открывать нельзя.
  static Future<LinkPreviewV1?> fetch(Uri uri, {http.Client? client}) async {
    final own = client == null;
    final c = client ?? http.Client();
    try {
      final page = await _get(c, uri, accept: _htmlAccept);
      if (page == null) return null;
      final contentType = page.contentType;
      if (contentType.isNotEmpty &&
          !contentType.contains('html') &&
          !contentType.contains('xml')) {
        return null;
      }
      final bytes = await _readLimited(page.response.stream, _maxHtmlBytes);
      if (bytes.isEmpty) return null;
      final html = utf8.decode(bytes, allowMalformed: true);
      final parsed = parseHtml(page.finalUri, html, displayUrl: uri);
      if (parsed == null) return null;
      Uint8List? thumbnail;
      final imageUrl = parsed.imageUrl;
      if (imageUrl != null) {
        thumbnail = await _thumbnail(c, imageUrl);
      }
      final preview = LinkPreviewV1(
        url: uri.toString(),
        siteName: parsed.siteName,
        title: parsed.title,
        description: parsed.description,
        thumbnail: thumbnail,
      );
      return preview.isEmpty ? null : preview;
    } catch (_) {
      return null;
    } finally {
      if (own) c.close();
    }
  }

  static const String _htmlAccept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.5';

  /// GET с ручными переадресациями: каждая ступень проверяется заново.
  static Future<_Fetched?> _get(
    http.Client c,
    Uri start, {
    required String accept,
  }) async {
    var uri = start;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (!await isSafeDestination(uri)) return null;
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['accept'] = accept
        ..headers['user-agent'] =
            'Mozilla/5.0 (compatible; SecretlyLinkPreview/1.0)';
      final response = await c.send(request).timeout(_timeout);
      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        final location = response.headers['location'];
        // Тело переадресации не нужно — закрываем поток.
        unawaited(response.stream.drain<void>().catchError((_) {}));
        if (location == null || location.isEmpty) return null;
        uri = uri.resolve(location);
        continue;
      }
      if (status < 200 || status >= 300) {
        unawaited(response.stream.drain<void>().catchError((_) {}));
        return null;
      }
      return _Fetched(
        response: response,
        finalUri: uri,
        contentType: response.headers['content-type']?.toLowerCase() ?? '',
      );
    }
    return null;
  }

  /// Адрес можно открывать: правильный вид и указывает НЕ во внутреннюю сеть.
  static Future<bool> isSafeDestination(Uri uri) async {
    if (!isSafeUri(uri)) return false;
    final host = _normalizedHost(uri);
    // Литеральный адрес уже проверен в [isSafeUri].
    if (InternetAddress.tryParse(host) != null) return true;
    final List<InternetAddress> addresses;
    try {
      addresses = await (lookupOverride ?? InternetAddress.lookup)(
        host,
      ).timeout(_timeout);
    } catch (_) {
      return false;
    }
    if (addresses.isEmpty) return false;
    // Хоть один внутренний адрес — отказ: иначе подмена DNS между проверкой и
    // запросом увела бы запрос туда.
    return addresses.every((a) => !isPrivateAddress(a));
  }

  /// Правила вида адреса — те же, что у телефона.
  static bool isSafeUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.hasPort && uri.port != 80 && uri.port != 443) return false;
    final host = _normalizedHost(uri);
    if (host.isEmpty) return false;
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.lan') ||
        host.endsWith('.home.arpa') ||
        !host.contains('.')) {
      return false;
    }
    final address = InternetAddress.tryParse(host);
    if (address == null) return true;
    return !isPrivateAddress(address);
  }

  static String _normalizedHost(Uri uri) {
    final host = uri.host.trim().toLowerCase();
    return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
  }

  /// Внутренние, служебные и зарезервированные адреса.
  static bool isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }
    final raw = address.rawAddress;
    if (raw.length == 4) {
      final a = raw[0];
      final b = raw[1];
      return a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 192 && b == 0 && raw[2] == 0) ||
          (a == 198 && (b == 18 || b == 19)) ||
          a >= 224;
    }
    if (raw.length == 16) {
      final allZero = raw.every((byte) => byte == 0);
      // IPv4, упакованный в IPv6 (::ffff:10.0.0.1), проверяем как IPv4.
      final mapped =
          raw.sublist(0, 10).every((byte) => byte == 0) &&
          raw[10] == 0xff &&
          raw[11] == 0xff;
      if (mapped) {
        return isPrivateAddress(
          InternetAddress.fromRawAddress(Uint8List.fromList(raw.sublist(12))),
        );
      }
      return allZero ||
          raw[0] == 0xff ||
          (raw[0] & 0xfe) == 0xfc ||
          (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80);
    }
    return true;
  }

  static Future<Uint8List> _readLimited(
    Stream<List<int>> stream,
    int maxBytes,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(_timeout)) {
      final remaining = maxBytes - builder.length;
      if (remaining <= 0) break;
      if (chunk.length <= remaining) {
        builder.add(chunk);
      } else {
        builder.add(chunk.sublist(0, remaining));
        break;
      }
    }
    return builder.takeBytes();
  }

  /// Картинка страницы → миниатюра JPEG в пределах [LinkPreviewV1.maxThumbnailBytes].
  static Future<Uint8List?> _thumbnail(http.Client c, Uri imageUri) async {
    try {
      final fetched = await _get(c, imageUri, accept: 'image/*');
      if (fetched == null) return null;
      final type = fetched.contentType;
      if (type.isNotEmpty && !type.startsWith('image/')) return null;
      final bytes = await _readLimited(fetched.response.stream, _maxImageBytes);
      if (bytes.isEmpty) return null;
      return await compute(makeThumbnail, bytes);
    } catch (_) {
      return null;
    }
  }

  /// Уменьшить картинку и сжать в JPEG, пока не влезет в предел: сперва
  /// качество, потом ширина. Не влезла и так — `null`: карточка обойдётся без
  /// картинки.
  static Uint8List? makeThumbnail(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      // Огромные картинки (бомбы разжатия) не трогаем вовсе.
      if (decoded.width * decoded.height > 40 * 1000 * 1000) return null;
      // Прозрачность JPEG не держит — кладём на белое, как браузер.
      final flat = decoded.hasAlpha
          ? img.compositeImage(
              img.Image(width: decoded.width, height: decoded.height)
                ..clear(img.ColorRgb8(255, 255, 255)),
              decoded,
            )
          : decoded;
      for (final width in _widthLadder) {
        final resized = flat.width > width
            ? img.copyResize(flat, width: width)
            : flat;
        for (final quality in const [72, 58, 44]) {
          final jpeg = Uint8List.fromList(
            img.encodeJpg(resized, quality: quality),
          );
          if (jpeg.length <= LinkPreviewV1.maxThumbnailBytes) return jpeg;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Разбор страницы: заголовок, описание, сайт и адрес картинки.
  static ParsedLinkPage? parseHtml(Uri pageUri, String html, {Uri? displayUrl}) {
    final title = _firstNonEmpty([
      _metaContent(html, const ['og:title']),
      _metaContent(html, const ['twitter:title']),
      _htmlTitle(html),
    ]);
    final description = _firstNonEmpty([
      _metaContent(html, const ['og:description']),
      _metaContent(html, const ['twitter:description']),
      _metaContent(html, const ['description']),
    ]);
    // Сайт — из адреса, а не из `og:site_name`: см. [LinkPreviewV1.displayHost].
    final siteName = LinkPreviewV1.displayHost(displayUrl ?? pageUri);
    final rawImage = _firstNonEmpty([
      _metaContent(html, const ['og:image', 'og:image:url']),
      _metaContent(html, const ['twitter:image', 'twitter:image:src']),
    ]);
    final imageUrl = rawImage == null ? null : _resolveImage(pageUri, rawImage);
    if ((title ?? '').isEmpty &&
        (description ?? '').isEmpty &&
        imageUrl == null) {
      return null;
    }
    return ParsedLinkPage(
      siteName:
          LinkPreviewV1.cleanText(siteName, LinkPreviewV1.maxSiteChars) ??
          prettyHost((displayUrl ?? pageUri).host),
      title: LinkPreviewV1.cleanText(title, LinkPreviewV1.maxTitleChars),
      description: LinkPreviewV1.cleanText(
        description,
        LinkPreviewV1.maxDescriptionChars,
      ),
      imageUrl: imageUrl,
    );
  }

  static String prettyHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized.startsWith('www.') ? normalized.substring(4) : normalized;
  }

  static Uri? _resolveImage(Uri base, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final Uri resolved;
    try {
      resolved = base.resolve(value);
    } catch (_) {
      return null;
    }
    return isSafeUri(resolved) ? resolved : null;
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? _metaContent(String html, List<String> keys) {
    final wanted = keys.map((key) => key.toLowerCase()).toSet();
    final metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
    for (final tag in metaTag.allMatches(html)) {
      final attrs = _tagAttributes(tag.group(0) ?? '');
      final key = (attrs['property'] ?? attrs['name'] ?? attrs['itemprop'])
          ?.toLowerCase();
      if (key == null || !wanted.contains(key)) continue;
      final content = attrs['content'];
      if (content == null || content.trim().isEmpty) continue;
      return _cleanHtmlText(content);
    }
    return null;
  }

  static Map<String, String> _tagAttributes(String tag) {
    final attrs = <String, String>{};
    final attr = RegExp(
      r'''([a-zA-Z_:.-]+)\s*=\s*(['"])(.*?)\2''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in attr.allMatches(tag)) {
      attrs[(match.group(1) ?? '').toLowerCase()] = match.group(3) ?? '';
    }
    return attrs;
  }

  static String? _htmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)<\/title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final title = match?.group(1);
    if (title == null || title.trim().isEmpty) return null;
    return _cleanHtmlText(title);
  }

  static String _cleanHtmlText(String value) {
    final withoutTags = value.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeEntities(withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String _decodeEntities(String value) {
    const named = <String, String>{
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      '#39': "'",
      'nbsp': ' ',
    };
    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
      match,
    ) {
      final entity = match.group(1) ?? '';
      final lower = entity.toLowerCase();
      final namedValue = named[lower];
      if (namedValue != null) return namedValue;
      int? code;
      if (lower.startsWith('#x')) {
        code = int.tryParse(lower.substring(2), radix: 16);
      } else if (lower.startsWith('#')) {
        code = int.tryParse(lower.substring(1));
      }
      if (code == null || code <= 0 || code > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(code);
    });
  }
}

/// Что удалось достать со страницы (до загрузки картинки).
class ParsedLinkPage {
  const ParsedLinkPage({
    required this.siteName,
    this.title,
    this.description,
    this.imageUrl,
  });

  final String siteName;
  final String? title;
  final String? description;
  final Uri? imageUrl;
}

class _Fetched {
  const _Fetched({
    required this.response,
    required this.finalUri,
    required this.contentType,
  });

  final http.StreamedResponse response;
  final Uri finalUri;
  final String contentType;
}
