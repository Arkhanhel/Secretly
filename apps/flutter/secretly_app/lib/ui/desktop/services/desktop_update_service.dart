// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert' show base64Decode, jsonDecode, jsonEncode;
import 'dart:io'
    show Directory, File, HttpException, Platform, Process, ProcessStartMode;
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../../diagnostics/diag_log.dart';
import '../../../version/app_package_info.dart';
import 'pe_version.dart';

/// Открытый ключ EdDSA, которым подписаны обновления, — тот же, что
/// `SUPublicEDKey` у Sparkle на Mac (`macos/Runner/Info.plist`; тест сверяет,
/// что они не разошлись). Это открытая половина ключа, ей место в коде.
/// Закрытая хранится только у владельца.
const String kDesktopUpdatePublicKeyB64 =
    'D9ZGqnx7HEv5Qe6TYKXxd/Zf9dxkONCfy8J7rmuz3Ks=';

/// Как запускается проверенный установщик Windows (Inno Setup,
/// `windows/installer/secretly.iss`): без окон, закрыть старую копию, после
/// установки открыть новую. Аргументы — здесь, а не в перечне версий:
/// подменённый перечень не должен вписать установщику свои ключи.
const List<String> kWindowsSilentInstallArgs = [
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/CLOSEAPPLICATIONS',
  '/LAUNCH=1',
];

/// Куда вести человека, если само обновиться не вышло.
const String kDesktopDownloadPageUrl = 'https://www.secretlyapp.com/download';

/// Больше этого установщик не бывает; поле `length` в перечне — не повод
/// скачивать гигабайты.
const int kWindowsInstallerMaxBytes = 400 * 1024 * 1024;

/// Найденная новая версия — то, что нужно кнопке «Обновить».
@immutable
class DesktopUpdateOffer {
  const DesktopUpdateOffer({
    required this.version,
    this.build,
    this.downloadUrl,
    this.edSignature,
    this.length,
  });

  /// Версия для человека: «1.8.56».
  final String version;
  final int? build;

  /// Только Windows: откуда скачать новую версию. На macOS ставит Sparkle.
  final String? downloadUrl;

  /// Подпись EdDSA файла из перечня (`sparkle:edSignature`), base64.
  final String? edSignature;

  /// Размер файла в байтах из перечня.
  final int? length;

  /// Установщик, который можно поставить из приложения: `.exe` с подписью
  /// и размером. Всё остальное (старые записи с архивом) открывается в
  /// браузере, как раньше.
  bool get isWindowsInstaller {
    final url = downloadUrl?.toLowerCase() ?? '';
    return url.endsWith('.exe') &&
        (edSignature ?? '').isNotEmpty &&
        (length ?? 0) > 0 &&
        length! <= kWindowsInstallerMaxBytes;
  }

  @override
  bool operator ==(Object other) =>
      other is DesktopUpdateOffer &&
      other.version == version &&
      other.build == build &&
      other.downloadUrl == downloadUrl &&
      other.edSignature == edSignature &&
      other.length == length;

  @override
  int get hashCode =>
      Object.hash(version, build, downloadUrl, edSignature, length);
}

/// Этап обновления на Windows — для кнопки.
enum DesktopUpdatePhase { downloading, verifying, launching, failed }

/// Почему обновление на Windows не встало.
enum DesktopUpdateFailure {
  /// Скачать не вышло: нет связи, ошибка сервера, файл больше заявленного.
  download,

  /// Размер или подпись не сошлись — файл удалён и не запускался.
  verification,

  /// Установщик не запустился.
  launch,

  /// Установщик запускали, но после него работает прежняя версия.
  notInstalled,
}

/// Итог последней попытки обновиться на Windows — для строки «Обновление не
/// установилось: …» в настройках.
@immutable
class DesktopUpdateAttempt {
  const DesktopUpdateAttempt({
    required this.version,
    this.build,
    this.failure,
  });

  /// Какую версию ставили: «1.8.63».
  final String version;
  final int? build;

  /// `null` — встала.
  final DesktopUpdateFailure? failure;

  bool get succeeded => failure == null;
}

@immutable
class DesktopUpdateProgress {
  const DesktopUpdateProgress(this.phase, {this.fraction});

