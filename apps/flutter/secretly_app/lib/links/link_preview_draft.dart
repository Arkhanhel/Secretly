// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/link_preview_v1.dart';
import 'link_preview_fetch.dart';
import 'link_preview_policy.dart';

/// Загрузка превью по адресу. В приложении — [LinkPreviewFetcher.fetch].
typedef LinkPreviewLoader = Future<LinkPreviewV1?> Function(Uri uri);

/// Превью ссылки, которую человек сейчас набирает, — для поля ввода.
///
/// Поле ввода сообщает каждый новый текст ([update]); черновик следит за
/// ПЕРВОЙ ссылкой в нём, выжидает паузу (человек ещё печатает) и грузит
/// превью в фоне. На отправке [takeFor] отдаёт готовое превью ровно для этого
/// текста — или ничего, если оно не успело, не удалось или его закрыли.
///
/// 🔴 ОТПРАВКА ПРЕВЬЮ НЕ ЖДЁТ. Не успело — сообщение уходит без карточки, как
/// в Signal. Задерживать отправку ради картинки значило бы перепутать порядок
/// сообщений, отправленных одно за другим.
class OutgoingLinkPreviewDraft extends ChangeNotifier {
  OutgoingLinkPreviewDraft({
    LinkPreviewLoader? loader,
    this.debounce = const Duration(milliseconds: 400),
  }) : _loader = loader ?? LinkPreviewFetcher.fetch;

  final LinkPreviewLoader _loader;

  /// Пауза в наборе, после которой начинается загрузка.
  final Duration debounce;

  static const int _cacheMax = 24;

  /// Загруженные превью — только удачные. Сбой не запоминается: сеть могла
  /// моргнуть, и та же ссылка через минуту загрузится.
  final Map<String, LinkPreviewV1> _ready = <String, LinkPreviewV1>{};

  /// Ссылки, чью карточку человек закрыл в ЭТОМ сообщении.
  final Set<String> _dismissed = <String>{};

  Uri? _target;
  bool _loading = false;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Ссылка, для которой сейчас готовится карточка.
  Uri? get target => _target;

  /// Готовая карточка для текущей ссылки, если её не закрыли.
  LinkPreviewV1? get preview {
    final key = _target?.toString();
    if (key == null || _dismissed.contains(key)) return null;
    return _ready[key];
  }

  /// Страница грузится прямо сейчас.
  ///
  /// Только после паузы в наборе, не раньше: пока ссылку набирают по буквам,
  /// каждая буква — новый адрес, и полоска «грузится» мигала бы на каждом
  /// нажатии.
  bool get loading => _loading;

  /// Новый текст поля ввода.
  void update(String text) {
    final next = linkPreviewTargetFor(text);
    final key = next?.toString();
    if (key == _target?.toString()) return;
    _timer?.cancel();
    _generation++;
    _target = next;
    _loading = false;
    notifyListeners();
    if (next == null || _ready.containsKey(key) || _dismissed.contains(key)) {
      return;
    }
    final generation = _generation;
    _timer = Timer(debounce, () {
      if (_disposed || generation != _generation) return;
      _loading = true;
      notifyListeners();
      unawaited(_load(next, generation));
    });
  }

  Future<void> _load(Uri uri, int generation) async {
    final key = uri.toString();
    LinkPreviewV1? result;
    try {
      result = await _loader(uri);
    } catch (_) {
      result = null;
    }
    if (_disposed) return;
    // Карточка обязана быть от ТОЙ ЖЕ ссылки: иначе на отправке её отбросит
    // [linkPreviewForOutgoing], а до того человек видел бы чужую.
    if (result != null && result.url == key) _remember(key, result);
    // Пока грузилось, ссылка в поле сменилась — показывать нечего.
    if (generation != _generation) return;
    _loading = false;
    notifyListeners();
  }

  void _remember(String key, LinkPreviewV1 value) {
    _ready.remove(key);
    if (_ready.length >= _cacheMax) _ready.remove(_ready.keys.first);
    _ready[key] = value;
  }

