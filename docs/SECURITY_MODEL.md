# Secretly — Security Model

> **Read [THREAT_MODEL.md](THREAT_MODEL.md) first.** It states what we protect,
> against whom, and — importantly — what we do *not* claim. This file is the
> engineering detail beneath it.
>
> **Two claims in the table below were corrected on 25 August 2026 after being
> checked against the code:**
>
> - *"Backup leak — backup encrypted with identity key"* was wrong. The archive is
>   encrypted with a **user-chosen password**, and until that date it could be
>   downloaded by anyone who knew the profile identifier (SEC-01, remediation in
>   progress — see THREAT_MODEL §3.4).
> - *"Server impersonation — TLS; domain-pinned in production builds"* was
>   misleading. Certificates are validated against the **system root store**;
>   there is no certificate pinning. SNI is bound to the real hostname even when
>   DNS is bypassed, which is what "domain-pinned" was presumably describing.
>
> Both are stated plainly in THREAT_MODEL §3.4 and §5.1.

---

## Threat Model Summary

| Threat | Mitigation |
|--------|-----------|
| Server reads messages | E2EE: server only stores opaque ciphertext envelopes per device_id |
| MITM on key exchange | QR-based contact verification; identity fingerprint comparison |
| Replay attacks | Double Ratchet: each message uses a fresh message key; nonce included in wire |
| Key compromise (forward secrecy) | Double Ratchet provides forward secrecy (ratchet advances on each message) |
| Key compromise (break-in recovery) | Double Ratchet provides break-in recovery via DH ratchet steps |
| Unauthorized device registration | Ed25519 signatures: `publish_keys` requires proof-of-possession |
| Server impersonation | TLS validated against the system root store. **No certificate pinning** — see THREAT_MODEL §5.1. SNI stays bound to the real hostname even when DNS is bypassed |
| Local data theft | SQLCipher: all local DB encrypted at rest |
| Backup leak | `SafeBackup`/`RecoveryKit` — archive encrypted with a **user-chosen password** (PBKDF2-HMAC-SHA256, 400 000 iterations), not with the identity key. Access-token remediation in progress — see THREAT_MODEL §3.4 |
| Delivery tampering | ACK only after successful decrypt+apply; relay cannot forge `delivered` |
| Call eavesdropping | SRTP via WebRTC (DTLS-SRTP); LiveKit for room calls (JWT-gated) |

---

## Identity Layer

### Key Types

| Key | Algorithm | Purpose |
|-----|-----------|---------|
| Identity key | Ed25519 | Long-term signing identity |
| Signed prekey | X25519 | Medium-term DH key, signed by identity key |
| One-time prekeys | X25519 | Ephemeral DH (consumed per session init) |
| Device key | Ed25519 | Per-device authentication to relay/keys |

### Registration Flow

```
AppSecurityManager.generateIdentity():
  generate Ed25519 identity keypair
  generate device Ed25519 keypair
  generate signed X25519 prekey (signed with identity key)
  generate N one-time prekeys

KeysClient.publishKeys(bundle):
  POST /identity/publish
  body: { identity_key_pub, device_key_pub, signed_prekey, prekeys[], sig }
  → Keys server: verifies signature, stores bundle
  → Keys server: keys_security_errors preflight (prod: requires REQUIRE_PROFILE_SECRET etc.)
```

### Contact Discovery (QR)

```
A shows QR:  { profile_id, identity_key_pub_b64, display_name?, qr_nonce }
B scans QR:
  addContact(profileId, identityKeyPub)
  → db.contactUpsert
  → KeysClient.fetchBundle(profileId) → fetch prekey bundle
  → announceQrPairingIntroduction:
      sendControlMessage(profileId, __secretly_qr_pair__:<json>)
      → goes through E2EE ratchet

A receives pairing introduction:
  → verifies via ratchet (already authenticated)
  → db.contactUpsert + convoEnsure1to1
  → requestUpsert(status=accepted)
  → no UI notification (silent installation)
```

Identity authenticity is NOT established by the ratchet handshake itself (see the corrected section below); it relies on the relay's sender stamp today and until Stage C-2 lands.

---

## Encryption Layer (Double Ratchet v3)

### Session Initialization (X3DH-like) — as implemented

> Corrected 2026-09-17 (docs/TZ_ROOMS_KEY_AND_SENDER_AUTH_2026-09-17.md, finding ID-1).
> An earlier version of this section described DH1 = DH(IK_A, SPK_D) and
> DH2 = DH(ek, IK_D). **The code has never done that.**

```
Initiator (A) initializing session to recipient device D (lib/ratchet/session_v1.dart):
  fetch bundle: { identity_key_pub, signed_prekey_pub, prekey_sig, one_time_prekey_pub }
  verify prekey_sig against identity_key_pub
  ephemeral keypair: (ek_priv, ek_pub)
  DH1 = DH(ek_priv, D.signed_prekey_pub)
  DH2 = DH(ek_priv, D.one_time_prekey_pub)   [if available]
  root = HKDF(DH1 || DH2)
  header = { sender_device_id, sender_eph_pub, spk_id, otk_id }   // NOT signed
```

