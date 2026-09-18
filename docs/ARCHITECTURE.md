# Architecture

Written against the code as of 28 August 2026. The previous version described
the system as it stood in May and predated group rooms, the desktop clients, the
server backup archive and the paid tier — anyone auditing from it would have been
auditing a system that no longer exists.

---

## Shape of the system

Three programs and one shared library.

| Component | Language | Size (measured 18 Sep 2026) | Role |
|---|---|---|---|
| Client | Dart / Flutter | 332,931 lines, generated localisations excluded | iOS, Android, macOS, Windows |
| `secretly_relay` | Rust | 34,772 lines | message transport, rooms, calls, blobs |
| `secretly_keys` | Rust | 13,560 lines | identity, key bundles, backups, entitlements |
| `secretly_core` | Rust | 201 lines | local-content AEAD over FFI — see below |

Both servers keep state in SQLite. The client keeps state in SQLCipher.

**`secretly_core` is smaller and narrower than the name suggests.** An earlier
version of this document described it as ~3k lines of primitives shared by the
servers. It is 198 lines, and neither server uses it. What it provides is one
XChaCha20-Poly1305 seal/open pair, loaded over FFI by
`apps/flutter/secretly_app/lib/crypto/rust_crypto_provider.dart` and used for local content encryption on
Android (arm64, the only ABI shipped); everywhere else a byte-compatible
pure-Dart implementation (`apps/flutter/secretly_app/lib/crypto/dart_crypto_provider.dart`) does the same
work, and either can read what the other wrote. The end-to-end ratchet does not
use it: **X3DH and the Double Ratchet are pure Dart**, under `apps/flutter/secretly_app/lib/ratchet/`. A
leftover demo binding, `apps/flutter/secretly_app/lib/rust_core.dart`, exposes only `version` and `add`
and is called by nothing.

**The two servers are deliberately separate.** The key server knows who exists;
the relay knows what moved. Neither holds both halves, and a compromise of one
does not hand over the other.

## What each server knows

### `secretly_keys`

Twenty-nine routes. The interesting ones:

| Route | Purpose |
|---|---|
| `/v1/profile/create` | mints a profile — no phone, no email, no name required |
| `/v1/profile/{id}/devices` | which devices a profile has (signed request) |
| `/v1/profile/{id}/meta` | display name, photo, presence |
| `/v1/keys/bundle/{id}` | X3DH prekey bundle |
| `/v1/device/register_proof` | device registration with proof of the profile secret |
| `/v1/backup/{id}` | encrypted backup archive |
| `/v1/config` | signed feature flags and rollout percentages |
| `/v1/entitlements/*` | paid tier, keyed to profile id only |

It holds: profiles, devices, key bundles, one-time prekeys, backup archives,
entitlements. **It holds no contact graph and no messages.** That is a design
constraint, not an omission — see `THREAT_MODEL.md` §5.2a for what it costs.

### `secretly_relay`

Fifty-three routes. Message transport plus everything that needs a rendezvous
point:

| Area | Routes |
|---|---|
| Messages | `/v1/send`, `/v1/pending/{device}`, `/v1/ack`, `/v1/cancel_scheduled` |
| Rooms (groups) | `/v1/rooms`, `/v1/rooms/{id}`, `/v1/room-invites/{slug}` |
| Calls | `/v1/ice/{device}`, `/health/calls` |
| Media | `/v1/blob/upload`, `/v1/blob/{id}` |
| Push | `/v1/push/{device}` |
| Support | `/v1/support`, `/v1/support/replies` |

It holds ciphertext in per-device mailboxes until the recipient acknowledges it,
or until the envelope expires (seven days for a message). It sees source device,
destination device, size and timing — and cannot see content.

**Group sender attribution is forgotten after 30 days.** For one-to-one messages
the relay never stores the sender at all.

## Client modules