  final DesktopUpdatePhase phase;

  /// 0..1, только пока идёт загрузка.
  final double? fraction;
}

/// Обновление приложения, скачанного с сайта.
///
/// На macOS — тонкая сторона Flutter к `Runner/SparkleBridge.swift`: там
/// живёт и сама проверка, и её окна. На Windows Sparkle нет — там служба сама
/// читает перечень версий и, найдя новее, предлагает обновиться.
///
/// 🔴 КНОПКА «ОБНОВИТЬ» (24.09.2026, указание владельца). Суточная проверка
/// Sparkle показывала окно, только когда сама решала проверить; нашедший
/// обновление человек в остальное время о нём не знал. Теперь служба тихо
/// спрашивает про новую версию при запуске и раз в четыре часа, и найденная
/// версия ложится в [available] — по нему внизу окна рядом с «Синхронизировано»
/// появляется кнопка.
///
/// 🔴 УСТАНОВЩИК НА WINDOWS (26.09.2026, указание владельца: «чтобы человек
/// одной кнопкой установил»). Если в перечне установщик `.exe` с подписью,
/// кнопка скачивает его сама, сверяет размер и подпись EdDSA тем же ключом,
/// что Sparkle на Mac, запускает тихую установку и закрывает приложение —
/// установщик ставит новую версию поверх и открывает её. Файл, не прошедший
/// проверку, удаляется и НЕ запускается: вместо него — страница загрузки.
/// Скачанный самим приложением файл не несёт пометки «из интернета», поэтому
/// SmartScreen при обновлении не вмешивается; первый раз человек ставит
/// установщик с сайта.
///
/// 🔴 ПОКА НЕ НАСТРОЕНО — ПУНКТА МЕНЮ НЕТ. Обновлятору нужны адрес перечня
/// версий и открытый ключ, которым проверяется подпись пакета; пока их не
/// положили в Info.plist, [configured] остаётся `false`, и «Проверить
/// обновления» в меню не появляется. Пункт, который отвечает «не настроено»,
/// — это обещание, которого некому сдержать, а в меню такие обещания читаются
/// как поломка приложения.
class DesktopUpdateService {
  DesktopUpdateService._();

  static final DesktopUpdateService instance = DesktopUpdateService._();

  static const MethodChannel _channel = MethodChannel('secretly/updates');

  /// Перечень версий для Windows — в том же формате, что у Sparkle на Mac.
  static const String windowsFeedUrl = String.fromEnvironment(
    'SECRETLY_WINDOWS_UPDATE_FEED',
    defaultValue: 'https://updates.secretlyapp.com/appcast-windows.xml',
  );

  /// Есть ли у приложения рабочая проверка обновлений (меню на Mac).
  final ValueNotifier<bool> configured = ValueNotifier<bool>(false);

  /// Найденная новая версия; `null` — версия свежая или ещё не проверяли.
  final ValueNotifier<DesktopUpdateOffer?> available =
      ValueNotifier<DesktopUpdateOffer?>(null);

  /// Идёт ли установка на Windows и на каком она этапе; `null` — не идёт.
  final ValueNotifier<DesktopUpdateProgress?> progress =
      ValueNotifier<DesktopUpdateProgress?>(null);

  /// Почему её нет, если её нет. Для раздела «О программе» и для журнала —
  /// молчаливое «не работает» не даёт ни починить, ни объяснить.
  String? lastError;

  /// 🔴 Итог последней попытки обновиться на Windows (30.09.2026). Неудача
  /// была видна только кнопкой «Скачать с сайта» до перезапуска, а установщик,
  /// не сумевший встать, не оставлял следа вовсе. Отказ до запуска
  /// установщика ложится сюда сразу; удачу или неудачу самого установщика
  /// служба узнаёт при следующем запуске — по отметке, записанной перед ним.
  final ValueNotifier<DesktopUpdateAttempt?> lastAttempt =
      ValueNotifier<DesktopUpdateAttempt?>(null);

  /// Подмены для тестов: скачивание, запуск установщика, выход, ключ.
  @visibleForTesting
  Future<File> Function(
    Uri url,
    int expectedLength,
    void Function(double fraction) onProgress,
  )? debugDownloader;

