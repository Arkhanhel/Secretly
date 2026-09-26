# Secretly — Threat Model

**Version 1.2 — 26 September 2026** (1.1: 2 September 2026; 1.0: 25 August 2026)

This document states what Secretly protects, against whom, and — equally
important — **what it does not protect against**. Every claim here is meant to be
verifiable against the source code. Where a protection is incomplete or absent,
it is named as such rather than omitted.

Written for independent auditors, corporate reviewers, and anyone deciding
whether this tool fits their risk.

**Changes in 1.2.** Group calls are named as not end-to-end encrypted (§3.5).
The metadata the servers keep is listed in full (§5.2). Four things a malicious
server can still do are added to A3, and two iOS storage exceptions to A5. The
replay window is corrected to ±5 minutes (§7). SEC-15 is marked closed (§5.8).
Auto-delete, voice dictation and third-party downloads are described
(§5.11–§5.13).

---

## 1. Assets — what is worth protecting

| Asset | Where it lives | Impact if lost |
|---|---|---|
| Message content | device storage (SQLCipher), relay (ciphertext only) | conversation exposed |
| Ratchet state and message keys | device storage | past and future messages decryptable |
| Device identity key (Ed25519) | OS keychain / keystore | impersonation of the device |
| Local database passphrase | OS keychain / keystore | **entire local history exposed** |
| Server backup archive | keys server (encrypted blob) | full history exposed if password is broken |
| Media files (sent and received) | device storage, as regular files | attachments exposed |
| Group-call audio and video | our media server, in transit (§3.5) | call content exposed to the operator |
| Social graph (who talks to whom) | relay (see §5.2) | relationships exposed |
| Profile identifier | public by design | discoverability, not confidentiality |

---

## 2. Adversaries

### A1 — Passive network observer

Sees traffic between device and servers. Cannot read message content: transport
is TLS, payloads are end-to-end encrypted underneath it.

### A2 — Active network attacker

Can intercept, modify, and inject traffic. Constrained by TLS certificate
validation against system roots. **See §5.1 — we do not pin certificates.**

### A3 — Malicious or compromised server operator

This is the adversary the architecture is built around. The server stores
ciphertext envelopes addressed to device identifiers and cannot decrypt them:
message keys never leave the devices.

The server **can**: observe metadata (§5.2), withhold or delay delivery, and
attempt to serve a forged prekey bundle to mount a man-in-the-middle attack —
which is what contact verification exists to detect (§3.3).

The key agreement does not authenticate the initiator (§3.1), so the server
could also start a session in the name of a device you already know. Handshake
signatures close this for every device that signs: to succeed, the server has
to change that device's identity key in the open, which resets verification and
shows a notice. What remains open is listed in §5.10.

Four more things a malicious server can do today; each is being closed:

- **Use a legacy handshake.** An old wire format still opens new sessions
  without the handshake signature, so the server can show a message "from" any
  device, including your own computer. It cannot read the replies, which travel
  in the current format. The next phone release refuses new sessions in the
  old format.
- **Switch the signature check off.** The configuration switch that disables
  refusals of unsigned handshakes (§5.10) is signed with the server's own
  configuration key. It exists so that delivery survives the rollout. Builds
  released after unsigned handshakes are refused for everyone will ignore it.
- **Substitute a computer during linking.** Until the next phone release, the
  phone trusts the computer's key as served by the key server when it hands the
  account over to a newly linked computer. The fix — the computer's key
  fingerprint in the linking QR code, checked by the phone — is in the code.
- **Decide room membership.** Room membership lives on the relay and is not
  signed. The server can add a member, or a device of a member, to a room; that
  member then receives the room key. It appears in the member list.

### A4 — Attacker with physical access to an unlocked device

Out of scope. An unlocked device with the app open is the user's own session.

### A5 — Attacker with physical access to a locked device

Local database is encrypted with SQLCipher on phones and SQLite3 Multiple
Ciphers on desktop; the passphrase lives in the OS keychain (iOS, macOS), the
keystore (Android) or DPAPI (Windows), released only after first unlock.
Defeating this requires defeating platform-level protection.

