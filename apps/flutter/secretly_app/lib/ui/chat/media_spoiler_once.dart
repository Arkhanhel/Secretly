// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// SendFlow Э5 (24.11.2026): медиа под спойлером и одноразовый просмотр.
///
/// - Спойлер: размытие с «пылью» поверх снимка; касание открывает (на этот
///   сеанс приложения). Отправляется только получателям, которые умеют
///   (`msx1`), иначе старая сборка показала бы снимок открыто.
/// - Одноразовое: в пузыре нет превью вовсе — только плашка. Открывается
///   один раз во весь экран; на Android снимки экрана и запись запрещены
///   (`FLAG_SECURE`), на iPhone система запретить их не даёт — не обещаем.
///   После закрытия файл с устройства удаляется, второй раз не открыть.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../models/e2e_payload_v1.dart';
import '../../security/screen_privacy.dart';
import '../wave1_l10n.dart';

/// Какие одноразовые уже открыты (по id события). Хранится на устройстве.
class ViewOnceStore {
  ViewOnceStore._();

  static const String _key = 'view_once_opened_v1';
  static const int _cap = 2000;
  static Set<String>? _opened;
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static Future<void> load() async {
    if (_opened != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _opened = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (_) {
      _opened = <String>{};
    }
    changed.value++;
  }

  static bool isOpened(String eventId) => _opened?.contains(eventId) ?? false;

  static Future<void> markOpened(String eventId) async {
    await load();
    final set = _opened!;
    if (!set.add(eventId)) return;
    while (set.length > _cap) {
      set.remove(set.first);
    }
    changed.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, set.toList());
    } catch (_) {}
  }

  @visibleForTesting
  static void debugReset() {
    _opened = null;
  }
}

/// Открытые за сеанс спойлеры (по id события).
final Set<String> _revealedSpoilers = <String>{};

@visibleForTesting
void debugResetRevealedSpoilers() => _revealedSpoilers.clear();

/// Обложка спойлера поверх медиа: размытие + «пыль»; касание — открыть.
class MediaSpoilerCover extends StatefulWidget {
  const MediaSpoilerCover({
    super.key,
    required this.eventId,
    required this.child,
  });

  final String eventId;
  final Widget child;

  @override
  State<MediaSpoilerCover> createState() => _MediaSpoilerCoverState();
}

