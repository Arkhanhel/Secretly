// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// «Всё уже в чате при открытии» — порядок и трактовка догоняющих сообщений.
//
// Разбор 16.08 (docs/AUDIT_INSTANT_INBOX_2026-08-16.md) нашёл главное: ночную
// почту мы применяли ПОСЛЕ сетевого запроса. Самое быстрое, что есть — готовые
// байты на диске от расширения уведомлений — ждало самого медленного: сети,
// которая на холодном старте ещё поднимается. Отсюда «сообщения приходят как
// новые»: они не приходят, они проявляются позже сети.
//
// Обе операции локальные (импорт читает файлы, переигровка расшифровывает из
// базы), поэтому им ничто не мешает идти первыми.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/app/app_controller.dart').readAsStringSync();

  test('локальное применяется раньше сети', () {
    final importAt = source.indexOf('await _importStagedNseInbox();');
    final replayAt = source.indexOf('await _replayAllQuarantine();');
    final connectAt = source.indexOf('await _relay?.connect();');
    final pumpAt = source.indexOf('await _relay?.pumpInbox(force: true);');

    expect(importAt, greaterThan(0), reason: 'импорт стадированного пропал');
    expect(replayAt, greaterThan(0),
        reason: 'переигровка снова не ожидается — именно она превращает '
            'импортированные байты в сообщения на экране');
    expect(connectAt, greaterThan(0));
    expect(pumpAt, greaterThan(0));

    expect(importAt, lessThan(connectAt),
        reason: 'ночная почта снова ждёт подключения к сети');
    expect(replayAt, lessThan(pumpAt),
        reason: 'ночная почта снова ждёт сетевой выборки — это и есть '
            '«сообщения приходят как новые»');
  });

  test('догоняющее сообщение не звучит как живое', () {
    expect(source.contains('shouldInAppCue && !bannerIsBacklog'), isTrue,
        reason: 'звук и вибрация снова играют для вчерашних сообщений: баннер '
            'гасится, а звук нет — открытие после ночи отзванивает десяток раз');
    expect(source.contains('suppress_backlog_cue'), isTrue,
        reason: 'подавление звука должно быть видно в логе, иначе его не '
            'отличить от «звук выключен в настройках»');
  });

  test('живое сообщение по-прежнему звучит и всплывает', () {
    // Признак «догона» — общий для баннера и звука, и он ложен для сообщения,
    // пришедшего в давно открытое приложение.
    final start = source.indexOf('static bool shouldSuppressInAppBannerAsBacklog');
    expect(start, greaterThan(0));
    final body = source.substring(start, start + 900);
    expect(body.contains('withinResumeGrace || olderThanLiveWindow'), isTrue,
        reason: 'правило «догона» изменилось — проверьте, что живое сообщение '
            'не попало под подавление');
  });
}
