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
>
> Both are stated plainly in THREAT_MODEL §3.4 and §5.1.
>
> **Corrected again on 26 September 2026 against the code:** room calls are not
> end-to-end encrypted; the database passphrase is random, not derived from the
> identity key; the recovery kit uses 200 000 iterations; requests are signed in
> `x-secretly-*` headers (there is no `Authorization: SKS1` header); the replay
> window is ±5 minutes; push payloads are described as they are.

---

## Threat Model Summary

| Threat | Mitigation |
|--------|-----------|
| Server reads messages | E2EE: the relay stores opaque ciphertext envelopes per device, plus routing metadata (THREAT_MODEL §5.2). Room calls are the exception — see *Call eavesdropping* |
| MITM on key exchange | QR-based contact verification; identity fingerprint comparison. The session initiator signs the handshake with its identity key (C-2) |
| Replay attacks | Double Ratchet: each message uses a fresh message key; nonce included in wire |
| Key compromise (forward secrecy) | Double Ratchet provides forward secrecy (ratchet advances on each message) |
| Key compromise (break-in recovery) | Double Ratchet provides break-in recovery via DH ratchet steps |
| Unauthorized device registration | Ed25519 signatures: `publish_keys` requires proof-of-possession |
| Server impersonation | TLS validated against the system root store. **No certificate pinning** — see THREAT_MODEL §5.1. SNI stays bound to the real hostname even when DNS is bypassed |
| Local data theft | The local database is encrypted at rest — SQLCipher on phones, SQLite3 Multiple Ciphers on desktop — with a random passphrase kept by the OS. Media files are regular files under the OS's storage encryption |
| Backup leak | `SafeBackup`/`RecoveryKit` — archive encrypted with a **user-chosen password** (PBKDF2-HMAC-SHA256: 400 000 iterations for SafeBackup, 200 000 for RecoveryKit), not with the identity key. Access-token remediation in progress — see THREAT_MODEL §3.4 |
| Delivery tampering | The `delivered` receipt is sent only after decrypt+apply, and the relay cannot forge it. The relay-level acknowledgement can come earlier: an undecryptable wire is acknowledged and quarantined so it does not block the mailbox |
| Call eavesdropping | One-to-one: DTLS-SRTP end to end, signalling inside the E2EE channel. Room calls: LiveKit SFU, DTLS-SRTP to the server only — **not end-to-end**; the JWT controls who may join, not who can listen (THREAT_MODEL §3.5) |

---

## Identity Layer

### Key Types

| Key | Algorithm | Purpose |
|-----|-----------|---------|
| Device identity key | Ed25519 | One key per device. Signs the signed prekey, handshakes (C-2) and requests to relay/keys; its fingerprint is what contact verification compares |
| Signed prekey | X25519 | Medium-term DH key, signed by the device identity key. Not rotated yet (`spk_id` is always 1) |
| One-time prekeys | X25519 | The server hands each out once; the private halves are not deleted after use yet |
| Account key | Ed25519 | Certifies new devices of a profile. Certificates are recorded and counted, not yet required |

### Registration Flow

```
DeviceKeys (apps/flutter/secretly_app/lib/security/device_keys.dart):
  generate the device Ed25519 identity key (seed kept by the OS keychain/keystore)
  generate the X25519 signed prekey, signed by the device identity key
  generate one-time prekeys

Keys server:
  /v1/profile/create        → profile id and a profile secret; the server keeps
                              only a hash of the secret
  /v1/device/register_proof → a 2-minute challenge, answered with a signature
                              over "SECRETLY-DEVICE-REGISTER-V1" and proof of the
                              profile secret; the device's prekey bundle is then
                              published under its device id
```

### Contact Discovery (QR)

