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
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:secretly_app/ui/video_trim_editor_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import 'icons/app_icons.dart';
import 'l10n.dart';
import 'recent_attachments_store.dart';
import 'widgets/island_backdrop.dart';
import 'theme_presets.dart';
import 'wave1_l10n.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/broken_media_box.dart';

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

class ChatAttachmentPickerMediaItem {
  const ChatAttachmentPickerMediaItem({
    required this.path,
    required this.kind,
    this.mime,
    this.caption = '',
  });

  final String path;
  final ChatAttachmentPickerMediaKind kind;
  final String? mime;

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
  ChatAttachmentPickerResult.photos(List<ChatAttachmentPickerMediaItem> items)
    : kind = ChatAttachmentPickerResultKind.photos,
      mediaItems = List<ChatAttachmentPickerMediaItem>.unmodifiable(items),
      filePaths = List<String>.unmodifiable(
        items.map((item) => item.path).toList(growable: false),
      ),
      fileName = null;

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
      fileName = null;

  ChatAttachmentPickerResult.file(String filePath, {String? fileName})
    : kind = ChatAttachmentPickerResultKind.file,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = List<String>.unmodifiable(<String>[filePath]),
      fileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : null;

  ChatAttachmentPickerResult.audio(String filePath)
    : kind = ChatAttachmentPickerResultKind.audio,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = List<String>.unmodifiable(<String>[filePath]),
      fileName = null;

  ChatAttachmentPickerResult.poll()
    : kind = ChatAttachmentPickerResultKind.poll,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null;

  ChatAttachmentPickerResult.topic()
    : kind = ChatAttachmentPickerResultKind.topic,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null;

  ChatAttachmentPickerResult.event()
    : kind = ChatAttachmentPickerResultKind.event,
      mediaItems = const <ChatAttachmentPickerMediaItem>[],
      filePaths = const <String>[],
      fileName = null;

  final ChatAttachmentPickerResultKind kind;
  final List<ChatAttachmentPickerMediaItem> mediaItems;
  final List<String> filePaths;

  /// Original file name (e.g. "report.pdf") for the [file] result, captured
  /// from the picker (PlatformFile.name) so the chat shows the real name +
  /// format. Null for non-file results.
  final String? fileName;

  String? get primaryPath => filePaths.isEmpty ? null : filePaths.first;
  ChatAttachmentPickerMediaItem? get primaryMediaItem =>
      mediaItems.isEmpty ? null : mediaItems.first;
}

Future<ChatAttachmentPickerResult?> showChatAttachmentPickerSheet(
  BuildContext context, {
  bool showPoll = false,
  bool showTopic = false,
  bool showEvent = false,
}) {
  return showModalBottomSheet<ChatAttachmentPickerResult>(
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
    ),
  );
}

enum _AttachmentPickerTab { photo, file, music }

class _ChatAttachmentPickerSheet extends StatefulWidget {
  const _ChatAttachmentPickerSheet({
    this.showPoll = false,
    this.showTopic = false,
    this.showEvent = false,
  });

  final bool showPoll;
  final bool showTopic;
  final bool showEvent;

  @override
  State<_ChatAttachmentPickerSheet> createState() =>
      _ChatAttachmentPickerSheetState();
}

