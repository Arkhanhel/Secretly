// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_controller.dart';
import '../../../widgets/conversation_media_gallery.dart'
    show
        ConversationAttachmentItem,
        ConversationLinkItem,
        ConversationMediaGalleryVm,
        fetchConversationAttachmentFile,
        kAttachmentGoneCode,
        loadConversationAttachmentFile,
        loadConversationMediaFiles,
        openConversationAttachmentImage;
import '../../design/tokens.dart';
import '../../primitives/context_menu.dart';
import '../../primitives/hover_listener.dart';
import '../../../widgets/broken_media_box.dart';

/// Desktop-native media gallery for the details (third-column) drawer.
///
/// We use our own desktop-native grid instead of reusing the mobile
/// `ConversationMediaGrid` so that we can offer right-click context menus —
/// the mobile grid only exposes a single tap callback.
///
/// (Historical note: this widget also predates U-01, when the desktop
/// `MaterialApp` did not register `AppLocalizations` and any `context.l10n`
/// call crashed on desktop. That restriction is gone — l10n is registered in
/// `desktop_production_app.dart` — so mobile widgets may now be reused here
/// when their interaction model fits.)
///
/// Вкладки: Медиа / Файлы / Ссылки / Аудио. Выборка ленивая — на первой
/// отрисовке, потом при смене [convoId].
///
/// 🔴 ПОЧЕМУ ФОТО И ВИДЕО СЛИЛИСЬ В «МЕДИА» (13.09.2026, макет владельца).
/// Вкладок в панели шириной 260–330 точек помещается ровно четыре, а ссылок в
/// ней не было вовсе — при том что ссылка в переписке теряется быстрее всего:
/// картинку видно листанием, а адрес утонул в тексте месячной давности. Макет
/// делит так же: «Медиа · Файлы · Ссылки · Голос».
///
/// Последняя вкладка названа «Аудио», а не «Голос», и это сознательное
/// отступление: сюда попадает ЛЮБОЙ `audio/*`, в том числе присланный
/// музыкальный файл, и называть его голосовым сообщением было бы неправдой.
class DesktopMediaGallery extends StatefulWidget {
  const DesktopMediaGallery({
    super.key,
    required this.controller,
    required this.convoId,
    this.height = 420,
  });

  final AppController controller;
  final String convoId;
  final double height;

  @override
  State<DesktopMediaGallery> createState() => _DesktopMediaGalleryState();
}