```
A shows QR:  { secretly_id, keys_base_url, device_id, identity_key_pub_b64, nickname? }
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

Identity authenticity is NOT established by the key agreement itself (see the corrected section below). It rests on the relay's sender stamp (C-1) and, since 1.8.58, on handshake signatures (C-2).

The safety number shown for a contact is the first 96 bits of SHA-256 over one device's identity key — a per-device fingerprint, not a two-party number.

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
  appears. A silent or stale server changes nothing — but the block is signed
  with the configuration key the keys server itself holds, so a malicious
  server could lift the rejections. Builds released after unsigned handshakes
  are refused for everyone will ignore the block.
- **Earlier mitigations remain (2026-09-17):**
  - the relay stamps the authenticated sender (`from_device_id`) on every queued
    message, and the client drops a wire whose header names someone else (C-1);
  - a wire naming the receiving device itself is dropped;
  - "session ended" wipes only after the keys server confirms the registration
    is gone;
  - room messages are signed per sender generation (K-1).
- **Still open:**
  - the legacy `SKS1` wire still opens new sessions without any signature
    check, so the server can present a message from any device id. Replies go
    over the current format, so it cannot read them. New sessions from `SKS1`
    are refused in the next phone release;
  - a wire without the relay's sender stamp is still accepted; refusing it
    (C-1, stage 1b) is planned no earlier than 30 days after 17 September 2026;
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

**Delivery invariant:** the `delivered` receipt goes back to the sender only after `decryptFromWire` and `handleDecryptedInboundPayload` both succeed, so the relay cannot make an unprocessed message look delivered. The relay-level acknowledgement is separate: a wire that cannot be decrypted is acknowledged and quarantined, so it does not block the mailbox, and the sender is asked to resend.

---

## Authentication (Relay / Keys)

### AuthSigner (`apps/flutter/secretly_app/lib/security/auth_signer.dart`)

Every request to relay/keys is signed with the device identity key (Ed25519).
The signature covers a canonical text of the request with a domain tag, a
timestamp and a random nonce, and travels in four headers:
`x-secretly-device-id`, `x-secretly-ts-ms`, `x-secretly-nonce-b64` and
`x-secretly-signature-b64`. (`SKS1` is the magic of the legacy message wire,
not an authentication header; an earlier version of this document confused the
two.) On the WebSocket, the signature is checked once, at `HelloAuth`.

Replay protection, two layers: requests outside a ±5-minute timestamp window are
rejected, and both servers keep a nonce cache (`used_nonces`, 10-minute TTL, in
memory, so it is empty after a restart) — presenting the same nonce twice
returns `401 replayed nonce` inside the window.

### Server-side (Keys)

Production preflight (`keys_security_errors`):
- `REQUIRE_PROFILE_SECRET=true`
- `REQUIRE_DEVICE_LOOKUP_AUTH=true`
- `REQUIRE_LIST_DEVICES_AUTH=true`
- `REQUIRE_BUNDLE_FETCH_AUTH=true`
- `INTERNAL_KEY` must be set
- `TRUST_XFF` + `PROXY_ONLY` checks

With `SECRETLY_ENV=prod` (or `STRICT_PRODUCTION`) the server refuses to start
if any are missing; without it, it only logs a warning.

---

## Local Data Security

- **Database**: SQLCipher on phones, SQLite3 Multiple Ciphers on desktop. The passphrase is 32 random bytes kept by `SecureSecrets`; it is not derived from the identity key.
- **SecureSecrets** (`apps/flutter/secretly_app/lib/security/secure_secrets.dart`): Keychain with `ThisDeviceOnly` on iOS and macOS, Keystore on Android (AES-CBC without an integrity check — SEC-03, planned), DPAPI on Windows. On iOS the notification extension reads a copy of the device identity seed from the app group's settings; it is moving into the keychain.
- **Media files**: regular files in the app's folders, under the OS's storage encryption rather than the database key.
- **SafeBackup** (`apps/flutter/secretly_app/lib/security/safe_backup.dart`) and **RecoveryKit** (`apps/flutter/secretly_app/lib/security/recovery_kit.dart`): AES-256-GCM under a password-derived key (PBKDF2-HMAC-SHA256; 400 000 and 200 000 iterations). The archive holds everything needed to restore — the database snapshot, media, the content key and the device identity material — so the password is the only barrier (THREAT_MODEL §5.5).

---

## Push Notifications

FCM/APNs payloads carry **no message text** since 24 September 2026, but they are
not empty:
- data: `type=relay_pending`, the recipient and sender device ids, a message id,
  a timestamp, and for messages the conversation id and the message kind;
- the notification title: the sender's display name, or the group title, unless
  the recipient chose hidden previews; for calls, the caller's display name;
- the app wakes, opens the WebSocket, drains the inbox and decrypts locally. The
  iOS notification extension does not decrypt yet; it shows the relay's title.

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
