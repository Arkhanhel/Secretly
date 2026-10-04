// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Выбор звуков на ПК (01.10.2026, владелец: «человек должен выбирать звуки и
// слышать их»): звук сообщений, звук в открытом чате, мелодия звонка.
//
// Сторожится: выбор пишется в телефонные ключи и доходит до того, что
// звучит на деле (уведомление ПК и звонок); «Послушать» — один проигрыватель
// на все списки; платное без подписки — замок и плашка ПК, а не витрина
// телефона; в названиях нет чужих марок.

import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support_public_tree.dart';
import 'package:secretly_app/calls/call_audio_route.dart';
import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/app_asset_paths.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_devices.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_sounds.dart';
import 'package:secretly_app/ui/desktop/workspace/ringtone_card.dart';
import 'package:secretly_app/ui/desktop/workspace/sound_picker.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSoundOutput implements DesktopSoundOutput {
  final starts = <({String asset, double volume, bool loop})>[];
  final volumes = <double>[];
  int stops = 0;
  bool disposed = false;
  bool failNext = false;
  Completer<void> _done = Completer<void>();

  void finishNow() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> start(
    String asset, {
    required double volume,
    bool loop = false,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('файл не загрузился');
    }
    finishNow();
    _done = Completer<void>();
    starts.add((asset: asset, volume: volume, loop: loop));
  }

  @override
  Future<void> get finished => _done.future;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> stop() async {
    stops++;
    finishNow();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    finishNow();
  }
}

const _free = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.free,
  source: 'none',
  features: EntitlementFeatures.none,
  limits: EntitlementLimits.free,
);

const _premium = EntitlementState(
  monetizationEnabled: true,
  tier: EntitlementTier.premium,
  source: 'appstore',
  features: EntitlementFeatures.all,
  limits: EntitlementLimits.premium,
);

Widget _host(List<Widget> children, {Locale locale = const Locale('ru')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: ListView(children: children)),
      ),
    );

Finder _row(DesktopSoundKind kind, String id) =>
    find.byKey(ValueKey<String>('desktop-sound-${kind.name}-$id'));

Finder _play(DesktopSoundKind kind, String id) =>
    find.byKey(ValueKey<String>('desktop-sound-play-${kind.name}-$id'));

Finder _inRow(DesktopSoundKind kind, String id, IconData icon) =>
    find.descendant(of: _row(kind, id), matching: find.byIcon(icon));

