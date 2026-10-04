// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ОБОИ НА ПК (28.09.2026, владелец: «нет обоев всех, которые есть в
// мобильной версии» и «внутри чата нельзя поменять обои сугубо для этого
// чата»).
//
// Было: список ПК собран руками — без «Классики», `chat_default`, фото из
// профиля и серверных; пять светлых обоев не открывались (путь без
// `improved_light/`); обоев для отдельного чата не было вовсе, хотя телефон
// давно пишет их ключом `chat_wallpaper_v1_<чат>`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support_public_tree.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/chat_wallpapers.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_wallpaper_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _ru = lookupAppLocalizations(const Locale('ru'));

/// Все обои, что лежат в приложении, — как их отдаст манифест ассетов.
List<String> bundledOnDisk() {
  final out = <String>[];
  for (final dir in ['assets/Background', 'assets/Background/improved_light']) {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final name = f.path.split('/').last.toLowerCase();
      if (name.endsWith('.jpg') || name.endsWith('.png')) {
        out.add(f.path.replaceAll('\\', '/'));
      }
    }
  }
  return out..sort();
}

void main() {
  group('набор — как у телефона', () {
    test('тёмная тема: Классика, Ночной, живые, тёмные картинки', () {
      final choices = buildDesktopWallpaperChoices(
        l10n: _ru,
        dark: true,
        bundledAssets: bundledOnDisk(),
      );
      final ids = choices.map((c) => c.id).toList();
      expect(ids.take(2), ['default', 'midnight']);
      expect(choices.firstWhere((c) => c.id == 'default').title, 'Классика');
      expect(
        ids.where(isAnimatedChatWallpaperId).length,
        WallpaperStyles.all.length,
      );
      final assets = ids.where(isAssetChatWallpaperId).toList();
      expect(assets, isNotEmpty);
      for (final id in assets) {
        expect(isDarkThemeChatWallpaperAssetPath(decodeAssetChatWallpaperId(id)!),
            isTrue,
            reason: 'в тёмной теме — только тёмные картинки, как у телефона');
      }
      expect(
        assets.any((id) => id.endsWith('/chat_default.jpg')),
        isTrue,
        reason: '«Стандартные» на ПК не было',
      );
      // Живые — платные.
      expect(
        choices.where((c) => isAnimatedChatWallpaperId(c.id)).every((c) => c.premium),
        isTrue,
      );
    }, skip: skipInPublicTree('картинок обоев'));

    test('🔴 светлая тема: пять светлых обоев — существующие файлы', () {
      final choices = buildDesktopWallpaperChoices(
        l10n: _ru,
        dark: false,
        bundledAssets: bundledOnDisk(),
      );
      final light = choices
          .map((c) => decodeAssetChatWallpaperId(c.id))
          .whereType<String>()
          .toList();
      expect(light.where((p) => p.contains('wallpaper_light_')).length, 5);
      for (final path in light) {
        expect(File(path).existsSync(), isTrue,
            reason: '$path — раньше путь строился без improved_light/');
      }
    }, skip: skipInPublicTree('картинок обоев'));

    test('каждая плитка-картинка — файл из сборки', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/Background/'));
      expect(pubspec, contains('- assets/Background/improved_light/'));
      for (final dark in [true, false]) {
        for (final c in buildDesktopWallpaperChoices(
          l10n: _ru,
          dark: dark,
          bundledAssets: bundledOnDisk(),
        )) {
          final path = decodeAssetChatWallpaperId(c.id);
          if (path == null) continue;
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('для чата первым — «Как в настройках»; фото профиля и серверные', () {
      final tmp = File('${Directory.systemTemp.path}/sly_wall_test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      addTearDown(() => tmp.deleteSync());
      final choices = buildDesktopWallpaperChoices(
        l10n: _ru,
        dark: true,
        bundledAssets: const <String>[],
        profileFiles: [tmp.path, '/нет/такого.jpg'],
        server: const [(id: 'w1', title: 'Космос')],
        includeGlobal: true,
      );
      expect(choices.first.id, kGlobalChatWallpaperSelectionId);
      expect(choices.first.title, 'Как в настройках');
      expect(
        choices.where((c) => isFileChatWallpaperId(c.id)).single.title,
        'Фото 1',
        reason: 'пропавший файл в список не попадает',
      );
      final server = choices.singleWhere((c) => isServerChatWallpaperId(c.id));
      expect(server.title, 'Космос');
      expect(server.premium, isTrue);
    });
  });

  group('обои отдельного чата', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_wallpaper_v1_peer-1': 'midnight',
        'chat_wallpaper_v1_peer-2': 'мусор',
      });
      DesktopChatWallpapers.resetForTest();
    });

    test('читается ключ телефона; испорченное значение — «как в настройках»',
        () async {
      await DesktopChatWallpapers.load();
      expect(DesktopChatWallpapers.selectionFor('peer-1'), 'midnight');
      expect(
        DesktopChatWallpapers.selectionFor('peer-2'),
        kGlobalChatWallpaperSelectionId,
      );
      expect(
        DesktopChatWallpapers.selectionFor('peer-3'),
        kGlobalChatWallpaperSelectionId,
      );
    });

    test('выбор пишется тем же ключом, «как в настройках» — снимает его',
        () async {
      await DesktopChatWallpapers.load();
      final before = DesktopChatWallpapers.revision.value;
      await DesktopChatWallpapers.set('peer-3', 'default');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_wallpaper_v1_peer-3'), 'default');
      expect(DesktopChatWallpapers.revision.value, greaterThan(before),
          reason: 'открытая переписка перерисовывается сразу');
      await DesktopChatWallpapers.set('peer-3', kGlobalChatWallpaperSelectionId);
      expect(prefs.getString('chat_wallpaper_v1_peer-3'), isNull);
    });

    test('платные без подписки — общие, выбор чата не стирается', () {
      expect(
        desktopEffectiveChatWallpaperId(
          chatSelection: 'server:w1',
          globalId: 'midnight',
          usable: (id) => !isServerChatWallpaperId(id),
        ),
        'midnight',
      );
      expect(
        desktopEffectiveChatWallpaperId(
          chatSelection: kGlobalChatWallpaperSelectionId,
          globalId: 'midnight',
          usable: (_) => true,
        ),
        'midnight',
      );
      expect(
        desktopEffectiveChatWallpaperId(
          chatSelection: 'default',
          globalId: 'midnight',
          usable: (_) => true,
        ),
        'default',
      );
    });
  });

  group('🔴 подключено', () {
    test('переписка рисует обои своего чата и перерисовывается при выборе', () {
      final src = File('lib/ui/desktop/app/desktop_chats_section.dart')
          .readAsStringSync();
      expect(src, contains('DesktopChatWallpapers.selectionFor(_convoId)'));
      expect(
        src,
        contains('DesktopChatWallpapers.revision.addListener(_onChatWallpaperChanged)'),
      );
      expect(src, contains('label: l10n.desktopChatWallpaperMenu'));
    });

    test('прежний default ПК один раз переводится в свою картинку', () {
      final app = File('lib/ui/desktop/app/desktop_production_app.dart')
          .readAsStringSync();
      expect(app, contains('_migrateDesktopDefaultWallpaper()'));
      expect(app, contains("'desktop_wallpaper_default_migrated_v1'"));
    });
  });
}