  @visibleForTesting
  Future<void> Function(String path, List<String> args)? debugLauncher;

  @visibleForTesting
  Future<void> Function()? debugQuit;

  @visibleForTesting
  Future<void> Function(Uri url)? debugOpenUrl;

  @visibleForTesting
  String? debugPublicKeyB64;

  /// Тесты идут на Mac, где кнопка ведёт в Sparkle; этим флагом они
  /// проверяют путь Windows.
  @visibleForTesting
  bool debugWindowsPath = false;

  /// Папка скачанных установщиков и номер работающей сборки — для тестов.
  @visibleForTesting
  static Directory? debugDownloadDir;

  @visibleForTesting
  int? debugCurrentBuild;

  static const String _pendingFileName = 'pending-update.json';

  bool _loaded = false;
  Timer? _first;
  Timer? _periodic;

  /// Sparkle — только macOS.
  static bool get supported => !kIsWeb && Platform.isMacOS;

  /// Своя проверка перечня — Windows.
  static bool get windowsFeed => !kIsWeb && Platform.isWindows;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    if (windowsFeed) await settlePreviousAttempt();
    if (supported) {
      _channel.setMethodCallHandler(_onNative);
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('status');
        configured.value = (res?['configured'] as bool?) ?? false;
        lastError = res?['error'] as String?;
      } catch (e) {
        configured.value = false;
        lastError = '$e';
      }
    }
    if (supported || windowsFeed) {
      // Не в первую секунду: запуск и так занят ключами, реле и базой.
      _first = Timer(const Duration(seconds: 20), () => unawaited(probe()));
      _periodic = Timer.periodic(
        const Duration(hours: 4),
        (_) => unawaited(probe()),
      );
    }
  }

  Future<dynamic> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'updateAvailable':
        final args = (call.arguments as Map?) ?? const {};
        final version = '${args['version'] ?? ''}'.trim();
        if (version.isEmpty) return null;
        available.value = DesktopUpdateOffer(
          version: version,
          build: int.tryParse('${args['build'] ?? ''}'),
        );
      case 'noUpdate':
        available.value = null;
    }
    return null;
  }

  /// Тихо спросить, есть ли новее.
  Future<void> probe() async {
    if (supported) {
      try {
        await _channel.invokeMethod<void>('probe');
      } catch (e) {
        lastError = '$e';
      }
      return;
    }
    if (windowsFeed) await _probeWindowsFeed();
  }

  Future<void> _probeWindowsFeed() async {
    // Пока ставится одно обновление, перечень его не подменяет.
    if (progress.value != null) return;
    try {
      final uri = Uri.parse(windowsFeedUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final current = int.tryParse(AppPackageInfo.buildNumberFromEnv) ?? 0;
      available.value = parseWindowsFeed(
        res.body,
        currentBuild: current,
        feedHost: uri.host,
      );
    } catch (e) {
      // Нет связи — не повод для шума: следующая проверка через четыре часа.
      lastError = '$e';
    }
  }

  /// Проверить с окнами (пункт меню «Проверить обновления…»).
  Future<void> check() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('check');
    } catch (e) {
      lastError = '$e';
    }
  }

  /// Нажатие «Обновить».
  ///
  /// На Mac — окно Sparkle: скачает, проверит подпись EdDSA и поставит. На
  /// Windows — установщик из перечня: скачать, проверить, поставить тихо; для
  /// старых записей с архивом — архив в браузере. После неудачи кнопка ведёт
  /// на страницу загрузки.
  Future<void> install() async {
    if (supported && !debugWindowsPath) return check();
    final current = progress.value;
    if (current != null) {
      if (current.phase == DesktopUpdatePhase.failed) {
        await _open(Uri.parse(kDesktopDownloadPageUrl));
      }
      return;
    }
    final offer = available.value;
    final url = offer?.downloadUrl;
    if (offer == null || url == null) return;
    if (offer.isWindowsInstaller) {
      await _installWindowsSetup(offer);
      return;
    }
    await _open(Uri.parse(url));
  }

  /// «Повторить» у строки «Обновление не установилось: …» в настройках
  /// (01.10.2026).
  ///
  /// Неудача оставляет кнопку внизу в состоянии «Скачать с сайта», а после
  /// перезапуска найденной версии может ещё не быть — поэтому здесь: снять
  /// прежний итог, при нужде заново спросить перечень и поставить найденное
  /// тем же путём, что кнопка «Обновить». Ставить нечего (перечень молчит) —
  /// честно ведём на страницу загрузки, а не делаем вид, что повторили.
  Future<void> retry() async {
    final current = progress.value;
    // Установка уже идёт — второй не начинаем.
    if (current != null && current.phase != DesktopUpdatePhase.failed) return;
    progress.value = null;
    lastAttempt.value = null;
    if (available.value?.downloadUrl == null) {
      await (debugProbe ?? probe)();
    }
    final offer = available.value;
    if (offer == null || offer.downloadUrl == null) {
      await _open(Uri.parse(kDesktopDownloadPageUrl));
      return;
    }
    await install();
  }

  /// Подмена опроса перечня для проверки «Повторить».
  @visibleForTesting
  Future<void> Function()? debugProbe;

  /// Подмена чтения версии установщика — для проверок, где файл не PE.
  @visibleForTesting
  Future<PeFileVersion?> Function(String path)? debugInstallerVersionReader;

  /// Номер работающей сборки — для защиты от отката. Берётся больший из
  /// двух: dart-define релизного скрипта и ресурс версии собственного `.exe`
  /// (`--build-number` сборки). Больший — строже: откат на сборку между ними
  /// не пройдёт.
  Future<int> _runningBuild() async {
    final forced = debugCurrentBuild;
    if (forced != null) return forced;
    final fromEnv = int.tryParse(AppPackageInfo.buildNumberFromEnv) ?? 0;
    final fromExe =
        (await readPeFileVersion(Platform.resolvedExecutable))?.build ?? 0;
    return fromEnv > fromExe ? fromEnv : fromExe;
  }

  Future<void> _installWindowsSetup(DesktopUpdateOffer offer) async {
    File? file;
    var failure = DesktopUpdateFailure.download;
    try {
      progress.value = const DesktopUpdateProgress(
        DesktopUpdatePhase.downloading,
        fraction: 0,
      );
      await _purgeDownloads();
      file = await (debugDownloader ?? _download)(
        Uri.parse(offer.downloadUrl!),
        offer.length!,
        (fraction) => progress.value = DesktopUpdateProgress(
          DesktopUpdatePhase.downloading,
          fraction: fraction.clamp(0.0, 1.0),
        ),
      );
      failure = DesktopUpdateFailure.verification;
      progress.value =
          const DesktopUpdateProgress(DesktopUpdatePhase.verifying);
      final ok = await verifyUpdateFile(
        file,
        signatureB64: offer.edSignature!,
        expectedLength: offer.length!,
        publicKeyB64: debugPublicKeyB64 ?? kDesktopUpdatePublicKeyB64,
      );
      if (!ok) {
        throw const _UpdateRejected('signature or size mismatch');
      }
      // 🔴 ЗАЩИТА ОТ ОТКАТА (01.10.2026). Подписью заверены только БАЙТЫ
      // файла, а номер сборки брался из перечня, который не подписан. Значит,
      // подменённый по дороге перечень мог подсунуть наш же, честно
      // подписанный, но СТАРЫЙ установщик — с дырами, закрытыми с тех пор.
      // Номер теперь читается из ресурса версии самого файла (его ставит
      // `VersionInfoVersion` в `windows/installer/secretly.iss`), то есть из
      // заверенных байтов, и установщик запускается, только если он строго
      // новее работающей сборки. Нет ресурса версии — отказ, а не «наверное,
      // можно».
      final installed = await (debugInstallerVersionReader ??
          readPeFileVersion)(file.path);
      final running = await _runningBuild();
      if (installed == null || installed.build <= running) {
        DiagLog.event('update', 'installer_not_newer', {
          'installer': installed?.build,
          'running': running,
          'feed': offer.build,
        });
        throw _UpdateRejected(
          'installer build ${installed?.build} is not newer than $running',
        );
      }
      failure = DesktopUpdateFailure.launch;
      progress.value =
          const DesktopUpdateProgress(DesktopUpdatePhase.launching);
      // Итог установщика станет известен только после перезапуска.
      await _downloadDir.create(recursive: true);
      // Номер — заверенный, из самого файла, а не из перечня.
      await _pendingFile.writeAsString(
        jsonEncode({'version': offer.version, 'build': installed.build}),
      );
      await (debugLauncher ?? _launchDetached)(
        file.path,
        kWindowsSilentInstallArgs,
      );
    } catch (e) {
      lastError = '$e';
      _record(DesktopUpdateAttempt(
        version: offer.version,
        build: offer.build,
        failure: failure,
      ));
      progress.value = const DesktopUpdateProgress(DesktopUpdatePhase.failed);
      try {
        await _pendingFile.delete();
      } catch (_) {}
      final f = file;
      if (f != null) {
        try {
          await f.delete();
        } catch (_) {}
      }
      return;
    }
    // Установщик уже идёт: прежние скачанные файлы больше не нужны.
    await _purgeDownloads(keep: file.path);
    try {
      // Закрываемся сами: крестик окна у нас прячет в трей, и установщик
      // иначе упёрся бы в занятые файлы.
      await (debugQuit ?? _quitForUpdate)();
    } catch (e) {
      // Установщик закроет окно сам (/CLOSEAPPLICATIONS) — это не неудача.
      lastError = '$e';
    }
  }

  /// Windows, при запуске: итог прошлой попытки обновиться — по отметке,
  /// записанной перед установщиком, — и уборка скачанных установщиков.
  @visibleForTesting
  Future<void> settlePreviousAttempt() async {
    final marker = _pendingFile;
    try {
      if (await marker.exists()) {
        final data = jsonDecode(await marker.readAsString());
        final build = data is Map ? data['build'] : null;
        final version = data is Map ? '${data['version'] ?? ''}' : '';
        final current = debugCurrentBuild ??
            int.tryParse(AppPackageInfo.buildNumberFromEnv) ??
            0;
        _record(DesktopUpdateAttempt(
          version: version,
          build: build is int ? build : null,
          failure: build is int && current >= build
              ? null
              : DesktopUpdateFailure.notInstalled,
        ));
      }
    } catch (_) {
      // Испорченная отметка — просто без итога.
    }
    try {
      await marker.delete();
    } catch (_) {}
    await _purgeDownloads();
  }

  void _record(DesktopUpdateAttempt attempt) {
    lastAttempt.value = attempt;
    DiagLog.event('update', 'attempt', {
      'ok': attempt.succeeded,
      'reason': attempt.failure?.name ?? '-',
      'build': attempt.build,
    });
  }

  static Directory get _downloadDir =>
      debugDownloadDir ??
      Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}secretly-update',
      );

  static File get _pendingFile => File(
        '${_downloadDir.path}${Platform.pathSeparator}$_pendingFileName',
      );

  /// 🔴 Скачанные установщики копились во временной папке (30.09.2026): по
  /// одному на каждое обновление, десятки мегабайт. Убираются все `.exe`,
  /// кроме [keep]; запущенный сейчас установщик Windows удалить не даст — его
  /// уберёт следующий запуск.
  static Future<void> _purgeDownloads({String? keep}) async {
    final dir = _downloadDir;
    try {
      if (!await dir.exists()) return;
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File || entry.path == keep) continue;
        if (!entry.path.toLowerCase().endsWith('.exe')) continue;
        try {
          await entry.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _open(Uri uri) async {
    try {
      final open = debugOpenUrl;
      if (open != null) {
        await open(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      lastError = '$e';
    }
  }

  static Future<File> _download(
    Uri uri,
    int expectedLength,
    void Function(double fraction) onProgress,
  ) async {
    final dir = _downloadDir;
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}${windowsInstallerFileName(uri)}',
    );
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
      }
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk
            in res.stream.timeout(const Duration(seconds: 60))) {
          received += chunk.length;
          if (received > expectedLength) {
            throw const _UpdateRejected('file is larger than announced');
          }
          sink.add(chunk);
          onProgress(received / expectedLength);
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close();
    }
  }

  static Future<void> _launchDetached(String path, List<String> args) async {
    await Process.start(path, args, mode: ProcessStartMode.detached);
  }

  /// Выход тем же путём, что и «Выйти» в трее.
  static Future<void> _quitForUpdate() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @visibleForTesting
  void debugReset() {
    _first?.cancel();
    _periodic?.cancel();
    _loaded = false;
    available.value = null;
    progress.value = null;
    debugDownloader = null;
    debugLauncher = null;
    debugQuit = null;
    debugOpenUrl = null;
    debugProbe = null;
    debugInstallerVersionReader = null;
    debugPublicKeyB64 = null;
    debugWindowsPath = false;
    debugDownloadDir = null;
    debugCurrentBuild = null;
    lastAttempt.value = null;
  }
}

