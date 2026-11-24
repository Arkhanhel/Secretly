// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Просмотр фото и видео — макет «Просмотр медиа» (6a/6b), 22.11.2026.
///
/// Один просмотр на всё приложение: чат, вкладка «Медиа» профиля собеседника
/// и комнаты, своя галерея профиля, аватар. Источник истины — прототип
/// `MediaViewerPhone.dc.html` (пороги, формулы, тайминги).
///
///   * Перелёт из миниатюры и обратно (в т. ч. из приближения и смахивания),
///     миниатюра в ленте скрыта, пока её снимок открыт.
///   * Жест решается один раз за касание: приближено → сдвиг; иначе по оси —
///     листание или смахивание. Порог 7 px.
///   * Листание с шагом «экран + 20», сопротивление на краях ×0,32, переход
///     при |dx| > 70 или броске; лента миниатюр едет вместе с пальцем.
///   * Двойное касание — 2,5× в точке касания (видео: −5 с / пауза / +5 с),
///     щипок 1…5×, плашка масштаба на 900 мс.
///   * Смахивание вверх или вниз: снимок уменьшается до 70 %, фон уходит до
///     8 %; закрыть при |dy| > 110 или резком броске.
///   * Шапка в одну строку, затемнения, подпись в 2 строки с раскрытием,
///     лента миниатюр, панель действий, меню, шторки, всплывающие подсказки.
///
/// Производительность: значения жестов и анимаций живут в слушателях —
/// движение пальца перерисовывает только слой страницы, а не весь экран;
/// живой плеер только у текущего видео; снимки декодируются под размер
/// экрана (×2 для приближения), миниатюры — маленькими копиями.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../chat/video_note_playback.dart' show VideoNotePlayback;
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../diagnostics/diag_log.dart';
import '../../media/decrypted_temp_cleanup.dart';
import '../../media/progressive_playback.dart';
import '../../media/video_thumbnail_cache.dart';
import '../icons/adaptive_icons.dart';
import '../l10n.dart';
import '../widgets/attachment_actions.dart' show saveAttachmentToUserVisibleLocation;
import 'edited_media_view.dart';
import 'editor/media_editor_screen.dart';
import 'media_edits.dart';
import 'media_edits_store.dart';
import 'media_flight.dart';
import 'media_sheet.dart';
import 'media_viewer_tokens.dart';
import 'media_viewer_video.dart';

/// О-1 (разбор медиа 22.11.2026): пока просмотр готовит перелёт (до 450 мс:
/// файл, пропорция, декод), страницы НЕ рисуются. Раньше они были видны
/// поверх чата при прозрачном фоне: размытая копия снимка во весь экран и
/// крутилка в центре, а потом всё это пропадало и стартовал перелёт из
/// миниатюры — то самое мигание при открытии любого медиа на iPhone и
/// Android. `false` — как было.
const bool kViewerHidePagesWhilePreparing = true;

/// С-9: после удаления въезжает только новый текущий снимок (раньше в центре
/// мелькал сосед слева). `false` — как было.
const bool kViewerSoloSlideAfterDelete = true;

/// С-9: дальний прыжок (лента миниатюр, «Все медиа») — сначала подготовить
/// цель, потом показать сразу, без проезда через пустые страницы. `false` —
/// как было.
const bool kViewerFarJumpPrecache = true;

/// С-11: предел крупного шрифта в шапке просмотра.
const double kViewerHeaderMaxTextScale = 1.3;

// ─── Модель ─────────────────────────────────────────────────────────────────

enum MediaViewerKind { photo, video }

/// Один снимок или ролик в просмотре.
@immutable
class MediaViewerEntry {
  const MediaViewerEntry({
    required this.id,
    required this.kind,
    required this.loadFile,
    this.cachedFile,
    this.title,
    this.time,
    this.caption,
    this.own = false,
    this.knownAspect,
    this.duration,
    this.thumbBytes,
    this.anchorTag,
    this.exportName,
    this.payload,
  });

  /// Ключ правок (blobId вложения или путь файла).
  final String id;
  final MediaViewerKind kind;

  /// Файл для показа (может скачать).
  final Future<File> Function() loadFile;

  /// Файл, только если уже на диске (для ленты миниатюр — не качает).
  final Future<File?> Function()? cachedFile;

  /// Автор («Анна», «Вы»); пусто — заголовок просмотра.
  final String? title;
  final DateTime? time;
  final String? caption;

  /// Своё — для текста удаления.
  final bool own;

  /// Пропорция, если известна заранее (размеры от отправителя).
  final double? knownAspect;
  final Duration? duration;

  /// Размытая микро-миниатюра от отправителя — пока нет файла.
  final Uint8List? thumbBytes;

  /// Метка миниатюры для перелёта; по умолчанию [id].
  final Object? anchorTag;

  /// Основа имени при выгрузке правленого снимка.
  final String? exportName;

  /// Что угодно для хозяина (событие чата и т. п.).
  final Object? payload;

  Object get tag => anchorTag ?? id;
  bool get isVideo => kind == MediaViewerKind.video;
}

enum MediaDeleteScope { me, everyone }

@immutable
class MediaViewerDeleteInfo {
  const MediaViewerDeleteInfo({
    required this.own,
    this.canDeleteForEveryone = false,
    this.isGroup = false,
    this.peerName,
  });

  final bool own;
  final bool canDeleteForEveryone;
  final bool isGroup;
  final String? peerName;
}

/// Что умеет хозяин. Всё необязательно: чего нет — того нет в просмотре.
///
/// [onShare], [onSaveToGallery], [onSaveAsFile] вызываются для ОРИГИНАЛА и
/// возвращают текст подсказки (или null). Правленый снимок просмотр
/// выгружает сам.
@immutable
class MediaViewerActions {
  const MediaViewerActions({
    this.onReply,
    this.onForward,
    this.onShowInChat,
    this.onShare,
    this.onSaveToGallery,
    this.onSaveAsFile,
    this.deleteInfo,
    this.onDelete,
    this.canEdit = false,
    this.canCopy = true,
    this.onSendEdited,
  });

  static const MediaViewerActions none = MediaViewerActions(canCopy: false);

  /// Закрыть просмотр и ответить (плашка ответа над полем ввода).
  final Future<void> Function(MediaViewerEntry e)? onReply;

  /// Закрыть просмотр и переслать.
  final Future<void> Function(MediaViewerEntry e)? onForward;

  /// Закрыть просмотр, прокрутить чат к сообщению и подсветить его.
  final Future<void> Function(MediaViewerEntry e)? onShowInChat;
  final Future<String?> Function(MediaViewerEntry e)? onShare;
  final Future<String?> Function(MediaViewerEntry e)? onSaveToGallery;
  final Future<String?> Function(MediaViewerEntry e)? onSaveAsFile;
  final MediaViewerDeleteInfo Function(MediaViewerEntry e)? deleteInfo;

  /// true — снимок удалён; просмотр остаётся на соседнем.
  final Future<bool> Function(MediaViewerEntry e, MediaDeleteScope scope)?
  onDelete;

  /// «Изменить» для фото (правки хранятся на устройстве).
  final bool canEdit;
  final bool canCopy;

  /// Отправить отредактированную КОПИЮ снимка [edited] (JPEG) в этот чат —
  /// оригинал не меняется. `null` — правки недоступны.
  final Future<bool> Function(MediaViewerEntry e, File edited)? onSendEdited;

  bool get hasBar =>
      onReply != null ||
      onForward != null ||
      (canEdit && onSendEdited != null) ||
      onShare != null ||
      onDelete != null;
}

/// Открыть просмотр. [context] — экран с миниатюрами (из его маршрута ищется
/// точка перелёта).
Future<void> openMediaViewer(
  BuildContext context, {
  required List<MediaViewerEntry> entries,
  required int initialIndex,
  MediaViewerActions actions = MediaViewerActions.none,
  String? title,
  bool Function()? hapticsEnabled,
}) async {
  if (entries.isEmpty) return;
  FocusManager.instance.primaryFocus?.unfocus();
  final opener = ModalRoute.of(context);
  // Кружки в ленте под просмотром стоят (разбор 22.11.2026).
  final resumeFeed = VideoNotePlayback.instance.suspendFeed();
  try {
    await _pushMediaViewer(context, entries, initialIndex, actions, title,
        hapticsEnabled, opener);
  } finally {
    resumeFeed();
  }
}

Future<void> _pushMediaViewer(
  BuildContext context,
  List<MediaViewerEntry> entries,
  int initialIndex,
  MediaViewerActions actions,
  String? title,
  bool Function()? hapticsEnabled,
  ModalRoute<Object?>? opener,
) async {
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      // Поверх, а не новая страница: на iPhone чат под ним не сдвигается
      // влево (видно при смахивании фото вниз).
      fullscreenDialog: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => MediaViewerScreen(
        entries: entries,
        initialIndex: initialIndex.clamp(0, entries.length - 1),
        actions: actions,
        title: title,
        openerRoute: opener,
        hapticsEnabled: hapticsEnabled,
      ),
    ),
  );
}

// ─── Значки ─────────────────────────────────────────────────────────────────