Media files are not in that database: sent and received attachments, and voice
transcripts, are regular files protected only by the operating system's storage
encryption.

Since 25 August 2026, keychain items are stored **`ThisDeviceOnly`**: they are no
longer carried to a new device by an Apple backup. On Android, application
backups are disabled in the manifest.

Two exceptions on iOS, both moving in the next release: the notification
extension reads a copy of the device identity key from the app group's settings
rather than from the keychain; and media files sit in the app's Documents
folder, which is visible in the Files app and included in device backups. On
Windows, media files sit in the user's Documents folder, which OneDrive may
sync.

### A6 — Attacker who obtains a device backup

Apple: keychain items no longer migrate (see A5). Android: backups disabled.
Server-side archive: see §3.4.

### A7 — State-level adversary compelling the operator

The operator can be compelled to hand over what it has: ciphertext envelopes and
metadata (§5.2). It cannot be compelled to produce message content it never had.
It **can** be compelled to serve forged key material to a targeted user — see
§3.3 for the countermeasure and its limits.

---

## 3. What we protect, and how

### 3.1 Message confidentiality and integrity

Double Ratchet v3 with an X3DH-like key agreement. Each message uses a fresh key
derived from a ratcheting chain; message keys are discarded after use. Prekeys
are not yet: the private halves of one-time prekeys are kept after use, and the
signed prekey is not rotated. Both are planned.

- **Forward secrecy:** compromising current state does not decrypt past messages.
- **Break-in recovery:** a compromise heals once a fresh DH ratchet step happens.
- **Integrity:** AEAD (XChaCha20-Poly1305). A forged message fails
  authentication and — verified by test — **does not advance ratchet state**.
- **Replay:** message numbers plus single-use skipped keys. A retired skipped key
  is deleted, so the same ciphertext cannot be opened twice.
- **Denial of service via skipped keys:** bounded at 200 per step on phones and
  5,000 on desktop (a server flag can raise the desktop bound to 25,000); a
  message claiming a larger gap is rejected before any key is derived.
- **Initiator authentication:** the initiator's identity key is not part of the
  DH. Since 24 September 2026 the initiator signs the handshake with that key,
  and the receiver checks the signature against the key it has pinned for the
  device (SECURITY_MODEL, "Session Initialization"). It protects a conversation
  once both devices run a build that has it.

**Note for auditors:** this is our own implementation of the Double Ratchet,
not a binding to libsignal. That is the single largest thing worth your time.

### 3.2 Local storage

SQLCipher for the message database; OS keychain/keystore for keys, with
`ThisDeviceOnly` accessibility on Apple platforms.

### 3.3 Man-in-the-middle detection

Contact verification through safety numbers, compared out of band. The safety
number is bound to the **device**, so a new device is visibly a new device.

**Limit:** verification is opt-in and advisory by default. Users may enable
strict mode, which blocks sending to unverified contacts.

**Known gap (SEC-06):** strict mode is enforced on one-to-one paths only —
messages, stickers, attachments, resends and scheduled messages. **Group paths do
not enforce it.** Since 28 August 2026 the setting text says so explicitly, in
all eight languages; the behaviour on group paths is unchanged and remains a
limitation we state rather than hide.

### 3.4 Server backup archive

An optional encrypted archive of local history, stored on the keys server.
Encrypted client-side with AES-256-GCM; the key is derived from a user-chosen
password with PBKDF2-HMAC-SHA256 (400 000 iterations for new archives; archives
written earlier at 200 000 remain readable). The recovery kit uses 200 000.

**Being remediated (SEC-01).** Until 25 August 2026 the archive could be
downloaded by **anyone who knew the profile identifier** — the signature check
was applied only to requests that presented one. Password strength was therefore
the only barrier, and it could be attacked offline.

Current state: clients derive an access token from the archive password and
present it; the server stores only a hash of that token. Token and content key
are separated by distinct salts and distinct labels, so a server holding the
token cannot decrypt the archive. **The public path is still open for clients
that predate this change** — closing it fully requires those clients to update.
Progress is measurable server-side.

### 3.5 Calls

