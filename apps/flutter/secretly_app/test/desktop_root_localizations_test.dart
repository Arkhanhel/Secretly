// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Корень окна не ищет переводы на СВОЁМ контексте.
//
// 🔴 ЧТО ЭТО ЗА ДЕФЕКТ (найден 21.09.2026).
//
// `_DesktopProductionAppState` СТРОИТ `MaterialApp`. Значит его собственный
// `context` лежит ВЫШЕ `Localizations`, которые `MaterialApp` вставляет под
// собой, а поиск идёт среди предков. `AppLocalizations.of(context)` оттуда —
// всегда null, и `!` рядом с ним — всегда исключение.
//
// Молчаливое. `_installDesktopErrorGuard` гасит красное полотно, поэтому
// наружу выходит не поломка, а ПРОПАЖА: с 20.09.2026 (`224f2a63`, перевод окна
// на ARB) хлебные крошки в шапке окна бросали исключение при каждой сборке, и
// строка заголовка — стрелки «назад»/«вперёд», поле ⌘K, кнопка «не беспокоить»
// — не рисовалась вовсе. В журнале это шесть `ui.widget_error` подряд.
//
// Первый тест доказывает саму причину на живом дереве, а не рассуждением.
// Второй стережёт файл: соблазн написать `AppLocalizations.of(context)!` в
// корне возвращается каждый раз, когда там появляется новая подпись.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  AppLocalizations? seenFromRootContext;

  @override
  Widget build(BuildContext context) {
    // Ровно то, что делал корень окна.
    seenFromRootContext = AppLocalizations.of(context);
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('.')),
    );
  }
}

void main() {
  testWidgets('🔴 на контексте строителя MaterialApp переводов НЕТ', (t) async {
    await t.pumpWidget(const _Root());
    await t.pumpAndSettle();
    expect(
      t.state<_RootState>(find.byType(_Root)).seenFromRootContext,
      isNull,
      reason: 'если это однажды станет не-null, запасной путь в l10n корня '
          'можно упрощать — но не раньше',
    );
  });

  test('🔴 корень окна не берёт переводы со своего контекста', () {
    final src = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    // Комментарии отбрасываем: в этом файле об ошибке НАПИСАНО, и искать
    // строку по всему тексту значило бы ловить собственное объяснение.
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    // Внутри корня допустим только явный контекст ИЗ приложения: ключ
    // `_OverlayHost` или контекст, переданный в обработчик.
    expect(
      code.contains('AppLocalizations.of(context)!'),
      isFalse,
      reason: 'это всегда null — см. заголовок файла. Нужен контекст ниже '
          'MaterialApp: `_overlayHostKey.currentContext` или тот, что пришёл '
          'в метод параметром',
    );
    // И сам запасной путь на месте: без него первые кадры снова падали бы.
    expect(src.contains('lookupAppLocalizations(_localeForStrings)'), isTrue);
  });
}
