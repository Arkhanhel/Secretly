// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЭМОДЗИ WINDOWS — NOTO, КАК НА ТЕЛЕФОНЕ (30.09.2026, Э1).
//
// Владелец: эмодзи на Windows «как из аськи» — Segoe UI Emoji вместо Noto.
// Шрифт едет только в сборку Windows, текст ПК получает его запасным.
//
// Тесты идут на macOS и Linux, поэтому ветка Windows включается подменой
// (`DesktopEmojiFont.debugWindowsOverride`) — иначе ранний выход по ОС молча
// проглотил бы любую ошибку в ней. Обе половины проверяются: на Windows
// запасной шрифт есть везде, на остальных ОС его нет нигде.
//
// Главные проверки — НАСТОЯЩИМ движком: настоящий файл шрифта грузится тем же
// загрузчиком, что у программы, и ширина знака в каждой поверхности сверяется
// с шириной знака Noto (2550/2048 кегля). Совпадение по ширине — подпись
// именно этого шрифта: заглушка и чужой шрифт дают другую ширину. Цвет знаков
// так не проверить (движок Mac и Linux картинки CBDT в тестах не рисует) —
// его проверяет самотест `--emoji-font-selftest` на настоящей Windows в CI.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/legal/third_party_licenses.dart';
import 'package:secretly_app/ui/desktop/app/desktop_child_window_app.dart';
import 'package:secretly_app/ui/desktop/chat/emoji_grid.dart';
import 'package:secretly_app/ui/desktop/chat/message_rich_text.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/emoji_font.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/design/typography.dart';
import 'package:secretly_app/ui/desktop/services/desktop_emoji_font_loader.dart';
import 'package:secretly_app/ui/desktop/services/desktop_emoji_font_selftest.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Файл, его размер и сумма — ровно то, что записано в
/// `assets/fonts/LICENSES.md`. Обновили шрифт — поправить и там, и здесь.
const String _fontPath = 'windows/fonts/NotoColorEmoji_WindowsCompatible.ttf';

/// Ширина строки «как у Noto» с допуском движка (04.10.2026).
///
/// 🔴 Движки текста округляют ширины по-разному: CoreText на Mac даёт
/// 24,902, FreeType на Linux (CI открытой выкладки) — 24,953, то есть до
/// 0,065 точки на знак, и расхождение копится по длине строки. Различать
/// проверки должны Noto и чужой шрифт — они расходятся больше чем на 0,5
/// точки (`greaterThan(0.5)` ниже), так что 0,1 на знак (или 0,3 % строки)
/// ничего не размывает.
Matcher _closeToWidth(double expected) =>
    moreOrLessEquals(expected, epsilon: math.max(0.1, expected * 0.003));
const int _fontBytes = 10739048;
const String _fontSha256 =
    '2c7ede2f5438f9c1da098778bd681535933a345334008bb03fc51119f6b1cd72';
const String _upstreamCommit = 'e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e';

/// Вся шкала `DType`.
List<TextStyle> _scale() => <TextStyle>[
      DType.display,
      DType.title,
      DType.body,
      DType.bodyStrong,
      DType.label,
      DType.caption,
      DType.tiny,
      DType.panelTitle,
      DType.threadTitle,
      DType.rowName,
      DType.preview,
      DType.timeSmall,
      DType.topicName,
      DType.meta,
      DType.mono,
    ];

double _width(InlineSpan span) {
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
    ..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

/// Действующий стиль куска текста, в котором стоит знак с номером [target]:
/// то, чего кусок не задал, он берёт у родителя (так наследует и движок).
TextStyle? _styleAt(InlineSpan root, int target) {
  var pos = 0;
  TextStyle? found;
  bool walk(InlineSpan span, TextStyle? inherited) {
    final own = inherited == null ? span.style : inherited.merge(span.style);
    if (span is TextSpan) {
      final text = span.text ?? '';
      if (target >= pos && target < pos + text.length) {
        found = own;
        return true;
      }
      pos += text.length;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (walk(child, own)) return true;
      }
    } else if (span is PlaceholderSpan) {
      pos += 1;
    }
    return false;
  }

  walk(root, null);
  return found;
}

