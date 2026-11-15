// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// О11 (разбор медиа 15.11.2026): отказы сервера на загрузку — своими словами,
// а не «сервис недоступен». Строки — ровно те, что отдаёт реле.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/l10n/app_localizations_ru.dart';
import 'package:secretly_app/ui/attachment_error_text.dart';

void main() {
  AttachmentFailureCode code(String body) =>
      classifyAttachmentFailure(StateError('blob upload failed: $body'));

  test('413 — «слишком большой для сервера»', () {
    expect(code('413 blob too large'), AttachmentFailureCode.serverRejectedSize);
  });

  test('507 — нет места / исчерпан объём различаются', () {
    expect(
      code('507 server storage full'),
      AttachmentFailureCode.serverStorageFull,
    );
    expect(
      code('507 blob quota exceeded'),
      AttachmentFailureCode.uploadQuotaExceeded,
    );
  });

  test('прочие сбои загрузки — по-прежнему «сервис недоступен»', () {
    expect(code('502 bad gateway'), AttachmentFailureCode.serviceUnavailable);
    expect(code('500 internal'), AttachmentFailureCode.serviceUnavailable);
  });

  test('тексты на русском', () {
    final l10n = AppLocalizationsRu();
    expect(
      attachmentErrorText(l10n, StateError('blob upload failed: 507 blob quota exceeded')),
      contains('7 дней'),
    );
    expect(
      attachmentErrorText(l10n, StateError('blob upload failed: 413 blob too large')),
      contains('слишком большой'),
    );
  });
}
