// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Вкладка GIF в подборщике на компьютере.
///
/// 🔴 ЗДЕСЬ БЫЛА ЗАГЛУШКА «GIF-ПОИСК СКОРО» (до 16.09.2026).
///
/// Указание владельца: «сделай чтобы все эмодзи, гифки и т д работали
/// правильно в пк версии — в мобильной всё идеально работает». На телефоне
/// подборщик гифок живой и давно: с категориями-иконками, с поиском, который
/// умеет русский, с подгрузкой страниц и с недавними. Здесь же вкладка
/// открывалась и честно сообщала, что её нет.
///
/// Правила поиска взяты ОБЩИЕ, а не написаны заново: [gifQueryPlan] решает,
/// каким словом и на каком языке спрашивать (жалоба «поиск работает только на
/// английском» чинилась именно там), [fetchGifPage] ходит в GIPHY, недавние
/// лежат в той же зашифрованной базе профиля, что и на телефоне. Разойтись
/// двум подборщикам теперь негде.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../gifs/gif_api.dart';
import '../../../gifs/gif_categories.dart';
import '../../../gifs/gif_query.dart';
import '../../../gifs/gif_recents.dart' show RecentGif;
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/hover_listener.dart';

class DesktopGifPickerTab extends StatefulWidget {
  const DesktopGifPickerTab({
    super.key,
    required this.loadRecents,
    required this.rememberPicked,
    required this.query,
    required this.onPicked,
  });

  /// 🔴 ДВЕ ЗАМЫКАЮЩИЕ ВМЕСТО КОНТРОЛЛЕРА — ЭТО НЕ ВКУСОВЩИНА.
  ///
  /// `desktop_controller_seam_ratchet_test` считает файлы окна, которые лезут
  /// в `AppController` напрямую, и не даёт этому числу расти: каждый такой
  /// файл — это кусок окна, который нельзя ни собрать в проверке, ни
  /// переиспользовать без живого приложения. Подборщику гифок от контроллера
  /// нужны ровно две вещи — прочитать недавние и запомнить выбранную; их и
  /// передают.
  final Future<List<RecentGif>> Function() loadRecents;

  final Future<void> Function({
    required String previewUrl,
    required String fullUrl,
  }) rememberPicked;

  /// Слово из общей строки поиска над вкладками.
  final String query;

  /// Путь к скачанному файлу. Отправкой занимается хозяин окна — тем же путём,
  /// что и перетащенным файлом: он уже умеет и личные чаты, и комнаты, и темы.
  final ValueChanged<String> onPicked;

  @override
  State<DesktopGifPickerTab> createState() => _DesktopGifPickerTabState();
}

class _DesktopGifPickerTabState extends State<DesktopGifPickerTab> {
  final ScrollController _scroll = ScrollController();

  List<GifItem> _gifs = <GifItem>[];
  List<RecentGif> _recents = const <RecentGif>[];

  int? _activeCategory;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _failed = false;
  bool _hasMore = false;
  bool _saving = false;

  /// Выбранную гифку не удалось скачать (17.09.2026). Отдельно от [_failed]:
  /// тот про поиск, и его заметку видно только в пустой сетке — при полной
  /// сетке неудача выбора была беззвучной.
  bool _pickFailed = false;

  /// Неудача сетевая (лечится повтором) — иначе, например, гифки больше нет.
  bool _pickFailedNetwork = true;

  /// Курсор GIPHY: сколько записей уже спросили.
  int _offset = 0;

  /// Слово и язык, которыми ДОБЫТА текущая выдача.
  ///
  /// 🔴 Без этого подгрузка ломается: человек ищет «кот», план превращает это
  /// в «cat», и вторая страница обязана спрашивать «cat» — иначе продолжение
  /// приезжает из другого поиска.
  String? _resolvedTerm;
  String _resolvedLang = 'en';

