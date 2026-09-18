// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../security/qr_payload.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'qr_scan_screen.dart';
import 'widgets/frosted_top_bar.dart';

class VerifyContactScreen extends StatefulWidget {
  const VerifyContactScreen({
    super.key,
    required this.controller,
    required this.peerProfileId,
    required this.title,
  });

  final AppController controller;
  final String peerProfileId;
  final String title;

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    if (!widget.controller.keysOnline) return;
    setState(() => _refreshing = true);
    try {
      await widget.controller.refreshContactDevices(widget.peerProfileId);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<String> _fingerprintFromIdentityB64(String b64) async {
    try {
      final bytes = base64Decode(b64);
      final h = await Sha256().hash(bytes);
      final hex = h.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final shortHex = hex.substring(0, 24);
      return '${shortHex.substring(0, 6)}-${shortHex.substring(6, 12)}-${shortHex.substring(12, 18)}-${shortHex.substring(18, 24)}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = !widget.controller.keysOnline;
    final l10n = context.l10n;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          l10n.verifyTitle(widget.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.scanQr,
            onPressed: () async {
              final raw = await QrScanScreen.scan(
                context,
                title: l10n.scanVerifyQrTitle,
              );
              if (raw == null || raw.trim().isEmpty) return;
              final p = QrPayload.tryParse(raw);
              final pid = p.secretlyId;
              final did = p.deviceId;
              final ik = p.identityKeyPubB64;
              final qrKeys = (p.keysBaseUrl ?? '').trim();

              if (qrKeys.isNotEmpty) {
                try {
                  final qrUri = Uri.parse(qrKeys);
                  final here = widget.controller.keysBaseUrl;
                  final sameHost =
                      qrUri.host.isNotEmpty && qrUri.host == here.host;
                  final samePort =
                      (qrUri.hasPort
                          ? qrUri.port
                          : (qrUri.scheme == 'https' ? 443 : 80)) ==
                      (here.hasPort
                          ? here.port
                          : (here.scheme == 'https' ? 443 : 80));
                  final sameScheme = qrUri.scheme == here.scheme;
                  if (!(sameHost && samePort && sameScheme)) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SecretlySnackBar(
                        content: Text(
                          l10n.qrBelongsAnotherServer(qrUri.toString()),
                        ),
                      ),
                    );
                    return;
                  }
                } catch (_) {
                  // ignore invalid URL
                }
              }

              if (pid == null || pid.isEmpty || pid != widget.peerProfileId) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SecretlySnackBar(content: Text(l10n.qrSecretlyIdMismatch)),
                );
                return;
              }
              if (did == null || did.isEmpty || ik == null || ik.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SecretlySnackBar(content: Text(l10n.qrMissingDeviceKeyInfo)),
                );
                return;
              }

              var devices = await widget.controller.listContactDevices(
                widget.peerProfileId,
              );
              var match = devices
                  .where((d) => d.deviceId == did)
                  .toList(growable: false);
              if (match.isEmpty) {
                // Best-effort auto-refresh so the user doesn't have to press Refresh manually.
                if (widget.controller.keysOnline) {
                  try {
                    await widget.controller.refreshContactDevices(
                      widget.peerProfileId,
                    );
                    devices = await widget.controller.listContactDevices(
                      widget.peerProfileId,
                    );
                    match = devices
                        .where((d) => d.deviceId == did)
                        .toList(growable: false);
                  } catch (_) {
                    // ignore
                  }
                }

                if (match.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SecretlySnackBar(
                      content: Text(l10n.deviceNotCachedTapRefresh),
                    ),
                  );
                  return;
                }
              }
              if (match.first.identityKeyPubB64 != ik) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SecretlySnackBar(content: Text(l10n.identityKeyMismatch)),
                );
                return;
              }

              await widget.controller.markContactDeviceVerified(
                peerProfileId: widget.peerProfileId,
                peerDeviceId: did,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SecretlySnackBar(content: Text(l10n.verifiedSuccess)),
              );
            },
            icon: const Icon(AppIcons.qrScanner),
          ),
          IconButton(
            tooltip: l10n.refreshKeys,
            onPressed: offline || _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 16),
        children: [
          if (offline) ...[
            Text(
              l10n.keysOfflineCannotFetch,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            l10n.secretlyIdLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SelectableText(widget.peerProfileId),
          const SizedBox(height: 16),
          Text(
            l10n.devicesLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          StreamBuilder<void>(
            stream: widget.controller.changed,
            builder: (context, _) {
              return FutureBuilder<List<ContactDevice>>(
                future: widget.controller.listContactDevices(
                  widget.peerProfileId,
                ),
                builder: (context, snap) {
                  final devices = snap.data ?? const [];
                  if (devices.isEmpty) {
                    return Text(l10n.noDeviceKeysCachedYet);
                  }

                  return Column(
                    children: devices
                        .map((d) {
                          final verified = d.verifiedAtMs != null;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                verified
                                    ? AppIcons.verifiedOutline
                                    : AppIcons.shield,
                              ),
                              title: Text(
                                l10n.deviceTitle(d.deviceId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: FutureBuilder<String>(
                                future: _fingerprintFromIdentityB64(
                                  d.identityKeyPubB64,
                                ),
                                builder: (context, fpSnap) {
                                  final fp =
                                      fpSnap.data ??
                                      (fpSnap.hasError ? '—' : '…');
                                  return Text(
                                    l10n.deviceFpStatus(
                                      fp,
                                      verified
                                          ? l10n.verifiedLower
                                          : l10n.unverifiedLower,
                                    ),
                                  );
                                },
                              ),
                              trailing: verified
                                  ? const Icon(AppIcons.checkCircle)
                                  : TextButton(
                                      onPressed: () async {
                                        await widget.controller
                                            .markContactDeviceVerified(
                                              peerProfileId: d.profileId,
                                              peerDeviceId: d.deviceId,
                                            );
                                      },
                                      child: Text(l10n.verify),
                                    ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
