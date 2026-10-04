// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Голосовые на ПК не записывались вовсе — и молча (30.09.2026).
//
// Поле ввода писало Opus, которого пакет записи не умеет ни на macOS, ни на
// Windows; ошибку глотал пустой `catch`. Теперь — как телефон: AAC-LC в
// `.m4a`, `audio/mp4` и волна; беды — словами; временный файл не остаётся на
// диске ни после отправки, ни после сбоя, ни после ухода из переписки.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/desktop/chat/attachment_kinds.dart';
import 'package:secretly_app/ui/desktop/chat/composer.dart';
import 'package:secretly_app/ui/desktop/chat/desktop_voice_recorder.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart'
    show MessageAttachmentKind;
import 'package:secretly_app/ui/desktop/design/colors.dart';

class _FakeRecorder implements DesktopVoiceRecorder {
  bool encoder = true;
  bool permission = true;
  bool? device = true;
  Object? startError;
  int encoderChecks = 0;
  int permissionChecks = 0;
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  int disposes = 0;
  String? path;
  final StreamController<double> levels = StreamController<double>.broadcast();

  @override
  Future<bool> isEncoderSupported() async {
    encoderChecks++;
    return encoder;
  }

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<bool?> hasInputDevice() async => device;

  @override
  Future<void> start(String p) async {
    final error = startError;
    if (error != null) throw error;
    starts++;
    path = p;
    File(p).writeAsStringSync('m4a');
  }

  @override
  Stream<double> amplitudeDb(Duration interval) => levels.stream;

  @override
  Future<String?> stop() async {
    stops++;
    return path;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    final p = path;
    if (p != null && File(p).existsSync()) File(p).deleteSync();
  }

  @override
  Future<void> dispose() async => disposes++;
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(width: 640, child: child)),
  ),
);

