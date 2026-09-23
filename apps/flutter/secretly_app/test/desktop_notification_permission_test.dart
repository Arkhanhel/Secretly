// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Отказ системы показывать уведомления не остаётся незамеченным.
//
// 🔴 ЧТО ЭТО ЗА ДЕФЕКТ (найден 23.09.2026). Разрешение у macOS запрашивалось,
// но результат выбрасывался: `unawaited(...catchError((_) => false))`.
// Приложение не знало отказа и вело себя так, будто его нет.
//
// Чем это кончается именно на компьютере. Окно живёт в трее и большую часть
// времени спрятано; уведомление — ЕДИНСТВЕННЫЙ способ узнать о новом
// сообщении. Человек однажды нажал «Не разрешать» — и с тех пор не получает
// ничего, а в разделе «Уведомления» все переключатели стоят включёнными и
// выглядят рабочими. Вывод, который он делает: «Secretly не доставляет
// сообщения». Это худший вид отказа — тот, что выглядит как исправная работа.
//
// Проверка идёт через шов `debugPermissionProbe`: настоящий путь ведёт в
// платформенный канал, которого в тесте нет, а на сборщике CI нет и самой
// macOS. Без шва проверка молчала бы ровно там, где нужна.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';

void main() {
  // `AppController` в конструкторе поднимает проигрыватель, а тот — канал
  // звуковой сессии. Без инициализированной привязки канал бросает ошибку
  // ещё до того, как дело дойдёт до уведомлений.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopNotificationService svc;

  setUp(() {
    svc = DesktopNotificationService(controller: AppController());
  });

  tearDown(() {
    DesktopNotificationService.debugPermissionProbe = null;
    DesktopNotificationService.instance = null;
  });

  test('пока не спросили — ни «да», ни «нет»', () {
    // Тревога до ответа была бы ложной, а ложная тревога обесценивает
    // настоящую: её перестают читать.
    expect(svc.systemAllowed.value, isNull);
  });

  test('🔴 система отказала — приложение об этом ЗНАЕТ', () async {
    DesktopNotificationService.debugPermissionProbe = () async => false;
    await svc.refreshSystemPermission();
    expect(svc.systemAllowed.value, isFalse);
  });

  test('система разрешила — предупреждения нет', () async {
    DesktopNotificationService.debugPermissionProbe = () async => true;
    await svc.refreshSystemPermission();
    expect(svc.systemAllowed.value, isTrue);
  });

  test('🔴 система промолчала — прежний ответ НЕ затирается', () async {
    // `null` от системы — это «не ответила», а не «запрещено». Принять
    // молчание за отказ значит показать плашку на ровном месте.
    DesktopNotificationService.debugPermissionProbe = () async => true;
    await svc.refreshSystemPermission();
    DesktopNotificationService.debugPermissionProbe = () async => null;
    await svc.refreshSystemPermission();
    expect(svc.systemAllowed.value, isTrue);
  });

  test('возвращение в окно перепроверяет разрешение', () async {
    // Человек уходит в системные настройки и возвращается — плашка должна
    // исчезнуть сама, без перезапуска приложения.
    DesktopNotificationService.debugPermissionProbe = () async => false;
    await svc.refreshSystemPermission();
    expect(svc.systemAllowed.value, isFalse);

    DesktopNotificationService.debugPermissionProbe = () async => true;
    svc.setWindowFocused(false);
    svc.setWindowFocused(true);
    await Future<void>.delayed(Duration.zero);
    expect(svc.systemAllowed.value, isTrue);
  });

  test('🔴 ответ на запрос разрешения больше не выбрасывается', () {
    // Сторож против возврата прежнего вида: запрос без сверки с системой.
    final src = File(
      'lib/ui/desktop/services/desktop_notification_service.dart',
    ).readAsStringSync();
    expect(src.contains('.whenComplete(refreshSystemPermission)'), isTrue,
        reason: 'запрос разрешения обязан заканчиваться сверкой с системой');
    expect(src.contains('macImpl.checkPermissions()'), isTrue);
  });

  test('🔴 у раздела «Уведомления» есть отметка в боковой колонке', () {
    // Иначе про запрет человек узнаёт, только если сам откроет раздел, —
    // то есть последним и случайно.
    final src = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(src.contains('_NotificationsAlertDot'), isTrue);
    expect(src.contains('_SystemNotificationsBlockedCard'), isTrue);
    expect(src.contains('allowed == false'), isTrue,
        reason: 'плашка показывается ТОЛЬКО при отказе, не при молчании');
  });

  testWidgets('🔴 при отказе раздел «Уведомления» ПОКАЗЫВАЕТ плашку',
      (t) async {
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    DesktopNotificationService.instance = svc;
    svc.systemAllowed.value = false;

    await t.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SettingsWorkspace(initialSectionId: 'notifications')),
      ),
    ));
    await t.pumpAndSettle();

    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(find.text(ru.desktopNotifBlockedTitle), findsOneWidget);
    expect(find.text(ru.desktopNotifBlockedAction), findsOneWidget);

    // Разрешили — плашка уходит сама, без перестроения страницы руками.
    svc.systemAllowed.value = true;
    await t.pumpAndSettle();
    expect(find.text(ru.desktopNotifBlockedTitle), findsNothing);
  });

  testWidgets('пока система молчит — никакой плашки', (t) async {
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    DesktopNotificationService.instance = svc;
    expect(svc.systemAllowed.value, isNull);

    await t.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SettingsWorkspace(initialSectionId: 'notifications')),
      ),
    ));
    await t.pumpAndSettle();
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(find.text(ru.desktopNotifBlockedTitle), findsNothing);
  });
}
