// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// СТРОКИ ПРОВЕРОК В «ЗВОНКАХ / ЗВУКЕ И ВИДЕО»: уровень и проверка
/// микрофона, проверочный сигнал динамиков, превью камеры и «Зеркалить моё
/// видео» (ТЗ «ПК как Telegram», §1.4).
///
/// Строки собраны тем же набором, что остальные настройки (поля 14/12,
/// подпись 14/600, пояснение 12,5 третьим тоном), но с одним отличием от
/// [WorkspaceRow]: под подписью может стоять живая полоска или состояние
/// записи, а не только текст.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../services/desktop_audio_output.dart';
import '../services/desktop_call_prefs.dart';
import '../services/desktop_camera_preview.dart';
import '../services/desktop_mic_check.dart';
import 'settings_kit.dart';
import 'settings_style.dart';
import 'workspace_layout.dart';

/// Чем пользуются проверки раздела. Настоящие — [MediaCheckServices.system];
/// тесты подставляют свои.
class MediaCheckServices {
  const MediaCheckServices({
    required this.platform,
    required this.micCapture,
    required this.audioOutput,
    this.cameraEngine = WebRtcCameraPreviewEngine.new,
    this.callActive,
  });

  /// Настоящие проверки своей системы.
  factory MediaCheckServices.system() {
    final platform = currentDesktopAudioPlatform;
    return MediaCheckServices(
      platform: platform,
      micCapture: RecordMicCapture.new,
      audioOutput: () => DesktopAudioOutput.forPlatform(platform),
    );
  }

  final DesktopAudioPlatform platform;
  final DesktopMicCapture Function() micCapture;
  final DesktopAudioOutput Function() audioOutput;

  /// Превью камеры. По умолчанию — тот же движок, что снимает звонок.
  final DesktopCameraPreviewEngine Function() cameraEngine;

  /// Идёт ли звонок. `null` — следить за настоящими менеджерами звонков.
  final ValueListenable<bool>? callActive;

  /// Проверки звука есть только там, где они настоящие: Windows и macOS.
  /// На прочих системах строк нет вовсе — кнопка, которая ничего не
  /// проверяет, хуже отсутствующей.
  bool get soundChecks => platform != DesktopAudioPlatform.other;

  /// Превью камеры — там же: это Windows и macOS, где камеру открывает
  /// `flutter_webrtc` звонков и где это проверено.
  bool get cameraCheck => platform != DesktopAudioPlatform.other;
}

/// Какой доступ открыть в настройках системы.
enum SystemPrivacyPane { microphone, camera }

/// Адрес настроек конфиденциальности системы: доступ приложений к микрофону
/// или камере. На macOS адрес старой панели ведёт и в новые «Системные
/// настройки». `null` — у системы такой страницы нет. Чистая функция.
String? systemPrivacySettingsUrl(
  DesktopAudioPlatform platform,
  SystemPrivacyPane pane,
) {
  final mic = pane == SystemPrivacyPane.microphone;
  return switch (platform) {
    DesktopAudioPlatform.windows =>
      mic ? 'ms-settings:privacy-microphone' : 'ms-settings:privacy-webcam',
    DesktopAudioPlatform.macos =>
      'x-apple.systempreferences:com.apple.preference.security?'
          '${mic ? 'Privacy_Microphone' : 'Privacy_Camera'}',
    DesktopAudioPlatform.other => null,
  };
}

/// Открыть настройки конфиденциальности своей системы (см.
/// [systemPrivacySettingsUrl]).
Future<void> openSystemPrivacySettings(SystemPrivacyPane pane) async {
  final url = systemPrivacySettingsUrl(currentDesktopAudioPlatform, pane);
  if (url == null) return;
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Не открылось — человек найдёт настройку сам; падать тут не из-за чего.
  }
}

/// Строки микрофона: уровень и «Проверить микрофон». Каждая — отдельный
/// ребёнок карточки, чтобы между ними легла черта, как между любыми строками.
///
/// [busy] — идёт звонок: проверки молчат и объясняют почему. [outputId] и
/// [outputLabel] — куда проиграть запись: выбранные динамики. Пока звучит
/// сигнал динамиков ([speaker]), запись не начинается — иначе в неё попал бы
/// сам сигнал.
List<Widget> micCheckRows({
  required DesktopMicCheck check,
  required bool busy,
  required String outputId,
  required String outputLabel,
  DesktopSpeakerCheck? speaker,
}) => <Widget>[
  ListenableBuilder(
    listenable: check,
    builder: (ctx, _) => _MicLevelRow(check: check, busy: busy),
  ),
  ListenableBuilder(
    listenable: Listenable.merge([check, if (speaker != null) speaker]),
    builder: (ctx, _) => _MicTestRow(
      check: check,
      busy: busy,
      speakerPlaying: speaker?.playing ?? false,
      outputId: outputId,
      outputLabel: outputLabel,
    ),
  ),
];