**One-to-one calls** use WebRTC with DTLS-SRTP, directly between the two
devices. Call signalling — offers, answers and ICE candidates — travels over the
same end-to-end encrypted channel as messages, so the keys of the media stream
are authenticated by that channel. It is only as strong as the device keys:
until a contact is verified (§3.3), a server that serves a false device could
answer the call.

The relay still learns that a call happened. The call action, a call id and
whether it is a video call travel beside the ciphertext; the invitation also
carries the caller's display name and profile id; and the push that rings the
phone carries the caller's display name through Apple or Google.

**Group calls are not end-to-end encrypted.** They go through our own LiveKit
media server (SFU), which runs on the same host as the relay. Audio, video and
screen sharing are encrypted in transit between each device and the server, but
the server decodes them, so the operator could listen. It also sees who is in a
call, when, and each participant's IP address. End-to-end encryption for group
calls — a key per participant, distributed over the existing end-to-end
channel — is the next piece of work on calls. Even then, the server will see
who takes part, when, and who is speaking.

**Your IP address is visible to the person you are calling — by default.**
One-to-one calls connect peer-to-peer, which is standard WebRTC behaviour and
the reason call quality is good, but it means the other party sees your address.
The production policy only puts our TURN server first in the list; it does not
hide addresses. Since 28 August
2026 (release 1.8.16) a per-user setting forces every call through our relay;
its label states the cost in latency plainly. The default remains peer-to-peer.

**Three call findings from our August review are closed (SEC-10, shipped 28
August 2026):** the fallback STUN server is now derived from our own relay host
rather than Google's, so no third party observes call metadata when the relay
omits ICE servers; the relay-only setting above now exists; and the
`validateIceConfigForSession` guard, which used to run *after* the fallback had
already rewritten the policy and therefore never fired, now runs before it.

### 3.6 Account model

No phone number, no email, no password recovery flow. An account is a key pair
generated on the device. This removes an entire class of attacks (SIM swap,
account recovery abuse, mailbox compromise) and removes the link between an
account and a phone number or email. It does not make users unknowable to us:
IP addresses and push tokens still reach our servers (§5.2).

---

## 4. What we deliberately do NOT claim

- **We do not claim unbreakable encryption.** No independent audit has been
  performed as of this writing. That is precisely why this document exists.
- **We do not claim anonymity from a network observer.** Using Secretly is
  visible to anyone watching your connection.
- **We do not claim protection against a compromised device.** Malware with
  sufficient privileges reads messages after decryption, regardless of transport.
- **We do not claim metadata resistance** at the level of Signal's sealed sender
  or a mixnet. See §5.2.

---

## 5. Known limitations

### 5.1 No certificate pinning

TLS certificates are validated against the operating system's root store.
Certificate validation is **not** weakened — no `badCertificateCallback` override
exists — and SNI stays bound to the real hostname even when DNS is bypassed by a
hardcoded fallback address.

But a certificate issued by any trusted root would be accepted. An adversary able
to obtain such a certificate (A2, A7) can intercept the transport layer. **This
does not expose message content**, which is end-to-end encrypted underneath, but
it does expose metadata and enables targeted delivery manipulation.

*(An earlier version of `SECURITY_MODEL.md` described transport as
"domain-pinned". That wording was misleading and is corrected here.)*

### 5.2 Metadata visible to the server

The relay necessarily sees, for each envelope: source device identifier,
destination device identifier, size, and timing. Since 17 September 2026 it
stores the source device with each queued message, until delivery or expiry
(seven days at most), so that recipients can check who sent it. From this, the
social graph and activity patterns are derivable by the operator.

Beyond envelopes, the servers keep:

- **rooms** — name, description, avatar, membership and roles, and an index of
  who posted in a room and when (kept 30 days);
- **your profile as you publish it** — nickname, photo, bio, emoji status — and
  when you were last online;
- **devices** — your devices, their build numbers and push tokens, with
  notification preferences: muted chats, per-contact settings, quiet hours and
  time zone;
- **blocks** — who blocked whom;
- **one-to-one calls** — which devices called which, and when (kept 6 hours, or
  15 minutes after the call ends);