class _Ic {
  static const IconData back = AdaptiveIconData(
    Icons.arrow_back_rounded,
    CupertinoIcons.chevron_back,
  );
  static const IconData more = AdaptiveIconData(
    Icons.more_horiz_rounded,
    CupertinoIcons.ellipsis,
  );
  static const IconData reply = AdaptiveIconData(
    Icons.reply_rounded,
    CupertinoIcons.arrowshape_turn_up_left,
  );
  static const IconData forward = AdaptiveIconData(
    Icons.forward_rounded,
    CupertinoIcons.arrowshape_turn_up_right,
  );
  static const IconData edit = AdaptiveIconData(
    Icons.tune_rounded,
    CupertinoIcons.slider_horizontal_3,
  );
  static const IconData share = AdaptiveIconData(
    Icons.share_rounded,
    CupertinoIcons.share,
  );
  static const IconData delete = AdaptiveIconData(
    Icons.delete_outline_rounded,
    CupertinoIcons.delete,
  );
  static const IconData saveGallery = AdaptiveIconData(
    Icons.download_rounded,
    CupertinoIcons.arrow_down_to_line,
  );
  static const IconData saveFile = AdaptiveIconData(
    Icons.insert_drive_file_outlined,
    CupertinoIcons.doc,
  );
  static const IconData showInChat = AdaptiveIconData(
    Icons.chat_bubble_outline_rounded,
    CupertinoIcons.chat_bubble,
  );
  static const IconData grid = AdaptiveIconData(
    Icons.grid_view_rounded,
    CupertinoIcons.square_grid_2x2,
  );
  static const IconData copy = AdaptiveIconData(
    Icons.content_copy_rounded,
    CupertinoIcons.doc_on_doc,
  );
  static const IconData play = AdaptiveIconData(
    Icons.play_arrow_rounded,
    CupertinoIcons.play_fill,
  );
  static const IconData pause = AdaptiveIconData(
    Icons.pause_rounded,
    CupertinoIcons.pause_fill,
  );
  static const IconData replay = AdaptiveIconData(
    Icons.replay_rounded,
    CupertinoIcons.arrow_counterclockwise,
  );
  static const IconData volumeOn = AdaptiveIconData(
    Icons.volume_up_rounded,
    CupertinoIcons.speaker_2_fill,
  );
  static const IconData volumeOff = AdaptiveIconData(
    Icons.volume_off_rounded,
    CupertinoIcons.speaker_slash_fill,
  );
  static const IconData zoom = AdaptiveIconData(
    Icons.zoom_in_rounded,
    CupertinoIcons.zoom_in,
  );
  static const IconData rewind = AdaptiveIconData(
    Icons.fast_rewind_rounded,
    CupertinoIcons.backward_fill,
  );
  static const IconData fastForward = AdaptiveIconData(
    Icons.fast_forward_rounded,
    CupertinoIcons.forward_fill,
  );
  static const IconData playError = AdaptiveIconData(
    Icons.error_outline_rounded,
    CupertinoIcons.exclamationmark_circle,
  );
  static const IconData check = AdaptiveIconData(
    Icons.check_circle_rounded,
    CupertinoIcons.check_mark_circled_solid,
  );
}

// ─── Экран ──────────────────────────────────────────────────────────────────

enum _Phase { preparing, opening, open, closing }

enum _Mode { none, pan, page, dismiss }

@immutable
class _Zoom {
  const _Zoom(this.s, this.x, this.y);

  static const _Zoom one = _Zoom(1, 0, 0);
  final double s, x, y;

  bool get zoomed => s > 1.01;

  static _Zoom lerp(_Zoom a, _Zoom b, double t) => _Zoom(
    a.s + (b.s - a.s) * t,
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
  );
}

/// Данные одного снимка: файл, картинка под экран, маленькая копия,
/// пропорция.
class _Media {
  Future<File?>? fileFuture;
  File? file;
  ImageProvider? image;
  ImageProvider? thumb;
  double? aspect;
  bool failed = false;
  bool posterAsked = false;
  Duration? duration;
}

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.entries,
    required this.initialIndex,
    required this.actions,
    this.title,
    this.openerRoute,
    this.hapticsEnabled,
  });

  final List<MediaViewerEntry> entries;
  final int initialIndex;
  final MediaViewerActions actions;
  final String? title;
  final ModalRoute<Object?>? openerRoute;
  final bool Function()? hapticsEnabled;

  @override
  State<MediaViewerScreen> createState() => MediaViewerScreenState();
}

