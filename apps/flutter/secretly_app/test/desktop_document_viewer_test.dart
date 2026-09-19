// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПРОСМОТР ДОКУМЕНТА ВНУТРИ ОКНА.
//
// 🔴 Полученный файл открывался ЧУЖОЙ программой: расшифрованный документ
// уходил другому приложению, попадал в его список недавних и в его кэш. Для
// переписки со сквозным шифрованием это самое слабое место пути.
//
// PDF рисует системный PDFKit (он уже есть в macOS — ни веса, ни зависимости,
// мобильной сборки не касается), простой текст показываем сами.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_pdf_bridge.dart';
import 'package:secretly_app/ui/desktop/chat/document_viewer.dart';
import 'package:secretly_app/ui/desktop/chat/document_viewer_kind.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Картинка 1×1 — на месте страницы PDF в проверке.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(colors: kDColorsDark, child: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('чем показывать файл', () {
    test('🔴 PDF — своим просмотром', () {
      expect(
        desktopViewerKindFor(mime: 'application/pdf', fileName: 'x'),
        DesktopViewerKind.pdf,
      );
      expect(
        desktopViewerKindFor(mime: null, fileName: 'Договор.PDF'),
        DesktopViewerKind.pdf,
      );
    });

    test('текст — своим просмотром', () {
      expect(
        desktopViewerKindFor(mime: 'text/plain', fileName: 'note.txt'),
        DesktopViewerKind.text,
      );
      expect(
        desktopViewerKindFor(mime: null, fileName: 'данные.json'),
        DesktopViewerKind.text,
      );
      expect(
        desktopViewerKindFor(mime: 'application/xml', fileName: 'f'),
        DesktopViewerKind.text,
      );
    });

    test('🔴 огромный текст честнее отдать программе', () {
      expect(
        desktopViewerKindFor(
          mime: 'text/plain',
          fileName: 'log.txt',
          sizeBytes: kDesktopTextViewerMaxBytes + 1,
        ),
        DesktopViewerKind.external_,
      );
    });

    test('🔴 система не умеет PDF (Windows) — отдаём программе', () {
      // Показать пустое окно вместо документа хуже прежнего поведения.
      expect(
        desktopViewerKindFor(
          mime: 'application/pdf',
          fileName: 'x.pdf',
          canRenderPdf: false,
        ),
        DesktopViewerKind.external_,
      );
      // Текст показывается везде — он никакого движка не требует.
      expect(
        desktopViewerKindFor(
          mime: 'text/plain',
          fileName: 'note.txt',
          canRenderPdf: false,
        ),
        DesktopViewerKind.text,
      );
    });

    test('чужие типы — как раньше, внешней программой', () {
      for (final f in const ['архив.zip', 'песня.mp3', 'таблица.xlsx']) {
        expect(
          desktopViewerKindFor(mime: null, fileName: f),
          DesktopViewerKind.external_,
          reason: f,
        );
      }
    });
  });

  group('окно просмотра', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('doc_viewer');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DesktopPdfBridge.channel, null);
    });

    testWidgets('текст показывается прямо в окне', (t) async {
      final file = File('${tmp.path}/note.txt')
        ..writeAsStringSync('привет\nвторая строка');
      // Настоящее чтение файла идёт только внутри `runAsync`: обычный
      // прогон подменяет время, и ввод-вывод в нём не завершается.
      await t.runAsync(() async {
        await t.pumpWidget(
          _host(
            DesktopDocumentViewer(
              file: file,
              title: 'note.txt',
              kind: DesktopViewerKind.text,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      expect(find.text('привет\nвторая строка'), findsOneWidget);
      expect(find.text('note.txt'), findsOneWidget);
    });

    testWidgets('🔴 PDF рисуется постранично, с номером страницы', (t) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DesktopPdfBridge.channel, (call) async {
            calls.add(call.method);
            if (call.method == 'info') return 3;
            if (call.method == 'render') return _png;
            return null;
          });
      final file = File('${tmp.path}/doc.pdf')..writeAsBytesSync(<int>[1, 2]);
      await t.pumpWidget(
        _host(
          DesktopDocumentViewer(
            file: file,
            title: 'doc.pdf',
            kind: DesktopViewerKind.pdf,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(calls.first, 'info');
      expect(calls.contains('render'), isTrue);
      expect(find.text('Страница 1 из 3'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('нечитаемый PDF честно говорит об этом', (t) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            DesktopPdfBridge.channel,
            (call) async => null,
          );
      final file = File('${tmp.path}/broken.pdf')..writeAsBytesSync(<int>[0]);
      await t.pumpWidget(
        _host(
          DesktopDocumentViewer(
            file: file,
            title: 'broken.pdf',
            kind: DesktopViewerKind.pdf,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Не удалось показать файл'), findsOneWidget);
    });

    testWidgets('кнопки «сохранить» и «открыть в программе» на месте', (
      t,
    ) async {
      final file = File('${tmp.path}/note.md')..writeAsStringSync('# привет');
      var opened = 0;
      var saved = 0;
      await t.runAsync(() async {
        await t.pumpWidget(
          _host(
            DesktopDocumentViewer(
              file: file,
              title: 'note.md',
              kind: DesktopViewerKind.text,
              onOpenExternally: () async => opened++,
              onSaveAs: () async => saved++,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      await t.tap(find.text('Открыть в программе'));
      await t.tap(find.text('Сохранить как…'));
      await t.pump();
      expect(opened, 1);
      expect(saved, 1);
    });
  });

  group('проводка (по исходникам)', () {
    String read(String path) => File(path).readAsStringSync();

    test('🔴 свой просмотр спрашивают раньше внешней программы', () {
      final section = read('lib/ui/desktop/app/desktop_chats_section.dart');
      final at = section.indexOf('Future<void> _openFile(');
      expect(at, greaterThan(0));
      final body = section.substring(at, at + 2600);
      final kindAt = body.indexOf('desktopViewerKindFor(');
      final externalAt = body.indexOf('_openFileExternally(');
      expect(kindAt, greaterThan(0));
      expect(kindAt < externalAt, isTrue);
    });

    test('мост PDF зарегистрирован в приложении macOS', () {
      final window = read('macos/Runner/MainFlutterWindow.swift');
      expect(window.contains('pdfRenderBridge.attach('), isTrue);
      final project = read('macos/Runner.xcodeproj/project.pbxproj');
      expect(
        project.contains('PdfRenderBridge.swift in Sources'),
        isTrue,
        reason: 'файл не попал в сборку — мост молча не работал бы',
      );
    });

    test('подписи просмотра есть во всех восьми языках', () {
      for (final code in const [
        'ru', 'en', 'uk', 'es', 'pt', 'pt_BR', 'fr', 'de',
      ]) {
        final arb = read('lib/l10n/app_$code.arb');
        for (final key in const [
          'desktopViewerOpenExternally',
          'desktopViewerSaveAs',
          'desktopViewerPage',
          'desktopViewerFailed',
        ]) {
          expect(arb.contains('"$key"'), isTrue, reason: '$code: $key');
        }
      }
    });
  });
}
