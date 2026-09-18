# Changelog

Notable changes to Secretly. Dates are the day the change reached a published
build, not the day it was written.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow the scheme `MAJOR.MINOR.PATCH+BUILD`, where the build number is
what the app stores show.

---

## [Unreleased]

Work in progress on the `main` branch.

### Added
- Desktop client for macOS: rooms, polls, events, media sending, link previews.

### Security
- Sender authentication in rooms: the relay can no longer name a sender on
  another device's behalf. The remaining handshake signature is tracked
  internally as C-2.

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
