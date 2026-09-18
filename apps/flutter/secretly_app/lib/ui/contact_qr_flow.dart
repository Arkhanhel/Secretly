// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../app/message_command_utils.dart';
import '../security/qr_payload.dart';
import 'animations/animations.dart';
import 'chat_screen.dart';
import 'contact_action_error_text.dart';
import 'l10n.dart';

class ContactQrScanOutcome {
  const ContactQrScanOutcome({
    required this.profileId,
    required this.displayName,
    required this.deviceVerified,
  });

  final String profileId;
  final String? displayName;
  final bool deviceVerified;
}

@visibleForTesting
bool qrMatchesKeysServer(String? qrKeysBaseUrl, Uri appKeysBaseUrl) {
  final normalizedQrKeysBaseUrl = (qrKeysBaseUrl ?? '').trim();
  if (normalizedQrKeysBaseUrl.isEmpty) {
    return true;
  }

  final Uri qrUri;
  try {
    qrUri = Uri.parse(normalizedQrKeysBaseUrl);
  } catch (_) {
    return true;
  }

  final sameHost = qrUri.host.isNotEmpty && qrUri.host == appKeysBaseUrl.host;
  final samePort =
      (qrUri.hasPort ? qrUri.port : (qrUri.scheme == 'https' ? 443 : 80)) ==
      (appKeysBaseUrl.hasPort
          ? appKeysBaseUrl.port
          : (appKeysBaseUrl.scheme == 'https' ? 443 : 80));
  final sameScheme = qrUri.scheme == appKeysBaseUrl.scheme;
  return sameHost && samePort && sameScheme;
}

Future<ContactQrScanOutcome?> handleContactQrScan({
  required BuildContext context,
  required AppController controller,
  required String raw,
  bool openChatOnSuccess = false,
}) async {
  final payload = QrPayload.tryParse(raw);
  final profileId = (payload.secretlyId ?? '').trim();
  if (profileId.isEmpty) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(context.l10n.qrMissingSecretlyId)));
    return null;
  }

  final qrKeysBaseUrl = (payload.keysBaseUrl ?? '').trim();
  if (!qrMatchesKeysServer(qrKeysBaseUrl, controller.keysBaseUrl)) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.differentServerTitle),
          content: Text(
            context.l10n.differentServerBody(
              qrKeysBaseUrl,
              controller.keysBaseUrl.toString(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
    return null;
  }

  try {
    final displayName = _trimmedNonEmpty(payload.nickname);
    await controller.addContact(profileId: profileId, displayName: displayName);

    // Tell the peer who scanned them so they auto-add us as a contact instead of
    // routing our first message into their Requests inbox.
    final ownName = controller.myNickname.trim();
    unawaited(
      controller
          .sendControlMessage(
            peerProfileId: profileId,
            controlText: buildQrPairingIntroductionCommand(
              scannerDisplayName: ownName.isEmpty ? null : ownName,
            ),
          )
          .catchError((_) {}),
    );

    var deviceVerified = false;
    final deviceId = _trimmedNonEmpty(payload.deviceId);
    final identityKeyPubB64 = _trimmedNonEmpty(payload.identityKeyPubB64);
    if (deviceId != null &&
        identityKeyPubB64 != null &&
        controller.keysOnline) {
      try {
        await controller.refreshContactDevices(profileId);
        final devices = await controller.listContactDevices(profileId);
        final match = devices
            .where((device) => device.deviceId == deviceId)
            .toList(growable: false);
        if (match.isNotEmpty &&
            match.first.identityKeyPubB64 == identityKeyPubB64) {
          await controller.markContactDeviceVerified(
            peerProfileId: profileId,
            peerDeviceId: deviceId,
          );
          deviceVerified = true;
        }
      } catch (_) {
        // Best-effort only; the contact itself was already added.
      }
    }

    final outcome = ContactQrScanOutcome(
      profileId: profileId,
      displayName: displayName,
      deviceVerified: deviceVerified,
    );
    if (!openChatOnSuccess || !context.mounted) {
      return outcome;
    }

    final resolvedTitle = (await controller.resolveConvoTitle(
      profileId,
    )).trim();
    if (!context.mounted) {
      return outcome;
    }
    Navigator.of(context).pushReplacement(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: controller,
          convoId: profileId,
          title: resolvedTitle.isEmpty
              ? (displayName ?? profileId)
              : resolvedTitle,
          peerProfileIdForSend: profileId,
        ),
      ),
    );
    return outcome;
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(content: Text(contactActionErrorText(context.l10n, error))),
    );
    return null;
  }
}

String? _trimmedNonEmpty(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
