// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:record/record.dart';

import '../../../links/link_preview_draft.dart';
import '../design/tokens.dart';
import 'desktop_mentions.dart';
import 'link_preview_card.dart';
import 'outgoing_media.dart' show DesktopClipboardMedia;
import '../services/desktop_ui_prefs.dart';
import '../primitives/glass.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_button.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Reply / Edit context displayed above the composer.
///
/// Carries the target message's logical [payloadEventId] so that, on send, the
/// thread can route a reply through `sendMessage(replyToPayloadEventId: …)` or
/// an edit through `editTextMessage(payloadEventId: …)`. Without it the reply
/// target / edit target is lost and the action silently no-ops (reply) or
/// duplicates the message (edit).
class ComposerContext {
  const ComposerContext.reply({
    required this.authorName,
    required this.preview,
    this.payloadEventId,
  }) : isEdit = false;
  const ComposerContext.edit({required this.preview, this.payloadEventId})
    : authorName = '',
      isEdit = true;
  final String authorName;
  final String preview;
  final bool isEdit;

  /// Logical payload-event id of the message being replied to / edited.
  final String? payloadEventId;
}

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onScheduleSend,
    this.onAttach,
    this.onEmoji,
    this.onVoice,
    this.onSendVoice,
    this.onPasteImage,
    this.onPasteFiles,
    this.onTypingActivity,
    this.context,
    this.onClearContext,
    this.attachAnchorKey,
    this.emojiAnchorKey,
    this.placeholder,
    this.topicTitle,
    this.mentionTargets = const <DesktopMentionTarget>[],
    this.autofocus = false,
    this.linkPreviewDraft,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  /// Спросить время и отправить отложенно. Возвращает `true`, если время
  /// выбрано и сообщение поставлено в очередь, — тогда поле чистится.
  final Future<bool> Function(String text)? onScheduleSend;

  /// E7: an image pasted from the clipboard (Cmd/Ctrl+V). When wired, the
  /// composer intercepts paste, and if the clipboard holds an image it hands
  /// the bytes here instead of pasting text; plain text still pastes normally.
  final ValueChanged<Uint8List>? onPasteImage;

  /// ⌘V со скопированными в Finder файлами — их пути.
  final ValueChanged<List<String>>? onPasteFiles;

  /// E9: fired on each keystroke while the field is non-empty, so the host can
  /// emit a (throttled) typing signal to the peer.
  final VoidCallback? onTypingActivity;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback? onVoice;

  /// E7: a recorded voice note is ready to send — receives the temp file path
  /// (opus) and its duration in ms. When wired, the mic button records instead
  /// of invoking [onVoice].
  final void Function(String path, int durationMs)? onSendVoice;
  final ComposerContext? context;
  final VoidCallback? onClearContext;
  final GlobalKey? attachAnchorKey;
  final GlobalKey? emojiAnchorKey;
  /// Пусто — берём подпись из переводов при отрисовке.
  final String? placeholder;

  /// Тема, в которую уходит сообщение. `null` — «Общий» или личная переписка.
  ///
  /// 🔴 ДО ЭТОГО ТЕМА ЖИЛА ТОЛЬКО В ПЛЕЙСХОЛДЕРЕ — и исчезала с первым же
  /// набранным символом. Самая дорогая ошибка в мессенджере с темами —
  /// написать не туда, а подсказка пропадала ровно в тот момент, когда
  /// человек начинал писать.
  final String? topicTitle;

  /// Кого можно позвать через «@». Пусто — подстановки нет вовсе (личная
  /// переписка, комната без загруженного состава).
  final List<DesktopMentionTarget> mentionTargets;

  final bool autofocus;

  /// Карточка ссылки, которая уйдёт вместе с сообщением, — над полем, как
  /// карточка ответа. `null` — превью выключены или идёт правка.
  final OutgoingLinkPreviewDraft? linkPreviewDraft;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  /// Подписи поля ввода.
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _focus = FocusNode();
  bool _hasText = false;

  // E7 voice recording (opus → renders as a voice note everywhere).
  AudioRecorder? _recorder;
  bool _recording = false;
  Timer? _recTimer;
  int _recMs = 0;
  String? _recPath;
  static const int _recMinMs = 700;

  @override
  void initState() {
    super.initState();
    // Seed from the controller so a pre-loaded draft shows Send (not the mic)
    // on first build — the change listener fires only on later edits.
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onChange);
    // 🔴 РАМКА ФОКУСА БЫЛА НАПИСАНА, НО НЕ ПЕРЕРИСОВЫВАЛАСЬ.
    //
    // Цвет рамки читает `_focus.hasFocus`, а подписки на узел не было ни
    // одной: `TextField` перестраивает себя сам, но рамку рисует контейнер
    // ВОКРУГ него — из `build` этого состояния. Поэтому акцент появлялся не
    // по щелчку в поле, а с первым набранным символом (его перерисовывал
    // `_onChange`), и пропадал не по уходу фокуса, а когда что-то ещё
    // случайно перестраивало композер.
    _focus.addListener(_onFocus);
    widget.linkPreviewDraft?.addListener(_onLinkDraft);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (!identical(old.linkPreviewDraft, widget.linkPreviewDraft)) {
      old.linkPreviewDraft?.removeListener(_onLinkDraft);
      widget.linkPreviewDraft?.addListener(_onLinkDraft);
    }
  }

  /// Появилась или пропала карточка ссылки — меняется форма поля (скругление
  /// сверху уходит к карточке).
  void _onLinkDraft() {
    if (mounted) setState(() {});
  }

  bool get _linkBarVisible {
    final d = widget.linkPreviewDraft;
    return d != null && (d.preview != null || d.loading);
  }

  void _onChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (has) widget.onTypingActivity?.call();
    _syncMentions();
  }

  // ── Подстановка участников по «@» ────────────────────────────────────────
  //
  // Без неё нужный ярлык не набрать: он собирается из имени по правилам
  // (пробелы в подчёркивания, знаки прочь), и угадать «@Игорь_Петров» по
  // виду «Игорь Петров» человек не обязан. А не угадав — отправит обычный
  // текст, и позванный об этом не узнает.

  List<DesktopMentionTarget> _mentionMatches = const <DesktopMentionTarget>[];
  DesktopMentionDraft? _mentionDraft;
  int _mentionCursor = 0;

  /// Человек закрыл список Escape'ом — не открывать его снова, пока он не
  /// начнёт новое «@». Иначе Escape не закрывал бы ничего.
  bool _mentionDismissed = false;

  void _syncMentions() {
    if (widget.mentionTargets.isEmpty) {
      if (_mentionDraft != null) setState(() => _mentionDraft = null);
      return;
    }
    final v = widget.controller.value;
    final sel = v.selection;
    final draft = (sel.isValid && sel.isCollapsed)
        ? desktopMentionDraft(text: v.text, caret: sel.baseOffset)
        : null;
    if (draft == null) {
      _mentionDismissed = false;
      if (_mentionDraft != null) {
        setState(() {
          _mentionDraft = null;
          _mentionMatches = const <DesktopMentionTarget>[];
        });
      }
      return;
    }
    if (_mentionDismissed) return;
    final matches = desktopMentionMatches(
      targets: widget.mentionTargets,
      query: draft.query,
    );
    setState(() {
      _mentionDraft = matches.isEmpty ? null : draft;
      _mentionMatches = matches;
      if (_mentionCursor >= matches.length) _mentionCursor = 0;
    });
  }

  void _applyMention(DesktopMentionTarget t) {
    final draft = _mentionDraft;
    if (draft == null) return;
    final text = widget.controller.text;
    // Пробел после ярлыка ставим сами: без него следующее слово прилипнет к
    // имени, и разбор на отправке упоминания уже не увидит — у него граница
    // обязана быть разделителем.
    final inserted = '${t.token} ';
    final next = text.replaceRange(draft.start, draft.end, inserted);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: draft.start + inserted.length,
      ),
    );
    setState(() {
      _mentionDraft = null;
      _mentionMatches = const <DesktopMentionTarget>[];
      _mentionCursor = 0;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focus.removeListener(_onFocus);
    widget.linkPreviewDraft?.removeListener(_onLinkDraft);
    _recTimer?.cancel();
    unawaited(_recorder?.dispose());
    _focus.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    final rec = _recorder ??= AudioRecorder();
    try {
      if (!await rec.hasPermission()) return;
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}voice-${DateTime.now().millisecondsSinceEpoch}.opus';
      await rec.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 32000,
          sampleRate: 48000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        await rec.stop();
        return;
      }
      setState(() {
        _recording = true;
        _recPath = path;
        _recMs = 0;
      });
      _recTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _recMs += 200);
      });
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    _recTimer = null;
    final durMs = _recMs;
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (_) {
      path = null;
    }
    path ??= _recPath;
    if (mounted) setState(() => _recording = false);
    final tooShort = durMs < _recMinMs;
    if (!send || tooShort || path == null) {
      if (path != null) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      return;
    }
    widget.onSendVoice?.call(path, durMs);
  }

  static String _fmtRec(int ms) {
    final s = ms ~/ 1000;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _trySend() {
    final txt = widget.controller.text.trim();
    if (txt.isEmpty) return;
    widget.onSend(txt);
    widget.controller.clear();
  }

  /// Отложенная отправка. Поле чистим ТОЛЬКО когда время выбрано: передумав,
  /// человек обязан найти набранное на месте.
  Future<void> _trySendLater() async {
    final ask = widget.onScheduleSend;
    if (ask == null) return;
    final txt = widget.controller.text.trim();
    if (txt.isEmpty) return;
    final sent = await ask(txt);
    if (!mounted || !sent) return;
    widget.controller.clear();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // 🔴 СПИСОК УЧАСТНИКОВ ЗАБИРАЕТ КЛАВИШИ ПЕРВЫМ, пока он открыт.
    //
    // Иначе Enter отправлял бы сообщение с недонабранным «@иг» вместо того,
    // чтобы подставить выбранного, а стрелки уводили бы курсор в тексте
    // мимо списка.
    if (_mentionDraft != null && _mentionMatches.isNotEmpty) {
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(
          () => _mentionCursor = (_mentionCursor + 1) % _mentionMatches.length,
        );
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _mentionCursor =
              (_mentionCursor - 1 + _mentionMatches.length) %
              _mentionMatches.length,
        );
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.numpadEnter ||
          e.logicalKey == LogicalKeyboardKey.tab) {
        _applyMention(_mentionMatches[_mentionCursor]);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.escape) {
        // Закрываем список, а не карточку ответа: закрывается то, что
        // человек открыл последним.
        setState(() {
          _mentionDismissed = true;
          _mentionDraft = null;
          _mentionMatches = const <DesktopMentionTarget>[];
        });
        return KeyEventResult.handled;
      }
    }
    // E7: Cmd/Ctrl+V — intercept so a clipboard IMAGE attaches instead of
    // doing nothing. Only when paste-image is wired, so plain-text contexts
    // keep the TextField's native paste. _handlePaste falls back to text.
    final isPaste =
        e.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (isPaste &&
        (widget.onPasteImage != null || widget.onPasteFiles != null)) {
      unawaited(_handlePaste());
      return KeyEventResult.handled;
    }
    final isEnter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    // The «Enter отправляет сообщение» setting used to be a dead switch —
    // Enter always sent. It now decides which of Enter / Shift+Enter sends and
    // which inserts a newline; returning `ignored` lets the TextField insert
    // the newline itself.
    final sendOnThisChord = shouldSendOnEnter(
      enterToSend: DesktopUiPrefs.enterToSend.value,
      shiftPressed: shift,
    );
    if (!sendOnThisChord) return KeyEventResult.ignored;
    _trySend();
    return KeyEventResult.handled;
  }

  /// E7 paste handler: image on the clipboard → attach via [onPasteImage];
  /// otherwise replicate a plain-text paste at the caret (since we consumed
  /// the key event to get first crack at the image).
  Future<void> _handlePaste() async {
    // 🔴 Сперва файлы, потом картинка: у файла, скопированного в Finder, в
    // буфере лежит ещё и его значок — см. [DesktopClipboardMedia.files].
    final onFiles = widget.onPasteFiles;
    if (onFiles != null) {
      final paths = await DesktopClipboardMedia.files();
      if (!mounted) return;
      if (paths.isNotEmpty) {
        onFiles(paths);
        return;
      }
    }
    final onImage = widget.onPasteImage;
    if (onImage != null) {
      final img = await DesktopClipboardMedia.image();
      if (!mounted) return;
      if (img != null) {
        onImage(img);
        return;
      }
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final text = data?.text;
      if (text == null || text.isEmpty) return;
      final ctl = widget.controller;
      final sel = ctl.selection;
      final start = sel.isValid ? sel.start : ctl.text.length;
      final end = sel.isValid ? sel.end : ctl.text.length;
      final newText = ctl.text.replaceRange(start, end, text);
      ctl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
      );
    } catch (_) {
      // best-effort
    }
  }

  Widget _recordingBar(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          DesktopIconButton(
            icon: FluentIcons.delete_24_regular,
            tooltip: l10n.desktopComposerCancelRec,
            onPressed: () => unawaited(_stopRecording(send: false)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.desktopComposerRecording(_fmtRec(_recMs)),
            style: DType.body.copyWith(color: c.textPrimary),
          ),
          const Spacer(),
          _RoundIcon(
            icon: FluentIcons.send_24_filled,
            color: c.accentPrimary,
            tooltip: l10n.desktopComposerSendVoice,
            onTap: () => unawaited(_stopRecording(send: true)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return AnimatedContainer(
      duration: DMotion.fast,
      // 🔴 Поле ввода СЖАТО по высоте, и это не экономия ради экономии.
      //
      // Было 56 точек минимальной высоты плюс 12 снизу — под однострочное
      // сообщение отдавалась полоса в 80 точек, то есть примерно полторы
      // строки переписки на каждом экране. У поля ввода нет содержимого,
      // которое стоило бы этой высоты: оно пустое большую часть времени.
      //
      // Размеры взяты из макета: 52 точки поля, 10 снизу. Кнопки внутри при
      // этом не уменьшены — по ним попадают мышью.
      padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.s, DSpace.l, 10),
      // 🔴 ВОКРУГ ПОЛЯ ВВОДА НЕТ НИКАКОЙ ПАНЕЛИ (13.09.2026, макет владельца).
      //
      // Было: сплошная плашка цвета переписки с чертой сверху. Она отрезала
      // низ окна ровной линией, и лента упиралась в неё, как в пол. В макете
      // поле ввода ПЛАВАЕТ над перепиской: вокруг него прозрачно, сообщения
      // уходят под него и гаснут в затенении у нижней границы.
      //
      // Затенение рисует не поле ввода, а сама лента — см. `_bottomFade` в
      // `chat_thread_panel.dart`: оно должно лежать ПОД полем и НАД
      // сообщениями, а изнутри поля этого слоя не построить.
      //
      // 🔴 ПОДТВЕРЖДЕНО ПОВТОРНО 15.09.2026. Исходник макета от 14.09 рисует
      // под полем подложку `rgba(10,14,20,.8)` с чертой сверху — то есть
      // прямо обратное. Владельцу задан вопрос в лоб («плавает или лежит на
      // подложке?»), ответ: ПЛАВАЕТ.
      //
      // Одно с другим не складывается: подложка и затенение ленты дают
      // двойной пол — сперва градиент, потом ещё и сплошная полоса с чертой.
      // Поэтому расхождение с макетом здесь осознанное, а не забытое.
      decoration: const BoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mentionDraft != null && _mentionMatches.isNotEmpty)
            _MentionList(
              items: _mentionMatches,
              cursor: _mentionCursor,
              onPick: _applyMention,
              onHover: (i) => setState(() => _mentionCursor = i),
            ),
          // 🔴 ПОЛЕ ВВОДА — ОДИН ОСТРОВОК МАТОВОГО СТЕКЛА (24.09.2026).
          //
          // Превью ссылки, карточка ответа и само поле были тремя плашками с
          // общей рамкой, каждая со своей заливкой. Теперь это одно стекло,
          // как у телефона: лента под ним видна размытой. Рамка — только в
          // фокусе, цвета акцента; в покое край задаёт само стекло.
          _GlassFrame(
            focused: _focus.hasFocus,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Карточка ссылки — над карточкой ответа: ответ ближе к полю, потому
          // что относится к набираемому, а карточка — к ссылке внутри него.
          if (_linkBarVisible)
            DesktopLinkPreviewDraftBar(
              draft: widget.linkPreviewDraft!,
              frameColor: Colors.transparent,
              frameWidth: 0,
              fill: Colors.transparent,
            ),
          if (widget.context != null)
            _contextCard(c, widget.context!, roundTop: !_linkBarVisible),
          Container(
            // Геометрия из макета: содержимое от 34 точек, поля 10/8, то есть
            // внешняя высота около 52; радиус 12.
            //
            // 🔴 Высота ВЛИЯЕТ НА ЗАТЕНЕНИЕ ЛЕНТЫ: она измеряется живьём
            // (`_MeasuredComposer` → `_composerHeight`), и лента резервирует
            // под неё место. Менять её «на глаз» нельзя — проверено, что
            // затенение не прыгает.
            constraints: const BoxConstraints(minHeight: 52, maxHeight: 240),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _recording
                ? _recordingBar(c)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: DesktopIconButton(
                          key: widget.attachAnchorKey,
                          // «+», а не скрепка: в макете слева от поля стоит
                          // именно плюс. Скрепка обещает только файл, плюс —
                          // всё, что можно добавить (фото, файл, и дальше).
                          icon: FluentIcons.add_24_regular,
                          tooltip: l10n.desktopComposerAttach,
                          onPressed: widget.onAttach,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Focus(
                            onKeyEvent: _onKey,
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focus,
                              autofocus: widget.autofocus,
                              maxLines: 8,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              style: DType.body.copyWith(color: c.textPrimary),
                              cursorColor: c.accentPrimary,
                              cursorWidth: 1.5,
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: widget.placeholder ?? l10n.desktopThreadMessageHint,
                                hintStyle: DType.body.copyWith(
                                  color: c.textSecondary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: DesktopIconButton(
                          key: widget.emojiAnchorKey,
                          icon: FluentIcons.emoji_24_regular,
                          tooltip: l10n.desktopComposerEmoji,
                          onPressed: widget.onEmoji,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        // 🔴 МИКРОФОН И ОТПРАВКА БОЛЬШЕ НЕ ИСКЛЮЧАЮТ ДРУГ
                        // ДРУГА.
                        //
                        // Была одна кнопка на два действия: есть текст —
                        // «отправить», нет текста — «записать». То есть
                        // записать голосовое, не стерев начатый черновик,
                        // было НЕЛЬЗЯ; а стереть его, чтобы добраться до
                        // микрофона, — значит потерять написанное.
                        //
                        // В макете обе кнопки стоят рядом ОДНОВРЕМЕННО, и
                        // именно на кадре с уже набранным текстом.
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoundIcon(
                              icon: FluentIcons.mic_24_regular,
                              // 🔴 ПОДСКАЗКА ОБЕЩАЛА УДЕРЖАНИЕ, А РАБОТАЕТ
                              // НАЖАТИЕ. Кнопка запускает запись обычным
                              // нажатием и останавливает её отдельной кнопкой
                              // в полосе записи — ни `onLongPress`, ни
                              // `onLongPressEnd` в этом файле нет вовсе.
                              // Человек жал и держал, ничего не происходило
                              // по отпусканию, и он решал, что запись
                              // сломана.
                              //
                              // Для стола нажатие уместнее удержания:
                              // голосовое на компьютере пишут не
                              // пятисекундное. Поэтому исправлена подпись, а
                              // не поведение.
                              tooltip: l10n.desktopComposerRecordVoice,
                              onTap: widget.onSendVoice != null
                                  ? () => unawaited(_startRecording())
                                  : widget.onVoice,
                            ),
                            const SizedBox(width: 4),
                            // Отправка ВИДНА всегда, но без текста погашена:
                            // исчезающая кнопка сдвигает соседнюю под курсор,
                            // а главное действие поля не должно прыгать.
                            _SendButton(
                              onTap: _hasText ? _trySend : null,
                              onScheduleTap: widget.onScheduleSend == null
                                  ? null
                                  : _trySendLater,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
            child: Row(
              children: [
                // 🔴 Подсказка ЧИТАЕТ настройку, а не повторяет её значение по
                // умолчанию.
                //
                // Строка была написана буквами: «Enter — отправить ·
                // Shift+Enter — новая строка». Само поле при этом слушается
                // [DesktopUiPrefs.enterToSend] и при выключенной настройке
                // меняет клавиши местами — а подсказка продолжала утверждать
                // обратное. Подпись, которая врёт про клавишу прямо над этой
                // клавишей, хуже отсутствующей подписи.
                if ((widget.topicTitle ?? '').trim().isNotEmpty) ...[
                  _TopicChip(title: widget.topicTitle!.trim()),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: DesktopUiPrefs.enterToSend,
                    builder: (ctx, enterToSend, _) => Text(
                      enterToSend
                          ? l10n.desktopComposerEnterSends
                          : l10n.desktopComposerEnterNewline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.tiny.copyWith(color: c.textDisabled),
                    ),
                  ),
                ),
                const Spacer(),
                // 🔴 Замок без подписи — как в макете, но со словами по
                // наведению.
                //
                // В макете здесь один приглушённый замок и ничего больше:
                // строка под полем ввода — служебная, и зелёная надпись
                // «сквозное шифрование» перетягивала на себя внимание каждый
                // раз, когда человек смотрел на своё же сообщение.
                //
                // Слова при этом НЕ выброшены: шифрование — не украшение, и
                // знать о нём человек должен уметь. Они переехали в подсказку
                // замка, то есть ровно туда, куда потянется тот, кто хочет
                // проверить.
                DesktopTooltip(
                  message: l10n.desktopSecurityE2ee,
                  child: Icon(
                    FluentIcons.lock_closed_16_filled,
                    size: 13,
                    color: c.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextCard(
    DColorSet c,
    ComposerContext ctx, {
    bool roundTop = true,
  }) {
    final icon = ctx.isEdit
        ? FluentIcons.edit_24_regular
        : FluentIcons.arrow_reply_24_regular;
    // Средняя точка, а не тире: в макете «Ответ · Игорь». Тире между словом
    // и именем читается как «Ответ минус Игорь».
    final title = ctx.isEdit ? l10n.desktopComposerEditing : l10n.desktopComposerReplyTo(ctx.authorName);
    return AnimatedSize(
      duration: DMotion.fast,
      child: Container(
        // Отступы из макета: 7 сверху и снизу, 9 слева (под значок) и 10
        // справа.
        padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
        decoration: BoxDecoration(
          // Внутри стеклянного островка: своей заливки и рамки нет, шов с
          // полем — одна волосяная черта.
          border: Border(bottom: BorderSide(color: c.borderHairline)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Порядок из макета: сперва ЗНАЧОК (он называет, что это —
              // ответ или правка), потом полоска, потом текст. Полоска первой
              // не говорила ничего: цветная черта у левого края есть и у
              // цитаты в пузыре, и у выделенной строки списка.
              // #6FA8F7 — служебный синий ленты: им же набраны имя автора в
              // чужом пузыре и галочки доставки. Сам `accentPrimary` (#3E8BF5)
              // на шаг темнее и на подложке поля читается глуше.
              Icon(icon, size: 17, color: c.deliveryIndicator),
              const SizedBox(width: 9),
              Container(
                width: 2,
                height: 26,
                decoration: BoxDecoration(
                  color: c.deliveryIndicator,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DType.caption.copyWith(
                        fontSize: 11.5,
                        color: c.deliveryIndicator,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      ctx.preview,
                      style: DType.caption.copyWith(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              DesktopIconButton(
                icon: FluentIcons.dismiss_24_regular,
                tooltip: l10n.desktopComposerCancelAction,
                size: 26,
                iconSize: 16,
                // · Скруглённый квадрат, а не таблетка (макет): значок стоит
                // ВНУТРИ карточки с радиусом 12, и кружок в её углу спорил с
                // её собственной формой.
                radius: DRadii.r8,
                onPressed: widget.onClearContext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка отправки — залитая градиентом, как в макете.
///
/// 🔴 Единственное действие поля ввода, ради которого поле и существует.
/// Прозрачным кружком среди таких же прозрачных кружков оно ничем не
/// отличалось от «прикрепить» и «эмодзи» — то есть главное действие выглядело
/// как служебное. Заливка тем же градиентом, что у своих пузырей, связывает
/// кнопку с тем, что она производит.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, this.onScheduleTap});

  /// `null` — текста нет: кнопка видна, но не нажимается.
  final VoidCallback? onTap;

  /// 🔴 «ОТПРАВИТЬ ПОЗЖЕ» — ПРАВОЙ КНОПКОЙ ПО ОТПРАВКЕ.
  ///
  /// На телефоне это удержание кнопки отправки. Удержания на столе нет, а
  /// заводить рядом вторую кнопку ради редкого действия значит тратить место
  /// главного действия на служебное. Правая кнопка — привычный способ
  /// спросить «а как ещё можно»; подсказка о ней написана прямо в подсказке
  /// самой отправки, иначе это было бы тайным знанием.
  final VoidCallback? onScheduleTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final enabled = onTap != null;
    return DesktopTooltip(
      message: enabled
          ? l10n.desktopComposerSendHint
          : l10n.desktopComposerWriteFirst,
      child: HoverListener(
        onTap: onTap,
        onSecondaryTapDown: (enabled && onScheduleTap != null)
            ? (_) => onScheduleTap!()
            : null,
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? [c.accentPrimary, c.accentPrimaryAlt]
                  // Погашенная кнопка — та же форма серым: пустое место на
                  // её месте сдвигало бы микрофон под курсор.
                  : [c.elevated, c.elevated],
            ),
            borderRadius: BorderRadius.circular(11),
            // 🔴 ТЕНЬ ПОСТОЯННАЯ, а не «по наведению».
            //
            // Она включалась только под курсором — то есть кнопка отрывалась
            // от поля ровно тогда, когда на неё уже смотрят, и лежала плоско
            // всё остальное время. В макете тень у неё есть всегда: это
            // главное действие поля ввода, и приподнятость — то, чем оно
            // отличается от соседних прозрачных кружков. Наведение тень
            // УСИЛИВАЕТ, а не зажигает.
            border: enabled ? null : Border.all(color: c.borderSubtle),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: c.accentPrimaryAlt.withValues(
                        alpha: hovered ? 0.45 : 0.32,
                      ),
                      blurRadius: hovered ? 24 : 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            FluentIcons.send_24_filled,
            size: 19,
            color: enabled ? Colors.white : c.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    this.color,
    this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final fg = color ?? c.textPrimary;
    final btn = HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: hovered
              ? (color != null ? c.selected : c.hover)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DRadii.pill),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// Чип «в тему «Общий»» под полем ввода.
///
/// 🔴 ПОЧЕМУ ОН НУЖЕН, ЕСЛИ ТЕМА И ТАК НАПИСАНА В ПЛЕЙСХОЛДЕРЕ.
///
/// Потому что плейсхолдер исчезает с первым набранным символом — то есть
/// ровно тогда, когда человек начинает писать. Самая дорогая ошибка в
/// мессенджере с темами это написать не туда; чип отвечает на вопрос «куда я
/// пишу» всё время, пока идёт набор.
class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.hover,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.number_symbol_16_regular,
            size: 14,
            color: c.textTertiary,
          ),
          const SizedBox(width: 5),
          Text(
            l10n.desktopComposerToTopic(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DType.tiny.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Список тех, кого можно позвать, — над полем ввода.
///
/// Стоит НАД полем, а не под ним: поле у нижнего края окна, и список под ним
/// уехал бы за границу. По той же причине он ограничен по высоте и
/// прокручивается — в комнате на тридцать человек иначе перекрыло бы всю
/// переписку.
class _MentionList extends StatelessWidget {
  const _MentionList({
    required this.items,
    required this.cursor,
    required this.onPick,
    required this.onHover,
  });

  final List<DesktopMentionTarget> items;
  final int cursor;
  final ValueChanged<DesktopMentionTarget> onPick;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: DSpace.s),
      constraints: const BoxConstraints(maxHeight: 216),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.r12),
        border: Border.all(color: c.borderSubtle),
        boxShadow: DShadows.popover,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final t = items[i];
          final active = i == cursor;
          return HoverListener(
            onTap: () => onPick(t),
            cursor: SystemMouseCursors.click,
            builder: (ctx, hovered, pressed) {
              if (hovered && !active) onHover(i);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                color: active ? c.hover : Colors.transparent,
                child: Row(
                  children: [
                    if (t.isBroadcast)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accentPrimary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FluentIcons.people_24_regular,
                          size: 15,
                          color: c.deliveryIndicator,
                        ),
                      )
                    else
                      Avatar(
                        name: t.title,
                        image: Avatar.fileImage(t.avatarPath),
                        size: 26,
                      ),
                    const SizedBox(width: DSpace.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DType.label.copyWith(
                              fontSize: 12.5,
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if ((t.subtitle ?? '').isNotEmpty)
                            Text(
                              t.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DType.tiny.copyWith(
                                color: c.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DSpace.s),
                    // Сам ярлык виден заранее: человек должен знать, что
                    // попадёт в текст, ДО нажатия — имя и ярлык совпадают не
                    // всегда.
                    Text(
                      t.token,
                      style: DType.meta.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Стекло поля ввода с рамкой фокуса.
///
/// Рамка — только когда курсор в поле, цвета акцента: видно, куда пойдёт
/// набор. В покое край задаёт само стекло с бликом по верхней кромке.
class _GlassFrame extends StatelessWidget {
  const _GlassFrame({required this.focused, required this.child});

  final bool focused;
  final Widget child;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopGlass(
      radius: _radius,
      child: AnimatedContainer(
        duration: DMotion.fast,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            // Рамка ОБЩАЯ на карточку ответа и поле: при наборе это один
            // блок, а не два — шов между ними её не режет.
            color: focused ? c.accentPrimary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
