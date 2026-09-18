// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_wallpapers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'themeStandardChatWallpaperId uses improved light secure2 and dark secure12',
    () {
      expect(
        themeStandardChatWallpaperId(darkMode: false),
        encodeAssetChatWallpaperId(kLightThemeStandardChatWallpaperAssetPath),
      );
      expect(
        themeStandardChatWallpaperId(darkMode: true),
        encodeAssetChatWallpaperId(kDarkThemeStandardChatWallpaperAssetPath),
      );
    },
  );

  testWidgets(
    'wallpaper options keep solids and filter image entries by theme',
    (WidgetTester tester) async {
      late List<ChatWallpaperOption> lightOptions;
      late List<ChatWallpaperOption> darkOptions;
      late List<Color> lightSolidColors;
      late List<Color> darkSolidColors;

      const darkAsset = '${kBundledChatWallpaperAssetRoot}secure7.png';
      const lightAsset = '${kLightThemeChatWallpaperAssetRoot}secure7.png';
      const assetPaths = <String>[lightAsset, darkAsset];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              lightOptions = buildChatWallpaperOptions(
                context,
                assetPaths: assetPaths,
                includeGlobalOption: false,
              );
              lightSolidColors = themedLightSolidChatWallpaperColors(context);
              darkSolidColors = themedDarkSolidChatWallpaperColors(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(lightOptions.take(2).map((option) => option.id).toList(), <String>[
        'default',
        'midnight',
      ]);
      expect(lightOptions[0].colors, lightSolidColors);
      expect(lightOptions[1].colors, darkSolidColors);
      expect(
        lightOptions.skip(2).map((option) => option.id),
        contains(encodeAssetChatWallpaperId(lightAsset)),
      );
      expect(
        lightOptions.skip(2).map((option) => option.id),
        isNot(contains(encodeAssetChatWallpaperId(darkAsset))),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData.dark(),
            child: Builder(
              builder: (context) {
                darkOptions = buildChatWallpaperOptions(
                  context,
                  assetPaths: assetPaths,
                  includeGlobalOption: false,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(darkOptions.take(2).map((option) => option.id).toList(), <String>[
        'default',
        'midnight',
      ]);
      expect(
        darkOptions.skip(2).map((option) => option.id),
        contains(encodeAssetChatWallpaperId(darkAsset)),
      );
      expect(
        darkOptions.skip(2).map((option) => option.id),
        isNot(contains(encodeAssetChatWallpaperId(lightAsset))),
      );
    },
  );

  test('themedChatWallpaperAssetPath maps image wallpapers between themes', () {
    const darkAsset = '${kBundledChatWallpaperAssetRoot}secure5.jpg';
    const lightAsset = '${kLightThemeChatWallpaperAssetRoot}secure5.jpg';

    expect(
      themedChatWallpaperAssetPath(darkAsset, darkMode: false),
      lightAsset,
    );
    expect(themedChatWallpaperAssetPath(lightAsset, darkMode: true), darkAsset);
    expect(themedChatWallpaperAssetPath(darkAsset, darkMode: true), darkAsset);
    expect(
      themedChatWallpaperAssetPath(lightAsset, darkMode: false),
      lightAsset,
    );
  });

  testWidgets('built-in solid wallpaper colors follow the selected theme', (
    WidgetTester tester,
  ) async {
    Future<List<Color>> captureLightColors(Color seedColor) async {
      late List<Color> colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: seedColor).copyWith(
              primaryContainer: seedColor,
              secondaryContainer: Color.lerp(seedColor, Colors.white, 0.35),
            ),
          ),
          home: Builder(
            builder: (context) {
              colors = buildChatWallpaperOptions(
                context,
                assetPaths: const <String>[],
                includeGlobalOption: false,
              ).first.colors!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return colors;
    }

    final blueColors = await captureLightColors(Colors.blue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final greenColors = await captureLightColors(Colors.green);

    expect(blueColors, isNot(equals(greenColors)));
    expect(
      blueColors,
      isNot(
        equals(<Color>[
          kLightSolidChatWallpaperColor,
          kLightSolidChatWallpaperColor,
        ]),
      ),
    );
  });

  test(
    'file-backed wallpaper ids are valid only while the file exists',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'secretly_chat_wallpapers_',
      );
      addTearDown(() {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}profile_bg.png',
      );
      await file.writeAsBytes(const <int>[0x89, 0x50, 0x4E, 0x47]);

      final encoded = encodeFileChatWallpaperId(file.path);

      expect(isValidChatWallpaperId(encoded), isTrue);
      expect(decodeFileChatWallpaperId(encoded), file.path);

      await file.delete();

      expect(isValidChatWallpaperId(encoded), isFalse);
      expect(decodeFileChatWallpaperId(encoded), isNull);
    },
  );

  testWidgets('buildChatWallpaperOptions includes profile background files', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'secretly_chat_wallpapers_options_',
    );
    addTearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });
    final file = File('${tempDir.path}${Platform.pathSeparator}sunset_mix.png');
    file.writeAsBytesSync(const <int>[0x89, 0x50, 0x4E, 0x47]);

    late List<ChatWallpaperOption> options;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Builder(
            builder: (context) {
              options = buildChatWallpaperOptions(
                context,
                assetPaths: const <String>['assets/Background/aurora.jpg'],
                filePaths: <String>[file.path],
                includeGlobalOption: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      options.any(
        (option) => option.id == encodeFileChatWallpaperId(file.path),
      ),
      isTrue,
    );
    expect(
      options.any(
        (option) =>
            option.filePath == file.path && option.title == 'sunset mix',
      ),
      isTrue,
    );
  });
}