class _ChatAttachmentPickerSheetState
    extends State<_ChatAttachmentPickerSheet> {
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
  final Map<String, Future<Uint8List?>> _galleryThumbnailFutures =
      <String, Future<Uint8List?>>{};
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
    unawaited(_loadGalleryAssets());
    unawaited(_initializeCameraPreview());
  }

  @override
  void dispose() {
    final cameraController = _cameraController;
    _cameraController = null;
    if (cameraController != null) {
      unawaited(cameraController.dispose());
    }
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
        );
      }
    }
    final file = await asset.file;
    if (file == null || !await file.exists()) return null;
    return ChatAttachmentPickerMediaItem(
      path: file.path,
      kind: _galleryMediaKind(asset),
      mime: _mimeForPath(file.path),
      caption: caption,
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

    if (mounted) {
      setState(() {
        _galleryLoading = true;
        _galleryPermissionDenied = false;
      });
    }

    try {
      final granted = await _requestGalleryPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _galleryLoading = false;
          _galleryPermissionDenied = true;
        });
        return;
      }

      final filterOption = FilterOptionGroup(
        orders: const <OrderOption>[
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: true,
        filterOption: filterOption,
      );
      final album = paths.isNotEmpty ? paths.first : null;
      if (album == null) {
        if (!mounted) return;
        setState(() {
          _galleryAlbum = null;
          _galleryAssets.clear();
          _galleryThumbnailFutures.clear();
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

      if (!mounted) return;
      setState(() {
        _galleryAlbum = album;
        _galleryAssets
          ..clear()
          ..addAll(mediaAssets);
        _galleryThumbnailFutures.clear();
        _galleryNextPage = 1;
        _galleryHasMore = firstPage.length >= _galleryPageSize;
        _galleryLoadingMore = false;
        _galleryLoading = false;
        _galleryPermissionDenied = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galleryLoading = false;
        _galleryLoadingMore = false;
        _galleryPermissionDenied = true;
      });
    }
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
    if (mounted) {
      setState(() => _galleryLoadingMore = true);
    }

    try {
      final nextPage = await album.getAssetListPaged(
        page: page,
        size: _galleryPageSize,
      );
      final mediaAssets = nextPage
          .where(_isGalleryMediaAsset)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        final knownIds = _galleryAssets.map((asset) => asset.id).toSet();
        for (final asset in mediaAssets) {
          if (knownIds.add(asset.id)) {
            _galleryAssets.add(asset);
          }
        }
        _galleryNextPage = page + 1;
        _galleryHasMore = nextPage.length >= _galleryPageSize;
        _galleryLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galleryLoadingMore = false;
      });
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
      final selected = _galleryAssets
          .where((asset) => _selectedPhotoIds.contains(asset.id))
          .toList(growable: false);
      final mediaItems = <ChatAttachmentPickerMediaItem>[];
      for (final asset in selected) {
        final mediaItem = await _resolveGalleryMediaItem(
          asset,
          caption: _captionByAssetId[asset.id]?.trim() ?? '',
          editedPath: _editedPathByAssetId[asset.id],
        );
        if (mediaItem == null) continue;
        mediaItems.add(mediaItem);
      }
      if (!mounted || mediaItems.isEmpty) return;
      Navigator.of(context).pop(
        _sendPhotosAsFiles
            ? ChatAttachmentPickerResult.filesFromGallery(mediaItems)
            : ChatAttachmentPickerResult.photos(mediaItems),
      );
    } finally {
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
        allowMultiple: false,
        withData: false,
      );
      final file = picked?.files.single;
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
    final sendButtonBottom = tabChipsBottom + (_overlayHidden ? 6 : 58);

    return DraggableScrollableSheet(
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
          child: SafeArea(
            top: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildBody(scrollController)),
                  const Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(child: SecretlyGlassSheetHandle()),
                  ),
                  Positioned(
                    top: 16,
                    right: 14,
                    child: _buildGlassIconButton(
                      icon: AppIcons.close,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
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
                          curve: Curves.easeOutCubic,
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
                  if (_currentTab == _AttachmentPickerTab.photo &&
                      _selectedPhotoIds.isNotEmpty)
                    Positioned(
                      right: 14,
                      bottom: sendButtonBottom,
                      child: _buildSendSelectionButton(
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
                              child: CircularProgressIndicator(
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
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (_galleryPermissionDenied) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 66, 14, 110),
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
        return GridView.builder(
          controller: scrollController,
          // Extra top clearance so the first row clears the floating handle +
          // close button (which previously overlapped the top-right thumbnail).
          padding: const EdgeInsets.fromLTRB(2, 66, 2, 114),
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
          padding: const EdgeInsets.fromLTRB(10, 66, 10, 114),
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
              Icon(Icons.add_rounded, size: 20, color: cs.primary),
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
                  Icons.north_east_rounded,
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
                  Icons.north_east_rounded,
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
      padding: const EdgeInsets.fromLTRB(10, 66, 10, 114),
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

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.58),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  icon,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendSelectionButton({
    required Color actionTop,
    required Color actionBottom,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[actionTop, actionBottom],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: actionBottom.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _busy ? null : _confirmPhotoSelection,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(AppIcons.send, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${context.l10n.send} ${_selectedPhotoIds.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
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
                      child: CircularProgressIndicator(
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

    void toggleSelection() {
      setState(() {
        if (_selectedPhotoIds.contains(asset.id)) {
          _selectedPhotoIds.remove(asset.id);
        } else {
          _selectedPhotoIds.add(asset.id);
        }
      });
    }

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
                    opaque: true,
                    barrierColor: Colors.black,
                    pageBuilder: (_, __, ___) => _AssetPreviewPage(
                      asset: asset,
                      isSelected: () =>
                          _selectedPhotoIds.contains(asset.id),
                      onToggle: toggleSelection,
                      localize: _t,
                      initialCaption: _captionByAssetId[asset.id] ?? '',
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
                final item = ChatAttachmentPickerMediaItem(
                  path: req.path,
                  kind: isVideo
                      ? ChatAttachmentPickerMediaKind.video
                      : ChatAttachmentPickerMediaKind.image,
                  mime: req.mime ??
                      (req.trimmed
                          ? 'video/mp4'
                          : (asset.mimeType ??
                                (isVideo ? 'video/mp4' : 'image/jpeg'))),
                  caption: req.caption,
                );
                Navigator.of(context).pop(
                  ChatAttachmentPickerResult.photos(
                    <ChatAttachmentPickerMediaItem>[item],
                  ),
                );
              },
        child: Ink(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildPhotoThumbnail(asset),
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

  Widget _buildPhotoThumbnail(AssetEntity asset) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: _galleryThumbnailFutures.putIfAbsent(
        asset.id,
        () => asset.thumbnailDataWithSize(
          const ThumbnailSize(320, 320),
          quality: 80,
        ),
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DecoratedBox(
            decoration: BoxDecoration(color: colors.surfaceContainerHighest),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(color: colors.surfaceContainerHighest),
          child: Icon(
            AppIcons.brokenImage,
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        );
      },
    );
  }

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
            IconButton(
              onPressed: _busy
                  ? null
                  : () {
                      unawaited(onTrailingTap());
                    },
              icon: Icon(trailingIcon),
            ),
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
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Top bar: close + recording indicator.
          Positioned(
            top: media.padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed:
                      _recording ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
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
                          ? IconButton(
                              onPressed: _busy ? null : () => _flipCamera(),
                              icon: const Icon(
                                Icons.cameraswitch_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            )
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
  }) : sendAll = false;

  /// The user hit Send with MORE than one asset selected — the picker sends the
  /// whole selection, applying each asset's persisted caption. (Per-asset video
  /// trim / rotation are only honoured in the single-asset path.)
  const _AssetEditorSendRequest.sendAll()
    : path = '',
      caption = '',
      trimmed = false,
      mime = null,
      sendAll = true;

  final String path;
  final String caption;
  final bool trimmed;

  /// Overrides the item mime when the editor re-encoded the file (a rotated
  /// photo is baked to JPEG). Null = keep the asset's original mime.
  final String? mime;
  final bool sendAll;
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
  });

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
  bool _muted = false;
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

  @override
  void initState() {
    super.initState();
    _caption.text = widget.initialCaption;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final f = await widget.asset.file;
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
        // True ORIENTED dimensions (EXIF-applied), for correct crop/draw AR.
        try {
          final codec = await ui.instantiateImageCodec(await f.readAsBytes());
          final frame = await codec.getNextFrame();
          final iw = frame.image.width;
          final ih = frame.image.height;
          frame.image.dispose();
          if (mounted) {
            setState(() {
              _workW = iw;
              _workH = ih;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _workW = widget.asset.width;
              _workH = widget.asset.height;
            });
          }
        }
      }
      if (_isVideo) {
        final v = VideoPlayerController.file(f);
        _video = v;
        await v.initialize();
        await v.setLooping(false);
        v.addListener(_onVideoTick);
        if (!mounted) {
          await v.dispose();
          return;
        }
        setState(() {
          _durationMs = v.value.duration.inMilliseconds;
          _startMs = 0;
          _endMs = _durationMs;
        });
        unawaited(v.play());
        unawaited(
          videoTrimFilmstripFrames(f.path).then((frames) {
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

  Future<void> _openCrop() async {
    final file = _file;
    if (file == null) return;
    final rect = await Navigator.of(context).push<Rect>(
      MaterialPageRoute<Rect>(
        fullscreenDialog: true,
        builder: (_) => _CropPage(
          file: file,
          quarterTurns: _rotationQuarter,
          imageWidth: _workW,
          imageHeight: _workH,
          localize: widget.localize,
        ),
      ),
    );
    if (rect == null || !mounted) return;
    setState(() => _exporting = true);
    final baked = await _bakeViaUi(
      file,
      quarterTurns: _rotationQuarter,
      cropNorm: rect,
    );
    if (!mounted) return;
    if (baked == null) {
      setState(() => _exporting = false);
      return;
    }
    final len = await File(baked.$1).length();
    if (!mounted) return;
    setState(() {
      _file = File(baked.$1);
      _fileBytes = len;
      _workW = baked.$2; // baked file is already rotated + oriented
      _workH = baked.$3;
      _rotationQuarter = 0;
      _bakedToJpeg = true;
      _exporting = false;
    });
  }

  Future<void> _openDraw() async {
    final file = _file;
    if (file == null) return;
    final out = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => _DrawPage(
          file: file,
          quarterTurns: _rotationQuarter,
          imageWidth: _workW,
          imageHeight: _workH,
        ),
      ),
    );
    if (out == null || !mounted) return;
    final len = await File(out).length();
    // Refresh working dims from the drawn output (rotation is baked in).
    int? nw;
    int? nh;
    try {
      final codec = await ui.instantiateImageCodec(await File(out).readAsBytes());
      final frame = await codec.getNextFrame();
      nw = frame.image.width;
      nh = frame.image.height;
      frame.image.dispose();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _file = File(out);
      _fileBytes = len;
      if (nw != null && nh != null) {
        _workW = nw;
        _workH = nh;
      }
      _rotationQuarter = 0;
      _bakedToJpeg = true;
    });
  }

  @override
  void dispose() {
    // Keep whatever caption was typed for this asset (backing out must not lose
    // it — the multi-photo flow relies on captions persisting in the picker).
    widget.onPersistCaption(widget.asset.id, _caption.text.trim());
    final v = _video;
    _video = null;
    if (v != null) {
      v.removeListener(_onVideoTick);
      unawaited(v.dispose());
    }
    _caption.dispose();
    super.dispose();
  }

  String _metaLine() {
    final w = widget.asset.width;
    final h = widget.asset.height;
    final parts = <String>[];
    if (w > 0 && h > 0) parts.add('${w}x$h');
    if (_isVideo && _durationMs > 0) {
      final effective = (_endMs - _startMs).clamp(0, _durationMs);
      final total = (effective / 1000).round();
      final m = total ~/ 60;
      final sec = (total % 60).toString().padLeft(2, '0');
      parts.add('$m:$sec');
    }
    if (_fileBytes > 0) {
      final mb = _fileBytes / (1024 * 1024);
      parts.add('~${mb.toStringAsFixed(1)} MB');
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final selected = widget.isSelected();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
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
                child: _loadFailed
                    ? const Icon(
                        AppIcons.brokenImage,
                        color: Colors.white70,
                        size: 44,
                      )
                    : _file == null
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _isVideo
                    ? (video != null && video.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: video.value.aspectRatio <= 0
                                  ? 16 / 9
                                  : video.value.aspectRatio,
                              child: VideoPlayer(video),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white,
                            ))
                    : InteractiveViewer(
                        minScale: 0.9,
                        maxScale: 5,
                        child: RotatedBox(
                          quarterTurns: _rotationQuarter,
                          child: Image.file(
                            _file!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
                          ),
                        ),
                      ),
              ),
            ),
          ),
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
                    Icons.play_arrow_rounded,
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
                  child: IconButton(
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _metaLine(),
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
                      child: Icon(
                        Icons.check_rounded,
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
          // ---------- низ: [звук + трим-лента] + подпись + отправка ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: (bottomInset > 0 ? bottomInset : safeBottom) + 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isVideo &&
                    video != null &&
                    video.value.isInitialized) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _muted = !_muted);
                            unawaited(video.setVolume(_muted ? 0 : 1));
                          },
                          child: _roundGlass(
                            size: 38,
                            child: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: VideoTrimTrack(
                      durationMs: _durationMs,
                      startMs: _startMs,
                      endMs: _endMs,
                      minTrimMs: _minTrimMs,
                      frames: _frames,
                      positionMs: video.value.position.inMilliseconds,
                      onChanged: _onTrimChanged,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _editToolbar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: islandBackdropFilter(
                              sigmaX: 20,
                              sigmaY: 20,
                            ),
                            child: Container(
                              // Island recipe over media: vibrancy blur + a soft
                              // top→bottom tint (kept dark enough for white text
                              // to stay legible over bright photos) + a specular
                              // top-edge highlight + hairline border.
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.26),
                                    Colors.black.withValues(alpha: 0.40),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              foregroundDecoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _caption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                cursorColor:
                                    Theme.of(context).colorScheme.primary,
                                decoration: InputDecoration(
                                  hintText: wave1Text(
                                    context,
                                    ru: 'Добавить подпись...',
                                    en: 'Add a caption...',
                                    uk: 'Додати підпис...',
                                    es: 'Añadir descripción...',
                                    pt: 'Adicionar legenda...',
                                    ptBr: 'Adicionar legenda...',
                                    fr: 'Ajouter une légende...',
                                    de: 'Beschriftung hinzufügen...',
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                ),
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 1,
                                maxLines: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _exporting ? null : () => unawaited(_send()),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.26),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _exporting
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  AppIcons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundGlass({required Widget child, double size = 44}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Bottom edit-tools island — a glass pill in our style (matte blur, soft
  /// white border), sized/positioned like the reference screenshots. Only
  /// FUNCTIONAL tools are shown (no dead buttons): today = photo rotate. Crop /
  /// draw / adjust and the video cover picker land here in later passes.
  Widget _editToolbar() {
    final tools = <Widget>[];
    if (_isPhoto) {
      tools.add(
        _toolButton(
          icon: Icons.crop_rounded,
          tooltip: wave1Text(
            context,
            ru: 'Кадрировать',
            en: 'Crop',
            uk: 'Кадрувати',
            es: 'Recortar',
            pt: 'Cortar',
            ptBr: 'Cortar',
            fr: 'Rogner',
            de: 'Zuschneiden',
          ),
          onTap: _exporting ? null : () => unawaited(_openCrop()),
        ),
      );
      tools.add(
        _toolButton(
          icon: Icons.rotate_right_rounded,
          tooltip: wave1Text(
            context,
            ru: 'Повернуть',
            en: 'Rotate',
            uk: 'Повернути',
            es: 'Girar',
            pt: 'Girar',
            ptBr: 'Girar',
            fr: 'Pivoter',
            de: 'Drehen',
          ),
          onTap: _exporting
              ? null
              : () => setState(
                  () => _rotationQuarter = (_rotationQuarter + 1) % 4,
                ),
        ),
      );
      tools.add(
        _toolButton(
          icon: Icons.brush_rounded,
          tooltip: wave1Text(
            context,
            ru: 'Рисовать',
            en: 'Draw',
            uk: 'Малювати',
            es: 'Dibujar',
            pt: 'Desenhar',
            ptBr: 'Desenhar',
            fr: 'Dessiner',
            de: 'Zeichnen',
          ),
          onTap: _exporting ? null : () => unawaited(_openDraw()),
        ),
      );
    }
    if (tools.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: tools),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      icon: Icon(icon, color: Colors.white, size: 21),
    );
  }
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
                  IconButton(
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
                    icon: const Icon(Icons.undo_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_done()),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
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
