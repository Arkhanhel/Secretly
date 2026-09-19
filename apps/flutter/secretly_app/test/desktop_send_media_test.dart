// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ОКНО ОТПРАВКИ ФАЙЛОВ — КАК В TELEGRAM ДЛЯ macOS.
//
// Указание владельца 16.09.2026: «при перетаскивании файла появляется
// окошко, в которое можно переносить фото сколько угодно, и добавить можно
// комментарий — это важно! Сейчас они без комментария отправляются… все фото
// и видео должны отправляться не в отдельном пузыре, а без него».
//
// Было: брошенный файл уходил сразу, по одному, без подписи; снимки с
// компьютера приходили на телефон ДОКУМЕНТАМИ (с именем файла), а файл,
// брошенный на любое окно, уходил ещё и в переписку под ним.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/ui/desktop/app/desktop_file_match.dart'
    show formatAttachmentSize;
import 'package:secretly_app/ui/desktop/app/desktop_media_send.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/chat/message_media.dart';
import 'package:secretly_app/ui/desktop/chat/outgoing_media.dart';
import 'package:secretly_app/ui/desktop/chat/send_media_dialog.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_dialog.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

OutgoingFile _photo(String name, {double w = 1600, double h = 900}) =>
    OutgoingFile(path: '/nonexistent/$name', name: name, sizeBytes: 1000)
      ..size = ui.Size(w, h)
      ..previewPath = '/nonexistent/$name'
      ..prepared = true;

OutgoingFile _video(String name, {int? ms}) =>
    OutgoingFile(path: '/nonexistent/$name', name: name, sizeBytes: 5000)
      ..size = const ui.Size(1920, 1080)
      ..durationMs = ms
      ..prepared = true;

OutgoingFile _doc(String name) =>
    OutgoingFile(path: '/nonexistent/$name', name: name, sizeBytes: 2048)
      ..prepared = true;

Widget _app(Widget home) =>
    DColors(colors: kDColorsDark, child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,home: home));

void _bigView(WidgetTester t) {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

String _title(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('send-media-title'))).data!;

String _caption(WidgetTester t) => t
    .widget<TextField>(find.byKey(const ValueKey('send-media-caption')))
    .controller!
    .text;

Finder _tile(String path) => find.byKey(ValueKey('send-media-tile-$path'));

final Finder _card = find.byKey(const ValueKey('send-media-card'));

Future<List<Object>> _openDialog(
  WidgetTester t,
  List<OutgoingFile> files, {
  String caption = '',
  bool asFiles = false,
}) async {
  _bigView(t);
  final results = <Object>[];
  await t.pumpWidget(
    _app(
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                results.add(
                  await showSendMediaDialog(
                    ctx,
                    files: files,
                    maxBytes: 0,
                    caption: caption,
                    sendAsFiles: asFiles,
                  ),
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('открыть'));
  await t.pumpAndSettle();
  return results;
}

Future<void> _pasteShortcut(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyV);
  await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
}

/// Событие `desktop_drop` — так же, как его шлёт система.
Future<void> _dropEvent(WidgetTester t, String method, Object? args) =>
    t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );

Future<void> _dropFiles(WidgetTester t, Offset at, List<String> paths) async {
  await _dropEvent(t, 'entered', <double>[at.dx, at.dy]);
  await _dropEvent(t, 'updated', <double>[at.dx, at.dy]);
  await t.pump();
  await _dropEvent(t, 'performOperation', paths);
  await t.pump();
}

