// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Громкость мелодии входящего звонка на ПК (ТЗ «ПК как Telegram», §1.4,
// блок «Входящие»).
//
// 🔴 ТЕЛЕФОН НЕ ЗАТРОНУТ: громкость доходит до общего кода звонков через точку
// ПК (`DesktopCallDevices.hooks`), которую телефон не заполняет, — у него
// множитель всегда 1, и мелодия звучит ровно как раньше.
//
// Выбор мелодии и «Послушать» у каждой — с 01.10.2026, см.
// desktop_sound_picker_test.dart. Здесь — громкость и «Послушать» рядом с
// ней: выбранная мелодия, с той громкостью, с какой зазвонит.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:secretly_app/calls/call_audio_route.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_devices.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_sounds.dart';
import 'package:secretly_app/ui/desktop/workspace/ringtone_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Проигрыватель «Послушать» — общий для всех списков звуков ПК.
class FakeRingtonePlayer implements DesktopSoundOutput {
  final plays = <double>[];
  final assets = <String>[];
  final volumes = <double>[];
  int stops = 0;
  Completer<void> _done = Completer<void>();

  @override
  Future<void> start(
    String asset, {
    required double volume,
    bool loop = false,
  }) async {
    _done = Completer<void>();
    assets.add(asset);
    plays.add(volume);
  }

