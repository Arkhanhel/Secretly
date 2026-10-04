// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Установщик Windows и обновление из приложения (26.09.2026, владелец: «чтобы
// с сайта скачивался не архив, а exe… одной кнопкой установил грамотно и
// профессионально»).
//
// Главное, что здесь сторожится:
// - файл, не прошедший проверку подписи EdDSA, НЕ запускается;
// - ключ проверки в приложении — тот же, что у Sparkle на Mac;
// - установщик ставится на пользователя, поверх себя, с тем же ярлыком для
//   уведомлений и не трогает данные человека.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_login_item_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_update_service.dart';

import 'support/synthetic_pe.dart';

String _feed({
  required String url,
  String? signature,
  int length = 1234,
  int build = 633,
}) =>
    '''<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <title>1.8.62</title>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>1.8.62</sparkle:shortVersionString>
      <enclosure url="$url" length="$length" type="application/octet-stream"${signature == null ? '' : ' sparkle:edSignature="$signature"'}/>
    </item>
  </channel>
</rss>''';

const _host = 'updates.secretlyapp.com';
const _setupUrl =
    'https://updates.secretlyapp.com/Secretly-Setup-1.8.62-633-x64.exe';

Future<({String publicKeyB64, String signatureB64})> _sign(
  List<int> bytes,
) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final signature = await algorithm.sign(bytes, keyPair: keyPair);
  final publicKey = await keyPair.extractPublicKey();
  return (
    publicKeyB64: base64Encode(publicKey.bytes),
    signatureB64: base64Encode(signature.bytes),
  );
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('secretly-installer-test');
    // Отметка попытки и уборка — во временной папке теста, не в системной.
    DesktopUpdateService.debugDownloadDir = Directory('${tmp.path}/dl');
  });

  tearDown(() {
    DesktopUpdateService.instance.debugReset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('перечень версий: установщик', () {
    test('установщик с подписью и размером — ставится из приложения', () {
      final offer = parseWindowsFeed(
        _feed(url: _setupUrl, signature: 'c2ln'),
        currentBuild: 631,
        feedHost: _host,
      );
      expect(offer, isNotNull);
      expect(offer!.build, 633);
      expect(offer.length, 1234);
      expect(offer.edSignature, 'c2ln');
      expect(offer.isWindowsInstaller, isTrue);
    });

    test('без подписи — не ставится сам, только открывается ссылка', () {
      final offer = parseWindowsFeed(
        _feed(url: _setupUrl),
        currentBuild: 631,
        feedHost: _host,
      );
      expect(offer!.isWindowsInstaller, isFalse);
    });

    test('старая запись с архивом — прежний путь через браузер', () {
      final offer = parseWindowsFeed(
        _feed(
          url: 'https://updates.secretlyapp.com/Secretly-1.8.61-631-windows-x64.zip',
          signature: 'c2ln',
          build: 632,
        ),
        currentBuild: 631,
        feedHost: _host,
      );
      expect(offer!.isWindowsInstaller, isFalse);
    });

    test('🔴 размер больше разумного — не ставится сам', () {
      final offer = parseWindowsFeed(
        _feed(url: _setupUrl, signature: 'c2ln', length: 2000000000),
        currentBuild: 631,
        feedHost: _host,
      );
      expect(offer!.isWindowsInstaller, isFalse);
    });

    test('🔴 установщик с чужого адреса не принимается вовсе', () {
      final offer = parseWindowsFeed(
        _feed(url: 'https://evil.example/Secretly-Setup.exe', signature: 'c2ln'),
        currentBuild: 631,
        feedHost: _host,
      );
      expect(offer, isNull);
    });
  });

  group('проверка файла', () {
    test('верная подпись и размер — принимается', () async {
      final bytes = utf8.encode('installer bytes ${'x' * 1000}');
      final keys = await _sign(bytes);
      final file = File('${tmp.path}/setup.exe')..writeAsBytesSync(bytes);
      expect(
        await verifyUpdateFile(
          file,
          signatureB64: keys.signatureB64,
          expectedLength: bytes.length,
          publicKeyB64: keys.publicKeyB64,
        ),
        isTrue,
      );
    });

    test('🔴 изменённый байт — отклоняется', () async {
      final bytes = utf8.encode('installer bytes ${'x' * 1000}');
      final keys = await _sign(bytes);
      final tampered = List<int>.of(bytes)..[5] ^= 1;
      final file = File('${tmp.path}/setup.exe')..writeAsBytesSync(tampered);
      expect(
        await verifyUpdateFile(
          file,
          signatureB64: keys.signatureB64,
          expectedLength: bytes.length,
          publicKeyB64: keys.publicKeyB64,
        ),
        isFalse,
      );
    });

    test('🔴 чужой ключ — отклоняется', () async {
      final bytes = utf8.encode('installer bytes');
      final keys = await _sign(bytes);
      final other = await _sign(bytes);
      final file = File('${tmp.path}/setup.exe')..writeAsBytesSync(bytes);
      expect(
        await verifyUpdateFile(
          file,
          signatureB64: keys.signatureB64,
          expectedLength: bytes.length,
          publicKeyB64: other.publicKeyB64,
        ),
        isFalse,
      );
    });

    test('🔴 размер не совпал — отклоняется до проверки подписи', () async {
      final bytes = utf8.encode('installer bytes');
      final keys = await _sign(bytes);
      final file = File('${tmp.path}/setup.exe')..writeAsBytesSync(bytes);
      expect(
        await verifyUpdateFile(
          file,
          signatureB64: keys.signatureB64,
          expectedLength: bytes.length + 1,
          publicKeyB64: keys.publicKeyB64,
        ),
        isFalse,
      );
    });

    test('имя временного файла — из адреса, только безопасные символы', () {
      expect(
        windowsInstallerFileName(Uri.parse(_setupUrl)),
        'Secretly-Setup-1.8.62-633-x64.exe',
      );
      expect(
        windowsInstallerFileName(
          Uri.parse('https://updates.secretlyapp.com/a%20b..%5C..%5Cx.exe'),
        ),
        isNot(contains(r'\')),
      );
      expect(
        windowsInstallerFileName(Uri.parse('https://updates.secretlyapp.com/x.zip')),
        'Secretly-Setup.exe',
      );
    });
  });

  group('кнопка «Обновить» на Windows', () {
    Future<({File file, String publicKeyB64, String signatureB64, int length})>
        signedSetup() async {
      // Настоящий (маленький) PE с ресурсом версии: с 01.10.2026 установщик
      // запускается, только если его собственный номер сборки новее.
      final bytes = buildSyntheticPe(
        major: 1,
        minor: 8,
        patch: 62,
        build: 633,
        padding: 4000,
      );
      final keys = await _sign(bytes);
      final file = File('${tmp.path}/Secretly-Setup-1.8.62-633-x64.exe')
        ..writeAsBytesSync(bytes);
      return (
        file: file,
        publicKeyB64: keys.publicKeyB64,
        signatureB64: keys.signatureB64,
        length: bytes.length,
      );
    }

    test('проверенный установщик запускается тихо, приложение закрывается',
        () async {
      final setup = await signedSetup();
      final service = DesktopUpdateService.instance
        ..debugWindowsPath = true
        ..debugPublicKeyB64 = setup.publicKeyB64;
      final launched = <List<String>>[];
      var quit = 0;
      service.debugDownloader = (url, length, onProgress) async {
        onProgress(1);
        return setup.file;
      };
      service.debugLauncher = (path, args) async => launched.add([path, ...args]);
      service.debugQuit = () async => quit++;
      service.available.value = DesktopUpdateOffer(
        version: '1.8.62',
        build: 633,
        downloadUrl: _setupUrl,
        edSignature: setup.signatureB64,
        length: setup.length,
      );

      await service.install();

      expect(launched, hasLength(1));
      expect(launched.single.first, setup.file.path);
      expect(launched.single.skip(1), kWindowsSilentInstallArgs);
      expect(kWindowsSilentInstallArgs, containsAll(['/VERYSILENT', '/LAUNCH=1']));
      expect(quit, 1);
      expect(service.progress.value?.phase, DesktopUpdatePhase.launching);
    });

    test('🔴 подпись не сошлась — установщик НЕ запускается, файл удалён, '
        'кнопка ведёт на страницу загрузки', () async {
      final setup = await signedSetup();
      final stranger = await _sign([1, 2, 3]);
      final service = DesktopUpdateService.instance
        ..debugWindowsPath = true
        ..debugPublicKeyB64 = stranger.publicKeyB64;
      final launched = <String>[];
      final opened = <Uri>[];
      var quit = 0;
      service.debugDownloader = (url, length, onProgress) async => setup.file;
      service.debugLauncher = (path, args) async => launched.add(path);
      service.debugQuit = () async => quit++;
      service.debugOpenUrl = (uri) async => opened.add(uri);
      service.available.value = DesktopUpdateOffer(
        version: '1.8.62',
        build: 633,
        downloadUrl: _setupUrl,
        edSignature: setup.signatureB64,
        length: setup.length,
      );

      await service.install();

      expect(launched, isEmpty);
      expect(quit, 0);
      expect(setup.file.existsSync(), isFalse);
      expect(service.progress.value?.phase, DesktopUpdatePhase.failed);
      expect(opened, isEmpty, reason: 'сама страница не открывается — только по нажатию');

      await service.install();
      expect(opened.single.toString(), kDesktopDownloadPageUrl);
      expect(launched, isEmpty);
    });

    test('ошибка скачивания — тоже «скачать с сайта», без запуска', () async {
      final service = DesktopUpdateService.instance..debugWindowsPath = true;
      final launched = <String>[];
      service.debugDownloader =
          (url, length, onProgress) async => throw const HttpException('503');
      service.debugLauncher = (path, args) async => launched.add(path);
      service.debugQuit = () async {};
      service.available.value = const DesktopUpdateOffer(
        version: '1.8.62',
        build: 633,
        downloadUrl: _setupUrl,
        edSignature: 'c2ln',
        length: 10,
      );

      await service.install();

      expect(launched, isEmpty);
      expect(service.progress.value?.phase, DesktopUpdatePhase.failed);
    });

    test('запись с архивом — открывается в браузере, как раньше', () async {
      final service = DesktopUpdateService.instance..debugWindowsPath = true;
      final opened = <Uri>[];
      final launched = <String>[];
      service.debugOpenUrl = (uri) async => opened.add(uri);
      service.debugLauncher = (path, args) async => launched.add(path);
      service.available.value = const DesktopUpdateOffer(
        version: '1.8.61',
        build: 631,
        downloadUrl:
            'https://updates.secretlyapp.com/Secretly-1.8.61-631-windows-x64.zip',
      );

      await service.install();

      expect(opened.single.path, endsWith('.zip'));
      expect(launched, isEmpty);
    });
  });

  test('🔴 ключ проверки в приложении — тот же, что SUPublicEDKey у Sparkle', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();
    final match = RegExp(r'<key>SUPublicEDKey</key>[\s\S]*?<string>([^<]+)</string>')
        .firstMatch(plist);
    expect(match, isNotNull);
    expect(match!.group(1)!.trim(), kDesktopUpdatePublicKeyB64);
  });

  group('сценарий установщика (windows/installer/secretly.iss)', () {
    final iss = File('windows/installer/secretly.iss').readAsStringSync();

    test('🔴 AppId постоянный — новая версия встаёт поверх, а не рядом', () {
      expect(iss, contains('AppId={{A475E0B8-A2A2-4298-B913-DDE939EEF2D5}'));
    });

    test('ставится на пользователя, без окна UAC; админ — через /ALLUSERS', () {
      expect(iss, contains('PrivilegesRequired=lowest'));
      expect(iss, contains('PrivilegesRequiredOverridesAllowed=commandline'));
      expect(iss, contains(r'DefaultDirName={autopf}\{#AppName}'));
    });

    test('одна кнопка: без выбора папки и страницы «готово»', () {
      expect(iss, contains('DisableDirPage=yes'));
      expect(iss, contains('DisableReadyPage=yes'));
    });

    test('ярлык на рабочем столе — по выбору, отмечен заранее', () {
      expect(
        iss,
        contains('Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"'),
      );
      expect(
        iss,
        contains(
          r'Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon',
        ),
      );
      // «unchecked» сделал бы ответом по умолчанию «без ярлыка».
      expect(iss.contains('Flags: unchecked'), isFalse);
    });

    test('🔴 удаление снимает автозапуск — тот, что пишет программа, и только свой',
        () {
      final i = iss.indexOf('procedure CurUninstallStepChanged');
      expect(i, greaterThan(0));
      final body = iss.substring(i);
      // Ключ и имя значения — те же, что у программы.
      expect(body, contains("'$kWindowsRunKeyPath', '$kWindowsRunValueName'"));
      expect(
        body,
        contains("RegDeleteValue(HKEY_CURRENT_USER, '$kWindowsRunKeyPath'"),
      );
      expect(
        body,
        contains("'$kWindowsStartupApprovedPath', '$kWindowsRunValueName'"),
      );
      // Переносная копия пишет то же имя со своим путём — её не трогаем.
      expect(body, contains(r"ExpandConstant('{app}\{#AppExe}')"));
    });

    test('номер сборки — четвёртой частью обеих версий файла', () {
      expect(iss, contains('VersionInfoVersion={#AppVersion}.{#AppBuild}'));
      expect(
        iss,
        contains('VersionInfoProductVersion={#AppVersion}.{#AppBuild}'),
      );
    });

    test('🔴 ярлык в «Пуске» с AppUserModelID "Secretly" — как у уведомлений', () {
      expect(
        iss,
        contains(
          r'Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Secretly"',
        ),
      );
    });

    test('тихое обновление открывает программу снова только по /LAUNCH=1', () {
      expect(iss, contains("ExpandConstant('{param:LAUNCH|0}') = '1'"));
      expect(iss, contains('Check: LaunchAfterSilentUpdate'));
      expect(iss, contains('CloseApplications=force'));
    });

    test('🔴 данные человека не удаляются: в [UninstallDelete] ничего нет', () {
      expect(iss.contains('[UninstallDelete]'), isFalse);
      expect(iss.contains('{userappdata}'), isFalse);
      expect(iss.contains('{localappdata}\\Yurii'), isFalse);
    });

    test('восемь языков интерфейса', () {
      for (final name in [
        'Default.isl',
        'Russian.isl',
        'Ukrainian.isl',
        'German.isl',
        'Spanish.isl',
        'French.isl',
        'Portuguese.isl',
        'BrazilianPortuguese.isl',
      ]) {
        expect(iss, contains(name));
      }
    });
  });
}