/// Для каждого вхождения [emoji] в абзацах и полях ввода под [finder]:
/// (ширина знака на экране, ширина знака Noto того же кегля). Разрядка
/// (`letterSpacing`, у стилей Material она есть) прибавляется к обеим.
List<(double, double)> _emojiWidths(Finder finder, String emoji) {
  final out = <(double, double)>[];
  void measure(
    InlineSpan? span,
    List<TextBox> Function(TextSelection) boxes,
    TextScaler scaler,
  ) {
    if (span == null) return;
    final plain = span.toPlainText(includeSemanticsLabels: false);
    var i = plain.indexOf(emoji);
    while (i >= 0) {
      final got = boxes(
        TextSelection(baseOffset: i, extentOffset: i + emoji.length),
      ).fold<double>(0, (s, b) => s + (b.right - b.left));
      final style = _styleAt(span, i);
      final size = scaler.scale(style?.fontSize ?? 14);
      final spacing = style?.letterSpacing ?? 0;
      out.add((got, size * kNotoEmojiAdvanceEm + spacing));
      i = plain.indexOf(emoji, i + emoji.length);
    }
  }

  void visit(RenderObject o) {
    if (o is RenderParagraph) {
      measure(o.text, o.getBoxesForSelection, o.textScaler);
    } else if (o is RenderEditable) {
      measure(o.text, o.getBoxesForSelection, o.textScaler);
    }
    o.visitChildren(visit);
  }

  for (final e in finder.evaluate()) {
    final ro = e.renderObject;
    if (ro != null) visit(ro);
  }
  return out;
}

void _expectNoto(Finder finder, String emoji) {
  final widths = _emojiWidths(finder, emoji);
  expect(widths, isNotEmpty, reason: 'знак $emoji не найден');
  for (final (got, noto) in widths) {
    expect(got, _closeToWidth(noto),
        reason: '$emoji нарисован не Noto: ширина $got, у Noto $noto');
  }
}

void _expectNotNoto(Finder finder, String emoji) {
  final widths = _emojiWidths(finder, emoji);
  expect(widths, isNotEmpty, reason: 'знак $emoji не найден');
  for (final (got, noto) in widths) {
    expect((got - noto).abs(), greaterThan(0.5),
        reason: '$emoji нарисован Noto там, где запасного шрифта быть не должно');
  }
}

/// Окно ПК в миниатюре: тема ПК, стиль по умолчанию над навигатором,
/// `Material` и палитра — как у главного окна.
Widget _desktopHost(Widget child) => MaterialApp(
      theme: desktopMaterialTheme(kDColorsDark, dark: true),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, c) => desktopEmojiTextFallback(c ?? const SizedBox()),
      home: Material(
        color: kDColorsDark.bg,
        child: DColors(
          colors: kDColorsDark,
          child: Center(
            child: SizedBox(width: 420, height: 420, child: child),
          ),
        ),
      ),
    );