/// Строка «Проверить динамики»: короткий сигнал в выбранном устройстве.
/// Пока идёт проверка микрофона, сигнал не играет: он попал бы в запись.
Widget speakerCheckRow({
  required DesktopSpeakerCheck check,
  required bool busy,
  required String outputId,
  required String outputLabel,
  DesktopMicCheck? mic,
}) => ListenableBuilder(
  listenable: Listenable.merge([check, if (mic != null) mic]),
  builder: (ctx, _) => _SpeakerTestRow(
    check: check,
    busy: busy,
    micTesting: (mic?.phase ?? MicTestPhase.idle) != MicTestPhase.idle,
    outputId: outputId,
    outputLabel: outputLabel,
  ),
);

class _SpeakerTestRow extends StatelessWidget {
  const _SpeakerTestRow({
    required this.check,
    required this.busy,
    required this.micTesting,
    required this.outputId,
    required this.outputLabel,
  });

  final DesktopSpeakerCheck check;
  final bool busy;
  final bool micTesting;
  final String outputId;
  final String outputLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final c = DColors.of(context);
    final lines = <Widget>[];
    if (busy) {
      lines.add(SettingsCheckNote(l10n.desktopMediaBusyInCall));
    } else if (check.playing) {
      lines.add(
        SettingsCheckNote(
          l10n.desktopSpeakerTestPlaying,
          leading: Icon(
            FluentIcons.speaker_2_16_filled,
            size: 13,
            color: c.accentPrimary,
          ),
          strong: true,
        ),
      );
    } else {
      switch (check.result) {
        case SpeakerCheckResult.systemOnly:
          lines.add(SettingsCheckNote(l10n.desktopMediaPlaybackSystemOnly));
        case SpeakerCheckResult.failed:
          lines.add(SettingsCheckNote(l10n.desktopMediaPlaybackFailed));
        case SpeakerCheckResult.none:
        case SpeakerCheckResult.targeted:
          break;
      }
      lines.add(SettingsCheckNote(l10n.desktopSpeakerTestHint));
    }
    final playing = check.playing;
    return SettingsCheckRow(
      label: l10n.desktopSpeakerTest,
      lines: lines,
      muted: busy,
      palette: p,
      trailing: SettingsSoftButton(
        label: playing ? l10n.desktopMediaCheckStop : l10n.desktopMediaCheck,
        icon: playing
            ? FluentIcons.stop_24_regular
            : FluentIcons.speaker_2_24_regular,
        onTap: playing
            ? check.stop
            : (busy || micTesting
                  ? null
                  : () => unawaited(
                      check.play(outputId: outputId, outputLabel: outputLabel),
                    )),
      ),
    );
  }
}

class _MicLevelRow extends StatelessWidget {
  const _MicLevelRow({required this.check, required this.busy});

  final DesktopMicCheck check;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final status = busy ? MicCheckStatus.off : check.status;
    Widget? trailing;
    final lines = <Widget>[];
    if (busy) {
      lines.add(SettingsCheckNote(l10n.desktopMediaBusyInCall));
    } else {
      switch (status) {
        case MicCheckStatus.live:
        case MicCheckStatus.off:
          lines.add(MicLevelMeter(level: check.level));
          if (status == MicCheckStatus.live && !check.micExact) {
            lines.add(SettingsCheckNote(l10n.desktopMicSystemFallback));
          }
          lines.add(SettingsCheckNote(l10n.desktopMicLevelHint));
        case MicCheckStatus.needsPermission:
          lines.add(SettingsCheckNote(l10n.desktopMicNeedsAccess));
          trailing = SettingsSoftButton(
            label: l10n.desktopMicAllow,
            icon: FluentIcons.mic_24_regular,
            onTap: () => unawaited(check.requestPermission()),
          );
        case MicCheckStatus.denied:
          lines.add(SettingsCheckNote(l10n.desktopMicNoAccess));
          trailing = SettingsSoftButton(
            label: l10n.desktopMediaOpenPrivacy,
            icon: FluentIcons.open_24_regular,
            onTap: () => unawaited(
              openSystemPrivacySettings(SystemPrivacyPane.microphone),
            ),
          );
        case MicCheckStatus.failed:
          lines.add(SettingsCheckNote(l10n.desktopMicOpenFailed));
          trailing = SettingsSoftButton(
            label: l10n.desktopMediaOpenPrivacy,
            icon: FluentIcons.open_24_regular,
            onTap: () => unawaited(
              openSystemPrivacySettings(SystemPrivacyPane.microphone),
            ),
          );
      }
    }
    return SettingsCheckRow(
      label: l10n.desktopMicLevel,
      lines: lines,
      trailing: trailing,
      muted: busy,
      palette: p,
    );
  }
}

