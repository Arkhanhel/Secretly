// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_controller.dart';
import 'settings_screen_l10n.dart';

/// In-app Support chat (TZ docs/TZ_SUPPORT_TICKETS_2026-07-24.md, Variant C).
/// The user types (and can attach a photo/file); the message is sealed to the
/// support key and posted to the relay, and admin replies stream back in-place.
/// The thread is cached locally per profile so it survives navigating away.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

/// Сколько сырых байт можно приложить к обращению в поддержку.
///
/// 🔴 Было ~58 КБ (полевой отчёт 03.08.2026: «пишет, что файл больше 58 КБ,
/// хотя фото весит 5 МБ»). Число не было произвольным — оно вытекало из
/// потолка реле в 128 КБ base64, — но приложить обычный снимок экрана было
/// нельзя, а именно снимок и нужен поддержке чаще всего.
const int kSupportAttachmentMaxBytes = 5 * 1024 * 1024;

/// Целевой вес СЖАТОГО фото. Бюджет теперь 5 МБ, но тратить его целиком на
/// снимок экрана незачем: 1.2 МБ при 2048 px читаются лучше, чем прежние
/// 58 КБ, и оставляют запас тексту и тех-инфо.
const int _kSupportPhotoTargetBytes = 1200 * 1024;

/// Сжимает фото под бюджет вложения. Работает в изоляте: декод, уменьшение
/// длинной стороны до 2048 px, затем понижение качества JPEG до попадания в
/// цель; крайняя мера — ещё уменьшить.
Uint8List _compressSupportImage(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return input;
  var im = decoded;
  if (im.width >= im.height && im.width > 2048) {
    im = img.copyResize(im, width: 2048);
  } else if (im.height > im.width && im.height > 2048) {
    im = img.copyResize(im, height: 2048);
  }
  for (final q in <int>[86, 76, 64, 52, 40]) {
    final out = img.encodeJpg(im, quality: q);
    if (out.length <= _kSupportPhotoTargetBytes) {
      return Uint8List.fromList(out);
    }
  }
  final small = img.copyResize(im, width: 1280);
  return Uint8List.fromList(img.encodeJpg(small, quality: 45));
}

/// «5 МБ» / «820 КБ» — для сообщений человеку, а не байты.
///
/// Единицы передаются вызывающим: строка про размер подставляется и в русское,
/// и в английское сообщение, и «5.0 МБ» посреди английского текста читалось бы
/// так же нелепо, как «5.0 MB» посреди русского.
String _humanBytes(int bytes, {required bool ru}) {
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    final n = mb.toStringAsFixed(mb >= 10 ? 0 : 1);
    return ru ? '$n МБ' : '$n MB';
  }
  final kb = (bytes / 1024).round();
  return ru ? '$kb КБ' : '$kb KB';
}

class _SupportMsg {
  _SupportMsg({
    required this.mine,
    required this.text,
    required this.tsMs,
    this.failed = false,
    this.attB64,
    this.attName,
    this.attMime,
  });

  final bool mine;
  final String text;
  final int tsMs;
  bool failed;
  final String? attB64;
  final String? attName;
  final String? attMime;

  bool get hasAtt => (attB64 ?? '').isNotEmpty;
  bool get isImage => (attMime ?? '').startsWith('image/');

  /// 🔴 Декодируем ОДИН раз. Геттер зовётся из build, а вложения теперь бывают
  /// до 5 МБ: раскодировать 6.7 МБ base64 на каждый кадр — это заметный рывок
  /// на каждой перерисовке ленты.
  Uint8List? _decoded;
  bool _decodeFailed = false;

