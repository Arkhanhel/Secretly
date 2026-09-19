// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// МОСТ К СИСТЕМНОМУ ПОКАЗУ PDF (macOS).
///
/// 🔴 ПОЧЕМУ СИСТЕМОЙ, А НЕ БИБЛИОТЕКОЙ. Библиотека для PDF потянула бы движок
/// вроде pdfium — десятки мегабайт в КАЖДОЙ сборке, включая мобильную, а она
/// выпущена и заморожена. PDFKit уже есть в macOS: ни веса, ни зависимости.
///
/// Страницы рисуются по одной, по запросу: документ на пятьсот страниц не
/// должен занимать память целиком. Всё считается на самом компьютере.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class DesktopPdfBridge {
  DesktopPdfBridge._();

  static const MethodChannel channel = MethodChannel('secretly/pdf_render');

  /// Умеет ли эта система показать PDF сама.
  ///
  /// 🔴 Сейчас только macOS: там рисует системный PDFKit. У Windows свой
  /// встроенный движок PDF, но к нему нужен свой мост в приложении-обёртке;
  /// пока его нет, PDF там открывается внешней программой, как раньше.
  /// Показать пустое окно вместо документа было бы хуже прежнего.
  static bool get isAvailable => !kIsWeb && Platform.isMacOS;

  /// Сколько страниц в документе; `null` — файл не читается как PDF или
  /// система показа недоступна (не macOS).
  static Future<int?> pageCount(String path) async {
    try {
      final pages = await channel.invokeMethod<int>('info', <String, Object?>{
        'path': path,
      });
      if (pages == null || pages <= 0) return null;
      return pages;
    } catch (_) {
      return null;
    }
  }

  /// Страница [page] (с нуля) картинкой PNG шириной не больше [maxWidth].
  static Future<Uint8List?> renderPage({
    required String path,
    required int page,
    double maxWidth = 1200,
  }) async {
    try {
      final data = await channel.invokeMethod<Uint8List>(
        'render',
        <String, Object?>{
          'path': path,
          'page': page,
          'maxWidth': maxWidth,
        },
      );
      if (data == null || data.isEmpty) return null;
      return data;
    } catch (_) {
      return null;
    }
  }
}
