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

## [1.8.63] — 2026-10-04

Build 644 (macOS, Windows, iOS TestFlight, Android). Source: tag `v1.8.63-644`.

### Security
- Desktop: a received file whose real extension can run code (`.exe`, `.lnk`,
  `.js`, `.hta`, macro-enabled documents and similar) never opens on a single
  click; a warning names the real extension. Windows copies carry the
  Mark-of-the-Web, and invisible bidi characters are stripped from file names.
- Desktop: the app lock (Touch ID or PIN) now covers every open window and
  dialog; an incoming call no longer lifts the PIN lock; notifications under
  the lock show no sender, no text and no Reply.
- Desktop: the "Personal" chats password can no longer be bypassed through
  notifications, links or back/forward navigation.
- Desktop: a `secretly://profile` link asks before opening a chat and never
  accepts a message request by itself; links wait while the app is locked.
- Windows: decrypted attachments and contact photos moved out of the user's
  Documents folder (often synced to the cloud) into the application's folder.
- Windows: the updater refuses an older signed installer (downgrade protection).
- Desktop: optional protection of the window from screenshots and screen
  recording.
- Server: device activity times of someone else's profile are reported with
  day precision only.

### Fixed
- macOS: closing the window quit the app, so messages and calls stopped
  arriving in the background; it now stays in the menu bar.
- macOS: the app did not start on Apple Silicon Macs below macOS 26; the
  minimum is now macOS 13 Ventura.
- Desktop: after "Leave" or "End for everyone" in a group call the microphone
  stayed connected.
- Desktop: "Create account" did not create an account, and "Connect device" in
  Settings signed the computer out.
- Desktop: voice messages could not be recorded.

### Added
- Desktop: message, open-chat and call sounds can be chosen and previewed.

### Changed
- Desktop: neutral gray dark theme; chat wallpapers keep the pattern size and
  repeat it on larger windows instead of stretching.
- Desktop builds ship the GPL license text and source information for FFmpeg.

---

## [1.8.62] — 2026-09-28

Build 635 (macOS, Windows, iOS TestFlight, Android). Source: tag `v1.8.62-635`.

### Fixed
- Linking a computer no longer leaves an empty chat with a raw ID behind on
  the phone.

### Changed
- Windows: a regular installer (`.exe`) with silent updates replaces the ZIP as
  the main download; the portable ZIP stays available.

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
