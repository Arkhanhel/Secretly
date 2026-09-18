// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Cross-OS single-instance guard for the Secretly desktop client.
///
/// On macOS / Linux we bind a unix domain socket inside the per-user
/// application-support directory and use file-based locking semantics
/// (bind succeeds → we are the primary; bind fails → another instance is
/// running). The secondary process opens the socket, sends a `focus`
/// command, and exits. The primary instance reacts to the command by
/// invoking the callback registered in [becomePrimary].
///
/// On Windows we fall back to a stamped lock file in
/// `%APPDATA%\Secretly\single_instance.lock`. A future slice will replace
/// this with a proper named-mutex + WM_COPYDATA bridge.
///
/// Mobile builds never import this file (it lives under `lib/desktop/`).
class SingleInstance {
  SingleInstance._({required this.socketPath, required this.lockPath});

  final String socketPath;
  final String lockPath;
  ServerSocket? _server;
  RandomAccessFile? _lockHandle;

  /// Returns a configured [SingleInstance] for `Secretly`. Pure-IO; safe to
  /// call early in main() before runApp.
  ///
  /// The lock file lives inside the per-user app-support directory.
  /// The unix socket is intentionally placed in `Directory.systemTemp`
  /// under a short deterministic name: macOS caps `sockaddr_un.sun_path`
  /// at 104 bytes, and the sandboxed app-support path easily exceeds
  /// that. A hash of the app-support path keeps the socket per-bundle
  /// without colliding across users.
  static Future<SingleInstance> forApp() async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory('${dir.path}/single_instance');
    if (!base.existsSync()) {
      base.createSync(recursive: true);
    }
    final socketPath = _shortSocketPath(base.path);
    return SingleInstance._(
      socketPath: socketPath,
      lockPath: '${base.path}/secretly.lock',
    );
  }

  static String _shortSocketPath(String basePath) {
    final hash = sha1.convert(utf8.encode(basePath)).toString().substring(0, 10);
    return '${Directory.systemTemp.path}/scrtly-$hash.sock';
  }

  /// Attempts to become the primary instance.
  ///
  /// On success returns `true`. The [onFocusRequested] callback fires whenever
  /// a secondary launch hits the socket.
  ///
  /// On failure (another instance is already primary) returns `false`. The
  /// caller is responsible for sending a focus command via [sendFocus] and
  /// then terminating.
  Future<bool> becomePrimary({required Future<void> Function() onFocusRequested}) async {
    if (Platform.isWindows) {
      // Pure-Dart fallback for Windows: lock file via exclusive open.
      try {
        final file = File(lockPath);
        _lockHandle =
            file.openSync(mode: FileMode.write).._lockSafe();
        _lockHandle!.writeStringSync('$pid\n${DateTime.now().toIso8601String()}\n');
        return true;
      } catch (_) {
        return false;
      }
    }

    // Stale-socket cleanup: previous process crashed without unlinking.
    final socketFile = File(socketPath);
    if (socketFile.existsSync()) {
      try {
        await Socket.connect(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
          timeout: const Duration(milliseconds: 200),
        );
        // Connection succeeded → primary is alive.
        return false;
      } catch (_) {
        // Connection failed → stale socket, safe to unlink and re-bind.
        try {
          socketFile.deleteSync();
        } catch (_) {}
      }
    }

    try {
      final server = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      _server = server;
      server.listen((client) {
        final buf = <int>[];
        client.listen(
          (chunk) => buf.addAll(chunk),
          onDone: () async {
            final cmd = utf8.decode(buf, allowMalformed: true).trim();
            if (cmd == 'focus' || cmd.isEmpty) {
              try {
                await onFocusRequested();
              } catch (_) {}
            }
            try {
              await client.close();
            } catch (_) {}
          },
          onError: (_) {
            try {
              client.close();
            } catch (_) {}
          },
          cancelOnError: true,
        );
      });
      return true;
    } catch (_) {
      // Bind failed for a reason other than a live peer (e.g. socket path
      // exceeds sockaddr_un's 104-byte limit, or the parent dir is
      // sandboxed read-only). The stale-socket connect check above already
      // proved no live peer is listening, so we proceed as a degraded
      // primary rather than asking the caller to exit.
      return true;
    }
  }

  /// Sends a focus command to the running primary. Used by the secondary
  /// process right before exit.
  Future<void> sendFocus() async {
    if (Platform.isWindows) {
      // No socket yet on Windows — secondary instances simply exit.
      return;
    }
    try {
      final socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 1),
      );
      socket.add(utf8.encode('focus'));
      await socket.flush();
      await socket.close();
    } catch (_) {
      // best-effort
    }
  }

  /// Release the primary slot. Called from `dispose` or shutdown handlers.
  Future<void> release() async {
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        File(socketPath).deleteSync();
      } catch (_) {}
    }
    try {
      _lockHandle?.closeSync();
    } catch (_) {}
    _lockHandle = null;
    if (Platform.isWindows) {
      try {
        File(lockPath).deleteSync();
      } catch (_) {}
    }
  }
}

extension on RandomAccessFile {
  void _lockSafe() {
    try {
      lockSync(FileLock.exclusive);
    } catch (_) {
      // Already held → caller treats this as "another instance is primary".
      rethrow;
    }
  }
}