  Uint8List? get attBytes {
    if (!hasAtt || _decodeFailed) return null;
    final cached = _decoded;
    if (cached != null) return cached;
    try {
      return _decoded = base64Decode(attB64!);
    } catch (_) {
      _decodeFailed = true;
      return null;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'mine': mine,
        'text': text,
        'ts': tsMs,
        if (failed) 'failed': true,
        if (hasAtt) 'att': attB64,
        if (hasAtt) 'attName': attName,
        if (hasAtt) 'attMime': attMime,
      };

  static _SupportMsg fromJson(Map<dynamic, dynamic> j) => _SupportMsg(
        mine: j['mine'] == true,
        text: (j['text'] as String?) ?? '',
        tsMs: (j['ts'] as num?)?.toInt() ?? 0,
        failed: j['failed'] == true,
        attB64: j['att'] as String?,
        attName: j['attName'] as String?,
        attMime: j['attMime'] as String?,
      );
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_SupportMsg> _messages = <_SupportMsg>[];
  int _cursor = 0;
  bool _loading = true;

  /// Последняя применённая отметка очистки — чтобы стирать ленту один раз, а
  /// не на каждом опросе (иначе новое обращение исчезало бы сразу после
  /// отправки).
  int _clearedSeenMs = 0;
  bool _sending = false;
  bool _attaching = false;
  Timer? _pollTimer;

  Uint8List? _pendAttBytes;
  String? _pendAttName;
  String? _pendAttMime;

  AppController get _c => widget.controller;
  String get _threadKey => 'support_thread_v1_${_c.profileId}';
  String get _cursorKey => 'support_cursor_v1_${_c.profileId}';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 🔴 Переписка лежит В ФАЙЛЕ, а не в SharedPreferences.
  ///
  /// Раньше вся лента (вместе с base64 вложений) писалась одной строкой в
  /// prefs. Пока вложение весило 58 КБ, это сходило с рук. С потолком в 5 МБ
  /// туда легло бы под 7 МБ — а SharedPreferences на Android читаются
  /// ЦЕЛИКОМ В ПАМЯТЬ при первом обращении, то есть на самом старте
  /// приложения. Мы бы своими руками усугубили ровно ту медленную загрузку,
  /// на которую жалуются.
  Future<File> _threadFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/support_thread_${_c.profileId}.json');
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getInt(_cursorKey) ?? 0;
    _clearedSeenMs = _c.supportClearedSeenAtMs;
    String? raw;
    try {
      final f = await _threadFile();
      if (await f.exists()) raw = await f.readAsString();
    } catch (_) {
      // повреждённый файл — начинаем с пустой ленты
    }
    // Переезд со старого места хранения: читаем один раз и ВЫЧИЩАЕМ ключ,
    // иначе многомегабайтная строка так и осталась бы висеть в prefs.
    final legacy = prefs.getString(_threadKey);
    if (legacy != null) {
      raw ??= legacy;
      await prefs.remove(_threadKey);
    }
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _messages.addAll(list.whereType<Map>().map(_SupportMsg.fromJson));
      } catch (_) {
        // ignore a corrupt cache — start fresh
      }
    }
    if (mounted) setState(() => _loading = false);
    _scrollToBottomSoon();
    await _poll();
    // Экран открыт и прочитан — гасим значок в настройках и на нижней панели
    // и подтягиваем его отметку к нашему курсору, чтобы уже показанные ответы
    // не посчитались значком заново.
    await _c.markSupportRead(seenSeq: _cursor);
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _poll();
      // Пока экран открыт, новые ответы читаются сразу — значку считать нечего.
      await _c.markSupportRead(seenSeq: _cursor);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    // Курсор — целое число, ему в prefs самое место. Лента — в файл.
    await prefs.setInt(_cursorKey, _cursor);
    try {
      final f = await _threadFile();
      await f.writeAsString(
        jsonEncode(_messages.map((m) => m.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
      // Не смогли сохранить — переписка останется в памяти до выхода. Это
      // лучше, чем ронять экран поддержки из-за кеша.
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.txt') || n.endsWith('.log')) return 'text/plain';
    return 'application/octet-stream';
  }

  Future<void> _pickAttachment() async {
    final cs = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: cs.primary),
              title: Text(settingsScreenLabel(ctx, ru: 'Фото из галереи', en: 'Photo library')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: cs.primary),
              title: Text(settingsScreenLabel(ctx, ru: 'Камера', en: 'Camera')),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.attach_file_rounded, color: cs.primary),
              title: Text(settingsScreenLabel(ctx, ru: 'Файл', en: 'File')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'file') {
      await _pickFile();
    } else {
      await _pickImage(
          choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      // maxWidth снят: сжимаем сами и до 2048 px — снимок экрана телефона
      // теперь доезжает читаемым, а не обрезанным до 1600.
      final x = await ImagePicker().pickImage(source: src, imageQuality: 92);
      if (x == null) return;
      setState(() => _attaching = true);
      var bytes = await x.readAsBytes();
      if (bytes.length > _kSupportPhotoTargetBytes) {
        bytes = await compute(_compressSupportImage, bytes);
      }
      if (!mounted) return;
      if (bytes.length > kSupportAttachmentMaxBytes) {
        _snack(settingsScreenLabel(context,
            ru: 'Фото слишком большое даже после сжатия',
            en: 'Photo too large even after compression'));
        setState(() => _attaching = false);
        return;
      }
      setState(() {
        _pendAttBytes = bytes;
        _pendAttName = x.name.isEmpty ? 'photo.jpg' : x.name;
        _pendAttMime = 'image/jpeg';
        _attaching = false;
      });
    } catch (e) {
      setState(() => _attaching = false);
      _snack('$e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      if (!mounted) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;
      if (bytes.length > kSupportAttachmentMaxBytes) {
        final gotRu = _humanBytes(bytes.length, ru: true);
        final capRu = _humanBytes(kSupportAttachmentMaxBytes, ru: true);
        final gotEn = _humanBytes(bytes.length, ru: false);
        final capEn = _humanBytes(kSupportAttachmentMaxBytes, ru: false);
        _snack(settingsScreenLabel(context,
            ru: 'Файл слишком большой: $gotRu. '
                'Максимум $capRu — вложения шифруются целиком',
            en: 'File too large: $gotEn. '
                'Max $capEn — attachments are fully encrypted'));
        return;
      }
      setState(() {
        _pendAttBytes = bytes;
        _pendAttName = f.name;
        _pendAttMime = _mimeFromName(f.name);
      });
    } catch (e) {
      _snack('$e');
    }
  }

  void _clearPending() {
    setState(() {
      _pendAttBytes = null;
      _pendAttName = null;
      _pendAttMime = null;
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final attBytes = _pendAttBytes;
    final attName = _pendAttName;
    final attMime = _pendAttMime;
    if ((text.isEmpty && attBytes == null) || _sending) return;
    final msg = _SupportMsg(
      mine: true,
      text: text,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      attB64: attBytes == null ? null : base64Encode(attBytes),
      attName: attName,
      attMime: attMime,
    );
    setState(() {
      _messages.add(msg);
      _input.clear();
      _pendAttBytes = null;
      _pendAttName = null;
      _pendAttMime = null;
      _sending = true;
    });
    _scrollToBottomSoon();
    try {
      await _c.submitSupportMessage(
        text,
        attachmentBytes: attBytes,
        attachmentName: attName,
        attachmentMime: attMime,
      );
      // Обращение ушло — с этого момента ждём ответа, и в настройках горит
      // точка «в работе».
      await _c.noteSupportMessageSent();
    } catch (_) {
      msg.failed = true;
    } finally {
      if (mounted) setState(() => _sending = false);
      await _save();
    }
  }

  Future<void> _poll() async {
    try {
      final res = await _c.fetchSupportReplies(_cursor);
      // 🔴 Переписку стёрли из админки. Контроллер уже обнулил счётчики и
      // удалил файл ленты; экрану остаётся забыть то, что он держит в памяти,
      // иначе стёртая переписка так и осталась бы на глазах до перезахода.
      if (res.clearedAtMs > 0 && res.clearedAtMs > _clearedSeenMs) {
        _clearedSeenMs = res.clearedAtMs;
        _cursor = 0;
        if (mounted) setState(_messages.clear);
        return;
      }
      if (res.replies.isEmpty && res.cursor == _cursor) return;
      _cursor = res.cursor;
      if (res.replies.isNotEmpty) {
        _messages.addAll(res.replies
            .map((r) => _SupportMsg(mine: false, text: r.text, tsMs: r.tsMs)));
        if (mounted) setState(() {});
        _scrollToBottomSoon();
      }
      await _save();
    } catch (_) {
      // network hiccup — the periodic timer retries
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(settingsScreenLabel(context, ru: 'Поддержка', en: 'Support')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded,
                    size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                const SizedBox(width: 5),
                Text(
                  settingsScreenLabel(context,
                      ru: 'Сквозное шифрование', en: 'End-to-end encrypted'),
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _empty(cs)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i], cs),
                      ),
          ),
          _composer(cs),
        ],
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_rounded,
                  size: 48, color: cs.primary.withValues(alpha: 0.85)),
              const SizedBox(height: 16),
              Text(
                settingsScreenLabel(
                  context,
                  ru: 'Опишите проблему — ответим здесь. Можно приложить фото. '
                      'Переписка зашифрована.',
                  en: "Describe your issue — we'll reply here. You can attach a "
                      'photo. The chat is end-to-end encrypted.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(_SupportMsg m, ColorScheme cs) {
    final mine = m.mine;
    final bg = m.failed
        ? cs.errorContainer
        : (mine ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = m.failed
        ? cs.onErrorContainer
        : (mine ? cs.onPrimaryContainer : cs.onSurface);
    final bytes = m.attBytes;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(m.hasAtt && m.isImage ? 5 : 0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bytes != null && m.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(bytes,
                    fit: BoxFit.cover, gaplessPlayback: true),
              ),
            if (bytes != null && !m.isImage)
              Padding(
                padding: EdgeInsets.fromLTRB(14, m.hasAtt ? 8 : 10, 14, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insert_drive_file_rounded, size: 20, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(m.attName ?? 'file',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: fg, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            if (m.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    14, (m.hasAtt && m.isImage) ? 8 : 10, 14, 10),
                child: SelectableText(m.text,
                    style: TextStyle(color: fg, height: 1.3)),
              ),
            if (m.failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  settingsScreenLabel(context, ru: 'не отправлено', en: 'not sent'),
                  style: TextStyle(color: fg, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attPreview(ColorScheme cs) {
    final bytes = _pendAttBytes;
    if (bytes == null) return const SizedBox.shrink();
    final isImage = (_pendAttMime ?? '').startsWith('image/');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isImage
                  ? Image.memory(bytes,
                      width: 46, height: 46, fit: BoxFit.cover)
                  : Container(
                      width: 46,
                      height: 46,
                      color: cs.surface,
                      child: Icon(Icons.insert_drive_file_rounded,
                          color: cs.primary),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_pendAttName ?? 'file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${(bytes.length / 1024).toStringAsFixed(0)} КБ',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              onPressed: _clearPending,
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _attPreview(cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _circleButton(
                    cs: cs,
                    bg: cs.surfaceContainerHighest,
                    fg: cs.primary,
                    icon: Icons.add_rounded,
                    busy: _attaching,
                    onTap: (_attaching || _sending) ? null : _pickAttachment,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: settingsScreenLabel(context,
                            ru: 'Сообщение…', en: 'Message…'),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _circleButton(
                    cs: cs,
                    bg: cs.primary,
                    fg: cs.onPrimary,
                    icon: Icons.arrow_upward_rounded,
                    busy: _sending,
                    onTap: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required ColorScheme cs,
    required Color bg,
    required Color fg,
    required IconData icon,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}
