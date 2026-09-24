// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../version/app_package_info.dart';

/// Найденная новая версия — то, что нужно кнопке «Обновить».
@immutable
class DesktopUpdateOffer {
  const DesktopUpdateOffer({
    required this.version,
    this.build,
    this.downloadUrl,
  });

  /// Версия для человека: «1.8.56».
  final String version;
  final int? build;

  /// Только Windows: откуда скачать новый архив. На macOS ставит Sparkle.
  final String? downloadUrl;

  @override
  bool operator ==(Object other) =>
      other is DesktopUpdateOffer &&
      other.version == version &&
      other.build == build &&
      other.downloadUrl == downloadUrl;

  @override
  int get hashCode => Object.hash(version, build, downloadUrl);
}

/// Обновление приложения, скачанного с сайта.
///
/// На macOS — тонкая сторона Flutter к `Runner/SparkleBridge.swift`: там
/// живёт и сама проверка, и её окна. На Windows Sparkle нет — там служба сама
/// читает перечень версий и, найдя новее, предлагает скачать архив.
///
/// 🔴 КНОПКА «ОБНОВИТЬ» (24.09.2026, указание владельца). Суточная проверка
/// Sparkle показывала окно, только когда сама решала проверить; нашедший
/// обновление человек в остальное время о нём не знал. Теперь служба тихо
/// спрашивает про новую версию при запуске и раз в четыре часа, и найденная
/// версия ложится в [available] — по нему внизу окна рядом с «Синхронизировано»
/// появляется кнопка.
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

  /// Почему её нет, если её нет. Для раздела «О программе» и для журнала —
  /// молчаливое «не работает» не даёт ни починить, ни объяснить.
  String? lastError;

  bool _loaded = false;
  Timer? _first;
  Timer? _periodic;

  /// Sparkle — только macOS.
  static bool get supported => !kIsWeb && Platform.isMacOS;

  /// Своя проверка перечня — Windows: установщика там нет, но знать о новой
  /// версии человек должен.
  static bool get windowsFeed => !kIsWeb && Platform.isWindows;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
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
  /// Windows установщика нет — новый архив скачивается в браузере.
  Future<void> install() async {
    if (supported) return check();
    final url = available.value?.downloadUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      lastError = '$e';
    }
  }

  @visibleForTesting
  void debugReset() {
    _first?.cancel();
    _periodic?.cancel();
    _loaded = false;
    available.value = null;
  }
}

/// Разбор перечня версий Windows. Открытая функция — чтобы проверять разбор
/// без сети.
///
/// Формат — тот же RSS Sparkle, что у macOS: `<item>` с `sparkle:version`
/// (номер сборки), `sparkle:shortVersionString` (версия для человека) и
/// `<enclosure url=…>`. Берётся самая новая запись; если она не новее
/// [currentBuild] — обновления нет.
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
    final url = RegExp(r'<enclosure[^>]*\burl="([^"]+)"').firstMatch(body)?.group(1);
    final parsed = url == null ? null : Uri.tryParse(url);
    final safe =
        parsed != null && parsed.scheme == 'https' && parsed.host == feedHost;
    if (!safe) continue;
    if (best == null || build > (best.build ?? 0)) {
      best = DesktopUpdateOffer(version: version, build: build, downloadUrl: url);
    }
  }
  if (best == null || (best.build ?? 0) <= currentBuild) return null;
  return best;
}