  /// Номер поколения запроса: страница от старого слова не имеет права попасть
  /// в новую выдачу — человек набирает быстрее, чем отвечает сеть.
  int _seq = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_loadFirst(widget.query.trim().isEmpty ? null : widget.query));
    unawaited(_loadRecents());
  }

  @override
  void didUpdateWidget(covariant DesktopGifPickerTab old) {
    super.didUpdateWidget(old);
    if (old.query == widget.query) return;
    _debounce?.cancel();
    if (_activeCategory != null) {
      // Набранное слово важнее нажатой иконки: подсветка обязана уйти, иначе
      // человек видит выбранную категорию и результаты другого запроса.
      setState(() => _activeCategory = null);
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final q = widget.query.trim();
      unawaited(_loadFirst(q.isEmpty ? null : q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    try {
      final recents = await widget.loadRecents();
      if (!mounted) return;
      setState(() => _recents = recents);
    } catch (_) {
      // Недавние — удобство, а не содержимое вкладки.
    }
  }

  void _onScroll() {
    if (_loadingFirst || _loadingMore || !_hasMore) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < pos.maxScrollExtent - kGifPrefetchExtent) return;
    unawaited(_loadMore());
  }

  void _onCategoryTap(int index) {
    _debounce?.cancel();
    final wasActive = _activeCategory == index;
    setState(() => _activeCategory = wasActive ? null : index);
    final category = wasActive ? null : kGifCategories[index];
    unawaited(_loadFirst(category?.query));
  }

  Future<void> _loadFirst(String? rawQuery) async {
    final seq = ++_seq;
    if (mounted) {
      setState(() {
        _loadingFirst = true;
        // Сбрасывается вместе с первой страницей: застрявший признак от
        // отменённой подгрузки навсегда закрыл бы дорогу следующим страницам.
        _loadingMore = false;
        _failed = false;
        _gifs = <GifItem>[];
        _hasMore = false;
        _offset = 0;
      });
    }

    final plan = gifQueryPlan(rawQuery ?? '');
    var page = GifPage.empty;
    String? term;
    var lang = 'en';

    if (plan.isEmpty) {
      page = await fetchGifPage(query: null, offset: 0);
      if (seq != _seq || !mounted) return;
    } else {
      for (final attempt in plan) {
        page = await fetchGifPage(
          query: attempt.term,
          lang: attempt.lang,
          offset: 0,
        );
        if (seq != _seq || !mounted) return;
        term = attempt.term;
        lang = attempt.lang;
        if (page.items.isNotEmpty) break;
        // Нет связи — второй запрос тем же путём бессмыслен.
        if (page.failed) break;
      }
    }

    setState(() {
      _gifs = page.items;
      _hasMore = page.hasMore && page.items.length < kGifMaxItems;
      _failed = page.failed;
      _loadingFirst = false;
      _offset = page.returned;
      _resolvedTerm = term;
      _resolvedLang = lang;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final seq = _seq;
    setState(() => _loadingMore = true);
    final page = await fetchGifPage(
      query: _resolvedTerm,
      lang: _resolvedLang,
      offset: _offset,
    );
    if (seq != _seq || !mounted) return;
    setState(() {
      final before = _gifs.length;
      final merged = <GifItem>[..._gifs];
      final seen = merged.map((g) => g.fullUrl).toSet();
      for (final item in page.items) {
        // GIPHY повторяет часть выдачи на границах страниц.
        if (!seen.add(item.fullUrl)) continue;
        merged.add(item);
        if (merged.length >= kGifMaxItems) break;
      }
      _gifs = merged;
      _offset += page.returned;
      // Страница целиком из повторов значит, что полезное кончилось.
      final progressed = merged.length > before;
      _hasMore = page.hasMore &&
          !page.failed &&
          progressed &&
          merged.length < kGifMaxItems;
      _loadingMore = false;
    });
  }

  /// Скачивает выбранную гифку во временный файл и отдаёт путь наружу.
  ///
  /// 🔴 ОТПРАВКОЙ ЗАНИМАЕТСЯ ХОЗЯИН, А НЕ ПОДБОРЩИК. Путь отправки на
  /// компьютере уже написан и проверен: он различает личный чат и комнату,
  /// проставляет тему и умеет отвечать на сообщение. Написать здесь второй
  /// значило бы завести вторую правду о том, куда уходит вложение.
  Future<void> _pick(GifItem gif) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _pickFailed = false;
    });
    // Запоминаем в момент выбора, а не после отправки: недавние не должны
    // зависеть от того, чем закончилась отправка.
    unawaited(
      widget
          .rememberPicked(
            previewUrl: gif.previewUrl,
            fullUrl: gif.fullUrl,
          )
          .catchError((Object _) {}),
    );
    try {
      final resp = await _downloadGifWithRetry(gif.fullUrl);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/gif_${DateTime.now().millisecondsSinceEpoch}.gif',
      );
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      if (!mounted) return;
      widget.onPicked(file.path);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pickFailed = true;
        _pickFailedNetwork = gifDownloadIsWorthRetrying(error);
      });
    }
  }

  Future<http.Response> _downloadGifWithRetry(String gifUrl) =>
      downloadGifWithRetry(gifUrl, isAlive: () => mounted);

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _categoryStrip(c),
        if (_pickFailed) _pickFailureBanner(c),
        Flexible(child: _grid(c)),
        _attribution(c),
      ],
    );
  }

  /// Неудача выбора — видна и при полной сетке (17.09.2026).
  Widget _pickFailureBanner(DColorSet c) {
    final text = _pickFailedNetwork
        ? _kGifConnectionLost
        : AppLocalizations.of(context)!.attachmentActionGeneric;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.m, DSpace.xs, DSpace.m, 0),
      child: Row(
        children: [
          Icon(
            _pickFailedNetwork
                ? FluentIcons.wifi_off_24_regular
                : FluentIcons.error_circle_24_regular,
            size: 16,
            color: c.danger,
          ),
          const SizedBox(width: DSpace.xs),
          Expanded(
            child: Text(
              text,
              style: DType.label.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryStrip(DColorSet c) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
          itemCount: kGifCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (ctx, i) {
            final selected = i == _activeCategory;
            return HoverListener(
              onTap: () => _onCategoryTap(i),
              cursor: SystemMouseCursors.click,
              builder: (ctx, hovered, pressed) => Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? c.accentPrimary.withValues(alpha: 0.18)
                      : (hovered ? c.hover : Colors.transparent),
                  borderRadius: BorderRadius.circular(DRadii.sm),
                ),
                child: Text(
                  kGifCategories[i].emoji,
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
              ),
            );
          },
        ),
      );

  Widget _grid(DColorSet c) {
    if (kGiphyApiKey.isEmpty) {
      return _notice(
        c,
        FluentIcons.gif_24_regular,
        'GIF недоступны: сборка без ключа GIPHY',
      );
    }
    if (_loadingFirst) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(DSpace.xl2),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    // 🔴 «Нет связи» и «ничего не нашлось» — РАЗНЫЕ сообщения: первое лечится
    // повтором, второе другим словом.
    if (_failed && _gifs.isEmpty) {
      return _notice(
        c,
        FluentIcons.wifi_off_24_regular,
        _kGifConnectionLost,
      );
    }
    final showRecents = _recents.isNotEmpty &&
        _activeCategory == null &&
        widget.query.trim().isEmpty;
    if (_gifs.isEmpty && !showRecents) {
      return _notice(c, FluentIcons.gif_24_regular, 'Ничего не нашлось');
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(DSpace.s, 0, DSpace.s, DSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRecents) ...[
            _sectionLabel(c, 'Недавние'),
            _wrap(
              _recents
                  .map(
                    (r) => GifItem(
                      previewUrl: r.previewUrl,
                      fullUrl: r.fullUrl,
                    ),
                  )
                  .toList(growable: false),
              c,
            ),
            const SizedBox(height: DSpace.s),
          ],
          if (_gifs.isNotEmpty) _wrap(_gifs, c),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(DSpace.s),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wrap(List<GifItem> items, DColorSet c) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final gif in items)
            HoverListener(
              onTap: () => unawaited(_pick(gif)),
              cursor: SystemMouseCursors.click,
              builder: (ctx, hovered, pressed) => Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: c.bubblePeer,
                  borderRadius: BorderRadius.circular(DRadii.sm),
                  border: Border.all(
                    color: hovered ? c.accentPrimary : Colors.transparent,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  gif.previewUrl,
                  fit: BoxFit.cover,
                  // Сломанная ссылка не имеет права ронять сетку.
                  errorBuilder: (_, __, ___) => Icon(
                    FluentIcons.image_off_24_regular,
                    size: 20,
                    color: c.textDisabled,
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _sectionLabel(DColorSet c, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 6, bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: DType.tiny
              .copyWith(color: c.textSecondary, letterSpacing: 1.2),
        ),
      );

  /// Условие GIPHY: упоминание источника должно быть видно.
  Widget _attribution(DColorSet c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          'Powered by GIPHY',
          style: DType.tiny.copyWith(color: c.textDisabled),
        ),
      );

  Widget _notice(DColorSet c, IconData icon, String label) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DSpace.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: c.textDisabled),
              const SizedBox(height: DSpace.s),
              Text(
                label,
                textAlign: TextAlign.center,
                style: DType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
}

const String _kGifConnectionLost = 'Связь прервалась. Попробуйте ещё раз';

/// Стоит ли повторять неудавшуюся загрузку гифки: только сетевой класс.
/// Ответ сервера — доказательство, что связь есть (5xx обрабатывается в цикле).
bool gifDownloadIsWorthRetrying(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is HandshakeException ||
    error is http.ClientException;

/// Скачивает гифку, переживая пропавший маршрут — как телефон (`a4004ccd`).
///
/// «No route to host» (errno 113) — это «маршрута прямо сейчас нет»: смена
/// сети, просыпающееся радио. Через секунду на свежем сокете он почти всегда
/// есть, а на компьютере была ровно одна попытка (17.09.2026). Повторяются
/// только сетевые сбои и 5xx; 404/410 — «гифки больше нет», повтор не поможет.
/// [isAlive] — экран ещё открыт; закрыли — повторы прекращаются.
Future<http.Response> downloadGifWithRetry(
  String gifUrl, {
  required bool Function() isAlive,
  List<Duration> backoff = const <Duration>[
    Duration(milliseconds: 600),
    Duration(milliseconds: 1500),
  ],
}) async {
  final uri = Uri.parse(gifUrl);
  Object lastError = const SocketException('GIF download failed');
  for (var attempt = 0; attempt <= backoff.length; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(backoff[attempt - 1]);
      if (!isAlive()) break;
    }
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return resp;
      final failure = HttpException('HTTP ${resp.statusCode}', uri: uri);
      if (resp.statusCode < 500) throw failure;
      lastError = failure;
    } catch (error) {
      if (!gifDownloadIsWorthRetrying(error)) rethrow;
      lastError = error;
    }
  }
  throw lastError;
}
