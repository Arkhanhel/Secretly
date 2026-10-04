// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «ОБНОВЛЕНИЕ НЕ УСТАНОВИЛОСЬ: …» В НАСТРОЙКАХ (01.10.2026).
//
// 🔴 Итог попытки обновиться служба знала с 30.09, но на экране его не было:
// кнопка внизу превращалась в «Скачать с сайта» до перезапуска, а установщик,
// не сумевший встать, не оставлял следа вовсе. Здесь проверяется, что причина
// видна словами и что «Повторить» действительно повторяет.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_update_service.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url =
    'https://updates.secretlyapp.com/Secretly-Setup-1.8.63-642-x64.exe';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
    tmp = Directory.systemTemp.createTempSync('secretly-update-retry');
    DesktopUpdateService.debugDownloadDir = tmp;
  });

  tearDown(() {
    DesktopUpdateService.instance.debugReset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpAbout(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: AppController());
    addTearDown(vm.dispose);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: desktopMaterialTheme(kDColorsDark, dark: true),
        home: DColors(
          colors: kDColorsDark,
          child: Scaffold(
            body: SettingsWorkspace(vm: vm, initialSectionId: 'about'),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  test('у каждой причины есть слова на всех восьми языках', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final texts = {
        for (final f in DesktopUpdateFailure.values)
          desktopUpdateFailureText(l10n, f),
      };
      expect(texts, hasLength(DesktopUpdateFailure.values.length),
          reason: '$locale: две причины звучат одинаково');
      expect(texts.every((t) => t.trim().isNotEmpty), isTrue);
    }
  });

  testWidgets('🔴 неудача видна причиной, «Повторить» повторяет', (t) async {
    final service = DesktopUpdateService.instance;
    final opened = <Uri>[];
    var downloads = 0;
    service
      ..debugWindowsPath = true
      ..debugOpenUrl = ((u) async {
        opened.add(u);
      })
      ..debugProbe = () async {}
      ..debugDownloader = (url, length, onProgress) async {
        downloads++;
        throw const HttpException('503');
      };
    service.available.value = const DesktopUpdateOffer(
      version: '1.8.63',
      build: 642,
      downloadUrl: _url,
      edSignature: 'AAAA',
      length: 10,
    );
    service.lastAttempt.value = const DesktopUpdateAttempt(
      version: '1.8.63',
      build: 642,
      failure: DesktopUpdateFailure.verification,
    );
    service.progress.value =
        const DesktopUpdateProgress(DesktopUpdatePhase.failed);

    await pumpAbout(t);

    final line =
        ru.desktopUpdateAttemptFailed(ru.desktopUpdateFailureVerification);
    expect(line, startsWith('Обновление не установилось: '));
    expect(find.text(line), findsOneWidget);

    await t.runAsync(() async {
      await t.tap(find.text(ru.desktopUpdateRetry));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pump();

    // Повтор пошёл тем же путём, что «Обновить», а не на страницу загрузки.
    expect(downloads, 1);
    expect(opened, isEmpty);
    // Новый итог — новая причина на экране.
    expect(service.lastAttempt.value!.failure, DesktopUpdateFailure.download);
    await t.pump();
    expect(
      find.text(
        ru.desktopUpdateAttemptFailed(ru.desktopUpdateFailureDownload),
      ),
      findsOneWidget,
    );

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('без неудачи строки нет', (t) async {
    await pumpAbout(t);
    expect(find.text(ru.desktopUpdateRetry), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  test('ставить нечего — «Повторить» честно ведёт на страницу загрузки',
      () async {
    final service = DesktopUpdateService.instance;
    final opened = <Uri>[];
    var probed = 0;
    service
      ..debugWindowsPath = true
      ..debugOpenUrl = ((u) async {
        opened.add(u);
      })
      ..debugProbe = () async {
        probed++;
      };
    service.lastAttempt.value = const DesktopUpdateAttempt(
      version: '1.8.63',
      build: 642,
      failure: DesktopUpdateFailure.notInstalled,
    );

    await service.retry();

    expect(probed, 1, reason: 'после перезапуска перечень надо спросить');
    expect(opened.single.toString(), kDesktopDownloadPageUrl);
    expect(service.lastAttempt.value, isNull);
  });

  test('установка уже идёт — «Повторить» второй не начинает', () async {
    final service = DesktopUpdateService.instance;
    var probed = 0;
    service
      ..debugWindowsPath = true
      ..debugProbe = () async {
        probed++;
      };
    service.progress.value =
        const DesktopUpdateProgress(DesktopUpdatePhase.downloading);

    await service.retry();

    expect(probed, 0);
    expect(service.progress.value!.phase, DesktopUpdatePhase.downloading);
  });
}
