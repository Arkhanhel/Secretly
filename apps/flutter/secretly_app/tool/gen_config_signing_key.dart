// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// One-off generator for the monetization config-signing Ed25519 keypair
// (TZ-MONETIZE-01). Run from the app dir:
//
//   dart run tool/gen_config_signing_key.dart /absolute/path/to/private.env
//
// Writes `SECRETLY_KEYS_CONFIG_SIGNING_KEY=<base64 32-byte seed>` to the given
// file (the SERVER private key — keep secret) and prints
// `SECRETLY_CONFIG_PUBLIC_KEY_B64=<base64 32-byte public key>` to stdout (safe
// to embed in the client build). The private seed is never printed.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/gen_config_signing_key.dart <private-out-file>');
    exit(2);
  }
  final algo = Ed25519();
  final keyPair = await algo.newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes(); // 32-byte Ed25519 seed
  final pub = (await keyPair.extractPublicKey()).bytes; // 32-byte public key

  final seedB64 = base64.encode(seed);
  final pubB64 = base64.encode(pub);

  final outFile = File(args[0]);
  outFile.writeAsStringSync('SECRETLY_KEYS_CONFIG_SIGNING_KEY=$seedB64\n');

  stdout.writeln('OK seed_bytes=${seed.length} pub_bytes=${pub.length}');
  stdout.writeln('SECRETLY_CONFIG_PUBLIC_KEY_B64=$pubB64');
}
