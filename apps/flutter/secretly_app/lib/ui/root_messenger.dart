// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Ключ единственного [ScaffoldMessenger] приложения.
///
/// 🔴 ЗАЧЕМ ОН НУЖЕН: СООБЩЕНИЕ ОБЯЗАНО ПЕРЕЖИТЬ ЭКРАН, С КОТОРОГО ПРИШЛО.
///
/// Найдено на живом телефоне 15.09.2026. Экран «Восстановить аккаунт»
/// сообщал об ошибке через `ScaffoldMessenger.of(context)` — и падал с
/// `No ScaffoldMessenger widget found`, потому что к моменту ответа его
/// собственный элемент уже был снят с дерева: длинная операция (запрос
/// резервной копии с сервера) переживает страницу, а у снятого элемента поиск
/// наследуемых виджетов не находит ничего.
///
/// Итог был худшим из возможных: человек, у которого не восстановился
/// аккаунт, не получал НИКАКОГО объяснения — вместо надписи приложение
/// роняло неперехваченное исключение. Экран восстановления — ровно то место,
/// где молчать нельзя.
///
/// Ключ висит на корневом [MaterialApp], живёт всё время работы приложения и
/// не зависит ни от одного экрана. Поэтому сообщение показывается даже тогда,
/// когда страница, которая его заказала, уже закрылась.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Показывает сообщение, откуда бы его ни позвали.
///
/// Порядок поиска: сначала корневой [ScaffoldMessenger] (он есть всегда),
/// потом — ближайший к [context], если корневой почему-то ещё не собран.
/// [ScaffoldMessenger.maybeOf] вместо `of`: этот путь не имеет права падать,
/// он и заведён ради того, чтобы не падать.
///
/// Текст передаётся ГОТОВЫМ, а не собирается здесь: за `context.l10n` стоит
/// тот же поиск по дереву, и на снятом элементе он упал бы первым — до того,
/// как дело дошло бы до самого сообщения.
void showRootSnackBar(SnackBar snackBar, {BuildContext? context}) {
  final messenger =
      rootScaffoldMessengerKey.currentState ??
      (context == null ? null : ScaffoldMessenger.maybeOf(context));
  messenger?.showSnackBar(snackBar);
}
