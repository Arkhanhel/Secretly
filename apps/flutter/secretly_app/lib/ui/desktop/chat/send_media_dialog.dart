// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/desktop_file_match.dart' show formatAttachmentSize;
import '../design/tokens.dart';
import '../primitives/context_menu.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_ui_prefs.dart';
import 'attachments_drop_zone.dart';
import 'emoji_popover.dart';
import 'media_group_layout.dart';
import 'message_media.dart';
import 'outgoing_media.dart';

// 🔴 ОКНО ОТПРАВКИ ФАЙЛОВ — КАК В TELEGRAM ДЛЯ macOS.
//
// Указание владельца 16.09.2026 (со скриншотом): «при перетаскивании файла
// появляется окошко, в которое можно переносить фото сколько угодно, и
// добавить можно комментарий — это важно! Сейчас они без комментария
// отправляются».
//
// Было: брошенный файл уходил сразу, по одному, без подписи и без
// возможности передумать; вставленная картинка спрашивала «Отправить?» без
// подписи.
//
// Стало: крестик слева, заголовок «2 медиа», «…» справа (файлами или как
// медиа, группировать или нет, добавить ещё), превью альбомом — той же
// раскладкой, что и в ленте, — поле «Добавить подпись…» с эмодзи и круглая
// кнопка отправки. Файлы добавляются перетаскиванием прямо в окно и
// вставкой из буфера. Enter отправляет, Shift+Enter — перенос (или наоборот,
// по настройке), Esc закрывает, и подпись возвращается в поле ввода.

/// Что выбрал человек.
class SendMediaResult {
  const SendMediaResult({
    required this.files,
    required this.sendAsFiles,
    required this.grouped,
    required this.caption,
  });

  final List<OutgoingFile> files;
  final bool sendAsFiles;
  final bool grouped;
  final String caption;

  List<OutgoingGroup> get groups =>
      planOutgoingGroups(files, sendAsFiles: sendAsFiles, grouped: grouped);
}

/// Окно закрыли, ничего не отправив. Подпись возвращается туда, откуда
/// пришла, — в поле ввода: набранное не должно пропадать.
class SendMediaDismissed {
  const SendMediaDismissed(this.caption);

  final String caption;
}

/// Открывает окно. Возвращает [SendMediaResult] или [SendMediaDismissed].
Future<Object> showSendMediaDialog(
  BuildContext context, {
  required List<OutgoingFile> files,
  required int maxBytes,
  String caption = '',
  bool sendAsFiles = false,
  String? destinationTitle,
  String? notice,
  Future<List<String>> Function()? onPickMore,
}) async {
  final echo = ValueNotifier<String>(caption);
  try {
    final result = await showGeneralDialog<Object>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'send-media',
      barrierColor: Colors.transparent,
      transitionDuration: DMotion.medium,
      pageBuilder: (ctx, animation, _) => SendMediaDialog(
        animation: animation,
        initialFiles: files,
        initialCaption: caption,
        initialSendAsFiles: sendAsFiles,
        maxBytes: maxBytes,
        destinationTitle: destinationTitle,
        initialNotice: notice,
        onPickMore: onPickMore,
        captionEcho: echo,
      ),
      transitionBuilder: (ctx, a, b, child) {
        final scale = Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).chain(CurveTween(curve: DMotion.easeOutCubic)).animate(a);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
    // Окно могли закрыть и не нашими кнопками — подпись не теряем и тогда.
    return result ?? SendMediaDismissed(echo.value);
  } finally {
    echo.dispose();
  }
}

class SendMediaDialog extends StatefulWidget {
  const SendMediaDialog({
    super.key,
    required this.initialFiles,
    required this.maxBytes,
    this.animation,
    this.initialCaption = '',
    this.initialSendAsFiles = false,
    this.destinationTitle,
    this.initialNotice,
    this.onPickMore,
    this.captionEcho,
  });

  final Animation<double>? animation;
  final List<OutgoingFile> initialFiles;
  final int maxBytes;
  final String initialCaption;
  final bool initialSendAsFiles;

  /// Куда уйдёт — показывается, когда файлы брошены на строку списка, а не
  /// в открытую переписку.
  final String? destinationTitle;

  /// Что не взято из первого броска.
  final String? initialNotice;

  /// «Добавить файлы…» — системный выбор файлов.
  final Future<List<String>> Function()? onPickMore;

  final ValueNotifier<String>? captionEcho;

  @override
  State<SendMediaDialog> createState() => _SendMediaDialogState();
}

