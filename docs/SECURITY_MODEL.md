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
| MITM on key exchange | QR-based contact verification; identity fingerprint comparison. The session initiator signs the handshake with its identity key (C-2) |
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

> Corrected 2026-09-17 (finding ID-1).
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
  header = { sender_device_id, sender_eph_pub, spk_id, otk_id,
             hs_sig }                    // hs_sig since 2026-09-24, see below
```

Consequences and mitigations:

- **The key agreement does not authenticate the initiator.** The initiator's
  identity key takes no part in the DH, so `sender_device_id` is only the
  wire's own claim: anyone holding D's public bundle — including the server —
  can open a session under any device id.
- **Handshake signature (stage C-2, 24 September 2026).** The initiator signs
  the handshake with its device identity key (Ed25519):

  ```
  "secretly-hs-sig-v1" 0x00 ‖ lp(sender_device_id) ‖ lp(recipient_device_id)
    ‖ lp(sender_eph_pub) ‖ lp(recipient_signed_prekey_pub)
    ‖ u32(spk_id) ‖ u8(has_otk) ‖ u32(otk_id | 0)          lp = u16 length ‖ bytes
  ```

  The context and the length prefixes keep these bytes distinct from anything
  else the same key signs (the raw signed prekey, device certificates). The
  signature travels in the header, which is the AEAD associated data. The key
  formula is unchanged, and older builds ignore the field.

  A device that signs also marks its ordinary messages with `hsv: 1`. The mark
  is part of the associated data, so the server can neither add nor strip it.
  The receiver verifies the signature against the identity key it has pinned
  for that device. It **rejects** a handshake only from a device that has
  already proven it signs — by a valid signature or by an `hsv` message — when
  the new handshake is unsigned or signed by another key. The session is left
  untouched and the wire goes to quarantine. Everything else is accepted as
  before and counted (`hs_auth.*`, shown in delivery diagnostics).
- **A changed identity key is never accepted silently.** A legitimate change
  (the OS keychain lost, the device number kept) is picked up from the keys
  server through the usual "safety number changed" path: the contact's
  verification is reset and a notice appears, after which the quarantined wire
  decrypts. For the server, this means impersonating a device that signs
  requires changing its key in the open.
- **Server-side switch.** A separately signed `handshake_auth` block in
  `/v1/config` can lift the rejections (not the checks) if a field problem
  appears. A silent or stale server changes nothing.
- **Earlier mitigations remain (2026-09-17):**
  - the relay stamps the authenticated sender (`from_device_id`) on every queued
    message, and the client drops a wire whose header names someone else (C-1);
  - a wire naming the receiving device itself is dropped;
  - "session ended" wipes only after the keys server confirms the registration
    is gone;
  - room messages are signed per sender generation (K-1).
- **Still open:**
  - a device that has not yet shown it signs (an older build) can be
    impersonated by an unsigned handshake. This closes as devices update, and
    fully only once unsigned handshakes are refused for everyone;
  - a new device of a known contact is trusted on first use. Requiring an
    account-key certificate for it is not enforced yet;
  - replaying an old, genuine signed handshake can break a live session. That
    denies service; it does not disclose anything;
  - deniability is partly lost: a signature shows that one device started a
    session with another at some point. It says nothing about the contents.

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