void main() {
  late FakeSoundOutput out;
  var outputsMade = 0;
  final idle = ValueNotifier<bool>(false);

  setUp(() async {
    // Список звуков открытого чата виден, когда звук включён; по умолчанию
    // на ПК он выключен — это проверяет отдельный тест ниже.
    SharedPreferences.setMockInitialValues({
      DesktopSounds.inChatEnabledSettingsKey: true,
    });
    DesktopCallPrefs.resetForTest();
    out = FakeSoundOutput();
    outputsMade = 0;
    DesktopSoundPreview.createOutput = () {
      outputsMade++;
      return out;
    };
    await DesktopSoundPreview.instance.resetForTest();
  });

  tearDown(() => DesktopCallDevices.hooks = null);

  group('выбор', () {
    testWidgets(
      '🔴 сохраняется в ключи телефона — оба, что читает контроллер',
      (t) async {
        await t.pumpWidget(
          _host([DesktopMessageSoundCard(soundOn: true, callActive: idle)]),
        );
        await t.pump();
        // По умолчанию — звук по умолчанию телефона.
        expect(
          _inRow(
            DesktopSoundKind.message,
            'bubble_mail',
            FluentIcons.checkmark_circle_16_filled,
          ),
          findsOneWidget,
        );

        await t.tap(_row(DesktopSoundKind.message, 'splash'));
        await t.pump();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(DesktopSounds.messageSettingsKey), 'splash');
        expect(prefs.getString(DesktopSounds.messageRuntimeKey), 'splash');
        expect(
          _inRow(
            DesktopSoundKind.message,
            'splash',
            FluentIcons.checkmark_circle_16_filled,
          ),
          findsOneWidget,
        );
        expect(
          _inRow(
            DesktopSoundKind.message,
            'bubble_mail',
            FluentIcons.checkmark_circle_16_filled,
          ),
          findsNothing,
        );
        // Выбор — не «Послушать».
        expect(out.starts, isEmpty);
      },
    );

    testWidgets('звук открытого чата: выключатель и список из папки inchat', (
      t,
    ) async {
      await t.pumpWidget(
        _host([DesktopInChatSoundCard(soundOn: true, callActive: idle)]),
      );
      await t.pump();
      await t.tap(_row(DesktopSoundKind.inChat, 'switch_click'));
      await t.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DesktopSounds.inChatSettingsKey), 'switch_click');
      expect(prefs.getString(DesktopSounds.inChatRuntimeKey), 'switch_click');

      // Выключили — список прячется, а выключатель ложится в оба ключа.
      await t.tap(find.byType(WorkspaceSwitch));
      await t.pump();
      expect(prefs.getBool(DesktopSounds.inChatEnabledSettingsKey), isFalse);
      expect(prefs.getBool(DesktopSounds.inChatEnabledRuntimeKey), isFalse);
      expect(DesktopSounds.readInChatEnabled(prefs), isFalse);
      expect(_row(DesktopSoundKind.inChat, 'keycap'), findsNothing);
    });
  });

  group('«Послушать»', () {
    testWidgets(
      '🔴 один проигрыватель: новый звук гасит прежний; повтор — стоп',
      (t) async {
        await t.pumpWidget(
          _host([
            DesktopMessageSoundCard(soundOn: true, callActive: idle),
            DesktopInChatSoundCard(soundOn: true, callActive: idle),
          ]),
        );
        await t.pump();
        final preview = DesktopSoundPreview.instance;

        await t.tap(_play(DesktopSoundKind.message, 'pingo'));
        await t.pump();
        expect(out.starts.last.asset, 'assets/app_ui/sounds/noti/pingo.mp3');
        expect(out.starts.last.volume, DesktopSounds.messageVolume);
        expect(preview.isPlaying(DesktopSoundKind.message, 'pingo'), isTrue);
        expect(
          _inRow(
            DesktopSoundKind.message,
            'pingo',
            FluentIcons.stop_24_regular,
          ),
          findsOneWidget,
        );

        await t.tap(_play(DesktopSoundKind.inChat, 'click_s7'));
        await t.pump();
        expect(
          out.starts.last.asset,
          'assets/app_ui/sounds/inchat/click_s7.mp3',
        );
        expect(out.starts.last.volume, DesktopSounds.inChatVolume);
        expect(preview.isPlaying(DesktopSoundKind.message, 'pingo'), isFalse);
        expect(preview.isPlaying(DesktopSoundKind.inChat, 'click_s7'), isTrue);
        expect(outputsMade, 1, reason: 'один проигрыватель на все списки');

        await t.tap(_play(DesktopSoundKind.inChat, 'click_s7'));
        await t.pump();
        expect(out.stops, 1);
        expect(preview.playing.value, isNull);

        // Доиграл сам — кнопка снова «Послушать».
        await t.tap(_play(DesktopSoundKind.message, 'splash'));
        await t.pump();
        out.finishNow();
        await t.pump();
        await t.pump();
        expect(preview.playing.value, isNull);
        expect(
          _inRow(
            DesktopSoundKind.message,
            'splash',
            FluentIcons.play_24_regular,
          ),
          findsOneWidget,
        );

        // Выбор «Послушать» не трогал.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(DesktopSounds.messageSettingsKey), isNull);

        // Ушли со страницы — звук смолкает.
        await t.tap(_play(DesktopSoundKind.message, 'drip_drop'));
        await t.pump();
        final stopsBefore = out.stops;
        await t.pumpWidget(const SizedBox());
        await t.pump();
        expect(out.stops, greaterThan(stopsBefore));
        expect(preview.playing.value, isNull);
      },
    );

    testWidgets('🔴 начался звонок — смолкает и до конца звонка недоступно', (
      t,
    ) async {
      final busy = ValueNotifier<bool>(false);
      await t.pumpWidget(
        _host([
          DesktopRingtoneCard(entitlement: () => _premium, callActive: busy),
        ]),
      );
      await t.pump();
      await t.tap(_play(DesktopSoundKind.call, 'pixel_tono'));
      await t.pump();
      expect(out.starts.last.asset, 'assets/app_ui/sounds/call/pixel_tono.mp3');
      expect(out.starts.last.loop, isTrue, reason: 'по кругу, как у звонка');

      busy.value = true;
      await t.pump();
      expect(out.stops, greaterThanOrEqualTo(1));
      expect(DesktopSoundPreview.instance.playing.value, isNull);
      await t.tap(_play(DesktopSoundKind.call, 'cytus_ii_im'));
      await t.pump();
      expect(out.starts, hasLength(1));
    });
  });

  group('платные звуки', () {
    testWidgets('🔴 без подписки: замок, плашка ПК, выбор не меняется', (
      t,
    ) async {
      await t.pumpWidget(
        _host([
          DesktopMessageSoundCard(
            soundOn: true,
            entitlement: () => _free,
            callActive: idle,
          ),
        ]),
      );
      await t.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      for (final id in ['water_drop_one_plus', 'xiaomi_notification']) {
        expect(
          _inRow(
            DesktopSoundKind.message,
            id,
            FluentIcons.lock_closed_12_filled,
          ),
          findsOneWidget,
        );
      }
      expect(
        _inRow(
          DesktopSoundKind.message,
          'splash',
          FluentIcons.lock_closed_12_filled,
        ),
        findsNothing,
      );

      await t.tap(_row(DesktopSoundKind.message, 'water_drop_one_plus'));
      await t.pump();
      expect(find.text(l10n.desktopAppearancePremiumOnly), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DesktopSounds.messageSettingsKey), isNull);
      expect(prefs.getString(DesktopSounds.messageRuntimeKey), isNull);

      // Послушать до покупки — можно.
      await t.tap(_play(DesktopSoundKind.message, 'water_drop_one_plus'));
      await t.pump();
      expect(out.starts.last.asset, contains('water_drop_one_plus'));

      // Плашка уходит сама.
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('мелодии звонка: бесплатна только мелодия по умолчанию', (
      t,
    ) async {
      await t.pumpWidget(
        _host([
          DesktopRingtoneCard(entitlement: () => _free, callActive: idle),
        ]),
      );
      await t.pump();
      await t.tap(_row(DesktopSoundKind.call, 'pixel_tono'));
      await t.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DesktopSounds.callSettingsKey), isNull);
      await t.pump(const Duration(seconds: 5));
    });

    test('подписка есть или неизвестна — можно всё (оплата ошибается в '
        'пользу человека)', () {
      for (final kind in DesktopSoundKind.values) {
        for (final id in DesktopSounds.idsOf(kind)) {
          expect(DesktopSounds.isAllowed(kind, _premium, id), isTrue);
          expect(DesktopSounds.isAllowed(kind, null, id), isTrue);
        }
      }
      // Звуки открытого чата телефон не делит на платные.
      for (final id in DesktopSounds.inChatIds) {
        expect(
          DesktopSounds.isAllowed(DesktopSoundKind.inChat, _free, id),
          isTrue,
        );
      }
    });
  });

  group('названия', () {
    test(
      '🔴 без чужих марок — ни на одном языке, и в списке не повторяются',
      () async {
        final brand = RegExp(
          r'xiaomi|one ?plus|samsung|pixel|cytus|galaxy|\bs7\b|google|apple|'
          r'huawei|signal|telegram|whatsapp',
          caseSensitive: false,
        );
        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = await AppLocalizations.delegate.load(locale);
          for (final kind in DesktopSoundKind.values) {
            final names = [
              for (final id in DesktopSounds.idsOf(kind))
                DesktopSounds.nameOf(l10n, id),
            ];
            for (final name in names) {
              expect(brand.hasMatch(name), isFalse, reason: '$locale: $name');
              expect(name.trim(), isNotEmpty);
            }
            expect(
              names.toSet(),
              hasLength(names.length),
              reason: '$locale $kind',
            );
          }
        }
      },
    );

    testWidgets('по-английски — без русских слов', (t) async {
      await t.pumpWidget(
        _host([
          DesktopMessageSoundCard(soundOn: false, callActive: idle),
          DesktopInChatSoundCard(soundOn: false, callActive: idle),
          DesktopRingtoneCard(callActive: idle),
        ], locale: const Locale('en')),
      );
      await t.pump();
      final texts = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '');
      final cyrillic = RegExp(r'[а-яА-ЯёЁ]');
      expect(texts.where(cyrillic.hasMatch), isEmpty);
    });
  });

  group('🔴 выбор доходит до того, что звучит', () {
    test(
      'уведомление ПК: выбранный файл, правило ключей — как у контроллера',
      () async {
        final sound = DesktopMessageSound(output: () => out);
        SharedPreferences.setMockInitialValues({
          DesktopSounds.messageSettingsKey: 'splash',
        });
        expect(await sound.play(DesktopSoundKind.message), isTrue);
        expect(out.starts.last.asset, 'assets/app_ui/sounds/noti/splash.mp3');
        expect(out.starts.last.volume, DesktopSounds.messageVolume);

        // Рабочий ключ контроллера старше `settings_…` — как в контроллере.
        SharedPreferences.setMockInitialValues({
          DesktopSounds.messageSettingsKey: 'splash',
          DesktopSounds.messageRuntimeKey: 'drip_drop',
        });
        await sound.play(DesktopSoundKind.message);
        expect(
          out.starts.last.asset,
          'assets/app_ui/sounds/noti/drip_drop.mp3',
        );

        // Звук сообщений, выбранный телефоном для открытого чата, в папке
        // `inchat` не лежит — звучит звук по умолчанию, а не тишина.
        SharedPreferences.setMockInitialValues({
          DesktopSounds.inChatSettingsKey: 'bubble_mail',
        });
        await sound.play(DesktopSoundKind.inChat);
        expect(out.starts.last.asset, 'assets/app_ui/sounds/inchat/keycap.mp3');

        // Не заиграл — служба вернёт системный звук.
        out.failNext = true;
        expect(await sound.play(DesktopSoundKind.message), isFalse);
      },
    );

    test('звонок: телефон — прежняя мелодия, ПК — выбранная', () {
      const fallback = AppAssetPaths.incomingRingtoneMp3;
      DesktopCallDevices.hooks = null;
      expect(
        desktopIncomingRingtoneAsset('pixel_tono', fallback: fallback),
        fallback,
      );

      installDesktopCallDevices();
      expect(
        desktopIncomingRingtoneAsset('pixel_tono', fallback: fallback),
        'assets/app_ui/sounds/call/pixel_tono.mp3',
      );
      for (final same in [
        'default',
        'beacon',
        'chime',
        '',
        '../x',
        'ringback_ru',
      ]) {
        expect(
          desktopIncomingRingtoneAsset(same, fallback: fallback),
          fallback,
          reason: same,
        );
      }
    });

    test('звонок берёт мелодию через точку ПК только у ВХОДЯЩЕГО', () {
      final src = File('lib/calls/call_manager.dart').readAsStringSync();
      final i = src.indexOf('case _RingtoneMode.incoming:');
      final block = src.substring(
        i,
        src.indexOf('case _RingtoneMode.outgoing:', i),
      );
      expect(block.contains('desktopIncomingRingtoneAsset('), isTrue);
      expect(block.contains('_callRingtoneSetting,'), isTrue);
      expect(block.contains('fallback: _incomingRingtoneAsset'), isTrue);
      final rest = src.substring(
        src.indexOf('case _RingtoneMode.outgoing:', i),
      );
      expect(
        rest
            .substring(0, rest.indexOf('loop = false;'))
            .contains('desktopIncomingRingtoneAsset'),
        isFalse,
      );
    });

    test('служба уведомлений: свой звук, системный — только если свой не '
        'заиграл; звук открытого чата — свой', () {
      final src = File(
        'lib/ui/desktop/services/desktop_notification_service.dart',
      ).readAsStringSync();
      expect(src.contains('ownSound: _playMessageSound'), isTrue);
      expect(src.contains('sound: withSound && ownSound == null'), isTrue);
      expect(src.contains('presentSound: withSound && !own'), isTrue);
      expect(src.contains('playNotificationSound()'), isTrue);
      expect(src.contains('await _playOpenChatSound(evt.convoId);'), isTrue);
      expect(src.contains('DesktopSoundKind.inChat'), isTrue);
      expect(src.contains('DesktopSounds.readInChatEnabled(prefs)'), isTrue);
    });

    test('все звуки списков лежат в сборке', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dir in ['noti', 'inchat', 'call']) {
        expect(pubspec.contains('- assets/app_ui/sounds/$dir/'), isTrue);
      }
      for (final kind in DesktopSoundKind.values) {
        for (final id in DesktopSounds.idsOf(kind)) {
          final asset = DesktopSounds.assetOf(kind, id);
          expect(File(asset).existsSync(), isTrue, reason: asset);
        }
      }
    }, skip: skipInPublicTree('файлов звуков'));
  });

  test('🔴 звук открытого чата на ПК по умолчанию выключен', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(DesktopSounds.readInChatEnabled(prefs), isFalse);
    // Выбор человека (хоть в ключе телефона) главнее умолчания.
    SharedPreferences.setMockInitialValues({
      DesktopSounds.inChatEnabledSettingsKey: true,
    });
    expect(
      DesktopSounds.readInChatEnabled(await SharedPreferences.getInstance()),
      isTrue,
    );
  });
}
