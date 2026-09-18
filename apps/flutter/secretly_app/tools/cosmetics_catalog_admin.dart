// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Premium-cosmetics catalog admin (Block 3 / PR5).
//
// Generates the signed server catalog of premium profile icons + chat
// wallpapers consumed by the relay (`/v1/cosmetics/*`) and the Flutter client
// (CosmeticsCatalogService). Mirrors the sticker-catalog flow but with its own
// dedicated Ed25519 signing keypair.
//
// Usage (run from apps/flutter/secretly_app):
//   dart run tools/cosmetics_catalog_admin.dart keygen --out <private-seed-file>
//   dart run tools/cosmetics_catalog_admin.dart build \
//       --icons-dir <dir-of-png-icons> \
//       --wallpapers-dir <dir-of-jpg-wallpapers> \
//       --private-key <private-seed-file> \
//       [--output <dir>] [--max-icons N] [--max-wallpapers N]
//
// `build` writes <output>/{catalog.json, catalog.sig, icons/*, wallpapers/*}.
// The signature is over the EXACT bytes of catalog.json (what the relay serves).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const int kIconFullSize = 256;
const int kIconThumbSize = 96;
const int kWallpaperFullLongest = 1280;
const int kWallpaperThumbLongest = 220;
const int kWallpaperJpegQuality = 82;
const int kWallpaperThumbQuality = 76;
// Perceptual-dedup threshold: Hamming distance on a 64-bit dHash. <=6 catches
// near-identical / resaved / lightly-cropped wallpapers without dropping
// genuinely distinct ones.
const int kWallpaperDedupThreshold = 10;

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? '' : args.first.trim();
  final options = _parseOptions(args.skip(1));
  switch (command) {
    case 'keygen':
      await _keygen(options);
      break;
    case 'build':
      await _build(options);
      break;
    case 'verify':
      await _verify(options);
      break;
    default:
      stderr.writeln(
        'Usage:\n'
        '  keygen --out <private-seed-file>\n'
        '  build --icons-dir <dir> --wallpapers-dir <dir> '
        '--private-key <file> [--output <dir>] [--max-icons N] '
        '[--max-wallpapers N]',
      );
      exitCode = 2;
  }
}

Future<void> _keygen(Map<String, String> options) async {
  final kp = await Ed25519().newKeyPair();
  final pub = await kp.extractPublicKey();
  final seed = await kp.extractPrivateKeyBytes();
  final pubB64 = base64Encode(pub.bytes);
  final seedB64 = base64Encode(seed);
  final out = options['out']?.trim();
  if (out != null && out.isNotEmpty) {
    final f = File(out);
    await f.parent.create(recursive: true);
    await f.writeAsString('$seedB64\n');
    stdout.writeln('Private seed (base64) written to: $out');
  } else {
    stdout.writeln('PRIVATE SEED (base64 — store in ops/secrets, gitignored):');
    stdout.writeln(seedB64);
  }
  stdout.writeln('');
  stdout.writeln('PUBLIC KEY (base64 — bake into server + client):');
  stdout.writeln(pubB64);
}