class _MicTestRow extends StatelessWidget {
  const _MicTestRow({
    required this.check,
    required this.busy,
    required this.speakerPlaying,
    required this.outputId,
    required this.outputLabel,
  });

  final DesktopMicCheck check;
  final bool busy;
  final bool speakerPlaying;
  final String outputId;
  final String outputLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final c = DColors.of(context);
    final phase = check.phase;
    final lines = <Widget>[];
    if (busy) {
      lines.add(SettingsCheckNote(l10n.desktopMediaBusyInCall));
    } else {
      switch (phase) {
        case MicTestPhase.recording:
          // 🔴 ЗАПИСЬ ВИДНА СРАЗУ: красная точка и обратный счёт. Человек
          // должен знать, что его сейчас пишут, а не догадываться.
          lines.add(
            SettingsCheckNote(
              l10n.desktopMicTestRecording(check.secondsLeft),
              leading: Icon(
                FluentIcons.record_16_filled,
                size: 12,
                color: c.danger,
              ),
              strong: true,
            ),
          );
        case MicTestPhase.playing:
          lines.add(
            SettingsCheckNote(
              l10n.desktopMicTestPlaying,
              leading: Icon(
                FluentIcons.speaker_2_16_filled,
                size: 13,
                color: c.accentPrimary,
              ),
              strong: true,
            ),
          );
        case MicTestPhase.idle:
          if (check.playbackFailed) {
            lines.add(SettingsCheckNote(l10n.desktopMediaPlaybackFailed));
          } else if (check.playbackTargeted == false) {
            lines.add(SettingsCheckNote(l10n.desktopMediaPlaybackSystemOnly));
          }
          lines.add(SettingsCheckNote(l10n.desktopMicTestHint));
      }
    }
    final running = phase != MicTestPhase.idle;
    final canStart = !busy &&
        !speakerPlaying &&
        (check.status == MicCheckStatus.live ||
            check.status == MicCheckStatus.needsPermission);
    return SettingsCheckRow(
      label: l10n.desktopMicTest,
      lines: lines,
      muted: busy,
      palette: p,
      trailing: SettingsSoftButton(
        label: running ? l10n.desktopMediaCheckStop : l10n.desktopMediaCheck,
        icon: running ? FluentIcons.stop_24_regular : FluentIcons.mic_24_regular,
        onTap: running
            ? check.cancelTest
            : (canStart
                  ? () => unawaited(
                      check.runTest(
                        outputId: outputId,
                        outputLabel: outputLabel,
                      ),
                    )
                  : null),
      ),
    );
  }
}

/// Строка проверки: подпись, под ней — живое содержимое ([lines]), справа —
/// кнопка. Поля и шрифты — как у [WorkspaceRow].
class SettingsCheckRow extends StatelessWidget {
  const SettingsCheckRow({
    super.key,
    required this.label,
    required this.lines,
    required this.palette,
    this.trailing,
    this.muted = false,
    this.alignTop = false,
  });

  final String label;
  final List<Widget> lines;
  final SettingsPalette palette;
  final Widget? trailing;

  /// Строка сейчас недоступна (идёт звонок) — подпись приглушена.
  final bool muted;

  /// Кнопка — вровень с подписью, а не посередине высокой строки (превью).
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: DType.family,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: muted ? p.faint : p.head,
                  ),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 6),
                  line,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Пояснение или состояние под подписью строки проверки.
class SettingsCheckNote extends StatelessWidget {
  const SettingsCheckNote(
    this.text, {
    super.key,
    this.leading,
    this.strong = false,
  });

  final String text;

  /// Значок перед текстом: точка записи, динамик.
  final Widget? leading;