class _MediaSpoilerCoverState extends State<MediaSpoilerCover>
    with SingleTickerProviderStateMixin {
  late bool _revealed = _revealedSpoilers.contains(widget.eventId);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: _revealed ? 1 : 0,
  )..addStatusListener((status) {
      // Растаяло — убрать обложку совсем (иначе она перехватывала бы касания).
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _revealed = true);
    _revealedSpoilers.add(widget.eventId);
    _fade.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed && _fade.isCompleted) return widget.child;
    // Размытие самого снимка (ImageFiltered), а не всего фона под ним
    // (BackdropFilter): дешевле в ленте и не зависит от обоев.
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final sigma = 22 * (1 - _fade.value);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: widget.child,
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 1 - _fade.value,
                child: GestureDetector(
                  key: ValueKey('spoiler:${widget.eventId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _revealed ? null : _reveal,
                  child: const CustomPaint(
                    painter: _DustPainter(),
                    child: Center(
                      child: Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Неподвижная «пыль» спойлера (без анимации — не греет телефон).
class _DustPainter extends CustomPainter {
  const _DustPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x33141A22),
    );
    final rnd = math.Random(7);
    final p = Paint()..color = const Color(0x99FFFFFF);
    final n = (size.width * size.height / 260).clamp(40, 900).round();
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.6 + rnd.nextDouble() * 0.7,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter oldDelegate) => false;
}

/// Плашка одноразового медиа в пузыре (превью нет вовсе).
class ViewOnceTile extends StatelessWidget {
  const ViewOnceTile({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.color,
    required this.onOpen,
  });

  final AttachmentEventV1 attachment;
  final bool isMe;
  final Color color;
  final VoidCallback onOpen;

  bool get _video => (attachment.mime ?? '').toLowerCase().startsWith('video/');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ViewOnceStore.changed,
      builder: (context, _, _) {
        final opened = ViewOnceStore.isOpened(attachment.eventId);
        final canOpen = !isMe && !opened;
        final title = _video
            ? wave1Text(context, ru: 'Одноразовое видео', en: 'View-once video', uk: 'Одноразове відео', es: 'Vídeo de una vista', pt: 'Vídeo de visualização única', ptBr: 'Vídeo de visualização única', fr: 'Vidéo éphémère', de: 'Einmal-Video')
            : wave1Text(context, ru: 'Одноразовое фото', en: 'View-once photo', uk: 'Одноразове фото', es: 'Foto de una vista', pt: 'Foto de visualização única', ptBr: 'Foto de visualização única', fr: 'Photo éphémère', de: 'Einmal-Foto');
        final sub = opened
            ? wave1Text(context, ru: 'Просмотрено', en: 'Opened', uk: 'Переглянуто', es: 'Visto', pt: 'Visto', ptBr: 'Visto', fr: 'Ouvert', de: 'Geöffnet')
            : canOpen
            ? wave1Text(context, ru: 'Нажмите, чтобы открыть', en: 'Tap to open', uk: 'Натисніть, щоб відкрити', es: 'Toca para abrir', pt: 'Toque para abrir', ptBr: 'Toque para abrir', fr: 'Touchez pour ouvrir', de: 'Zum Öffnen tippen')
            : wave1Text(context, ru: 'Откроется один раз', en: 'Opens once', uk: 'Відкриється один раз', es: 'Se abre una vez', pt: 'Abre uma vez', ptBr: 'Abre uma vez', fr: 'S’ouvre une fois', de: 'Öffnet sich einmal');
        return GestureDetector(
          key: ValueKey('view-once:${attachment.eventId}'),
          behavior: HitTestBehavior.opaque,
          onTap: canOpen ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: opened ? 0.08 : 0.16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: opened
                      ? Icon(Icons.done_rounded, color: color.withValues(alpha: .8), size: 20)
                      : Text('1', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(color: color.withValues(alpha: .7), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Открыть одноразовое медиа во весь экран. [loadFile] — скачать/взять
/// файл; [onDeleteFile] — стереть его с устройства после закрытия.
Future<void> openViewOnceMedia(
  BuildContext context, {
  required AttachmentEventV1 attachment,
  required Future<File?> Function() loadFile,
  required Future<void> Function(File file) onDeleteFile,
  required bool restorePrivacyTo,
}) async {
  final file = await loadFile();
  if (file == null || !context.mounted) return;
  // Сразу отмечаем: даже если приложение закроют посреди просмотра, второй
  // раз не откроется.
  await ViewOnceStore.markOpened(attachment.eventId);
  if (Platform.isAndroid) await ScreenPrivacy.apply(enabled: true);
  try {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => _ViewOnceScreen(
          file: file,
          video: (attachment.mime ?? '').toLowerCase().startsWith('video/'),
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  } finally {
    if (Platform.isAndroid) {
      unawaited(ScreenPrivacy.apply(enabled: restorePrivacyTo));
    }
    unawaited(onDeleteFile(file));
  }
}

class _ViewOnceScreen extends StatefulWidget {
  const _ViewOnceScreen({required this.file, required this.video});

  final File file;
  final bool video;

  @override
  State<_ViewOnceScreen> createState() => _ViewOnceScreenState();
}

class _ViewOnceScreenState extends State<_ViewOnceScreen> {
  VideoPlayerController? _v;
  bool _closing = false;

  /// Закрыть один раз: повторный maybePop закрыл бы уже чат под экраном.
  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    if (widget.video) {
      final v = VideoPlayerController.file(widget.file);
      _v = v;
      v.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        unawaited(v.play());
      });
      // Видео — до конца один раз, потом закрыть.
      v.addListener(() {
        final val = v.value;
        if (val.isInitialized &&
            val.duration > Duration.zero &&
            val.position >= val.duration) {
          _close();
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_v?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: Center(
                child: widget.video
                    ? (v != null && v.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: v.value.aspectRatio,
                              child: VideoPlayer(v),
                            )
                          : const CircularProgressIndicator(color: Colors.white))
                    : InteractiveViewer(
                        maxScale: 4,
                        child: Image.file(widget.file, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('view-once:close'),
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wave1Text(context, ru: 'Одноразовый просмотр — после закрытия не откроется', en: 'View once — won’t open again after closing', uk: 'Одноразовий перегляд — після закриття не відкриється', es: 'Una sola vista: no se abrirá de nuevo', pt: 'Visualização única — não abre de novo', ptBr: 'Visualização única — não abre de novo', fr: 'Vue unique — ne se rouvrira pas', de: 'Einmalansicht — öffnet sich nicht erneut'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
