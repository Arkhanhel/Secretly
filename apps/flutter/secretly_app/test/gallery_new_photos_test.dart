// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 26.11.2026: новые фото (скриншот, скачанное) не появлялись в скрепке до
// перезапуска — общий набор условий photo_manager держал «не позже, чем
// сейчас» с момента первого открытия.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  test('условие даты photo_manager по умолчанию — «не позже момента создания»', () {
    final before = DateTime.now();
    final cond = DateTimeCond.def();
    expect(cond.ignore, isFalse);
    expect(cond.max.isBefore(before.add(const Duration(seconds: 5))), isTrue);
    expect(DateTimeCond.def().copyWith(ignore: true).ignore, isTrue);
  });

  test('🔴 скрепка строит условия на каждый запрос и без границы по дате', () {
    final s = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    expect(s, isNot(contains('static final FilterOptionGroup')));
    expect(s, contains('static FilterOptionGroup get _galleryOrder => FilterOptionGroup('));
    expect(s, contains('createTimeCond: DateTimeCond.def().copyWith(ignore: true),'));
  });
}
