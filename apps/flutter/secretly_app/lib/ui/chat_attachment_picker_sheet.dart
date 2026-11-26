// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image/image.dart' as img;
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:secretly_app/ui/video_trim_editor_screen.dart';
import '../media/photo_compressor.dart' show kPhotoSendMaxSideSd;
import '../media/video_compressor.dart' show VideoCompressor;
import 'media_viewer/media_viewer_tokens.dart' show mediaViewerGlass, mediaViewerGlassFilter, mediaViewerLiquidGlass;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../build_variant.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'motion/app_dialogs.dart';
import 'motion/motion.dart';
import 'motion/press_feedback.dart';
import 'recent_attachments_store.dart';
import 'widgets/island_backdrop.dart';
import '../diagnostics/picker_probe.dart';
import 'motion/frame_stats.dart' show kFrameStats;
import 'chat/composer_drops.dart' show ComposerDropStyle, ComposerDropSurface;
import 'gallery_thumbs.dart';
import 'theme_presets.dart';
import 'wave1_l10n.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/broken_media_box.dart';
import 'media_viewer/edited_media_view.dart' show exportEditedImageFile;
import 'media_viewer/editor/media_editor_model.dart' show MediaEditorTab;
import 'media_viewer/editor/media_editor_screen.dart' show openMediaEditor;
import 'media_viewer/media_edits.dart' show MediaEdits;
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

enum ChatAttachmentPickerResultKind {
  photos,
  file,
  filesFromGallery,
  audio,
  poll,
  topic,
  event,
}

enum ChatAttachmentPickerMediaKind { image, video }

/// Параметры отправки пачки (SendFlow, меню по долгому нажатию).
class ChatAttachmentSendOptions {
  const ChatAttachmentSendOptions({
    this.captionAbove = false,
    this.group = true,
    this.spoiler = false,
    this.silent = false,
    this.scheduleAtMs,
  });

  static const ChatAttachmentSendOptions defaults = ChatAttachmentSendOptions();

  /// Подпись над медиа.
  final bool captionAbove;

  /// `false` — «Не группировать»: каждое медиа отдельным сообщением.
  final bool group;

  /// Скрыть под спойлер (только если все получатели умеют).
  final bool spoiler;

  /// Без звука у получателя.
  final bool silent;

  /// Отложенная отправка (момент, мс); `null` — сразу.
  final int? scheduleAtMs;
}

class ChatAttachmentPickerMediaItem {
  const ChatAttachmentPickerMediaItem({
    required this.path,
    required this.kind,
    this.mime,
    this.caption = '',
    this.photoMaxSide,
    this.videoMaxSide,
    this.muteVideo = false,
    this.viewOnce = false,
  });

  /// Одноразовый просмотр этого снимка (SendFlow Э5).
  final bool viewOnce;

  final String path;
  final ChatAttachmentPickerMediaKind kind;
  final String? mime;

  /// SendFlow: качество, выбранное в просмотре (см. PendingPhotoUpload).
  final int? photoMaxSide;
  final int? videoMaxSide;
  final bool muteVideo;

  /// SEND EDITOR (2026-07-17): caption typed in the fullscreen pre-send
  /// editor. Non-empty → the chat uses it directly and skips its own caption
  /// sheet.
  final String caption;

  bool get isImage => kind == ChatAttachmentPickerMediaKind.image;
  bool get isVideo => kind == ChatAttachmentPickerMediaKind.video;

  String get resolvedMime {
    final trimmed = mime?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return isVideo ? 'video/mp4' : 'image/jpeg';
  }
}

class ChatAttachmentPickerResult {
  ChatAttachmentPickerResult.photos(
    List<ChatAttachmentPickerMediaItem> items, {
    ChatAttachmentSendOptions options = ChatAttachmentSendOptions.defaults,
  }) : _options = options,
       kind = ChatAttachmentPickerResultKind.photos,
      mediaItems = List<ChatAttachmentPickerMediaItem>.unmodifiable(items),
      filePaths = List<String>.unmodifiable(
        items.map((item) => item.path).toList(growable: false),
      ),
      fileName = null,
      fileNames = const <String?>[];

  /// Gallery photos/videos picked from the «Галерея» source on the FILE tab.
  /// Same media items as [photos], but the caller must send them through the
  /// generic-file path (original bytes, uncompressed) instead of the
  /// compressing photo pipeline. Each item is sent as its OWN file (document
  /// bubble) — no album grouping.
  ChatAttachmentPickerResult.filesFromGallery(
    List<ChatAttachmentPickerMediaItem> items,
  ) : kind = ChatAttachmentPickerResultKind.filesFromGallery,
      mediaItems = List<ChatAttachmentPickerMediaItem>.unmodifiable(items),
      filePaths = List<String>.unmodifiable(
        items.map((item) => item.path).toList(growable: false),
      ),
      fileName = null,
      fileNames = const <String?>[];

  ChatAttachmentPickerResult.file(String filePath, {String? fileName})
    : kind = ChatAttachmentPickerResultKind.file,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = List<String>.unmodifiable(<String>[filePath]),
      fileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : null,
      fileNames = List<String?>.unmodifiable(<String?>[
        (fileName != null && fileName.trim().isNotEmpty)
            ? fileName.trim()
            : null,
      ]);

  /// О9 (разбор медиа 15.11.2026): несколько документов за раз, как на ПК.
  /// Тот же вид результата [ChatAttachmentPickerResultKind.file]; каждый
  /// файл уходит отдельным сообщением. [fileNames] идёт парой к [filePaths].
  ChatAttachmentPickerResult.files(
    List<({String path, String? name})> picked,
  ) : assert(picked.isNotEmpty),
      kind = ChatAttachmentPickerResultKind.file,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = List<String>.unmodifiable(
        picked.map((f) => f.path).toList(growable: false),
      ),
      fileName = picked.first.name,
      fileNames = List<String?>.unmodifiable(
        picked.map((f) => f.name).toList(growable: false),
      );

  ChatAttachmentPickerResult.audio(String filePath)
    : kind = ChatAttachmentPickerResultKind.audio,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = List<String>.unmodifiable(<String>[filePath]),
      fileName = null,
      fileNames = const <String?>[];

  ChatAttachmentPickerResult.poll()
    : kind = ChatAttachmentPickerResultKind.poll,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null,
      fileNames = const <String?>[];

  ChatAttachmentPickerResult.topic()
    : kind = ChatAttachmentPickerResultKind.topic,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null,
      fileNames = const <String?>[];

  ChatAttachmentPickerResult.event()
    : kind = ChatAttachmentPickerResultKind.event,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null,
      fileNames = const <String?>[];

  final ChatAttachmentPickerResultKind kind;
  final List<ChatAttachmentPickerMediaItem> mediaItems;

  /// SendFlow: параметры отправки из меню (долгое нажатие на «Отправить»).
  ChatAttachmentSendOptions? _options;
  ChatAttachmentSendOptions get options =>
      _options ?? ChatAttachmentSendOptions.defaults;
  final List<String> filePaths;

  /// Original file name (e.g. "report.pdf") for the [file] result, captured
  /// from the picker (PlatformFile.name) so the chat shows the real name +
  /// format. Null for non-file results.
  final String? fileName;

  /// Original names for each of [filePaths] (same order); empty for results
  /// that carry no names.
  final List<String?> fileNames;

  String? get primaryPath => filePaths.isEmpty ? null : filePaths.first;
  ChatAttachmentPickerMediaItem? get primaryMediaItem =>
      mediaItems.isEmpty ? null : mediaItems.first;
}

Future<ChatAttachmentPickerResult?> showChatAttachmentPickerSheet(
  BuildContext context, {
  bool showPoll = false,
  bool showTopic = false,
  bool showEvent = false,
  Future<bool> Function()? spoilerSupported,
  VoidCallback? onSettled,
}) {
  return showModalBottomSheet<ChatAttachmentPickerResult>(
  sheetAnimationStyle: appSheetAnimationStyle,
    context: context,
    enableDrag: true,
    isDismissible: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (context) => _ChatAttachmentPickerSheet(
      showPoll: showPoll,
      showTopic: showTopic,
      showEvent: showEvent,
      spoilerSupported: spoilerSupported,
      onSettled: onSettled,
    ),
  );
}

/// Первая страница из памяти → свежая: свежая целиком, за ней подгруженное
/// ниже (без повторов и без ушедшего из первой страницы). `null` — ничего не
/// изменилось.
@visibleForTesting
List<AssetEntity>? mergeGalleryPages({
  required List<AssetEntity> shown,
  required List<AssetEntity> oldFirst,
  required List<AssetEntity> fresh,
}) {
  bool same = oldFirst.length == fresh.length;
  for (var i = 0; same && i < fresh.length; i++) {
    same =
        oldFirst[i].id == fresh[i].id &&
        oldFirst[i].modifiedDateSecond == fresh[i].modifiedDateSecond;
  }
  if (same) return null;
  final freshIds = {for (final a in fresh) a.id};
  final oldIds = {for (final a in oldFirst) a.id};
  return [
    ...fresh,
    for (final a in shown)
      if (!freshIds.contains(a.id) && !oldIds.contains(a.id)) a,
  ];
}

/// Шапка листа: ручка, под ней название альбома, сразу под ним снимки
/// (владелец, 25.11.2026: ближе к верхнему краю). У файлов и музыки шапка
/// пустая — место только под ручку.
const double kSheetHeaderTop = 12;
const double kSheetHeaderHeight = 32;
const double kSheetGridTop = kSheetHeaderTop + kSheetHeaderHeight + 2;
const double kSheetListTop = 28;

enum _AttachmentPickerTab { photo, file, music }

class _ChatAttachmentPickerSheet extends StatefulWidget {
  const _ChatAttachmentPickerSheet({
    this.showPoll = false,
    this.showTopic = false,
    this.showEvent = false,
    this.spoilerSupported,
    this.onSettled,
  });

  /// Лист выехал до конца.
  final VoidCallback? onSettled;

  /// Умеют ли все получатели спойлер и одноразовый просмотр (SendFlow Э5).
  final Future<bool> Function()? spoilerSupported;

  final bool showPoll;
  final bool showTopic;
  final bool showEvent;

  @override
  State<_ChatAttachmentPickerSheet> createState() =>
      _ChatAttachmentPickerSheetState();
}