| Module | Lines | What lives there |
|---|---|---|
| `ui` | 171k | four platforms' interfaces, including a separate desktop workspace |
| `app` | 54k | `AppController` — the orchestrator |
| `l10n` | 21k | eight languages |
| `storage` | 13k | SQLCipher schema, outbox, event log |
| `calls` | 13k | WebRTC session, ICE policy, call journal |
| `transport` | 8k | HTTP and WebSocket clients, DNS fallback, server clock |
| `security` | 5k | device keys, secure storage, backup format, account identity |
| `rooms` | 4.4k | group membership, sender keys, invites |
| `ratchet` | 3.7k | Double Ratchet and X3DH |
| `entitlements`, `billing` | 3.2k | paid tier |
| `push`, `sync`, `attachments`, `messages` | 4.7k | delivery support |

🔴 **`ratchet` is the smallest security-critical module and the most important.**
It is our own implementation of the Double Ratchet in Dart, not a reviewed
library. If you have limited time, spend it there — and see `THREAT_MODEL.md`
§5.4 for why we consider this a known limitation rather than a feature.

## How a message travels

1. The sender resolves the recipient's device list (`/v1/profile/{id}/devices`,
   signed) and fetches key bundles for any device it has no session with.
2. X3DH establishes the session; the Double Ratchet advances per message.
3. One ciphertext is produced **per recipient device**, plus one per the sender's
   own other devices.
4. Each ciphertext is queued in the local outbox, then uploaded to `/v1/send`.
5. The relay stores it in the destination device's mailbox and wakes the device
   by push.
6. The recipient drains the mailbox, decrypts, and acknowledges. The
   acknowledgement is what deletes the row.
7. Delivery and read receipts travel back as ordinary encrypted envelopes.

Media follows the same path with the payload in an encrypted blob, referenced by
id.

Failure paths — undecryptable wires, session resets, duplicate delivery — are
not covered here. They live in an internal audit document that is not published
while the defects it lists are open; the ones with security impact are in
`THREAT_MODEL.md`.

## Groups (rooms)

Rooms have a membership list on the relay and a sender key per room. A room
message is encrypted once under the sender key rather than once per member,
which is what makes larger rooms possible.

**Rooms are less protected than one-to-one conversations, and we say so.** The
gate that blocks sending to unverified devices is wired into every one-to-one
path and none of the room paths.

## Calls

WebRTC with DTLS-SRTP. ICE servers and the network policy come from the relay
(`/v1/ice/{device}`); STUN and TURN run on our own coturn. The policy can be
`p2p_preferred`, `relay_preferred` or `relay_only`; production uses
`relay_preferred`, and a per-user setting can force `relay_only` to hide the
caller's address at the cost of latency.

## Backup

The user can store an encrypted archive of their history on the key server. The
archive is AES-256-GCM under a key derived from a user-chosen passphrase.
Retrieval requires an access token derived from the same passphrase by a
different label, so the server can verify the right to download without being
able to decrypt.

This subsystem carried the most serious finding of our internal review and is
still being migrated; `THREAT_MODEL.md` §3.4 has the current state.

## Configuration and rollout

Feature flags come from `/v1/config`, **signed**, with a public key baked into
the client. A flag that fails verification falls back to its safe state rather
than its last value. Percentage rollouts are deterministic per device id, so
widening a rollout never removes a device that was already included.

This is how changes that could break an installed base are staged, and it is why
several fixes in this repository are described as "enabled for profiles that can
already satisfy them."

## Platform integration

| | iOS | Android | macOS | Windows |
|---|---|---|---|---|
| Push | APNs + VoIP | FCM | — | — |
| Background fetch | Notification Service Extension | WorkManager | — | — |
| Key storage | Keychain, `first_unlock_this_device` | KeyStore-wrapped | Keychain | DPAPI |
| Screen privacy | cover view on resign-active | `FLAG_SECURE` | — | — |

🔴 The iOS Notification Service Extension **must never write to the ratchet**.
It decrypts for display only; a second writer would fork the chain.

## What is not in this repository

Decorative assets, Firebase configuration, deployment tooling and internal
incident write-ups. See the README for why. The build runs; some decoration will
be missing.