@visibleForTesting
class MediaViewerScreenState extends State<MediaViewerScreen>
    with TickerProviderStateMixin {
  late final List<MediaViewerEntry> _entries = List.of(widget.entries);
  late int _index = widget.initialIndex;
  final Map<String, _Media> _media = <String, _Media>{};
  final ValueNotifier<int> _mediaTick = ValueNotifier<int>(0);

  _Phase _phase = _Phase.preparing;
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: kMediaFlightDuration,
  );
  FlightPose _flightFrom = FlightPose.identity;
  FlightPose _flightTo = FlightPose.identity;
  double _bgFrom = 0, _bgTo = 1;
  String? _flightId;

  /// Позиция листания: индекс минус доля протяжки.
  late final AnimationController _pagePos = AnimationController.unbounded(
    vsync: this,
    value: widget.initialIndex.toDouble(),
  );

  /// Смахивание: сдвиг пальца (null — нет).
  final ValueNotifier<Offset?> _drag = ValueNotifier<Offset?>(null);
  late final AnimationController _dragBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Offset _dragBackFrom = Offset.zero;

  final ValueNotifier<_Zoom> _zoom = ValueNotifier<_Zoom>(_Zoom.one);
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  _Zoom _zoomFrom = _Zoom.one, _zoomTo = _Zoom.one;

  bool _chrome = true;
  bool _capOpen = false;
  bool _menuOpen = false;
  bool _busy = false;
  final ValueNotifier<bool> _zoomPill = ValueNotifier<bool>(false);
  Timer? _pillTimer;
  final ValueNotifier<String?> _toast = ValueNotifier<String?>(null);
  Timer? _toastTimer;
  final ValueNotifier<({bool left, int n})?> _seekFx =
      ValueNotifier<({bool left, int n})?>(null);
  Timer? _seekFxTimer;

  MediaViewerVideo? _video;
  String? _videoId;
  bool _muted = false;
  double _speed = 1;

  /// В-2: с этого места продолжит плеер полного файла, если плеер по ходу
  /// скачивания сорвался до того, как файл докачался.
  Duration? _resumeAt;

  /// С-9: на время въезда соседа после удаления и дальнего прыжка рисуется
  /// только текущая страница — иначе в центре мелькал другой снимок.
  bool _soloPage = false;
  int _jumpSeq = 0;

  // Касания сцены.
  final Map<int, Offset> _pointers = <int, Offset>{};
  _Mode _mode = _Mode.none;
  Offset? _origin;
  _Zoom _z0 = _Zoom.one;
  VelocityTracker? _vt;
  ({double d0, Offset f0, _Zoom z0})? _pinch;
  Timer? _tapTimer;
  Offset? _lastTap;
  DateTime? _lastTapAt;

  double _dpr = 3;
  Size _screenSize = const Size(390, 844);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    _dpr = mq.devicePixelRatio;
    _screenSize = mq.size;
  }

  MediaViewerEntry get _cur => _entries[_index];
  MediaViewerTokens get _t => MediaViewerTokens.of(context);
  Size get _screen => MediaQuery.sizeOf(context);
  double get _pageStep => _screen.width + 20;

  void _haptic(void Function() f) {
    if (widget.hapticsEnabled?.call() ?? true) f();
  }

  @override
  void initState() {
    super.initState();
    _flight.addStatusListener(_onFlightStatus);
    _dragBack.addListener(() {
      final t = kMediaFlightCurve.transform(_dragBack.value);
      _drag.value = Offset.lerp(_dragBackFrom, Offset.zero, t);
    });
    _dragBack.addStatusListener((s) {
      if (s == AnimationStatus.completed) _drag.value = null;
    });
    _zoomAnim.addListener(() {
      _zoom.value = _Zoom.lerp(
        _zoomFrom,
        _zoomTo,
        kMediaFlightCurve.transform(_zoomAnim.value),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareAndOpen());
  }

  @override
  void dispose() {
    if (MediaFlightAnchors.hidden.value != null &&
        _entries.any((e) => e.tag == MediaFlightAnchors.hidden.value)) {
      MediaFlightAnchors.hidden.value = null;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _video?.dispose();
    // С-13: выгрузки правленых снимков старше получаса — с диска.
    unawaited(sweepDecryptedTempCopies());
    _flight.dispose();
    _pagePos.dispose();
    _dragBack.dispose();
    _zoomAnim.dispose();
    _drag.dispose();
    _zoom.dispose();
    _zoomPill.dispose();
    _toast.dispose();
    _seekFx.dispose();
    _mediaTick.dispose();
    _pillTimer?.cancel();
    _toastTimer?.cancel();
    _seekFxTimer?.cancel();
    _tapTimer?.cancel();
    super.dispose();
  }

  // ─── Данные ───────────────────────────────────────────────────────────────

  _Media _m(MediaViewerEntry e) => _media.putIfAbsent(e.id, _Media.new);

  /// Запросить файл и картинки снимка (один раз).
  Future<void> _ensureMedia(MediaViewerEntry e, {bool download = true}) {
    final m = _m(e);
    if (m.fileFuture != null && (m.file != null || !download)) {
      return m.fileFuture!.then((_) {});
    }
    final dpr = _dpr;
    final screen = _screenSize;
    Future<File?> load() async {
      try {
        File? f;
        if (!download) {
          f = await e.cachedFile?.call();
        } else {
          f = await e.loadFile();
        }
        return f;
      } catch (_) {
        if (download) m.failed = true;
        return null;
      }
    }

    final fut = load().then((f) async {
      if (f == null) {
        _bump();
        return null;
      }
      m.file = f;
      if (e.isVideo) {
        await _ensurePoster(e, f);
      } else {
        m.image ??= ResizeImage(
          FileImage(f),
          width: (screen.width * dpr * 2).round(),
          height: (screen.height * dpr * 2).round(),
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        );
        m.thumb ??= ResizeImage(
          FileImage(f),
          width: 480,
          height: 480,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        );
        m.aspect ??= e.knownAspect;
        m.aspect ??= await resolveImageAspect(m.thumb!);
      }
      _bump();
      return f;
    });
    m.fileFuture = fut;
    return fut.then((_) {});
  }

  Future<void> _ensurePoster(MediaViewerEntry e, File video) async {
    final m = _m(e);
    if (m.posterAsked) return;
    m.posterAsked = true;
    try {
      final poster = await VideoThumbnailCache.forVideo(
        key: e.id,
        videoPath: video.path,
      );
      if (poster != null) {
        m.image = FileImage(poster.file);
        m.thumb = ResizeImage(
          FileImage(poster.file),
          width: 480,
          height: 480,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        );
        m.aspect ??= e.knownAspect ?? await resolveImageAspect(m.thumb!);
      }
    } catch (_) {
      // Без кадра — тёмная заглушка с ▶.
    }
    m.aspect ??= e.knownAspect ?? 16 / 9;
    _bump();
  }

  void _bump() {
    if (mounted) _mediaTick.value++;
  }

  double _aspectOf(MediaViewerEntry e) =>
      _media[e.id]?.aspect ?? e.knownAspect ?? 1;

  MediaEdits _editsOf(MediaViewerEntry e) => e.isVideo
      ? MediaEdits.identity
      : (MediaEditsStore.instance.peek(e.id) ?? MediaEdits.identity);

  /// Прямоугольник «contain» снимка на экране (F).
  Rect _fitRect(MediaViewerEntry e) =>
      containRect(_aspectOf(e), _editsOf(e), _screen);

  // ─── Открытие и закрытие ──────────────────────────────────────────────────

  Future<void> _prepareAndOpen() async {
    if (!mounted) return;
    final e = _cur;
    // Сначала — файл и пропорция (снимок обычно уже на диске: миниатюра в
    // ленте его показывала). Не дольше 450 мс: дальше открываемся «появлением»
    // и догружаем на месте.
    final ready = () async {
      await _ensureMedia(e);
      if (!e.isVideo) await MediaEditsStore.instance.read(e.id);
      final m = _m(e);
      if (m.image != null && mounted) {
        await precacheImage(m.image!, context, onError: (_, _) {});
      }
    }();
    var timedOut = false;
    await ready.timeout(
      const Duration(milliseconds: 450),
      onTimeout: () {
        timedOut = true;
      },
    );
    if (!mounted) return;
    final anchor = MediaFlightAnchors.geometryOf(
      e.tag,
      route: widget.openerRoute,
      screen: _screen,
    );
    final f = _fitRect(e);
    _flightId = e.id;
    _flightFrom = (!timedOut && anchor != null && _m(e).image != null)
        ? FlightPose.toThumb(f, anchor.rect, anchor.radius)
        : FlightPose.appear;
    _flightTo = FlightPose.identity;
    _bgFrom = 0;
    _bgTo = 1;
    MediaFlightAnchors.hidden.value = e.tag;
    setState(() => _phase = _Phase.opening);
    unawaited(_flight.forward(from: 0));
    _warmNeighbours();
  }

  void _onFlightStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    if (_phase == _Phase.opening) {
      setState(() {
        _phase = _Phase.open;
        _flightId = null;
      });
      _syncVideo();
    } else if (_phase == _Phase.closing) {
      MediaFlightAnchors.hidden.value = null;
      final after = _afterClose;
      _afterClose = null;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
      if (after != null) scheduleMicrotask(after);
    }
  }

  VoidCallback? _afterClose;

  double _bgNow() {
    final d = _drag.value;
    if (d == null) return 1;
    return 1 - math.min(1.0, d.dy.abs() / 320) * .92;
  }

  /// Закрыть: перелёт из нынешнего положения в миниатюру (или растаять).
  void _close({VoidCallback? after}) {
    if (_phase == _Phase.closing) return;
    if (_phase == _Phase.preparing || _entries.isEmpty) {
      MediaFlightAnchors.hidden.value = null;
      // pop(), не maybePop(): PopScope этого экрана перехватил бы его снова.
      Navigator.of(context).pop();
      if (after != null) scheduleMicrotask(after);
      return;
    }
    _tapTimer?.cancel();
    final e = _cur;
    final f = _fitRect(e);
    final d = _drag.value;
    final z = _zoom.value;
    FlightPose from;
    if (_phase == _Phase.opening) {
      from = FlightPose.lerp(
        _flightFrom,
        _flightTo,
        kMediaFlightCurve.transform(_flight.value),
      );
    } else if (d != null) {
      final m = 1 - (d.dy.abs() / 1000).clamp(0.0, .3);
      from = FlightPose.centered(f.size, m, d);
    } else if (z.zoomed) {
      from = FlightPose.centered(f.size, z.s, Offset(z.x, z.y));
    } else {
      from = FlightPose.identity;
    }
    final anchor = MediaFlightAnchors.geometryOf(
      e.tag,
      route: widget.openerRoute,
      screen: _screen,
    );
    final to = anchor != null
        ? FlightPose.toThumb(f, anchor.rect, anchor.radius)
        : from.fadedOut(f.size);
    _video?.blocked = true;
    _afterClose = after;
    _bgFrom = _phase == _Phase.opening ? _flight.value : _bgNow();
    _bgTo = 0;
    _flightFrom = from;
    _flightTo = to;
    _flightId = e.id;
    _dragBack.stop();
    _zoomAnim.stop();
    MediaFlightAnchors.hidden.value = e.tag;
    setState(() {
      _phase = _Phase.closing;
      _menuOpen = false;
      _chrome = false;
    });
    _drag.value = null;
    unawaited(_flight.forward(from: 0));
  }

  void _warmNeighbours() {
    for (final i in [_index - 1, _index + 1]) {
      if (i < 0 || i >= _entries.length) continue;
      final e = _entries[i];
      unawaited(_ensureMedia(e, download: !e.isVideo).then((_) {
        final img = _media[e.id]?.image;
        if (img != null && mounted) {
          unawaited(precacheImage(img, context, onError: (_, _) {}));
        }
        if (!e.isVideo) unawaited(MediaEditsStore.instance.read(e.id));
      }));
    }
  }

  // ─── Листание ─────────────────────────────────────────────────────────────

  /// С-9: переход с ленты миниатюр и из «Все медиа». Сосед — обычное
  /// листание. Дальний прыжок раньше ехал через пустые страницы (строятся
  /// только текущая и соседи) — ~300 мс чёрного экрана. Теперь цель сначала
  /// готовится (файл, декод — не дольше 250 мс), потом показывается сразу.
  Future<void> _jumpTo(int n) async {
    if (_entries.isEmpty) return;
    n = n.clamp(0, _entries.length - 1);
    if (!kViewerFarJumpPrecache || (n - _pagePos.value).abs() <= 1.01) {
      _go(n);
      return;
    }
    final seq = ++_jumpSeq;
    final e = _entries[n];
    final ready = () async {
      await _ensureMedia(e, download: !e.isVideo);
      final img = _media[e.id]?.image;
      if (img != null && mounted) {
        await precacheImage(img, context, onError: (_, _) {});
      }
      if (!e.isVideo) await MediaEditsStore.instance.read(e.id);
    }();
    await ready.timeout(const Duration(milliseconds: 250), onTimeout: () {});
    if (!mounted || seq != _jumpSeq) return;
    final at = _entries.indexWhere((x) => x.id == e.id);
    if (at < 0) return;
    _go(at, animate: false);
  }

  void _go(int n, {bool animate = true}) {
    if (_entries.isEmpty) return;
    n = n.clamp(0, _entries.length - 1);
    final changed = n != _index;
    _zoomAnim.stop();
    _zoom.value = _Zoom.one;
    if (changed) {
      setState(() {
        _index = n;
        _capOpen = false;
      });
      MediaFlightAnchors.hidden.value = _cur.tag;
      _warmNeighbours();
      _syncVideo();
    }
    if (animate) {
      unawaited(
        _pagePos.animateTo(
          n.toDouble(),
          duration: kMediaFlightDuration,
          curve: kMediaFlightCurve,
        ),
      );
    } else {
      _pagePos.value = n.toDouble();
    }
  }

  // ─── Видео ────────────────────────────────────────────────────────────────

  void _syncVideo() {
    final e = _entries.isEmpty ? null : _cur;
    if (e == null || !e.isVideo) {
      _disposeVideo();
      return;
    }
    if (_videoId == e.id) {
      _video?.blocked = !_videoAllowed;
      return;
    }
    _disposeVideo();
    final id = e.id;
    _videoId = id;
    final fileReady = _ensureMedia(e);
    // В-2: пока ролик качается — играть с локального источника (только
    // `faststart`; иначе `null`, и ждём полный файл, как раньше).
    if (kProgressivePlayback && _media[id]?.file == null) {
      unawaited(_startProgressive(id, fileReady));
    }
    unawaited(fileReady.then((_) {
      if (!mounted || _videoId != id) return;
      final f = _media[id]?.file;
      if (f == null) return;
      final cur = _video;
      if (cur != null) {
        // Уже играет по ходу скачивания — не перезапускать. Ещё не начал —
        // полный файл быстрее и надёжнее.
        if (!cur.isProgressive || cur.ready.value) return;
        _dropVideo(cur);
      }
      final at = _resumeAt;
      _resumeAt = null;
      _attachVideo(
        MediaViewerVideo(file: f, muted: _muted, speed: _speed, startAt: at),
      );
    }));
  }

  void _attachVideo(MediaViewerVideo v) {
    v.blocked = !_videoAllowed;
    // Не из уведомления самого ValueNotifier: обработчик может его закрыть.
    v.failed.addListener(() => scheduleMicrotask(() => _onVideoFailed(v)));
    setState(() => _video = v);
    unawaited(v.sync());
  }

  /// Убрать плеер, не забывая, чья это страница.
  void _dropVideo(MediaViewerVideo v) {
    _muted = v.muted;
    _speed = v.speed;
    if (identical(_video, v)) _video = null;
    v.dispose();
  }

  Future<void> _startProgressive(String id, Future<void> fileReady) async {
    final sw = Stopwatch()..start();
    final server = await openProgressivePlayback(id, until: fileReady);
    if (server == null) return;
    if (!mounted ||
        _videoId != id ||
        _video != null ||
        _media[id]?.file != null) {
      await server.close();
      return;
    }
    final v = MediaViewerVideo.progressive(
      server: server,
      muted: _muted,
      speed: _speed,
    );
    void onReady() {
      if (!v.ready.value) return;
      v.ready.removeListener(onReady);
      final feed = server.feed;
      DiagLog.event('media', 'progressive_ready', {
        'ms': sw.elapsedMilliseconds,
        'downloaded_pct': (feed.totalBytes ?? 0) <= 0
            ? 0
            : feed.available * 100 ~/ feed.totalBytes!,
      });
    }

    v.ready.addListener(onReady);
    _attachVideo(v);
  }

  void _onVideoFailed(MediaViewerVideo v) {
    if (!mounted || !identical(_video, v) || !v.failed.value) return;
    if (!v.isProgressive) {
      // Полный файл не открылся — сообщение и «Повторить».
      setState(() {});
      return;
    }
    // В-2: локальный источник не справился — как раньше, с полного файла и
    // с того же места.
    final at = v.controller.value.position;
    DiagLog.event('media', 'progressive_fallback', {
      'was_ready': v.ready.value,
      'feed_failed': v.server?.feed.isFailed ?? false,
    });
    final id = _videoId;
    _dropVideo(v);
    final f = id == null ? null : _media[id]?.file;
    if (f != null) {
      _attachVideo(
        MediaViewerVideo(file: f, muted: _muted, speed: _speed, startAt: at),
      );
    } else {
      _resumeAt = at;
      setState(() {});
    }
  }

  /// «Повторить» после ошибки видео: заново файл (если не скачался) и плеер.
  void _retryVideo() {
    if (_entries.isEmpty) return;
    final e = _cur;
    final m = _media[e.id];
    if (m != null && m.failed) {
      m
        ..failed = false
        ..posterAsked = false;
    }
    _disposeVideo();
    _bump();
    setState(() {});
    _syncVideo();
  }

  bool get _videoAllowed => _phase == _Phase.open && !_busy;

  void _disposeVideo() {
    final v = _video;
    if (v != null) {
      _muted = v.muted;
      _speed = v.speed;
      v.dispose();
    }
    _video = null;
    _videoId = null;
    _resumeAt = null;
  }

  // ─── Касания сцены ────────────────────────────────────────────────────────

  _Zoom _clampZ(double s, double x, double y) {
    final f = _fitRect(_cur);
    final w = _screen.width, h = _screen.height;
    final mx = math.max(0.0, (f.width * s - w) / 2);
    final my = math.max(0.0, (f.height * s - h) / 2);
    return _Zoom(s, x.clamp(-mx, mx), y.clamp(-my, my));
  }

  void _animateZoom(_Zoom to, {Duration? duration}) {
    _zoomFrom = _zoom.value;
    _zoomTo = to;
    _zoomAnim.duration = duration ?? const Duration(milliseconds: 300);
    unawaited(_zoomAnim.forward(from: 0));
  }

  void _onDown(PointerDownEvent e) {
    if (_phase != _Phase.open || _menuOpen || _busy) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _origin = e.localPosition;
      _mode = _Mode.none;
      _z0 = _zoom.value;
      _vt = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.localPosition);
    } else if (_pointers.length == 2 && !_cur.isVideo) {
      // Второй палец — щипок; одиночный жест сворачиваем.
      _tapTimer?.cancel();
      _lastTapAt = null;
      _settleSingle(cancelled: true);
      _origin = null;
      final pts = _pointers.values.toList();
      _pinch = (
        d0: math.max(1.0, (pts[0] - pts[1]).distance),
        f0: (pts[0] + pts[1]) / 2,
        z0: _zoom.value,
      );
      _mode = _Mode.pan;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final pinch = _pinch;
    if (pinch != null) {
      if (_pointers.length < 2) return;
      final pts = _pointers.values.take(2).toList();
      final d = math.max(1.0, (pts[0] - pts[1]).distance);
      final f = (pts[0] + pts[1]) / 2;
      final c = _screen.center(Offset.zero);
      final s = (pinch.z0.s * d / pinch.d0).clamp(.85, 5.6);
      final ox = f.dx - c.dx - (pinch.f0.dx - c.dx - pinch.z0.x) * s / pinch.z0.s;
      final oy = f.dy - c.dy - (pinch.f0.dy - c.dy - pinch.z0.y) * s / pinch.z0.s;
      _zoomAnim.stop();
      _zoom.value = _Zoom(s, ox, oy);
      return;
    }
    final o = _origin;
    if (o == null) return;
    _vt?.addPosition(e.timeStamp, e.localPosition);
    final d = e.localPosition - o;
    if (_mode == _Mode.none) {
      if (d.distance < 7) return;
      _mode = _zoomedOrZooming
          ? _Mode.pan
          : (d.dx.abs() > d.dy.abs() ? _Mode.page : _Mode.dismiss);
      if (_mode == _Mode.pan && _zoomAnim.isAnimating) {
        // Палец подхватывает снимок там, где его застала анимация.
        _zoomAnim.stop();
        _z0 = _zoom.value;
        _origin = e.localPosition;
        return;
      }
      _tapTimer?.cancel();
      _lastTapAt = null;
      if (_mode == _Mode.page) _pagePos.stop();
      if (_mode == _Mode.dismiss) {
        _dragBack.stop();
        setState(() {}); // оформление гаснет на время смахивания
      }
    }
    switch (_mode) {
      case _Mode.pan:
        _zoom.value = _clampZ(_z0.s, _z0.x + d.dx, _z0.y + d.dy);
      case _Mode.page:
        var dx = d.dx;
        if ((_index == 0 && dx > 0) ||
            (_index == _entries.length - 1 && dx < 0)) {
          dx *= .32;
        }
        _pagePos.value = _index - dx / _pageStep;
      case _Mode.dismiss:
        _drag.value = d;
      case _Mode.none:
        break;
    }
  }

  void _onUp(PointerEvent e, {required bool cancelled}) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers.remove(e.pointer);
    if (_pinch != null) {
      if (_pointers.length >= 2) return;
      _pinch = null;
      final z = _zoom.value;
      final s = z.s.clamp(1.0, 5.0);
      final target = s <= 1.01 ? _Zoom.one : _clampZ(s, z.x, z.y);
      _animateZoom(target, duration: const Duration(milliseconds: 260));
      _showPill();
      if (_pointers.length == 1) {
        // Остался палец — дальше он двигает приближенный снимок.
        _origin = _pointers.values.first;
        _z0 = target;
        _mode = target.zoomed ? _Mode.pan : _Mode.none;
        _vt = VelocityTracker.withKind(e.kind);
      } else {
        _origin = null;
        _mode = _Mode.none;
      }
      if (target.zoomed && _chrome) _setChrome(false);
      return;
    }
    if (_pointers.isNotEmpty) return;
    final o = _origin;
    _origin = null;
    if (o == null) return;
    final v = _vt?.getVelocity().pixelsPerSecond ?? Offset.zero;
    final mode = _mode;
    _mode = _Mode.none;
    switch (mode) {
      case _Mode.none:
        if (!cancelled) _handleTap(e.localPosition);
      case _Mode.pan:
        // Мягкая инерция без выхода за края.
        final z = _zoom.value;
        _animateZoom(
          _clampZ(z.s, z.x + v.dx * .18, z.y + v.dy * .18),
          duration: const Duration(milliseconds: 420),
        );
      case _Mode.page:
        final dx = (_index - _pagePos.value) * _pageStep;
        var n = _index;
        if (!cancelled) {
          // 8 px за кадр ≈ 480 px/с.
          if (dx < -70 || v.dx < -480) {
            n = _index + 1;
          } else if (dx > 70 || v.dx > 480) {
            n = _index - 1;
          }
        }
        _go(n);
      case _Mode.dismiss:
        final d = _drag.value ?? Offset.zero;
        // 10 px за кадр ≈ 600 px/с.
        if (!cancelled && (d.dy.abs() > 110 || v.dy.abs() > 600)) {
          _close();
        } else {
          _dragBackFrom = d;
          unawaited(_dragBack.forward(from: 0));
          setState(() {});
        }
    }
  }

  /// Одиночный жест прерван вторым пальцем: вернуть страницу и снимок.
  void _settleSingle({required bool cancelled}) {
    if (_mode == _Mode.page) _go(_index);
    if (_mode == _Mode.dismiss) {
      _dragBackFrom = _drag.value ?? Offset.zero;
      unawaited(_dragBack.forward(from: 0));
    }
    _mode = _Mode.none;
  }

  void _handleTap(Offset p) {
    final now = DateTime.now();
    final lt = _lastTapAt, lp = _lastTap;
    if (lt != null &&
        lp != null &&
        now.difference(lt) < const Duration(milliseconds: 300) &&
        (p - lp).distance < 40) {
      _tapTimer?.cancel();
      _lastTapAt = null;
      _doubleTap(p);
      return;
    }
    _lastTapAt = now;
    _lastTap = p;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      _lastTapAt = null;
      if (!mounted) return;
      _setChrome(!_chrome);
      if (_capOpen) setState(() => _capOpen = false);
    });
  }

  @visibleForTesting
  double get debugZoomScale => _zoom.value.s;

  /// Приближено — или вот-вот будет (анимация уже идёт к приближению).
  bool get _zoomedOrZooming =>
      _zoomAnim.isAnimating ? _zoomTo.zoomed : _zoom.value.zoomed;

  void _doubleTap(Offset p) {
    final w = _screen.width;
    if (_cur.isVideo) {
      final v = _video;
      if (v == null) return;
      if (p.dx < w / 3) {
        unawaited(v.seekBy(const Duration(seconds: -5)));
        _flashSeek(left: true);
      } else if (p.dx > w * 2 / 3) {
        unawaited(v.seekBy(const Duration(seconds: 5)));
        _flashSeek(left: false);
      } else {
        unawaited(v.togglePlay());
      }
      return;
    }
    final zoomed = _zoomedOrZooming;
    if (zoomed) {
      _animateZoom(_Zoom.one);
    } else {
      const s1 = 2.5;
      final c = _screen.center(Offset.zero);
      _animateZoom(_clampZ(s1, (p.dx - c.dx) * (1 - s1), (p.dy - c.dy) * (1 - s1)));
      _setChrome(false);
    }
    _showPill(target: zoomed ? 1 : 2.5);
  }

  void _flashSeek({required bool left}) {
    _seekFxTimer?.cancel();
    _seekFx.value = (left: left, n: (_seekFx.value?.n ?? 0) + 1);
    _seekFxTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) _seekFx.value = null;
    });
  }

  double _pillScale = 1;

  void _showPill({double? target}) {
    _pillScale = target ?? _zoom.value.s.clamp(1.0, 5.0);
    _pillTimer?.cancel();
    _zoomPill.value = false;
    _zoomPill.value = true;
    _pillTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _zoomPill.value = false;
    });
  }

  void _setChrome(bool v) {
    if (_chrome == v) return;
    setState(() => _chrome = v);
    SystemChrome.setEnabledSystemUIMode(
      v ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  // ─── Действия ─────────────────────────────────────────────────────────────

  void _showToast(String? text) {
    if (text == null || text.isEmpty || !mounted) return;
    _toastTimer?.cancel();
    _toast.value = text;
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) _toast.value = null;
    });
  }

  Future<T?> _withBusy<T>(Future<T?> Function() job) async {
    setState(() => _busy = true);
    _video?.blocked = true;
    try {
      return await job();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _video?.blocked = !_videoAllowed;
      }
    }
  }

  void _closeThen(Future<void> Function(MediaViewerEntry e)? action) {
    if (action == null) return;
    final e = _cur;
    _close(after: () => unawaited(action(e)));
  }

  bool _hasEdits(MediaViewerEntry e) =>
      !e.isVideo && !(MediaEditsStore.instance.peek(e.id)?.isIdentity ?? true);

  /// Правленый снимок — в JPEG во временную папку.
  Future<File?> _exportEdited(MediaViewerEntry e) async {
    final edits = await MediaEditsStore.instance.read(e.id);
    final src = _media[e.id]?.file ?? await e.loadFile();
    if (edits == null || edits.isIdentity) return null;
    final tmp = await getTemporaryDirectory();
    final stem = (e.exportName ?? 'photo').replaceAll(RegExp(r'\.[^.]+$'), '');
    final name = '${stem}_edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return exportEditedImageFile(
      source: src,
      edits: edits,
      outPath: p.join(tmp.path, 'secretly_edited', name),
    );
  }

  Future<void> _share() async {
    final e = _cur;
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : (box.localToGlobal(Offset.zero) & box.size);
    await _withBusy(() async {
      try {
        if (_hasEdits(e)) {
          final f = await _exportEdited(e);
          if (f == null) return null;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(f.path, mimeType: 'image/jpeg')],
              sharePositionOrigin: origin,
            ),
          );
          return null;
        }
        _showToast(await widget.actions.onShare?.call(e));
      } catch (err) {
        _showToast(l10n.downloadFailed(err.toString()));
      }
      return null;
    });
  }

  Future<void> _saveToGallery() async {
    final e = _cur;
    final l10n = context.l10n;
    await _withBusy(() async {
      try {
        if (_hasEdits(e)) {
          final f = await _exportEdited(e);
          if (f == null) return null;
          final perm = await PhotoManager.requestPermissionExtend(
            requestOption: const PermissionRequestOption(
              iosAccessLevel: IosAccessLevel.addOnly,
            ),
          );
          if (perm.hasAccess) {
            await PhotoManager.editor.saveImageWithPath(
              f.path,
              title: p.basename(f.path),
              relativePath: 'Pictures/Secretly',
            );
            _showToast(l10n.mvSavedToGallery);
          } else {
            final saved = await saveAttachmentToUserVisibleLocation(
              fileName: p.basename(f.path),
              source: f,
              mime: 'image/jpeg',
            );
            _showToast(l10n.savedTo(_shortPath(saved)));
          }
          return null;
        }
        _showToast(await widget.actions.onSaveToGallery?.call(e));
      } catch (err) {
        _showToast(l10n.downloadFailed(err.toString()));
      }
      return null;
    });
  }

  Future<void> _saveAsFile() async {
    final e = _cur;
    final l10n = context.l10n;
    await _withBusy(() async {
      try {
        if (_hasEdits(e)) {
          final f = await _exportEdited(e);
          if (f == null) return null;
          final saved = await saveAttachmentToUserVisibleLocation(
            fileName: p.basename(f.path),
            source: f,
            mime: 'image/jpeg',
          );
          _showToast(l10n.savedTo(_shortPath(saved)));
          return null;
        }
        _showToast(await widget.actions.onSaveAsFile?.call(e));
      } catch (err) {
        _showToast(l10n.downloadFailed(err.toString()));
      }
      return null;
    });
  }

  static String _shortPath(String path) {
    final parts = p.split(path);
    return parts.length <= 2 ? path : p.joinAll(parts.sublist(parts.length - 2));
  }

  Future<void> _copy() async {
    final e = _cur;
    if (e.isVideo) return;
    final l10n = context.l10n;
    await _withBusy(() async {
      try {
        final src = _media[e.id]?.file ?? await e.loadFile();
        final edits =
            await MediaEditsStore.instance.read(e.id) ?? MediaEdits.identity;
        // Всегда перерисовываем: в буфер уходит снимок без метаданных.
        final png = await exportEditedImagePng(source: src, edits: edits);
        // С-13: прежние копии буфера (Android кладёт <uuid>.png в кэш) уже
        // не в буфере — убрать их до новой.
        await sweepPasteboardCopies();
        await Pasteboard.writeImage(png);
        _haptic(HapticFeedback.lightImpact);
        _showToast(l10n.mvCopied);
      } catch (err) {
        _showToast(l10n.downloadFailed(err.toString()));
      }
      return null;
    });
  }

  Future<void> _edit() async {
    final e = _cur;
    final send = widget.actions.onSendEdited;
    if (e.isVideo || !widget.actions.canEdit || send == null) return;
    final m = _m(e);
    final img = m.image;
    if (img == null) return;
    final l10n = context.l10n;
    // Правка — всегда с чистого листа: оригинал не трогается.
    const initial = MediaEdits.identity;
    if (!mounted) return;
    _zoomAnim.stop();
    _zoom.value = _Zoom.one;
    setState(() {
      _busy = true;
      _menuOpen = false;
    });
    MediaEdits? result;
    try {
      result = await openMediaEditor(
        context,
        image: img,
        sourceAspect: _aspectOf(e),
        initial: initial,
        hapticsEnabled: widget.hapticsEnabled,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || result == null || result.sameAs(initial)) return;
    // 🔴 Правленое фото — новая копия: отправить или отменить. Оригинал
    // (в том числе присланный другом) не меняется ни в ленте, ни на диске.
    _video?.blocked = true;
    final choice = await showMediaViewerSheet<bool>(
      context: context,
      tokens: _t,
      title: l10n.mvEditedTitle,
      subtitle: l10n.mvEditedHint,
      options: [
        MediaSheetOption(label: l10n.mvEditedSend, value: true),
        MediaSheetOption(label: l10n.mvEditedDiscard, value: false, danger: true),
      ],
    );
    if (!mounted) return;
    _video?.blocked = !_videoAllowed;
    if (choice != true) return;
    await _withBusy(() async {
      try {
        final src = _media[e.id]?.file ?? await e.loadFile();
        final dir = await getTemporaryDirectory();
        final out = await exportEditedImageFile(
          source: src,
          edits: result!,
          outPath: p.join(
            dir.path,
            'edited_${DateTime.now().microsecondsSinceEpoch}.jpg',
          ),
        );
        final ok = await send(e, out);
        if (!mounted) return null;
        if (ok) {
          _haptic(HapticFeedback.lightImpact);
          _showToast(l10n.mvEditedSent);
        }
      } catch (err) {
        _showToast(l10n.downloadFailed(err.toString()));
      }
      return null;
    });
  }

  Future<void> _delete() async {
    final e = _cur;
    final onDelete = widget.actions.onDelete;
    if (onDelete == null) return;
    final l10n = context.l10n;
    final info =
        widget.actions.deleteInfo?.call(e) ?? MediaViewerDeleteInfo(own: e.own);
    final options = <MediaSheetOption<MediaDeleteScope>>[];
    String subtitle;
    if (info.own && info.canDeleteForEveryone) {
      options.add(
        MediaSheetOption(
          label: info.isGroup
              ? l10n.mvDeleteForEveryone
              : l10n.mvDeleteForBoth(info.peerName ?? ''),
          value: MediaDeleteScope.everyone,
          danger: true,
        ),
      );
      options.add(
        MediaSheetOption(
          label: l10n.mvDeleteForMeOnly,
          value: MediaDeleteScope.me,
          danger: true,
        ),
      );
      subtitle = info.isGroup ? l10n.mvDeleteOwnGroupHint : l10n.mvDeleteOwnHint;
    } else {
      options.add(
        MediaSheetOption(
          label: l10n.mvDeleteForMe,
          value: MediaDeleteScope.me,
          danger: true,
        ),
      );
      subtitle = info.own ? l10n.mvDeleteLocalHint : l10n.mvDeleteTheirsHint;
    }
    _video?.blocked = true;
    final scope = await showMediaViewerSheet<MediaDeleteScope>(
      context: context,
      tokens: _t,
      title: e.isVideo ? l10n.mvDeleteVideoTitle : l10n.mvDeletePhotoTitle,
      subtitle: subtitle,
      options: options,
    );
    if (!mounted) return;
    _video?.blocked = !_videoAllowed;
    if (scope == null) return;
    final ok = await onDelete(e, scope);
    if (!mounted || !ok) return;
    _haptic(HapticFeedback.mediumImpact);
    unawaited(MediaEditsStore.instance.forget(e.id));
    final removedAt = _index;
    if (_entries.length == 1) {
      _entries.clear();
      MediaFlightAnchors.hidden.value = null;
      _close();
      return;
    }
    if (_videoId == e.id) _disposeVideo();
    final toast = e.isVideo ? l10n.mvVideoDeleted : l10n.mvPhotoDeleted;
    setState(() {
      _entries.removeAt(removedAt);
      _media.remove(e.id);
      _capOpen = false;
      _soloPage = kViewerSoloSlideAfterDelete;
      // Сосед справа въезжает на место удалённого; если удалён последний —
      // въезжает сосед слева.
      if (removedAt < _entries.length) {
        _index = removedAt;
        _pagePos.value = removedAt - 1.0;
      } else {
        _index = _entries.length - 1;
        _pagePos.value = removedAt.toDouble();
      }
    });
    _zoom.value = _Zoom.one;
    MediaFlightAnchors.hidden.value = _cur.tag;
    _pagePos
        .animateTo(
          _index.toDouble(),
          duration: kMediaFlightDuration,
          curve: kMediaFlightCurve,
        )
        .whenCompleteOrCancel(() {
          if (mounted && _soloPage) setState(() => _soloPage = false);
        });
    _syncVideo();
    _warmNeighbours();
    _showToast(toast);
  }

  Future<void> _openGrid() async {
    final l10n = context.l10n;
    final t = _t;
    _video?.blocked = true;
    final picked = await showMediaViewerSheet<int>(
      context: context,
      tokens: t,
      title: l10n.mvAllMediaCount(_entries.length),
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(420.0, _screen.height * .5),
        ),
        child: _GridBody(
          entries: _entries,
          current: _index,
          tokens: t,
          ensure: (e) => _ensureMedia(e, download: false),
          media: (e) => _media[e.id],
          tick: _mediaTick,
        ),
      ),
    );
    if (!mounted) return;
    _video?.blocked = !_videoAllowed;
    if (picked != null) unawaited(_jumpTo(picked));
  }

  void _openMenu() {
    _tapTimer?.cancel();
    setState(() => _menuOpen = true);
  }

  // ─── Отрисовка ────────────────────────────────────────────────────────────

  Widget _island({
    required BorderRadius radius,
    required Widget child,
  }) {
    final t = _t;
    final deco = BoxDecoration(
      color: t.islandFill,
      borderRadius: radius,
      boxShadow: t.islandShadow,
      border: Border.all(color: t.islandBorder, width: .5),
    );
    if (!mediaViewerGlass) {
      return DecoratedBox(decoration: deco, child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: t.islandShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: mediaViewerGlassFilter(MediaViewerTokens.islandBlur / 2),
          child: DecoratedBox(
            decoration: deco.copyWith(boxShadow: const <BoxShadow>[]),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Снимок страницы: правки, загрузка, видео.
  Widget _pageContent(MediaViewerEntry e, {required bool live}) {
    return ValueListenableBuilder<int>(
      valueListenable: _mediaTick,
      builder: (context, _, _) {
        final m = _media[e.id];
        final img = m?.image;
        Widget placeholder() {
          final bytes = e.thumbBytes;
          final a = m?.aspect ?? e.knownAspect;
          Widget inner = bytes != null
              ? ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
                )
              : const SizedBox.shrink();
          if (a != null) {
            inner = Center(child: AspectRatio(aspectRatio: a, child: inner));
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              inner,
              Center(
                child: m?.failed == true
                    // Видео: сообщение с «Повторить» — поверх сцены.
                    ? (e.isVideo
                          ? const SizedBox.shrink()
                          : Icon(Icons.broken_image_outlined, color: _t.sub, size: 44))
                    : const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
                      ),
              ),
            ],
          );
        }

        if (e.isVideo) {
          final poster = img == null
              ? placeholder()
              : Image(
                  image: img,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                );
          final v = _video;
          if (live && v != null && _videoId == e.id) {
            return MediaViewerVideoSurface(video: v, poster: poster);
          }
          return poster;
        }
        if (img == null) return placeholder();
        return ValueListenableBuilder<MediaEdits?>(
          valueListenable: MediaEditsStore.instance.listen(e.id),
          builder: (context, edits, _) => EditedMediaView(
            image: img,
            edits: edits ?? MediaEdits.identity,
            sourceAspect: m?.aspect,
            filterQuality: FilterQuality.medium,
          ),
        );
      },
    );
  }

  /// Содержимое страниц на один кадр сборки экрана: во время протяжки и
  /// приближения AnimatedBuilder получает ТЕ ЖЕ виджеты — Flutter их не
  /// пересобирает, двигается только слой.
  final Map<String, Widget> _pageWidgets = <String, Widget>{};

  Widget _buildPages() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pagePos, _drag, _zoom]),
      builder: (context, _) {
        final pos = _pagePos.value;
        final step = _pageStep;
        final size = _screen;
        final hideForFlight =
            _flightId != null ||
            (kViewerHidePagesWhilePreparing && _phase == _Phase.preparing);
        final children = <Widget>[];
        for (var i = _index - 1; i <= _index + 1; i++) {
          if (i < 0 || i >= _entries.length) continue;
          if (_soloPage && i != _index) continue;
          final x = (i - pos) * step;
          if (x.abs() > step * 1.5) continue;
          final e = _entries[i];
          final live = i == _index;
          Widget page = _pageWidgets.putIfAbsent(
            '${e.id}|$live',
            () => RepaintBoundary(child: _pageContent(e, live: live)),
          );
          if (i == _index) {
            final d = _drag.value;
            final z = _zoom.value;
            final Matrix4 m;
            if (d != null) {
              final s = 1 - (d.dy.abs() / 1000).clamp(0.0, .3);
              m = Matrix4.identity()
                ..translateByDouble(d.dx, d.dy, 0, 1)
                ..scaleByDouble(s, s, 1, 1);
            } else {
              m = Matrix4.identity()
                ..translateByDouble(z.x, z.y, 0, 1)
                ..scaleByDouble(z.s, z.s, 1, 1);
            }
            page = Transform(
              alignment: Alignment.center,
              transform: m,
              child: page,
            );
          }
          children.add(
            Positioned(
              key: ValueKey<String>('mv-page-${e.id}'),
              left: x,
              top: 0,
              width: size.width,
              height: size.height,
              child: Opacity(opacity: hideForFlight ? 0 : 1, child: page),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }

  Widget _buildFlight() {
    final id = _flightId;
    if (id == null) return const SizedBox.shrink();
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return const SizedBox.shrink();
    final e = _entries[idx];
    final f = _fitRect(e);
    final m = _media[e.id];
    final img = m?.image;
    Widget child;
    if (img == null) {
      final bytes = e.thumbBytes;
      child = bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
          : ColoredBox(color: _t.viewerBg);
    } else if (e.isVideo) {
      child = Image(image: img, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      child = EditedMediaView(
        image: img,
        edits: _editsOf(e),
        sourceAspect: m?.aspect,
      );
    }
    return AnimatedBuilder(
      animation: _flight,
      builder: (context, _) {
        final t = kMediaFlightCurve.transform(_flight.value);
        return Stack(
          children: [
            MediaFlightLayer(
              pose: FlightPose.lerp(_flightFrom, _flightTo, t),
              fit: f,
              child: SizedBox(width: f.width, height: f.height, child: child),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_flight, _drag]),
      builder: (context, _) {
        double o;
        switch (_phase) {
          case _Phase.preparing:
            o = 0;
          case _Phase.opening:
          case _Phase.closing:
            final t = Curves.ease.transform(_flight.value);
            o = _bgFrom + (_bgTo - _bgFrom) * t;
          case _Phase.open:
            o = _bgNow();
        }
        return ColoredBox(color: _t.viewerBg.withValues(alpha: o.clamp(0.0, 1.0)));
      },
    );
  }

  String _subtitle(BuildContext context, MediaViewerEntry e) {
    final l10n = context.l10n;
    final parts = <String>[];
    if (_entries.length > 1) {
      parts.add(l10n.mvCounter(_index + 1, _entries.length));
    }
    final time = e.time;
    if (time != null) {
      final material = MaterialLocalizations.of(context);
      final hm = material.formatTimeOfDay(
        TimeOfDay.fromDateTime(time),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(time.year, time.month, time.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) {
        parts.add(l10n.mvDateToday(hm));
      } else if (diff == 1) {
        parts.add(l10n.mvDateYesterday(hm));
      } else {
        parts.add('${material.formatShortDate(time)}, $hm');
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    _pageWidgets.clear();
    final t = _t;
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safeTop = mq.viewPadding.top;
    final safeBottom = mq.viewPadding.bottom;
    final l10n = context.l10n;
    final open = _phase == _Phase.open;
    final cur = _entries.isEmpty ? null : _cur;
    final dragging = _drag.value != null || _mode == _Mode.dismiss;
    final chromeOn = open && _chrome && !dragging && !_busy;
    final isVid = cur?.isVideo ?? false;
    final cap = (cur?.caption ?? '').trim();
    final hasCap = cap.isNotEmpty;
    final actions = widget.actions;

    // Нижняя стопка — от панели действий вверх (см. прототип: 30 / 94 / 146).
    final barBottom = math.max(safeBottom - 4, 12.0);
    final hasBar = actions.hasBar;
    final barTop = hasBar ? barBottom + 58 : barBottom;
    final hasStrip = _entries.length > 1;
    final stripBottom = barTop + 6;
    final stripTop = hasStrip ? stripBottom + 50 : barTop;
    final videoBottom = stripTop + 2;
    final videoTop = videoBottom + 44;
    final capBottom = (isVid ? videoTop : stripTop) + 10;
    final scrimBase = isVid ? videoTop : stripTop;
    final scrimH = _capOpen
        ? scrimBase + 336
        : isVid
        ? math.max(scrimBase + 110, hasCap ? capBottom + 100 : 0.0)
        : scrimBase + (hasCap ? 146 : 86);
    final headerTop = safeTop + 6;

    final style = t.isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_menuOpen) {
            setState(() => _menuOpen = false);
            return;
          }
          _close();
        },
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: t.ink),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _buildBackground()),
                Positioned.fill(child: _buildPages()),
                Positioned.fill(child: _buildFlight()),
                // Сцена: все жесты по снимку.
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onDown,
                    onPointerMove: _onMove,
                    onPointerUp: (e) => _onUp(e, cancelled: false),
                    onPointerCancel: (e) => _onUp(e, cancelled: true),
                    child: Semantics(
                      image: !isVid,
                      label: cur?.title ?? widget.title,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                if (isVid && open) _buildBigPlay(size),
                if (isVid && open && cur != null) _buildVideoState(cur),
                if (isVid) _buildSeekFx(size),
                // Оформление.
                IgnorePointer(
                  ignoring: !chromeOn,
                  child: AnimatedOpacity(
                    opacity: chromeOn ? 1 : 0,
                    duration: kMediaChromeFade,
                    curve: Curves.ease,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: safeTop + 106,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: t.scrimTop,
                                  stops: const [0, .55, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.ease,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: scrimH,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: t.scrimBottom,
                                  stops: const [0, .5, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (cur != null)
                          Positioned(
                            top: headerTop,
                            left: 8,
                            right: 8,
                            // С-11: без жёсткой высоты — при крупном шрифте
                            // шапка растёт, а не обрезается.
                            child: AnimatedSlide(
                              offset: chromeOn ? Offset.zero : const Offset(0, -12 / 48),
                              duration: kMediaChromeSlide,
                              curve: Curves.ease,
                              child: _buildHeader(context, cur),
                            ),
                          ),
                        if (cur != null && hasCap)
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: capBottom,
                            child: _Caption(
                              text: cap,
                              open: _capOpen,
                              tokens: t,
                              moreLabel: l10n.mvShowFullCaption,
                              onTap: () => setState(() => _capOpen = !_capOpen),
                            ),
                          ),
                        if (isVid && _video != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: videoBottom,
                            height: 44,
                            child: MediaViewerVideoPanel(
                              video: _video!,
                              tokens: t,
                              island: _island,
                              playLabel: l10n.mvPlay,
                              pauseLabel: l10n.mvPause,
                              replayLabel: l10n.mvReplay,
                              speedLabel: l10n.mvSpeed,
                              muteLabel: l10n.mvMute,
                              unmuteLabel: l10n.mvUnmute,
                              icons: const MediaVideoIcons(
                                play: _Ic.play,
                                pause: _Ic.pause,
                                replay: _Ic.replay,
                                volumeOn: _Ic.volumeOn,
                                volumeOff: _Ic.volumeOff,
                              ),
                              onInteract: () {},
                            ),
                          ),
                        if (hasStrip)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: stripBottom,
                            height: 50,
                            child: _Strip(
                              entries: _entries,
                              pos: _pagePos,
                              index: _index,
                              tokens: t,
                              media: (e) => _media[e.id],
                              ensure: (e) => _ensureMedia(e, download: false),
                              tick: _mediaTick,
                              onTap: (i) => unawaited(_jumpTo(i)),
                            ),
                          ),
                        if (cur != null && hasBar)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: barBottom,
                            height: 58,
                            child: AnimatedSlide(
                              offset: chromeOn ? Offset.zero : const Offset(0, 12 / 58),
                              duration: kMediaChromeSlide,
                              curve: Curves.ease,
                              child: _buildBar(context, cur),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: safeTop + 68,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: _buildZoomPill(context)),
                ),
                if (_menuOpen && cur != null) ..._buildMenu(context, cur, headerTop + 54),
                Positioned(
                  top: safeTop + 64,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(child: _buildToast()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MediaViewerEntry e) {
    final t = _t;
    final l10n = context.l10n;
    final hasMenu = _menuItems(context, e).isNotEmpty;
    final title = (e.title ?? '').trim().isNotEmpty
        ? e.title!.trim()
        : (widget.title ?? '').trim();
    final sub = _subtitle(context, e);
    return Row(
      children: [
        _RoundIsland(
          island: _island,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: _close,
          child: Icon(_Ic.back, size: 24, color: t.ink),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _island(
            radius: BorderRadius.circular(24),
            // С-11: шрифт не крупнее 1,3× (две строки остаются в 48), и
            // блок растёт, если строкам всё же тесно.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: kViewerHeaderMaxTextScale,
              child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.sub,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (hasMenu)
          _RoundIsland(
            island: _island,
            tooltip: l10n.mvMenu,
            onTap: _openMenu,
            child: Icon(_Ic.more, size: 24, color: t.ink),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  List<({IconData icon, String label, VoidCallback onTap})> _menuItems(
    BuildContext context,
    MediaViewerEntry e,
  ) {
    final l10n = context.l10n;
    final a = widget.actions;
    return [
      if (a.onSaveToGallery != null)
        (icon: _Ic.saveGallery, label: l10n.mvSaveToGallery, onTap: _saveToGallery),
      if (a.onSaveAsFile != null)
        (icon: _Ic.saveFile, label: l10n.mvSaveAsFile, onTap: _saveAsFile),
      if (a.onShowInChat != null)
        (
          icon: _Ic.showInChat,
          label: l10n.mvShowInChat,
          onTap: () => _closeThen(a.onShowInChat),
        ),
      if (_entries.length > 1)
        (icon: _Ic.grid, label: l10n.mvAllMedia, onTap: _openGrid),
      if (a.canCopy && !e.isVideo)
        (icon: _Ic.copy, label: l10n.mvCopy, onTap: _copy),
    ];
  }

  List<Widget> _buildMenu(BuildContext context, MediaViewerEntry e, double top) {
    final t = _t;
    final items = _menuItems(context, e);
    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _menuOpen = false),
        ),
      ),
      Positioned(
        top: top,
        right: 8,
        width: 252,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(
              scale: .92 + .08 * v,
              alignment: Alignment.topRight,
              child: child,
            ),
          ),
          child: _sheetPanel(
            radius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final it in items)
                    _MenuRow(
                      icon: it.icon,
                      label: it.label,
                      color: t.ink,
                      onTap: () {
                        setState(() => _menuOpen = false);
                        it.onTap();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _sheetPanel({required BorderRadius radius, required Widget child}) {
    final t = _t;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: radius,
        boxShadow: t.sheetShadow,
        border: Border.all(color: t.islandBorder, width: .5),
      ),
      child: child,
    );
    if (!mediaViewerGlass) return panel;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: mediaViewerGlassFilter(MediaViewerTokens.sheetBlur / 2),
        child: panel,
      ),
    );
  }

  Widget _buildBar(BuildContext context, MediaViewerEntry e) {
    final t = _t;
    final l10n = context.l10n;
    final a = widget.actions;
    final items = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      if (a.onReply != null)
        (icon: _Ic.reply, label: l10n.mvReply, color: t.ink, onTap: () => _closeThen(a.onReply)),
      if (a.onForward != null)
        (icon: _Ic.forward, label: l10n.mvForward, color: t.ink, onTap: () => _closeThen(a.onForward)),
      if (a.canEdit && a.onSendEdited != null && !e.isVideo)
        (icon: _Ic.edit, label: l10n.mvEdit, color: t.ink, onTap: _edit),
      if (a.onShare != null)
        (icon: _Ic.share, label: l10n.mvShare, color: t.ink, onTap: _share),
      if (a.onDelete != null)
        (icon: _Ic.delete, label: l10n.mvDelete, color: t.danger, onTap: _delete),
    ];
    return _island(
      radius: BorderRadius.circular(29),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final it in items)
              Expanded(
                child: _BarButton(
                  icon: it.icon,
                  label: it.label,
                  color: it.color,
                  onTap: it.onTap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigPlay(Size size) {
    final v = _video;
    if (v == null) return const SizedBox.shrink();
    return Positioned(
      left: size.width / 2 - 36,
      top: size.height / 2 - 36,
      width: 72,
      height: 72,
      child: AnimatedBuilder(
        animation: Listenable.merge([v.controller, v.ended, v.failed, _drag]),
        builder: (context, _) {
          final show = !v.controller.value.isPlaying &&
              v.ready.value &&
              !v.failed.value &&
              _drag.value == null &&
              !_busy;
          if (!show) return const SizedBox.shrink();
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: .92, end: 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, s, child) => Opacity(
              opacity: ((s - .92) / .08).clamp(0.0, 1.0),
              child: Transform.scale(scale: s, child: child),
            ),
            child: Semantics(
              button: true,
              label: v.ended.value ? context.l10n.mvReplay : context.l10n.mvPlay,
              child: GestureDetector(
                onTap: () => unawaited(v.togglePlay()),
                child: ClipOval(
                  child: BackdropFilter(
                    enabled: mediaViewerGlass,
                    filter: mediaViewerGlassFilter(7),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x800A0E13),
                        border: Border.all(color: const Color(0x40FFFFFF), width: .5),
                      ),
                      child: Center(
                        child: Icon(
                          v.ended.value ? _Ic.replay : _Ic.play,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Видео не открылось (не скачалось или плеер не справился) — сообщение и
  /// «Повторить»; плеер по ходу скачивания ждёт байтов — крутилка.
  Widget _buildVideoState(MediaViewerEntry e) {
    final t = _t;
    return ValueListenableBuilder<int>(
      valueListenable: _mediaTick,
      builder: (context, _, _) {
        final v = _video;
        final server = v?.server;
        Widget body() {
          final m = _media[e.id];
          final playerFailed = v != null && !v.isProgressive && v.failed.value;
          if ((v == null && (m?.failed ?? false)) || playerFailed) {
            final l10n = context.l10n;
            return Center(
              key: const ValueKey<String>('mv-video-error'),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.6,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: _island(
                    radius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_Ic.playError, size: 30, color: t.sub),
                          const SizedBox(height: 8),
                          Text(
                            l10n.mvVideoOpenFailed,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            button: true,
                            child: _Pressable(
                              onTap: _retryVideo,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                  minWidth: 120,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.chip,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  l10n.mvRetry,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: t.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final waiting =
              v != null &&
              server != null &&
              v.ready.value &&
              v.wantPlay.value &&
              (server.waiting.value || v.controller.value.isBuffering);
          if (waiting) {
            return IgnorePointer(
              child: Center(
                child: Semantics(
                  label: context.l10n.mvVideoBuffering,
                  child: const DecoratedBox(
                    key: ValueKey<String>('mv-video-buffering'),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x800A0E13),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        if (v == null) return Positioned.fill(child: body());
        return Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              v.failed,
              v.ready,
              v.wantPlay,
              v.controller,
              if (server != null) server.waiting,
            ]),
            builder: (context, _) => body(),
          ),
        );
      },
    );
  }

  Widget _buildSeekFx(Size size) {
    return ValueListenableBuilder<({bool left, int n})?>(
      valueListenable: _seekFx,
      builder: (context, fx, _) {
        if (fx == null) return const SizedBox.shrink();
        final cx = fx.left ? size.width * .23 : size.width * .77;
        return Positioned(
          left: cx - 60,
          top: size.height / 2 - 60,
          width: 120,
          height: 120,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey<int>(fx.n),
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOut,
              builder: (context, v, child) {
                final o = v < .25 ? v / .25 : 1 - (v - .25) / .75;
                return Opacity(
                  opacity: o.clamp(0.0, 1.0),
                  child: Transform.scale(scale: .8 + .35 * v, child: child),
                );
              },
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2EFFFFFF),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      fx.left ? _Ic.rewind : _Ic.fastForward,
                      size: 30,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fx.left ? context.l10n.mvSeekBack : context.l10n.mvSeekForward,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoomPill(BuildContext context) {
    final t = _t;
    final dec = Localizations.localeOf(context).languageCode == 'en' ? '.' : ',';
    return ValueListenableBuilder<bool>(
      valueListenable: _zoomPill,
      builder: (context, show, _) {
        return AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: AnimatedScale(
              scale: show ? 1 : .92,
              duration: const Duration(milliseconds: 150),
              child: _island(
                radius: BorderRadius.circular(15),
                child: SizedBox(
                  height: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_Ic.zoom, size: 17, color: t.ink),
                        const SizedBox(width: 5),
                        Text(
                          '${_pillScale.toStringAsFixed(1).replaceAll('.', dec)}×',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                            fontFeatures: const [ui.FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToast() {
    final t = _t;
    return ValueListenableBuilder<String?>(
      valueListenable: _toast,
      builder: (context, text, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .3),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('mv-toast-none'))
              : Center(
                  key: ValueKey<String>('mv-toast-$text'),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.toastBg,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_Ic.check, size: 18, color: t.accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: t.toastInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ─── Части оформления ───────────────────────────────────────────────────────

class _RoundIsland extends StatelessWidget {
  const _RoundIsland({
    required this.island,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final Widget Function({required BorderRadius radius, required Widget child})
  island;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: _Pressable(
        onTap: onTap,
        child: island(
          radius: BorderRadius.circular(24),
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Нажатие с лёгким сжатием (как остальные острова приложения).
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: Duration(milliseconds: _down ? 90 : 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _down ? const Color(0x1F808080) : const Color(0x00808080),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 23, color: widget.color),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: _down ? const Color(0x1F808080) : const Color(0x00808080),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 22, color: widget.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: widget.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Подпись: 2 строки и «Показать полностью»; касание раскрывает до 240 px
/// с прокруткой.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.open,
    required this.tokens,
    required this.moreLabel,
    required this.onTap,
  });

  final String text;
  final bool open;
  final MediaViewerTokens tokens;
  final String moreLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 14.5, height: 1.4, color: tokens.ink);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        alignment: Alignment.bottomCenter,
        child: open
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(child: Text(text, style: style)),
              )
            : LayoutBuilder(
                builder: (context, c) {
                  final tp = TextPainter(
                    text: TextSpan(text: text, style: style),
                    maxLines: 2,
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: c.maxWidth);
                  final overflow = tp.didExceedMaxLines;
                  tp.dispose();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                      if (overflow)
                        Text(
                          moreLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.sub,
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Маленький снимок с правками (лента миниатюр, сетка «Все медиа»).
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.entry,
    required this.media,
    required this.ensure,
    required this.tick,
  });

  final MediaViewerEntry entry;
  final _Media? Function(MediaViewerEntry e) media;
  final Future<void> Function(MediaViewerEntry e) ensure;
  final ValueListenable<int> tick;

  @override
  Widget build(BuildContext context) {
    unawaited(ensure(entry));
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, _) {
        final m = media(entry);
        final thumb = m?.thumb;
        Widget child;
        if (thumb == null) {
          final bytes = entry.thumbBytes;
          child = bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
              : const ColoredBox(color: Color(0x33808080));
        } else if (entry.isVideo) {
          child = Image(image: thumb, fit: BoxFit.cover, gaplessPlayback: true);
        } else {
          child = ValueListenableBuilder<MediaEdits?>(
            valueListenable: MediaEditsStore.instance.listen(entry.id),
            builder: (context, edits, _) => (edits == null || edits.isIdentity)
                ? Image(image: thumb, fit: BoxFit.cover, gaplessPlayback: true)
                : EditedMediaView(
                    image: thumb,
                    edits: edits,
                    cover: true,
                    sourceAspect: m?.aspect,
                  ),
          );
        }
        return child;
      },
    );
  }
}

/// Лента миниатюр: 32×44, радиус 7, зазор 4; текущая ×1,14 с обводкой 2 px,
/// остальные — 55 %. Едет вместе с пальцем: позиция = центр − (fi·36 + 16).
class _Strip extends StatelessWidget {
  const _Strip({
    required this.entries,
    required this.pos,
    required this.index,
    required this.tokens,
    required this.media,
    required this.ensure,
    required this.tick,
    required this.onTap,
  });

  final List<MediaViewerEntry> entries;
  final Animation<double> pos;
  final int index;
  final MediaViewerTokens tokens;
  final _Media? Function(MediaViewerEntry e) media;
  final Future<void> Function(MediaViewerEntry e) ensure;
  final ValueListenable<int> tick;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        colors: [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        stops: [0, .14, .86, 1],
      ).createShader(r),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          // Миниатюры — одни и те же виджеты на все кадры протяжки.
          final thumbs = <String, Widget>{};
          return AnimatedBuilder(
            animation: pos,
            builder: (context, _) {
              final fi = pos.value;
              final visible = (w / 36 / 2).ceil() + 2;
              final lo = math.max(0, (fi - visible).floor());
              final hi = math.min(entries.length - 1, (fi + visible).ceil());
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = lo; i <= hi; i++)
                    Positioned(
                      key: ValueKey<String>('mv-strip-${entries[i].id}'),
                      left: w / 2 - (fi * 36 + 16) + i * 36,
                      top: 3,
                      width: 32,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        child: AnimatedOpacity(
                          opacity: i == index ? 1 : .55,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedScale(
                            scale: i == index ? 1.14 : 1,
                            duration: const Duration(milliseconds: 250),
                            curve: kMediaFlightCurve,
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                border: i == index
                                    ? Border.all(
                                        color: tokens.ring,
                                        width: 2,
                                        strokeAlign: BorderSide.strokeAlignOutside,
                                      )
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    thumbs.putIfAbsent(
                                      entries[i].id,
                                      () => _Thumb(
                                        entry: entries[i],
                                        media: media,
                                        ensure: ensure,
                                        tick: tick,
                                      ),
                                    ),
                                    if (entries[i].isVideo)
                                      const Center(
                                        child: Icon(
                                          _Ic.play,
                                          size: 16,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(color: Color(0x80000000), blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
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
        },
      ),
    );
  }
}

/// Сетка «Все медиа»: 3 колонки, зазор 4, радиус 10; текущая — обводка
/// акцента 2,5 px внутри.
class _GridBody extends StatelessWidget {
  const _GridBody({
    required this.entries,
    required this.current,
    required this.tokens,
    required this.ensure,
    required this.media,
    required this.tick,
  });

  final List<MediaViewerEntry> entries;
  final int current;
  final MediaViewerTokens tokens;
  final Future<void> Function(MediaViewerEntry e) ensure;
  final _Media? Function(MediaViewerEntry e) media;
  final ValueListenable<int> tick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final m = media(e);
        final dur = m?.duration ?? e.duration;
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Thumb(entry: e, media: media, ensure: ensure, tick: tick),
                if (e.isVideo)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x8C0A0E13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: dur == null
                          ? const Icon(_Ic.play, size: 12, color: Colors.white)
                          : Text(
                              formatMediaTime(dur),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                if (i == current)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.accent, width: 2.5),
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