  @override
  Future<void> get finished => _done.future;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> stop() async {
    stops++;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DesktopCallPrefs.resetForTest();
    await DesktopSoundPreview.instance.resetForTest();
  });

  tearDown(() => DesktopCallDevices.hooks = null);

  group('громкость доходит до звонка', () {
    DesktopCallDeviceHooks hooks(double Function() volume) =>
        DesktopCallDeviceHooks(
          preferredOutputId: () => '',
          systemDefaultOutputId: () async => null,
          ringtoneVolume: volume,
        );

    test('🔴 телефон: точки нет — множитель 1, всё как было', () {
      DesktopCallDevices.hooks = null;
      expect(desktopRingtoneVolumeScale(), 1.0);
    });

    test('ПК: множитель — громкость из настроек, в пределах 0…1', () {
      DesktopCallDevices.hooks = hooks(() => 0.35);
      expect(desktopRingtoneVolumeScale(), 0.35);
      DesktopCallDevices.hooks = hooks(() => 1.7);
      expect(desktopRingtoneVolumeScale(), 1.0);
      DesktopCallDevices.hooks = hooks(() => -1);
      expect(desktopRingtoneVolumeScale(), 0.0);
      DesktopCallDevices.hooks = hooks(() => double.nan);
      expect(desktopRingtoneVolumeScale(), 1.0);
      DesktopCallDevices.hooks = hooks(() => throw StateError('prefs'));
      expect(desktopRingtoneVolumeScale(), 1.0);
    });

    test('ПК при запуске окна подключает свою громкость', () async {
      installDesktopCallDevices();
      await DesktopCallPrefs.setRingtoneVolume(0.4);
      expect(desktopRingtoneVolumeScale(), 0.4);
    });

    test('звонок умножает на неё только мелодию ВХОДЯЩЕГО', () {
      final src = File('lib/calls/call_manager.dart').readAsStringSync();
      final i = src.indexOf('case _RingtoneMode.incoming:');
      final block = src.substring(i, src.indexOf('case _RingtoneMode.outgoing:', i));
      expect(block.contains('desktopRingtoneVolumeScale()'), isTrue);
      expect(
        block.contains('incomingRingtoneVolumeForSetting(_callRingtoneSetting) *'),
        isTrue,
      );
      // Гудки исходящего и звук соединения — без изменений.
      final rest = src.substring(src.indexOf('case _RingtoneMode.outgoing:', i));
      expect(rest.contains('volume = 0.58;'), isTrue);
      expect(rest.contains('volume = 0.32;'), isTrue);
    });
  });

  group('DesktopCallPrefs.ringtoneVolume', () {
    test('шаг 5 %, мусор — полная громкость', () {
      expect(DesktopCallPrefs.normalizeVolume(0.33), 0.35);
      expect(DesktopCallPrefs.normalizeVolume(0.32), 0.3);
      expect(DesktopCallPrefs.normalizeVolume(null), 1.0);
      expect(DesktopCallPrefs.normalizeVolume(double.nan), 1.0);
      expect(DesktopCallPrefs.normalizeVolume(2), 1.0);
      expect(DesktopCallPrefs.normalizeVolume(-3), 0.0);
    });

    test('по умолчанию полная; выбор переживает перезапуск', () async {
      expect(DesktopCallPrefs.ringtoneVolume.value, 1.0);
      await DesktopCallPrefs.setRingtoneVolume(0.25);
      DesktopCallPrefs.resetForTest();
      await DesktopCallPrefs.load();
      expect(DesktopCallPrefs.ringtoneVolume.value, 0.25);
    });
  });

  group('карточка «Мелодия звонка»', () {
    Widget host(FakeRingtonePlayer player, ValueNotifier<bool> busy) {
      DesktopSoundPreview.createOutput = () => player;
      return MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: ListView(
                children: [
                  DesktopRingtoneCard(callActive: busy),
                ],
              ),
            ),
          ),
        );
    }

    testWidgets('«Послушать» — текущая громкость; ползунок слышен сразу', (t) async {
      final player = FakeRingtonePlayer();
      await t.pumpWidget(host(player, ValueNotifier<bool>(false)));
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(NumberFormat.percentPattern('ru').format(1.0)), findsOneWidget);
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      await t.pump();
      expect(player.plays, [1.0]);
      // Ничего не выбрано — мелодия по умолчанию, та же, что у звонка.
      expect(player.assets, ['assets/app_ui/sounds/Bubble.mp3']);
      expect(find.text(l10n.desktopMediaCheckStop), findsOneWidget);

      // Середина ползунка — 50 %, и играющая мелодия стала тише сразу.
      await t.tap(find.byType(Slider));
      await t.pump();
      expect(DesktopCallPrefs.ringtoneVolume.value, 0.5);
      expect(player.volumes.last, 0.5);
      expect(find.text(NumberFormat.percentPattern('ru').format(0.5)), findsOneWidget);

      // Сама смолкает через несколько секунд.
      await t.pump(const Duration(seconds: 5));
      expect(player.stops, 1);
      expect(find.text(l10n.desktopRingtoneListen), findsOneWidget);
    });

    testWidgets('«Послушать» у громкости — ВЫБРАННАЯ мелодия', (t) async {
      SharedPreferences.setMockInitialValues({
        DesktopSounds.callSettingsKey: 'pixel_tono',
      });
      final player = FakeRingtonePlayer();
      await t.pumpWidget(host(player, ValueNotifier<bool>(false)));
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      await t.pump();
      expect(player.assets, ['assets/app_ui/sounds/call/pixel_tono.mp3']);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('без звука — так и сказано, слушать нечего', (t) async {
      await DesktopCallPrefs.setRingtoneVolume(0);
      final player = FakeRingtonePlayer();
      await t.pumpWidget(host(player, ValueNotifier<bool>(false)));
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopRingtoneSilent), findsOneWidget);
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      expect(player.plays, isEmpty);
    });

    testWidgets('🔴 начался звонок — «Послушать» смолкает и молчит', (t) async {
      final player = FakeRingtonePlayer();
      final busy = ValueNotifier<bool>(false);
      await t.pumpWidget(host(player, busy));
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      await t.pump();
      busy.value = true;
      await t.pump();
      expect(player.stops, greaterThanOrEqualTo(1));
      expect(find.text(l10n.desktopMediaBusyInCall), findsOneWidget);
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      expect(player.plays, hasLength(1));
      // Ушли со страницы, пока играло, — смолкает.
      busy.value = false;
      await t.pump();
      await t.tap(find.text(l10n.desktopRingtoneListen));
      await t.pump();
      await t.pump();
      expect(player.plays, hasLength(2));
      final stops = player.stops;
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(player.stops, greaterThan(stops));
    });
  });

  test('карточка стоит в разделе «Звонки»', () {
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    final i = src.indexOf('class _CallsPaneState');
    final j = src.indexOf('Future<void> openSystemSoundSettings()', i);
    expect(src.substring(i, j).contains('DesktopRingtoneCard('), isTrue);
  });
}