- **in transit** — the sender's display name and a group's title, which the
  relay uses for notification titles.

Server database backups are kept on the same host and are not yet encrypted at
rest; encryption and an off-site copy are being added.

We do not implement sealed sender or any mixing. Profile identifiers are not tied
to real-world identity, which limits — but does not remove — what this metadata
reveals.

### 5.2a Profile privacy settings: only "nobody" is enforced

Each person can set an audience — `everyone`, `contacts` or `nobody` — for their
photo, last-seen time and several other fields.

**Only `nobody` is enforced by the server.** The key server holds profiles,
devices and key bundles; it has no contact graph, so it cannot tell whether two
people are contacts. `contacts` is therefore honoured by the application, not by
the server: anyone querying the API directly sees such fields regardless of the
setting.

What the server does enforce today:

| Setting | Enforced server-side |
|---|---|
| `nobody` | yes — the field is withheld from everyone but the owner's own devices |
| `contacts` | **no** — see above; last-seen is additionally coarsened to the hour for unsigned requests |
| `everyone` | not applicable |

Closing this properly requires either a server-side notion of "contact" — which
would mean uploading the social graph, something this project deliberately does
not do — or requiring a signed request and accepting that anyone can register a
device. Neither is a clean win, and we state the gap rather than imply the
setting does more than it does.

### 5.3 Key material is not zeroed in memory

The ratchet is implemented in Dart, a garbage-collected language. Key material
cannot be reliably erased after use: copies may persist in the heap until
collection and may reach memory dumps or swap.

An attacker able to dump process memory can recover keys. We do not claim
protection against that adversary.

### 5.4 Own cryptographic implementation

Double Ratchet and X3DH are implemented in this codebase rather than delegated to
libsignal. Primitives come from reviewed libraries (`cryptography` for
XChaCha20-Poly1305, HKDF, X25519; RustCrypto and dalek server-side), but the
protocol composition is ours.

We consider this the highest-risk area of the system and the first thing an
auditor should examine.

### 5.5 Backup password strength

The archive is only as strong as the password chosen by the user; the current
minimum is 8 characters. If a copy of the archive is obtained, that password is
the only barrier.

### 5.6 Server-side breach exposes verifier material

The backup access verifier is derived from the user's password. An attacker who
steals the server database obtains both archives and verifiers, and can attempt
offline recovery. The slow derivation runs client-side to raise that cost;
protocols such as OPAQUE would remove the exposure entirely and are not
implemented.

### 5.7 Push notifications and notification previews

Message delivery uses Firebase Cloud Messaging (Android) and APNs (iOS) to wake
the app. The existence and timing of a wake-up are visible to the push provider.

**Notification previews — corrected 24 September 2026.** Earlier versions of
this document said that push payloads carry no message content. That was wrong.

The sender's app attaches a short plaintext preview to every chat message: up to
180 characters of the message text, plus the sender's display name and, for
groups, the group title. The relay uses them to build the notification. Before
24 September 2026 the relay stored the preview together with the queued message,
and therefore in its database backups. With the default notification setting it
also put the preview into the push sent through Apple or Google. The recipient's
"hidden" notification setting changed only what went into the push, not what the
relay received.

Since 24 September 2026 the relay discards the preview on arrival. It is no
longer stored and no longer sent to Apple or Google, and previews that were
already queued have been removed. Two things remain:

- the relay still receives the preview in transit, and still sees the sender's
  display name and the group title, which it uses for the notification title;
- database snapshots taken before that date may still contain previews.

Since version 1.8.59 the client no longer sends the preview; older versions
still do, and the relay discards it on arrival. Message text now appears in a
notification only when the device decrypts the message itself.

Names are a different matter. The relay puts the sender's display name — and,
for groups, the group title — into the notification title it sends through
Apple or Google, unless the recipient chose hidden previews. The caller's
display name reaches Apple or Google the same way when a call rings.

---

### 5.8 Speech-recognition model: third-party host (SEC-15, closed)