class _ChatAttachmentPickerSheetState
    extends State<_ChatAttachmentPickerSheet>
    with WidgetsBindingObserver {
  static const int _galleryPageSize = 80;
  static const double _galleryPrefetchExtent = 720;

  static const Set<String> _audioExtensions = <String>{
    'mp3',
    'm4a',
    'aac',
    'wav',
    'aif',
    'aiff',
    'caf',
    'ogg',
    'opus',
    'flac',
    'm4b',
    'wma',
    'amr',
  };
  final List<AssetEntity> _galleryAssets = <AssetEntity>[];
  // ── SendFlow Э1 (24.11.2026, макет SendFlow) ──────────────────────────
  /// Альбом сетки: Недавние / Избранное / Видео / Скриншоты.
  _GalleryFilter _galleryFilter = _GalleryFilter.recent;
  final Map<_GalleryFilter, AssetPathEntity> _filterPaths = {};
  final Map<_GalleryFilter, int> _filterCounts = {};
  bool _filtersResolved = false;
  bool _albumsOpen = false;

  /// Сетка слушает это вместо setState листа: новая страница не перестраивает
  /// стекло, шапку и подпись (25.11.2026).
  final ValueNotifier<int> _galleryTick = ValueNotifier<int>(0);

  /// Первая страница «Недавних» с прошлого открытия — сетка сразу, обновление
  /// следом. Только в памяти процесса.
  static AssetPathEntity? _lastRecentAlbum;
  static List<AssetEntity> _lastRecentPage = const <AssetEntity>[];

  /// Номер загрузки: ответ прежнего альбома не перебивает новый.
  int _loadSeq = 0;
  Timer? _albumsTimer;
  Timer? _cameraTimer;
  Animation<double>? _routeAnimation;

  /// Выбранные снимки по id — переживают смену альбома (в сетке другого
  /// альбома их может не быть), отправка идёт в порядке выбора.
  final Map<String, AssetEntity> _selectedAssetById = {};

  // Меню отправки (долгое нажатие): общие для пачки.
  bool _flowCaptionAbove = false;
  bool _flowGroup = true;
  bool _flowSpoiler = false;
  bool _flowSilent = false;
  final int? _flowScheduleAtMs = null;
  bool _flowAsFiles = false;

  /// Поддержка спойлера/одноразового у получателей — спрашиваем один раз.
  late final Future<bool> _spoilerOk =
      widget.spoilerSupported?.call() ?? Future<bool>.value(false);

  void _explainSpoilerUnavailable() => _showInlineMessage(
    wave1Text(context, ru: 'Недоступно в этом чате: нужна новая версия Secretly на телефонах получателя (в группах пока нет)', en: 'Not available in this chat: the recipient’s phones need the new Secretly (not in groups yet)', uk: 'Недоступно в цьому чаті: потрібна нова версія Secretly на телефонах одержувача (у групах поки ні)', es: 'No disponible aquí: el destinatario necesita la nueva versión de Secretly en sus teléfonos (aún no en grupos)', pt: 'Indisponível aqui: o destinatário precisa da nova versão do Secretly nos telemóveis (ainda não em grupos)', ptBr: 'Indisponível aqui: o destinatário precisa da nova versão do Secretly nos celulares (ainda não em grupos)', fr: 'Indisponible ici : le destinataire doit avoir la nouvelle version de Secretly sur ses téléphones (pas encore en groupe)', de: 'Hier nicht verfügbar: Empfänger braucht die neue Secretly-Version auf dem Handy (noch nicht in Gruppen)'),
  );

  ChatAttachmentSendOptions _flowOptions() => ChatAttachmentSendOptions(
    captionAbove: _flowCaptionAbove,
    group: _flowGroup,
    spoiler: _flowSpoiler,
    silent: _flowSilent,
    scheduleAtMs: _flowScheduleAtMs,
  );

  final Map<String, _AssetSendOpts> _sendOptsByAssetId = {};
  _AssetSendOpts _optsFor(String id) =>
      _sendOptsByAssetId.putIfAbsent(id, _AssetSendOpts.new);

  /// Подпись, набранная прямо в листе (к пачке — у первого снимка).
  final TextEditingController _sheetCaption = TextEditingController();

  bool _toggleAssetSelection(AssetEntity asset) {
    if (_selectedPhotoIds.remove(asset.id)) {
      _selectedAssetById.remove(asset.id);
      setState(() {});
      return true;
    }
    if (_selectedPhotoIds.length >= kSendFlowMaxSelection) {
      _showInlineMessage(
        wave1Text(
          context,
          ru: 'Можно выбрать до $kSendFlowMaxSelection медиа',
          en: 'You can select up to $kSendFlowMaxSelection items',
          uk: 'Можна вибрати до $kSendFlowMaxSelection медіа',
          es: 'Puedes elegir hasta $kSendFlowMaxSelection elementos',
          pt: 'Pode escolher até $kSendFlowMaxSelection itens',
          ptBr: 'Você pode escolher até $kSendFlowMaxSelection itens',
          fr: 'Vous pouvez choisir jusqu’à $kSendFlowMaxSelection éléments',
          de: 'Du kannst bis zu $kSendFlowMaxSelection Medien auswählen',
        ),
      );
      return false;
    }
    _selectedPhotoIds.add(asset.id);
    _selectedAssetById[asset.id] = asset;
    setState(() {});
    return true;
  }

  final Set<String> _selectedPhotoIds = <String>{};

  // MULTI-PHOTO CAPTIONS (2026-07-17): the fullscreen send editor writes each
  // asset's caption here (keyed by AssetEntity.id), so a caption typed on one
  // photo survives switching/backing out and is applied to THAT photo when the
  // whole selection is sent — previously the multi-send path carried no
  // captions at all ("коментарии не становятся при нескольких фото").
  final Map<String, String> _captionByAssetId = <String, String>{};

  // MULTI-PHOTO EDITS (2026-07-17): the send editor writes an asset's edited
  // (rotated/cropped/drawn) file path here so a whole-selection send uses the
  // EDITED file for that photo instead of re-resolving the original gallery
  // file (which silently discarded the edits).
  final Map<String, String> _editedPathByAssetId = <String, String>{};

  _AttachmentPickerTab _currentTab = _AttachmentPickerTab.photo;
  ScrollController? _draggableScrollController;
  CameraController? _cameraController;
  AssetPathEntity? _galleryAlbum;
  final int _preferredCameraIndex = 0;
  int _galleryNextPage = 0;
  bool _galleryLoading = true;
  bool _galleryLoadingMore = false;
  bool _galleryHasMore = true;
  bool _galleryPermissionDenied = false;
  bool _cameraInitializing = false;
  bool _cameraUnavailable = false;
  bool _busy = false;
  bool _overlayHidden = false;

  /// When set, the photo grid is being used as the «Галерея» source of the
  /// FILE tab: the confirmed selection is sent through the generic-file path
  /// (uncompressed) instead of the compressing photo pipeline.
  bool _sendPhotosAsFiles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_lastRecentPage.isNotEmpty && (Platform.isAndroid || Platform.isIOS)) {
      _galleryAlbum = _lastRecentAlbum;
      _galleryAssets.addAll(_lastRecentPage);
      _galleryNextPage = 1;
      _galleryLoading = false;
    }
    PickerProbe.opened(fromMemory: _lastRecentPage.isNotEmpty);
    if (kFrameStats) {
      GalleryThumbs.instance.onFastIdle = () => PickerProbe.mark('thumbs');
    }
    unawaited(_loadGalleryAssets());
    // Камера — когда лист уже выехал: её запуск и живой кадр в сетке не
    // делят с ним первые кадры (25.11.2026).
    _cameraInitializing = _supportsLiveCamera;
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchSheetSettled());
  }

  void _watchSheetSettled() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _scheduleCamera();
      return;
    }
    _routeAnimation = animation..addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _scheduleCamera();
  }

  void _scheduleCamera() {
    widget.onSettled?.call();
    _cameraTimer = Timer(const Duration(milliseconds: 250), () {
      // Системная камера или выбор уже идут — камерой управляет тот путь.
      if (!mounted || _busy || _cameraController != null) return;
      final life = WidgetsBinding.instance.lifecycleState;
      if (life != null && life != AppLifecycleState.resumed) {
        // Ушли в фон раньше — откроем по возвращении.
        _cameraReleasedForBackground = true;
        return;
      }
      unawaited(_initializeCameraPreview());
    });
  }

  /// Камеру отпустили, уйдя в фон, — вернуть её при возвращении.
  bool _cameraReleasedForBackground = false;

  // 🔴 Play Vitals п. 1/12 (15.11.2026): сбой `FlutterJNI.ensureAttachedToNative`
  // — кадр камеры приходит в движок, уже отсоединённый от окна. Как велит
  // руководство плагина camera: в фоне камеру отпускаем, на переднем плане —
  // открываем снова. Пока идёт системная камера или выбор (`_busy`), камерой
  // управляет тот путь.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_busy) return;
      final controller = _cameraController;
      if (controller == null) return;
      _cameraController = null;
      _cameraReleasedForBackground = true;
      if (mounted) setState(() {});
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed &&
        _cameraReleasedForBackground) {
      _cameraReleasedForBackground = false;
      if (mounted) unawaited(_initializeCameraPreview());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _albumsTimer?.cancel();
    _cameraTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    final cameraController = _cameraController;
    _cameraController = null;
    if (cameraController != null) {
      unawaited(cameraController.dispose());
    }
    _galleryTick.dispose();
    _sheetCaption.dispose();
    super.dispose();
  }

  bool get _supportsLiveCamera => Platform.isAndroid || Platform.isIOS;

  String _t(String ru, String en) => wave1Text(context, ru: ru, en: en);

  String _fileExtension(String path) {
    return p.extension(path).replaceFirst('.', '').trim().toLowerCase();
  }

  bool _isAudioPath(String path) =>
      _audioExtensions.contains(_fileExtension(path));

  String? _mimeForPath(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.opus')) return 'audio/opus';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wma')) return 'audio/x-ms-wma';
    if (lower.endsWith('.amr')) return 'audio/amr';
    return null;
  }

  ChatAttachmentPickerMediaKind _galleryMediaKind(AssetEntity asset) {
    return asset.type == AssetType.video
        ? ChatAttachmentPickerMediaKind.video
        : ChatAttachmentPickerMediaKind.image;
  }

  Future<ChatAttachmentPickerMediaItem?> _resolveGalleryMediaItem(
    AssetEntity asset, {
    String caption = '',
    String? editedPath,
  }) async {
    final opts = _optsFor(asset.id);
    final photoSide = opts.hd ? null : kPhotoSendMaxSideSd;
    // An edited (rotated/cropped/drawn) file replaces the original — always a
    // baked JPEG image.
    if (editedPath != null && editedPath.isNotEmpty) {
      final edited = File(editedPath);
      if (await edited.exists()) {
        return ChatAttachmentPickerMediaItem(
          path: editedPath,
          kind: ChatAttachmentPickerMediaKind.image,
          mime: 'image/jpeg',
          caption: caption,
          photoMaxSide: photoSide,
          viewOnce: opts.once,
        );
      }
    }
    final file = await asset.file;
    if (file == null || !await file.exists()) return null;
    final isVideo = asset.type == AssetType.video;
    return ChatAttachmentPickerMediaItem(
      path: file.path,
      kind: _galleryMediaKind(asset),
      mime: _mimeForPath(file.path),
      caption: caption,
      photoMaxSide: isVideo ? null : photoSide,
      videoMaxSide:
          isVideo ? VideoCompressor.maxSideForQuality(opts.videoQuality) : null,
      muteVideo: isVideo && opts.mute,
      viewOnce: opts.once,
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!mounted || notification.depth != 0) return false;
    // Only the vertical gallery/list scroll should hide the overlay chips.
    // Ignore the chips' own horizontal scroll (otherwise swiping the bar makes
    // it slide away downward).
    if (notification.metrics.axis != Axis.vertical) return false;
    final hidden = notification.metrics.pixels > 24;
    if (hidden != _overlayHidden) {
      setState(() => _overlayHidden = hidden);
    }
    if (_currentTab == _AttachmentPickerTab.photo &&
        notification.metrics.extentAfter < _galleryPrefetchExtent) {
      unawaited(_loadMoreGalleryAssets());
    }
    return false;
  }

  bool _isGalleryMediaAsset(AssetEntity asset) {
    return asset.type == AssetType.image || asset.type == AssetType.video;
  }

  Future<bool> _requestGalleryPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final permission = Platform.isAndroid
        ? await PhotoManager.requestPermissionExtend(
            requestOption: const PermissionRequestOption(
              androidPermission: AndroidPermission(
                type: RequestType.common,
                mediaLocation: false,
              ),
            ),
          )
        : await PhotoManager.requestPermissionExtend();
    return permission.isAuth;
  }

  Future<void> _loadGalleryAssets() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (!mounted) return;
      setState(() {
        _galleryLoading = false;
      });
      return;
    }

    final seq = ++_loadSeq;
    final filter = _galleryFilter;
    // Первая страница из памяти уже на экране — крутилка не нужна.
    final shown =
        filter == _GalleryFilter.recent &&
        _galleryAssets.isNotEmpty &&
        identical(_galleryAlbum, _lastRecentAlbum);
    if (mounted && !shown) {
      setState(() {
        _galleryLoading = true;
        _galleryPermissionDenied = false;
      });
    }

    try {
      final granted = await _requestGalleryPermission();
      if (!mounted || seq != _loadSeq) return;
      if (!granted) {
        _lastRecentAlbum = null;
        _lastRecentPage = const <AssetEntity>[];
        setState(() {
          _galleryAssets.clear();
          _galleryLoading = false;
          _galleryPermissionDenied = true;
        });
        return;
      }

      // Только «Недавние»: остальные альбомы и счётчики — потом, показ их не
      // ждёт (раньше до сетки шло до семи запросов к фототеке).
      if (!_filterPaths.containsKey(_GalleryFilter.recent)) {
        final all = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: true,
          onlyAll: true,
          filterOption: _galleryOrder,
        );
        if (all.isNotEmpty) _filterPaths[_GalleryFilter.recent] = all.first;
      }
      if (!mounted || seq != _loadSeq) return;
      final album =
          _filterPaths[filter] ?? _filterPaths[_GalleryFilter.recent];
      if (album == null) {
        setState(() {
          _galleryAlbum = null;
          _galleryAssets.clear();
          _galleryNextPage = 0;
          _galleryHasMore = false;
          _galleryLoadingMore = false;
          _galleryLoading = false;
          _galleryPermissionDenied = false;
        });
        return;
      }

      final firstPage = await album.getAssetListPaged(
        page: 0,
        size: _galleryPageSize,
      );
      final mediaAssets = firstPage
          .where(_isGalleryMediaAsset)
          .toList(growable: false);
      prepareGalleryThumbs(mediaAssets);

      if (!mounted || seq != _loadSeq) return;
      if (shown) {
        _refreshShownPage(album, mediaAssets, firstPage.length);
      } else {
        setState(() {
          _galleryAlbum = album;
          _galleryAssets
            ..clear()
            ..addAll(mediaAssets);
          _galleryNextPage = 1;
          _galleryHasMore = firstPage.length >= _galleryPageSize;
          _galleryLoadingMore = false;
          _galleryLoading = false;
          _galleryPermissionDenied = false;
        });
      }
      if (filter == _GalleryFilter.recent) {
        _lastRecentAlbum = album;
        _lastRecentPage = mediaAssets;
      }
      PickerProbe.mark('list');
      _scheduleAlbums();
    } catch (_) {
      // Страница из памяти уже на экране — сбой обновления её не стирает.
      if (!mounted || seq != _loadSeq || shown) return;
      setState(() {
        _galleryLoading = false;
        _galleryLoadingMore = false;
        _galleryPermissionDenied = true;
      });
    }
  }

  /// 🔴 ЗАНОВО НА КАЖДЫЙ ЗАПРОС, БЕЗ ГРАНИЦЫ ПО ДАТЕ (26.11.2026).
  ///
  /// Был один общий набор на всё время работы приложения, а у photo_manager
  /// условие даты по умолчанию — «не позже, чем СЕЙЧАС» на момент создания.
  /// Всё снятое, скачанное или заскриншоченное после первого открытия скрепки
  /// в галерею не попадало, пока приложение не перезапустят.
  static FilterOptionGroup get _galleryOrder => FilterOptionGroup(
    createTimeCond: DateTimeCond.def().copyWith(ignore: true),
    orders: const <OrderOption>[
      OrderOption(type: OrderOptionType.createDate, asc: false),
    ],
  );

  /// Страница из памяти уже показана, пришла свежая: новое — наверх,
  /// удалённое — вон, подгруженное ниже остаётся. Ничего не изменилось —
  /// сетку не трогаем.
  void _refreshShownPage(
    AssetPathEntity album,
    List<AssetEntity> fresh,
    int pageLength,
  ) {
    final merged = mergeGalleryPages(
      shown: _galleryAssets,
      oldFirst: _lastRecentPage,
      fresh: fresh,
    );
    _galleryAlbum = album;
    if (_galleryNextPage <= 1) _galleryHasMore = pageLength >= _galleryPageSize;
    if (merged != null) {
      _galleryAssets
        ..clear()
        ..addAll(merged);
      _galleryTick.value++;
    }
  }

  /// Список альбомов — когда лист выехал и первые миниатюры уже запрошены.
  void _scheduleAlbums() {
    if (_filtersResolved) return;
    _filtersResolved = true;
    _albumsTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) unawaited(_resolveFilterPaths());
    });
  }

  /// Альбомы для выпадающего списка: «Недавние» (всё), «Видео», а на
  /// iPhone «Избранное» и «Снимки экрана» — системные альбомы; на Android
  /// снимки экрана — папка Screenshots. Нет альбома — нет пункта.
  Future<void> _resolveFilterPaths() async {
    try {
      final videos = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        hasAll: true,
        onlyAll: true,
        filterOption: _galleryOrder,
      );
      if (videos.isNotEmpty) _filterPaths[_GalleryFilter.videos] = videos.first;
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: false,
        filterOption: _galleryOrder,
      );
      for (final a in albums) {
        final sub = a.albumTypeEx?.darwin?.subtype;
        final name = a.name.toLowerCase();
        if (sub == PMDarwinAssetCollectionSubtype.smartAlbumFavorites) {
          _filterPaths[_GalleryFilter.favorites] = a;
        } else if (sub == PMDarwinAssetCollectionSubtype.smartAlbumScreenshots ||
            (Platform.isAndroid &&
                (name == 'screenshots' || name.contains('снимки экрана')))) {
          _filterPaths.putIfAbsent(_GalleryFilter.screenshots, () => a);
        }
      }
    } catch (_) {
      // Без списка альбомов — только «Недавние», как раньше.
    }
    if (mounted) setState(() {});
  }

  bool _countsLoading = false;

  /// Сколько снимков в альбомах — только когда открыли их список: на большой
  /// фототеке каждый подсчёт — выборка всего альбома.
  Future<void> _loadFilterCounts() async {
    if (_countsLoading) return;
    _countsLoading = true;
    try {
      for (final e in List.of(_filterPaths.entries)) {
        if (_filterCounts.containsKey(e.key)) continue;
        final n = await e.value.assetCountAsync;
        if (!mounted) return;
        setState(() => _filterCounts[e.key] = n);
      }
    } catch (_) {
      // Без счётчиков.
    } finally {
      _countsLoading = false;
    }
  }

  Future<void> _selectGalleryFilter(_GalleryFilter f) async {
    setState(() {
      _albumsOpen = false;
      _galleryFilter = f;
    });
    await _loadGalleryAssets();
    final c = _draggableScrollController;
    if (c != null && c.hasClients) c.jumpTo(0);
  }

  Future<void> _loadMoreGalleryAssets() async {
    final album = _galleryAlbum;
    if (album == null ||
        _galleryLoading ||
        _galleryLoadingMore ||
        !_galleryHasMore) {
      return;
    }

    final page = _galleryNextPage;
    final seq = _loadSeq;
    _galleryLoadingMore = true;

    try {
      final nextPage = await album.getAssetListPaged(
        page: page,
        size: _galleryPageSize,
      );
      final mediaAssets = nextPage
          .where(_isGalleryMediaAsset)
          .toList(growable: false);
      if (!mounted) return;
      _galleryLoadingMore = false;
      // Пока грузили, открыли другой альбом — эта страница не его.
      if (!identical(album, _galleryAlbum) && seq != _loadSeq) return;
      prepareGalleryThumbs(mediaAssets);
      final knownIds = _galleryAssets.map((asset) => asset.id).toSet();
      for (final asset in mediaAssets) {
        if (knownIds.add(asset.id)) {
          _galleryAssets.add(asset);
        }
      }
      _galleryNextPage = page + 1;
      _galleryHasMore = nextPage.length >= _galleryPageSize;
      _galleryTick.value++;
    } catch (_) {
      _galleryLoadingMore = false;
    }
  }

  Future<void> _initializeCameraPreview() async {
    if (!_supportsLiveCamera) {
      if (!mounted) return;
      setState(() {
        _cameraUnavailable = true;
        _cameraInitializing = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _cameraInitializing = true;
        _cameraUnavailable = false;
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraInitializing = false;
          _cameraUnavailable = true;
        });
        return;
      }

      final nextIndex = _preferredCameraIndex.clamp(0, cameras.length - 1);
      final controller = CameraController(
        cameras[nextIndex],
        ResolutionPreset.medium,
        // Audio enabled so hold-to-record captures sound with the video.
        enableAudio: true,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previous = _cameraController;
      setState(() {
        _cameraController = controller;
        _cameraInitializing = false;
        _cameraUnavailable = false;
      });
      if (previous != null) {
        unawaited(previous.dispose());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _cameraUnavailable = true;
      });
    }
  }

  Future<void> _openSystemCamera() async {
    if (_busy) return;
    setState(() => _busy = true);
    final previous = _cameraController;
    _cameraController = null;
    if (previous != null) {
      await previous.dispose();
    }
    if (mounted) {
      setState(() {
        _cameraInitializing = false;
      });
    }

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (!mounted || picked == null) return;
      Navigator.of(context).pop(
        ChatAttachmentPickerResult.photos(<ChatAttachmentPickerMediaItem>[
          ChatAttachmentPickerMediaItem(
            path: picked.path,
            kind: ChatAttachmentPickerMediaKind.image,
            mime: _mimeForPath(picked.path),
          ),
        ]),
      );
    } catch (_) {
      if (mounted) {
        _showInlineMessage(
          _t('Не удалось открыть камеру', 'Failed to open camera'),
        );
      }
    } finally {
      if (mounted) {
        unawaited(_initializeCameraPreview());
        setState(() => _busy = false);
      }
    }
  }

  /// Tap on the camera tile → OPEN the full-screen in-app camera. The page lets
  /// the user take a photo (tap shutter) or record video (hold shutter, or flip
  /// the Фото/Видео toggle). Returns the captured media item which we forward to
  /// the caller. Falls back to the system camera when the live camera isn't
  /// available on this device.
  Future<void> _openInAppCamera() async {
    if (_busy) return;
    if (!_supportsLiveCamera) {
      await _openSystemCamera();
      return;
    }
    setState(() => _busy = true);

    // Release the inline preview controller so the full-screen page owns the
    // camera exclusively (two CameraControllers can't share one device).
    final previous = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() => _cameraInitializing = false);
    }
    if (previous != null) {
      await previous.dispose();
    }

    try {
      List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (_) {
        cameras = const <CameraDescription>[];
      }
      if (cameras.isEmpty) {
        await _openSystemCamera();
        return;
      }
      if (!mounted) return;
      final result = await Navigator.of(context).push<ChatAttachmentPickerMediaItem>(
        MaterialPageRoute<ChatAttachmentPickerMediaItem>(
          fullscreenDialog: true,
          builder: (_) => _InAppCameraPage(
            cameras: cameras,
            initialCameraIndex:
                _preferredCameraIndex.clamp(0, cameras.length - 1),
            mimeForPath: _mimeForPath,
            localize: (ru, en) => wave1Text(context, ru: ru, en: en),
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(
          ChatAttachmentPickerResult.photos(<ChatAttachmentPickerMediaItem>[
            result,
          ]),
        );
        return;
      }
    } catch (_) {
      if (mounted) {
        _showInlineMessage(
          _t('Не удалось открыть камеру', 'Failed to open camera'),
        );
      }
    } finally {
      if (mounted) {
        // Camera dismissed without capture — bring the inline preview back.
        unawaited(_initializeCameraPreview());
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmPhotoSelection() async {
    if (_selectedPhotoIds.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      // В порядке выбора (номера на плитках), а не в порядке галереи; снимки
      // из другого альбома тоже уходят.
      final selected = <AssetEntity>[
        for (final id in _selectedPhotoIds)
          if (_selectedAssetById[id] ??
                  _galleryAssets.where((a) => a.id == id).firstOrNull
              case final a?)
            a,
      ];
      final sheetCaption = _sheetCaption.text.trim();
      final mediaItems = <ChatAttachmentPickerMediaItem>[];
      for (var i = 0; i < selected.length; i++) {
        final asset = selected[i];
        var caption = _captionByAssetId[asset.id]?.trim() ?? '';
        // Подпись из листа — подпись пачки: у первого снимка.
        if (i == 0 && sheetCaption.isNotEmpty && caption.isEmpty) {
          caption = sheetCaption;
        }
        final mediaItem = await _resolveGalleryMediaItem(
          asset,
          caption: caption,
          editedPath: _editedPathByAssetId[asset.id],
        );
        if (mediaItem == null) continue;
        mediaItems.add(mediaItem);
      }
      if (!mounted || mediaItems.isEmpty) return;
      Navigator.of(context).pop(
        _sendPhotosAsFiles || _flowAsFiles
            ? ChatAttachmentPickerResult.filesFromGallery(mediaItems)
            : ChatAttachmentPickerResult.photos(
                mediaItems,
                options: _flowOptions(),
              ),
      );
    } finally {
      // Разовые действия меню — только для этой отправки.
      _flowAsFiles = false;
      _flowSilent = false;
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickFromSystemPicker({required bool audioOnly}) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: audioOnly ? FileType.custom : FileType.any,
        allowedExtensions: audioOnly
            ? _audioExtensions.toList(growable: false)
            : null,
        // О9 (разбор медиа 15.11.2026): документы — сразу несколько, как на
        // ПК; музыка — по одной, как была.
        allowMultiple: !audioOnly,
        withData: false,
      );
      if (!audioOnly && picked != null && picked.files.length > 1) {
        await _finishMultiFilePick(picked.files);
        return;
      }
      final file = picked?.files.isEmpty ?? true ? null : picked!.files.first;
      final path = file?.path?.trim();
      if (!mounted || file == null) return;
      if (path == null || path.isEmpty) {
        _showInlineMessage(
          _t(
            'Не удалось получить путь к файлу',
            'Could not resolve the selected file path',
          ),
        );
        return;
      }

      if (!await File(path).exists()) {
        _showInlineMessage(
          _t('Файл уже недоступен', 'The file is no longer available'),
        );
        return;
      }

      if (audioOnly) {
        if (!_isAudioPath(path)) {
          _showInlineMessage(_t('Выберите аудиофайл', 'Choose an audio file'));
          return;
        }
      } else {
        if (_isAudioPath(path)) {
          _showInlineMessage(
            _t(
              'Для треков откройте вкладку Музыка',
              'Use the Music tab for audio files',
            ),
          );
          return;
        }
        // Images/videos are allowed here: Telegram-style, the FILE tab can send
        // photos/videos AS FILES (uncompressed) via the generic-file path.
      }

      if (!mounted) return;
      // Remember this pick so it appears under «Недавние» next time the
      // music/files tab is opened (durable copy + index, best-effort).
      unawaited(
        RecentAttachmentsStore.instance.record(
          kind: audioOnly ? 'audio' : 'file',
          sourcePath: path,
          fileName: file.name,
          sizeBytes: file.size,
        ),
      );
      Navigator.of(context).pop(
        audioOnly
            ? ChatAttachmentPickerResult.audio(path)
            : ChatAttachmentPickerResult.file(path, fileName: file.name),
      );
    } catch (_) {
      if (mounted) {
        _showInlineMessage(
          audioOnly
              ? _t(
                  'Не удалось выбрать аудиофайл',
                  'Failed to pick the audio file',
                )
              : _t('Не удалось выбрать файл', 'Failed to pick the file'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Several documents from the system picker (О9). Same checks as for one
  /// file; a file that fails them is skipped with the same message, the rest
  /// still go. Each one is sent as its own message.
  Future<void> _finishMultiFilePick(List<PlatformFile> files) async {
    final ok = <({String path, String? name})>[];
    final accepted = <PlatformFile>[];
    String? skippedReason;
    for (final file in files) {
      final path = file.path?.trim();
      if (path == null || path.isEmpty) {
        skippedReason ??= _t(
          'Не удалось получить путь к файлу',
          'Could not resolve the selected file path',
        );
        continue;
      }
      if (!await File(path).exists()) {
        skippedReason ??= _t(
          'Файл уже недоступен',
          'The file is no longer available',
        );
        continue;
      }
      if (_isAudioPath(path)) {
        skippedReason ??= _t(
          'Для треков откройте вкладку Музыка',
          'Use the Music tab for audio files',
        );
        continue;
      }
      ok.add((path: path, name: file.name));
      accepted.add(file);
    }
    if (!mounted) return;
    if (ok.isEmpty) {
      if (skippedReason != null) _showInlineMessage(skippedReason);
      return;
    }
    for (final f in accepted) {
      unawaited(
        RecentAttachmentsStore.instance.record(
          kind: 'file',
          sourcePath: f.path!.trim(),
          fileName: f.name,
          sizeBytes: f.size,
        ),
      );
    }
    Navigator.of(context).pop(ChatAttachmentPickerResult.files(ok));
  }

  Future<void> _pickFileFromSystem() {
    return _pickFromSystemPicker(audioOnly: false);
  }

  Future<void> _pickMusicFromSystem() {
    return _pickFromSystemPicker(audioOnly: true);
  }

  void _switchTab(_AttachmentPickerTab nextTab) {
    if (_currentTab == nextTab) return;
    setState(() {
      _currentTab = nextTab;
      _overlayHidden = false;
      // Tapping a tab chip always leaves the «send-as-files» gallery mode: the
      // Photo chip means normal (compressed) photos again.
      _sendPhotosAsFiles = false;
      if (nextTab != _AttachmentPickerTab.photo) {
        _selectedPhotoIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _draggableScrollController;
      if (controller != null && controller.hasClients) {
        controller.jumpTo(0);
      }
    });
  }

  // Opens the same multi-select photo grid the Photo tab uses, but marks the
  // selection so it is sent through the generic-file path (uncompressed). Used
  // by the «Галерея» row on the FILE tab.
  void _openGalleryAsFiles() {
    setState(() {
      _currentTab = _AttachmentPickerTab.photo;
      _overlayHidden = false;
      _sendPhotosAsFiles = true;
      _selectedPhotoIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _draggableScrollController;
      if (controller != null && controller.hasClients) {
        controller.jumpTo(0);
      }
    });
  }

  void _showInlineMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visuals = theme.extension<ChatVisualsThemeExtension>();
    final actionTop = visuals?.actionTop ?? colors.primary;
    final actionBottom = visuals?.actionBottom ?? colors.secondary;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final tabChipsBottom = safeBottom + 16;

    // Закрытие с выбранным — только после «Отменить выбор?».
    return PopScope(
      canPop: _selectedPhotoIds.isEmpty && _sheetCaption.text.trim().isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_albumsOpen) {
          setState(() => _albumsOpen = false);
          return;
        }
        final discard = await _confirmDiscardSelection();
        if (!discard || !context.mounted) return;
        {
          setState(() {
            _selectedPhotoIds.clear();
            _selectedAssetById.clear();
            _sheetCaption.clear();
          });
          Navigator.of(context).pop();
        }
      },
      child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.26,
      maxChildSize: 0.94,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        _draggableScrollController = scrollController;
        // Во всю ширину и до низа экрана: поверхность уходит ЗА системную
        // панель, а внутренний SafeArea держит содержимое над ней.
        return SecretlyGlassSheetSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          flushToEdges: true,
          solid: true,
          child: SafeArea(
            top: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildBody(scrollController)),
                  const Positioned(
                    top: 7,
                    left: 0,
                    right: 0,
                    child: Center(child: SecretlyGlassSheetHandle()),
                  ),
                  // Шапка (макет SendFlow): «Отмена» · альбом ▾ · «Выбрано N».
                  Positioned(
                    top: kSheetHeaderTop,
                    left: 10,
                    right: 10,
                    height: kSheetHeaderHeight,
                    child: _buildSheetHeader(),
                  ),
                  if (_albumsOpen && _currentTab == _AttachmentPickerTab.photo)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _albumsOpen = false),
                      ),
                    ),
                  if (_albumsOpen && _currentTab == _AttachmentPickerTab.photo)
                    Positioned(
                      top: kSheetGridTop,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildAlbumsMenu()),
                    ),
                  if (!_selectionBarOn)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: tabChipsBottom,
                    child: IgnorePointer(
                      ignoring: _overlayHidden,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _overlayHidden ? 0 : 1,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 180),
                          curve: Motion.standard,
                          offset: _overlayHidden
                              ? const Offset(0, 0.6)
                              : Offset.zero,
                          // Full-width glass strip; the chips scroll
                          // horizontally inside it when they don't all fit.
                          child: _buildOverlayTabChips(
                            actionTop: actionTop,
                            actionBottom: actionBottom,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Выбрано — вместо вкладок: подпись и кнопка с числом.
                  if (_selectionBarOn)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: safeBottom + 10,
                      child: _buildSelectionCaptionBar(
                        actionTop: actionTop,
                        actionBottom: actionBottom,
                      ),
                    ),
                  if (_busy)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: SecretlySpinner(
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey<_AttachmentPickerTab>(_currentTab),
        child: switch (_currentTab) {
          _AttachmentPickerTab.photo => _buildPhotoTab(scrollController),
          _AttachmentPickerTab.file => _buildFileTab(scrollController),
          _AttachmentPickerTab.music => _buildMusicTab(scrollController),
        },
      ),
    );
  }

  Widget _buildPhotoTab(ScrollController scrollController) {
    if (_galleryLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: SecretlySpinner(strokeWidth: 2.4),
        ),
      );
    }

    if (_galleryPermissionDenied) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, kSheetGridTop + 8, 14, 110),
        children: <Widget>[
          _buildInlineStateTile(
            icon: AppIcons.photoSolid,
            title: _t('Нужен доступ к галерее', 'Gallery access is required'),
            subtitle: _t(
              'Без доступа к фото и видео сетка не загрузится.',
              'Without photo and video access the grid cannot be loaded.',
            ),
            actionLabel: _t('Открыть настройки', 'Open settings'),
            onAction: PhotoManager.openSetting,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900 ? 5 : (width >= 650 ? 4 : 3);
        return ValueListenableBuilder<int>(
          valueListenable: _galleryTick,
          builder: (context, _, _) => GridView.builder(
          controller: scrollController,
          // Сверху — ручка и название альбома.
          padding: const EdgeInsets.fromLTRB(2, kSheetGridTop, 2, 114),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 1.5,
            crossAxisSpacing: 1.5,
            childAspectRatio: 1,
          ),
          itemCount: _galleryAssets.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildCameraTile();
            }
            final assetIndex = index - 1;
            if (_galleryHasMore &&
                !_galleryLoadingMore &&
                _galleryAssets.length - assetIndex <= 18) {
              unawaited(_loadMoreGalleryAssets());
            }
            return _buildPhotoTile(_galleryAssets[index - 1]);
          },
          ),
        );
      },
    );
  }

  // Cached per-kind recents futures so switching tabs / setState doesn't reload
  // (and flicker) the «Недавние» list within a single sheet session.
  final Map<String, Future<List<RecentAttachment>>> _recentsFutures =
      <String, Future<List<RecentAttachment>>>{};
  Future<List<RecentAttachment>> _recentsFor(String kind) =>
      _recentsFutures.putIfAbsent(
        kind,
        () => RecentAttachmentsStore.instance.list(kind),
      );

  Widget _buildFileTab(ScrollController scrollController) {
    return _buildActionTabWithRecents(
      scrollController: scrollController,
      kind: 'file',
      icon: AppIcons.fileOutline,
      title: _t('Выбрать файл с устройства', 'Choose a file from your device'),
      subtitle: _t(
        'Откроется системный файловый picker без полного доступа к памяти.',
        'The system file picker opens without requesting full storage access.',
      ),
      actionLabel: _t('Открыть файлы', 'Browse files'),
      onAction: _pickFileFromSystem,
      // Telegram-style: the FILE tab also offers a Gallery source that sends
      // photos/videos uncompressed (as files).
      showGalleryAsFiles: true,
    );
  }

  Widget _buildMusicTab(ScrollController scrollController) {
    return _buildActionTabWithRecents(
      scrollController: scrollController,
      kind: 'audio',
      icon: AppIcons.musicNote,
      title: _t('Выбрать трек с устройства', 'Choose a track from your device'),
      subtitle: _t(
        'Откроется системный picker только для аудиофайлов.',
        'The system picker opens only for audio files.',
      ),
      actionLabel: _t('Открыть музыку', 'Browse music'),
      onAction: _pickMusicFromSystem,
    );
  }

  // When recents exist: a compact browse button followed by the «Недавние»
  // list. When empty: the original full-height browse hero.
  Widget _buildActionTabWithRecents({
    required ScrollController scrollController,
    required String kind,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required Future<void> Function() onAction,
    bool showGalleryAsFiles = false,
  }) {
    return FutureBuilder<List<RecentAttachment>>(
      future: _recentsFor(kind),
      builder: (context, snapshot) {
        final recents = snapshot.data ?? const <RecentAttachment>[];
        if (recents.isEmpty) {
          return _buildPickerActionTab(
            scrollController: scrollController,
            icon: icon,
            title: title,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onAction: onAction,
            showGalleryAsFiles: showGalleryAsFiles,
          );
        }
        final cs = Theme.of(context).colorScheme;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(10, kSheetListTop, 10, 114),
          children: <Widget>[
            if (showGalleryAsFiles) _buildGalleryAsFilesTile(),
            _buildCompactBrowseTile(
              icon: icon,
              label: actionLabel,
              onAction: onAction,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                _t('Недавние', 'Recent'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final r in recents) _buildRecentAttachmentTile(r, kind),
          ],
        );
      },
    );
  }

  Widget _buildCompactBrowseTile({
    required IconData icon,
    required String label,
    required Future<void> Function() onAction,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : () => onAction(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(AdaptiveIcons.add_rounded, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  // Telegram-style «Галерея» entry on the FILE tab: opens the multi-photo grid
  // and sends the picked images/videos AS FILES (no compression).
  Widget _buildGalleryAsFilesTile() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = wave1Text(
      context,
      ru: 'Галерея',
      en: 'Gallery',
      uk: 'Галерея',
      es: 'Galería',
      pt: 'Galeria',
      ptBr: 'Galeria',
      fr: 'Galerie',
      de: 'Galerie',
    );
    final subtitle = wave1Text(
      context,
      ru: 'отправить изображения без сжатия',
      en: 'send images without compression',
      uk: 'надіслати зображення без стиснення',
      es: 'enviar imágenes sin compresión',
      pt: 'enviar imagens sem compressão',
      ptBr: 'enviar imagens sem compressão',
      fr: 'envoyer des images sans compression',
      de: 'Bilder ohne Komprimierung senden',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.30 : 0.55,
        ),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _openGalleryAsFiles,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(AppIcons.photoSolid, size: 22, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AdaptiveIcons.north_east_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAttachmentTile(RecentAttachment item, String kind) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.30 : 0.55,
        ),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy
              ? null
              : () {
                  if (!mounted) return;
                  Navigator.of(context).pop(
                    kind == 'audio'
                        ? ChatAttachmentPickerResult.audio(item.path)
                        : ChatAttachmentPickerResult.file(
                            item.path,
                            fileName: item.fileName,
                          ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  kind == 'audio' ? AppIcons.musicNote : AppIcons.fileOutline,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_formatRecentSize(item.sizeBytes).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatRecentSize(item.sizeBytes),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AdaptiveIcons.north_east_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRecentSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildPickerActionTab({
    required ScrollController scrollController,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required Future<void> Function() onAction,
    bool showGalleryAsFiles = false,
  }) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(10, kSheetListTop, 10, 114),
      children: <Widget>[
        if (showGalleryAsFiles) _buildGalleryAsFilesTile(),
        _buildInlineStateTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ],
    );
  }

  Widget _buildOverlayTabChips({
    required Color actionTop,
    required Color actionBottom,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = 22.0;
    // Island recipe (matches the chat-header / now-playing islands): matte
    // backdrop blur + soft top→bottom white fill + specular top-edge highlight.
    final fillTop = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.30);
    final fillBottom = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.18);
    final br = BorderRadius.circular(radius);
    return CustomPaint(
      foregroundPainter: _IslandTopHighlightPainter(
        radius: radius,
        color: isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.46),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[fillTop, fillBottom],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Center the chips when they fit (e.g. 3 chips in a 1:1 chat —
                // no lopsided empty slot), and scroll horizontally only when
                // they overflow (e.g. 5 chips in a room).
                final minRowWidth = (constraints.maxWidth - 8).clamp(
                  0.0,
                  double.infinity,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(4),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minRowWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _buildOverlayTabChip(
                          tab: _AttachmentPickerTab.photo,
                          icon: AppIcons.photoSolid,
                          label: context.l10n.photo,
                          actionTop: actionTop,
                          actionBottom: actionBottom,
                        ),
                        const SizedBox(width: 4),
                        _buildOverlayTabChip(
                          tab: _AttachmentPickerTab.file,
                          icon: AppIcons.fileOutline,
                          label: context.l10n.file,
                          actionTop: actionTop,
                          actionBottom: actionBottom,
                        ),
                        const SizedBox(width: 4),
                        _buildOverlayTabChip(
                          tab: _AttachmentPickerTab.music,
                          icon: AppIcons.musicNote,
                          label: context.l10n.music,
                          actionTop: actionTop,
                          actionBottom: actionBottom,
                        ),
                        if (widget.showPoll) ...<Widget>[
                          const SizedBox(width: 4),
                          _buildActionChip(
                            icon: AppIcons.poll,
                            label: _t('Опрос', 'Poll'),
                            actionTop: actionTop,
                            actionBottom: actionBottom,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(ChatAttachmentPickerResult.poll()),
                          ),
                        ],
                        if (widget.showTopic) ...<Widget>[
                          const SizedBox(width: 4),
                          _buildActionChip(
                            icon: AppIcons.topic,
                            label: _t('Тема', 'Topic'),
                            actionTop: actionTop,
                            actionBottom: actionBottom,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(ChatAttachmentPickerResult.topic()),
                          ),
                        ],
                        if (widget.showEvent) ...<Widget>[
                          const SizedBox(width: 4),
                          _buildActionChip(
                            icon: AppIcons.calendar,
                            label: _t('Событие', 'Event'),
                            actionTop: actionTop,
                            actionBottom: actionBottom,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(ChatAttachmentPickerResult.event()),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // A chip that performs an action (e.g. opens the poll composer) instead of
  // switching the in-sheet tab. Styled to match [_buildOverlayTabChip].
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color actionTop,
    required Color actionBottom,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.onSurface.withValues(alpha: 0.04),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: colors.onSurface.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayTabChip({
    required _AttachmentPickerTab tab,
    required IconData icon,
    required String label,
    required Color actionTop,
    required Color actionBottom,
  }) {
    final selected = _currentTab == tab;
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[actionTop, actionBottom],
              )
            : null,
        color: selected ? null : colors.onSurface.withValues(alpha: 0.04),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _switchTab(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : colors.onSurface.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? Colors.white
                        : colors.onSurface.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final GlobalKey _sendButtonKey = GlobalKey(debugLabel: 'sendflow:send');

  bool get _selectionBarOn =>
      _currentTab == _AttachmentPickerTab.photo && _selectedPhotoIds.isNotEmpty;

  String _filterLabel(_GalleryFilter f) => switch (f) {
    _GalleryFilter.recent => wave1Text(context, ru: 'Недавние', en: 'Recents', uk: 'Нещодавні', es: 'Recientes', pt: 'Recentes', ptBr: 'Recentes', fr: 'Récents', de: 'Neueste'),
    _GalleryFilter.favorites => wave1Text(context, ru: 'Избранное', en: 'Favorites', uk: 'Обране', es: 'Favoritos', pt: 'Favoritos', ptBr: 'Favoritos', fr: 'Favoris', de: 'Favoriten'),
    _GalleryFilter.videos => wave1Text(context, ru: 'Видео', en: 'Videos', uk: 'Відео', es: 'Vídeos', pt: 'Vídeos', ptBr: 'Vídeos', fr: 'Vidéos', de: 'Videos'),
    _GalleryFilter.screenshots => wave1Text(context, ru: 'Скриншоты', en: 'Screenshots', uk: 'Знімки екрана', es: 'Capturas', pt: 'Capturas de ecrã', ptBr: 'Capturas de tela', fr: 'Captures', de: 'Bildschirmfotos'),
  };

  IconData _filterIcon(_GalleryFilter f) => switch (f) {
    _GalleryFilter.recent => Icons.photo_library_outlined,
    _GalleryFilter.favorites => Icons.favorite_border_rounded,
    _GalleryFilter.videos => Icons.videocam_outlined,
    _GalleryFilter.screenshots => Icons.screenshot_outlined,
  };

  Widget _buildSheetHeader() {
    final cs = Theme.of(context).colorScheme;
    final photo = _currentTab == _AttachmentPickerTab.photo;
    final n = _selectedPhotoIds.length;
    final multipleAlbums = _filterPaths.length > 1;
    return Row(
      children: [
        // Кнопки «закрыть» нет (владелец, 25.11.2026): лист закрывают
        // смахиванием, касанием мимо или «назад». Место слева держит название
        // альбома посередине.
        const SizedBox(width: 92),
        Expanded(
          child: photo
              ? Center(
                  child: GestureDetector(
                    key: const ValueKey('sendflow:albums'),
                    behavior: HitTestBehavior.opaque,
                    onTap: multipleAlbums
                        ? () {
                            setState(() => _albumsOpen = !_albumsOpen);
                            if (_albumsOpen) unawaited(_loadFilterCounts());
                          }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _filterLabel(_galleryFilter),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (multipleAlbums)
                          AnimatedRotation(
                            turns: _albumsOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.expand_more_rounded, size: 22, color: cs.onSurface),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(
          width: 92,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: photo && n > 0
                  ? Text(
                      wave1Text(context, ru: 'Выбрано: $n', en: 'Selected: $n', uk: 'Вибрано: $n', es: 'Elegidos: $n', pt: 'Escolhidos: $n', ptBr: 'Selecionados: $n', fr: 'Choisis : $n', de: 'Gewählt: $n'),
                      key: ValueKey('sendflow:count:$n'),
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsMenu() {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        alignment: Alignment.topCenter,
        child: Opacity(opacity: ((v - 0.9) * 10).clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        key: const ValueKey('sendflow:albums-menu'),
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF22303D) : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), blurRadius: 34, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in _GalleryFilter.values)
              if (_filterPaths.containsKey(f))
                InkWell(
                  key: ValueKey('sendflow:album:${f.name}'),
                  onTap: () => unawaited(_selectGalleryFilter(f)),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(_filterIcon(f), size: 20, color: f == _galleryFilter ? cs.primary : cs.onSurface),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _filterLabel(f),
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurface,
                                fontWeight: f == _galleryFilter ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (_filterCounts[f] case final c?)
                            Text('$c', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCaptionBar({
    required Color actionTop,
    required Color actionBottom,
  }) {
    final cs = Theme.of(context).colorScheme;
    final n = _selectedPhotoIds.length;
    return Row(
      children: [
        Expanded(
          // Островок подписи — как поле ввода чата (стекло iPhone / матовое
          // Android), а не тёмная цветная плашка (владелец 24.11.2026).
          child: ComposerDropSurface(
            style: _islandStyle(actionTop, actionBottom),
            radius: BorderRadius.circular(22),
            child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 8),
            alignment: Alignment.centerLeft,
            child: TextField(
              key: const ValueKey('sendflow:sheet-caption'),
              controller: _sheetCaption,
              minLines: 1,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 16, color: cs.onSurface),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: wave1Text(context, ru: 'Добавить подпись…', en: 'Add a caption…', uk: 'Додати підпис…', es: 'Añadir un pie…', pt: 'Adicionar legenda…', ptBr: 'Adicionar legenda…', fr: 'Ajouter une légende…', de: 'Bildunterschrift…'),
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
          ),
        ),
        const SizedBox(width: 8),
        _buildRoundSendButton(count: n, actionTop: actionTop, actionBottom: actionBottom),
      ],
    );
  }

  ComposerDropStyle _islandStyle(Color top, Color bottom) => ComposerDropStyle.of(
    context,
    frosted: PanelPrefs.frostedEnabled.value,
    accentTop: top,
    accentBottom: bottom,
    solidFill: opaquePanelFill(context),
  );

  Widget _buildRoundSendButton({
    required int count,
    required Color actionTop,
    required Color actionBottom,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${context.l10n.send} $count',
      child: GestureDetector(
        key: _sendButtonKey,
        onTap: _busy ? null : _confirmPhotoSelection,
        onLongPress: _busy
            ? null
            : () => unawaited(
                _openSendMenu(
                  _sendButtonKey.currentContext ?? context,
                  multi: _selectedPhotoIds.length > 1,
                ).then((go) {
                  if (go && mounted) unawaited(_confirmPhotoSelection());
                }),
              ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [actionTop, actionBottom],
                  ),
                ),
                child: const Icon(AppIcons.send, color: Colors.white, size: 22),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Container(
                    key: ValueKey(count),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: actionTop),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Меню отправки (макет SendFlow, долгое нажатие на «Отправить»).
  /// Возвращает `true`, если выбрали действие «отправить сейчас»; флажки
  /// (подпись над, не группировать) меняются на месте.
  Future<bool> _openSendMenu(BuildContext anchorContext, {required bool multi}) async {
    HapticFeedback.mediumImpact();
    final box = anchorContext.findRenderObject() as RenderBox?;
    final media = MediaQuery.of(context);
    final bottom = box == null
        ? media.padding.bottom + 70
        : media.size.height - box.localToGlobal(Offset.zero).dy + 8;
    final go = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'send-menu',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, _) => _SendFlowMenu(
        bottom: bottom,
        multi: multi,
        captionAbove: _flowCaptionAbove,
        group: _flowGroup,
        spoiler: _flowSpoiler,
        spoilerOk: _spoilerOk,
        onSpoiler: (v) async {
          if (!await _spoilerOk) {
            _explainSpoilerUnavailable();
            return false;
          }
          setState(() => _flowSpoiler = v);
          return true;
        },
        onAsFiles: () {
          // Файлом одноразовое и спойлер не отправить — не снимаем их молча.
          final hidden = _flowSpoiler ||
              _selectedPhotoIds.any((id) => _sendOptsByAssetId[id]?.once ?? false);
          if (hidden) {
            Navigator.of(ctx).pop(false);
            _showInlineMessage(
              wave1Text(context, ru: 'Одноразовое и спойлер файлом не отправить — снимите их или отправьте как медиа', en: 'View-once and spoiler can’t be sent as files — turn them off or send as media', uk: 'Одноразове і спойлер файлом не надіслати — вимкніть їх або надішліть як медіа', es: 'Vista única y spoiler no se envían como archivo: desactívalos o envía como medio', pt: 'Visualização única e spoiler não seguem como ficheiro — desligue-os ou envie como multimédia', ptBr: 'Visualização única e spoiler não vão como arquivo — desative ou envie como mídia', fr: 'Vue unique et spoiler impossibles en fichier : désactivez-les ou envoyez en média', de: 'Einmalansicht und Spoiler gehen nicht als Datei – ausschalten oder als Medien senden'),
            );
            return;
          }
          _flowAsFiles = true;
          Navigator.of(ctx).pop(true);
        },
        onSilent: () {
          _flowSilent = true;
          Navigator.of(ctx).pop(true);
        },
        onCaptionAbove: (v) {
          setState(() => _flowCaptionAbove = v);
          Navigator.of(ctx).pop(false);
        },
        onGroup: (v) => setState(() => _flowGroup = v),
      ),
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: .85, end: 1.0).animate(
            CurvedAnimation(parent: a, curve: const Cubic(.3, 1.35, .5, 1)),
          ),
          alignment: Alignment.bottomRight,
          child: child,
        ),
      ),
    );
    return go ?? false;
  }

  /// «Отменить выбор?» (макет SendFlow): при закрытии с выбранным или с
  /// набранной подписью.
  Future<bool> _confirmDiscardSelection() async {
    final n = _selectedPhotoIds.length;
    final hasCaption = _sheetCaption.text.trim().isNotEmpty;
    if (n == 0 && !hasCaption) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wave1Text(ctx, ru: 'Отменить выбор?', en: 'Discard selection?', uk: 'Скасувати вибір?', es: '¿Descartar la selección?', pt: 'Descartar seleção?', ptBr: 'Descartar seleção?', fr: 'Annuler la sélection ?', de: 'Auswahl verwerfen?')),
        content: Text(
          n > 0
              ? wave1Text(ctx, ru: '$n медиа не будут отправлены, изменения в редакторе пропадут.', en: '$n items won’t be sent and edits will be lost.', uk: '$n медіа не буде надіслано, зміни в редакторі зникнуть.', es: 'No se enviarán $n elementos y se perderán los cambios.', pt: '$n itens não serão enviados e as edições perdem-se.', ptBr: '$n itens não serão enviados e as edições serão perdidas.', fr: '$n éléments ne seront pas envoyés et les retouches seront perdues.', de: '$n Medien werden nicht gesendet, Bearbeitungen gehen verloren.')
              : wave1Text(ctx, ru: 'Подпись не будет отправлена.', en: 'The caption won’t be sent.', uk: 'Підпис не буде надіслано.', es: 'El pie no se enviará.', pt: 'A legenda não será enviada.', ptBr: 'A legenda não será enviada.', fr: 'La légende ne sera pas envoyée.', de: 'Die Bildunterschrift wird nicht gesendet.'),
        ),
        actions: [
          TextButton(
            key: const ValueKey('sendflow:keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(wave1Text(ctx, ru: 'Продолжить', en: 'Keep', uk: 'Продовжити', es: 'Seguir', pt: 'Continuar', ptBr: 'Continuar', fr: 'Continuer', de: 'Weiter')),
          ),
          TextButton(
            key: const ValueKey('sendflow:discard'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(wave1Text(ctx, ru: 'Сбросить', en: 'Discard', uk: 'Скинути', es: 'Descartar', pt: 'Descartar', ptBr: 'Descartar', fr: 'Annuler', de: 'Verwerfen')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _buildCameraTile() {
    final controller = _cameraController;
    final hasPreview = controller != null && controller.value.isInitialized;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        // Tap the tile to OPEN the full camera (photo by default, video on hold
        // or via the in-camera Фото/Видео toggle) — same flow as before, just
        // with video support added inside the camera page.
        onTap: _busy ? null : () => unawaited(_openInAppCamera()),
        child: Ink(
          // Clip the live preview to the tile bounds — BoxFit.cover otherwise
          // bleeds the camera feed a few pixels past the top edge.
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (hasPreview)
                  _buildLiveCameraPreview(controller)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          colors.primary.withValues(alpha: 0.82),
                          colors.secondary.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Icon(
                      AppIcons.camera,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 28,
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.44),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_cameraInitializing)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SecretlySpinner(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _t('Камера', 'Camera'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cameraUnavailable
                            ? _t(
                                'Открыть полноценную камеру',
                                'Open the full camera',
                              )
                            : _t(
                                'Нажмите, чтобы открыть камеру',
                                'Tap to open the camera',
                              ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(AssetEntity asset) {
    final orderedSelection = _selectedPhotoIds.toList(growable: false);
    final selectedIndex = orderedSelection.indexOf(asset.id) + 1;
    final isSelected = selectedIndex > 0;
    final isVideo = asset.type == AssetType.video;

    void toggleSelection() => _toggleAssetSelection(asset);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // SEND EDITOR (2026-07-17): tapping the MEDIA opens the fullscreen
        // pre-send editor (Telegram-style: meta, trim, caption, send);
        // selection lives on the check circle.
        onTap: _busy
            ? null
            : () async {
                final req = await Navigator.of(context)
                    .push<_AssetEditorSendRequest>(
                  PageRouteBuilder<_AssetEditorSendRequest>(
                    // Fullscreen editor must FULLY cover the picker/chat below —
                    // opaque:false kept the chat route (and its accent-tinted
                    // composer field) painted underneath, so it bled through as a
                    // second "caption" field overlapping ours.
                    // Прозрачный маршрут: при смахивании вниз и закрытии
                    // снимок улетает обратно в свою плитку (Hero), а сетка
                    // видна под гаснущим фоном. Фон рисует сам просмотр.
                    opaque: false,
                    transitionDuration: const Duration(milliseconds: 320),
                    reverseTransitionDuration: const Duration(milliseconds: 280),
                    // 24.11.2026: листание по всей галерее, с этого снимка.
                    pageBuilder: (_, __, ___) => _AssetPreviewPager(
                      assets: List<AssetEntity>.of(_galleryAssets),
                      initialIndex: math.max(
                        0,
                        _galleryAssets.indexWhere((a) => a.id == asset.id),
                      ),
                      pageFor: (
                        a, {
                        required active,
                        required onZoomChanged,
                        required chromeOpacity,
                        required onJump,
                      }) =>
                          _AssetPreviewPage(
                            asset: a,
                            active: active,
                            onZoomChanged: onZoomChanged,
                            chromeOpacity: chromeOpacity,
                            onJump: onJump,
                            opts: _optsFor(a.id),
                            selectionNumber: () {
                              final i = _selectedPhotoIds.toList().indexOf(a.id);
                              return i + 1;
                            },
                            strip: () => [
                              for (final id in _selectedPhotoIds)
                                if (_selectedAssetById[id] case final e?) e,
                            ],
                            onSendMenu: (ctx, multi) =>
                                _openSendMenu(ctx, multi: multi),
                            onceAllowed: () async {
                              if (await _spoilerOk) return true;
                              _explainSpoilerUnavailable();
                              return false;
                            },
                            stripThumb: GalleryThumbs.instance.bytes,
                            thumbnail: GalleryThumbs.instance.bytes(a),
                            isSelected: () => _selectedPhotoIds.contains(a.id),
                            onToggle: () => _toggleAssetSelection(a),
                            localize: _t,
                            initialCaption: _captionByAssetId[a.id] ?? '',
                            initialEditedPath: _editedPathByAssetId[a.id],
                            selectedCount: () => _selectedPhotoIds.length,
                            onPersistCaption: (id, cap) {
                              if (cap.isEmpty) {
                                _captionByAssetId.remove(id);
                              } else {
                                _captionByAssetId[id] = cap;
                              }
                            },
                            onPersistEditedPath: (id, path) {
                              _editedPathByAssetId[id] = path;
                            },
                          ),
                    ),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                );
                if (req == null || !mounted) return;
                // More than one selected → send the whole selection with each
                // photo's caption (multi-photo caption fix).
                if (req.sendAll) {
                  await _confirmPhotoSelection();
                  return;
                }
                // Снимок, который отправили, — тот, на котором стоял просмотр
                // (могли пролистать от открытого).
                final sent = _galleryAssets
                        .where((a) => a.id == req.assetId)
                        .firstOrNull ??
                    asset;
                final sentIsVideo = sent.type == AssetType.video;
                final sentOpts = _optsFor(sent.id);
                final item = ChatAttachmentPickerMediaItem(
                  path: req.path,
                  kind: sentIsVideo
                      ? ChatAttachmentPickerMediaKind.video
                      : ChatAttachmentPickerMediaKind.image,
                  mime: req.mime ??
                      (req.trimmed
                          ? 'video/mp4'
                          : (sent.mimeType ??
                                (sentIsVideo ? 'video/mp4' : 'image/jpeg'))),
                  caption: req.caption,
                  photoMaxSide:
                      sentIsVideo || sentOpts.hd ? null : kPhotoSendMaxSideSd,
                  videoMaxSide: sentIsVideo
                      ? VideoCompressor.maxSideForQuality(sentOpts.videoQuality)
                      : null,
                  muteVideo: sentIsVideo && sentOpts.mute,
                  viewOnce: sentOpts.once,
                );
                Navigator.of(context).pop(
                  _flowAsFiles
                      ? ChatAttachmentPickerResult.filesFromGallery(
                          <ChatAttachmentPickerMediaItem>[item],
                        )
                      : ChatAttachmentPickerResult.photos(
                          <ChatAttachmentPickerMediaItem>[item],
                          options: _flowOptions(),
                        ),
                );
              },
        child: Ink(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Перелёт в просмотр и обратно (макет SendFlow).
              Hero(
                tag: 'sendflow:${asset.id}',
                child: _buildPhotoThumbnail(asset),
              ),
              if (isVideo)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.36),
                        ],
                      ),
                    ),
                  ),
                ),
              if (isVideo)
                Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.playCircle,
                      size: 24,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              if (isVideo)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.black.withValues(alpha: 0.54),
                    ),
                    child: Text(
                      _formatAssetDuration(asset.duration),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (isSelected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.03),
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : toggleSelection,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black.withValues(alpha: 0.28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Center(
                    child: isSelected
                        ? Text(
                            '$selectedIndex',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(AssetEntity asset) =>
      GalleryThumbView(key: ValueKey<String>(asset.id), asset: asset);

  String _formatAssetDuration(int durationSeconds) {
    final safeSeconds = durationSeconds.clamp(0, 99 * 60 * 60);
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildInlineStateTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    Future<void> Function()? onAction,
    IconData? trailingIcon,
    Future<void> Function()? onTrailingTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.52),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            unawaited(onAction());
                          },
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
          if (trailingIcon != null && onTrailingTap != null)
            PressFeedback(child: IconButton(
              onPressed: _busy
                  ? null
                  : () {
                      unawaited(onTrailingTap());
                    },
              icon: Icon(trailingIcon),
            )),
        ],
      ),
    );
  }
}

/// Specular top-edge highlight (bright white along the top, fading to
/// transparent) — gives a glass strip the same convex, lit-from-above look as
/// the chat-header / now-playing islands.
class _IslandTopHighlightPainter extends CustomPainter {
  const _IslandTopHighlightPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.2;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[color, color.withValues(alpha: 0.0)],
      stops: const <double>[0.0, 0.55],
    ).createShader(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_IslandTopHighlightPainter old) =>
      old.radius != radius || old.color != color;
}

/// Full-screen in-app camera. Tap the shutter to take a photo, press-and-hold
/// the shutter to record video, or flip the Фото/Видео toggle to switch the
/// shutter into video mode. Pops the route with the captured
/// [ChatAttachmentPickerMediaItem] (or null when cancelled).
class _InAppCameraPage extends StatefulWidget {
  const _InAppCameraPage({
    required this.cameras,
    required this.initialCameraIndex,
    required this.mimeForPath,
    required this.localize,
  });

  final List<CameraDescription> cameras;
  final int initialCameraIndex;
  final String? Function(String path) mimeForPath;
  final String Function(String ru, String en) localize;

  @override
  State<_InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<_InAppCameraPage> {
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _unavailable = false;
  bool _busy = false;
  bool _videoMode = false;
  bool _recording = false;
  bool _stopRequested = false;
  Timer? _maxDurationTimer;
  static const Duration _maxVideoDuration = Duration(seconds: 60);

  String _t(String ru, String en) => widget.localize(ru, en);

  @override
  void initState() {
    super.initState();
    _cameraIndex = widget.initialCameraIndex
        .clamp(0, math.max(0, widget.cameras.length - 1));
    unawaited(_initController());
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  Future<void> _initController() async {
    if (widget.cameras.isEmpty) {
      if (mounted) {
        setState(() => _unavailable = true);
      }
      return;
    }
    if (mounted) {
      setState(() => _unavailable = false);
    }
    try {
      final controller = CameraController(
        widget.cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _controller;
      setState(() {
        _controller = controller;
        _unavailable = false;
      });
      if (previous != null) {
        unawaited(previous.dispose());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _unavailable = true);
    }
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2 || _busy || _recording) return;
    setState(() {
      _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    });
    await _initController();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(
        ChatAttachmentPickerMediaItem(
          path: shot.path,
          kind: ChatAttachmentPickerMediaKind.image,
          mime: widget.mimeForPath(shot.path) ?? 'image/jpeg',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo ||
        _busy) {
      return;
    }
    _stopRequested = false;
    try {
      await controller.startVideoRecording();
      if (!mounted) {
        unawaited(controller.stopVideoRecording().catchError((_) => XFile('')));
        return;
      }
      setState(() => _recording = true);
      if (_stopRequested) {
        await _stopRecording();
        return;
      }
      _maxDurationTimer?.cancel();
      _maxDurationTimer =
          Timer(_maxVideoDuration, () => unawaited(_stopRecording()));
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    final controller = _controller;
    if (controller != null &&
        !controller.value.isRecordingVideo &&
        !_recording) {
      _stopRequested = true;
      return;
    }
    if (controller == null || !controller.value.isRecordingVideo) {
      if (mounted && _recording) setState(() => _recording = false);
      return;
    }
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final clip = await controller.stopVideoRecording();
      if (!mounted) return;
      // Pause the live preview while the editor is on top so the camera does
      // not keep streaming frames behind the modal editor.
      await controller.pausePreview();
      if (!mounted) return;
      // Облегчённая сборка: редактора обрезки нет — снятый клип уходит как
      // есть, ровно как снятый в системной камере.
      if (!kVideoToolsAvailable) {
        Navigator.of(context).pop(
          ChatAttachmentPickerMediaItem(
            path: clip.path,
            kind: ChatAttachmentPickerMediaKind.video,
            mime: widget.mimeForPath(clip.path) ?? 'video/mp4',
          ),
        );
        return;
      }
      final edited = await Navigator.of(context).push<VideoTrimEditorResult>(
        MaterialPageRoute<VideoTrimEditorResult>(
          fullscreenDialog: true,
          builder: (_) => VideoTrimEditorScreen(
            sourcePath: clip.path,
            localize: widget.localize,
          ),
        ),
      );
      if (!mounted) return;
      if (edited == null) {
        // User cancelled the editor: resume the camera so they can retake.
        try {
          await controller.resumePreview();
        } catch (_) {}
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        ChatAttachmentPickerMediaItem(
          path: edited.path,
          kind: ChatAttachmentPickerMediaKind.video,
          mime: widget.mimeForPath(edited.path) ?? 'video/mp4',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  /// The shutter behaves contextually: in photo mode tap = photo / hold = quick
  /// video; in video mode tap = start / stop the recording.
  void _onShutterTap() {
    if (_videoMode) {
      if (_recording) {
        unawaited(_stopRecording());
      } else {
        unawaited(_startRecording());
      }
    } else {
      unawaited(_capturePhoto());
    }
  }

  Widget _buildPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasPreview = controller != null && controller.value.isInitialized;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasPreview)
            _buildPreview(controller)
          else if (_unavailable)
            Center(
              child: Text(
                _t('Камера недоступна', 'Camera unavailable'),
                style: const TextStyle(color: Colors.white70),
              ),
            )
          else
            const Center(
              child: SecretlySpinner(color: Colors.white),
            ),

          // Top bar: close + recording indicator.
          Positioned(
            top: media.padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: <Widget>[
                PressFeedback(child: IconButton(
                  onPressed:
                      _recording ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(AdaptiveIcons.close, color: Colors.white, size: 28),
                )),
                const Spacer(),
                if (_recording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _t('Запись', 'REC'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom controls: mode toggle + shutter + flip.
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!_recording) _buildModeToggle(),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    const SizedBox(width: 48),
                    const Spacer(),
                    _buildShutter(),
                    const Spacer(),
                    SizedBox(
                      width: 48,
                      child: (widget.cameras.length > 1 && !_recording)
                          ? PressFeedback(child: IconButton(
                              onPressed: _busy ? null : () => _flipCamera(),
                              icon: const Icon(
                                AdaptiveIcons.cameraswitch_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _videoMode
                      ? (_recording
                          ? _t('Нажмите, чтобы остановить',
                              'Tap to stop')
                          : _t('Нажмите, чтобы записать видео',
                              'Tap to record video'))
                      : _t('Нажмите — фото · удержание — видео',
                          'Tap for photo · hold for video'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    Widget chip(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          chip(
            _t('Фото', 'Photo'),
            !_videoMode,
            () {
              if (_videoMode && !_recording) {
                setState(() => _videoMode = false);
              }
            },
          ),
          chip(
            _t('Видео', 'Video'),
            _videoMode,
            () {
              if (!_videoMode) setState(() => _videoMode = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShutter() {
    final recording = _recording;
    return GestureDetector(
      onTap: _busy && !recording ? null : _onShutterTap,
      // Press-and-hold always records video, regardless of the current mode.
      onLongPressStart: (_busy || _videoMode)
          ? null
          : (_) => unawaited(_startRecording()),
      onLongPressEnd: (_videoMode)
          ? null
          : (_) => unawaited(_stopRecording()),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: recording ? 32 : 62,
            height: recording ? 32 : 62,
            decoration: BoxDecoration(
              color: (recording || _videoMode)
                  ? const Color(0xFFFF3B30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(recording ? 8 : 40),
            ),
          ),
        ),
      ),
    );
  }
}


/// SEND EDITOR (2026-07-17, по референс-скриншотам Telegram): полноэкранный
/// пред-отправочный редактор одного медиа из галереи.
///   * верх: круглая стеклянная «Назад», строка метаданных (WxH, длительность,
///     ~размер), живой кружок выбора;
///   * видео: тап — пауза/пуск, кнопка звука, ИНЛАЙН трим-лента с ручками
///     (кадры FFmpeg), проигрывание строго внутри выбранного диапазона;
///   * низ: тёмная пилюля «Добавить подпись…» + синяя круглая отправка.
/// Отправка возвращает [_AssetEditorSendRequest] — пикер закрывается сразу с
/// этим одним медиа (подпись едет в чат, каптшн-шит пропускается). Трим
/// экспортируется быстрым stream-copy через общий хелпер трим-редактора.
/// Инструменты рисования/кропа/качества (скриншоты 2–3) — следующий слой.
class _AssetEditorSendRequest {
  const _AssetEditorSendRequest.single({
    required this.path,
    required this.caption,
    required this.trimmed,
    this.mime,
    this.assetId,
  }) : sendAll = false;

  /// The user hit Send with MORE than one asset selected — the picker sends the
  /// whole selection, applying each asset's persisted caption. (Per-asset video
  /// trim / rotation are only honoured in the single-asset path.)
  const _AssetEditorSendRequest.sendAll()
    : path = '',
      caption = '',
      trimmed = false,
      mime = null,
      assetId = null,
      sendAll = true;

  final String path;
  final String caption;
  final bool trimmed;

  /// Overrides the item mime when the editor re-encoded the file (a rotated
  /// photo is baked to JPEG). Null = keep the asset's original mime.
  final String? mime;
  final bool sendAll;

  /// Какой снимок отправляется: в просмотре можно пролистать к другому
  /// (24.11.2026), и вид/тип файла берутся у него, а не у открытого первым.
  final String? assetId;
}

/// Просмотр снимков галереи с листанием (24.11.2026, владелец: «нажал на
/// фото — показывается, можно редактировать… и листать свайпом влево,
/// вправо»). Каждая страница — прежний экран снимка (выбор, подпись, трим,
/// правка); подпись и правки каждого снимка хранит лист вложений, поэтому
/// листание туда-обратно их не теряет. Пока снимок увеличен, листание стоит.
/// Лимит выбора за раз (макет SendFlow, как в Telegram).
const int kSendFlowMaxSelection = 10;

enum _GalleryFilter { recent, favorites, videos, screenshots }

/// Параметры отправки одного снимка (SendFlow): HD — оригинал (как было),
/// SD — 1280; видео 480/720/1080p, без звука.
class _AssetSendOpts {
  _AssetSendOpts();
  bool hd = true;
  int videoQuality = 1080;
  bool mute = false;
  bool once = false;
}

/// Заглушка для страниц без листа (тесты): правки ни на что не влияют.
class _NoOpts implements _AssetSendOpts {
  const _NoOpts();
  @override
  bool get hd => true;
  @override
  set hd(bool v) {}
  @override
  int get videoQuality => 1080;
  @override
  set videoQuality(int v) {}
  @override
  bool get mute => false;
  @override
  set mute(bool v) {}
  @override
  bool get once => false;
  @override
  set once(bool v) {}
}

/// Меню отправки (макет SendFlow): стеклянная карточка над кнопкой.
class _SendFlowMenu extends StatefulWidget {
  const _SendFlowMenu({
    required this.bottom,
    required this.multi,
    required this.captionAbove,
    required this.group,
    required this.onAsFiles,
    required this.onCaptionAbove,
    required this.onGroup,
    required this.spoiler,
    required this.spoilerOk,
    required this.onSpoiler,
    required this.onSilent,
  });

  final VoidCallback onSilent;

  final bool spoiler;
  final Future<bool> spoilerOk;
  final Future<bool> Function(bool value) onSpoiler;

  final double bottom;
  final bool multi;
  final bool captionAbove;
  final bool group;
  final VoidCallback onAsFiles;
  final ValueChanged<bool> onCaptionAbove;
  final ValueChanged<bool> onGroup;

  @override
  State<_SendFlowMenu> createState() => _SendFlowMenuState();
}

class _SendFlowMenuState extends State<_SendFlowMenu> {
  late bool _group = widget.group;
  late bool _spoiler = widget.spoiler;

  @override
  Widget build(BuildContext context) {
    final ios = mediaViewerLiquidGlass;
    final blur = mediaViewerGlass;
    Widget row(String key, IconData icon, String label, VoidCallback onTap, {bool check = false}) {
      return InkWell(
        key: ValueKey('sendflow:menu:$key'),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
                if (check) const Icon(Icons.check_rounded, size: 20, color: Color(0xFF3390EC)),
              ],
            ),
          ),
        ),
      );
    }

    String t(String ru, String en, String uk, String es, String pt, String ptBr, String fr, String de) =>
        wave1Text(context, ru: ru, en: en, uk: uk, es: es, pt: pt, ptBr: ptBr, fr: fr, de: de);

    final card = Container(
      width: 270,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: !blur
            ? const Color(0xF51E2834)
            : ios
            ? Colors.white.withValues(alpha: 0.16)
            : const Color(0xCC12161C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: ios ? 0.22 : 0.16), width: ios ? .5 : 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(
              'silent',
              Icons.notifications_off_outlined,
              t('Отправить без звука', 'Send without sound', 'Надіслати без звуку', 'Enviar sin sonido', 'Enviar sem som', 'Enviar sem som', 'Envoyer sans son', 'Ohne Ton senden'),
              widget.onSilent,
            ),
            row(
              'as-file',
              Icons.description_outlined,
              widget.multi
                  ? t('Отправить как файлы', 'Send as files', 'Надіслати як файли', 'Enviar como archivos', 'Enviar como ficheiros', 'Enviar como arquivos', 'Envoyer en fichiers', 'Als Dateien senden')
                  : t('Отправить как файл', 'Send as file', 'Надіслати як файл', 'Enviar como archivo', 'Enviar como ficheiro', 'Enviar como arquivo', 'Envoyer en fichier', 'Als Datei senden'),
              widget.onAsFiles,
            ),
            FutureBuilder<bool>(
              future: widget.spoilerOk,
              builder: (context, snap) => Opacity(
                opacity: snap.data == true ? 1 : 0.45,
                child: row(
                  'spoiler',
                  Icons.visibility_off_outlined,
                  t('Скрыть под спойлер', 'Hide with spoiler', 'Сховати під спойлер', 'Ocultar con spoiler', 'Ocultar com spoiler', 'Ocultar com spoiler', 'Masquer (spoiler)', 'Als Spoiler verbergen'),
                  () async {
                    if (await widget.onSpoiler(!_spoiler) && mounted) {
                      setState(() => _spoiler = !_spoiler);
                    }
                  },
                  check: _spoiler,
                ),
              ),
            ),
            row(
              'caption-above',
              widget.captionAbove ? Icons.vertical_align_bottom_rounded : Icons.vertical_align_top_rounded,
              widget.captionAbove
                  ? t('Подпись под медиа', 'Caption below media', 'Підпис під медіа', 'Pie debajo', 'Legenda abaixo', 'Legenda abaixo', 'Légende en dessous', 'Text unter Medien')
                  : t('Подпись над медиа', 'Caption above media', 'Підпис над медіа', 'Pie encima', 'Legenda acima', 'Legenda acima', 'Légende au-dessus', 'Text über Medien'),
              () => widget.onCaptionAbove(!widget.captionAbove),
            ),
            if (widget.multi)
              row(
                'no-group',
                Icons.view_agenda_outlined,
                t('Не группировать', 'Don’t group', 'Не групувати', 'No agrupar', 'Não agrupar', 'Não agrupar', 'Ne pas grouper', 'Nicht gruppieren'),
                () {
                  setState(() => _group = !_group);
                  widget.onGroup(_group);
                },
                check: !_group,
              ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(
          right: 12,
          bottom: widget.bottom,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: blur && ios
                ? BackdropFilter(filter: mediaViewerGlassFilter(24), child: card)
                : card,
          ),
        ),
      ],
    );
  }
}

class _ChromeFade extends StatelessWidget {
  const _ChromeFade({required this.opacity, required this.child});

  final ValueListenable<double>? opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final o = opacity;
    if (o == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: o,
      child: child,
      builder: (context, v, child) => IgnorePointer(
        ignoring: v < 0.5,
        child: Opacity(opacity: v, child: child),
      ),
    );
  }
}

/// Видимость панелей страницы [index] по положению [pages].
class _PageChromeOpacity extends ValueNotifier<double> {
  _PageChromeOpacity(this.pages, this.index, this.dragDy) : super(1) {
    pages.addListener(_update);
    dragDy.addListener(_update);
    _update();
  }

  final PageController pages;
  final int index;
  final ValueListenable<double> dragDy;

  void _update() {
    final p = pages.hasClients && pages.position.haveDimensions
        ? (pages.page ?? index.toDouble())
        : pages.initialPage.toDouble();
    final byPage = (1 - (p - index).abs() * 2.5).clamp(0.0, 1.0);
    // Смахивание вниз — панели прячутся сразу.
    final byDrag = (1 - dragDy.value.abs() / 40).clamp(0.0, 1.0);
    value = byPage * byDrag;
  }

  @override
  void dispose() {
    pages.removeListener(_update);
    dragDy.removeListener(_update);
    super.dispose();
  }
}

class _AssetPreviewPager extends StatefulWidget {
  const _AssetPreviewPager({
    required this.assets,
    required this.initialIndex,
    required this.pageFor,
  });

  final List<AssetEntity> assets;
  final int initialIndex;
  final Widget Function(
    AssetEntity asset, {
    required bool active,
    required ValueChanged<bool> onZoomChanged,
    required ValueListenable<double> chromeOpacity,
    required ValueChanged<String> onJump,
  })
  pageFor;

  @override
  State<_AssetPreviewPager> createState() => _AssetPreviewPagerState();
}

class _AssetPreviewPagerState extends State<_AssetPreviewPager> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  final Map<int, _PageChromeOpacity> _chrome = {};

  /// Смахивание вниз (макет SendFlow): снимок едет за пальцем и уменьшается,
  /// фон гаснет, панели прячутся; дальше 110 pt или быстро — закрыть (снимок
  /// улетает в плитку), иначе — пружиной назад.
  final ValueNotifier<double> _dragDy = ValueNotifier<double>(0);
  bool _dragging = false;

  _PageChromeOpacity _chromeFor(int i) =>
      _chrome.putIfAbsent(i, () => _PageChromeOpacity(_pages, i, _dragDy));

  void _onDragUpdate(DragUpdateDetails d) {
    if (_zoomed) return;
    _dragging = true;
    _dragDy.value = math.max(-40, _dragDy.value + d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    if (_dragDy.value > 110 || v > 700) {
      Navigator.of(context).maybePop();
      return;
    }
    _animateBack();
  }

  void _animateBack() {
    final from = _dragDy.value;
    final c = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 260),
    );
    final a = CurvedAnimation(parent: c, curve: const Cubic(.2, .8, .2, 1));
    a.addListener(() => _dragDy.value = from * (1 - a.value));
    c.forward().whenComplete(c.dispose);
  }

  @override
  void dispose() {
    for (final c in _chrome.values) {
      c.dispose();
    }
    _dragDy.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final page = PageView.builder(
        key: const ValueKey('asset-preview:pager'),
        controller: _pages,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        itemCount: widget.assets.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) {
          final asset = widget.assets[i];
          return KeyedSubtree(
            key: ValueKey('asset-preview:${asset.id}'),
            child: widget.pageFor(
              asset,
              active: i == _index,
              chromeOpacity: _chromeFor(i),
              onJump: (id) {
                final k = widget.assets.indexWhere((a) => a.id == id);
                if (k < 0 || k == _index) return;
                _pages.animateToPage(
                  k,
                  duration: const Duration(milliseconds: 340),
                  curve: const Cubic(.2, .8, .2, 1),
                );
              },
              onZoomChanged: (z) {
                if (i != _index || z == _zoomed) return;
                setState(() => _zoomed = z);
              },
            ),
          );
        },
      );
    return GestureDetector(
      key: const ValueKey('sendflow:dismiss-drag'),
      onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
      onVerticalDragEnd: _zoomed ? null : _onDragEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragDy,
        child: page,
        builder: (context, dy, child) {
          final bg = dy == 0 ? 1.0 : 1 - (dy.abs() / 350).clamp(0.0, 1.0) * 0.9;
          final scale = 1 - (dy.abs() / h).clamp(0.0, 1.0) * 0.3;
          return ColoredBox(
            color: Colors.black.withValues(alpha: bg),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
      ),
    );
  }
}

class _AssetPreviewPage extends StatefulWidget {
  const _AssetPreviewPage({
    required this.asset,
    required this.isSelected,
    required this.onToggle,
    required this.localize,
    this.initialCaption = '',
    required this.onPersistCaption,
    required this.selectedCount,
    required this.onPersistEditedPath,
    this.initialEditedPath,
    this.active = true,
    this.onZoomChanged,
    this.chromeOpacity,
    this.thumbnail,
    this.onJump,
    _AssetSendOpts? opts,
    this.selectionNumber,
    this.strip,
    this.stripThumb,
    this.onSendMenu,
    this.onceAllowed,
  }) : opts = opts ?? const _NoOpts();

  /// Можно ли одноразовый (все получатели умеют); `false` — объяснить.
  final Future<bool> Function()? onceAllowed;

  /// Меню отправки по долгому нажатию; `true` — отправить сейчас.
  final Future<bool> Function(BuildContext context, bool multi)? onSendMenu;

  /// Параметры отправки этого снимка (хранит лист вложений).
  final _AssetSendOpts opts;

  /// Номер в выборе (0 — не выбран).
  final int Function()? selectionNumber;

  /// Выбранные снимки по порядку — лента над инструментами (от двух).
  final List<AssetEntity> Function()? strip;
  final Future<Uint8List?> Function(AssetEntity asset)? stripThumb;

  /// Перейти к снимку из ленты.
  final ValueChanged<String>? onJump;

  /// Видимость панелей (0…1) от положения листания: панели не уезжают со
  /// снимком, а гаснут у уходящего и проявляются у нового (как в Telegram).
  final ValueListenable<double>? chromeOpacity;

  /// Миниатюра из сетки — сразу на месте снимка, пока грузится оригинал
  /// (вместо чёрного экрана со спиннером при каждом свайпе).
  final Future<Uint8List?>? thumbnail;

  /// Правленый файл этого снимка с прошлого визита (листание туда-обратно не
  /// теряет кадрирование и рисунок).
  final String? initialEditedPath;

  /// Страница на экране (в листании): видео играет только у неё.
  final bool active;

  /// Снимок увеличен — листание отключается, чтобы двигать снимок.
  final ValueChanged<bool>? onZoomChanged;

  final AssetEntity asset;
  final bool Function() isSelected;
  final VoidCallback onToggle;
  final String Function(String ru, String en) localize;

  /// This asset's caption from a previous visit (multi-photo: captions persist
  /// in the picker so backing out and coming back keeps what you typed).
  final String initialCaption;

  /// Save this asset's caption in the picker (empty clears it). Called on Send
  /// and on back-out, so every caption the user types is applied on send.
  final void Function(String assetId, String caption) onPersistCaption;

  /// Current number of selected assets — decides Send = "this one" vs "all".
  final int Function() selectedCount;

  /// Persist THIS asset's edited (rotated/cropped/drawn) file path so a
  /// multi-photo batch send uses the edit instead of the original gallery file.
  final void Function(String assetId, String path) onPersistEditedPath;

  @override
  State<_AssetPreviewPage> createState() => _AssetPreviewPageState();
}

class _AssetPreviewPageState extends State<_AssetPreviewPage> {
  static const int _minTrimMs = 1000;

  File? _file;
  int _fileBytes = 0;
  VideoPlayerController? _video;
  bool _loadFailed = false;
  bool _exporting = false;

  List<File> _frames = const <File>[];
  int _durationMs = 0;
  int _startMs = 0;
  int _endMs = 0;

  final TextEditingController _caption = TextEditingController();

  // EDITOR TOOLS (2026-07-17): 90° rotation applied to a PHOTO. Preview rotates
  // live; on send we bake the rotation into a new JPEG so the recipient sees it
  // upright. 0..3 quarter-turns clockwise.
  int _rotationQuarter = 0;

  // Crop bakes (rotation + crop) destructively into a fresh JPEG that replaces
  // `_file`, so the preview shows the result and send just uses it. This flag
  // means the working file is already a re-encoded JPEG (mime override on send).
  bool _bakedToJpeg = false;

  // ORIENTED display dimensions of the current working image (`_file`). Seeded
  // from the asset in _load() via the EXIF-aware ui codec and updated after each
  // bake, so the crop/draw pages compute the right aspect ratio (asset.width/
  // height are RAW, un-oriented → wrong AR for portrait phone photos and for a
  // re-encoded second edit).
  int _workW = 0;
  int _workH = 0;

  bool get _isVideo => widget.asset.type == AssetType.video;
  bool get _isPhoto => widget.asset.type == AssetType.image;
  bool get _hasTrim =>
      _isVideo && (_startMs > 60 || (_durationMs - _endMs) > 60);

  final TransformationController _zoom = TransformationController();
  bool _zoomed = false;

  void _onZoom() {
    final z = _zoom.value.getMaxScaleOnAxis() > 1.02;
    if (z == _zoomed) return;
    _zoomed = z;
    widget.onZoomChanged?.call(z);
  }

  @override
  void initState() {
    super.initState();
    _caption.text = widget.initialCaption;
    _zoom.addListener(_onZoom);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _AssetPreviewPage old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active && _isVideo && !_videoStarted) _scheduleVideoStart();
    if (!widget.active) _videoStartTimer?.cancel();
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    // Видео играет только на странице, которая на экране.
    if (widget.active) {
      unawaited(v.play());
    } else {
      unawaited(v.pause());
    }
  }

  Future<void> _load() async {
    try {
      final edited = widget.initialEditedPath;
      final editedFile = edited != null && File(edited).existsSync()
          ? File(edited)
          : null;
      if (editedFile != null) _bakedToJpeg = true;
      final f = editedFile ?? await widget.asset.file;
      if (!mounted) return;
      if (f == null) {
        setState(() => _loadFailed = true);
        return;
      }
      final bytes = await f.length();
      if (!mounted) return;
      setState(() {
        _file = f;
        _fileBytes = bytes;
      });
      if (_isPhoto) {
        // Размеры без раскрытия снимка (раньше — полный декод 24–48 Мп на
        // каждой странице листания: сотни МБ и нагрев). Оригинал — по
        // данным галереи с учётом поворота EXIF; правленый JPEG — по
        // заголовку файла (поворот в нём уже «запечён»).
        final dims = editedFile != null
            ? await _probeImageSize(f)
            : (widget.asset.orientatedWidth, widget.asset.orientatedHeight);
        if (mounted && dims != null) {
          setState(() {
            _workW = dims.$1;
            _workH = dims.$2;
          });
        }
      }
      if (_isVideo) {
        // Видео — только у страницы на экране и после того, как листание
        // остановилось: пролистанные мимо не поднимают плеер и FFmpeg.
        _scheduleVideoStart();
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Timer? _videoStartTimer;
  bool _videoStarted = false;

  void _scheduleVideoStart() {
    _videoStartTimer?.cancel();
    if (!widget.active || _videoStarted || _file == null) return;
    _videoStartTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted && widget.active && !_videoStarted) unawaited(_startVideo());
    });
  }

  Future<void> _startVideo() async {
    final f = _file;
    if (f == null || _videoStarted) return;
    _videoStarted = true;
    try {
      {
        final v = VideoPlayerController.file(f);
        _video = v;
        await v.initialize();
        await v.setLooping(false);
        v.addListener(_onVideoTick);
        if (widget.opts.mute) unawaited(v.setVolume(0));
        // Страницу закрыли, пока плеер поднимался: его уже освободил
        // dispose страницы — второй раз нельзя.
        if (!mounted) return;
        setState(() {
          _durationMs = v.value.duration.inMilliseconds;
          _startMs = 0;
          _endMs = _durationMs;
        });
        if (widget.active) unawaited(v.play());
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 400)).then((_) async {
            // Лента кадров — полный проход FFmpeg; только если человек
            // остался на этом видео.
            if (!mounted || !widget.active) return;
            final frames = await videoTrimFilmstripFrames(f.path);
            if (mounted && frames.isNotEmpty) {
              setState(() => _frames = frames);
            }
          }),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Ширина и высота картинки по заголовку файла, без раскрытия пикселей.
  static Future<(int, int)?> _probeImageSize(File f) async {
    ui.ImmutableBuffer? buf;
    ui.ImageDescriptor? desc;
    try {
      buf = await ui.ImmutableBuffer.fromFilePath(f.path);
      desc = await ui.ImageDescriptor.encoded(buf);
      return (desc.width, desc.height);
    } catch (_) {
      return null;
    } finally {
      desc?.dispose();
      buf?.dispose();
    }
  }

  void _onVideoTick() {
    final v = _video;
    if (v == null || !v.value.isInitialized || _durationMs <= 0) return;
    final pos = v.value.position.inMilliseconds;
    // Проигрывание строго внутри трим-диапазона (как в полном редакторе).
    if (pos >= _endMs - 40) {
      unawaited(v.seekTo(Duration(milliseconds: _startMs)));
      if (!v.value.isPlaying) unawaited(v.play());
    } else if (pos < _startMs - 200) {
      unawaited(v.seekTo(Duration(milliseconds: _startMs)));
    }
    if (mounted) setState(() {});
  }

  void _onTrimChanged(int startMs, int endMs) {
    setState(() {
      _startMs = startMs.clamp(0, _durationMs);
      _endMs = endMs.clamp(_startMs + _minTrimMs, _durationMs);
    });
    final v = _video;
    if (v != null) {
      final pos = v.value.position.inMilliseconds;
      if (pos < _startMs || pos > _endMs) {
        unawaited(v.seekTo(Duration(milliseconds: _startMs)));
      }
    }
  }

  Future<void> _send() async {
    if (_exporting) return;
    final file = _file;
    if (file == null) return;
    // Persist THIS asset's caption and make sure it is part of the batch.
    widget.onPersistCaption(widget.asset.id, _caption.text.trim());
    if (!widget.isSelected()) {
      widget.onToggle();
    }
    final multi = widget.selectedCount() > 1;

    // PHOTO: bake any pending rotation on top of an already-baked crop/draw so
    // the FINAL file carries every edit. `_bakedToJpeg` = _file is already an
    // edited JPEG (crop/draw).
    var photoPath = file.path;
    var photoEdited = _bakedToJpeg;
    if (_isPhoto && _rotationQuarter != 0) {
      setState(() => _exporting = true);
      final baked = await _bakeViaUi(file, quarterTurns: _rotationQuarter);
      if (!mounted) return;
      setState(() => _exporting = false);
      if (baked != null) {
        photoPath = baked.$1;
        photoEdited = true;
      }
    }

    if (multi) {
      // Carry THIS photo's edits into the batch (the others are sent as-is).
      // Was silently lost: the batch re-resolved every asset from the ORIGINAL
      // gallery file, so crop/rotate/draw never made it.
      if (_isPhoto && photoEdited) {
        widget.onPersistEditedPath(widget.asset.id, photoPath);
      }
      if (!mounted) return;
      Navigator.of(context).pop(const _AssetEditorSendRequest.sendAll());
      return;
    }

    // Single VIDEO: export the trim if the user trimmed it.
    if (_isVideo) {
      var path = file.path;
      var trimmed = false;
      if (_hasTrim) {
        setState(() => _exporting = true);
        unawaited(_video?.pause());
        final out = await exportTrimmedVideoFile(
          file.path,
          startMs: _startMs,
          endMs: _endMs,
        );
        if (!mounted) return;
        if (out == null) {
          setState(() => _exporting = false);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SecretlySnackBar(
              content: Text(
                wave1Text(
                  context,
                  ru: 'Не удалось обрезать видео',
                  en: 'Failed to trim the video',
                  uk: 'Не вдалося обрізати відео',
                  es: 'No se pudo recortar el vídeo',
                  pt: 'Não foi possível cortar o vídeo',
                  ptBr: 'Não foi possível cortar o vídeo',
                  fr: 'Échec du rognage de la vidéo',
                  de: 'Video konnte nicht zugeschnitten werden',
                ),
              ),
            ),
          );
          return;
        }
        path = out;
        trimmed = true;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _AssetEditorSendRequest.single(
          path: path,
          caption: _caption.text.trim(),
          trimmed: trimmed,
          assetId: widget.asset.id,
        ),
      );
      return;
    }

    // Single PHOTO.
    if (!mounted) return;
    Navigator.of(context).pop(
      _AssetEditorSendRequest.single(
        path: photoPath,
        caption: _caption.text.trim(),
        trimmed: false,
        mime: photoEdited ? 'image/jpeg' : null,
        assetId: widget.asset.id,
      ),
    );
  }

  /// Bake current rotation (+ optional crop) into a fresh JPEG via the SAME
  /// EXIF-aware `ui` codec the draw tool uses. `img.decodeImage` ignores the
  /// EXIF orientation tag and can't read HEIC, so the old crop/rotate bakes
  /// corrupted portrait photos and silently no-op'd on iPhone HEIC. The crop
  /// rect is normalized in the ROTATED display space. Output is downscaled to a
  /// sane max dimension so a 48–108MP photo can't OOM. Returns (path, w, h).
  Future<(String, int, int)?> _bakeViaUi(
    File src, {
    required int quarterTurns,
    Rect? cropNorm,
  }) async {
    ui.Image? image;
    ui.Image? outImg;
    try {
      final bytes = await src.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image; // already EXIF-oriented (matches the preview)
      final q = quarterTurns % 4;
      final rw = q.isOdd ? image.height : image.width;
      final rh = q.isOdd ? image.width : image.height;
      final cx = (cropNorm?.left ?? 0.0) * rw;
      final cy = (cropNorm?.top ?? 0.0) * rh;
      final cw = ((cropNorm?.width ?? 1.0) * rw).round().clamp(1, rw);
      final ch = ((cropNorm?.height ?? 1.0) * rh).round().clamp(1, rh);
      const maxDim = 4096;
      var scale = 1.0;
      if (cw > maxDim || ch > maxDim) {
        scale = maxDim / (cw > ch ? cw : ch);
      }
      final outW = (cw * scale).round().clamp(1, cw);
      final outH = (ch * scale).round().clamp(1, ch);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale); // outermost: downscale the whole composite
      canvas.translate(-cx, -cy); // shift the crop origin to (0,0)
      canvas.translate(rw / 2, rh / 2); // rotate the image about its centre
      canvas.rotate(q * math.pi / 2);
      canvas.translate(-image.width / 2, -image.height / 2);
      canvas.drawImage(image, Offset.zero, Paint());
      final pic = recorder.endRecording();
      outImg = await pic.toImage(outW, outH);
      final png = await outImg.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      // Re-encode to JPEG (pixels already oriented) so the file stays small.
      final decoded = img.decodePng(png.buffer.asUint8List());
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(dir.path, 'edit_${DateTime.now().microsecondsSinceEpoch}.jpg'),
      );
      if (decoded != null) {
        await out.writeAsBytes(img.encodeJpg(decoded, quality: 92), flush: true);
      } else {
        await out.writeAsBytes(png.buffer.asUint8List(), flush: true);
      }
      return (out.path, outW, outH);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      outImg?.dispose();
    }
  }

  /// Поворот на 90° по часовой — сразу в файл (как кадр и рисунок): при
  /// листании и отправке пачкой поворот не теряется, а редактор потом видит
  /// уже повёрнутый снимок. JPEG кодируется в фоновом потоке.
  Future<void> _rotateBaked() async {
    final file = _file;
    if (file == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final dir = await getTemporaryDirectory();
      final out = await exportEditedImageFile(
        source: file,
        edits: const MediaEdits(rotation: 90),
        outPath:
            '${dir.path}/secretly_rotate_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final len = await out.length();
      final dims = await _probeImageSize(out);
      if (!mounted) return;
      setState(() {
        _file = out;
        _fileBytes = len;
        if (dims != null) {
          _workW = dims.$1;
          _workH = dims.$2;
        }
        _rotationQuarter = 0;
        _bakedToJpeg = true;
        _exporting = false;
      });
      _zoom.value = Matrix4.identity();
    } catch (_) {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openCrop() => _openEditor(MediaEditorTab.crop);

  Future<void> _openDraw() => _openEditor(MediaEditorTab.draw);

  /// Правка — в новом редакторе просмотра медиа (24.11.2026, владелец: «у
  /// нас уже есть готовый редактор… сделай, чтобы тут так же»): кадр,
  /// поворот, рисунок, текст, настройки, отмена шагов. Результат «запекается»
  /// в JPEG и заменяет рабочий файл — отправка и пачка берут его.
  Future<void> _openEditor(MediaEditorTab tab) async {
    var file = _file;
    if (file == null || _exporting) return;
    // Быстрый поворот кнопкой — сначала в файл, чтобы редактор видел то же.
    if (_rotationQuarter != 0) {
      setState(() => _exporting = true);
      final baked = await _bakeViaUi(file, quarterTurns: _rotationQuarter);
      if (!mounted) return;
      setState(() => _exporting = false);
      if (baked != null) {
        file = File(baked.$1);
        setState(() {
          _file = file;
          _workW = baked.$2;
          _workH = baked.$3;
          _rotationQuarter = 0;
          _bakedToJpeg = true;
        });
      }
    }
    final aspect = _workW > 0 && _workH > 0 ? _workW / _workH : 1.0;
    // В редактор — уменьшенная копия (до 2048 по длинной стороне): экспорт
    // всё равно берёт исходный файл.
    final edits = await openMediaEditor(
      context,
      image: ResizeImage(
        FileImage(file),
        width: aspect >= 1 ? 2048 : null,
        height: aspect < 1 ? 2048 : null,
        allowUpscaling: false,
      ),
      sourceAspect: aspect,
      initial: MediaEdits.identity,
      initialTab: tab,
    );
    if (edits == null || edits.isIdentity || !mounted) return;
    setState(() => _exporting = true);
    try {
      final dir = await getTemporaryDirectory();
      final out = await exportEditedImageFile(
        source: file,
        edits: edits,
        outPath:
            '${dir.path}/secretly_edit_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final len = await out.length();
      final dims = await _probeImageSize(out);
      if (!mounted) return;
      setState(() {
        _file = out;
        _fileBytes = len;
        if (dims != null) {
          _workW = dims.$1;
          _workH = dims.$2;
        }
        _rotationQuarter = 0;
        _bakedToJpeg = true;
        _exporting = false;
      });
      _zoom.value = Matrix4.identity();
    } catch (_) {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    // Keep whatever caption was typed for this asset (backing out must not lose
    // it — the multi-photo flow relies on captions persisting in the picker).
    widget.onPersistCaption(widget.asset.id, _caption.text.trim());
    // Правки этого снимка — тоже (уход листанием или назад их не теряет).
    final edited = _file;
    if (_isPhoto && _bakedToJpeg && edited != null) {
      widget.onPersistEditedPath(widget.asset.id, edited.path);
    }
    _zoom
      ..removeListener(_onZoom)
      ..dispose();
    _videoStartTimer?.cancel();
    final v = _video;
    _video = null;
    if (v != null) {
      v.removeListener(_onVideoTick);
      unawaited(v.dispose());
    }
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final selected = widget.isSelected();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      // Фон — у просмотра (гаснет при смахивании вниз).
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ---------- медиа ----------
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusScope.of(context).unfocus();
                final v = _video;
                if (v == null || !v.value.isInitialized) return;
                v.value.isPlaying ? v.pause() : v.play();
                setState(() {});
              },
              child: Center(
                child: Hero(
                  tag: 'sendflow:${widget.asset.id}',
                  // Пока летит — миниатюра из сетки (оригинал ещё грузится).
                  flightShuttleBuilder: (_, anim, dir, from, to) =>
                      dir == HeroFlightDirection.push ? _placeholder() : from.widget,
                  child: _loadFailed
                    ? const Icon(
                        AppIcons.brokenImage,
                        color: Colors.white70,
                        size: 44,
                      )
                    : _file == null
                    ? _placeholder()
                    : _isVideo
                    ? (video != null && video.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: video.value.aspectRatio <= 0
                                  ? 16 / 9
                                  : video.value.aspectRatio,
                              child: VideoPlayer(video),
                            )
                          : _placeholder())
                    : InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 0.9,
                        maxScale: 5,
                        child: RotatedBox(
                          quarterTurns: _rotationQuarter,
                          // Декод под экран (×1,5 под увеличение), а не
                          // 24–48 Мп целиком на каждой странице листания.
                          child: Image.file(
                            _file!,
                            fit: BoxFit.contain,
                            cacheWidth: _workW >= _workH ? _displayDecodeSide(context) : null,
                            cacheHeight: _workW < _workH ? _displayDecodeSide(context) : null,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
          // Панели гаснут при листании, а не уезжают со снимком.
          Positioned.fill(
            child: _ChromeFade(
              opacity: widget.chromeOpacity,
              child: Stack(
                children: [
          // Центральная кнопка Play (когда видео на паузе).
          if (video != null &&
              video.value.isInitialized &&
              !video.value.isPlaying &&
              !_exporting)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Icon(
                    AdaptiveIcons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          // ---------- верх: назад + мета + выбор ----------
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _roundGlass(
                  child: PressFeedback(child: IconButton(
                    tooltip: wave1Text(
                      context,
                      ru: 'Назад',
                      en: 'Back',
                      uk: 'Назад',
                      es: 'Atrás',
                      pt: 'Voltar',
                      ptBr: 'Voltar',
                      fr: 'Retour',
                      de: 'Zurück',
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.arrowBack, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _infoLine(),
                    key: const ValueKey('sendflow:info'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onToggle();
                    setState(() {});
                  },
                  child: _roundGlass(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.6,
                        ),
                      ),
                      alignment: Alignment.center,
                      // Выбран — номер в выборе (как на плитке), нет — галочка.
                      child: selected && (widget.selectionNumber?.call() ?? 0) > 0
                          ? Text(
                              '${widget.selectionNumber!.call()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(
                              AdaptiveIcons.check_rounded,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.55),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---------- низ (макет SendFlow) ----------
          // Лента выбранных · плеер с обрезкой · инструменты и переключатели ·
          // подпись и отправка. Острова — стекло iPhone / мат Android.
          Positioned(
            left: 0,
            right: 0,
            bottom: (bottomInset > 0 ? bottomInset : safeBottom) + 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _selectionStrip(),
                if (_isVideo &&
                    video != null &&
                    video.value.isInitialized) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          key: const ValueKey('sendflow:play'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            video.value.isPlaying ? video.pause() : video.play();
                            setState(() {});
                          },
                          child: _glass(
                            radius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 40,
                              height: 44,
                              child: Icon(
                                video.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Облегчённая сборка: обрезать нечем — трека нет.
                        if (kVideoToolsAvailable)
                          Expanded(
                            child: VideoTrimTrack(
                              durationMs: _durationMs,
                              startMs: _startMs,
                              endMs: _endMs,
                              minTrimMs: _minTrimMs,
                              frames: _frames,
                              positionMs: video.value.position.inMilliseconds,
                              onChanged: _onTrimChanged,
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                  ),
                ],
                _toolsRow(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        // Островок подписи — как остальные острова (владелец
                        // 24.11.2026: «не тёмный и не цветной»).
                        child: _glass(
                          radius: BorderRadius.circular(21),
                          child: TextField(
                            key: const ValueKey('sendflow:caption'),
                            controller: _caption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText: wave1Text(
                                context,
                                ru: 'Добавить подпись…',
                                en: 'Add a caption…',
                                uk: 'Додати підпис…',
                                es: 'Añadir un pie…',
                                pt: 'Adicionar legenda…',
                                ptBr: 'Adicionar legenda…',
                                fr: 'Ajouter une légende…',
                                de: 'Bildunterschrift…',
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                11,
                                12,
                                11,
                              ),
                            ),
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sendButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Остров поверх медиа (макет SendFlow): iPhone — жидкое стекло
  /// (белый 14 %, кант 0,5 px), Android — матовое (тёмный 55 %, кант 1 px);
  /// «Размытие панелей» выключено — сплошная подложка.
  Widget _glass({required Widget child, required BorderRadius radius, Color? tint}) {
    final blur = mediaViewerGlass;
    final ios = mediaViewerLiquidGlass;
    final fill = tint ??
        (!blur
            ? const Color(0xF0202328)
            : ios
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0x8C0A0C10));
    final border = Border.all(
      color: Colors.white.withValues(alpha: ios ? 0.22 : 0.16),
      width: ios ? 0.5 : 1,
    );
    Widget body = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius, border: border),
      child: child,
    );
    // Размытие — только жидкое стекло iPhone. На Android (макет: blur none)
    // — плотная подложка: семь размытых островов поверх снимка давали
    // подтормаживания на Xiaomi (журнал 755: raster p90 13–17 мс).
    if (blur && ios) {
      body = BackdropFilter(filter: mediaViewerGlassFilter(20), child: body);
    }
    return ClipRRect(borderRadius: radius, child: body);
  }

  static const Color _kSendFlowBlue = Color(0xF23390EC);

  final GlobalKey _previewSendKey = GlobalKey(debugLabel: 'sendflow:preview-send');

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SecretlySnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Widget _toolsRow() {
    final tools = <({String key, IconData icon, String tip, VoidCallback onTap, bool on})>[
      if (_isPhoto) ...[
        (key: 'crop', icon: Icons.crop_rounded, tip: wave1Text(context, ru: 'Кадр', en: 'Crop', uk: 'Кадр', es: 'Recortar', pt: 'Cortar', ptBr: 'Cortar', fr: 'Rogner', de: 'Zuschneiden'), onTap: () => unawaited(_openCrop()), on: false),
        (key: 'rotate', icon: Icons.rotate_90_degrees_ccw_rounded, tip: wave1Text(context, ru: 'Повернуть', en: 'Rotate', uk: 'Повернути', es: 'Girar', pt: 'Rodar', ptBr: 'Girar', fr: 'Pivoter', de: 'Drehen'), onTap: () => unawaited(_rotateBaked()), on: false),
        (key: 'draw', icon: Icons.brush_rounded, tip: wave1Text(context, ru: 'Рисовать', en: 'Draw', uk: 'Малювати', es: 'Dibujar', pt: 'Desenhar', ptBr: 'Desenhar', fr: 'Dessiner', de: 'Zeichnen'), onTap: () => unawaited(_openDraw()), on: false),
        (key: 'adjust', icon: Icons.tune_rounded, tip: wave1Text(context, ru: 'Настройки', en: 'Adjust', uk: 'Налаштування', es: 'Ajustes', pt: 'Ajustes', ptBr: 'Ajustes', fr: 'Réglages', de: 'Anpassen'), onTap: () => unawaited(_openEditor(MediaEditorTab.adjust)), on: false),
      ],
    ];
    final toggles = <Widget>[
      if (_isPhoto)
        _toggle(
          key: 'quality',
          text: widget.opts.hd ? 'HD' : 'SD',
          on: widget.opts.hd,
          onTap: () {
            setState(() => widget.opts.hd = !widget.opts.hd);
            _toast(
              widget.opts.hd
                  ? wave1Text(context, ru: 'Фото будет отправлено в HD', en: 'The photo will be sent in HD', uk: 'Фото буде надіслано в HD', es: 'La foto se enviará en HD', pt: 'A foto será enviada em HD', ptBr: 'A foto será enviada em HD', fr: 'La photo sera envoyée en HD', de: 'Das Foto wird in HD gesendet')
                  : wave1Text(context, ru: 'Фото будет сжато (SD)', en: 'The photo will be compressed (SD)', uk: 'Фото буде стиснуто (SD)', es: 'La foto se comprimirá (SD)', pt: 'A foto será comprimida (SD)', ptBr: 'A foto será comprimida (SD)', fr: 'La photo sera compressée (SD)', de: 'Das Foto wird komprimiert (SD)'),
            );
          },
        ),
      // Без FFmpeg (облегчённая сборка) дорожку не вырезать — не обещаем.
      if (_isVideo && kVideoToolsAvailable) ...[
        _toggle(
          key: 'mute',
          icon: widget.opts.mute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          on: widget.opts.mute,
          onTap: () {
            setState(() => widget.opts.mute = !widget.opts.mute);
            unawaited(_video?.setVolume(widget.opts.mute ? 0 : 1));
            _toast(
              widget.opts.mute
                  ? wave1Text(context, ru: 'Видео будет отправлено без звука', en: 'The video will be sent without sound', uk: 'Відео буде надіслано без звуку', es: 'El vídeo se enviará sin sonido', pt: 'O vídeo será enviado sem som', ptBr: 'O vídeo será enviado sem som', fr: 'La vidéo sera envoyée sans son', de: 'Das Video wird ohne Ton gesendet')
                  : wave1Text(context, ru: 'Звук включён', en: 'Sound on', uk: 'Звук увімкнено', es: 'Sonido activado', pt: 'Som ligado', ptBr: 'Som ativado', fr: 'Son activé', de: 'Ton an'),
            );
          },
        ),
        const SizedBox(width: 6),
        PopupMenuButton<int>(
          key: const ValueKey('sendflow:video-quality'),
          tooltip: '',
          position: PopupMenuPosition.over,
          color: const Color(0xF51E2834),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          offset: const Offset(0, -150),
          onSelected: (q) => setState(() => widget.opts.videoQuality = q),
          itemBuilder: (context) => [
            for (final q in const [480, 720, 1080])
              PopupMenuItem<int>(
                value: q,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: widget.opts.videoQuality == q
                          ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF3390EC))
                          : null,
                    ),
                    Text('${q}p', style: const TextStyle(color: Colors.white, fontSize: 15)),
                    const Spacer(),
                    Text(
                      '~${_videoMb(q).toStringAsFixed(1).replaceAll('.', ',')} ${_mbUnit()}',
                      style: const TextStyle(color: Color(0xFF7F91A4), fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
          child: _toggleBody(text: '${widget.opts.videoQuality}p', on: false),
        ),
      ],
      const SizedBox(width: 6),
      _toggle(
        key: 'once',
        text: '1',
        on: widget.opts.once,
        onTap: () async {
          if (!widget.opts.once &&
              !(await widget.onceAllowed?.call() ?? false)) {
            return;
          }
          if (!mounted) return;
          setState(() => widget.opts.once = !widget.opts.once);
          _toast(
            widget.opts.once
                ? (_isVideo
                      ? wave1Text(context, ru: 'Получатель сможет посмотреть видео один раз', en: 'The recipient can watch the video once', uk: 'Одержувач зможе переглянути відео один раз', es: 'Podrá ver el vídeo una sola vez', pt: 'O destinatário poderá ver o vídeo uma vez', ptBr: 'O destinatário poderá ver o vídeo uma vez', fr: 'La vidéo ne pourra être vue qu’une fois', de: 'Das Video kann einmal angesehen werden')
                      : wave1Text(context, ru: 'Получатель сможет открыть фото один раз', en: 'The recipient can open the photo once', uk: 'Одержувач зможе відкрити фото один раз', es: 'Podrá abrir la foto una sola vez', pt: 'O destinatário poderá abrir a foto uma vez', ptBr: 'O destinatário poderá abrir a foto uma vez', fr: 'La photo ne pourra être ouverte qu’une fois', de: 'Das Foto kann einmal geöffnet werden'))
                : wave1Text(context, ru: 'Одноразовый просмотр выключен', en: 'View once is off', uk: 'Одноразовий перегляд вимкнено', es: 'Vista única desactivada', pt: 'Visualização única desligada', ptBr: 'Visualização única desativada', fr: 'Vue unique désactivée', de: 'Einmalansicht aus'),
          );
        },
      ),
    ];
    if (tools.isEmpty && toggles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          if (tools.isNotEmpty)
            _glass(
              radius: BorderRadius.circular(21),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in tools)
                      Semantics(
                        button: true,
                        label: t.tip,
                        child: GestureDetector(
                          key: ValueKey('sendflow:tool:${t.key}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _exporting ? null : t.onTap,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(t.icon, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          ...toggles,
        ],
      ),
    );
  }

  Widget _toggleBody({String? text, IconData? icon, required bool on}) {
    return _glass(
      radius: BorderRadius.circular(21),
      tint: on ? _kSendFlowBlue : null,
      child: Container(
        height: 42,
        constraints: const BoxConstraints(minWidth: 42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: Colors.white, size: 20)
            : Text(
                text ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _toggle({
    required String key,
    String? text,
    IconData? icon,
    required bool on,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: ValueKey('sendflow:toggle:$key'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: KeyedSubtree(
          key: ValueKey('$key:$on:$text'),
          child: _toggleBody(text: text, icon: icon, on: on),
        ),
      ),
    );
  }

  Widget _selectionStrip() {
    final items = widget.strip?.call() ?? const <AssetEntity>[];
    if (items.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < items.length; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      key: ValueKey('sendflow:strip:${items[k].id}'),
                      onTap: () => widget.onJump?.call(items[k].id),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: items[k].id == widget.asset.id
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            items[k].id == widget.asset.id ? 6 : 8,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: widget.stripThumb?.call(items[k]),
                                builder: (context, snap) => snap.data == null
                                    ? const ColoredBox(color: Color(0x33FFFFFF))
                                    : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 14),
                                  height: 14,
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3390EC),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${k + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
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
          ),
        ),
      ),
    );
  }

  Widget _sendButton() {
    final n = widget.selectedCount();
    final badge = n > 1 || (n == 1 && !widget.isSelected());
    final count = widget.isSelected() ? n : n + 1;
    return GestureDetector(
      key: _previewSendKey,
      behavior: HitTestBehavior.opaque,
      onTap: _exporting ? null : () => unawaited(_send()),
      onLongPress: _exporting || widget.onSendMenu == null
          ? null
          : () async {
              final multi = widget.selectedCount() > 1 ||
                  (widget.selectedCount() == 1 && !widget.isSelected());
              final go = await widget.onSendMenu!(
                _previewSendKey.currentContext ?? context,
                multi,
              );
              if (go && mounted) unawaited(_send());
            },
      child: SizedBox(
        width: 48,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3390EC),
              ),
              child: _exporting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SecretlySpinner(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(AppIcons.send, color: Colors.white, size: 21),
            ),
            if (badge)
              Positioned(
                right: -2,
                top: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Color(0xFF3390EC), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _mbUnit() => wave1Text(context, ru: 'МБ', en: 'MB', uk: 'МБ', es: 'MB', pt: 'MB', ptBr: 'MB', fr: 'Mo', de: 'MB');

  double _videoMb(int q) {
    final d = ((_endMs - _startMs).clamp(0, _durationMs)) / 1000;
    final per = switch (q) { <= 480 => 0.22, <= 720 => 0.45, _ => 0.95 };
    return d * per * (widget.opts.mute ? 0.9 : 1);
  }

  /// Строка сверху (макет): фото «3024×4032, ~2,4 МБ» (SD — 1280 по длинной
  /// стороне), видео «720p · 0:14 · ~6,3 МБ».
  String _infoLine() {
    String n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    if (_isVideo) {
      final q = widget.opts.videoQuality;
      final total = ((_endMs - _startMs).clamp(0, _durationMs) / 1000).round();
      final m = total ~/ 60;
      final sec = (total % 60).toString().padLeft(2, '0');
      return '${q}p · $m:$sec · ~${n(_videoMb(q))} ${_mbUnit()}';
    }
    var w = _workW > 0 ? _workW : widget.asset.orientatedWidth;
    var h = _workH > 0 ? _workH : widget.asset.orientatedHeight;
    if (w <= 0 || h <= 0) return '';
    double mb;
    if (widget.opts.hd) {
      mb = _fileBytes > 0 ? _fileBytes / (1024 * 1024) : w * h / 1e6 * 0.34;
    } else {
      final longest = math.max(w, h);
      if (longest > kPhotoSendMaxSideSd) {
        final k = kPhotoSendMaxSideSd / longest;
        w = (w * k).round();
        h = (h * k).round();
      }
      mb = w * h / 1e6 * 0.24;
    }
    return '$w×$h, ~${n(mb)} ${_mbUnit()}';
  }

  int _displayDecodeSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final longest = math.max(size.width, size.height) * dpr * 1.5;
    return longest.clamp(1024, 3072).round();
  }

  /// Пока грузится оригинал — миниатюра из сетки, без спиннера.
  Widget _placeholder() {
    final thumb = widget.thumbnail;
    if (thumb == null) return const SecretlySpinner(color: Colors.white);
    return FutureBuilder<Uint8List?>(
      future: thumb,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const SizedBox.shrink();
        return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }

  Widget _roundGlass({required Widget child, double size = 44}) {
    return _glass(
      radius: BorderRadius.circular(size / 2),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  /// Bottom edit-tools island — a glass pill in our style (matte blur, soft
  /// white border), sized/positioned like the reference screenshots. Only
  /// FUNCTIONAL tools are shown (no dead buttons): today = photo rotate. Crop /
  /// draw / adjust and the video cover picker land here in later passes.
}

/// Interactive free-form photo crop. Shows the image (respecting the editor's
/// current rotation) with a draggable rectangle — corners resize, inside pans —
/// over a dark scrim with a rule-of-thirds grid. Returns the crop as a Rect
/// normalized (0..1) to the DISPLAYED image, which the editor bakes into a JPEG.
class _CropPage extends StatefulWidget {
  const _CropPage({
    required this.file,
    required this.quarterTurns,
    required this.imageWidth,
    required this.imageHeight,
    required this.localize,
  });

  final File file;
  final int quarterTurns;
  final int imageWidth;
  final int imageHeight;
  final String Function(String ru, String en) localize;

  @override
  State<_CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<_CropPage> {
  Rect _crop = const Rect.fromLTRB(0.06, 0.10, 0.94, 0.90);
  static const double _minN = 0.12;

  double get _displayAR {
    final rotated = widget.quarterTurns.isOdd;
    final w = (rotated ? widget.imageHeight : widget.imageWidth).toDouble();
    final h = (rotated ? widget.imageWidth : widget.imageHeight).toDouble();
    if (w <= 0 || h <= 0) return 1;
    return w / h;
  }

  Rect _imageRect(Size size) {
    final ar = _displayAR;
    var w = size.width;
    var h = w / ar;
    if (h > size.height) {
      h = size.height;
      w = h * ar;
    }
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  void _dragCorner(int corner, Offset dN) {
    var l = _crop.left, t = _crop.top, r = _crop.right, b = _crop.bottom;
    switch (corner) {
      case 0:
        l += dN.dx;
        t += dN.dy;
        break;
      case 1:
        r += dN.dx;
        t += dN.dy;
        break;
      case 2:
        r += dN.dx;
        b += dN.dy;
        break;
      case 3:
        l += dN.dx;
        b += dN.dy;
        break;
    }
    l = l.clamp(0.0, r - _minN);
    t = t.clamp(0.0, b - _minN);
    r = r.clamp(l + _minN, 1.0);
    b = b.clamp(t + _minN, 1.0);
    setState(() => _crop = Rect.fromLTRB(l, t, r, b));
  }

  void _move(Offset dN) {
    var l = (_crop.left + dN.dx).clamp(0.0, 1.0 - _crop.width);
    var t = (_crop.top + dN.dy).clamp(0.0, 1.0 - _crop.height);
    setState(() => _crop = Rect.fromLTWH(l, t, _crop.width, _crop.height));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Отмена',
                        en: 'Cancel',
                        uk: 'Скасувати',
                        es: 'Cancelar',
                        pt: 'Cancelar',
                        ptBr: 'Cancelar',
                        fr: 'Annuler',
                        de: 'Abbrechen',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    wave1Text(
                      context,
                      ru: 'Кадрирование',
                      en: 'Crop',
                      uk: 'Кадрування',
                      es: 'Recortar',
                      pt: 'Cortar',
                      ptBr: 'Cortar',
                      fr: 'Rogner',
                      de: 'Zuschneiden',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_crop),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Готово',
                        en: 'Done',
                        uk: 'Готово',
                        es: 'Listo',
                        pt: 'Concluir',
                        ptBr: 'Concluir',
                        fr: 'Terminé',
                        de: 'Fertig',
                      ),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  final imgRect = _imageRect(size);
                  final cropPx = Rect.fromLTRB(
                    imgRect.left + _crop.left * imgRect.width,
                    imgRect.top + _crop.top * imgRect.height,
                    imgRect.left + _crop.right * imgRect.width,
                    imgRect.top + _crop.bottom * imgRect.height,
                  );
                  Offset toN(Offset dPx) => Offset(
                    imgRect.width == 0 ? 0 : dPx.dx / imgRect.width,
                    imgRect.height == 0 ? 0 : dPx.dy / imgRect.height,
                  );
                  const hs = 34.0;
                  Widget handle(int i, Offset center) => Positioned(
                    left: center.dx - hs / 2,
                    top: center.dy - hs / 2,
                    width: hs,
                    height: hs,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate: (d) => _dragCorner(i, toN(d.delta)),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                      ),
                    ),
                  );
                  return Stack(
                    children: [
                      Positioned.fromRect(
                        rect: imgRect,
                        child: RotatedBox(
                          quarterTurns: widget.quarterTurns,
                          child: Image.file(
                            widget.file,
                            fit: BoxFit.fill,
                            errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CropScrimPainter(cropPx),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: cropPx,
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CropGridPainter()),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: cropPx,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _move(toN(d.delta)),
                        ),
                      ),
                      handle(0, cropPx.topLeft),
                      handle(1, cropPx.topRight),
                      handle(2, cropPx.bottomRight),
                      handle(3, cropPx.bottomLeft),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropScrimPainter extends CustomPainter {
  _CropScrimPainter(this.cropPx);
  final Rect cropPx;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropPx)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropScrimPainter old) => old.cropPx != cropPx;
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), border);
    final grid = Paint()
      ..color = Colors.white54
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Freehand draw over a photo. Strokes are captured in normalized (0..1)
/// coordinates over the displayed (rotated) image; on Done we composite the
/// image + strokes at full pixel resolution via dart:ui and return a PNG the
/// editor adopts as the working file (WYSIWYG — the same fraction-of-width
/// stroke scale is used in the preview painter and the bake).
class _DrawStroke {
  _DrawStroke(this.color, this.width);
  final Color color;
  final double width; // fraction of image width
  final List<Offset> points = <Offset>[]; // normalized 0..1
}

class _DrawPage extends StatefulWidget {
  const _DrawPage({
    required this.file,
    required this.quarterTurns,
    required this.imageWidth,
    required this.imageHeight,
  });

  final File file;
  final int quarterTurns;
  final int imageWidth;
  final int imageHeight;

  @override
  State<_DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<_DrawPage> {
  final List<_DrawStroke> _strokes = <_DrawStroke>[];
  _DrawStroke? _current;
  Color _color = const Color(0xFFFF3B30);
  bool _busy = false;
  static const double _strokeWFrac = 0.012;

  static const List<Color> _palette = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
  ];

  double get _displayAR {
    final rot = widget.quarterTurns.isOdd;
    final w = (rot ? widget.imageHeight : widget.imageWidth).toDouble();
    final h = (rot ? widget.imageWidth : widget.imageHeight).toDouble();
    if (w <= 0 || h <= 0) return 1;
    return w / h;
  }

  Rect _imageRect(Size size) {
    final ar = _displayAR;
    var w = size.width;
    var h = w / ar;
    if (h > size.height) {
      h = size.height;
      w = h * ar;
    }
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  Offset _toN(Offset local, Rect r) => Offset(
    r.width == 0 ? 0 : ((local.dx - r.left) / r.width).clamp(0.0, 1.0),
    r.height == 0 ? 0 : ((local.dy - r.top) / r.height).clamp(0.0, 1.0),
  );

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(
                      wave1Text(
                        context,
                        ru: 'Отмена',
                        en: 'Cancel',
                        uk: 'Скасувати',
                        es: 'Cancelar',
                        pt: 'Cancelar',
                        ptBr: 'Cancelar',
                        fr: 'Annuler',
                        de: 'Abbrechen',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  PressFeedback(child: IconButton(
                    tooltip: wave1Text(
                      context,
                      ru: 'Отменить штрих',
                      en: 'Undo',
                      uk: 'Скасувати штрих',
                      es: 'Deshacer',
                      pt: 'Desfazer',
                      ptBr: 'Desfazer',
                      fr: 'Annuler le trait',
                      de: 'Rückgängig',
                    ),
                    onPressed: _busy || _strokes.isEmpty ? null : _undo,
                    icon: const Icon(AdaptiveIcons.undo_rounded, color: Colors.white),
                  )),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_done()),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: SecretlySpinner(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            wave1Text(
                              context,
                              ru: 'Готово',
                              en: 'Done',
                              uk: 'Готово',
                              es: 'Listo',
                              pt: 'Concluir',
                              ptBr: 'Concluir',
                              fr: 'Terminé',
                              de: 'Fertig',
                            ),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  final r = _imageRect(size);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) {
                      setState(() {
                        _current = _DrawStroke(_color, _strokeWFrac)
                          ..points.add(_toN(d.localPosition, r));
                        _strokes.add(_current!);
                      });
                    },
                    onPanUpdate: (d) {
                      if (_current == null) return;
                      setState(
                        () => _current!.points.add(_toN(d.localPosition, r)),
                      );
                    },
                    onPanEnd: (_) => _current = null,
                    child: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: r,
                          child: RotatedBox(
                            quarterTurns: widget.quarterTurns,
                            child: Image.file(
                              widget.file,
                              fit: BoxFit.fill,
                              errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
                            ),
                          ),
                        ),
                        Positioned.fromRect(
                          rect: r,
                          child: IgnorePointer(
                            child: CustomPaint(painter: _DrawPainter(_strokes)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: _palette
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? accent : Colors.white24,
                              width: _color == c ? 3 : 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _done() async {
    if (_strokes.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _busy = true);
    final out = await _composite();
    if (!mounted) return;
    if (out != null) {
      Navigator.of(context).pop(out);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<String?> _composite() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final q = widget.quarterTurns % 4;
      final rw = q.isOdd ? src.height : src.width;
      final rh = q.isOdd ? src.width : src.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.save();
      canvas.translate(rw / 2, rh / 2);
      canvas.rotate(q * math.pi / 2);
      canvas.translate(-src.width / 2, -src.height / 2);
      canvas.drawImage(src, Offset.zero, Paint());
      canvas.restore();
      for (final s in _strokes) {
        if (s.points.isEmpty) continue;
        final paint = Paint()
          ..color = s.color
          ..strokeWidth = s.width * rw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (s.points.length == 1) {
          canvas.drawCircle(
            Offset(s.points.first.dx * rw, s.points.first.dy * rh),
            s.width * rw / 2,
            Paint()..color = s.color,
          );
        } else {
          final path = Path();
          for (var i = 0; i < s.points.length; i++) {
            final o = Offset(s.points[i].dx * rw, s.points[i].dy * rh);
            if (i == 0) {
              path.moveTo(o.dx, o.dy);
            } else {
              path.lineTo(o.dx, o.dy);
            }
          }
          canvas.drawPath(path, paint);
        }
      }
      final pic = recorder.endRecording();
      final outImg = await pic.toImage(rw, rh);
      final png = await outImg.toByteData(format: ui.ImageByteFormat.png);
      src.dispose();
      outImg.dispose();
      if (png == null) return null;
      // Re-encode to JPEG so the file is small AND its mime matches what the
      // editor labels it (`_openDraw` sets image/jpeg) — a PNG mislabeled JPEG
      // broke save-to-gallery / server thumbnailing.
      final decoded = img.decodePng(png.buffer.asUint8List());
      final dir = await getTemporaryDirectory();
      final f = File(
        p.join(dir.path, 'edit_draw_${DateTime.now().microsecondsSinceEpoch}.jpg'),
      );
      if (decoded != null) {
        await f.writeAsBytes(img.encodeJpg(decoded, quality: 92), flush: true);
      } else {
        await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
      }
      return f.path;
    } catch (_) {
      return null;
    }
  }
}

class _DrawPainter extends CustomPainter {
  _DrawPainter(this.strokes);
  final List<_DrawStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width * size.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (s.points.length == 1) {
        canvas.drawCircle(
          Offset(s.points.first.dx * size.width, s.points.first.dy * size.height),
          s.width * size.width / 2,
          Paint()..color = s.color,
        );
      } else {
        final path = Path();
        for (var i = 0; i < s.points.length; i++) {
          final o = Offset(
            s.points[i].dx * size.width,
            s.points[i].dy * size.height,
          );
          if (i == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter old) => true;
}