class _UpdateRejected implements Exception {
  const _UpdateRejected(this.reason);

  final String reason;

  @override
  String toString() => 'update rejected: $reason';
}

/// Имя файла установщика для временной папки: только из последней части
/// адреса, только безопасные символы, всегда `.exe`.
@visibleForTesting
String windowsInstallerFileName(Uri uri) {
  final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final safe = last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safe.isEmpty || !safe.toLowerCase().endsWith('.exe')) {
    return 'Secretly-Setup.exe';
  }
  return safe;
}

/// Сверить скачанный файл с перечнем: размер и подпись EdDSA (Ed25519 над
/// байтами файла — так подписывает `sign_update` из Sparkle). Считается в
/// отдельном изоляте: файл в десятки мегабайт не должен замораживать окно.
Future<bool> verifyUpdateFile(
  File file, {
  required String signatureB64,
  required int expectedLength,
  String publicKeyB64 = kDesktopUpdatePublicKeyB64,
}) {
  final path = file.path;
  return Isolate.run(() async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length != expectedLength) return false;
      final signature = base64Decode(signatureB64.trim());
      final publicKey = base64Decode(publicKeyB64.trim());
      if (signature.length != 64 || publicKey.length != 32) return false;
      return await Ed25519().verify(
        bytes,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  });
}