Future<void> _until(bool Function() cond, {int tries = 300}) async {
  for (var i = 0; i < tries && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(cond(), isTrue);
}

PendingAttachmentBatchUpload _batch(
  String id,
  List<PendingPhotoUpload> items, {
  List<PendingUploadHints>? hints,
  String convoId = 'peer-1',
}) => PendingAttachmentBatchUpload(
  id: id,
  items: items,
  hints: hints ?? [for (final _ in items) const PendingUploadHints()],
  convoId: convoId,
  targetId: convoId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DesktopClipboardMedia.filesOverride = null;
    DesktopClipboardMedia.imageOverride = null;
    DesktopClipboardMedia.textOverride = null;
    OutgoingMediaPrep.transcodeOverride = null;
    OutgoingMediaPrep.debugPrepDirectory = null;
  });

  group('деление на сообщения — как в Telegram', () {
    List<List<String>> plan(
      List<OutgoingFile> files, {
      bool asFiles = false,
      bool grouped = true,
    }) => [
      for (final g in planOutgoingGroups(
        files,
        sendAsFiles: asFiles,
        grouped: grouped,
      ))
        [for (final f in g.files) '${g.asMedia ? 'm' : 'f'}:${f.name}'],
    ];

    test('снимки и ролики подряд — один альбом', () {
      expect(plan([_photo('a.jpg'), _video('b.mp4'), _photo('c.png')]), [
        ['m:a.jpg', 'm:b.mp4', 'm:c.png'],
      ]);
    });

    test('🔴 больше десяти — альбомами по десять', () {
      final files = [for (var i = 0; i < 12; i++) _photo('p$i.jpg')];
      expect(plan(files).map((g) => g.length), [10, 2]);
    });

    test('документ между снимками разрывает альбом', () {
      expect(plan([_photo('a.jpg'), _doc('b.pdf'), _photo('c.jpg')]), [
        ['m:a.jpg'],
        ['f:b.pdf'],
        ['m:c.jpg'],
      ]);
    });

    test('гифка — всегда отдельно', () {
      final gif = OutgoingFile(path: '/x/g.gif', name: 'g.gif', sizeBytes: 1);
      expect(plan([_photo('a.jpg'), gif, _photo('b.jpg')]), [
        ['m:a.jpg'],
        ['m:g.gif'],
        ['m:b.jpg'],
      ]);
    });

    test('🔴 «Отправить как файлы» — снимки уходят документами', () {
      expect(plan([_photo('a.jpg'), _photo('b.jpg')], asFiles: true), [
        ['f:a.jpg', 'f:b.jpg'],
      ]);
    });

    test('песни — своей стопкой, документы — своей', () {
      final song = OutgoingFile(path: '/x/s.mp3', name: 's.mp3', sizeBytes: 1);
      expect(plan([song, _doc('a.pdf'), _doc('b.zip')]), [
        ['f:s.mp3'],
        ['f:a.pdf', 'f:b.zip'],
      ]);
    });

    test('🔴 подпись внутри — только если сообщение одно', () {
      final two = [_photo('a.jpg'), _photo('b.jpg')];
      final grouped = planOutgoingGroups(
        two,
        sendAsFiles: false,
        grouped: true,
      );
      final loose = planOutgoingGroups(two, sendAsFiles: false, grouped: false);
      expect(grouped, hasLength(1));
      expect(captionTravelsSeparately(grouped), isFalse);
      expect(loose, hasLength(2));
      expect(captionTravelsSeparately(loose), isTrue);
    });

    test('нечитаемый снимок уходит файлом', () {
      final broken = _photo('x.heic')..canBeMedia = false;
      expect(plan([_photo('a.jpg'), broken]), [
        ['m:a.jpg'],
        ['f:x.heic'],
      ]);
    });

    test('заголовок окна', () {
      String t(List<OutgoingFile> f, {bool asFiles = false}) =>
          outgoingDialogTitle(f, sendAsFiles: asFiles);
      expect(t([_photo('a.jpg')]), 'Фото');
      expect(t([_photo('a.jpg'), _photo('b.jpg'), _photo('c.jpg')]), '3 фото');
      expect(t([_video('a.mp4')]), 'Видео');
      expect(t([_photo('a.jpg'), _video('b.mp4')]), '2 медиа');
      expect(t([_doc('a.pdf')]), 'Файл');
      expect(t([_doc('a.pdf'), _doc('b.pdf')]), '2 файла');
      expect(t([for (var i = 0; i < 5; i++) _doc('d$i.pdf')]), '5 файлов');
      expect(t([for (var i = 0; i < 21; i++) _doc('d$i.pdf')]), '21 файл');
      expect(t([_photo('a.jpg'), _photo('b.jpg')], asFiles: true), '2 файла');
      expect(t([_photo('a.jpg'), _doc('b.pdf')]), '2 файла');
      expect(
        t([OutgoingFile(path: '/s.mp3', name: 's.mp3', sizeBytes: 1)]),
        'Аудио',
      );
    });

    test('вид и тип по расширению', () {
      expect(outgoingKindFor('IMG_0001.HEIC'), OutgoingKind.photo);
      expect(desktopMimeForName('IMG_0001.HEIC'), 'image/heic');
      expect(outgoingKindFor('logo.svg'), OutgoingKind.file);
      expect(outgoingKindFor('movie.mkv'), OutgoingKind.file);
      expect(outgoingKindFor('clip.MOV'), OutgoingKind.video);
      expect(outgoingKindFor('song.mp3'), OutgoingKind.audio);
      expect(outgoingKindFor('anim.gif'), OutgoingKind.gif);
      expect(desktopMimeForName('README'), isNull);
    });

    test('🔴 чего нет в своей таблице — из общей (apk больше не octet-stream)', () {
      // 17.09.2026: установочный пакет уходил с компьютера безымянным
      // двоичным файлом, хотя общая таблица его знает.
      expect(
        desktopMimeForName('app-release.apk'),
        'application/vnd.android.package-archive',
      );
      // Своя таблица по-прежнему первой: знакомые типы не поменялись.
      expect(desktopMimeForName('song.m4a'), 'audio/mp4');
      expect(desktopMimeForName('doc.pdf'), 'application/pdf');
    });

    test('пересылка не отдаёт получателю имя файла из кэша', () {
      final src = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(
        'filename: (asMedia || givenName.isEmpty) ? null : givenName,'
            .allMatches(src)
            .length,
        2,
        reason: 'и в комнату, и в личную переписку',
      );
      expect(src.contains('filename: asMedia ? null : name,'), isFalse);
      // Одна таблица типов на весь компьютер.
      expect(
        src.contains('String? _guessMimeForName(String name) => desktopMimeForName(name);'),
        isTrue,
      );
    });
  });

  group('что берётся из броска', () {
    test('🔴 папки, пустые и слишком большие — не берутся, с объяснением', () {
      final dir = Directory.systemTemp.createTempSync('secretly-intake');
      addTearDown(() => dir.deleteSync(recursive: true));
      final folder = Directory('${dir.path}/Фото')..createSync();
      final empty = File('${dir.path}/empty.txt')..writeAsBytesSync(const []);
      final big = File('${dir.path}/big.bin')
        ..writeAsBytesSync(Uint8List(2048));
      final ok = File('${dir.path}/ok.pdf')..writeAsBytesSync(Uint8List(10));
      final intake = intakeOutgoingPaths([
        folder.path,
        empty.path,
        big.path,
        ok.path,
        ok.path,
        '${dir.path}/missing.jpg',
        '  ',
      ], maxBytes: 1024);
      expect(intake.files.map((f) => f.name), ['ok.pdf']);
      expect(intake.files.single.sizeBytes, 10);
      expect(intake.folders, ['Фото']);
      expect(intake.empty, ['empty.txt']);
      expect(intake.tooLarge, ['big.bin']);
      expect(intake.unreadable, ['missing.jpg']);
      final text = intake.rejectionText(maxBytes: 1024 * 1024)!;
      expect(text, startsWith('Папку «Фото» отправить нельзя'));
      expect(text, contains('«big.bin» больше 1 МБ'));
      expect(text, contains('«empty.txt» пустой'));
      expect(text, contains('«missing.jpg» не удалось прочитать'));

      final again = intakeOutgoingPaths(
        [ok.path],
        maxBytes: 0,
        alreadyAdded: {ok.path},
      );
      expect(again.files, isEmpty);
      expect(again.rejectionText(maxBytes: 0), isNull);
    });
  });

  group('подготовка снимков', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('secretly-prep');
      OutgoingMediaPrep.debugPrepDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    File png(String name, int w, int h) => File('${dir.path}/$name')
      ..writeAsBytesSync(img.encodePng(img.Image(width: w, height: h)));

    test('обычный снимок — как есть, с размерами', () async {
      final f = png('a.png', 40, 20);
      final out = OutgoingFile(
        path: f.path,
        name: 'a.png',
        sizeBytes: f.lengthSync(),
      );
      await OutgoingMediaPrep.prepare(out);
      expect(out.prepared, isTrue);
      expect(out.size, const ui.Size(40, 20));
      expect(out.previewPath, f.path);
      expect(out.mediaPath, isNull);
      expect(out.canBeMedia, isTrue);
      expect(out.mediaSendPath, f.path);
      expect(out.mediaSendMime, 'image/png');
    });

    test('🔴 HEIC — перекодируется системой в JPEG', () async {
      final heic = File('${dir.path}/IMG_1.HEIC')
        ..writeAsBytesSync(Uint8List.fromList(List<int>.filled(64, 7)));
      String? asked;
      OutgoingMediaPrep.transcodeOverride = (path, outPath) async {
        asked = path;
        File(outPath).writeAsBytesSync(
          img.encodeJpg(img.Image(width: 30, height: 40)),
        );
        return {'path': outPath, 'width': 30, 'height': 40, 'mime': 'image/jpeg'};
      };
      final out = OutgoingFile(path: heic.path, name: 'IMG_1.HEIC', sizeBytes: 64);
      await OutgoingMediaPrep.prepare(out);
      expect(asked, heic.path);
      expect(out.mediaPath, endsWith('.jpg'));
      expect(out.mediaMime, 'image/jpeg');
      expect(out.size, const ui.Size(30, 40));
      expect(out.previewPath, out.mediaPath);
      expect(out.mediaSendSize, File(out.mediaPath!).lengthSync());
      // «Файлом» уходит исходник — как есть.
      expect(out.path, heic.path);
      expect(out.mime, 'image/heic');
    });

    test('🔴 больше 2560 точек — отдаётся системе на уменьшение', () async {
      final f = png('wide.png', 3000, 10);
      var called = false;
      OutgoingMediaPrep.transcodeOverride = (path, outPath) async {
        called = true;
        return null;
      };
      final out = OutgoingFile(
        path: f.path,
        name: 'wide.png',
        sizeBytes: f.lengthSync(),
      );
      await OutgoingMediaPrep.prepare(out);
      expect(called, isTrue);
      // Система не смогла — уходит как есть, но снимком.
      expect(out.mediaPath, isNull);
      expect(out.canBeMedia, isTrue);
      expect(out.size, const ui.Size(3000, 10));
    });

    test('нечитаемый снимок — файлом, без превью', () async {
      final f = File('${dir.path}/broken.png')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
      OutgoingMediaPrep.transcodeOverride = (path, outPath) async => null;
      final out = OutgoingFile(path: f.path, name: 'broken.png', sizeBytes: 4);
      await OutgoingMediaPrep.prepare(out);
      expect(out.canBeMedia, isFalse);
      expect(out.previewPath, isNull);
    });

    test('картинка из буфера ложится файлом «image.png»', () async {
      final bytes = img.encodePng(img.Image(width: 5, height: 5));
      final staged = await OutgoingMediaPrep.stagePastedImage(bytes);
      expect(staged!.name, 'image.png');
      expect(staged.kind, OutgoingKind.photo);
      expect(File(staged.path).readAsBytesSync(), bytes);
      expect(staged.path, startsWith(dir.path));
    });
  });

  group('буфер обмена', () {
    test('🔴 скопированная ссылка — не файл', () async {
      DesktopClipboardMedia.textOverride = () async =>
          'https://example.com/etc/hosts';
      DesktopClipboardMedia.filesOverride = () async => ['/etc/hosts'];
      expect(await DesktopClipboardMedia.files(), isEmpty);
    });

    test('файлы из Finder берутся, несуществующие — нет', () async {
      final dir = Directory.systemTemp.createTempSync('secretly-clip');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/a.pdf')..writeAsBytesSync([1]);
      DesktopClipboardMedia.textOverride = () async => 'a.pdf';
      DesktopClipboardMedia.filesOverride = () async => [
        f.path,
        '${dir.path}/нет.pdf',
      ];
      expect(await DesktopClipboardMedia.files(), [f.path]);
    });
  });

  group('окно', () {
    testWidgets('🔴 Enter отправляет — с подписью, альбомом, как медиа', (
      t,
    ) async {
      final results = await _openDialog(t, [
        _photo('a.jpg'),
        _photo('b.jpg'),
      ], caption: 'Смотри');
      expect(_title(t), '2 фото');
      expect(_caption(t), 'Смотри');
      expect(_tile('/nonexistent/a.jpg'), findsOneWidget);
      expect(_tile('/nonexistent/b.jpg'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      final r = results.single as SendMediaResult;
      expect(r.caption, 'Смотри');
      expect(r.files.map((f) => f.name), ['a.jpg', 'b.jpg']);
      expect(r.sendAsFiles, isFalse);
      expect(r.grouped, isTrue);
      expect(_card, findsNothing);
    });

    testWidgets('Shift+Enter не отправляет', (t) async {
      final results = await _openDialog(t, [_photo('a.jpg')]);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(results, isEmpty);
      expect(_card, findsOneWidget);
    });

    testWidgets('🔴 Esc закрывает, и подпись возвращается', (t) async {
      final results = await _openDialog(t, [_photo('a.jpg')], caption: 'черновик');
      await t.enterText(
        find.byKey(const ValueKey('send-media-caption')),
        'черновик и ещё',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect((results.single as SendMediaDismissed).caption, 'черновик и ещё');
      expect(_card, findsNothing);
    });

    testWidgets('🔴 Esc через систему ввода macOS (cancelOperation:) — тоже закрывает', (
      t,
    ) async {
      final results = await _openDialog(t, [_photo('a.jpg')], caption: 'набор');
      // Так приходит Esc, пока у поля есть незавершённый набор.
      t.state<EditableTextState>(find.byType(EditableText)).performSelector(
        'cancelOperation:',
      );
      await t.pumpAndSettle();
      expect((results.single as SendMediaDismissed).caption, 'набор');
      expect(_card, findsNothing);
    });

    testWidgets('Esc без фокуса в подписи — тоже закрывает', (t) async {
      final results = await _openDialog(t, [_photo('a.jpg')]);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results.single, isA<SendMediaDismissed>());
    });

    testWidgets('щелчок мимо окна — закрыть, подпись не теряется', (t) async {
      final results = await _openDialog(t, [_photo('a.jpg')], caption: 'текст');
      await t.tapAt(const Offset(20, 20));
      await t.pumpAndSettle();
      expect((results.single as SendMediaDismissed).caption, 'текст');
    });

    testWidgets('«…»: файлами — и обратно; без группировки — по одному', (
      t,
    ) async {
      final results = await _openDialog(t, [
        _photo('a.jpg', w: 1000, h: 1000),
        _photo('b.jpg', w: 1000, h: 1000),
      ]);
      // Квадратные в альбоме — рядом.
      expect(t.getSize(_tile('/nonexistent/a.jpg')).width, lessThan(200));

      Future<void> menu(String item) async {
        await t.tap(find.byIcon(FluentIcons.more_horizontal_24_regular));
        await t.pumpAndSettle();
        await t.tap(find.text(item));
        await t.pumpAndSettle();
      }

      await menu('Отправить как файлы');
      expect(_title(t), '2 файла');
      expect(
        find.byKey(const ValueKey('send-media-file-/nonexistent/a.jpg')),
        findsOneWidget,
      );
      expect(_tile('/nonexistent/a.jpg'), findsNothing);

      await menu('Отправить как медиа');
      expect(_title(t), '2 фото');

      await menu('Не группировать');
      // Каждый снимок — отдельным сообщением, во всю ширину окна: 400
      // минус рамка и поля.
      expect(t.getSize(_tile('/nonexistent/a.jpg')).width, 374);
      expect(t.getSize(_tile('/nonexistent/b.jpg')).width, 374);

      await t.tap(find.byKey(const ValueKey('send-media-send')));
      await t.pumpAndSettle();
      final r = results.single as SendMediaResult;
      expect(r.grouped, isFalse);
      expect(r.sendAsFiles, isFalse);
    });

    testWidgets('«×» убирает файл; убран последний — окно закрыто', (t) async {
      final results = await _openDialog(t, [
        _photo('a.jpg', w: 1000, h: 1000),
        _photo('b.jpg', w: 1000, h: 1000),
      ], caption: 'x');
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: t.getCenter(_tile('/nonexistent/a.jpg')));
      await t.pump();
      final remove = find.byKey(const ValueKey('send-media-remove'));
      await t.tap(remove.hitTestable());
      await t.pumpAndSettle();
      expect(_title(t), 'Фото');
      expect(_tile('/nonexistent/a.jpg'), findsNothing);

      await mouse.moveTo(t.getCenter(_tile('/nonexistent/b.jpg')));
      await t.pump();
      await t.tap(remove.hitTestable());
      await t.pumpAndSettle();
      expect((results.single as SendMediaDismissed).caption, 'x');
    });

    testWidgets('🔴 ⌘V в подписи: файл — в окно, адрес — текстом', (t) async {
      final dir = Directory.systemTemp.createTempSync('secretly-paste');
      addTearDown(() => dir.deleteSync(recursive: true));
      final pdf = File('${dir.path}/отчёт.pdf')
        ..writeAsBytesSync(Uint8List(10));
      DesktopClipboardMedia.textOverride = () async => 'отчёт.pdf';
      DesktopClipboardMedia.filesOverride = () async => [pdf.path];
      DesktopClipboardMedia.imageOverride = () async => null;
      await _openDialog(t, [_photo('a.jpg')]);
      await _pasteShortcut(t);
      await t.pumpAndSettle();
      expect(_title(t), '2 файла');
      expect(find.byKey(ValueKey('send-media-file-${pdf.path}')), findsOneWidget);
      expect(_caption(t), isEmpty);

      DesktopClipboardMedia.textOverride = () async =>
          'https://example.com/etc/hosts';
      DesktopClipboardMedia.filesOverride = () async => ['/etc/hosts'];
      await _pasteShortcut(t);
      await t.pumpAndSettle();
      expect(_title(t), '2 файла');
      expect(_caption(t), 'https://example.com/etc/hosts');
    });
  });

  group('лента и бросок', () {
    late Directory dir;
    late File pdf;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('secretly-drop');
      pdf = File('${dir.path}/отчёт.pdf')..writeAsBytesSync(Uint8List(10));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<List<(SendMediaResult, String?)>> pumpPanel(
      WidgetTester t, {
      List<MessageData> messages = const <MessageData>[],
      void Function(BuildContext context)? onContext,
    }) async {
      _bigView(t);
      final sent = <(SendMediaResult, String?)>[];
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (ctx) {
                onContext?.call(ctx);
                return ChatThreadPanel(
                  header: const ChatHeader(name: 'Пётр'),
                  isDirect: true,
                  messages: messages,
                  attachmentMaxBytes: 1024 * 1024,
                  onSendMedia: (r, {replyToPayloadEventId}) async {
                    sent.add((r, replyToPayloadEventId));
                  },
                );
              },
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      return sent;
    }

    testWidgets('🔴 бросок открывает окно; набранное — в подпись; Esc — обратно', (
      t,
    ) async {
      final sent = await pumpPanel(t);
      final composer = find.byType(TextField).first;
      await t.enterText(composer, 'Привет');
      await _dropFiles(t, const Offset(600, 400), [pdf.path]);
      await t.pumpAndSettle();
      expect(_card, findsOneWidget);
      expect(_title(t), 'Файл');
      expect(_caption(t), 'Привет');

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(_card, findsNothing);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Привет',
      );
      expect(sent, isEmpty);
    });

    testWidgets('🔴 отправка из окна уносит подпись и ответ', (t) async {
      final sent = await pumpPanel(
        t,
        messages: const [
          MessageData(
            id: 'm1',
            payloadId: 'p-1',
            authorName: 'Пётр',
            text: 'Пришли отчёт',
            time: '12:00',
            timestampMs: 1757700000000,
          ),
        ],
      );
      await t.tapAt(
        t.getCenter(
          find.textContaining('Пришли отчёт', findRichText: true).first,
        ),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Ответить'));
      await t.pumpAndSettle();
      expect(find.text('Ответ · Пётр'), findsOneWidget);

      await _dropFiles(t, const Offset(600, 400), [pdf.path]);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('send-media-caption')),
        'Держи',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.single.$1.caption, 'Держи');
      expect(sent.single.$1.files.single.path, pdf.path);
      expect(sent.single.$2, 'p-1');
      // Ответ ушёл вместе с файлом — карточка над полем снята.
      expect(find.text('Ответ · Пётр'), findsNothing);
    });

    testWidgets('🔴 под открытым окном лента файлы не принимает', (t) async {
      late BuildContext host;
      await pumpPanel(t, onContext: (c) => host = c);
      unawaited(
        DesktopDialog.show<void>(
          host,
          title: 'Настройки',
          body: const Text('тело'),
        ),
      );
      await t.pumpAndSettle();
      await _dropFiles(t, const Offset(100, 500), [pdf.path]);
      await t.pumpAndSettle();
      expect(_card, findsNothing);

      Navigator.of(host).pop();
      await t.pumpAndSettle();
      await _dropFiles(t, const Offset(100, 500), [pdf.path]);
      await t.pumpAndSettle();
      expect(_card, findsOneWidget);
    });

    testWidgets('слишком большой файл — окно не открывается, объяснение есть', (
      t,
    ) async {
      final big = File('${dir.path}/big.bin')
        ..writeAsBytesSync(Uint8List(2 * 1024 * 1024));
      await pumpPanel(t);
      await _dropFiles(t, const Offset(600, 400), [big.path]);
      await t.pump();
      expect(_card, findsNothing);
      expect(find.text('«big.bin» больше 1 МБ'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('уходящие файлы в ленте', () {
    test('🔴 заготовки: альбом, подпись, прогресс', () {
      final batch = _batch('b1', [
        PendingPhotoUpload(
          id: 'b1_0',
          filePath: '/x/a.jpg',
          mime: 'image/jpeg',
          caption: 'Отпуск',
          totalBytes: 100,
          mediaGroupId: 'b1',
        ),
        PendingPhotoUpload(
          id: 'b1_1',
          filePath: '/x/b.jpg',
          mime: 'image/jpeg',
          caption: '',
          totalBytes: 100,
          mediaGroupId: 'b1',
        ),
      ], hints: const [
        PendingUploadHints(width: 1000, height: 1000),
        PendingUploadHints(width: 10, height: 20),
      ]);
      batch.items[0].sentBytes = 50;
      final rows = desktopUploadRows(
        [batch],
        selfName: 'Вы',
        timeLabel: (_) => '12:00',
      );
      final row = rows.single;
      expect(row.albumItems, hasLength(2));
      expect(row.text, 'Отпуск');
      expect(row.isSelf, isTrue);
      expect(row.delivery, DeliveryStatus.sending);
      expect(row.isUploading, isTrue);
      expect(row.albumItems![0].attachment!.uploadProgress, 0.5);
      expect(row.albumItems![0].attachment!.filePath, '/x/a.jpg');
      expect(row.albumItems![1].attachment!.width, 10);
      expect(uploadBatchIdOfRow(row.albumItems![1]), 'b1');

      // Отменённый файл не рисуется.
      batch.items[1].canceled = true;
      final after = desktopUploadRows(
        [batch],
        selfName: 'Вы',
        timeLabel: (_) => '12:00',
      ).single;
      expect(after.albumItems, isNull);
      expect(after.id, 'upload:b1_0');
    });

    test('документ — строкой файла с именем; порядок — как поставлены', () {
      final older = _batch('b2', [
        PendingPhotoUpload(
          id: 'b2_0',
          filePath: '/x/tmp123',
          mime: 'application/pdf',
          caption: '',
          totalBytes: 10,
          filename: 'отчёт.pdf',
          asFile: true,
        ),
      ]);
      final newer = _batch('b3', [
        PendingPhotoUpload(
          id: 'b3_0',
          filePath: '/x/c.jpg',
          mime: 'image/jpeg',
          caption: '',
          totalBytes: 10,
        ),
      ]);
      final rows = desktopUploadRows(
        [older, newer],
        selfName: 'Вы',
        timeLabel: (_) => '12:00',
      );
      expect(rows.map((r) => r.id), ['upload:b2_0', 'upload:b3_0']);
      expect(rows.first.attachment!.sentAsFile, isTrue);
      expect(rows.first.attachment!.fileName, 'отчёт.pdf');
      expect(rows.last.attachment!.sentAsFile, isFalse);
      expect(rows.last.attachment!.fileName, isNull);
    });

    testWidgets('🔴 уходящий снимок: кольцо с отменой, без меню', (t) async {
      final batch = _batch('b4', [
        PendingPhotoUpload(
          id: 'b4_0',
          filePath: '/nonexistent/a.jpg',
          mime: 'image/jpeg',
          caption: '',
          totalBytes: 100,
        ),
      ]);
      batch.items[0].sentBytes = 40;
      final row = desktopUploadRows(
        [batch],
        selfName: 'Вы',
        timeLabel: (_) => '12:00',
      ).single;
      final cancelled = <String>[];
      var menus = 0;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 900,
                child: MessageBubble(
                  message: row,
                  onCancelUpload: (m) => cancelled.add(m.id),
                  onMoreActions: (_) => menus++,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      final ring = find.byKey(const ValueKey('media-upload-ring'));
      expect(ring, findsOneWidget);
      await t.tap(ring);
      expect(cancelled, ['upload:b4_0']);
      await t.tapAt(
        t.getCenter(find.byType(DesktopMediaTile)),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pump();
      expect(menus, 0);
    });

    testWidgets('уходящий документ: сколько ушло и кольцо', (t) async {
      final batch = _batch('b5', [
        PendingPhotoUpload(
          id: 'b5_0',
          filePath: '/x/tmp',
          mime: 'application/pdf',
          caption: '',
          totalBytes: 4096,
          filename: 'отчёт.pdf',
          asFile: true,
        ),
      ]);
      batch.items[0].sentBytes = 2048;
      final row = desktopUploadRows(
        [batch],
        selfName: 'Вы',
        timeLabel: (_) => '12:00',
      ).single;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 900, child: MessageBubble(message: row)),
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(DesktopFileRow), findsOneWidget);
      expect(find.byKey(const ValueKey('media-upload-ring')), findsOneWidget);
      expect(
        find.text(
          '${formatAttachmentSize(2048)} / ${formatAttachmentSize(4096)}',
        ),
        findsOneWidget,
      );
      // «Показать в Finder» у уходящего файла нет — показывать ещё нечего.
      expect(find.text('Показать в Finder'), findsNothing);
    });
  });

  group('очередь контроллера', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('secretly-batch-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (_) async {
            return tempDir.path;
          });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('🔴 пачка видна сразу; сбой — в поток ошибок, заготовка снята', () async {
      final controller = AppController();
      final pokes = <String>[];
      final errors = <AttachmentUploadErrorEvent>[];
      final s1 = controller.pendingUploadsChanged.listen(pokes.add);
      final s2 = controller.attachmentUploadErrors.listen(errors.add);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);
      final batch = _batch('q1', [
        PendingPhotoUpload(
          id: 'q1_0',
          filePath: '/nonexistent/a.jpg',
          mime: 'image/jpeg',
          caption: '',
          totalBytes: 1,
        ),
      ]);
      controller.enqueueAttachmentBatchUpload(batch);
      expect(controller.pendingAttachmentBatchUploadsFor('peer-1'), [batch]);
      // Альбомы телефона — отдельно: пачку компьютера они не видят.
      expect(controller.pendingPhotoAlbumUploadsFor('peer-1'), isEmpty);
      await _until(
        () => controller.pendingAttachmentBatchUploadsFor('peer-1').isEmpty,
      );
      await _until(() => errors.isNotEmpty);
      expect(errors.single.convoId, 'peer-1');
      expect(
        describeAttachmentFailure(errors.single.error).code,
        AttachmentFailureCode.fileMissing,
      );
      expect(pokes, contains('peer-1'));
    });

    test('отменённая до своей очереди пачка уходит молча', () async {
      final controller = AppController();
      final errors = <AttachmentUploadErrorEvent>[];
      final sub = controller.attachmentUploadErrors.listen(errors.add);
      addTearDown(sub.cancel);
      PendingPhotoUpload item(String id) => PendingPhotoUpload(
        id: id,
        filePath: '/nonexistent/$id.jpg',
        mime: 'image/jpeg',
        caption: '',
        totalBytes: 1,
      );
      final first = _batch('q2', [item('q2_0')]);
      final second = _batch('q3', [item('q3_0')]);
      controller.enqueueAttachmentBatchUpload(first);
      controller.enqueueAttachmentBatchUpload(second);
      controller.cancelPendingAttachmentBatchUpload('peer-1', 'q3');
      expect(
        controller.pendingAttachmentBatchUploadsFor('peer-1').map((b) => b.id),
        ['q2'],
      );
      expect(second.allCanceled, isTrue);
      await _until(
        () => controller.pendingAttachmentBatchUploadsFor('peer-1').isEmpty,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(errors, hasLength(1));
    });

    test('🔴 самому себе: подпись у первого, имя у документа, ролик с размерами', () async {
      final db = await AppDb.openForTesting();
      addTearDown(db.close);
      final controller = AppController();
      controller.seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (i) => i)),
        ),
      );
      final dir = Directory.systemTemp.createTempSync('secretly-self');
      addTearDown(() => dir.deleteSync(recursive: true));
      final png = File('${dir.path}/a.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 2)));
      final mp4 = File('${dir.path}/clip.mp4')..writeAsBytesSync(Uint8List(32));
      final pdf = File('${dir.path}/tmp.bin')..writeAsBytesSync(Uint8List(8));
      final batch = PendingAttachmentBatchUpload(
        id: 'self1',
        items: [
          PendingPhotoUpload(
            id: 'self1_0',
            filePath: png.path,
            mime: 'image/png',
            caption: 'Подпись',
            totalBytes: png.lengthSync(),
            mediaGroupId: 'self1',
          ),
          PendingPhotoUpload(
            id: 'self1_1',
            filePath: mp4.path,
            mime: 'video/mp4',
            caption: '',
            totalBytes: 32,
            mediaGroupId: 'self1',
          ),
          PendingPhotoUpload(
            id: 'self1_2',
            filePath: pdf.path,
            mime: 'application/pdf',
            caption: '',
            totalBytes: 8,
            mediaGroupId: 'self1',
            filename: 'отчёт.pdf',
            asFile: true,
          ),
        ],
        hints: const [
          PendingUploadHints(),
          PendingUploadHints(
            width: 1920,
            height: 1080,
            durationMs: 15000,
            thumbB64: 'AAAA',
          ),
          PendingUploadHints(),
        ],
        convoId: 'owner-1',
        targetId: 'owner-1',
      );
      final errors = <AttachmentUploadErrorEvent>[];
      final sub = controller.attachmentUploadErrors.listen(errors.add);
      addTearDown(sub.cancel);
      controller.enqueueAttachmentBatchUpload(batch);
      await _until(
        () => controller.pendingAttachmentBatchUploadsFor('owner-1').isEmpty,
        tries: 600,
      );
      expect(errors, isEmpty, reason: '${errors.map((e) => e.error)}');
      expect(batch.payloadEventIds, hasLength(3));

      final rows = await db.listEventsChronological('owner-1', limit: 50);
      final payloads = <AttachmentEventV1>[];
      for (final row in rows) {
        final event = ChatEvent(
          eventId: row['event_id'] as String,
          createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
          type: (row['type'] as String?) ?? '',
          ciphertextB64: (row['ciphertext_b64'] as String?) ?? '',
          localCiphertextB64: row['local_ciphertext_b64'] as String?,
          senderDeviceId: (row['sender_device_id'] as String?) ?? '',
          localState: (row['local_state'] as String?) ?? 'received',
          payloadEventId: row['payload_event_id'] as String?,
        );
        final payload = await controller.payloadEventForChatEvent(event);
        if (payload is AttachmentEventV1) payloads.add(payload);
      }
      expect(payloads, hasLength(3));
      expect(payloads[0].caption, 'Подпись');
      expect(payloads[0].filename, isNull);
      expect(payloads[0].width, 4);
      expect(payloads[0].height, 2);
      expect(payloads[1].caption, isNull);
      expect(payloads[1].filename, isNull);
      expect(payloads[1].width, 1920);
      expect(payloads[1].height, 1080);
      expect(payloads[1].durationMs, 15000);
      expect(payloads[1].thumbB64, 'AAAA');
      expect(payloads[2].filename, 'отчёт.pdf');
      expect(payloads[2].width, isNull);
      expect({for (final p in payloads) p.mediaGroupId}, {'self1'});
    });

    test('🔴 в комнату пачка уходит в открытую тему', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final group = src.substring(
        src.indexOf('  Future<List<String>> sendGroupAttachmentFiles({'),
        src.indexOf('  Future<void> ensureDemoChat() async {'),
      );
      expect(group.contains('    String? topicId,\n'), isTrue);
      expect(group.contains('topicId: normalizedTopicId,'), isTrue);
      expect(
        group.contains(
          "if (normalizedTopicId != null) 'topicId': normalizedTopicId,",
        ),
        isTrue,
      );
      final runner = src.substring(
        src.indexOf('  Future<void> _runPendingAttachmentBatchUpload('),
        src.indexOf('  Future<void> _runPendingAudioUpload('),
      );
      expect(runner.contains('topicId: batch.topicId,'), isTrue);
      expect(runner.contains('fileName: item.filename,'), isTrue);
      expect(runner.contains('durationMs: hint.durationMs,'), isTrue);
    });
  });
}
