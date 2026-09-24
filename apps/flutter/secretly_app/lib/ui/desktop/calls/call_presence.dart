// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

/// Как показан идущий звонок на компьютере: во всё окно или мини-окном.
///
/// 🔴 ЗАЧЕМ (24.09.2026, владелец: «не могу никак скрыть этот звонок или
/// свернуть в мини окно, чтобы пользоваться дальше приложением»). Звонок
/// один на один закрывал окно целиком, и свернуть его было нечем: написать
/// кому-то посреди разговора можно было, только положив трубку. Окно
/// группового созвона сворачивалось, но от разговора оставалась полоса
/// в одну строку — ни лиц, ни того, кто говорит.
///
/// Теперь у обоих звонков два вида: во всё окно и мини-окно поверх
/// приложения. Здесь — только то, КАКОЙ вид сейчас: сам звонок живёт в своих
/// управляющих, и этот признак ничего в нём не меняет.
///
/// 🔴 ОТДЕЛЬНОГО ОКНА СИСТЕМЫ ЗДЕСЬ НЕТ, И ЭТО РЕШЕНИЕ. Второе окно — это
/// второй движок Flutter, а картинка камеры живёт в первом и во второй не
/// переносится: мини-окно звонка было бы без видео. Многооконность самого
/// Flutter пока помечена «не для выпуска». Мини-окно плавает поверх всех
/// разделов этого окна, его можно утащить в любой угол.
class DesktopCallPresence {
  DesktopCallPresence._();

  static final DesktopCallPresence instance = DesktopCallPresence._();

  /// Звонок один на один свёрнут в мини-окно.
  final ValueNotifier<bool> directMinimized = ValueNotifier<bool>(false);

  String _directCallId = '';

  /// Сверить вид со звонком. Зовётся на каждом изменении звонка.
  ///
  /// Новый звонок открывается во всё окно, даже если прошлый был свёрнут:
  /// входящий, принятый из всплывашки, не должен прятаться в угол только
  /// потому, что так закончился предыдущий разговор.
  void syncDirect({required bool active, required String callId}) {
    if (!active) {
      _directCallId = '';
      directMinimized.value = false;
      return;
    }
    if (callId != _directCallId) {
      _directCallId = callId;
      directMinimized.value = false;
    }
  }

  void minimizeDirect() => directMinimized.value = true;

  void expandDirect() => directMinimized.value = false;

  /// Комната, чьё окно созвона сейчас открыто поверх приложения.
  ///
  /// Пока оно открыто, мини-окна этого созвона нет: одно и то же не
  /// показывают в двух местах.
  final ValueNotifier<String?> roomWindowOpen = ValueNotifier<String?>(null);

  Object? _roomWindowOwner;

  /// Окно созвона открылось. [owner] — само окно: по нему закрытие узнаёт,
  /// своё ли оно закрывает.
  void roomWindowOpened(String roomId, Object owner) {
    _roomWindowOwner = owner;
    roomWindowOpen.value = roomId;
  }

  /// Окно закрыли или свернули.
  ///
  /// 🔴 Закрывает только СВОЁ. Старое окно уходит не сразу — сначала
  /// доигрывает анимация, — и если за это время созвон успели развернуть
  /// снова, запоздалое «закрылось» от старого окна не должно гасить новое.
  void roomWindowClosed(Object owner) {
    if (!identical(_roomWindowOwner, owner)) return;
    _roomWindowOwner = null;
    roomWindowOpen.value = null;
  }

  final Map<String, String> _roomTitles = <String, String>{};

  /// Запомнить имя комнаты, пока оно известно.
  ///
  /// Имя приходит из открытой переписки. Свернул созвон, ушёл в другой
  /// раздел — и взять его уже неоткуда, а мини-окно и полоса без имени
  /// говорят «созвон» вместо «созвон в такой-то комнате».
  void rememberRoomTitle(String roomId, String title) {
    final t = title.trim();
    if (roomId.trim().isEmpty || t.isEmpty) return;
    _roomTitles[roomId.trim()] = t;
  }

  /// Последнее известное имя комнаты; пусто — не знаем.
  String roomTitle(String roomId) => _roomTitles[roomId.trim()] ?? '';

  @visibleForTesting
  void debugReset() {
    _directCallId = '';
    directMinimized.value = false;
    _roomWindowOwner = null;
    roomWindowOpen.value = null;
    _roomTitles.clear();
  }
}
