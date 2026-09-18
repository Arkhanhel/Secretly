// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 ПОТОК МЕДИА ОТПУСКАЕТСЯ ОДНИМ ПРАВИЛОМ ВО ВСЕХ ПУТЯХ.
///
/// Play Console (стек владельца, 20.08.2026, версии 405 и 468):
/// `IllegalStateException: MediaStreamTrack has been disposed` внутри
/// `FlutterWebRTCPlugin.onDetachedFromEngine` → падение при уничтожении экрана.
///
/// Механизм: `track.stop()` уходит в плагин как `trackDispose` — он убирает
/// дорожку из своего реестра и уничтожает захватчик камеры, но САМ ПОТОК
/// остаётся в `localStreams` со ссылками на мёртвые дорожки. Мы обнуляли
/// только свою ссылку. При отсоединении движка плагин обходит реестр и зовёт
/// `track.id()` у мёртвой дорожки.
///
/// Правило: поток снимается с учёта, ПОКА дорожки живы (в плагине
/// `localStreams.remove()` стоит ПОСЛЕ обхода — бросок на полпути оставил бы
/// запись навсегда). Проверяется проводка: голых циклов `track.stop()` по
/// потоку остаться не должно — поведенческий тест этого не ловит, потому что
/// правило верное, а применено не везде.
void main() {
  test('🔴 нет ни одного пути, отпускающего поток в обход правила', () {
    final src =
        File('lib/calls/webrtc_call_session.dart').readAsStringSync();

    // Голый цикл остановки дорожек ПОТОКА — признак пути в обход правила.
    // Тело самого правила исключаем: запасной цикл там и должен быть.
    final ruleStart =
        src.indexOf('Future<void> _retireStream(MediaStream? s) async {');
    expect(ruleStart, greaterThan(0));
    final ruleEnd = src.indexOf('\n  }', ruleStart);
    final outsideRule =
        src.substring(0, ruleStart) + src.substring(ruleEnd);

    final bare = RegExp(
      r'for \(final track in \w+\.getTracks\(\)\) \{\s*try \{\s*track\.stop\(\);',
    ).allMatches(outsideRule).length;

    expect(
      bare,
      0,
      reason: 'найден путь, гасящий дорожки без снятия потока с учёта плагина '
          '— это и есть падение при уничтожении экрана',
    );

    expect(
      src.contains('Future<void> _retireStream(MediaStream? s) async {'),
      isTrue,
      reason: 'правило обязано жить в ОДНОМ месте',
    );
    expect(
      '_retireStream('.allMatches(src).length,
      greaterThanOrEqualTo(6),
      reason: 'правило применяется во всех путях: разговор, откат видео, '
          'показ экрана и оба его пути отказа',
    );
  });

  test('🔴 внутри правила снятие с учёта идёт ПЕРЕД остановкой дорожек', () {
    final src =
        File('lib/calls/webrtc_call_session.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _retireStream(MediaStream? s) async {');
    expect(start, greaterThan(0));
    final body = src.substring(
      start,
      (start + 700).clamp(0, src.length),
    );
    expect(
      body.indexOf('await s.dispose();'),
      lessThan(body.indexOf('track.stop();')),
      reason: 'обратный порядок возвращает ровно тот сбой: плагин не успеет '
          'снять поток с учёта и споткнётся о мёртвую дорожку',
    );
  });
}
