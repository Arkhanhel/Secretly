// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Makes the controller↔UI seam stick.
//
// A facade nobody is required to use is a facade that gets bypassed: the next
// screen imports `app_controller.dart` directly because it is one line shorter,
// and in a month there is no seam again. Two numbers are recorded here and
// neither may grow:
//
//   1. Desktop UI files importing `app_controller.dart` directly. Every one is
//      a widget that can reach any of the controller's ~119 members and open
//      its own subscription.
//   2. Independent subscriptions to the catch-all `changed` bus. Each one
//      re-queries on its own schedule with its own ad-hoc debounce; that is
//      the duplication [DesktopSelectorHub] exists to collapse.
//
// Both are exact: a migration that removes one must lower the number in the
// same commit, so what is written here is always the truth rather than a
// ceiling somebody stopped looking at.
//
// See docs/DESKTOP_STRATEGY_REVIEW_2026-09-08.md §6.5.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The seam itself. It imports the controller by design — that is the whole
/// point of it — so it is not counted as debt.
const String _seamFile = 'lib/ui/desktop/app/desktop_app_view_model.dart';

void main() {
  // Counts as of 2026-09-08, after migrating every desktop surface that had
  // its own `changed` subscription: calls, settings, chats (list + thread),
  // contacts, contact/room details and onboarding.
  //
  // Subscriptions fell 18 -> 2, and the two that remain are deliberate:
  //
  //   * `desktop_production_app.dart` — the ROOT. It constructs the view
  //     model, so it cannot bind to the model's own tick without a cycle, and
  //     it already diffs by hand (`_rootSignature`) — the change that took
  //     idle CPU from ~23% to ~2%. Migrating it would swap a working guard
  //     for a circular one.
  //   * `_ScopeLockCard` in `settings_workspace.dart` — listens to
  //     `controller.security.changed`, a DIFFERENT and quiet stream (it fires
  //     when a lock setting changes). Routing it through the hub would mean a
  //     second hub for one rare event.
  //
  // Lowering this to 0 is therefore NOT the goal, and a future migration
  // should not treat these two as debt.
  //
  // The importer count moves much more slowly: a file stops importing
  // `AppController` only when it stops NAMING the type, which usually means
  // every one of its panes is migrated. Two different debts, tracked
  // separately on purpose — collapsing them would let progress on one hide
  // standing still on the other.
  // 18 -> 19 (13.09.2026): `calls/room_call_window.dart` — десктопное окно
  // комнатного созвона.
  //
  // 🔴 Оно НЕ рисовальщик, а распорядитель: вход, выход и смена своих флагов
  // это вызовы контроллера, и делать их надо в том же порядке, что на телефоне
  // (`joinRelayRoomCall` → `ensureJoined(forceRefresh)`; `leaveRelayRoomCall` →
  // `clearIfMatches`). Альтернатива — пять замыканий в сигнатуре виджета,
  // которые прячут ровно ту же власть за более длинным списком параметров и
  // мешают увидеть, что порядок вызовов повторяет мобильный.
  //
  // Вторая половина долга при этом НЕ выросла: снимок созвона окно читает
  // через общий склад (`vm.select`), а не своей подпиской на `changed`.
  // 19 -> 20 (14.09.2026): `services/desktop_nav_history.dart` — история
  // открытых переписок, за которой ходят стрелки «назад»/«вперёд» в шапке
  // окна (кнопки есть в макете владельца).
  //
  // 🔴 Из контроллера берётся ОДИН ТИП ДАННЫХ — `Conversation`, и ни одного
  // метода: файл ничего не спрашивает и ничего не меняет, он хранит путь
  // человека по окну. Хранить в шаге целый снимок переписки, а не её
  // идентификатор, нужно потому, что склад выбора принимает именно объект: с
  // идентификатором «назад» пришлось бы ждать запроса к базе, и возврат
  // перестал бы быть мгновенным.
  //
  // Этот файл — спутник `chat/details/desktop_selection_store.dart`, который
  // стоит в этом же списке и ровно по той же причине: он тоже держит
  // `Conversation?` и тоже ничего у контроллера не вызывает. Долг здесь
  // одинаковой природы — имя типа, а не власть над контроллером.
  // 20 -> 21 (14.09.2026): `chat/details/room_invite_share.dart` — общая
  // последовательность «взять годную ссылку-приглашение или завести новую».
  //
  // 🔴 Файл действительно ЗОВЁТ контроллер (`createRoomInviteLink`), и это
  // осознанно. Альтернатива — принимать создание ссылки колбэком — вернула бы
  // ровно ту дубликацию, ради устранения которой файл и появился: тот же
  // порядок действий пришлось бы повторить в панели комнаты и в окне созвона.
  // А разъехаться им нельзя: сперва ищется УЖЕ годная ссылка (иначе каждое
  // нажатие плодит новую, а их число у комнаты ограничено правилами), и новая
  // наследует «вступление по подтверждению» — не унаследовать значит тихо
  // открыть комнату, которую владелец закрыл.
  //
  // Вторая половина долга не выросла: своей подписки на `changed` у файла нет,
  // он вообще не виджет.
  const int directImporterBaseline = 21;
  // 2 -> 1 (17.09.2026): счёт уточнён, а не долг погашен. Подписки на
  // `controller.security.changed` — ТИХИЙ поток замков, а не общая шина
  // (о том же уже сказано выше про `_ScopeLockCard`), и считать их вместе с
  // шиной значило бы мерить не то, что заявлено в названии теста. Замков на
  // компьютере теперь слушают три места: карточка настроек, корень
  // (экран «Вход в приложение») и список чатов (снова запертые «Личные»).
  // На шину по-прежнему подписан только корень.
  const int changedSubscriptionBaseline = 1;

  test('desktop files importing AppController directly do not increase', () {
    final offenders = <String>[];
    for (final file in _desktopDartFiles()) {
      if (file.path == _seamFile) continue;
      if (file.readAsStringSync().contains('app_controller.dart')) {
        offenders.add(file.path);
      }
    }
    offenders.sort();

    expect(
      offenders.length,
      lessThanOrEqualTo(directImporterBaseline),
      reason:
          'A new desktop file reaches into AppController directly. Add what it '
          'needs to DesktopAppViewModel and bind to that instead.\n'
          '${offenders.join('\n')}',
    );
    expect(
      offenders.length,
      directImporterBaseline,
      reason:
          'A file stopped importing AppController — lower '
          'directImporterBaseline to ${offenders.length} in this test to lock '
          'the win in.',
    );
  });

  test('independent subscriptions to `changed` do not increase', () {
    // `.changed.listen(...)` and `StreamBuilder(stream: ....changed)`.
    // Comments are skipped so prose describing the old pattern — including the
    // comments explaining these very migrations — is not counted as one.
    // `security.changed` — поток замков, не шина: см. базовое число выше.
    final subscription = RegExp(
      r'(?<!security)\.changed\.listen|stream:\s*[A-Za-z_.]*(?<!security)\.changed',
    );
    final comment = RegExp(r'^\s*(///|//)');

    final perFile = <String, int>{};
    for (final file in _desktopDartFiles()) {
      var count = 0;
      for (final line in file.readAsLinesSync()) {
        if (comment.hasMatch(line)) continue;
        count += subscription.allMatches(line).length;
      }
      if (count > 0) perFile[file.path] = count;
    }
    final total = perFile.values.fold<int>(0, (a, b) => a + b);

    final worst = perFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    expect(
      total,
      lessThanOrEqualTo(changedSubscriptionBaseline),
      reason:
          'Another place subscribed to the catch-all invalidation bus on its '
          'own terms. Use a DesktopSelector so the query is debounced once and '
          'republished only on a real change.\n'
          '${worst.take(5).map((e) => '  ${e.key}: ${e.value}').join('\n')}',
    );
    expect(
      total,
      changedSubscriptionBaseline,
      reason:
          'A subscription was migrated onto the view model — lower '
          'changedSubscriptionBaseline to $total in this test to lock the win '
          'in.',
    );
  });

  test('the seam exists and is the only sanctioned controller importer', () {
    final seam = File(_seamFile);
    expect(seam.existsSync(), isTrue,
        reason: 'run this test from apps/flutter/secretly_app');
    expect(
      seam.readAsStringSync().contains('app_controller.dart'),
      isTrue,
      reason: 'the seam is supposed to wrap the controller',
    );
  });
}

List<File> _desktopDartFiles() {
  final dir = Directory('lib/ui/desktop');
  expect(dir.existsSync(), isTrue,
      reason: 'run this test from apps/flutter/secretly_app');
  return <File>[
    for (final entity in dir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];
}
