// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ОДНО НАЖАТИЕ ПО ПОЛУЧЕННОМУ ФАЙЛУ НЕ ЗАПУСКАЕТ ПРОГРАММУ (30.09.2026).
//
// Имя и тип файла пишет отправитель. «счёт.pdf.lnk» с типом application/pdf
// на Windows уходил системе как есть — без своего просмотра PDF — и та
// запускала ярлык. Расшифрованная копия не несла метки «из интернета», так
// что SmartScreen и защищённый просмотр Office молчали, а знак U+202E в
// имени выдавал «.exe» за «.pdf».

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/attachment_risk_dialog.dart';
import 'package:secretly_app/ui/desktop/chat/attachment_save.dart';
import 'package:secretly_app/ui/desktop/chat/message_media.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: child),
  ),
);

String _read(String path) => File(path).readAsStringSync();

void main() {
  tearDown(() => debugDesktopFileOsOverride = null);

  group('какой файл опасен', () {
    AttachmentOpenRisk? risk(
      String? name, {
      String? mime,
      DesktopFileOs os = DesktopFileOs.windows,
    }) => attachmentOpenRisk(fileName: name, mime: mime, os: os);

    test('🔴 решает ПОСЛЕДНЕЕ расширение, а не тип от отправителя', () {
      final r = risk('счёт.pdf.lnk', mime: 'application/pdf')!;
      expect(r.reason, AttachmentRiskReason.executable);
      expect(r.extension, '.lnk');
      for (final name in const [
        'setup.exe',
        'README.JS',
        'update.msi',
        'tool.hta',
        'x.settingcontent-ms',
        'disk.iso',
        'go.ps1',
      ]) {
        expect(
          risk(name)?.reason,
          AttachmentRiskReason.executable,
          reason: name,
        );
      }
    });

    test('🔴 документ с макросами опасен на любой системе', () {
      for (final os in DesktopFileOs.values) {
        expect(risk('отчёт.docm', os: os)?.extension, '.docm', reason: '$os');
      }
    });

    test('macOS — свой список', () {
      const mac = DesktopFileOs.macos;
      for (final name in const [
        'install.pkg',
        'run.command',
        'a.app',
        'x.sh',
      ]) {
        expect(risk(name, os: mac)?.reason, AttachmentRiskReason.executable);
      }
      // «.exe» на macOS ничего не запускает.
      expect(risk('setup.exe', os: mac), isNull);
    });

    test('🔴 невидимый разворот текста не прячет «.exe»', () {
      // На экране «счётexe.pdf», на диске — «счётfdp.exe».
      expect(risk('счёт\u202Efdp.exe')?.extension, '.exe');
      expect(safeDownloadFileName('счёт\u202Efdp.exe'), 'счётfdp.exe');
    });

    test('🔴 точка в конце не прячет «.exe» (Windows её срежет)', () {
      expect(risk('evil.exe.')?.extension, '.exe');
      expect(risk('evil.exe . ')?.extension, '.exe');
    });

    test('файл без расширения — тоже предупреждение', () {
      final r = risk('README')!;
      expect(r.reason, AttachmentRiskReason.noExtension);
      expect(r.extension, '');
    });

    test('🔴 «снимок» с незнакомым расширением — подмена', () {
      final r = risk('photo.appref', mime: 'image/jpeg')!;
      expect(r.reason, AttachmentRiskReason.mismatch);
      expect(r.extension, '.appref');
      expect(risk('clip.gif', mime: 'video/mp4'), isNull);
      expect(risk('Договор.pdf', mime: 'application/pdf'), isNull);
      expect(risk('заметка.txt', mime: 'text/plain'), isNull);
    });

    test('обычные файлы открываются как раньше', () {
      for (final name in const ['Договор.docx', 'архив.zip', 'песня.mp3']) {
        expect(risk(name, mime: 'application/octet-stream'), isNull);
      }
    });

    test('имени нет — придумываем сами, опасного расширения там нет', () {
      expect(risk(null, mime: 'application/x-msdownload'), isNull);
      expect(risk('  ', mime: 'image/png'), isNull);
    });
  });

  group('имя на диске', () {
    test('🔴 невидимки и управляющие знаки убраны', () {
      expect(safeDownloadFileName('a\u200Bb\u2066c\u2069.txt'), 'abc.txt');
      expect(safeDownloadFileName('a\u0085b.txt'), 'a_b.txt');
      expect(stripFileNameDisguise('x\u202Dy\u200Fz'), 'xyz');
      // Соединитель в эмодзи оставлен.
      expect(stripFileNameDisguise('👩\u200D💻.png'), '👩\u200D💻.png');
    });

    test('имя для показа и сохранения — без невидимок', () {
      expect(
        suggestedAttachmentFileName(
          fileName: 'счёт\u202Efdp.exe',
          mime: 'application/pdf',
          blobId: 'b',
        ),
        'счётfdp.exe',
      );
    });
  });

  group('метка «из интернета» (Windows)', () {
    late Directory root;
    late File cached;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('motw');
      cached = File(p.join(root.path, 'blob.bin'))..writeAsStringSync('данные');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    // На Windows это поток `файл:Zone.Identifier`; на машине проверки
    // двоеточие допустимо в имени, и поток виден соседним файлом.
    File zone(File f) => File('${f.path}:Zone.Identifier');

    test('🔴 копия для внешней программы помечена', () async {
      debugDesktopFileOsOverride = DesktopFileOs.windows;
      final copy = await attachmentOpenCopy(
        file: cached,
        suggestedName: 'Договор.docx',
        blobId: 'blob',
        root: root,
      );
      expect(zone(copy).readAsStringSync(), '[ZoneTransfer]\r\nZoneId=3\r\n');
      expect(kZoneIdentifierInternet, '[ZoneTransfer]\r\nZoneId=3\r\n');
    });

    test('🔴 копия в «Загрузки» помечена — и новая, и найденная', () async {
      debugDesktopFileOsOverride = DesktopFileOs.windows;
      final downloads = Directory(p.join(root.path, 'Downloads'))..createSync();
      final first = await exportAttachmentToDownloads(
        cached,
        'счёт.pdf',
        downloadsOverride: downloads,
      );
      expect(zone(first).readAsStringSync(), kZoneIdentifierInternet);
      // Прежняя сборка клала копию без метки — повтор её ставит.
      zone(first).deleteSync();
      final again = await exportAttachmentToDownloads(
        cached,
        'счёт.pdf',
        downloadsOverride: downloads,
      );
      expect(again.path, first.path);
      expect(zone(again).existsSync(), isTrue);
    });

    test('не Windows — поток не пишется', () async {
      debugDesktopFileOsOverride = DesktopFileOs.macos;
      final copy = await attachmentOpenCopy(
        file: cached,
        suggestedName: 'Договор.docx',
        blobId: 'blob',
        root: root,
      );
      expect(zone(copy).existsSync(), isFalse);
    });

    test('«Сохранить как…» тоже ставит метку', () {
      final save = _read('lib/ui/desktop/chat/attachment_save.dart');
      expect(
        save.contains('await markFileFromInternet(await file.copy(path));'),
        isTrue,
      );
    });
  });

  group('временные копии не живут дольше надобности', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('open_prune');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test(
      '🔴 копии старше десяти минут убираются при следующем открытии',
      () async {
        final base = attachmentOpenCopyDir(root: root);
        final stale = File(p.join(base.path, 'old', 'a.pdf'))
          ..createSync(recursive: true)
          ..setLastModifiedSync(
            DateTime.now().subtract(const Duration(minutes: 11)),
          );
        final fresh = File(p.join(base.path, 'new', 'b.pdf'))
          ..createSync(recursive: true);
        await pruneAttachmentOpenCopies(root: root);
        expect(stale.existsSync(), isFalse);
        expect(stale.parent.existsSync(), isFalse, reason: 'пустая папка тоже');
        expect(fresh.existsSync(), isTrue);
      },
    );

    test('🔴 свежая копия давнего файла не считается старой', () async {
      // Копирование сохраняет время исходника: без отметки уборка стёрла бы
      // только что открытый документ.
      final cached = File(p.join(root.path, 'blob.bin'))
        ..writeAsStringSync('x')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 30)),
        );
      final copy = await attachmentOpenCopy(
        file: cached,
        suggestedName: 'a.pdf',
        blobId: 'blob',
        root: root,
      );
      await pruneAttachmentOpenCopies(root: root);
      expect(copy.existsSync(), isTrue);
    });

    test('на выходе стирается всё, синхронно', () {
      final base = attachmentOpenCopyDir(root: root);
      File(p.join(base.path, 'b', 'a.pdf')).createSync(recursive: true);
      clearAttachmentOpenCopiesSync(root: root);
      expect(base.existsSync(), isFalse);
      clearAttachmentOpenCopiesSync(root: root); // пустое место не роняет
    });

    test(
      '🔴 выход из приложения сперва убирает копии, потом закрывает окно',
      () {
        debugResetDesktopQuit();
        addTearDown(debugResetDesktopQuit);
        fakeAsync((async) {
          final order = <String>[];
          unawaited(
            quitDesktopApp(
              cleanup: () => order.add('cleanup'),
              destroy: () async => order.add('destroy'),
              exitProcess: () {},
            ),
          );
          async.elapse(const Duration(milliseconds: 10));
          expect(order, ['cleanup', 'destroy']);
        });
      },
    );
  });

  group('предупреждение', () {
    const risky = AttachmentOpenRisk(
      extension: '.exe',
      reason: AttachmentRiskReason.executable,
    );

    Future<BuildContext> pumpHost(WidgetTester t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      return ctx;
    }

    testWidgets('🔴 называет настоящее расширение, открыть — только кнопкой', (
      t,
    ) async {
      final ctx = await pumpHost(t);
      RiskyAttachmentChoice? picked;
      unawaited(
        confirmRiskyAttachmentOpen(
          ctx,
          fileName: 'счётfdp.exe',
          risk: risky,
        ).then((v) => picked = v),
      );
      await t.pumpAndSettle();
      expect(find.text('счётfdp.exe'), findsOneWidget);
      expect(find.textContaining('.exe'), findsWidgets);
      expect(find.text('Показать в папке'), findsOneWidget);
      await t.tap(find.text('Всё равно открыть'));
      await t.pumpAndSettle();
      expect(picked, RiskyAttachmentChoice.openAnyway);
    });

    testWidgets('«Показать в папке» и Escape не открывают файл', (t) async {
      final ctx = await pumpHost(t);
      RiskyAttachmentChoice? picked;
      unawaited(
        confirmRiskyAttachmentOpen(
          ctx,
          fileName: 'x.exe',
          risk: risky,
        ).then((v) => picked = v),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Показать в папке'));
      await t.pumpAndSettle();
      expect(picked, RiskyAttachmentChoice.showInFolder);

      var closed = false;
      unawaited(
        confirmRiskyAttachmentOpen(
          ctx,
          fileName: 'x.exe',
          risk: risky,
        ).then((v) => closed = v == null),
      );
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('обычный файл открывается без вопросов', (t) async {
      final ctx = await pumpHost(t);
      debugDesktopFileOsOverride = DesktopFileOs.windows;
      final ok = await mayOpenReceivedFile(
        ctx,
        file: File('не-нужен'),
        fileName: 'Договор.docx',
        mime: null,
        blobId: 'b',
      );
      expect(ok, isTrue);
      expect(find.text('Открыть этот файл?'), findsNothing);
    });

    testWidgets('«Всё равно открыть» пропускает опасный файл', (t) async {
      final ctx = await pumpHost(t);
      debugDesktopFileOsOverride = DesktopFileOs.windows;
      bool? ok;
      unawaited(
        mayOpenReceivedFile(
          ctx,
          file: File('не-нужен'),
          fileName: 'счёт.pdf.lnk',
          mime: 'application/pdf',
          blobId: 'b',
        ).then((v) => ok = v),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('расширение .lnk'), findsOneWidget);
      await t.tap(find.text('Всё равно открыть'));
      await t.pumpAndSettle();
      expect(ok, isTrue);
    });

    test('текст есть во всех восьми языках', () {
      for (final code in const [
        'ru',
        'en',
        'uk',
        'es',
        'pt',
        'pt_BR',
        'fr',
        'de',
      ]) {
        final arb = _read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopFileRiskTitle',
          'desktopFileRiskExtension',
          'desktopFileRiskNoExtension',
          'desktopFileRiskMismatch',
          'desktopFileRiskShowInFolder',
          'desktopFileRiskOpenAnyway',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });

  group('пузырь показывает настоящее расширение', () {
    testWidgets('длинное расширение не обрезается', (t) async {
      await t.pumpWidget(
        _host(
          const SizedBox(
            width: 160,
            child: MiddleEllipsisText(
              'Очень длинное название счёта.settingcontent-ms',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
      expect(find.text('.settingcontent-ms'), findsOneWidget);
    });

    test('имя в пузыре — без невидимок', () {
      final media = _read('lib/ui/desktop/chat/message_media.dart');
      expect(
        media.contains(
          "final n = stripFileNameDisguise(attachment.fileName ?? '').trim();",
        ),
        isTrue,
      );
    });
  });

  group('проводка (по исходникам)', () {
    test('🔴 лента спрашивает ДО того, как отдать файл наружу', () {
      final section = _read('lib/ui/desktop/app/desktop_chats_section.dart');
      final at = section.indexOf('Future<void> _openFileExternally(');
      expect(at, greaterThan(0));
      final body = section.substring(at, at + 2400);
      final askAt = body.indexOf('mayOpenReceivedFile(');
      final copyAt = body.indexOf('attachmentOpenCopy(');
      expect(askAt, greaterThan(0));
      expect(askAt < copyAt, isTrue);
    });

    test('🔴 просмотр выбирается по настоящему размеру, не по заявленному', () {
      final section = _read('lib/ui/desktop/app/desktop_chats_section.dart');
      final at = section.indexOf('Future<void> _openFile(');
      final body = section.substring(at, at + 2600);
      expect(body.contains('sizeBytes: file.lengthSync(),'), isTrue);
      expect(body.contains('sizeBytes: att.sizeBytes'), isFalse);
    });

    test('🔴 галерея не отдаёт наружу файл из кэша', () {
      final gallery = _read(
        'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
      );
      expect(gallery.contains('Uri.file(f.path)'), isFalse);
      expect(gallery.contains('mayOpenReceivedFile('), isTrue);
      expect(gallery.contains('attachmentOpenCopy('), isTrue);
    });

    test('🔴 macOS: карантин ставит песочница — её нельзя снимать молча', () {
      // Файлы, записанные приложением в песочнице, получают
      // com.apple.quarantine сами (проверено на кэше вложений). Уберут
      // песочницу — понадобится LSFileQuarantineEnabled в Info.plist.
      final release = _read('macos/Runner/Release.entitlements');
      final plist = _read('macos/Runner/Info.plist');
      final sandboxed = RegExp(
        r'<key>com\.apple\.security\.app-sandbox</key>\s*<true/>',
      ).hasMatch(release);
      final quarantined = RegExp(
        r'<key>LSFileQuarantineEnabled</key>\s*<true/>',
      ).hasMatch(plist);
      expect(sandboxed || quarantined, isTrue);
    });
  });
}
