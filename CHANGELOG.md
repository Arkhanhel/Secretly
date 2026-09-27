# Changelog

Notable changes to Secretly. Dates are the day the change reached a published
build, not the day it was written.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow the scheme `MAJOR.MINOR.PATCH+BUILD`, where the build number is
what the app stores show.

---

## [Unreleased]

Work in progress on the `main` branch; nothing listed here has reached a
published build yet.

---

## [1.8.61] — 2026-09-26

Builds 630 (iOS TestFlight, macOS, Windows) and 631 (Android, Windows). Source:
tags `v1.8.61-630`, `v1.8.61-631-android` and `v1.8.61-631-windows`.

### Fixed
- Delivery receipts could get stuck and, once enough piled up, stop being sent.
- Windows: two writes to the secrets store could race and lose the device key or
  the database password. 631 queues the writes and moves the database into the
  application folder; anyone affected needs to link the computer again.
- Android: native libraries are aligned to 16 KB pages, as Google Play requires.

## [1.8.59] — 2026-09-24

Build 628.

### Privacy
- The app no longer sends the beginning of each message to the server for
  notification previews. The relay discards it from older versions as well.

## [1.8.58] — 2026-09-24

Build 627.

### Security
- The device that starts a conversation signs the handshake. An older wire
  format and unsigned handshakes from older versions are still accepted for
  now; see `KNOWN_ISSUES.md`.

### Fixed
- Incoming messages could appear twice on a second device.

## Between 1.8.39 and 1.8.58 — September 2026

- The desktop app for macOS and Windows, downloaded from our website and
  updated automatically.
- Sender authentication in rooms: the relay can no longer name a sender on
  another device's behalf.

---

## Before this repository was public

Secretly was developed privately from 2025 until the first public release of
the source code. That history is not itemised here: it was written by one
person, the commit messages were internal notes, and re-publishing them as a
changelog would suggest a rigour the process did not have.

What the versions up to **1.8.39 (build 588, 5 September 2026)** contain:

- End-to-end encryption using Double Ratchet with X3DH key agreement and
  Ed25519 identities; XChaCha20-Poly1305 for media and archives; SQLCipher for
  local storage; DTLS-SRTP for voice and video.
- Accounts as device-generated keypairs — no phone number, no email address, no
  analytics SDK.
- Rooms with a shared sender key, group calls, polls and events.
- Disappearing messages, screenshot protection, PIN, recovery kit and contact
  verification through safety numbers. None of these are behind payment and
  none ever will be.
- Encrypted backups with a user-held key.
- Eight interface languages: German, English, Spanish, French, Portuguese
  (European and Brazilian), Russian, Ukrainian.
- Android 7.0+, iOS 15.5+, macOS, Windows.

Known limitations at this point are stated in
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) §5. They are listed there rather
than here because they are not history — they are current.

---

Entries are added from the first public release onwards. Security fixes are
listed under **Security** with a reference to the advisory once it is published,
including the ones that are embarrassing for us.