/// Ширина окна: как у окна Telegram для macOS на скриншоте владельца.
const double _kDialogWidth = 400;
const double _kContentPadding = 12;

class _SendMediaDialogState extends State<SendMediaDialog> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late final List<OutgoingFile> _files = <OutgoingFile>[
    ...widget.initialFiles,
  ];
  late bool _asFiles = widget.initialSendAsFiles;
  bool _grouped = true;
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );
  final FocusNode _captionFocus = FocusNode(debugLabel: 'send-media-caption');
  final GlobalKey _moreKey = GlobalKey(debugLabel: 'send-media-more');
  final GlobalKey _emojiKey = GlobalKey(debugLabel: 'send-media-emoji');
  final Map<OutgoingFile, Future<void>> _prep = <OutgoingFile, Future<void>>{};
  late String? _notice = widget.initialNotice;
  bool _dragging = false;
  bool _sending = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _caption.selection = TextSelection.collapsed(
      offset: _caption.text.length,
    );
    _caption.addListener(_echoCaption);
    _files.forEach(_startPrep);
  }

  @override
  void dispose() {
    _caption.removeListener(_echoCaption);
    _caption.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  void _echoCaption() => widget.captionEcho?.value = _caption.text;

  void _startPrep(OutgoingFile f) {
    if (_prep.containsKey(f)) return;
    final future = OutgoingMediaPrep.prepare(f).whenComplete(() {
      if (mounted) setState(() {});
    });
    _prep[f] = future;
  }

  void _addFiles(List<OutgoingFile> files, {String? notice}) {
    if (!mounted || _closed) return;
    setState(() {
      _files.addAll(files);
      _notice = notice;
    });
    files.forEach(_startPrep);
  }

  void _addPaths(List<String> paths) {
    if (paths.isEmpty) return;
    final intake = intakeOutgoingPaths(
      paths,
      maxBytes: widget.maxBytes,
      alreadyAdded: {for (final f in _files) f.path},
    );
    _addFiles(
      intake.files,
      notice: intake.rejectionText(maxBytes: widget.maxBytes, l10n: l10n),
    );
  }

  void _remove(OutgoingFile f) {
    setState(() => _files.remove(f));
    // Последний убран — окно больше не о чем, как в Telegram.
    if (_files.isEmpty) _dismiss();
  }

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(SendMediaDismissed(_caption.text));
  }

  Future<void> _send() async {
    if (_files.isEmpty || _sending || _closed) return;
    setState(() => _sending = true);
    // Отправлять можно, только когда известно, ЧТО отправлять: HEIC ещё
    // перекодируется, у ролика ещё нет кадра. Обычно это доли секунды.
    try {
      await Future.wait([
        for (final f in _files) _prep[f] ?? OutgoingMediaPrep.prepare(f),
      ]).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Не дождались — уходит как есть; подготовка не условие отправки.
    }
    if (!mounted || _closed) return;
    _closed = true;
    Navigator.of(context).pop(
      SendMediaResult(
        files: List<OutgoingFile>.unmodifiable(_files),
        sendAsFiles: _asFiles,
        grouped: _grouped,
        caption: _caption.text.trim(),
      ),
    );
  }

  Future<void> _pickMore() async {
    final pick = widget.onPickMore;
    if (pick == null) return;
    final paths = await pick();
    if (!mounted) return;
    _addPaths(paths);
    _captionFocus.requestFocus();
  }

  Future<void> _openMore() async {
    final box = _moreKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final hasVisual = _files.any((f) => f.isVisual && f.canBeMedia);
    final sections = <List<CtxMenuItem>>[
      [
        if (hasVisual)
          CtxMenuItem(
            label: _asFiles ? l10n.desktopSendAsMedia : l10n.desktopSendAsFiles,
            icon: _asFiles
                ? FluentIcons.image_multiple_24_regular
                : FluentIcons.document_multiple_24_regular,
            onTap: () => setState(() => _asFiles = !_asFiles),
          ),
        if (_files.length > 1)
          CtxMenuItem(
            label: _grouped ? l10n.desktopSendUngroup : l10n.desktopSendGroup,
            icon: _grouped
                ? FluentIcons.group_dismiss_24_regular
                : FluentIcons.group_24_regular,
            onTap: () => setState(() => _grouped = !_grouped),
          ),
      ],
      [
        if (widget.onPickMore != null)
          CtxMenuItem(
            label: l10n.desktopSendAddFiles,
            icon: FluentIcons.add_24_regular,
            onTap: () => unawaited(_pickMore()),
          ),
      ],
    ].where((s) => s.isNotEmpty).toList();
    if (sections.isEmpty) return;
    final origin = box.localToGlobal(Offset(0, box.size.height + 4));
    await ContextMenu.show(
      context,
      globalPosition: origin.translate(-180 + box.size.width, 0),
      sections: sections,
    );
    if (mounted) _captionFocus.requestFocus();
  }

  Future<void> _openEmoji() async {
    final picked = await EmojiPopover.show(
      context,
      anchorKey: _emojiKey,
      emojiOnly: true,
    );
    if (!mounted) return;
    if (picked != null && picked.isNotEmpty) _insertText(picked);
    _captionFocus.requestFocus();
  }

  void _insertText(String text) {
    final value = _caption.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    _caption.value = TextEditingValue(
      text: value.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  /// ⌘V в подписи: файлы и картинки добавляются в окно, текст вставляется.
  Future<void> _paste() async {
    final paths = await DesktopClipboardMedia.files();
    if (!mounted) return;
    if (paths.isNotEmpty) {
      _addPaths(paths);
      return;
    }
    final image = await DesktopClipboardMedia.image();
    if (!mounted) return;
    if (image != null) {
      final staged = await OutgoingMediaPrep.stagePastedImage(image);
      if (staged != null) _addFiles([staged]);
      return;
    }
    final text = await DesktopClipboardMedia.text();
    if (!mounted || text == null || text.isEmpty) return;
    _insertText(text);
  }

  KeyEventResult _onCaptionKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      return KeyEventResult.handled;
    }
    final isPaste =
        e.logicalKey == LogicalKeyboardKey.keyV &&
        (keyboard.isMetaPressed || keyboard.isControlPressed);
    if (isPaste) {
      unawaited(_paste());
      return KeyEventResult.handled;
    }
    final isEnter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    // Та же настройка, что у поля ввода: какая из клавиш отправляет.
    if (!shouldSendOnEnter(
      enterToSend: DesktopUiPrefs.enterToSend.value,
      shiftPressed: keyboard.isShiftPressed,
    )) {
      return KeyEventResult.ignored;
    }
    unawaited(_send());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final screen = MediaQuery.sizeOf(context);
    final animation = widget.animation ?? kAlwaysCompleteAnimation;
    final groups = planOutgoingGroups(
      _files,
      sendAsFiles: _asFiles,
      grouped: _grouped,
    );
    // 🔴 Esc ЗАКРЫВАЕТ ОКНО И ТОГДА, КОГДА ЕГО ЗАБРАЛА СИСТЕМА ВВОДА.
    //
    // Проверено вживую 16.09.2026: пока у поля macOS держит незавершённый
    // набор (подсказку, «пометку»), Esc приходит не клавишей, а командой
    // `cancelOperation:` — Flutter превращает её в [DismissIntent] и ищет, кто
    // её примет. Раньше не принимал никто, и окно не закрывалось.
    return Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _dismiss();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        // Своя область фокуса — как у [DesktopDialog]: снятый с поля фокус
        // остаётся в окне, и Esc по-прежнему доходит до сочетания выше.
        child: FocusScope(
          autofocus: true,
          child: _dropArea(c, screen, animation, groups),
        ),
      ),
    );
  }

  Widget _dropArea(
    DColorSet c,
    Size screen,
    Animation<double> animation,
    List<OutgoingGroup> groups,
  ) {
    return DropTarget(
      // Всё окно принимает файлы: промахнуться мимо карточки легко, а
      // брошенное «мимо» не должно пропадать.
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _addPaths([for (final f in detail.files) f.path]);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = animation.value;
                  return BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
                    child: ColoredBox(
                      color: c.scrim.withValues(alpha: 0.45 * t),
                    ),
                  );
                },
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                key: const ValueKey('send-media-card'),
                width: _kDialogWidth,
                constraints: BoxConstraints(maxHeight: screen.height * 0.88),
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(DRadii.r16),
                  border: Border.all(color: c.borderSubtle),
                  boxShadow: DShadows.dialog,
                ),
                clipBehavior: Clip.antiAlias,
                // Material — ради поля ввода: TextField без него не живёт.
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(c),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                _kContentPadding,
                                0,
                                _kContentPadding,
                                _kContentPadding,
                              ),
                              child: _preview(c, groups),
                            ),
                          ),
                          if (_notice != null) _noticeLine(c, _notice!),
                          _footer(c),
                        ],
                      ),
                      if (_dragging)
                        Positioned.fill(
                          child: AttachmentsDropZone(
                            visible: true,
                            message: l10n.desktopSendDropHere,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(DColorSet c) {
    final destination = widget.destinationTitle?.trim() ?? '';
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const SizedBox(width: 8),
          DesktopIconButton(
            icon: FluentIcons.dismiss_24_regular,
            tooltip: l10n.desktopSendCloseEsc,
            onPressed: _dismiss,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  outgoingDialogTitle(_files, sendAsFiles: _asFiles, l10n: l10n),
                  key: const ValueKey('send-media-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DType.title.copyWith(color: c.textPrimary),
                ),
                if (destination.isNotEmpty)
                  Text(
                    l10n.desktopSendToDestination(destination),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: DType.caption.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
          DesktopIconButton(
            key: _moreKey,
            icon: FluentIcons.more_horizontal_24_regular,
            tooltip: l10n.desktopThreadMore,
            onPressed: () => unawaited(_openMore()),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _preview(DColorSet c, List<OutgoingGroup> groups) {
    // Ширина — по настоящей раскладке: рамка окна тоже занимает место.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floorToDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              if (groups[i].asMedia)
                _mediaGroup(c, groups[i], width)
              else
                _fileGroup(c, groups[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _mediaGroup(DColorSet c, OutgoingGroup group, double width) {
    const outer = BorderRadius.all(Radius.circular(DRadii.r12));
    final files = group.files;
    if (files.length == 1) {
      final f = files.single;
      final src = f.size ?? const Size(4, 3);
      final h = (width * src.height / src.width)
          .clamp(140.0, 420.0)
          .roundToDouble();
      return _PreviewTile(
        key: ValueKey('send-media-tile-${f.path}'),
        file: f,
        size: Size(width, h),
        radius: outer,
        background: c.thread,
        onRemove: () => _remove(f),
      );
    }
    final layout = layoutMediaGroup(
      [for (final f in files) f.size ?? const Size(1, 1)],
      maxWidth: width,
      minWidth: 60,
      spacing: 4,
    );
    return SizedBox.fromSize(
      size: mediaGroupSize(layout),
      child: Stack(
        children: [
          for (var i = 0; i < layout.length; i++)
            Positioned.fromRect(
              rect: layout[i].rect,
              child: _PreviewTile(
                key: ValueKey('send-media-tile-${files[i].path}'),
                file: files[i],
                size: layout[i].rect.size,
                radius: tileRadius(layout[i].corners, outer),
                background: c.thread,
                onRemove: () => _remove(files[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileGroup(DColorSet c, OutgoingGroup group) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: c.thread,
        borderRadius: BorderRadius.circular(DRadii.r12),
      ),
      child: Column(
        children: [
          for (final f in group.files)
            _PreviewFileRow(
              key: ValueKey('send-media-file-${f.path}'),
              file: f,
              onRemove: () => _remove(f),
            ),
        ],
      ),
    );
  }

  Widget _noticeLine(DColorSet c, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              FluentIcons.warning_16_regular,
              size: 14,
              color: c.warning,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: DType.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kContentPadding,
        0,
        _kContentPadding,
        _kContentPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.only(left: 14, right: 2),
              decoration: BoxDecoration(
                color: c.thread,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Focus(
                        onKeyEvent: _onCaptionKey,
                        child: TextField(
                          key: const ValueKey('send-media-caption'),
                          controller: _caption,
                          focusNode: _captionFocus,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          style: DType.body.copyWith(color: c.textPrimary),
                          cursorColor: c.accentPrimary,
                          cursorWidth: 1.5,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: l10n.desktopSendCaptionHint,
                            hintStyle: DType.body.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: DesktopIconButton(
                      key: _emojiKey,
                      icon: FluentIcons.emoji_24_regular,
                      tooltip: l10n.desktopSendEmoji,
                      onPressed: () => unawaited(_openEmoji()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendRoundButton(
            busy: _sending,
            onTap: _files.isEmpty ? null : () => unawaited(_send()),
          ),
        ],
      ),
    );
  }
}

/// Плитка превью: снимок, гифка или кадр ролика; «×» по наведению.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    super.key,
    required this.file,
    required this.size,
    required this.radius,
    required this.background,
    required this.onRemove,
  });

  final OutgoingFile file;
  final Size size;
  final BorderRadius radius;
  final Color background;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final preview = file.previewPath;
    final isVideo = file.kind == OutgoingKind.video;
    final Widget picture;
    if (preview != null) {
      picture = LocalMediaImage(
        path: preview,
        size: size,
        sourceSize: file.size,
        background: background,
        fallback: ColoredBox(color: background),
      );
    } else {
      picture = ColoredBox(
        color: background,
        child: Center(
          child: file.prepared
              ? Icon(
                  isVideo
                      ? FluentIcons.video_24_regular
                      : FluentIcons.image_24_regular,
                  size: 28,
                  color: Colors.white54,
                )
              : const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white70),
                  ),
                ),
        ),
      );
    }
    final duration = file.durationMs;
    return _HoverRemovable(
      onRemove: onRemove,
      radius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              picture,
              if (isVideo)
                const Center(
                  child: IgnorePointer(
                    child: MediaCenterButton(icon: FluentIcons.play_24_filled),
                  ),
                ),
              if (isVideo && duration != null && duration > 0)
                Positioned(
                  left: 6,
                  top: 6,
                  child: MediaBadge(child: Text(formatMediaDuration(duration))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка документа в окне: значок или миниатюра, имя, размер.
class _PreviewFileRow extends StatelessWidget {
  const _PreviewFileRow({super.key, required this.file, required this.onRemove});

  final OutgoingFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final preview = file.previewPath;
    final Widget leading;
    if (preview != null && file.kind != OutgoingKind.audio) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(DRadii.r8),
        child: LocalMediaImage(
          path: preview,
          size: const Size.square(44),
          sourceSize: file.size,
          background: c.elevated,
          fallback: ColoredBox(color: c.elevated),
        ),
      );
    } else {
      leading = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.accentPrimary,
        ),
        alignment: Alignment.center,
        child: Icon(
          switch (file.kind) {
            OutgoingKind.audio => FluentIcons.music_note_2_24_regular,
            OutgoingKind.video => FluentIcons.video_24_regular,
            OutgoingKind.photo ||
            OutgoingKind.gif => FluentIcons.image_24_regular,
            OutgoingKind.file => FluentIcons.document_24_regular,
          },
          size: 20,
          color: Colors.white,
        ),
      );
    }
    return _HoverRemovable(
      onRemove: onRemove,
      radius: BorderRadius.circular(DRadii.r8),
      removeAlignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            SizedBox.square(dimension: 44, child: leading),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Песня — как в Telegram: название из тегов, под ним
                  // исполнитель и размер. Нет тегов — имя файла.
                  MiddleEllipsisText(
                    file.musicTitle ?? file.name,
                    style: DType.bodyStrong.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      ?file.musicArtist,
                      formatAttachmentSize(file.sizeBytes, l10n),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            // Место под «×», чтобы он не наезжал на имя.
            const SizedBox(width: 30),
          ],
        ),
      ),
    );
  }
}

/// «×» в углу по наведению — убрать файл из пачки.
class _HoverRemovable extends StatefulWidget {
  const _HoverRemovable({
    required this.child,
    required this.onRemove,
    required this.radius,
    this.removeAlignment = Alignment.topRight,
  });

  final Widget child;
  final VoidCallback onRemove;
  final BorderRadius radius;
  final Alignment removeAlignment;

  @override
  State<_HoverRemovable> createState() => _HoverRemovableState();
}

class _HoverRemovableState extends State<_HoverRemovable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: Align(
              alignment: widget.removeAlignment,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: DMotion.fast,
                  child: IgnorePointer(
                    ignoring: !_hover,
                    child: DesktopTooltip(
                      message: l10n.desktopSendRemove,
                      child: HoverListener(
                        onTap: widget.onRemove,
                        builder: (ctx, hovered, pressed) => Container(
                          key: const ValueKey('send-media-remove'),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hovered
                                ? DMedia.badgeBgHover
                                : DMedia.badgeBg,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            FluentIcons.dismiss_24_regular,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Круглая синяя кнопка отправки — как на скриншоте Telegram.
class _SendRoundButton extends StatelessWidget {
  const _SendRoundButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final enabled = onTap != null && !busy;
    return DesktopTooltip(
      message: DesktopUiPrefs.enterToSend.value
          ? l10n.desktopSendEnter
          : l10n.desktopSendShiftEnter,
      child: HoverListener(
        onTap: enabled ? onTap : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          key: const ValueKey('send-media-send'),
          duration: DMotion.fast,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: onTap != null
                  ? [c.accentPrimary, c.accentPrimaryAlt]
                  : [c.hover, c.hover],
            ),
            boxShadow: onTap != null
                ? [
                    BoxShadow(
                      color: c.accentPrimaryAlt.withValues(
                        alpha: hovered ? 0.45 : 0.3,
                      ),
                      blurRadius: hovered ? 18 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  FluentIcons.arrow_up_24_filled,
                  size: 20,
                  color: onTap != null ? Colors.white : c.textDisabled,
                ),
        ),
      ),
    );
  }
}