Future<void> _loadManrope() async {
  // Manrope — основной шрифт ПК. В тестах его нет, пока не загрузить, а без
  // него пробелы и буквы рисовал бы тестовый шрифт, и проверка «пробелы у
  // эмодзи не распухли» была бы не о том.
  final loader = FontLoader(DType.family);
  for (final w in <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(
      File('assets/fonts/Manrope-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.sublistView(b)),
    );
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('файл шрифта и сборка Windows', () {
    test('файл — тот, что скачан из googlefonts/noto-emoji: размер и SHA-256',
        () {
      final bytes = File(_fontPath).readAsBytesSync();
      expect(bytes.length, _fontBytes);
      expect(sha256.convert(bytes).toString(), _fontSha256);
    });

    test('TrueType с цветными картинками (CBDT/CBLC) и таблицами для Windows',
        () {
      final bytes = File(_fontPath).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(0), 0x00010000);
      final tables = <String>{
        for (var i = 0; i < data.getUint16(4); i++)
          String.fromCharCodes(bytes.sublist(12 + 16 * i, 16 + 16 * i)),
      };
      expect(tables, containsAll(<String>['CBDT', 'CBLC', 'cmap', 'glyf', 'loca']));
    });

    test('🔴 pubspec шрифт не заявляет — телефон и macOS байт-в-байт прежние',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('NotoColorEmoji')));
      expect(pubspec, isNot(contains(kDesktopEmojiFontFamily)));
      expect(pubspec, isNot(contains('windows/fonts')));
      final copies = Directory('assets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains('NotoColorEmoji'));
      expect(copies, isEmpty, reason: 'копия шрифта среди ассетов уехала бы в телефон');
    });

    test('CMake кладёт файл в data\\ рядом с flutter_assets', () {
      final cmake = File('windows/CMakeLists.txt').readAsStringSync();
      final rule = RegExp(
        r'install\(\s*FILES\s+"\$\{CMAKE_CURRENT_SOURCE_DIR\}/fonts/' +
            RegExp.escape(kDesktopEmojiFontFileName) +
            r'"\s+DESTINATION\s+"\$\{INSTALL_BUNDLE_DATA_DIR\}"',
      );
      expect(rule.hasMatch(cmake), isTrue);
      expect(File('windows/fonts/$kDesktopEmojiFontFileName').existsSync(), isTrue);
    });

    test('🔴 имя семейства — своё, не из телефонных списков запасных шрифтов',
        () {
      expect(kDesktopEmojiFontFamily, isNot('Noto Color Emoji'));
      expect(kDesktopEmojiFontFamily, isNot('NotoColorEmoji'));
      // Вне кода ПК имя не встречается нигде: телефон его не видит.
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (!p.endsWith('.dart')) continue;
        if (p.startsWith('lib/ui/desktop/') || p == 'lib/main_desktop.dart') {
          continue;
        }
        if (f.readAsStringSync().contains(kDesktopEmojiFontFamily)) {
          offenders.add(p);
        }
      }
      expect(offenders, isEmpty);
    });

    final ciFile = File('../../../.github/workflows/windows-release.yml');
    test('самотест эмодзи подключён в CI Windows, снимок уходит в архив', () {
      final ci = ciFile.readAsStringSync();
      expect(ci, contains(kEmojiFontSelftestArg));
      expect(ci, contains('emoji-selftest.png'));
      expect(ci.indexOf('--child-window-selftest'),
          lessThan(ci.indexOf(kEmojiFontSelftestArg)));
    }, skip: !ciFile.existsSync());
  });

  group('лицензия', () {
    tearDown(LicenseRegistry.reset);

    test('на Windows заявлена: Noto Color Emoji под SIL OFL 1.1', () async {
      LicenseRegistry.reset();
      registerWindowsEmojiFontLicense();
      final entries = await LicenseRegistry.licenses.toList();
      final noto = entries.singleWhere(
        (e) => e.packages.contains('Noto Color Emoji'),
      );
      final text = noto.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(text, contains('OTHER DEALINGS IN THE FONT SOFTWARE'));
    });

    test('общий список (телефон, macOS) этот шрифт не заявляет', () async {
      LicenseRegistry.reset();
      registerThirdPartyLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      expect(entries.expand((e) => e.packages), isNot(contains('Noto Color Emoji')));
    });

    test('main_desktop заявляет её один раз и только на Windows', () {
      final desktop = File('lib/main_desktop.dart').readAsStringSync();
      expect(
        RegExp(r'registerWindowsEmojiFontLicense\(\);').allMatches(desktop).length,
        1,
      );
      expect(
        desktop,
        contains('if (DesktopEmojiFont.enabled) registerWindowsEmojiFontLicense();'),
      );
      expect(
        File('lib/main.dart').readAsStringSync(),
        isNot(contains('registerWindowsEmojiFontLicense')),
      );
    });

    test('LICENSES.md: источник, коммит, сумма и путь записаны', () {
      final md = File('assets/fonts/LICENSES.md').readAsStringSync();
      expect(md, contains('https://github.com/googlefonts/noto-emoji'));
      expect(md, contains(_upstreamCommit));
      expect(md, contains(_fontSha256));
      expect(md, contains(_fontPath));
      expect(md, contains('SIL OFL 1.1'));
    });
  });

  group('запасной шрифт — только на Windows', () {
    tearDown(() => DesktopEmojiFont.debugWindowsOverride = null);

    test('не Windows (macOS): тема, шкала DType и корень окна — как были', () {
      DesktopEmojiFont.debugWindowsOverride = false;
      expect(DesktopEmojiFont.enabled, isFalse);
      expect(DType.emojiFallback, isNull);
      final theme = desktopMaterialTheme(kDColorsDark, dark: true);
      expect(theme.textTheme.bodyMedium!.fontFamilyFallback, isNull);
      expect(theme.textTheme.bodyLarge!.fontFamilyFallback, isNull);
      for (final s in _scale()) {
        expect(s.fontFamilyFallback?.contains(kDesktopEmojiFontFamily) ?? false, isFalse);
      }
      expect(DType.body.fontFamilyFallback, isNull);
      expect(DType.meta.fontFamilyFallback, DType.monoFallback);
      final style = DType.body.copyWith(color: Colors.red);
      expect(identical(DType.withEmojiFallback(style), style), isTrue);
      const child = SizedBox();
      expect(identical(desktopEmojiTextFallback(child), child), isTrue);
    });

    test('Windows: тема, стили Material и вся шкала DType — Noto последним', () {
      DesktopEmojiFont.debugWindowsOverride = true;
      final theme = desktopMaterialTheme(kDColorsDark, dark: true);
      for (final s in <TextStyle?>[
        theme.textTheme.bodyMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.labelLarge,
        theme.textTheme.titleMedium,
      ]) {
        expect(s!.fontFamily, DType.family);
        expect(s.fontFamilyFallback, <String>[DType.family, kDesktopEmojiFontFamily]);
      }
      // Этими стилями Material ЗАМЕНЯЕТ стиль по умолчанию — им нужен свой.
      for (final s in <TextStyle?>[
        theme.dialogTheme.titleTextStyle,
        theme.dialogTheme.contentTextStyle,
        theme.popupMenuTheme.textStyle,
        theme.popupMenuTheme.labelTextStyle?.resolve(<WidgetState>{}),
        theme.tooltipTheme.textStyle,
        theme.snackBarTheme.contentTextStyle,
      ]) {
        expect(s!.fontFamilyFallback, contains(kDesktopEmojiFontFamily));
      }
      for (final s in _scale()) {
        expect(s.fontFamilyFallback!.last, kDesktopEmojiFontFamily);
      }
      expect(DType.body.fontFamilyFallback, <String>[kDesktopEmojiFontFamily]);
      // Моноширинные: свой список первым, Consolas раньше эмодзи.
      final mono = DType.mono.fontFamilyFallback!;
      expect(mono.sublist(0, DType.monoFallback.length), DType.monoFallback);
      expect(mono.indexOf('Consolas'), lessThan(mono.indexOf(kDesktopEmojiFontFamily)));
      // Геттер шкалы не плодит объекты.
      expect(identical(DType.body, DType.body), isTrue);
      const child = SizedBox();
      expect(identical(desktopEmojiTextFallback(child), child), isFalse);
    });

    test('оба окна ставят стиль по умолчанию с запасным шрифтом', () {
      for (final path in <String>[
        'lib/ui/desktop/app/desktop_production_app.dart',
        'lib/ui/desktop/app/desktop_child_window_app.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('desktopEmojiTextFallback(child ?? const SizedBox.shrink())'),
          reason: path,
        );
      }
    });
  });

  // 🔴 Порядок групп важен: здесь семейство ещё НЕ зарегистрировано — его
  // регистрирует группа «движок» ниже, и дальше оно живёт до конца файла.
  group('загрузчик: ошибки глотаются, запуск не держится', () {
    setUp(DesktopEmojiFontLoader.debugReset);
    tearDown(() {
      DesktopEmojiFontLoader.debugReset();
      DesktopEmojiFont.debugWindowsOverride = null;
    });

    test('путь — data\\ рядом с программой', () {
      final sep = Platform.pathSeparator;
      expect(
        DesktopEmojiFontLoader.fontPath,
        endsWith('${sep}data$sep$kDesktopEmojiFontFileName'),
      );
    });

    test('не Windows — ответ сразу, диск не трогается', () async {
      DesktopEmojiFont.debugWindowsOverride = false;
      DesktopEmojiFontLoader.debugFontPathOverride = _fontPath;
      var touched = false;
      DesktopEmojiFontLoader.debugRegisterOverride = (_, __) async {
        touched = true;
      };
      final r = await DesktopEmojiFontLoader.load();
      expect(r.loaded, isFalse);
      expect(r.reason, 'not_windows');
      expect(touched, isFalse);
    });

    test('Windows, файла нет — остаётся Segoe, без исключения', () async {
      DesktopEmojiFont.debugWindowsOverride = true;
      DesktopEmojiFontLoader.debugFontPathOverride =
          'windows/fonts/no_such_file.ttf';
      final r = await DesktopEmojiFontLoader.load();
      expect(r.loaded, isFalse);
      expect(r.reason, 'absent');
    });

    test('Windows, регистрация бросает — ошибка проглочена', () async {
      DesktopEmojiFont.debugWindowsOverride = true;
      DesktopEmojiFontLoader.debugFontPathOverride = _fontPath;
      DesktopEmojiFontLoader.debugRegisterOverride =
          (_, __) async => throw StateError('DirectWrite said no');
      final r = await DesktopEmojiFontLoader.load();
      expect(r.loaded, isFalse);
      expect(r.reason, 'error:StateError');
    });

    test('Windows, движок молча не принял файл — «rejected», а не «ok»',
        () async {
      expect(DesktopEmojiFontLoader.probeRegistered(), isFalse,
          reason: 'предусловие: семейство ещё не зарегистрировано');
      DesktopEmojiFont.debugWindowsOverride = true;
      DesktopEmojiFontLoader.debugFontPathOverride = _fontPath;
      DesktopEmojiFontLoader.debugRegisterOverride = (_, __) async {};
      final r = await DesktopEmojiFontLoader.load();
      expect(r.loaded, isFalse);
      expect(r.reason, 'rejected');
      expect(r.bytes, _fontBytes);
    });

    test('зависшая загрузка держит запуск не дольше предела', () async {
      DesktopEmojiFont.debugWindowsOverride = true;
      DesktopEmojiFontLoader.debugFontPathOverride = _fontPath;
      final never = Completer<void>();
      DesktopEmojiFontLoader.debugRegisterOverride = (_, __) => never.future;
      final watch = Stopwatch()..start();
      final r = await DesktopEmojiFontLoader.waitAtMost(
        const Duration(milliseconds: 100),
      );
      expect(r, isNull);
      expect(watch.elapsedMilliseconds, lessThan(3000));
    });

    test('один раз за процесс: повторный вызов — то же обещание', () {
      DesktopEmojiFont.debugWindowsOverride = false;
      expect(
        identical(DesktopEmojiFontLoader.load(), DesktopEmojiFontLoader.load()),
        isTrue,
      );
    });

    test('предел ожидания при запуске — доли секунды', () {
      expect(kDesktopEmojiFontStartupWait, lessThanOrEqualTo(const Duration(milliseconds: 500)));
      final src = File('lib/main_desktop.dart').readAsStringSync();
      expect(src, contains('DesktopEmojiFontLoader.waitAtMost(kDesktopEmojiFontStartupWait)'));
      expect(
        src.indexOf('DesktopEmojiFontLoader.load()'),
        lessThan(src.indexOf('SingleInstance.forApp()')),
        reason: 'загрузка начинается раньше подготовки окна — параллельно с ней',
      );
    });
  });

  group('движок: эмодзи рисует Noto — замер шириной знака', () {
    setUpAll(() async {
      await _loadManrope();
      DesktopEmojiFontLoader.debugReset();
      DesktopEmojiFont.debugWindowsOverride = true;
      DesktopEmojiFontLoader.debugFontPathOverride = _fontPath;
      final r = await DesktopEmojiFontLoader.load();
      DesktopEmojiFont.debugWindowsOverride = null;
      // ignore: avoid_print
      print('загрузка настоящего файла: $r');
      expect(r.loaded, isTrue, reason: '$r');
      expect(r.reason, 'ok');
    });
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
    tearDown(() => DesktopEmojiFont.debugWindowsOverride = null);
    tearDownAll(DesktopEmojiFontLoader.debugReset);

    test('правило движка: вложенный кусок со СВОИМ семейством теряет '
        'запасной шрифт родителя — поэтому он стоит в самих стилях DType', () {
      const size = 20.0;
      const noto = size * kNotoEmojiAdvanceEm;
      const parent = TextStyle(
        fontFamily: DType.family,
        fontFamilyFallback: <String>[kDesktopEmojiFontFamily],
        fontSize: size,
      );
      expect(_width(const TextSpan(text: '🧿', style: parent)),
          _closeToWidth(noto));
      expect(
        _width(const TextSpan(
          style: parent,
          children: <InlineSpan>[
            TextSpan(text: '🧿', style: TextStyle(fontSize: size)),
          ],
        )),
        _closeToWidth(noto),
        reason: 'кусок без семейства наследует список родителя',
      );
      expect(
        (_width(const TextSpan(
                  style: parent,
                  children: <InlineSpan>[
                    TextSpan(
                      text: '🧿',
                      style: TextStyle(fontFamily: DType.family, fontSize: size),
                    ),
                  ],
                )) -
                noto)
            .abs(),
        greaterThan(0.5),
        reason: 'кусок со своим семейством список родителя теряет',
      );
    });

    testWidgets('Windows: пузырь (разметка — вложенные куски) — Noto, '
        'пробелы у эмодзи обычные', (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      await t.pumpWidget(_desktopHost(MessageRichText(
        text: 'a 🧿 **b 🇺🇦** ~~c 🏳️‍🌈~~',
        mentions: const [],
        style: DType.body.copyWith(color: Colors.white),
        isSelf: false,
        selfProfileId: 'me',
      )));
      final bubble = find.byType(MessageRichText);
      _expectNoto(bubble, '🧿');
      _expectNoto(bubble, '🇺🇦');
      _expectNoto(bubble, '🏳️‍🌈');
      // Пробел рядом с эмодзи — пробел Manrope, а не Noto шириной с эмодзи.
      for (final (space, noto) in _emojiWidths(bubble, ' ')) {
        expect(space, lessThan(noto * 0.5));
      }
    });

    testWidgets('не Windows: тот же пузырь — без Noto (как было)', (t) async {
      DesktopEmojiFont.debugWindowsOverride = false;
      await t.pumpWidget(_desktopHost(MessageRichText(
        text: 'a 🧿 **b 🇺🇦**',
        mentions: const [],
        style: DType.body.copyWith(color: Colors.white),
        isSelf: false,
        selfProfileId: 'me',
      )));
      _expectNotNoto(find.byType(MessageRichText), '🧿');
      _expectNotNoto(find.byType(MessageRichText), '🇺🇦');
    });

    testWidgets('Windows: сетка эмодзи (текст без своего семейства) — Noto',
        (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      await t.pumpWidget(_desktopHost(DesktopEmojiGrid(onPicked: (_) {})));
      await t.pumpAndSettle();
      _expectNoto(find.byType(DesktopEmojiGrid), '😀');
    });

    testWidgets('не Windows: та же сетка — без Noto', (t) async {
      DesktopEmojiFont.debugWindowsOverride = false;
      await t.pumpWidget(_desktopHost(DesktopEmojiGrid(onPicked: (_) {})));
      await t.pumpAndSettle();
      _expectNotNoto(find.byType(DesktopEmojiGrid), '😀');
    });

    testWidgets('Windows: выбор тона кожи (меню Material со своим стилем) — Noto',
        (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      await t.pumpWidget(_desktopHost(
        DesktopEmojiGrid(onPicked: (_) {}, query: 'thumbs up'),
      ));
      await t.pumpAndSettle();
      // Правая кнопка по знаку с тонами открывает меню — как у человека.
      await t.tap(find.text('👍').first, buttons: kSecondaryMouseButton);
      await t.pumpAndSettle();
      final menu = find.byType(PopupMenuItem<String>);
      expect(menu, findsWidgets);
      _expectNoto(menu, '👍🏽');
    });

    testWidgets('Windows: поле ввода, черновик в списке, стиль без шрифта '
        'на машине', (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      await t.pumpWidget(_desktopHost(ListView(
        children: <Widget>[
          // Поле ввода — как у составителя сообщения.
          TextField(
            key: const ValueKey('composer'),
            controller: TextEditingController(text: 'a 🧿 b'),
            style: DType.body.copyWith(color: Colors.white),
          ),
          // Черновик в списке чатов — `RichText`: стиля по умолчанию нет.
          RichText(
            key: const ValueKey('draft'),
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'Draft: ',
                  style: DType.preview.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '🧊', style: DType.preview),
              ],
            ),
          ),
          // Семейства нет на машине (просмотр .txt — `monospace`): основным
          // шрифтом Noto стать не должен, иначе пробелы — шириной с эмодзи.
          const Text(
            'a b 🧿',
            key: ValueKey('missing'),
            style: TextStyle(fontFamily: 'SecretlyNoSuchFamily', fontSize: 20),
          ),
        ],
      )));
      await t.pump();
      _expectNoto(find.byKey(const ValueKey('composer')), '🧿');
      _expectNoto(find.byKey(const ValueKey('draft')), '🧊');
      _expectNoto(find.byKey(const ValueKey('missing')), '🧿');
      // Ширину пробела тут не замерить: в тестах любое незнакомое семейство
      // отвечает тестовым шрифтом, «нет на машине» не бывает. Поэтому
      // проверяем то, из чего это следует на Windows: перед Noto в списке
      // стоит Manrope — он вшит в сборку и найдётся всегда.
      final missing = t.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('missing')),
          matching: find.byType(RichText),
        ),
      );
      expect(
        missing.text.style!.fontFamilyFallback,
        <String>[DType.family, kDesktopEmojiFontFamily],
      );
    });

    testWidgets('Windows: отдельное окно ОС (звонок, уведомление) — Noto и '
        'вне Material', (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      await t.pumpWidget(DesktopChildWindowApp(
        locale: const Locale('en'),
        resolveLocale: (_) => const Locale('en'),
        home: ColoredBox(
          color: kDColorsDark.bg,
          child: Column(
            children: <Widget>[
              // Самодельный стиль, как у подписей экрана звонка.
              const Text(
                '🧿',
                key: ValueKey('adhoc'),
                style: TextStyle(fontFamily: DType.family, fontSize: 20),
              ),
              // Карточка уведомления.
              Text('🧊', key: const ValueKey('card'), style: DType.caption),
            ],
          ),
        ),
      ));
      await t.pump();
      _expectNoto(find.byKey(const ValueKey('adhoc')), '🧿');
      _expectNoto(find.byKey(const ValueKey('card')), '🧊');
    });

    testWidgets('лист самотеста: строки «тема» и «кусок DType» рисуют Noto, '
        '«как было» — нет; размер листа совпадает с геометрией разбора',
        (t) async {
      DesktopEmojiFont.debugWindowsOverride = true;
      final key = GlobalKey();
      await t.pumpWidget(DesktopEmojiSelftestApp(boundaryKey: key));
      final box = key.currentContext!.findRenderObject()! as RenderBox;
      expect(box.size.width, EmojiSelftestGeometry.width);
      expect(box.size.height, EmojiSelftestGeometry.height);
      final sheet = find.byType(DesktopEmojiSelftestSheet);
      for (final emoji in kEmojiSelftestSamples) {
        final widths = _emojiWidths(sheet, emoji);
        expect(widths.length, EmojiSelftestRow.values.length);
        for (final row in EmojiSelftestRow.values) {
          final (got, noto) = widths[row.index];
          if (row == EmojiSelftestRow.system) {
            expect((got - noto).abs(), greaterThan(0.5), reason: '$emoji ${row.label}');
          } else {
            expect(got, _closeToWidth(noto), reason: '$emoji ${row.label}');
          }
        }
      }
    });
  });

  group('самотест: разбор снимка', () {
    const bg = 0x80;
    final size = EmojiSelftestGeometry.cell.round();

    Uint8List blank() {
      final img = Uint8List(EmojiSelftestGeometry.width * EmojiSelftestGeometry.height * 4);
      for (var i = 0; i < img.length; i += 4) {
        img[i] = bg;
        img[i + 1] = bg;
        img[i + 2] = bg;
        img[i + 3] = 255;
      }
      return img;
    }

    /// Круг радиуса [r] в клетке: [paint] даёт цвет пикселя по координатам.
    void disc(Uint8List img, EmojiSelftestRow row, int sample,
        List<int> Function(int x, int y) paint, {int r = 28}) {
      final (ox, oy) = EmojiSelftestGeometry.cellOrigin(row, sample);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final dx = x - 48, dy = y - 48;
          if (dx * dx + dy * dy > r * r) continue;
          final c = paint(x, y);
          final i = ((oy + y) * EmojiSelftestGeometry.width + ox + x) * 4;
          img[i] = c[0];
          img[i + 1] = c[1];
          img[i + 2] = c[2];
        }
      }
    }

    List<int> yellow(int x, int y) => y > 60 ? <int>[120, 60, 20] : <int>[250, 200, 40];
    List<int> blue(int x, int y) => <int>[30, 90, 230];
    List<int> black(int x, int y) => <int>[10, 10, 10];

    Uint8List sheet({
      List<int> Function(int, int)? theme,
      List<int> Function(int, int)? dtype,
      List<int> Function(int, int)? noto,
      List<int> Function(int, int)? system,
    }) {
      final img = blank();
      for (var s = 0; s < kEmojiSelftestSamples.length; s++) {
        if (theme != null) disc(img, EmojiSelftestRow.theme, s, theme);
        if (dtype != null) disc(img, EmojiSelftestRow.dtypeSpan, s, dtype);
        if (noto != null) disc(img, EmojiSelftestRow.noto, s, noto);
        if (system != null) disc(img, EmojiSelftestRow.system, s, system);
      }
      return img;
    }

    test('цветной знак — «цветной», пусто — «пусто», чёрный — «не цветной»', () {
      final img = sheet(theme: yellow, dtype: black);
      final w = EmojiSelftestGeometry.width;
      final coloured = emojiCellStats(
          img, w, EmojiSelftestGeometry.cellOrigin(EmojiSelftestRow.theme, 0), size);
      expect(coloured.inkFraction, greaterThan(0.2));
      expect(coloured.colourfulFraction, greaterThan(0.9));
      expect(coloured.hueBuckets, greaterThanOrEqualTo(1));
      final mono = emojiCellStats(
          img, w, EmojiSelftestGeometry.cellOrigin(EmojiSelftestRow.dtypeSpan, 0), size);
      expect(mono.inkFraction, greaterThan(0.2));
      expect(mono.colourfulFraction, 0);
      final empty = emojiCellStats(
          img, w, EmojiSelftestGeometry.cellOrigin(EmojiSelftestRow.noto, 0), size);
      expect(empty.ink, 0);
      expect(empty.box, isNull);
    });

    test('всё как надо — да', () {
      final v = judgeEmojiSelftest(
        sheet(theme: yellow, dtype: yellow, noto: yellow, system: blue),
        EmojiSelftestGeometry.width,
        registered: true,
      );
      expect(v.ok, isTrue, reason: v.lines.join('\n'));
    });

    test('движок не знает семейство — нет', () {
      final v = judgeEmojiSelftest(
        sheet(theme: yellow, dtype: yellow, noto: yellow, system: blue),
        EmojiSelftestGeometry.width,
        registered: false,
      );
      expect(v.ok, isFalse);
    });

    test('пузырь рисует не Noto (запасной шрифт потерялся) — нет', () {
      final v = judgeEmojiSelftest(
        sheet(theme: yellow, dtype: blue, noto: yellow, system: blue),
        EmojiSelftestGeometry.width,
        registered: true,
      );
      expect(v.ok, isFalse);
      expect(v.lines.join('\n'), contains('not the Noto glyph'));
    });

    test('картинки не нарисованы (пусто) — нет', () {
      final v = judgeEmojiSelftest(
        sheet(system: blue),
        EmojiSelftestGeometry.width,
        registered: true,
      );
      expect(v.ok, isFalse);
      expect(v.lines.join('\n'), contains('empty or not coloured'));
    });

    test('одноцветный контур или заглушка — нет', () {
      final v = judgeEmojiSelftest(
        sheet(theme: black, dtype: black, noto: black, system: blue),
        EmojiSelftestGeometry.width,
        registered: true,
      );
      expect(v.ok, isFalse);
    });

    test('картинка в родном размере файла, а не в кегле, — нет', () {
      final img = sheet(noto: yellow, system: blue);
      for (var s = 0; s < kEmojiSelftestSamples.length; s++) {
        disc(img, EmojiSelftestRow.theme, s, yellow, r: 47);
        disc(img, EmojiSelftestRow.dtypeSpan, s, yellow, r: 47);
        disc(img, EmojiSelftestRow.noto, s, yellow, r: 47);
      }
      final v = judgeEmojiSelftest(img, EmojiSelftestGeometry.width,
          registered: true);
      expect(v.ok, isFalse);
      expect(v.lines.join('\n'), contains('wrong glyph size'));
    });

    test('Noto рисует так же, как система, — доказательства нет', () {
      final v = judgeEmojiSelftest(
        sheet(theme: yellow, dtype: yellow, noto: yellow, system: yellow),
        EmojiSelftestGeometry.width,
        registered: true,
      );
      expect(v.ok, isFalse);
      expect(v.lines.join('\n'), contains('Noto draws like the system font'));
    });
  });
}
