// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../calls/call_audio_route.dart';
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';

/// Сочетание клавиш так, как его пишет своя система: «⌘D» на Mac и «Ctrl+D»
/// на Windows.
///
/// 🔴 Подсказки звонка обещали «⌘D», «⌘E», «⌘W» — готовой строкой в
/// переводах, одинаковой для обеих систем, — а самих сочетаний не было
/// нигде. На Windows подсказка к тому же называла клавишу, которой на её
/// клавиатуре нет. Теперь сочетания настоящие (см. окна звонков), а подпись
/// собирается здесь.
String callShortcutLabel(String key) {
  if (key == 'Esc') return key;
  return (!kIsWeb && Platform.isMacOS) ? '⌘$key' : 'Ctrl+$key';
}

/// Подсказка кнопки с её сочетанием через три пробела — как в меню.
String callTooltipWithShortcut(String action, String key) =>
    '$action   ${callShortcutLabel(key)}';

/// Панель кнопок звонка — приподнятая карточка под сценой.
///
/// 🔴 ОДНА НА ОБА ЗВОНКА. Звонок один на один рисовал свою полосу кружков
/// без подписей, групповой созвон — карточку с подписями. Человек, который
/// звонит и так, и так, учил два пульта, а кнопки «свернуть» не было ни в
/// одном из них.
class CallDock extends StatelessWidget {
  const CallDock({super.key, required this.children, this.expand = false});

  final List<Widget> children;

  /// Во всю ширину сцены (групповой созвон — по макету) или по кнопкам
  /// (звонок один на один: карточка висит над картинкой и не должна её
  /// перечёркивать от края до края).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.lg),
        border: Border.all(color: c.textPrimary.withValues(alpha: 0.07)),
        // Тень — по теме: густая тень тёмной темы на светлом фоне ложилась
        // под карточкой серой плитой.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.10),
            blurRadius: c.isDark ? 44 : 24,
            offset: Offset(0, c.isDark ? 20 : 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// Черта в доке: отделяет «закончить разговор» от остальных кнопок.
class CallDockDivider extends StatelessWidget {
  const CallDockDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: c.textPrimary.withValues(alpha: 0.10),
    );
  }
}

/// Кнопка дока: значок и подпись, при надобности — шеврон выбора устройства.
///
/// Подпись — не украшение. Во время созвона кнопку ищут глазами и за секунду;
/// перечёркнутый прямоугольник без слова «Экран» одинаково похож на «выключить
/// видео» и на «остановить показ», и узнать разницу можно было только наведя
/// мышь и дождавшись подсказки.
class CallDockToggle extends StatelessWidget {
  const CallDockToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.on,
    required this.enabled,
    required this.onTap,
    this.danger = false,
    this.highlighted = false,
    this.neutralWhenOff = false,
    this.onExpand,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  /// Возможность ВКЛЮЧЕНА сейчас (микрофон открыт, камера идёт).
  final bool on;
  final bool enabled;
  final bool danger;

  /// Идёт то, что человек включил сам и должен видеть издалека: показ экрана.
  final bool highlighted;

  /// Выключенное — не тревога. Камера в голосовом звонке выключена не по
  /// сбою, а по сути звонка: красить её красным — пугать без причины.
  final bool neutralWhenOff;
  final VoidCallback onTap;

  /// Шеврон справа: открывает список устройств. `null` — кнопка простая.
  ///
  /// 🔴 Шеврон СВОЙ отдельной кнопкой, а не частью нажатия. Нажать на
  /// микрофон во время созвона нужно быстро и не глядя; если то же нажатие
  /// иногда открывает список, человек промахнётся ровно в тот момент, когда
  /// хотел просто замолчать.
  final void Function(BuildContext anchorContext)? onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    // Выключенная возможность — красноватая, включённая — обычная: во время
    // созвона тревожит именно «меня не слышно», а не «микрофон работает».
    final tone = danger
        ? c.danger
        : highlighted
        ? Colors.white
        : (on || neutralWhenOff ? c.textPrimary : c.danger);
    // 🔴 ЗАЛИВКА — ОТ ЦВЕТА ТЕКСТА ТЕМЫ, А НЕ БЕЛАЯ. Белая плёнка по белой
    // карточке светлой темы не видна вовсе: кнопки дока в светлой теме
    // выглядели надписями без кнопок и не отзывались на наведение.
    Color fill(bool hovered, bool pressed) {
      if (danger) return c.danger.withValues(alpha: pressed ? 0.28 : 0.16);
      if (highlighted) {
        return c.accentPrimary.withValues(
          alpha: pressed ? 0.95 : (hovered ? 0.88 : 0.78),
        );
      }
      return c.textPrimary.withValues(
        alpha: pressed ? 0.12 : (hovered ? 0.08 : 0.05),
      );
    }

    final button = DesktopTooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: danger ? null : on,
        label: label,
        child: HoverListener(
          onTap: enabled ? onTap : null,
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          builder: (ctx, hovered, pressed) => AnimatedContainer(
            duration: DMotion.fast,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: fill(hovered, pressed),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: tone),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: DType.tiny.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: danger
                          ? c.danger
                          : (highlighted ? Colors.white : c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onExpand == null) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: 2),
        Builder(
          builder: (anchor) => DesktopTooltip(
            message: l10n.desktopCallPickDevice,
            child: HoverListener(
              onTap: enabled ? () => onExpand!(anchor) : null,
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              builder: (ctx, hovered, pressed) => AnimatedContainer(
                duration: DMotion.fast,
                width: 28,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.textPrimary.withValues(
                    alpha: pressed ? 0.12 : (hovered ? 0.08 : 0.05),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: Icon(
                    FluentIcons.chevron_up_20_filled,
                    size: 14,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Меню раскрывается ВВЕРХ от кнопки.
///
/// 🔴 Проверено живьём: док стоит у нижнего края окна, и список,
/// раскрытый вниз, ложился ПОВЕРХ самих кнопок дока — выбираешь динамик, а
/// под пальцем «Выйти».
///
/// Высота считается той же формулой, что и внутри `ContextMenu` (32 на пункт
/// плюс поля): меню умеет прижиматься к экрану, но не умеет раскрываться
/// вверх, а якорь — единственное, чем это задаётся снаружи.
Offset callMenuAnchorAbove(BuildContext anchorContext, int itemCount) {
  final box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null) return Offset.zero;
  final origin = box.localToGlobal(Offset.zero);
  final height = itemCount * 32.0 + 12;
  return Offset(origin.dx, (origin.dy - height - 8).clamp(8.0, origin.dy));
}

/// Значок устройства вывода звука в списке выбора.
IconData callAudioRouteIcon(CallAudioRouteKind kind) {
  switch (kind) {
    case CallAudioRouteKind.bluetooth:
      return FluentIcons.bluetooth_24_regular;
    case CallAudioRouteKind.wiredHeadset:
      return FluentIcons.headphones_24_regular;
    case CallAudioRouteKind.earpiece:
      return FluentIcons.call_24_regular;
    case CallAudioRouteKind.speaker:
      return FluentIcons.speaker_2_24_regular;
    case CallAudioRouteKind.unknown:
      return FluentIcons.speaker_2_24_regular;
  }
}