Future<void> _build(Map<String, String> options) async {
  final iconsDir = options['icons-dir']?.trim();
  final wallpapersDir = options['wallpapers-dir']?.trim();
  final privateKeyFile = options['private-key']?.trim();
  if (privateKeyFile == null || privateKeyFile.isEmpty) {
    throw ArgumentError('--private-key <seed-file> is required for build');
  }
  final outputPath = (options['output']?.trim().isNotEmpty ?? false)
      ? options['output']!.trim()
      : p.normalize(
          p.join(
            Directory.current.path,
            '..',
            '..',
            '..',
            'server',
            'relay',
            'cosmetics',
          ),
        );
  final maxIcons = int.tryParse(options['max-icons'] ?? '') ?? 1 << 30;
  final maxWallpapers = int.tryParse(options['max-wallpapers'] ?? '') ?? 1 << 30;

  final seedB64 = (await File(privateKeyFile).readAsString()).trim();
  final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(seedB64));

  // Validate inputs BEFORE touching the output dir, so a bad path can never
  // wipe an existing catalog (the output dir is deleted+recreated below).
  final hasIcons = iconsDir != null && iconsDir.isNotEmpty;
  final hasWallpapers = wallpapersDir != null && wallpapersDir.isNotEmpty;
  if (!hasIcons && !hasWallpapers) {
    throw ArgumentError('provide --icons-dir and/or --wallpapers-dir');
  }
  if (hasIcons && !Directory(iconsDir).existsSync()) {
    throw ArgumentError('icons dir not found: $iconsDir');
  }
  if (hasWallpapers && !Directory(wallpapersDir).existsSync()) {
    throw ArgumentError('wallpapers dir not found: $wallpapersDir');
  }

  final outDir = Directory(outputPath);
  if (await outDir.exists()) await outDir.delete(recursive: true);
  await outDir.create(recursive: true);
  final iconsOut = Directory(p.join(outDir.path, 'icons'))
    ..createSync(recursive: true);
  final wallpapersOut = Directory(p.join(outDir.path, 'wallpapers'))
    ..createSync(recursive: true);

  final items = <Map<String, Object?>>[];
  final usedIds = <String>{};

  if (iconsDir != null && iconsDir.isNotEmpty) {
    final files = _listImages(iconsDir, const {'.png'});
    var n = 0;
    for (final f in files) {
      if (n >= maxIcons) break;
      final decoded = img.decodeImage(await File(f).readAsBytes());
      if (decoded == null) continue;
      final id = _uniqueId('icon_', p.basenameWithoutExtension(f), usedIds);
      final fullBytes = img.encodePng(_fitWithin(decoded, kIconFullSize));
      final thumbBytes = img.encodePng(_fitWithin(decoded, kIconThumbSize));
      final fullName = '$id.png';
      final thumbName = '${id}_thumb.png';
      await File(p.join(iconsOut.path, fullName)).writeAsBytes(fullBytes);
      await File(p.join(iconsOut.path, thumbName)).writeAsBytes(thumbBytes);
      items.add(
        _item(
          id: id,
          kind: 'icon',
          thumbName: thumbName,
          fullName: fullName,
          title: _title(p.basenameWithoutExtension(f)),
          fullBytes: fullBytes,
          thumbBytes: thumbBytes,
        ),
      );
      n++;
      if (n % 50 == 0) stdout.writeln('  icons: $n');
    }
    stdout.writeln('Icons processed: $n');
  }

  if (wallpapersDir != null && wallpapersDir.isNotEmpty) {
    final files = _listImages(wallpapersDir, const {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
    });
    final keptHashes = <int>[];
    var skippedDup = 0;
    var n = 0;
    for (final f in files) {
      if (n >= maxWallpapers) break;
      final decoded = img.decodeImage(await File(f).readAsBytes());
      if (decoded == null) continue;
      // Skip visually near-duplicate wallpapers (perceptual dHash).
      final ph = _dhash(decoded);
      if (keptHashes.any((h) => _hamming(h, ph) <= kWallpaperDedupThreshold)) {
        skippedDup++;
        continue;
      }
      keptHashes.add(ph);
      final id = _uniqueId('wp_', p.basenameWithoutExtension(f), usedIds);
      final fullBytes = img.encodeJpg(
        _fitWithin(decoded, kWallpaperFullLongest),
        quality: kWallpaperJpegQuality,
      );
      final thumbBytes = img.encodeJpg(
        _fitWithin(decoded, kWallpaperThumbLongest),
        quality: kWallpaperThumbQuality,
      );
      final fullName = '$id.jpg';
      final thumbName = '${id}_thumb.jpg';
      await File(p.join(wallpapersOut.path, fullName)).writeAsBytes(fullBytes);
      await File(
        p.join(wallpapersOut.path, thumbName),
      ).writeAsBytes(thumbBytes);
      items.add(
        _item(
          id: id,
          kind: 'wallpaper',
          thumbName: thumbName,
          fullName: fullName,
          title: _title(p.basenameWithoutExtension(f)),
          fullBytes: fullBytes,
          thumbBytes: thumbBytes,
        ),
      );
      n++;
      if (n % 20 == 0) stdout.writeln('  wallpapers: $n');
    }
    stdout.writeln(
      'Wallpapers processed: $n (skipped $skippedDup near-duplicates)',
    );
  }

  // generated_at_ms is fixed to 0 for reproducible signatures across runs with
  // identical inputs (the timestamp isn't load-bearing for the client).
  final catalog = <String, Object?>{
    'schema_version': 1,
    'generated_at_ms': 0,
    'items': items,
  };
  final catalogJson =
      '${const JsonEncoder.withIndent('  ').convert(catalog)}\n';
  await File(
    p.join(outDir.path, 'catalog.json'),
  ).writeAsString(catalogJson);

  // Sign the exact bytes the relay reads + serves (the catalog.json file body).
  final signature = await Ed25519().sign(
    utf8.encode(catalogJson),
    keyPair: keyPair,
  );
  await File(
    p.join(outDir.path, 'catalog.sig'),
  ).writeAsString('${base64Encode(signature.bytes)}\n');

  stdout.writeln(
    'Wrote ${items.length} items + catalog.json + catalog.sig to '
    '${outDir.path}',
  );
}