Optional voice transcription runs on-device with whisper.cpp. The model
(`ggml-base.bin`, ~140 MB) is downloaded once, on first use, from Hugging Face.
Until September 2026 it came from a mutable branch reference with no integrity
check. It now comes from a pinned revision and is checked against a
compiled-in SHA-256 and size before native code parses it; a file that does not
match is deleted. Hugging Face still sees the download and your IP address.

### 5.9 Translation models are delivered by Google ML Kit

The optional message-translation feature uses Google ML Kit. Language models
(~30 MB each) are fetched on demand by Google's own model manager from Google's
infrastructure; we cannot pin or verify them on our side. Enabling translation
also discloses to Google which language pairs a device requested, though never
any message content — translation itself runs on-device.

Neither model is fetched until the corresponding feature is used. Users for whom
either trust boundary is unacceptable can simply leave the feature off.

### 5.10 Handshake signatures are being rolled out

The receiver refuses an unsigned handshake only from a device that has already
shown it signs. Until then the check only counts. So:

- a contact still on an older build can be impersonated by the server with an
  unsigned handshake. This closes as devices update, and fully only once
  unsigned handshakes are refused for everyone;
- a new device of a known contact is trusted on first use. An account-key
  certificate exists for it but is not yet required;
- the server can replay an old, genuine signed handshake and break a live
  session. This denies service and discloses nothing;
- deniability is partly lost: a signature shows that one device started a
  session with another at some point. It says nothing about the contents.

A changed identity key is never taken silently: it resets the contact's
verification and shows a "safety number changed" notice.

### 5.11 Auto-delete works on your own devices only

Auto-delete removes messages older than the chosen period from your own
devices. It does not reach the other person's devices; they can set their own
timer. It does not yet remove downloaded files, the keys of received files or
voice-message transcripts.

### 5.12 Voice dictation may leave the device

Dictating a message uses the operating system's speech recognition. Depending
on the device and language, Apple or Google may process the audio on their
servers. Transcription of received voice messages is different: it runs on the
device (§5.8). Dictation is moving to on-device only.

### 5.13 Other third parties contacted by optional features

- Animated emoji are downloaded from Google Fonts (`fonts.gstatic.com`) the
  first time they are shown; Google sees your IP address and which animation.
- GIF search sends your search terms and IP address to GIPHY.
- Link previews are built by the sender's device, which fetches the page; the
  website sees the sender's IP address. Recipients do not contact it.
- Message translation downloads language models through Google ML Kit (§5.9).

## 6. Out of scope

- Compromised or rooted devices, and malicious keyboards or screen readers.
- Denial of service against our infrastructure.
- Attacks requiring physical access to an unlocked device.
- Coercion of a user to unlock their own device.

---

## 7. Verifying these claims

An auditor can check the following directly:

| Claim | Where |
|---|---|
| Forged messages do not advance ratchet state | `apps/flutter/secretly_app/lib/ratchet/double_ratchet_v3.dart`, `decrypt()` |
| Skipped-key bound is enforced | same file, `_skipMessageKeys` |
| Randomness comes from the OS | same file, `_randomBytes` |
| Backup access token cannot decrypt content | `apps/flutter/secretly_app/lib/security/safe_backup.dart`, `BackupAccessV1` |
| Keychain items are `ThisDeviceOnly` | `apps/flutter/secretly_app/lib/security/keychain_migration.dart` |
| Strict mode is not enforced on group paths | `apps/flutter/secretly_app/lib/app/app_controller.dart`, `_sendGateBlockingDevices` callers |
| TLS validation is not weakened | `apps/flutter/secretly_app/lib/transport/resilient_http_client_io.dart` |
| Signed-prekey signature is verified before any session is created, fail-closed | `apps/flutter/secretly_app/lib/ratchet/session_manager_v3.dart` |
| Replayed request nonces are rejected server-side (10-minute in-memory cache, lost on restart) in addition to a ±5-minute timestamp window | `server/keys/src/main.rs` and `server/relay/src/main.rs`, `used_nonces` |

Guard tests accompany each of these and are written to fail if the property is
removed.

---

## 8. Reporting

Security issues: see [SECURITY.md](../SECURITY.md).
