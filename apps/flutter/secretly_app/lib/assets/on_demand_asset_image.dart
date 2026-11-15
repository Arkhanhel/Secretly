// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Картинка украшения: из пакета или из скачанной копии (Э7).
///
/// 🔴 ПОСТАВЩИК КАРТИНКИ, А НЕ ВИДЖЕТ, И ЭТО РЕШАЕТ ВСЁ. Обои чата отдаются
/// наружу как `ImageProvider` и попадают и в `DecorationImage` ленты, и в
/// плитки выбора, и в окна компьютера. Будь здесь виджет, каждое из этих мест
/// пришлось бы переписывать, и забытое означало бы пустоту вместо обоев.
/// Поставщик подменяется одной строкой там, где раньше стоял `AssetImage`.
///
/// Поведение полной сборки не меняется: файл находится в пакете на первом
/// шаге, и ни сети, ни диска здесь не касаются. Отказ тихий — поток картинки
/// сообщает об ошибке, и место показа решает само (глиф вместо значка, ровный
/// цвет вместо обоев).
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'on_demand_assets.dart';

/// Картинка по пути ассета, с добором по требованию.
@immutable
class OnDemandAssetImage extends ImageProvider<OnDemandAssetImage> {
  const OnDemandAssetImage(this.assetPath, {this.scale = 1.0});

  final String assetPath;
  final double scale;

  @override
  Future<OnDemandAssetImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OnDemandAssetImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OnDemandAssetImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.assetPath,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('on-demand asset: ${key.assetPath}'),
      ],
    );
  }

  Future<ui.Codec> _load(
    OnDemandAssetImage key,
    ImageDecoderCallback decode,
  ) async {
    final assets = OnDemandAssets.instance;
    if (assets == null) {
      // Загрузчик не настроен (компьютер, тесты) — обычный путь через пакет.
      return _decodeBundle(key, decode);
    }
    final result = await assets.load(key.assetPath);
    final bytes = result.bytes;
    if (bytes == null) {
      throw StateError('on-demand asset unavailable: ${key.assetPath}');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  Future<ui.Codec> _decodeBundle(
    OnDemandAssetImage key,
    ImageDecoderCallback decode,
  ) async {
    final data = await rootBundle.load(key.assetPath);
    return decode(
      await ui.ImmutableBuffer.fromUint8List(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OnDemandAssetImage &&
      other.assetPath == assetPath &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(assetPath, scale);

  @override
  String toString() => 'OnDemandAssetImage("$assetPath")';
}