class _DesktopMediaGalleryState extends State<DesktopMediaGallery> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Future<ConversationMediaGalleryVm>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DesktopMediaGallery old) {
    super.didUpdateWidget(old);
    if (old.convoId != widget.convoId) _load();
  }

  void _load() {
    _future = loadConversationMediaFiles(widget.controller, widget.convoId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔴 Вкладки делят ширину поровну, а не жмутся к левому краю.
          //
          // Со `isScrollable: true` четыре коротких слова стояли слева стопкой,
          // а справа оставалась пустота: чем шире человек тянул панель, тем
          // нелепее выглядел этот перекос. Категорий ровно четыре, они никогда
          // не вырастут в список — значит делить ширину поровну честнее и
          // спокойнее для глаза, чем прокручивать то, что и так помещается.
          //
          // Цена решения — узкая панель (минимум 260 точек). Там на вкладку
          // остаётся около шестидесяти точек, и «Музыка» в них уже не влезает.
          // Поэтому подпись не обрезается и не переносится, а ужимается
          // [FittedBox]'ом: слово остаётся читаемым целиком, а строка —
          // симметричной. Обрезанное «Музы…» было бы хуже мелкого «Музыка».
          TabBar(
            isScrollable: false,
            indicatorColor: c.accentPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: c.textPrimary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: DType.label.copyWith(fontWeight: FontWeight.w600),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            // · Черта под полосой из макета. Без неё вкладки висели над
            // содержимым, и подпись вкладки читалась заголовком того, что под
            // ней, а не переключателем.
            dividerColor: c.borderSubtle,
            dividerHeight: 1,
            tabs: [
              _GalleryTab(l10n.desktopGalleryMedia),
              _GalleryTab(l10n.desktopGalleryFiles),
              _GalleryTab(l10n.desktopGalleryLinks),
              _GalleryTab(l10n.desktopChatsAudio),
            ],
          ),
          SizedBox(
            height: widget.height,
            child: FutureBuilder<ConversationMediaGalleryVm>(
              future: _future,
              builder: (ctx, snap) {
                final vm = snap.data;
                if (vm == null) {
                  return Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                      ),
                    ),
                  );
                }
                // Медиа — одной лентой, новейшее первым: раздельные «фото» и
                // «видео» заставляли искать в двух местах то, что человек
                // помнит как «картинка, которую он кидал во вторник».
                final media =
                    <ConversationAttachmentItem>[...vm.photos, ...vm.videos]
                      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
                return TabBarView(
                  children: [
                    _DesktopMediaGrid(
                      items: media,
                      controller: widget.controller,
                      emptyLabel: l10n.desktopGalleryNoMedia,
                    ),
                    _DesktopFilesList(
                      items: vm.files,
                      controller: widget.controller,
                      emptyLabel: l10n.desktopGalleryNoFiles,
                      kind: _ListKind.file,
                    ),
                    _DesktopLinksList(items: vm.links),
                    _DesktopFilesList(
                      items: vm.music,
                      controller: widget.controller,
                      emptyLabel: l10n.desktopGalleryNoAudio,
                      kind: _ListKind.audio,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Подпись вкладки галереи, которая ужимается вместо обрезки.
///
/// [Tab] кладёт подпись в строку без запаса: на узкой панели «Музыка» просто
/// вылезала бы за край. [FittedBox] с [BoxFit.scaleDown] уменьшает слово ровно
/// настолько, насколько не хватает места, и не трогает его, когда места
/// достаточно.
class _GalleryTab extends StatelessWidget {
  const _GalleryTab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}

/// Ссылки из переписки.
///
/// 🔴 Вкладки ссылок не было вовсе, при том что ссылка теряется быстрее
/// всего остального: картинку видно листанием, файл лежит во вкладке, а адрес
/// утонул в тексте месячной давности и ищется только поиском по слову, которое
/// надо вспомнить.
///
/// Показываем адрес и строку сообщения, в котором он встретился: по одному
/// адресу часто не вспомнить, о чём был разговор. Одинаковые адреса
/// схлопнуты — пять пересылок одной ссылки это одна ссылка.
class _DesktopLinksList extends StatelessWidget {
  const _DesktopLinksList({required this.items});

  final List<ConversationLinkItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.desktopGalleryNoLinks,
          style: DType.body.copyWith(color: c.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _LinkRow(item: items[i]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.item});

  final ConversationLinkItem item;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final context_ = item.messageText.replaceAll('\n', ' ').trim();
    return HoverListener(
      cursor: SystemMouseCursors.click,
      onTap: () => unawaited(_open(context)),
      builder: (ctx, hovered, pressed) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hovered ? c.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(FluentIcons.link_24_regular, size: 16, color: c.accentPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.body.copyWith(color: c.accentPrimary),
                  ),
                  if (context_.isNotEmpty && context_ != item.url) ...[
                    const SizedBox(height: 2),
                    Text(
                      context_,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DType.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(
      item.url.startsWith('http') ? item.url : 'https://${item.url}',
    );
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ссылка может оказаться нерабочей — это не повод ронять панель.
    }
  }
}

enum _ListKind { file, audio }

// ─────────────────────────────────────────────────────────────────────────────
// Photo / Video grid
// ─────────────────────────────────────────────────────────────────────────────

/// 🔴 ПРЕВЬЮ ИЗ ШЕСТИ ПЛИТОК С «+41» ИЗ МАКЕТА НЕ ВЗЯТО — И ЭТО РЕШЕНИЕ.
///
/// В макете панель показывает ровно шесть плиток, шестая несёт остаток. Так
/// сделано потому, что ТАМ панель растёт по содержимому. У нас область вкладок
/// фиксирована по высоте (`height`, по умолчанию 420) — и она общая на все
/// четыре вкладки: «Файлы», «Ссылки» и «Аудио» прокручиваются в ней списками.
///
/// Показав в этой области шесть плиток, мы получим две строки сверху и
/// примерно двести точек пустоты под ними. А менять высоту по вкладке нельзя:
/// панель прыгала бы при каждом переключении.
///
/// Довод «так уйдёт прокрутка внутри прокрутки» верный, но неполный: у
/// остальных трёх вкладок она всё равно останется. Это общая задача «панель
/// растёт по содержимому», а не мелочь сетки, и решать её надо целиком.
class _DesktopMediaGrid extends StatelessWidget {
  const _DesktopMediaGrid({
    required this.items,
    required this.controller,
    required this.emptyLabel,
  });

  final List<ConversationAttachmentItem> items;
  final AppController controller;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: DType.body.copyWith(color: c.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: items.length,
      // · Зазор 5 из макета вместо 2. На двух точках плитки слипались в одно
      // пятно, и сетка читалась как один рваный снимок, а не как двадцать
      // разных.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemBuilder: (ctx, i) =>
          _MediaTile(item: items[i], controller: controller),
    );
  }
}

/// Что сейчас с плиткой: тянем, показали, не смогли.
///
/// 🔴 СОСТОЯНИЕ БЫЛО ОДНО — «нет картинки», и серый значок означал сразу три
/// разные вещи: «ещё качаю», «не скачалось» и «файла нет вовсе». Владелец
/// увидел это на телефоне сеткой пустых плиток; на компьютере было ровно то
/// же самое.
enum _TilePhase { loading, ready, failed, gone }

class _MediaTile extends StatefulWidget {
  const _MediaTile({required this.item, required this.controller});

  final ConversationAttachmentItem item;
  final AppController controller;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  File? _file;
  _TilePhase _phase = _TilePhase.loading;

  ConversationAttachmentItem get item => widget.item;
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  /// 🔴 ТЯНЕМ РОВНО ОДИН РАЗ НА ПЛИТКУ.
  ///
  /// Здесь стоял `FutureBuilder`, чей `future` собирался прямо в `build`, —
  /// то есть КАЖДАЯ перерисовка списка начинала скачивание заново. У галереи
  /// на сотню вложений это сотня лишних загрузок на каждый тик ленты.
  /// Мобильная галерея этот же урок уже прошла, см. `_MediaGridCell`.
  Future<void> _resolve() async {
    if (mounted && _phase != _TilePhase.loading) {
      setState(() => _phase = _TilePhase.loading);
    }
    final got = await fetchConversationAttachmentFile(
      widget.controller,
      widget.item.attachment,
    );
    if (!mounted) return;
    setState(() {
      _file = got.file;
      _phase = got.file != null
          ? _TilePhase.ready
          // Файла больше нет на сервере — «повторить» тут ничего не даст.
          : (got.failure == kAttachmentGoneCode
                ? _TilePhase.gone
                : _TilePhase.failed);
    });
  }

  /// Вид плитки считается по САМОМУ вложению, а не по вкладке: «Медиа» теперь
  /// одна лента, и фотография с видео стоят в ней вперемешку.
  bool get _isVideo =>
      (item.attachment.mime ?? '').toLowerCase().startsWith('video/');

  /// Чем плитка является на слух. Названия у вложения нет — площадка хранит
  /// только вид и размер, — поэтому вслух идёт вид: «Фото», «Видео», «Файл».
  /// Без него обход галереи — это тридцать одинаковых «кнопка».
  String _spokenKind(AppLocalizations l10n) {
    final mime = widget.item.attachment.mime ?? '';
    if (mime.startsWith('video/')) return l10n.video;
    if (mime.startsWith('image/')) return l10n.photo;
    return l10n.file;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Semantics(
      button: true,
      label: _spokenKind(AppLocalizations.of(context)!),
      child: GestureDetector(
      onSecondaryTapDown: (d) => _openMenu(context, d.globalPosition),
      child: HoverListener(
        // Не смогли — нажатие ПОВТОРЯЕТ попытку, а не открывает пустоту.
        onTap: _phase == _TilePhase.failed
            ? () => unawaited(_resolve())
            : () => _primaryTap(context),
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) {
          // · Плитка скруглена на 10 (макет). Прямые углы в сетке из
          // квадратов дают решётку, а не набор снимков.
          return ClipRRect(
            borderRadius: BorderRadius.circular(DRadii.md),
            child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: c.elevated, child: _face(c)),
              if (_isVideo)
                const Center(
                  child: Icon(
                    FluentIcons.play_circle_24_filled,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              if (hovered)
                Container(color: Colors.black.withValues(alpha: 0.08)),
            ],
            ),
          );
        },
      ),
      ),
    );
  }

  /// Лицо плитки по её состоянию: кружок ожидания, картинка или стрелка
  /// «нажмите, чтобы повторить».
  Widget _face(DColorSet c) {
    final f = _file;
    if (f != null && f.existsSync() && !_isVideo) {
      return Image.file(
        f,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const BrokenMediaBox(),
      );
    }
    if (_isVideo) {
      return Center(
        child: Icon(
          FluentIcons.play_circle_24_regular,
          color: c.textSecondary,
          size: 28,
        ),
      );
    }
    if (_phase == _TilePhase.gone) {
      return Center(
        child: Icon(
          FluentIcons.image_off_24_regular,
          color: c.textTertiary,
          size: 26,
        ),
      );
    }
    if (_phase == _TilePhase.loading) {
      // Пока тянем — тихий кружок, а не «сломанная картинка»: ожидание и
      // отказ выглядели одинаково.
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.textTertiary),
        ),
      );
    }
    return Center(
      child: Icon(
        FluentIcons.arrow_download_24_regular,
        color: c.textSecondary,
        size: 26,
      ),
    );
  }

  Future<void> _primaryTap(BuildContext context) async {
    if (!_isVideo) {
      await openConversationAttachmentImage(
        context,
        controller,
        item.attachment,
      );
    } else {
      // Video: open with default app.
      await _openInDefaultApp(context);
    }
  }

  Future<void> _openInDefaultApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null || !f.existsSync()) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.file(f.path),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        _toast(context, l10n.desktopChatsOpenFailed, danger: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, l10n.desktopChatsOpenFailedShort('$e'), danger: true);
    }
  }

  Future<void> _revealInFinder(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null || !f.existsSync()) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', f.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', f.path]);
      } else {
        // Linux: open containing dir.
        await Process.run('xdg-open', [f.parent.path]);
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: f.path));
    if (!context.mounted) return;
    _toast(context, l10n.desktopGalleryPathCopied);
  }

  Future<void> _openMenu(BuildContext context, Offset globalPos) async {
    final l10n = AppLocalizations.of(context)!;
    await ContextMenu.show(
      context,
      globalPosition: globalPos,
      sections: <List<CtxMenuItem>>[
        [
          CtxMenuItem(
            label: _isVideo ? l10n.desktopGalleryOpen : l10n.desktopGalleryView,
            icon: _isVideo
                ? FluentIcons.open_24_regular
                : FluentIcons.eye_24_regular,
            onTap: () => _primaryTap(context),
          ),
          CtxMenuItem(
            label: l10n.desktopGalleryOpenInSystem,
            icon: FluentIcons.window_apps_24_regular,
            onTap: () => _openInDefaultApp(context),
          ),
        ],
        [
          CtxMenuItem(
            label: Platform.isMacOS
                ? l10n.desktopGalleryRevealFinder
                : (Platform.isWindows
                      ? l10n.desktopGalleryRevealExplorer
                      : l10n.desktopGalleryOpenFolder),
            icon: FluentIcons.folder_open_24_regular,
            onTap: () => _revealInFinder(context),
          ),
          CtxMenuItem(
            label: l10n.desktopGalleryCopyPath,
            icon: FluentIcons.copy_24_regular,
            onTap: () => _copyPath(context),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Files / Audio list
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopFilesList extends StatelessWidget {
  const _DesktopFilesList({
    required this.items,
    required this.controller,
    required this.emptyLabel,
    required this.kind,
  });

  final List<ConversationAttachmentItem> items;
  final AppController controller;
  final String emptyLabel;
  final _ListKind kind;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: DType.body.copyWith(color: c.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DSpace.s,
        DSpace.xs,
        DSpace.s,
        DSpace.m,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => Container(height: 1, color: c.borderSubtle),
      itemBuilder: (ctx, i) =>
          _FileTile(item: items[i], controller: controller, kind: kind),
    );
  }
}

class _FileTile extends StatelessWidget {

  const _FileTile({
    required this.item,
    required this.controller,
    required this.kind,
  });

  final ConversationAttachmentItem item;
  final AppController controller;
  final _ListKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final mime = (item.attachment.mime ?? '').toLowerCase();
    final isVoice =
        mime == 'audio/ogg' ||
        mime == 'audio/opus' ||
        mime.startsWith('audio/webm') ||
        mime == 'audio/3gpp' ||
        mime == 'audio/amr';
    final title = _title(mime, isVoice, l10n);
    final dt = DateTime.fromMillisecondsSinceEpoch(item.createdAtMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final size = _formatSize(item.attachment.sizeBytes, l10n);
    final icon = kind == _ListKind.audio
        ? FluentIcons.music_note_2_24_regular
        : FluentIcons.document_24_regular;

    return GestureDetector(
      onSecondaryTapDown: (d) => _openMenu(context, d.globalPosition),
      child: HoverListener(
        onTap: () => _openInDefaultApp(context),
        builder: (ctx, hovered, pressed) {
          final bg = pressed
              ? c.pressed
              : (hovered ? c.hover : Colors.transparent);
          return AnimatedContainer(
            duration: DMotion.fast,
            color: bg,
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.s,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.elevated,
                    borderRadius: BorderRadius.circular(DRadii.md),
                  ),
                  child: Icon(icon, size: 20, color: c.textPrimary),
                ),
                const SizedBox(width: DSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.body.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$size • $dd.$mo $hh:$mm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openInDefaultApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null || !f.existsSync()) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.file(f.path),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        _toast(context, l10n.desktopChatsOpenFailed, danger: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, l10n.desktopChatsOpenFailedShort('$e'), danger: true);
    }
  }

  Future<void> _revealInFinder(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null || !f.existsSync()) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', f.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', f.path]);
      } else {
        await Process.run('xdg-open', [f.parent.path]);
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final f = await loadConversationAttachmentFile(controller, item.attachment);
    if (!context.mounted) return;
    if (f == null) {
      _toast(context, l10n.desktopChatsFileUnavailable, danger: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: f.path));
    if (!context.mounted) return;
    _toast(context, l10n.desktopGalleryPathCopied);
  }

  Future<void> _openMenu(BuildContext context, Offset globalPos) async {
    final l10n = AppLocalizations.of(context)!;
    await ContextMenu.show(
      context,
      globalPosition: globalPos,
      sections: <List<CtxMenuItem>>[
        [
          CtxMenuItem(
            label: l10n.desktopGalleryOpen,
            icon: FluentIcons.open_24_regular,
            onTap: () => _openInDefaultApp(context),
          ),
        ],
        [
          CtxMenuItem(
            label: Platform.isMacOS
                ? l10n.desktopGalleryRevealFinder
                : (Platform.isWindows
                      ? l10n.desktopGalleryRevealExplorer
                      : l10n.desktopGalleryOpenFolder),
            icon: FluentIcons.folder_open_24_regular,
            onTap: () => _revealInFinder(context),
          ),
          CtxMenuItem(
            label: l10n.desktopGalleryCopyPath,
            icon: FluentIcons.copy_24_regular,
            onTap: () => _copyPath(context),
          ),
        ],
      ],
    );
  }

  String _title(String mime, bool isVoice, AppLocalizations l10n) {
    if (kind == _ListKind.audio) {
      if (isVoice) return l10n.desktopChatsVoiceMessage;
      return mime.isEmpty ? l10n.desktopChatsAudio : mime;
    }
    return mime.isEmpty ? l10n.file : mime;
  }

  String _formatSize(int bytes, AppLocalizations l10n) {
    if (bytes <= 0) return l10n.desktopGalleryZeroBytes;
    var u = 0;
    var v = bytes.toDouble();
    while (v >= 1024 && u < 3) {
      v /= 1024;
      u++;
    }
    final fmt = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    // Единица измерения — часть языка, а не приписка к числу.
    return switch (u) {
      0 => l10n.desktopGalleryBytes(fmt),
      1 => l10n.desktopStorageKb(fmt),
      2 => l10n.desktopStorageMb(fmt),
      _ => l10n.desktopStorageGb(fmt),
    };
  }
}

void _toast(BuildContext context, String message, {bool danger = false}) {
  final c = DColors.of(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: danger ? c.danger : c.elevated,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
