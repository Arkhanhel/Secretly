// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Generates the Support X25519 keypair.
// Uses the SAME SupportSeal construction the app + admin console use, so the
// keys are guaranteed compatible.
//
//   dart run tool/gen_support_key.dart
//
// PUBLIC key  → keys-server env  SECRETLY_SUPPORT_PUB_B64  (ships in signed
//                                 /v1/config; enable with SECRETLY_SUPPORT_ENABLED=1)
// PRIVATE seed → admin console ONLY  SECRETLY_SUPPORT_PRIV_SEED_B64
//               (never put the private seed on the server/relay).
import 'dart:convert';
import 'dart:io';

import 'package:secretly_app/crypto/support_seal.dart';

Future<void> main() async {
  final kp = await SupportSeal.generateKeypair();
  final pub = base64Encode(kp.publicKey);
  final priv = base64Encode(kp.privateSeed);

  stdout.writeln('Support keypair generated — keep the PRIVATE seed secret.\n');
  stdout.writeln('# keys-server (public — ships in signed /v1/config):');
  stdout.writeln('SECRETLY_SUPPORT_PUB_B64=$pub');
  stdout.writeln('SECRETLY_SUPPORT_ENABLED=1\n');
  stdout.writeln('# admin console ONLY (private — NEVER on the server/relay):');
  stdout.writeln('SECRETLY_SUPPORT_PRIV_SEED_B64=$priv');
}
