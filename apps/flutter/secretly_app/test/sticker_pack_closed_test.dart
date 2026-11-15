// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ЗАКРЫТЫЕ НАБОРЫ СТИКЕРОВ (docs/TZ_STICKER_PACKS_2026-11-14.md).
//
// Проверяется то, что обязано не сломаться у живых людей: старые сообщения
// читаются как открытые, старые сборки прячут отказ автора, режим не
// сбрасывается при добавлении стикера, флаг сверяется с сервером побайтово.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/stickers/sticker_flags.dart';
import 'package:secretly_app/stickers/sticker_pack_lock.dart';
import 'package:secretly_app/stickers/sticker_share_mode.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/sync/sticker_pack_protocol.dart';
import 'package:secretly_app/ui/desktop/chat/sticker_pack_dialog.dart';

StickerEventV1 _event({String? packAccess}) => StickerEventV1(
  eventId: 'e1',
  packId: 'user:author:cats',
  packVersion: 1,
  stickerId: 's1',
  packTitle: 'Котики',
  packStickerCount: 12,
  packOriginPid: 'author',
  packAccess: packAccess,
);

Map<String, dynamic> _roundTrip(E2eEventV1 e) =>
    jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 40, 40, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('поле режима в сообщении-стикере', () {
    test('закрытый набор доезжает как closed', () {
      final json = _roundTrip(
        _event(packAccess: StickerEventV1.packAccessClosed),
      );
      expect(json['pack_access'], 'closed');
      final ev = E2eEventV1.fromJson(json) as StickerEventV1;
      expect(ev.packClosed, isTrue);
    });

    test('🔴 сообщение старой сборки (поля нет) = открытый набор', () {
      final json = _roundTrip(_event());
      expect(json.containsKey('pack_access'), isFalse);
      final ev = E2eEventV1.fromJson(json) as StickerEventV1;
      expect(ev.packClosed, isFalse);
    });

    test('незнакомое значение не считается закрытым и не роняет разбор', () {
      final json = _roundTrip(_event())..['pack_access'] = 'public-v9';
      final ev = E2eEventV1.fromJson(json) as StickerEventV1;
      expect(ev.packClosed, isFalse);
    });
  });

  group('отказ автора «набор закрыт»', () {
    final denied = StickerPackDenied(
      requestId: 'r1',
      packId: 'user:author:cats',
      packTitle: 'Котики',
      totalCount: 12,
      previews: [
        StickerPackLockedPreview(
          stickerId: 's2',
          previewPngB64: base64Encode(_png(24, 24)),
        ),
      ],
    );

    test('переживает провод', () {
      final text = encodeStickerPackDenied(denied);
      expect(isStickerPackCommand(text), isTrue);
      final back = parseStickerPackDenied(text)!;
      expect(back.packId, 'user:author:cats');
      expect(back.totalCount, 12);
      expect(back.previews.single.stickerId, 's2');
    });

    test('🔴 старые сборки прячут отказ, а не показывают его текстом', () {
      // Выпущенные сборки не знают этого префикса. Если бы они не считали его
      // служебным, человек увидел бы в чате строку base64.
      expect(
        isHiddenMessageControlText(encodeStickerPackDenied(denied)),
        isTrue,
      );
    });

    test('разбор старой порции не принимает отказ за набор', () {
      expect(parseStickerPackChunk(encodeStickerPackDenied(denied)), isNull);
      expect(parseStickerPackRequest(encodeStickerPackDenied(denied)), isNull);
    });

    test('превью больше предела отбрасываются', () {
      final many = StickerPackDenied(
        requestId: 'r',
        packId: 'p',
        packTitle: '',
        totalCount: 100,
        previews: [
          for (var i = 0; i < 50; i++)
            StickerPackLockedPreview(stickerId: 's$i', previewPngB64: 'AA=='),
        ],
      );
      final back = parseStickerPackDenied(encodeStickerPackDenied(many))!;
      expect(back.previews.length, kStickerPackLockedPreviewMax);
    });
  });

  group('решение автора и превью', () {
    test('🔴 закрытый набор не отдаётся, открытый — как раньше', () {
      expect(stickerPackServesPeers(StickerShareMode.personal), isFalse);
      expect(stickerPackServesPeers(StickerShareMode.sentOnly), isTrue);
    });

    test('превью крошечное: стикер из него не собрать', () {
      final preview = buildLockedStickerPreview(_png(512, 384))!;
      final decoded = img.decodePng(preview)!;
      expect(decoded.width, kStickerLockedPreviewPx);
      expect(decoded.height, lessThanOrEqualTo(kStickerLockedPreviewPx));
      expect(preview.length, lessThan(8 * 1024));
    });

    test('битый файл — пустая клетка, а не сбой', () {
      expect(buildLockedStickerPreview(Uint8List.fromList([1, 2, 3])), isNull);
      expect(buildLockedStickerPreview(Uint8List(0)), isNull);
    });

    test('набор знает, что он закрыт', () {
      const closed = SecretlyStickerPack(
        id: 'user:me:a',
        version: 1,
        title: 't',
        iconStickerId: 's',
        stickers: [],
        shareMode: StickerShareMode.personal,
      );
      const open = SecretlyStickerPack(
        id: 'user:me:b',
        version: 1,
        title: 't',
        iconStickerId: 's',
        stickers: [],
      );
      expect(closed.isClosed, isTrue);
      expect(open.isClosed, isFalse);
    });
  });

  group('база', () {
    test('🔴 новый стикер в закрытом наборе НЕ открывает его', () async {
      // Сводка набора пишется через REPLACE: всё неперечисленное получает
      // умолчание столбца. До правки каждый добавленный стикер молча делал
      // закрытый набор открытым.
      final db = await AppDb.openForTesting();
      try {
        Future<void> upsert(int count) => db.upsertStickerPackSummary(
          packId: 'user:p1:a',
          packVersion: 1,
          title: 'Мои',
          iconStickerId: 's1',
          stickerCount: count,
          updatedAtMs: 1000 + count,
        );
        await upsert(1);
        await db.stickerPackSetShareMode(
          packId: 'user:p1:a',
          packVersion: 1,
          mode: StickerShareMode.personal,
        );
        await upsert(2);
        expect(
          await db.stickerPackShareMode(packId: 'user:p1:a', packVersion: 1),
          StickerShareMode.personal,
        );
        final rows = await db.listStickerCatalogPacks();
        expect(rows.single.shareMode, StickerShareMode.personal);
        expect(rows.single.stickerCount, 2);
      } finally {
        await db.close();
      }
    });
  });

  group('флаг в /v1/config', () {
    test('🔴 подписываемое сообщение совпадает с сервером побайтово', () {
      // Та же строка — в Rust-тесте stickers_signing_message_is_byte_stable.
      expect(
        stickersSigningMessage(
          packAccessPercent: 10,
          publicPublishPercent: 0,
          publicSearchEnabled: false,
          issuedAtMs: 1760000000123,
        ),
        'secretly-stickers-v1|10|0|false|1760000000123',
      );
    });

    test('непроверенный блок — всё выключено', () {
      final cfg = <String, dynamic>{
        'stickers': {'pack_access_percent': 100},
      };
      expect(
        StickerFlags.fromConfigResponse(cfg, verified: false),
        StickerFlags.defaults,
      );
      expect(
        StickerFlags.fromConfigResponse(
          cfg,
          verified: true,
        ).packAccessFor('d1'),
        isTrue,
      );
    });

    test('доля зажимается и детерминирована, пустой id — не в доле', () {
      final f = StickerFlags.fromConfigResponse({
        'stickers': {'pack_access_percent': 250},
      }, verified: true);
      expect(f.packAccessPercent, 100);
      expect(f.packAccessFor(''), isFalse);
      expect(const StickerFlags().packAccessFor('d1'), isFalse);
      const half = StickerFlags(packAccessPercent: 50);
      final ids = [for (var i = 0; i < 400; i++) 'device-$i'];
      final first = ids.map(half.packAccessFor).toList();
      expect(ids.map(half.packAccessFor).toList(), first);
      final inside = first.where((x) => x).length;
      expect(inside, inInclusiveRange(140, 260));
      // Расширение доли не выключает уже включённых.
      const more = StickerFlags(packAccessPercent: 80);
      for (var i = 0; i < ids.length; i++) {
        if (first[i]) expect(more.packAccessFor(ids[i]), isTrue);
      }
    });
  });

  group('окно набора на ПК', () {
    Widget host(DesktopStickerPackView view, {void Function()? onSend}) {
      return MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DesktopStickerPackDialog(
            changed: const Stream<void>.empty(),
            snapshot: () => view,
            onInstall: () async {},
            onSend: (_) async => onSend?.call(),
          ),
        ),
      );
    }

    const sticker = SecretlyStickerDescriptor(
      packId: 'user:author:cats',
      packVersion: 1,
      stickerId: 's1',
      assetPath: '',
      format: SecretlyStickerFormat.png,
      animated: false,
      emojiHint: '🙂',
      label: 's1',
      keywords: <String>[],
      assetSource: SecretlyStickerAssetSource.missing,
    );

    testWidgets('закрытый набор: замок вместо «Добавить», отправки нет', (
      t,
    ) async {
      var sent = 0;
      await t.pumpWidget(
        host(
          DesktopStickerPackView(
            title: 'Котики',
            total: 12,
            stickers: const [sticker],
            availability: DesktopStickerPackAvailability.locked,
            lockedPreviews: [_png(24, 24)],
          ),
          onSend: () => sent++,
        ),
      );
      expect(
        find.text('Автор не разрешил добавлять этот набор'),
        findsOneWidget,
      );
      expect(find.textContaining('Закрытый набор'), findsOneWidget);
      expect(find.textContaining('Добавить'), findsNothing);
      await t.tap(find.byType(GridView).first, warnIfMissed: false);
      await t.pump();
      expect(sent, 0);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    });
  });
}