/// Verifies `<dir>/catalog.sig` against `<dir>/catalog.json` with `--public-key`
/// (mirrors the relay + client check). Exits non-zero on failure.
Future<void> _verify(Map<String, String> options) async {
  final dir = options['dir']?.trim();
  final pubB64 = options['public-key']?.trim();
  if (dir == null || dir.isEmpty || pubB64 == null || pubB64.isEmpty) {
    throw ArgumentError('verify requires --dir <dir> --public-key <b64>');
  }
  final jsonBytes = await File(p.join(dir, 'catalog.json')).readAsBytes();
  final sigB64 = (await File(p.join(dir, 'catalog.sig')).readAsString()).trim();
  final pub = SimplePublicKey(
    base64Decode(pubB64),
    type: KeyPairType.ed25519,
  );
  final ok = await Ed25519().verify(
    jsonBytes,
    signature: Signature(base64Decode(sigB64), publicKey: pub),
  );
  if (ok) {
    stdout.writeln('OK: catalog.sig is valid for the given public key.');
  } else {
    stderr.writeln('FAIL: signature does NOT verify.');
    exitCode = 1;
  }
}

Map<String, Object?> _item({
  required String id,
  required String kind,
  required String thumbName,
  required String fullName,
  required String title,
  required List<int> fullBytes,
  required List<int> thumbBytes,
}) {
  return <String, Object?>{
    'id': id,
    'kind': kind,
    'thumb_file': thumbName,
    'full_file': fullName,
    'title': title,
    'sha256_b64': base64Encode(crypto.sha256.convert(fullBytes).bytes),
    'thumb_sha256_b64': base64Encode(crypto.sha256.convert(thumbBytes).bytes),
    'size_bytes': fullBytes.length,
  };
}

/// Downscales [src] so neither side exceeds [maxSide], preserving aspect ratio
/// and alpha. Never upscales.
img.Image _fitWithin(img.Image src, int maxSide) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  if (src.width >= src.height) {
    return img.copyResize(
      src,
      width: maxSide,
      interpolation: img.Interpolation.average,
    );
  }
  return img.copyResize(
    src,
    height: maxSide,
    interpolation: img.Interpolation.average,
  );
}

/// 64-bit difference hash (dHash) of [src] for perceptual dedup: resize to
/// 9x8 grayscale, then each bit = "this pixel darker than the next on the row".
int _dhash(img.Image src) {
  // img.grayscale() MUTATES its argument in place. Resize FIRST (copyResize
  // returns a new image) and grayscale that small copy, so the caller's
  // full-colour `src` is left untouched — otherwise every deduped wallpaper got
  // encoded in greyscale (the "all wallpapers are black & white" bug).
  final small = img.grayscale(
    img.copyResize(
      src,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    ),
  );
  var hash = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).r;
      final right = small.getPixel(x + 1, y).r;
      if (left < right) hash |= (1 << bit);
      bit++;
    }
  }
  return hash;
}

int _hamming(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    count += x & 1;
    x = x >>> 1;
  }
  return count;
}

List<String> _listImages(String dir, Set<String> exts) {
  final d = Directory(dir);
  if (!d.existsSync()) {
    throw ArgumentError('Directory not found: $dir');
  }
  final out = <String>[];
  for (final entity in d.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final ext = p.extension(entity.path).toLowerCase();
    if (exts.contains(ext)) out.add(entity.path);
  }
  out.sort();
  return out;
}

String _slug(String raw) {
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final code in lower.codeUnits) {
    final ch = String.fromCharCode(code);
    if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else {
      buf.write('_');
    }
  }
  var s = buf.toString().replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  // Cap length so the final id (prefix + slug) stays well under the relay's
  // 128-char id limit (is_safe_catalog_segment); uniqueness is preserved by the
  // numeric suffix in _uniqueId.
  if (s.length > 56) {
    s = s.substring(0, 56).replaceAll(RegExp(r'_+$'), '');
  }
  return s.isEmpty ? 'x' : s;
}

String _uniqueId(String prefix, String rawName, Set<String> used) {
  final base = '$prefix${_slug(rawName)}';
  var id = base;
  var i = 1;
  while (used.contains(id)) {
    id = '${base}_$i';
    i++;
  }
  used.add(id);
  return id;
}

String _title(String rawName) {
  final pretty = rawName
      .replaceAll(RegExp(r'^\d+[-_]'), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (pretty.isEmpty) return 'Premium';
  return pretty[0].toUpperCase() + pretty.substring(1);
}

Map<String, String> _parseOptions(Iterable<String> args) {
  final out = <String, String>{};
  final list = args.toList(growable: false);
  for (var i = 0; i < list.length; i++) {
    final raw = list[i].trim();
    if (!raw.startsWith('--')) continue;
    final eq = raw.indexOf('=');
    if (eq > 2) {
      out[raw.substring(2, eq)] = raw.substring(eq + 1).trim();
      continue;
    }
    final key = raw.substring(2);
    if (i + 1 < list.length && !list[i + 1].trim().startsWith('--')) {
      out[key] = list[i + 1].trim();
      i++;
    } else {
      out[key] = 'true';
    }
  }
  return out;
}
