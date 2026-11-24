// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// П-1 / М5 (разбор медиа 22.11.2026): место снимка в пузыре ленты.
///
/// Почему мигало. Пузырь строил `FutureBuilder` с НОВЫМ запросом файла в
/// каждой сборке; пока шло скачивание, повторный запрос сразу отвечал
/// `null`, и знак скачивания (он рисовался только «пока запрос не ответил»)
/// пропадал после первой же перерисовки ленты, а превью меняло форму дерева
/// (`Stack` ↔ голое превью) и пересоздавалось — пустой кадр и повторный
/// декод. В конце скачивания ещё и перерисовывался весь чат.
///
/// Теперь: запрос файла один на ключ, пока он идёт ([InflightRequests]);
/// дерево одной формы во всех состояниях, превью под ключом; знак — по ходу
/// скачивания ([progress]), а не по ожиданию запроса.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Один запрос на ключ, пока он идёт: повторный вызов получает ТОТ ЖЕ
/// `Future`, а не новый (новый у `FutureBuilder` — сброс в «ожидание»).
/// Завершился — запись снимается, следующий вызов спросит заново.
class InflightRequests<T> {
  final Map<String, Future<T>> _byKey = <String, Future<T>>{};

  bool contains(String key) => _byKey.containsKey(key);

  Future<T> run(String key, Future<T> Function() start) {
    final existing = _byKey[key];
    if (existing != null) return existing;
    final future = start();
    _byKey[key] = future;
    void drop() {
      if (identical(_byKey[key], future)) _byKey.remove(key);
    }

    // Свой слушатель и для ошибки: снять запись и не оставить ошибку
    // «без обработчика», если пузырь успел уйти с экрана.
    unawaited(future.then<void>((_) => drop(), onError: (Object _) => drop()));
    return future;
  }
}

/// Место снимка: превью (под ключом [slotKey]) и поверх — знак скачивания
/// или «файла нет». Форма дерева не меняется ни при каком состоянии.
class ChatMediaFileSlot extends StatelessWidget {
  const ChatMediaFileSlot({
    super.key,
    required this.slotKey,
    required this.known,
    required this.load,
    required this.preview,
    required this.progressMark,
    required this.goneMark,
    required this.isGone,
    this.progress,
  });

  /// Обычно blobId.
  final Object slotKey;

  /// Файл, уже известный синхронно (память ленты) — тогда запроса нет.
  final File? known;

  /// Запрос файла; пока он идёт, должен отдавать ОДИН И ТОТ ЖЕ `Future`
  /// (см. [InflightRequests]).
  final Future<File?> Function() load;

  final Widget Function(File? file) preview;

  /// Ход скачивания: знак виден, пока значение не `null`.
  final ValueListenable<double?>? progress;
  final Widget Function(ValueListenable<double?> progress) progressMark;
  final Widget goneMark;
  final bool Function(Object? error) isGone;

  @override
  Widget build(BuildContext context) {
    final knownFile = known;
    return FutureBuilder<File?>(
      future: knownFile != null ? null : load(),
      initialData: knownFile,
      builder: (context, snapshot) {
        final file = knownFile ?? snapshot.data;
        final gone = file == null && isGone(snapshot.error);
        final p = progress;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            KeyedSubtree(
              key: ValueKey<Object>(slotKey),
              child: preview(file),
            ),
            Positioned.fill(
              child: gone
                  ? goneMark
                  : (p == null ? const SizedBox.shrink() : progressMark(p)),
            ),
          ],
        );
      },
    );
  }
}
