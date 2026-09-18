// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'crypto_provider.dart';

typedef _SealNative =
    ffi.IntPtr Function(
      ffi.Pointer<ffi.Uint8> keyPtr,
      ffi.Size keyLen,
      ffi.Pointer<ffi.Uint8> plainPtr,
      ffi.Size plainLen,
      ffi.Pointer<ffi.Uint8> outPtr,
      ffi.Size outCap,
    );
typedef _SealDart =
    int Function(
      ffi.Pointer<ffi.Uint8> keyPtr,
      int keyLen,
      ffi.Pointer<ffi.Uint8> plainPtr,
      int plainLen,
      ffi.Pointer<ffi.Uint8> outPtr,
      int outCap,
    );

typedef _OpenNative =
    ffi.IntPtr Function(
      ffi.Pointer<ffi.Uint8> keyPtr,
      ffi.Size keyLen,
      ffi.Pointer<ffi.Uint8> sealedPtr,
      ffi.Size sealedLen,
      ffi.Pointer<ffi.Uint8> outPtr,
      ffi.Size outCap,
    );
typedef _OpenDart =
    int Function(
      ffi.Pointer<ffi.Uint8> keyPtr,
      int keyLen,
      ffi.Pointer<ffi.Uint8> sealedPtr,
      int sealedLen,
      ffi.Pointer<ffi.Uint8> outPtr,
      int outCap,
    );

class RustCryptoProvider implements CryptoProvider {
  RustCryptoProvider._(this._key, this._seal, this._open);

  static const int _keyLen = 32;
  static const int _nonceLen = 24;
  static const int _macLen = 16;

  final Uint8List _key;
  final _SealDart _seal;
  final _OpenDart _open;

  static void _zeroAndFree(ffi.Pointer<ffi.Uint8> ptr, int len) {
    if (len > 0) {
      ptr.asTypedList(len).fillRange(0, len, 0);
    }
    malloc.free(ptr);
  }

  static RustCryptoProvider? tryCreate(Uint8List key) {
    if (key.length != _keyLen) return null;
    if (!Platform.isAndroid && !Platform.isWindows) return null;

    final lib = _openCoreLibrary();
    if (lib == null) return null;

    try {
      final seal = lib.lookupFunction<_SealNative, _SealDart>(
        'secretly_aead_xchacha20poly1305_seal_v1',
      );
      final open = lib.lookupFunction<_OpenNative, _OpenDart>(
        'secretly_aead_xchacha20poly1305_open_v1',
      );
      return RustCryptoProvider._(key, seal, open);
    } catch (_) {
      return null;
    }
  }

  static ffi.DynamicLibrary? _openCoreLibrary() {
    try {
      if (Platform.isAndroid) {
        return ffi.DynamicLibrary.open('libsecretly_core.so');
      }
      if (Platform.isWindows) {
        return ffi.DynamicLibrary.open('secretly_core.dll');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<int>> encrypt(List<int> plaintext) async {
    final plain = Uint8List.fromList(plaintext);
    final outLen = _nonceLen + _macLen + plain.length;
    final keyPtr = malloc<ffi.Uint8>(_keyLen);
    final plainPtr = malloc<ffi.Uint8>(plain.length);
    final outPtr = malloc<ffi.Uint8>(outLen);
    try {
      keyPtr.asTypedList(_keyLen).setAll(0, _key);
      plainPtr.asTypedList(plain.length).setAll(0, plain);

      final n = _seal(keyPtr, _keyLen, plainPtr, plain.length, outPtr, outLen);
      if (n < 0) {
        throw StateError('rust seal failed: $n');
      }
      return Uint8List.fromList(outPtr.asTypedList(n));
    } finally {
      _zeroAndFree(keyPtr, _keyLen);
      _zeroAndFree(plainPtr, plain.length);
      _zeroAndFree(outPtr, outLen);
    }
  }

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async {
    final sealed = Uint8List.fromList(ciphertext);
    if (sealed.length < _nonceLen + _macLen) {
      throw StateError('ciphertext too short');
    }
    final outLen = sealed.length - _nonceLen - _macLen;

    final keyPtr = malloc<ffi.Uint8>(_keyLen);
    final sealedPtr = malloc<ffi.Uint8>(sealed.length);
    final outPtr = malloc<ffi.Uint8>(outLen);
    try {
      keyPtr.asTypedList(_keyLen).setAll(0, _key);
      sealedPtr.asTypedList(sealed.length).setAll(0, sealed);

      final n = _open(
        keyPtr,
        _keyLen,
        sealedPtr,
        sealed.length,
        outPtr,
        outLen,
      );
      if (n < 0) {
        throw StateError('rust open failed: $n');
      }
      return Uint8List.fromList(outPtr.asTypedList(n));
    } finally {
      _zeroAndFree(keyPtr, _keyLen);
      _zeroAndFree(sealedPtr, sealed.length);
      _zeroAndFree(outPtr, outLen);
    }
  }
}
