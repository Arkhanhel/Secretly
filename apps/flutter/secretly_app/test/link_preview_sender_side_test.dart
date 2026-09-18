// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПРЕВЬЮ ССЫЛКИ ГОТОВИТ ОТПРАВИТЕЛЬ — получатель в сеть не ходит.
//
// Решение владельца 16.09.2026 («делать сразу третий вариант»). Раньше
// телефон грузил превью и для ВХОДЯЩИХ сообщений: любой собеседник мог
// прислать ссылку на свой сервер и узнать IP получателя, как только тот
// откроет чат. Теперь карточку готовит устройство отправителя и кладёт её
// в зашифрованное сообщение (`MsgEventV1.linkPreview`).
//
// Здесь закреплено: формат и его совместимость со старыми версиями, строгий
// разбор чужих данных, привязка карточки к ссылке ИЗ ТЕКСТА и защита
// загрузчика отправителя от внутренней сети.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/links/link_preview_fetch.dart';
import 'package:secretly_app/links/link_preview_policy.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

Uint8List _jpeg({int w = 800, int h = 450}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

const _preview = LinkPreviewV1(
  url: 'https://example.com/post',
  siteName: 'example.com',
  title: 'Заголовок',
  description: 'Описание',
);

List<int> _rawMsg(Map<String, Object?> event) => utf8.encode(
  jsonEncode({
    'v': 1,
    'sender_device_id': 'd1',
    'created_at_ms': 1,
    'events': [
      {'type': 'msg', 'event_id': 'e1', ...event},
    ],
  }),
);

void main() {
  group('формат', () {
    test('превью едет внутри сообщения и возвращается целым', () {
      final thumb = LinkPreviewFetcher.makeThumbnail(_jpeg())!;
      final payload = E2ePayloadV1(
        senderDeviceId: 'd1',
        createdAtMs: 1,
        events: [
          MsgEventV1(
            eventId: 'e1',
            text: 'смотри https://example.com/post',
            linkPreview: LinkPreviewV1(
              url: _preview.url,
              siteName: _preview.siteName,
              title: _preview.title,
              description: _preview.description,
              thumbnail: thumb,
            ),
          ),
        ],
      );
      final back = E2ePayloadV1.decode(payload.encode());
      final msg = back.events.single as MsgEventV1;
      expect(msg.linkPreview?.url, 'https://example.com/post');
      expect(msg.linkPreview?.siteName, 'example.com');
      expect(msg.linkPreview?.title, 'Заголовок');
      expect(msg.linkPreview?.description, 'Описание');
      expect(msg.linkPreview?.thumbnail, thumb);
    });

    test('🔴 сообщение с миниатюрой укладывается в предел реле', () {
      // Реле принимает до 256 КБ base64 шифротекста. Самая тяжёлая карточка
      // плюс длинный текст должны помещаться с запасом.
      final worst = LinkPreviewV1(
        url: 'https://example.com/${'a' * (LinkPreviewV1.maxUrlChars - 30)}',
        siteName: 'я' * LinkPreviewV1.maxSiteChars,
        title: 'я' * LinkPreviewV1.maxTitleChars,
        description: 'я' * LinkPreviewV1.maxDescriptionChars,
        thumbnail: Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          ...List<int>.filled(LinkPreviewV1.maxThumbnailBytes - 3, 1),
        ]),
      );
      final bytes = E2ePayloadV1(
        senderDeviceId: 'd1',
        createdAtMs: 1,
        events: [
          MsgEventV1(eventId: 'e1', text: 'я' * 4000, linkPreview: worst),
        ],
      ).encode();
      // Шифротекст чуть длиннее открытого текста; base64 — ещё треть.
      final base64Len = ((bytes.length + 256) * 4 / 3).ceil();
      expect(base64Len, lessThan(256 * 1024 * 0.6));
    });

    test('🔴 старое сообщение без превью разбирается как прежде', () {
      final msg =
          E2ePayloadV1.decode(_rawMsg({'text': 'привет'})).events.single
              as MsgEventV1;
      expect(msg.text, 'привет');
      expect(msg.linkPreview, isNull);
    });

    test('🔴 без превью поле не пишется вовсе — старые версии не заметят', () {
      final json = MsgEventV1(eventId: 'e1', text: 'привет').toJson();
      expect(json.containsKey('link_preview'), isFalse);
    });

    test('🔴 испорченное превью не роняет сообщение', () {
      final notImage = base64Encode(List<int>.filled(100, 7));
      for (final bad in <Object?>[
        'строка',
        42,
        <String, Object?>{'url': 'javascript:alert(1)', 'title': 'x'},
        <String, Object?>{'url': 'https://example.com'}, // показывать нечего
        <String, Object?>{'url': 12, 'title': 'x'},
        <String, Object?>{'url': 'https:///path', 'title': 'x'}, // без сайта
        <String, Object?>{'url': 'https://example.com', 'thumb': notImage},
        <String, Object?>{'url': 'https://example.com', 'thumb': 'A' * 200000},
        <String, Object?>{'url': 'https://example.com', 'thumb': '%%%'},
      ]) {
        final msg =
            E2ePayloadV1.decode(
                  _rawMsg({'text': 'https://example.com', 'link_preview': bad}),
                ).events.single
                as MsgEventV1;
        expect(msg.text, 'https://example.com', reason: '$bad');
        expect(msg.linkPreview, isNull, reason: '$bad');
      }
    });

    test('непригодная миниатюра отбрасывается, а текст карточки остаётся', () {
      final p = LinkPreviewV1.fromJson({
        'url': 'https://example.com',
        'title': 'Заголовок',
        'thumb': base64Encode(List<int>.filled(100, 7)),
      })!;
      expect(p.title, 'Заголовок');
      expect(p.thumbnail, isNull);
    });

    test('🔴 знаки смены направления и управляющие символы вырезаются', () {
      final rlo = String.fromCharCode(0x202E);
      final isolate = String.fromCharCode(0x2066);
      final nul = String.fromCharCode(0);
      final p = LinkPreviewV1.fromJson({
        'url': 'https://example.com',
        'site': 'exa${rlo}mple',
        'title': 'Банк$rloтакой$nul\nзаголовок',
        'desc': '$isolateописание',
      })!;
      expect(p.title, 'Банк такой заголовок');
      expect(p.siteName, 'example.com');
      expect(p.description, 'описание');
    });

    test('🔴 сайт в карточке — из адреса, а не со слов отправителя', () {
      final p = LinkPreviewV1.fromJson({
        'url': 'https://evil.example/login',
        'site': 'Сбербанк Онлайн',
        'title': 'Вход',
      })!;
      expect(p.siteName, 'evil.example');
    });

    test('кириллический домен — буквами, смесь алфавитов — нет', () {
      String host(String url) => LinkPreviewV1.displayHost(Uri.parse(url));
      expect(host('https://пример.рф/путь'), 'пример.рф');
      expect(host('https://WWW.Example.COM./x'), 'example.com');
      expect(host('https://xn--e1afmkfd.xn--p1ai/'), 'xn--e1afmkfd.xn--p1ai');
      // «раураl.com»: р, а, у, а — русские. Выглядит как paypal — и потому
      // не расшифровывается.
      final mixed = host('https://раураl.com/');
      expect(mixed, isNot(contains('р')));
      expect(mixed, contains('%'));
      // «сосо.com»: все буквы имени русские, зона латинская — выглядит как
      // coco.com и тоже не расшифровывается.
      expect(host('https://сосо.com/'), contains('%'));
    });

    test('длинный текст режется по символам, а не посреди эмодзи', () {
      final long = '${'а' * (LinkPreviewV1.maxTitleChars - 1)}😀😀';
      final p = LinkPreviewV1.fromJson({
        'url': 'https://example.com',
        'title': long,
      })!;
      expect(p.title!.runes.length, LinkPreviewV1.maxTitleChars);
      expect(p.title!.endsWith('😀'), isTrue);
    });
  });

  group('привязка к ссылке из текста', () {
    test('🔴 карточка от другой ссылки не принимается', () {
      expect(
        acceptIncomingLinkPreview(_preview, 'вот https://example.com/post'),
        same(_preview),
      );
      expect(
        acceptIncomingLinkPreview(_preview, 'вот https://bank.example/login'),
        isNull,
      );
      expect(acceptIncomingLinkPreview(_preview, 'без ссылок'), isNull);
      expect(acceptIncomingLinkPreview(null, 'https://example.com'), isNull);
    });

    test('ссылка вида www. понимается так же, как у отправителя', () {
      const text = 'зайди на www.example.com/a';
      final target = linkPreviewTargetFor(text);
      expect(target, isNotNull);
      final p = LinkPreviewV1(
        url: target.toString(),
        siteName: 'example.com',
        title: 't',
      );
      expect(acceptIncomingLinkPreview(p, text), same(p));
    });

    test('подходит любая ссылка сообщения, не только первая', () {
      const p = LinkPreviewV1(
        url: 'https://second.example/x',
        siteName: 'second.example',
        title: 't',
      );
      expect(
        acceptIncomingLinkPreview(
          p,
          'https://first.example/a и https://second.example/x',
        ),
        same(p),
      );
    });

    test('отправить можно только превью первой ссылки текущего текста', () {
      expect(
        linkPreviewForOutgoing(_preview, 'https://example.com/post'),
        same(_preview),
      );
      // Ссылку стёрли или заменили, пока превью грузилось.
      expect(
        linkPreviewForOutgoing(_preview, 'https://other.example/x'),
        isNull,
      );
      expect(linkPreviewForOutgoing(_preview, 'без ссылки'), isNull);
      expect(linkPreviewForOutgoing(null, 'https://example.com/post'), isNull);
    });
  });

  group('загрузчик отправителя', () {
    setUp(() {
      LinkPreviewFetcher.lookupOverride = (host) async {
        if (host.endsWith('intranet.example')) {
          return [InternetAddress('10.0.0.5')];
        }
        if (host.endsWith('mixed.example')) {
          return [InternetAddress('93.184.216.34'), InternetAddress('::1')];
        }
        return [InternetAddress('93.184.216.34')];
      };
    });
    tearDown(() => LinkPreviewFetcher.lookupOverride = null);

    test('вид адреса — правила телефона и ещё несколько', () {
      bool ok(String s) => LinkPreviewFetcher.isSafeUri(Uri.parse(s));
      expect(ok('https://example.com/a'), isTrue);
      expect(ok('http://example.com'), isTrue);
      expect(ok('https://example.com:443/'), isTrue);
      expect(ok('ftp://example.com'), isFalse);
      expect(ok('https://localhost/'), isFalse);
      expect(ok('https://printer.local/'), isFalse);
      expect(ok('https://nas.lan/'), isFalse);
      expect(ok('https://router.home.arpa/'), isFalse);
      expect(ok('https://intranet/'), isFalse);
      expect(ok('https://user:pw@example.com/'), isFalse);
      expect(ok('https://example.com:8080/'), isFalse);
      expect(ok('https://192.168.1.1/'), isFalse);
      expect(ok('https://100.64.0.1/'), isFalse);
      expect(ok('https://[::1]/'), isFalse);
      expect(ok('https://8.8.8.8/'), isTrue);
    });

    test('🔴 внутренний адрес под IPv6-обёрткой тоже внутренний', () {
      expect(
        LinkPreviewFetcher.isPrivateAddress(InternetAddress('::ffff:10.1.2.3')),
        isTrue,
      );
      expect(
        LinkPreviewFetcher.isPrivateAddress(InternetAddress('::ffff:8.8.8.8')),
        isFalse,
      );
      expect(
        LinkPreviewFetcher.isPrivateAddress(InternetAddress('fd00::1')),
        isTrue,
      );
      expect(
        LinkPreviewFetcher.isPrivateAddress(
          InternetAddress('2606:4700:4700::1111'),
        ),
        isFalse,
      );
    });

    test('🔴 имя, ведущее во внутреннюю сеть, отвергается по DNS', () async {
      Future<bool> safe(String s) =>
          LinkPreviewFetcher.isSafeDestination(Uri.parse(s));
      expect(await safe('https://wiki.intranet.example/page'), isFalse);
      // Хоть один внутренний адрес среди ответов — тоже отказ.
      expect(await safe('https://www.mixed.example/'), isFalse);
      expect(await safe('https://example.com/page'), isTrue);
    });

    test('имя, которое не находится, не открывается', () async {
      LinkPreviewFetcher.lookupOverride = (host) async =>
          throw const SocketException('no such host');
      expect(
        await LinkPreviewFetcher.isSafeDestination(
          Uri.parse('https://nowhere.example/'),
        ),
        isFalse,
      );
    });

    test('разбор страницы: og, запасной заголовок, сущности, картинка', () {
      final page = Uri.parse('https://www.example.com/a/b');
      final parsed = LinkPreviewFetcher.parseHtml(page, '''
<html><head>
<title>Запасной</title>
<meta property="og:site_name" content="Настоящий Банк">
<meta property="og:title" content="Статья &amp; новости">
<meta name="description" content="Кратко &#8212; о главном">
<meta property="og:image" content="/img/cover.jpg">
</head></html>''')!;
      expect(parsed.title, 'Статья & новости');
      expect(parsed.description, 'Кратко — о главном');
      expect(parsed.siteName, 'example.com');
      expect(
        parsed.imageUrl.toString(),
        'https://www.example.com/img/cover.jpg',
      );

      final fallback = LinkPreviewFetcher.parseHtml(
        page,
        '<title>Только заголовок</title>',
      )!;
      expect(fallback.title, 'Только заголовок');
      expect(LinkPreviewFetcher.parseHtml(page, '<p>пусто</p>'), isNull);
    });

    test('картинка из внутренней сети не берётся', () {
      final parsed = LinkPreviewFetcher.parseHtml(
        Uri.parse('https://example.com/'),
        '<meta property="og:title" content="t">'
        '<meta property="og:image" content="http://192.168.0.1/x.jpg">',
      )!;
      expect(parsed.imageUrl, isNull);
    });

    test('миниатюра — JPEG шириной 320 и не больше предела', () {
      final thumb = LinkPreviewFetcher.makeThumbnail(_jpeg(w: 1600, h: 900))!;
      expect(LinkPreviewV1.looksLikeImage(thumb), isTrue);
      expect(thumb.length, lessThanOrEqualTo(LinkPreviewV1.maxThumbnailBytes));
      expect(img.decodeJpg(thumb)!.width, LinkPreviewFetcher.thumbnailWidth);
      expect(LinkPreviewFetcher.makeThumbnail(Uint8List(10)), isNull);
    });

    test('страница целиком: заголовок, описание и миниатюра', () async {
      final cover = _jpeg();
      final client = MockClient((req) async {
        if (req.url.path == '/post') {
          return http.Response.bytes(
            utf8.encode(
              '<meta property="og:title" content="Пост">'
              '<meta property="og:description" content="Текст">'
              '<meta property="og:image" '
              'content="https://cdn.example.com/c.jpg">',
            ),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        if (req.url.host == 'cdn.example.com') {
          return http.Response.bytes(
            cover,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        return http.Response('', 404);
      });
      final p = await LinkPreviewFetcher.fetch(
        Uri.parse('https://example.com/post'),
        client: client,
      );
      expect(p, isNotNull);
      expect(p!.url, 'https://example.com/post');
      expect(p.title, 'Пост');
      expect(p.description, 'Текст');
      expect(p.thumbnail, isNotNull);
      expect(LinkPreviewV1.looksLikeImage(p.thumbnail!), isTrue);
    });

    test('🔴 переадресация во внутреннюю сеть обрывает загрузку', () async {
      var internalHit = false;
      final client = MockClient((req) async {
        if (req.url.host == 'example.com') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://wiki.intranet.example/secret'},
          );
        }
        internalHit = true;
        return http.Response(
          '<title>Внутренняя страница</title>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final p = await LinkPreviewFetcher.fetch(
        Uri.parse('https://example.com/go'),
        client: client,
      );
      expect(p, isNull);
      expect(internalHit, isFalse, reason: 'запрос ушёл во внутреннюю сеть');
    });

    test('переадресация на обычный сайт выполняется', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/short') {
          return http.Response(
            '',
            301,
            headers: {'location': 'https://example.com/long'},
          );
        }
        return http.Response.bytes(
          utf8.encode('<title>Длинный адрес</title>'),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final p = await LinkPreviewFetcher.fetch(
        Uri.parse('https://example.com/short'),
        client: client,
      );
      // Адрес в превью — тот, что в тексте, а не конечный.
      expect(p?.url, 'https://example.com/short');
      expect(p?.title, 'Длинный адрес');
    });

    test('бесконечная переадресация прекращается', () async {
      var hits = 0;
      final client = MockClient((req) async {
        hits++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://example.com/loop$hits'},
        );
      });
      final p = await LinkPreviewFetcher.fetch(
        Uri.parse('https://example.com/loop'),
        client: client,
      );
      expect(p, isNull);
      expect(hits, lessThanOrEqualTo(4));
    });

    test('не страница — не превью', () async {
      final client = MockClient(
        (req) async => http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(
        await LinkPreviewFetcher.fetch(
          Uri.parse('https://example.com/api'),
          client: client,
        ),
        isNull,
      );
    });
  });
}
