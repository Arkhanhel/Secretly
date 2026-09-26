// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Лицензии зависимостей против того, что о них написано в документах.
//
// 🔴 ЗАЧЕМ (26.09.2026). NOTICE и CONTRIBUTING год утверждали, что сборка
// FFmpeg с суффиксом `-gpl` «сознательно не используется», — а она стояла в
// приложении с самого начала. Нашёл это не мы, а сторонний разбор перед
// подачей в фонд; проверка лицензий, которую для NLnet делает FSFE, нашла бы
// то же самое. Расхождение документа с кодом в лицензиях — не опечатка: на
// нём держится коммерческая половина модели и право выкладывать приложение в
// магазины.
//
// Поэтому теперь не человек следит за текстом, а тест: он читает настоящую
// зависимость из pubspec и требует, чтобы документы называли её своим именем.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Пакеты FFmpegKit, которые тянут за собой GPL (x264, x265, vid.stab,
/// xvidcore). Остальные варианты — LGPL.
const _gplFfmpegPackages = <String>{
  'ffmpeg_kit_flutter_new', // это и есть full-gpl, несмотря на имя
  'ffmpeg_kit_flutter_new_min_gpl',
  'ffmpeg_kit_flutter_new_https_gpl',
  'ffmpeg_kit_flutter_new_video_gpl',
  'ffmpeg_kit_flutter_new_full_gpl',
};

void main() {
  // Читаем pubspec построчно, без пакета yaml: он не в зависимостях
  // приложения, а тянуть его сюда ради четырёх строк незачем.
  final ffmpeg = File('pubspec.yaml')
      .readAsLinesSync()
      .map((l) => RegExp(r'^  (ffmpeg_kit_[a-z_0-9]+):').firstMatch(l)?.group(1))
      .whereType<String>()
      .toList();
  // 🔴 ДВЕ РАСКЛАДКИ. В рабочем репозитории публичные документы лежат в
  // `docs/public/`, а скрипт выкладки раскладывает их в корень публичного
  // репозитория. Тест обязан находить их в обоих: иначе он зелен дома и красен
  // у аудитора — на этом уже падала проверка 23.09.2026.
  String readPublicDoc(String name) {
    for (final path in ['../../../docs/public/$name', '../../../$name']) {
      final f = File(path);
      if (f.existsSync()) return f.readAsStringSync();
    }
    fail('не найден публичный документ $name ни в одной из раскладок');
  }

  final notice = readPublicDoc('NOTICE');
  final contributing = readPublicDoc('CONTRIBUTING.md');

  test('пакет FFmpeg в приложении ровно один — иначе непонятно, чья лицензия',
      () {
    expect(ffmpeg, hasLength(1), reason: 'найдено: $ffmpeg');
  });

  test('🔴 NOTICE называет лицензию FFmpeg так, как есть на самом деле', () {
    final isGpl = _gplFfmpegPackages.contains(ffmpeg.single);
    if (isGpl) {
      // Пока стоит GPL-сборка, NOTICE обязан это признавать.
      expect(
        notice.contains('full-gpl'),
        isTrue,
        reason: 'в приложении GPL-сборка FFmpeg, а NOTICE о ней молчит',
      );
      expect(
        notice.contains('General Public License'),
        isTrue,
        reason: 'NOTICE не называет лицензию, под которой мы раздаём FFmpeg',
      );
      expect(
        RegExp(r'-gpl.{0,80}(not used|deliberately not)', dotAll: true)
            .hasMatch(notice),
        isFalse,
        reason: 'NOTICE снова утверждает, что GPL-сборка не используется',
      );
    } else {
      // Перешли на LGPL — документы не должны пугать GPL задним числом.
      expect(
        notice.contains('x264'),
        isFalse,
        reason: 'x264 остался в NOTICE, хотя пакет уже без него',
      );
    }
  });

  test('🔴 CONTRIBUTING не запрещает то, что стоит в самом приложении', () {
    final isGpl = _gplFfmpegPackages.contains(ffmpeg.single);
    final forbids = RegExp(r'`-gpl`[^.]{0,60}cannot be used').hasMatch(
      contributing,
    );
    expect(
      isGpl && forbids,
      isFalse,
      reason: 'правило для чужих людей строже, чем то, что мы сделали сами',
    );
  });

  test('сборка для Windows берёт тот же вариант FFmpeg, что и остальные', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final variant = RegExp(r'set\(FFMPEGKIT_VARIANT "([^"]+)"').firstMatch(cmake);
    expect(variant, isNotNull, reason: 'вариант для Windows задаётся явно');
    final isGpl = _gplFfmpegPackages.contains(ffmpeg.single);
    expect(
      variant!.group(1)!.endsWith('-gpl'),
      isGpl,
      reason: 'Windows собирается с другой лицензией, чем телефон',
    );
  });
}