Consequences and mitigations:

- **The initiator is not authenticated by the handshake.** `sender_device_id` is
  the wire's own claim. Anyone holding D's public bundle can open a session
  under any device id.
- **Mitigations in place (2026-09-17):**
  - the relay stamps the authenticated sender (`from_device_id`) on every queued
    message, and the client drops a wire whose header names someone else (C-1);
  - a wire naming the receiving device itself is dropped;
  - "session ended" wipes only after the keys server confirms the registration
    is gone;
  - room messages are signed per sender generation (K-1).
- **Still open:** a malicious *server* can forge both the relay stamp and the
  wire. The end-to-end fix — the initiator signs the handshake header with its
  device identity key, advertised by a bundle capability — is Stage C-2 of the
  TZ above.
- Contact verification (safety numbers, account identity certificates) verifies
  *keys*. Until C-2 it does not by itself bind a session to those keys.

### Message Encryption

```
encryptToPeer(deviceId, plaintext):
  ratchet.ratchetEncrypt(plaintext)
  → DH ratchet step (when new ratchet key available)
  → KDF chain step → message key
  → AEAD encrypt(message_key, plaintext, associated_data)
  → returns RatchetWireV3{dh_pub, pn, n, ciphertext}
```

Wire format: `SKS2` (Secretly Session v2 envelope).

### Receive / Decrypt

```
decryptFromWire(wire):
  → validate header
  → advance ratchet to correct chain/message index
  → derive message key from chain
  → AEAD decrypt(message_key, ciphertext)
  → throws on any failure (fail-closed: no ACK, message dropped)
```

**Fail-closed invariant:** no ACK is sent to relay until `decryptFromWire` and `handleDecryptedInboundPayload` both succeed. This prevents relay from marking messages as delivered if the client cannot process them.

---

## Authentication (Relay / Keys)

### AuthSigner (`apps/flutter/secretly_app/lib/security/auth_signer.dart`)

Every request to relay/keys is signed:
```
_buildKeysAuthEnvelope():
  body_hash = SHA256(request_body)
  timestamp_ms = now
  nonce = random(16 bytes)
  sig = Ed25519.sign(device_key_priv, body_hash || timestamp_ms || nonce)
  header: Authorization: SKS1 device_id=<did> ts=<ms> nonce=<hex> sig=<b64>
```

Replay protection, two layers: requests outside a ±30 s timestamp window are
rejected, and the keys server additionally keeps a nonce cache (`used_nonces`,
10-minute TTL) — presenting the same nonce twice returns `401 replayed nonce`
even inside the window.

### Server-side (Keys)

Production preflight (`keys_security_errors`):
- `REQUIRE_PROFILE_SECRET=true`
- `REQUIRE_DEVICE_LOOKUP_AUTH=true`
- `REQUIRE_LIST_DEVICES_AUTH=true`
- `REQUIRE_BUNDLE_FETCH_AUTH=true`
- `INTERNAL_KEY` must be set
- `TRUST_XFF` + `PROXY_ONLY` checks

Fails with explicit error log on startup if any are missing.

---

## Local Data Security

- **SQLCipher**: entire SQLite database encrypted with a key derived from device identity
- **SecureSecrets** (`apps/flutter/secretly_app/lib/security/secure_secrets.dart`): secrets stored in platform keychain (Keystore on Android, Keychain on iOS)
- **RecoveryKit** (`apps/flutter/secretly_app/lib/security/recovery_kit.dart`): backup encrypted with a passphrase-derived key; identity key is not stored plaintext in backup
- **SafeBackup** (`apps/flutter/secretly_app/lib/security/safe_backup.dart`): backup format versioned, contains only encrypted blobs

---

## Push Notifications

FCM/APNs payloads contain **no plaintext message content**:
- Push payload: `{ type: "wake", relay_seq_hint }` — signals app to fetch from relay
- App wakes → opens WS → drains inbox → decrypts locally
- Notification text derived from decrypted payload, shown after decrypt succeeds

---

## Known Weaknesses / Deferred

| Item | Risk | Mitigation in place |
|------|------|---------------------|
| C1: call signal dedup in-memory only | Duplicate call signals after app kill | In-memory 3min dedup + relay-side `processed_inbound_signal_ids` |
| RM1: room message encrypt+admit not atomic | Partial delivery to some members | Admit idempotent; outbox watchdog re-sends failed rows |
| R5: per-device read timestamps missing | "read" shown if any device read | Deferred; UX matches Telegram-style (read = any device) |
| C4: push retry queue not persistent | Lost call invite if FCM throttled | Relay best-effort retry; 3500ms min interval |
| K3: no `/health/security` runtime self-test | Config drift in prod | `keys_security_errors` blocks startup |
| K1: relinking race on `_deviceId` null | Keys request with stale deviceId | Gating needed; deferred |
