// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// ГОНКА ДВУХ ЗАГРУЗОК ОДНОГО ВЛОЖЕНИЯ (найдено 02.09.2026, аудит передачи
/// файлов).
///
/// Дедупликация была разбросана по вызывающим, и у каждого своя: отдельный
/// набор у предзагрузки, отдельный у ленты сообщений, отдельный у просмотра
/// изображений — а галерея чата и её настольный вариант не имели никакой.
/// Наборы не пересекались, поэтому предзагрузка и открытие пузыря спокойно
/// начинали качать один блоб одновременно.
///
/// Хуже, что расшифрованное писалось во временный файл с ПРЕДСКАЗУЕМЫМ именем
/// `<blobId><расширение>.tmp` — один и тот же для обоих потоков. Содержимое
/// перемешивалось, и тот, кто добирался до переименования вторым, падал.
///
/// Проверяется точная копия ветвления из `ensureCachedAttachmentFile`:
/// поднимать ради этого контроллер целиком — значит тянуть базу, сеть и
/// платформенные каналы.
class _DedupHarness {
  final Map<String, Future<String>> _inflight = <String, Future<String>>{};

  int downloadsStarted = 0;
  final List<Completer<String>> pending = <Completer<String>>[];

  bool get isIdle => _inflight.isEmpty;

  Future<String> ensure(String blobId) async {
    final key = blobId.trim();
    if (key.isEmpty) {
      return _startDownload();
    }
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final future = _startDownload();
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<String> _startDownload() {
    downloadsStarted++;
    final completer = Completer<String>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  group('дедупликация загрузок вложений', () {
    test('🔴 два одновременных запроса дают ОДНУ загрузку', () async {
      final h = _DedupHarness();

      final a = h.ensure('blob-1');
      final b = h.ensure('blob-1');

      expect(
        h.downloadsStarted,
        1,
        reason: 'предзагрузка и открытие пузыря запускались параллельно и '
            'писали в один временный файл — ровно этот случай портил файл',
      );

      h.pending.single.complete('/cache/blob-1.jpg');
      expect(await a, '/cache/blob-1.jpg');
      expect(await b, '/cache/blob-1.jpg', reason: 'оба ждут один результат');
    });

    test('разные вложения качаются независимо', () async {
      final h = _DedupHarness();
      final a = h.ensure('blob-1');
      final b = h.ensure('blob-2');

      expect(h.downloadsStarted, 2);
      h.pending[0].complete('/cache/blob-1.jpg');
      h.pending[1].complete('/cache/blob-2.jpg');
      expect(await a, '/cache/blob-1.jpg');
      expect(await b, '/cache/blob-2.jpg');
    });

    test('🔴 после успеха ключ освобождается', () async {
      final h = _DedupHarness();
      final first = h.ensure('blob-1');
      h.pending.single.complete('/cache/blob-1.jpg');
      await first;

      expect(
        h.isIdle,
        isTrue,
        reason: 'иначе повторное открытие того же вложения вернуло бы '
            'завершённый результат вместо новой проверки кэша',
      );
    });

    test('🔴 после ОШИБКИ ключ тоже освобождается', () async {
      final h = _DedupHarness();
      final first = h.ensure('blob-1');
      h.pending.single.completeError(StateError('сеть отвалилась'));
      await expectLater(first, throwsA(isA<StateError>()));

      expect(
        h.isIdle,
        isTrue,
        reason: 'без снятия записи в finally провалившаяся загрузка навсегда '
            'заняла бы ключ: повтор возвращал бы ту же ошибку, и вложение '
            'стало бы недоступно до перезапуска приложения',
      );

      // Повтор обязан начать новую загрузку, а не вернуть старую ошибку.
      final second = h.ensure('blob-1');
      expect(h.downloadsStarted, 2);
      h.pending.last.complete('/cache/blob-1.jpg');
      expect(await second, '/cache/blob-1.jpg');
    });

    test('пустой идентификатор не дедуплицируется', () async {
      final h = _DedupHarness();
      final a = h.ensure('');
      final b = h.ensure('');
      expect(
        h.downloadsStarted,
        2,
        reason: 'без идентификатора склеивать нечего — общий ключ склеил бы '
            'разные вложения в одно',
      );
      h.pending[0].complete('/a');
      h.pending[1].complete('/b');
      await a;
      await b;
    });
  });
}
