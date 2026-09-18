// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use std::ffi::CStr;
use std::os::raw::{c_char, c_uint, c_ulonglong};
use std::slice;

use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use rand_core::{OsRng, RngCore};

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

#[unsafe(no_mangle)]
pub extern "C" fn secretly_core_version() -> *const c_char {
    static VERSION: &[u8] = b"secretly_core/0.1.0\0";
    VERSION.as_ptr() as *const c_char
}

#[unsafe(no_mangle)]
pub extern "C" fn secretly_core_add(a: c_ulonglong, b: c_ulonglong) -> c_ulonglong {
    a.wrapping_add(b)
}

#[unsafe(no_mangle)]
pub extern "C" fn secretly_core_strlen(ptr: *const c_char) -> c_uint {
    if ptr.is_null() {
        return 0;
    }

    // Safety: caller must provide a valid NUL-terminated C string.
    let cstr = unsafe { CStr::from_ptr(ptr) };
    cstr.to_bytes().len() as c_uint
}

const XCHACHA_KEY_LEN: usize = 32;
const XCHACHA_NONCE_LEN: usize = 24;
const AEAD_TAG_LEN: usize = 16;

// Returns number of bytes written, or a negative error code:
// -1 bad args, -2 crypto failure, -3 out buffer too small.
#[unsafe(no_mangle)]
pub extern "C" fn secretly_aead_xchacha20poly1305_seal_v1(
    key_ptr: *const u8,
    key_len: usize,
    plaintext_ptr: *const u8,
    plaintext_len: usize,
    out_ptr: *mut u8,
    out_cap: usize,
) -> isize {
    if key_ptr.is_null() || plaintext_ptr.is_null() || out_ptr.is_null() {
        return -1;
    }
    if key_len != XCHACHA_KEY_LEN {
        return -1;
    }

    let out_len = XCHACHA_NONCE_LEN + AEAD_TAG_LEN + plaintext_len;
    if out_cap < out_len {
        return -3;
    }

    let key = unsafe { slice::from_raw_parts(key_ptr, XCHACHA_KEY_LEN) };
    let plaintext = unsafe { slice::from_raw_parts(plaintext_ptr, plaintext_len) };
    let out = unsafe { slice::from_raw_parts_mut(out_ptr, out_cap) };

    let cipher = XChaCha20Poly1305::new_from_slice(key).ok();
    let Some(cipher) = cipher else {
        return -1;
    };

    let mut nonce_bytes = [0u8; XCHACHA_NONCE_LEN];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = XNonce::from_slice(&nonce_bytes);

    let sealed = match cipher.encrypt(nonce, plaintext) {
        Ok(v) => v,
        Err(_) => return -2,
    };

    // chacha20poly1305 returns ciphertext || tag; we store nonce || tag || ciphertext.
    if sealed.len() < AEAD_TAG_LEN {
        return -2;
    }
    let ct_len = sealed.len() - AEAD_TAG_LEN;
    if ct_len != plaintext_len {
        // Defensive: expected AEAD output to be plaintext_len + tag
        return -2;
    }
    let (ciphertext, tag) = sealed.split_at(ct_len);

    out[..XCHACHA_NONCE_LEN].copy_from_slice(&nonce_bytes);
    out[XCHACHA_NONCE_LEN..XCHACHA_NONCE_LEN + AEAD_TAG_LEN].copy_from_slice(tag);
    out[XCHACHA_NONCE_LEN + AEAD_TAG_LEN..XCHACHA_NONCE_LEN + AEAD_TAG_LEN + ct_len]
        .copy_from_slice(ciphertext);

    out_len as isize
}

// Returns number of plaintext bytes written, or a negative error code:
// -1 bad args, -2 auth failure, -3 out buffer too small.
#[unsafe(no_mangle)]
pub extern "C" fn secretly_aead_xchacha20poly1305_open_v1(
    key_ptr: *const u8,
    key_len: usize,
    sealed_ptr: *const u8,
    sealed_len: usize,
    out_ptr: *mut u8,
    out_cap: usize,
) -> isize {
    if key_ptr.is_null() || sealed_ptr.is_null() || out_ptr.is_null() {
        return -1;
    }
    if key_len != XCHACHA_KEY_LEN {
        return -1;
    }
    if sealed_len < XCHACHA_NONCE_LEN + AEAD_TAG_LEN {
        return -1;
    }

    let plain_len = sealed_len - XCHACHA_NONCE_LEN - AEAD_TAG_LEN;
    if out_cap < plain_len {
        return -3;
    }

    let key = unsafe { slice::from_raw_parts(key_ptr, XCHACHA_KEY_LEN) };
    let sealed = unsafe { slice::from_raw_parts(sealed_ptr, sealed_len) };
    let out = unsafe { slice::from_raw_parts_mut(out_ptr, out_cap) };

    let cipher = XChaCha20Poly1305::new_from_slice(key).ok();
    let Some(cipher) = cipher else {
        return -1;
    };

    let nonce = XNonce::from_slice(&sealed[..XCHACHA_NONCE_LEN]);
    let tag = &sealed[XCHACHA_NONCE_LEN..XCHACHA_NONCE_LEN + AEAD_TAG_LEN];
    let ciphertext = &sealed[XCHACHA_NONCE_LEN + AEAD_TAG_LEN..];

    // reconstruct ciphertext||tag for the Rust AEAD API.
    let mut ct_and_tag = Vec::with_capacity(ciphertext.len() + AEAD_TAG_LEN);
    ct_and_tag.extend_from_slice(ciphertext);
    ct_and_tag.extend_from_slice(tag);

    let plain = match cipher.decrypt(nonce, ct_and_tag.as_slice()) {
        Ok(v) => v,
        Err(_) => return -2,
    };

    if plain.len() != plain_len {
        return -2;
    }
    out[..plain_len].copy_from_slice(&plain);
    plain_len as isize
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    fn c_abi_add_works() {
        assert_eq!(secretly_core_add(10, 20), 30);
    }

    #[test]
    fn aead_seal_open_roundtrip() {
        let key = [7u8; XCHACHA_KEY_LEN];
        let plain = b"hello secretly";
        let mut sealed = vec![0u8; XCHACHA_NONCE_LEN + AEAD_TAG_LEN + plain.len()];

        let n = secretly_aead_xchacha20poly1305_seal_v1(
            key.as_ptr(),
            key.len(),
            plain.as_ptr(),
            plain.len(),
            sealed.as_mut_ptr(),
            sealed.len(),
        );
        assert_eq!(n as usize, sealed.len());

        let mut out = vec![0u8; plain.len()];
        let m = secretly_aead_xchacha20poly1305_open_v1(
            key.as_ptr(),
            key.len(),
            sealed.as_ptr(),
            sealed.len(),
            out.as_mut_ptr(),
            out.len(),
        );
        assert_eq!(m as usize, plain.len());
        assert_eq!(&out, plain);
    }
}
