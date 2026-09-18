// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Четыре мелочи списка чатов, сверенные с макетом.
//
// Все четыре про один и тот же перекос: список повторял сам себя (булавка на
// строке под заголовком «ЗАКРЕПЛЁННЫЕ», линия там же) и при этом отнимал
// сведения там, где они нужны (точка вместо числа у молчаливого чата).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/radii.dart';

void main() {
  final panel = File(
    'lib/ui/desktop/chat/chat_list_panel.dart',
  ).readAsStringSync();

  test('· линия только у датных заголовков, у «Закреплённых» её нет', () {
    // Там признак несёт булавка, и линия становилась второй чертой подряд.
    final i = panel.indexOf('class _SectionHeader');
    final body = panel.substring(i, i + 1900);
    expect(body.contains('if (icon == null)'), isTrue);
    expect(body.contains('const Spacer(),'), isTrue);
    expect(body.contains('Icon(icon, size: 14'), isTrue);
  });

  test('· булавки на самой строке больше нет', () {
    // Она повторяла заголовок раздела и сдвигала имя вправо, ломая ровный
    // столбик имён.
    expect(panel.contains('if (item.pinned) ...['), isFalse);
    // Но само поле по-прежнему строит раздел.
    expect(panel.contains('item.pinned'), isTrue);
  });

  test('· значок молчания стоит сразу после имени, а не у счётчика', () {
    final name = panel.indexOf('БУЛАВКИ НА САМОЙ СТРОКЕ НЕТ');
    final mute = panel.indexOf('alert_off_24_regular', name);
    final badge = panel.indexOf('if (item.unread > 0)', name);
    expect(mute, greaterThan(name));
    expect(
      mute,
      lessThan(badge),
      reason: 'у счётчика он читался как свойство счётчика, а не чата',
    );
  });

  test('🔴 у молчаливого чата счётчик с ЧИСЛОМ, а не точка', () {
    // Точка говорила «что-то есть» и отнимала само число — а у молчаливого
    // чата число как раз и решает, заходить сейчас или потом: звук выключен,
    // и напомнить о разговоре больше нечему.
    // Ветку молчаливого чата ищем по ней самой, а не окном от начала
    // функции: 16.09 перед ней встала ветка выбранной строки, а сам счётчик
    // стал общей функцией обычной и свёрнутой строки.
    final fn = panel.indexOf('Widget _chatUnreadBadge(');
    expect(fn, greaterThan(0));
    final i = panel.indexOf('if (item.muted) {', fn);
    expect(i, greaterThan(fn));
    final body = panel.substring(i, i + 700);
    expect(RegExp(r'width: 8,\s+height: 8,').hasMatch(body), isFalse);
    expect(body.contains('shape: BoxShape.circle'), isFalse);
    expect(body.contains('Colors.white.withValues(alpha: 0.14)'), isTrue);
    expect(RegExp(r'Text\(\s+txt,').hasMatch(body), isTrue);
  });

  test('🔴 выбранная строка — сплошная заливка, без полоски у края', () {
    // До 16.09 выбранную строку отмечали тихая подсветка и полоска у левого
    // края. Владелец прислал скриншот телеграма: там открытый чат залит цветом
    // целиком, текст на нём белый — и где ты сейчас, видно через всю панель.
    // Полоска рядом со сплошной заливкой ничего не добавляла.
    expect(panel.contains('topRight: Radius.circular(3)'), isFalse);
    expect(
      panel.contains(
        'color: selected\n                ? selectedChatRowFill(c.accentPrimary)',
      ),
      isTrue,
    );
    // Радиус самой строки — 12 из макета: скругление телеграма того же рода.
    expect(panel.contains('BorderRadius.circular(DRadii.r12)'), isTrue);
    expect(DRadii.r12, 12);
  });

  test('· ширина панели списка по умолчанию — 322', () {
    final shell = File(
      'lib/ui/desktop/shell/desktop_shell.dart',
    ).readAsStringSync();
    expect(shell.contains('(_listWidth ?? 322)'), isTrue);
  });
}
