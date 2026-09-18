// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A previously-picked music track or file, kept so it can be re-sent quickly
/// from the attachment picker's «Недавние» section.
class RecentAttachment {
  RecentAttachment({
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    required this.path,
    required this.sentAtMs,
  });

  /// 'audio' or 'file'.
  final String kind;
  final String fileName;
  final int sizeBytes;

  /// Durable copy inside the recents directory (survives temp cleanup).
  final String path;
  final int sentAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'name': fileName,
    'size': sizeBytes,
    'path': path,
    'ts': sentAtMs,
  };

  static RecentAttachment? fromJson(Map<String, Object?> j) {
    final kind = (j['kind'] as String?)?.trim() ?? '';
    final path = (j['path'] as String?)?.trim() ?? '';
    if (kind.isEmpty || path.isEmpty) return null;
    final name = (j['name'] as String?)?.trim() ?? '';
    return RecentAttachment(
      kind: kind,
      fileName: name.isEmpty ? p.basename(path) : name,
      sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
      path: path,
      sentAtMs: (j['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local, account-agnostic store of recently-sent music/files. Self-contained:
/// keeps durable copies under the app support directory plus a small JSON index,
/// so nothing in the message/event pipeline needs to change. Best-effort — any
/// I/O failure degrades to "no recents" rather than breaking the picker.
class RecentAttachmentsStore {
  RecentAttachmentsStore._();
  static final RecentAttachmentsStore instance = RecentAttachmentsStore._();

  /// Max remembered items per kind. Old entries (and their durable copies) are
  /// evicted beyond this so storage stays bounded.
  static const int _capPerKind = 15;

  Directory? _filesDir;
  File? _indexFile;

  Future<void> _ensureDirs() async {
    if (_filesDir != null && _indexFile != null) return;
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'recent_attachments'));
    final files = Directory(p.join(root.path, 'files'));
    if (!await files.exists()) {
      await files.create(recursive: true);
    }
    _filesDir = files;
    _indexFile = File(p.join(root.path, 'index.json'));
  }

  Future<List<RecentAttachment>> _readAll() async {
    await _ensureDirs();
    final f = _indexFile!;
    if (!await f.exists()) return <RecentAttachment>[];
    try {
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return <RecentAttachment>[];
      final out = <RecentAttachment>[];
      for (final e in decoded) {
        if (e is Map) {
          final r = RecentAttachment.fromJson(e.cast<String, Object?>());
          if (r != null) out.add(r);
        }
      }
      return out;
    } catch (_) {
      return <RecentAttachment>[];
    }
  }

  Future<void> _writeAll(List<RecentAttachment> all) async {
    await _ensureDirs();
    try {
      await _indexFile!.writeAsString(
        jsonEncode(all.map((e) => e.toJson()).toList(growable: false)),
      );
    } catch (_) {}
  }

  /// Recent items of [kind], newest first. Entries whose durable file no longer
  /// exists are pruned from the index.
  Future<List<RecentAttachment>> list(String kind) async {
    final all = await _readAll();
    final alive = <RecentAttachment>[];
    var changed = false;
    for (final r in all) {
      if (await File(r.path).exists()) {
        alive.add(r);
      } else {
        changed = true;
      }
    }
    if (changed) await _writeAll(alive);
    final filtered = alive.where((r) => r.kind == kind).toList()
      ..sort((a, b) => b.sentAtMs.compareTo(a.sentAtMs));
    return filtered;
  }

  /// Copy [sourcePath] into the durable recents directory and index it.
  /// De-dupes by (kind, name, size) and evicts beyond [_capPerKind].
  Future<void> record({
    required String kind,
    required String sourcePath,
    required String fileName,
    required int sizeBytes,
  }) async {
    try {
      await _ensureDirs();
      final src = File(sourcePath);
      if (!await src.exists()) return;

      final all = await _readAll();
      // Drop a prior identical pick (same kind+name+size); delete its copy.
      final keep = <RecentAttachment>[];
      for (final r in all) {
        if (r.kind == kind &&
            r.fileName == fileName &&
            r.sizeBytes == sizeBytes) {
          await _deleteQuiet(r.path);
        } else {
          keep.add(r);
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dest = File(p.join(_filesDir!.path, '${nowMs}_${_sanitize(fileName)}'));
      await src.copy(dest.path);
      keep.add(RecentAttachment(
        kind: kind,
        fileName: fileName.trim().isEmpty ? p.basename(sourcePath) : fileName,
        sizeBytes: sizeBytes,
        path: dest.path,
        sentAtMs: nowMs,
      ));

      // Enforce per-kind cap (evict oldest of this kind).
      final ofKind = keep.where((r) => r.kind == kind).toList()
        ..sort((a, b) => a.sentAtMs.compareTo(b.sentAtMs));
      while (ofKind.length > _capPerKind) {
        final victim = ofKind.removeAt(0);
        keep.remove(victim);
        await _deleteQuiet(victim.path);
      }

      await _writeAll(keep);
    } catch (_) {}
  }

  Future<void> _deleteQuiet(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  String _sanitize(String name) {
    final base = p.basename(name);
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (cleaned.isEmpty || cleaned == '_') return 'file';
    return cleaned.length > 80
        ? cleaned.substring(cleaned.length - 80)
        : cleaned;
  }
}
