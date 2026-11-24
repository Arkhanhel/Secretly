// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вид переписки, который человек настраивает ползунками в «Оформлении»
/// (макет «Chat Appearance v2», 20.11.2026): размер текста сообщений и
/// скругление пузырей.
///
/// Значения по умолчанию — ровно прежние числа экрана переписки (текст 16,
/// скругление 20 с «хвостом» 8), поэтому у того, кто ползунки не трогал, не
/// меняется ни пиксель.
///
/// Пузыри узнают значения через [ChatLookScope] — `InheritedNotifier` над
/// всем приложением. Пузырь подписывается, когда читает значение, и
/// перестраивается ТОЛЬКО при смене размера или скругления: ни общей
/// перестройки дерева, ни подписки в каждом из семи видов пузыря.
///
/// Хранится на устройстве (`shared_preferences`), как стиль значков.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatLookPrefs {
  const ChatLookPrefs._();

  static const String fontSizeKey = 'chat_text_size_v1';
  static const String radiusKey = 'chat_bubble_radius_v1';

  static const double defaultFontSize = 16;
  static const double minFontSize = 12;
  static const double maxFontSize = 21;

  static const double defaultRadius = 20;
  static const double minRadius = 4;
  static const double maxRadius = 24;

  /// «Хвост» пузыря — угол со стороны отправителя: не круглее этого.
  static const double tailRadius = 8;

  static final ValueNotifier<double> fontSize = ValueNotifier<double>(
    defaultFontSize,
  );
  static final ValueNotifier<double> radius = ValueNotifier<double>(
    defaultRadius,
  );

  static final Listenable listenable = Listenable.merge(<Listenable>[
    fontSize,
    radius,
  ]);

  static double _clampFont(double v) =>
      v.isFinite ? v.clamp(minFontSize, maxFontSize).toDouble() : defaultFontSize;

  static double _clampRadius(double v) =>
      v.isFinite ? v.clamp(minRadius, maxRadius).toDouble() : defaultRadius;

  static Future<void> load([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      fontSize.value = _clampFont(p.getDouble(fontSizeKey) ?? defaultFontSize);
      radius.value = _clampRadius(p.getDouble(radiusKey) ?? defaultRadius);
    } catch (_) {
      // Остаются значения по умолчанию — прежний вид переписки.
    }
  }

  /// Меняет размер сразу (превью и пузыри перестраиваются), а сохраняет
  /// только когда [persist] — ползунок пишет на диск один раз, по отпусканию.
  static Future<void> setFontSize(double value, {bool persist = true}) async {
    fontSize.value = _clampFont(value);
    if (persist) await _save(fontSizeKey, fontSize.value);
  }

  static Future<void> setRadius(double value, {bool persist = true}) async {
    radius.value = _clampRadius(value);
    if (persist) await _save(radiusKey, radius.value);
  }

  static Future<void> reset() async {
    fontSize.value = defaultFontSize;
    radius.value = defaultRadius;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(fontSizeKey);
      await p.remove(radiusKey);
    } catch (_) {}
  }

  static Future<void> _save(String key, double value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(key, value);
    } catch (_) {
      // Значение уже на экране; сохранение — по возможности.
    }
  }

  @visibleForTesting
  static void debugReset() {
    fontSize.value = defaultFontSize;
    radius.value = defaultRadius;
  }
}

/// Раздаёт [ChatLookPrefs] пузырям. Ставится один раз над приложением.
class ChatLookScope extends InheritedNotifier<Listenable> {
  ChatLookScope({super.key, required super.child})
    : super(notifier: ChatLookPrefs.listenable);

  /// Подписывает [context] на изменения, если область стоит выше; без неё
  /// (тесты, отдельные окна) просто читает текущие значения.
  static void _watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<ChatLookScope>();
  }
}

/// Размер текста сообщения.
double chatMessageFontSize(BuildContext context) {
  ChatLookScope._watch(context);
  return ChatLookPrefs.fontSize.value;
}

/// Скругление пузыря: три угла — выбранный радиус, угол со стороны
/// отправителя («хвост») — не больше [ChatLookPrefs.tailRadius]. [scale]
/// уменьшает всё пропорционально (для превью).
BorderRadius chatBubbleRadius(
  BuildContext context,
  bool isMe, {
  double scale = 1,
}) {
  ChatLookScope._watch(context);
  final r = ChatLookPrefs.radius.value * scale;
  final tail = math.min(ChatLookPrefs.tailRadius * scale, r);
  return BorderRadius.only(
    topLeft: Radius.circular(r),
    topRight: Radius.circular(r),
    bottomLeft: Radius.circular(isMe ? r : tail),
    bottomRight: Radius.circular(isMe ? tail : r),
  );
}