/// Разбор перечня версий Windows. Открытая функция — чтобы проверять разбор
/// без сети.
///
/// Формат — тот же RSS Sparkle, что у macOS: `<item>` с `sparkle:version`
/// (номер сборки), `sparkle:shortVersionString` (версия для человека) и
/// `<enclosure url=… length=… sparkle:edSignature=…>`. Берётся самая новая
/// запись; если она не новее [currentBuild] — обновления нет.
///
/// 🔴 Ссылка на скачивание принимается ТОЛЬКО с того же адреса, что и сам
/// перечень: подменённый по дороге перечень не должен уводить человека
/// качать «обновление» с чужого сайта.
DesktopUpdateOffer? parseWindowsFeed(
  String xml, {
  required int currentBuild,
  required String feedHost,
}) {
  final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml);
  DesktopUpdateOffer? best;
  for (final m in items) {
    final body = m.group(1)!;
    String? tag(String name) =>
        RegExp('<sparkle:$name>\\s*([^<]+?)\\s*</sparkle:$name>')
            .firstMatch(body)
            ?.group(1) ??
        RegExp('sparkle:$name="([^"]+)"').firstMatch(body)?.group(1);
    final build = int.tryParse(tag('version') ?? '');
    if (build == null) continue;
    final version = (tag('shortVersionString') ?? '$build').trim();
    final enclosure = RegExp(r'<enclosure\b[^>]*>').firstMatch(body)?.group(0);
    if (enclosure == null) continue;
    String? attr(String name) =>
        RegExp('(?:^|\\s)$name="([^"]+)"').firstMatch(enclosure)?.group(1);
    final url = attr('url');
    final parsed = url == null ? null : Uri.tryParse(url);
    final safe =
        parsed != null && parsed.scheme == 'https' && parsed.host == feedHost;
    if (!safe) continue;
    if (best == null || build > (best.build ?? 0)) {
      best = DesktopUpdateOffer(
        version: version,
        build: build,
        downloadUrl: url,
        edSignature: attr('sparkle:edSignature'),
        length: int.tryParse(attr('length') ?? ''),
      );
    }
  }
  if (best == null || (best.build ?? 0) <= currentBuild) return null;
  return best;
}