  /// Человек закрыл карточку крестиком: в этом сообщении для этой ссылки её
  /// больше не показываем и не отправляем.
  void dismiss() {
    final key = _target?.toString();
    if (key == null) return;
    _dismissed.add(key);
    _timer?.cancel();
    _generation++;
    _loading = false;
    notifyListeners();
  }

  /// Превью, которое уходит вместе с [text]: готовое, не закрытое и для
  /// первой ссылки именно этого текста, в пределах размера сообщения.
  LinkPreviewV1? takeFor(String text) {
    final target = linkPreviewTargetFor(text);
    if (target == null) return null;
    final key = target.toString();
    if (_dismissed.contains(key)) return null;
    return linkPreviewForOutgoing(_ready[key], text);
  }

  /// Сообщение ушло — следующее начинается с чистого листа: закрытая
  /// крестиком карточка снова предлагается.
  void reset() {
    _timer?.cancel();
    _generation++;
    _target = null;
    _loading = false;
    _dismissed.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Превью СВОИХ сообщений, в которых карточки нет: написанных до того, как
/// превью стало ездить внутри сообщения, или отправленных, пока оно не
/// успело загрузиться.
///
/// 🔴 ТОЛЬКО СВОИ. Чужую ссылку устройство не открывает никогда — иначе
/// собеседник узнал бы адрес получателя, просто прислав ссылку на свой
/// сервер. Свою ссылку человек выбрал сам, и её страница о нём ничего нового
/// не узнает.
class LinkPreviewMemoryCache {
  LinkPreviewMemoryCache({LinkPreviewLoader? loader})
    : _loader = loader ?? LinkPreviewFetcher.fetch;

  /// Общий на приложение. Изменяемый только ради тестов: в них страницы не
  /// грузятся, и кэш подменяется заготовленным.
  static LinkPreviewMemoryCache instance = LinkPreviewMemoryCache();

  final LinkPreviewLoader _loader;

  static const int _max = 64;

  /// Неудачу не повторяем при каждой перерисовке пузыря, но и не хороним
  /// навсегда.
  static const Duration retryAfter = Duration(minutes: 5);

  final Map<String, LinkPreviewV1> _ready = <String, LinkPreviewV1>{};
  final Map<String, Future<LinkPreviewV1?>> _inflight =
      <String, Future<LinkPreviewV1?>>{};
  final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// Уже загруженное — сразу, чтобы карточка появилась в том же кадре, что
  /// и пузырь.
  LinkPreviewV1? peek(Uri uri) => _ready[uri.toString()];

  Future<LinkPreviewV1?> get(Uri uri) {
    final key = uri.toString();
    final ready = _ready[key];
    if (ready != null) return SynchronousFuture<LinkPreviewV1?>(ready);
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < retryAfter) {
      return SynchronousFuture<LinkPreviewV1?>(null);
    }
    final running = _inflight[key];
    if (running != null) return running;
    final future = _load(uri, key);
    _inflight[key] = future;
    // Колбэки будущего всегда идут позже, даже если оно уже завершилось, —
    // так запись не останется висеть при мгновенном отказе.
    unawaited(future.whenComplete(() => _inflight.remove(key)));
    return future;
  }

  Future<LinkPreviewV1?> _load(Uri uri, String key) async {
    LinkPreviewV1? result;
    try {
      result = await _loader(uri);
    } catch (_) {
      result = null;
    }
    if (result == null || result.url != key) {
      _failedAt[key] = DateTime.now();
      return null;
    }
    _failedAt.remove(key);
    _ready.remove(key);
    if (_ready.length >= _max) _ready.remove(_ready.keys.first);
    _ready[key] = result;
    return result;
  }

  @visibleForTesting
  void clear() {
    _ready.clear();
    _inflight.clear();
    _failedAt.clear();
  }

  @visibleForTesting
  static void resetInstance() => instance = LinkPreviewMemoryCache();
}
