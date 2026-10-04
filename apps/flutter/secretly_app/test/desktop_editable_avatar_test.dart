// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 «СМЕНИТЬ / УДАЛИТЬ ФОТО» — КАК В TELEGRAM (29.09.2026).
//
// Жалоба владельца: «нет кнопки изменить / удалить фото профиля группы и
// своего профиля». Щелчок по своему портрету открывал только просмотр, у
// группы фото менялось лишь в окне «Изменить группу», а снимок уходил без
// кадрирования — общий сеттер брал центральный квадрат, и голова на
// вертикальном фото уезжала за край.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/details/avatar_crop_dialog.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/desktop/primitives/editable_avatar.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('кадр', () {
    test('без масштаба — квадрат по короткой стороне, по центру', () {
      final s = DesktopAvatarCropState(imageWidth: 1200, imageHeight: 1600);
      final r = s.sourceRect();
      expect(r.width, closeTo(1200, 0.01));
      expect(r.height, closeTo(1200, 0.01));
      expect(r.center, const Offset(600, 800));
    });

    test('рамка не выходит за снимок ни при каком сдвиге', () {
      final s = DesktopAvatarCropState(imageWidth: 1200, imageHeight: 1600);
      s.panBy(const Offset(-5000, 5000));
      var r = s.sourceRect();
      expect(r.left, greaterThanOrEqualTo(-0.01));
      expect(r.bottom, lessThanOrEqualTo(1600.01));
      s.setZoom(3);
      s.panBy(const Offset(9000, -9000));
      r = s.sourceRect();
      expect(r.width, closeTo(400, 0.01), reason: 'в 3 раза ближе');
      expect(r.left, greaterThanOrEqualTo(-0.01));
      expect(r.top, greaterThanOrEqualTo(-0.01));
      expect(r.right, lessThanOrEqualTo(1200.01));
    });

    test('масштаб зажат в 1…4', () {
      final s = DesktopAvatarCropState(imageWidth: 800, imageHeight: 800);
      s.setZoom(0.2);
      expect(s.zoom, DesktopAvatarCropState.minZoom);
      s.setZoom(40);
      expect(s.zoom, DesktopAvatarCropState.maxZoom);
    });

    // 🔴 Снимок на 48 Мп читался в полном размере — почти 200 МБ ради
    // портрета 512×512.
    test('большой снимок читается уменьшенным, маленький — как есть', () {
      final camera = desktopAvatarDecodeSize(8000, 6000);
      expect(camera.width, (8000 * 2048 / 6000).round(), reason: 'короткая — 2048');
      expect(camera.height, isNull, reason: 'пропорции держит декодер');
      final panorama = desktopAvatarDecodeSize(12000, 2000);
      expect(panorama.width, 4096, reason: 'длинная — не больше 4096');
      final small = desktopAvatarDecodeSize(1200, 1600);
      expect((small.width, small.height), (null, null));
    });

    // 🔴 Ответ окна приходит в начале его ухода: снимок отпускался сразу, а
    // гаснущее окно ещё рисовало его.
    testWidgets('окно гаснет и рисует снимок, отпущенный после ответа, — своей копией', (
      t,
    ) async {
      late Uint8List png;
      await t.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(
          const Rect.fromLTWH(0, 0, 300, 200),
          Paint()..color = const Color(0xFF3366CC),
        );
        final img = await rec.endRecording().toImage(300, 200);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        png = data!.buffer.asUint8List();
      });
      Future<Uint8List?>? result;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => result = showDesktopAvatarCropDialog(
                ctx,
                bytes: png,
                round: true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      // Чтение снимка — настоящая работа движка.
      for (var i = 0; i < 20 && find.text(l10n.desktopApply).evaluate().isEmpty; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 20));
      }
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.desktopApply));
      await t.pump();
      // Портрет считан и снимок отпущен, пока окно ещё гаснет.
      Uint8List? out;
      await t.runAsync(() async => out = await result);
      expect(out, isNotNull);
      // Гаснущее окно перерисовывается (сменился размер окна, тема) — и
      // рисует снимок снова.
      for (final e in find.byType(CustomPaint).evaluate()) {
        e.renderObject!.markNeedsPaint();
      }
      await t.pump();
      expect(t.takeException(), isNull);
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopApply), findsNothing);
    });

    testWidgets('на выходе — квадрат 512 в PNG', (t) async {
      await t.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(
          const Rect.fromLTWH(0, 0, 300, 200),
          Paint()..color = const Color(0xFF3366CC),
        );
        final img = await rec.endRecording().toImage(300, 200);
        final png = await renderDesktopAvatarCrop(
          img,
          const Rect.fromLTWH(50, 0, 200, 200),
        );
        img.dispose();
        expect(png, isNotNull);
        final codec = await ui.instantiateImageCodec(png!);
        final frame = (await codec.getNextFrame()).image;
        expect(frame.width, kDesktopAvatarCropSide);
        expect(frame.height, kDesktopAvatarCropSide);
        frame.dispose();
      });
    });
  });

  group('портрет', () {
    Widget editable({
      VoidCallback? onChoose,
      VoidCallback? onOpen,
      VoidCallback? onRemove,
      String? hint,
    }) => DesktopEditableAvatar(
      size: 88,
      avatar: const Avatar(name: 'Ада', size: 88),
      onChoose: onChoose ?? () {},
      onOpen: onOpen,
      onRemove: onRemove,
      removeUnavailableHint: hint,
    );

    testWidgets('наведение показывает камеру и подпись', (t) async {
      await t.pumpWidget(_host(editable()));
      final label = find.text(l10n.desktopProfileChangePhoto);
      double opacity() => t
          .widget<AnimatedOpacity>(
            find.ancestor(of: label, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), 0);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(find.byType(Avatar)));
      await t.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('щелчок — меню: выбрать, открыть, удалить', (t) async {
      var chose = 0, opened = 0, removed = 0;
      await t.pumpWidget(
        _host(
          editable(
            onChoose: () => chose++,
            onOpen: () => opened++,
            onRemove: () => removed++,
          ),
        ),
      );
      await t.tap(find.byType(Avatar));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopRoomEditPhotoChoose), findsOneWidget);
      expect(find.text(l10n.desktopAvatarOpen), findsOneWidget);
      expect(find.text(l10n.desktopRoomEditPhotoRemove), findsOneWidget);
      await t.tap(find.text(l10n.desktopRoomEditPhotoRemove));
      await t.pumpAndSettle();
      expect(removed, 1);
      expect((chose, opened), (0, 0));
    });

    testWidgets('фото с телефона: пункт удаления неактивен с подсказкой', (
      t,
    ) async {
      await t.pumpWidget(
        _host(editable(onOpen: () {}, hint: l10n.desktopAvatarRemoveOnPhone)),
      );
      await t.tap(find.byType(Avatar));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopRoomEditPhotoRemove), findsNothing);
      expect(find.text(l10n.desktopAvatarRemoveOnPhone), findsOneWidget);
    });

    testWidgets('камера в углу — сразу выбор файла', (t) async {
      var chose = 0;
      await t.pumpWidget(_host(editable(onChoose: () => chose++)));
      await t.tap(find.byTooltip(l10n.desktopProfileChangePhoto));
      await t.pumpAndSettle();
      expect(chose, 1);
    });
  });

  group('🔴 подключено', () {
    test('свой профиль: портрет с меню, кадр, подтверждение удаления', () {
      final src = File(
        'lib/ui/desktop/chat/details/self_profile_view.dart',
      ).readAsStringSync();
      expect(src.contains('avatar: DesktopEditableAvatar('), isTrue);
      expect(src.contains('showDesktopAvatarCropDialog('), isTrue);
      expect(src.contains('_confirmRemoveAvatar()'), isTrue);
      expect(src.contains('l10n.desktopAvatarRemoveOnPhone'), isTrue);
    });

    test('группа: портрет с меню только у того, кто меняет данные', () {
      final src = File(
        'lib/ui/desktop/chat/details/room_details_view.dart',
      ).readAsStringSync();
      expect(src.contains('avatar: _canEditPhoto'), isTrue);
      expect(
        src.contains(
          '!isDemoRoomId(_groupId) && (_policy?.canChangeGroupInfo ?? false)',
        ),
        isTrue,
      );
      expect(src.contains('setRoomAvatarFromImageBytes('), isTrue);
      expect(src.contains('removeRoomAvatar(groupId: _groupId)'), isTrue);
      expect(src.contains('round: false'), isTrue);
    });

    test('окно «Изменить группу» тоже кадрирует', () {
      final src = File(
        'lib/ui/desktop/chat/details/room_manage_dialogs.dart',
      ).readAsStringSync();
      expect(src.contains('showDesktopAvatarCropDialog('), isTrue);
    });
  });
}
