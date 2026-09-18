// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/transport/service_health_status.dart';
import 'package:secretly_app/ui/attachment_error_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('describeAttachmentFailure classifies legacy attachment errors', () {
    final tooLarge = describeAttachmentFailure(
      StateError('ATTACH_TOO_LARGE:15728640'),
    );
    expect(tooLarge.code, AttachmentFailureCode.tooLarge);
    expect(tooLarge.bytes, 15728640);

    expect(
      describeAttachmentFailure(StateError('ATTACH_FILE_MISSING')).code,
      AttachmentFailureCode.fileMissing,
    );
    expect(
      describeAttachmentFailure(
        StateError(
          'Recipient profile not found on server. (peer_profile_id=peer-1)',
        ),
      ).code,
      AttachmentFailureCode.recipientProfileNotFound,
    );
    expect(
      describeAttachmentFailure(TimeoutException('upload timeout')).code,
      AttachmentFailureCode.uploadTimedOut,
    );
  });

  test('attachmentErrorText localizes typed attachment failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      attachmentErrorText(
        l10n,
        AttachmentFailure(AttachmentFailureCode.tooLarge, bytes: 15728640),
      ),
      'Attachment is too large (15 MB).',
    );
    expect(
      attachmentErrorText(
        l10n,
        AttachmentFailure(AttachmentFailureCode.contactSyncPending),
      ),
      'Waiting for contact identity sync. Ask the contact to send one more message and try again.',
    );
    expect(
      attachmentErrorText(
        l10n,
        AttachmentFailure(AttachmentFailureCode.recipientNoDevices),
      ),
      'Recipient has no registered devices yet. Ask the contact to open Secretly and try again.',
    );
    expect(
      attachmentErrorText(
        l10n,
        AttachmentFailure(AttachmentFailureCode.generic),
      ),
      'Couldn\'t send the attachment. Try again.',
    );
  });

  test(
    'sendAttachment emits typed local-unavailable failure when controller is not ready',
    () async {
      final controller = AppController();

      await expectLater(
        controller.sendAttachment(
          peerProfileId: 'peer-1',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        throwsA(
          isA<AttachmentFailure>().having(
            (e) => e.code,
            'code',
            AttachmentFailureCode.localUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'sendAttachment rejects oversized byte payloads before transport setup',
    () async {
      final controller = AppController();

      await expectLater(
        controller.sendAttachment(
          peerProfileId: 'peer-1',
          bytes: Uint8List(AppController.maxAttachmentBytesForTest + 1),
        ),
        throwsA(
          isA<AttachmentFailure>()
              .having((e) => e.code, 'code', AttachmentFailureCode.tooLarge)
              .having(
                (e) => e.bytes,
                'bytes',
                AppController.maxAttachmentBytesForTest + 1,
              ),
        ),
      );
    },
  );

  test(
    'sendAttachment honors lower relay-advertised attachment cap before transport setup',
    () async {
      final controller = AppController();
      controller.seedServiceHealthForTesting(
        relayHealthStatus: const ServiceHealthStatus(
          httpStatusCode: 200,
          reachable: true,
          service: 'relay',
          status: 'ok',
          serverProtocolVersion: 1,
          minClientProtocolVersion: 1,
          maxClientProtocolVersion: 1,
          compatibilityState: ServiceCompatibilityState.supported,
          maxRequestBodyBytes: 512,
          maxAttachmentBytes: 512,
        ),
      );

      await expectLater(
        controller.sendAttachment(
          peerProfileId: 'peer-1',
          bytes: Uint8List(513),
        ),
        throwsA(
          isA<AttachmentFailure>()
              .having((e) => e.code, 'code', AttachmentFailureCode.tooLarge)
              .having((e) => e.bytes, 'bytes', 513),
        ),
      );
    },
  );

  test(
    'sendAttachmentFile emits typed file-missing failure before transport setup',
    () async {
      final controller = AppController();

      await expectLater(
        controller.sendAttachmentFile(
          peerProfileId: 'peer-1',
          filePath: 'd:/Secretly/__missing_attachment_for_test__.bin',
        ),
        throwsA(
          isA<AttachmentFailure>().having(
            (e) => e.code,
            'code',
            AttachmentFailureCode.fileMissing,
          ),
        ),
      );
    },
  );

  test(
    'sendAttachmentFiles rejects an empty batch before transport setup',
    () async {
      final controller = AppController();

      await expectLater(
        controller.sendAttachmentFiles(
          peerProfileId: 'peer-1',
          files: const <AttachmentFileSendRequest>[],
        ),
        throwsA(
          isA<AttachmentFailure>().having(
            (e) => e.code,
            'code',
            AttachmentFailureCode.fileMissing,
          ),
        ),
      );
    },
  );

  test(
    'sendAttachmentFiles validates every file before transport setup',
    () async {
      final controller = AppController();

      await expectLater(
        controller.sendAttachmentFiles(
          peerProfileId: 'peer-1',
          files: const <AttachmentFileSendRequest>[
            AttachmentFileSendRequest(
              filePath: 'd:/Secretly/__missing_batch_attachment_for_test__.bin',
            ),
          ],
        ),
        throwsA(
          isA<AttachmentFailure>().having(
            (e) => e.code,
            'code',
            AttachmentFailureCode.fileMissing,
          ),
        ),
      );
    },
  );
}