  /// Состояние, а не пояснение: основным тоном, а не третьим.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final label = Text(
      text,
      style: TextStyle(
        fontFamily: DType.family,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: strong ? p.text : p.faint,
      ),
    );
    if (leading == null) return label;
    return Row(
      children: [
        leading!,
        const SizedBox(width: 6),
        Expanded(child: label),
      ],
    );
  }
}

/// Полоска уровня микрофона.
///
/// Цвет — «голос» окна (`voice`): тот же зелёный, каким в созвоне отмечен
/// говорящий. Для диктора полоска не существует: число, меняющееся двадцать
/// раз в секунду, ему ничего не скажет, а подпись строки уже есть.
class MicLevelMeter extends StatelessWidget {
  const MicLevelMeter({super.key, required this.level});

  final ValueListenable<double> level;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final voice = DColors.of(context).voice;
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ColoredBox(
            color: p.dark ? p.ter : p.sel,
            child: ValueListenableBuilder<double>(
              valueListenable: level,
              builder: (ctx, v, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: v.isFinite ? v.clamp(0.0, 1.0) : 0,
                  heightFactor: 1,
                  child: ColoredBox(color: voice),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Строки камеры: превью и «Зеркалить моё видео».
///
/// 🔴 Превью включается только кнопкой — см. `desktop_camera_preview.dart`.
List<Widget> cameraCheckRows({
  required DesktopCameraPreviewController? preview,
  required bool busy,
  required String cameraId,
}) => <Widget>[
  if (preview != null)
    ListenableBuilder(
      listenable: preview,
      builder: (ctx, _) =>
          _CameraPreviewRow(preview: preview, busy: busy, cameraId: cameraId),
    ),
  // Зеркало работает во всех звонках ПК, а не только там, где есть превью:
  // своя плитка есть везде.
  ValueListenableBuilder<bool>(
    valueListenable: DesktopCallPrefs.mirrorSelfView,
    builder: (ctx, mirror, _) {
      final l10n = AppLocalizations.of(ctx)!;
      return WorkspaceRow(
        label: l10n.desktopCameraMirror,
        description: l10n.desktopCameraMirrorHint,
        trailing: WorkspaceSwitch(
          value: mirror,
          onChanged: (v) => unawaited(DesktopCallPrefs.setMirrorSelfView(v)),
        ),
      );
    },
  ),
];

class _CameraPreviewRow extends StatelessWidget {
  const _CameraPreviewRow({
    required this.preview,
    required this.busy,
    required this.cameraId,
  });

  final DesktopCameraPreviewController preview;
  final bool busy;
  final String cameraId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = SettingsScope.paletteOf(context);
    final lines = <Widget>[];
    final active = !busy && preview.active;
    if (busy) {
      lines.add(SettingsCheckNote(l10n.desktopMediaBusyInCall));
    } else {
      if (active) lines.add(_PreviewBox(preview: preview));
      if (preview.status == CameraPreviewStatus.failed) {
        lines.add(SettingsCheckNote(l10n.desktopCameraPreviewFailed));
        // Чаще всего камеру закрыла настройка конфиденциальности системы —
        // путь к ней прямо здесь.
        lines.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SettingsSoftButton(
              label: l10n.desktopMediaOpenPrivacy,
              icon: FluentIcons.open_24_regular,
              small: true,
              onTap: () => unawaited(
                openSystemPrivacySettings(SystemPrivacyPane.camera),
              ),
            ),
          ),
        );
      }
      lines.add(SettingsCheckNote(l10n.desktopCameraPreviewHint));
    }
    return SettingsCheckRow(
      label: l10n.desktopCameraPreview,
      lines: lines,
      muted: busy,
      palette: p,
      alignTop: active,
      trailing: SettingsSoftButton(
        label: active
            ? l10n.desktopCameraPreviewHide
            : l10n.desktopCameraPreviewShow,
        icon: active
            ? FluentIcons.video_off_24_regular
            : FluentIcons.video_24_regular,
        onTap: busy
            ? null
            : () => unawaited(
                active ? preview.hide() : preview.show(cameraId),
              ),
      ),
    );
  }
}

/// Окошко превью: 16:9, не шире 320 точек, скругление как у карточек.
/// Зеркало — живое: переключатель ниже меняет картинку сразу.
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.preview});

  final DesktopCameraPreviewController preview;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.black,
              child: preview.status == CameraPreviewStatus.on
                  ? ValueListenableBuilder<bool>(
                      valueListenable: DesktopCallPrefs.mirrorSelfView,
                      builder: (ctx, mirror, _) =>
                          preview.view(mirror: mirror),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
