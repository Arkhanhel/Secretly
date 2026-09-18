// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef _VersionDart = ffi.Pointer<ffi.Char> Function();

typedef _AddNative = ffi.Uint64 Function(ffi.Uint64 a, ffi.Uint64 b);
typedef _AddDart = int Function(int a, int b);

class SecretlyCore {
  SecretlyCore._(ffi.DynamicLibrary lib)
      : _versionPtr = lib.lookupFunction<_VersionNative, _VersionDart>(
          'secretly_core_version',
        ),
        _add = lib.lookupFunction<_AddNative, _AddDart>('secretly_core_add');
  final _VersionDart _versionPtr;
  final _AddDart _add;

  static SecretlyCore load() {
    if (Platform.isAndroid) {
      // Name must match Rust cdylib output copied into jniLibs.
      return SecretlyCore._(ffi.DynamicLibrary.open('libsecretly_core.so'));
    }
    if (Platform.isWindows) {
      // For desktop dev later: copy secretly_core.dll next to the exe.
      return SecretlyCore._(ffi.DynamicLibrary.open('secretly_core.dll'));
    }

    // iOS/macOS/Linux can be added later.
    return SecretlyCore._(ffi.DynamicLibrary.process());
  }

  String version() {
    final ptr = _versionPtr();
    if (ptr.address == 0) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  int add(int a, int b) => _add(a, b);

  /// Helper for future APIs: convert Dart String to C string.
  ffi.Pointer<ffi.Char> toCString(String value) {
    final cstr = value.toNativeUtf8(allocator: malloc);
    return cstr.cast<ffi.Char>();
  }
}