void main() {
  late Directory temp;
  late _FakeRecorder rec;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('secretly_voice_test');
    DesktopVoiceFiles.baseDir = () async => temp;
    DesktopVoiceFiles.legacyDir = () =>
        Directory('${temp.path}/legacy')..createSync(recursive: true);
    rec = _FakeRecorder();
    DesktopVoiceRecorder.create = () => rec;
  });

  tearDown(() {
    DesktopVoiceFiles.debugReset();
    DesktopVoiceRecorder.create = RecordDesktopVoiceRecorder.new;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('запись как у телефона', () {
    test('AAC-LC 128 кбит/с, 44,1 кГц, audio/mp4', () {
      expect(kDesktopVoiceRecordConfig.encoder, AudioEncoder.aacLc);
      expect(kDesktopVoiceRecordConfig.bitRate, 128000);
      expect(kDesktopVoiceRecordConfig.sampleRate, 44100);
      expect(kDesktopVoiceMime, 'audio/mp4');
    });

    test('🔴 audio/mp4 с волной — голосовое у получателя ПК', () {
      AttachmentEventV1 att({List<int>? waveform}) => AttachmentEventV1(
        eventId: 'e1',
        blobId: 'b1',
        fileKeyB64: 'k',
        blobAccessTokenB64: 't',
        sizeBytes: 10,
        mime: 'audio/mp4',
        waveform: waveform,
      );
      expect(
        desktopAttachmentKind(att(waveform: buildDesktopVoiceWaveform([]))),
        MessageAttachmentKind.voice,
      );
      // Без волны — песня: поэтому пустой волна не бывает.
      expect(desktopAttachmentKind(att()), MessageAttachmentKind.audio);
    });

    test('волна не бывает пустой и держится в 0..100', () {
      final none = buildDesktopVoiceWaveform([], random: math.Random(1));
      expect(none, hasLength(kDesktopVoiceWaveformBars));
      expect(none.every((v) => v >= 12 && v <= 100), isTrue);

      final samples = List<double>.generate(500, (i) => i.isEven ? 0.2 : 0.4);
      final wave = buildDesktopVoiceWaveform(samples);
      expect(wave, hasLength(kDesktopVoiceWaveformBars));
      // Растянута по самому громкому месту, как у телефона.
      expect(wave.reduce(math.max), 100);
      expect(wave.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('громкость речи: [-45, 0] dBFS → 0..1', () {
      expect(desktopVoiceLevel(0), 1);
      expect(desktopVoiceLevel(-45), 0);
      expect(desktopVoiceLevel(-90), 0);
      expect(desktopVoiceLevel(double.negativeInfinity), 0);
      expect(desktopVoiceLevel(-22.5), closeTo(0.5, 1e-9));
    });
  });

  group('проверки до записи', () {
    test('кодек — первым: без него доступ к микрофону не спрашиваем', () async {
      rec.encoder = false;
      expect(
        await desktopVoicePreflight(rec),
        DesktopVoiceFailure.unsupportedEncoder,
      );
      expect(rec.permissionChecks, 0);
    });

    test('нет разрешения / нет микрофона — своими словами', () async {
      rec.permission = false;
      expect(
        await desktopVoicePreflight(rec),
        DesktopVoiceFailure.noPermission,
      );
      rec.permission = true;
      rec.device = false;
      expect(
        await desktopVoicePreflight(rec),
        DesktopVoiceFailure.noInputDevice,
      );
      // Система не ответила про устройства — не мешаем записи.
      rec.device = null;
      expect(await desktopVoicePreflight(rec), isNull);
    });

    test('у каждой беды — своя строка', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      final texts = {
        for (final why in DesktopVoiceFailure.values)
          desktopVoiceFailureText(why, l10n),
      };
      expect(texts, hasLength(DesktopVoiceFailure.values.length));
    });
  });

  group('временные файлы', () {
    test('запись — в своей папке приложения, .m4a', () async {
      final path = await DesktopVoiceFiles.newPath();
      expect(
        path.startsWith(
          '${temp.path}${Platform.pathSeparator}${DesktopVoiceFiles.folderName}',
        ),
        isTrue,
      );
      expect(path.endsWith('.m4a'), isTrue);
      File(path).writeAsStringSync('x');
      await DesktopVoiceFiles.delete(path);
      expect(File(path).existsSync(), isFalse);
      await DesktopVoiceFiles.delete(path); // нет файла — ничего не делает
    });

    test('уборка: старше суток — прочь, свежие и чужие — на месте', () async {
      final own = Directory('${temp.path}/${DesktopVoiceFiles.folderName}')
        ..createSync();
      final legacy = DesktopVoiceFiles.legacyDir();
      final old = DateTime.now().subtract(const Duration(days: 2));
      File make(Directory d, String name, {bool stale = true}) {
        final f = File('${d.path}/$name')..writeAsStringSync('x');
        if (stale) f.setLastModifiedSync(old);
        return f;
      }

      final staleOwn = make(own, 'voice-123.m4a');
      final freshOwn = make(own, 'voice-456.m4a', stale: false);
      final staleLegacy = make(legacy, 'voice-1727000000000.opus');
      final foreign = make(legacy, 'voice-notes.opus');
      final otherApp = make(legacy, 'recording.m4a');

      expect(await DesktopVoiceFiles.sweep(), 2);
      expect(staleOwn.existsSync(), isFalse);
      expect(staleLegacy.existsSync(), isFalse);
      expect(freshOwn.existsSync(), isTrue, reason: 'может писаться сейчас');
      expect(foreign.existsSync(), isTrue);
      expect(otherApp.existsSync(), isTrue);
    });

    test('нет временного каталога — уборка молча отступает', () async {
      DesktopVoiceFiles.baseDir = () async => throw MissingPluginException();
      expect(await DesktopVoiceFiles.sweep(), 0);
    });
  });

  group('поле ввода', () {
    Future<List<(String, int, List<int>)>> pump(
      WidgetTester t, {
      Future<void> Function()? onSendError,
    }) async {
      final sent = <(String, int, List<int>)>[];
      // Уборка при запуске — уже была: она ходит на диск по-настоящему.
      await t.runAsync(DesktopVoiceFiles.sweepOnce);
      await t.pumpWidget(
        _host(
          Composer(
            controller: TextEditingController(),
            onSend: (_) {},
            onSendVoice: (path, ms, wave) async {
              expect(File(path).existsSync(), isTrue);
              sent.add((path, ms, wave));
              await onSendError?.call();
            },
          ),
        ),
      );
      return sent;
    }

    Future<void> record(WidgetTester t, {int ms = 1000}) async {
      await t.tap(find.byIcon(FluentIcons.mic_24_regular));
      await t.pump();
      rec.levels.add(-10);
      rec.levels.add(-30);
      await t.pump(Duration(milliseconds: ms));
    }

    testWidgets('🔴 записали и отправили: m4a с волной, файл удалён', (
      t,
    ) async {
      final sent = await pump(t);
      await record(t);
      expect(rec.starts, 1);
      final path = rec.path!;
      expect(path.endsWith('.m4a'), isTrue);

      await t.tap(find.byIcon(FluentIcons.send_24_filled));
      await t.pump();

      expect(sent, hasLength(1));
      expect(sent.single.$1, path);
      expect(sent.single.$2, greaterThanOrEqualTo(700));
      expect(sent.single.$3, hasLength(kDesktopVoiceWaveformBars));
      expect(
        File(path).existsSync(),
        isFalse,
        reason: 'отправке больше не нужен',
      );
    });

    testWidgets('🔴 двойной щелчок и двойное «отправить» — одна запись', (
      t,
    ) async {
      final sent = await pump(t);
      await t.tap(find.byIcon(FluentIcons.mic_24_regular));
      await t.tap(find.byIcon(FluentIcons.mic_24_regular), warnIfMissed: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 1000));
      expect(rec.starts, 1);

      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.tap(find.byIcon(FluentIcons.send_24_filled), warnIfMissed: false);
      await t.pump();
      expect(sent, hasLength(1));
      expect(rec.stops, 1);
    });

    testWidgets('Enter в полосе записи отправляет', (t) async {
      // Без этого проверка двойного «отправить» выше была бы пустой.
      final sent = await pump(t);
      await record(t);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(sent, hasLength(1));
    });

    testWidgets('отправка не удалась — файл всё равно удалён', (t) async {
      await pump(t, onSendError: () async => throw StateError('relay'));
      await record(t);
      final path = rec.path!;
      await t.tap(find.byIcon(FluentIcons.send_24_filled));
      await t.pump();
      expect(File(path).existsSync(), isFalse);
    });

    testWidgets('отмена и слишком короткая — файл удалён, ничего не ушло', (
      t,
    ) async {
      final sent = await pump(t);
      await record(t);
      final cancelled = rec.path!;
      await t.tap(find.byIcon(FluentIcons.delete_24_regular));
      await t.pump();
      expect(File(cancelled).existsSync(), isFalse);

      await record(t, ms: 200);
      final short = rec.path!;
      await t.tap(find.byIcon(FluentIcons.send_24_filled));
      await t.pump();
      expect(File(short).existsSync(), isFalse);
      expect(sent, isEmpty);
    });

    testWidgets('🔴 ушли из переписки посреди записи — запись выброшена', (
      t,
    ) async {
      await pump(t);
      await record(t);
      final path = rec.path!;
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(rec.cancels, 1);
      expect(File(path).existsSync(), isFalse);
      expect(rec.disposes, 1);
    });

    testWidgets('🔴 писать нечем — говорим словами, а не молчим', (t) async {
      rec.encoder = false;
      await pump(t);
      await t.tap(find.byIcon(FluentIcons.mic_24_regular));
      await t.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopComposerVoiceUnsupported), findsOneWidget);
      expect(rec.starts, 0);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('запись не началась — слова и никакого файла', (t) async {
      rec.startError = PlatformException(code: 'record');
      await pump(t);
      await t.tap(find.byIcon(FluentIcons.mic_24_regular));
      await t.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopMicOpenFailed), findsOneWidget);
      final own = Directory('${temp.path}/${DesktopVoiceFiles.folderName}');
      expect(own.listSync(), isEmpty);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('🔴 подключено', () {
    final composer = File(
      'lib/ui/desktop/chat/composer.dart',
    ).readAsStringSync();
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('Opus больше нигде не пишется и не отправляется', () {
      expect(composer.contains('AudioEncoder.opus'), isFalse);
      expect(composer.contains('.opus'), isFalse);
      final i = section.indexOf('Future<void> _onSendVoice(');
      final body = section.substring(i, section.indexOf('\n  }\n', i));
      expect(body.contains("'audio/opus'"), isFalse);
      expect(body.contains("mime: 'audio/mp4',"), isTrue);
      expect('waveform: waveform,'.allMatches(body), hasLength(2));
    });

    test('ошибки не глотаются молча', () {
      final i = composer.indexOf('Future<void> _startRecording() async {');
      final body = composer.substring(i, composer.indexOf('\n  }\n', i));
      expect(body.contains('catch (_) {\n      if (mounted)'), isFalse);
      expect(body.contains('_voiceFailed('), isTrue);
    });

    test('macOS: доступ к микрофону объявлен', () {
      final plist = File('macos/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('NSMicrophoneUsageDescription'), isTrue);
      for (final name in ['DebugProfile', 'Release']) {
        final ent = File('macos/Runner/$name.entitlements').readAsStringSync();
        expect(ent.contains('com.apple.security.device.audio-input'), isTrue);
      }
    });
  });
}
