# Secretly

[![CI](https://github.com/Arkhanhel/Secretly/actions/workflows/ci.yml/badge.svg)](https://github.com/Arkhanhel/Secretly/actions/workflows/ci.yml)
[![Licence: AGPL v3](https://img.shields.io/badge/licence-AGPL--3.0-blue.svg)](LICENSE)

An end-to-end encrypted messenger for iOS, Android, macOS and Windows.

**Get it:** [Google Play](https://play.google.com/store/apps/details?id=com.secretly.secretly_app) ·
[App Store](https://www.secretlyapp.com/download) ·
[secretlyapp.com](https://www.secretlyapp.com)

**An account is a keypair generated on your device.** No phone number, no email
address, no analytics SDK, no third-party telemetry. There is nothing to
register and no identifier that maps to a legal person.

Written and maintained by **Yurii Arkhanhelskyi**. Published on the App Store
and Google Play by **SIA Secretly**, Valmiera, Latvia.

---

## Why this exists

In much of the world a SIM card is an identity document: registration requires a
passport, and the number is retained by the carrier. Every mainstream secure
messenger that requires a phone number therefore asks you to disclose a
state-linked identifier before the first message is encrypted.

For many people the content of a conversation is not the risk. The fact of the
conversation is.

## What is here

| | |
|---|---|
| Client | Dart / Flutter, ~333k lines of hand-written Dart, four platforms |
| `secretly_keys` | Rust — identity, key bundles, backups |
| `secretly_relay` | Rust — message transport, rooms, calls |
| `secretly_core` | Rust — shared crypto primitives |

**Cryptography:** Double Ratchet with X3DH key agreement, Ed25519 identities,
XChaCha20-Poly1305 for media and archives, SQLCipher for local storage,
DTLS-SRTP for calls.

Start with [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Security

🔴 Read [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) before drawing
conclusions about what this protects. It states what we defend against and —
more usefully — what we do **not**: no certificate pinning, metadata visible to
the relay, key material not zeroed in a garbage-collected language, and a
Double Ratchet implementation that is ours rather than a reviewed library.

That section exists to be read, not to be buried.

**Reporting a vulnerability:** [`SECURITY.md`](SECURITY.md). Please do not open
a public issue.

## Licence

Copyright (C) 2025-2026 Yurii Arkhanhelskyi.

**GNU Affero General Public License v3** — full text in [`LICENSE`](LICENSE).

An additional permission under section 7 allows distribution through application
stores, which the AGPL otherwise makes legally uncertain; see
[`LICENSE-EXCEPTION`](LICENSE-EXCEPTION). It applies to forks as well as to us.

Third-party components are listed in [`NOTICE`](NOTICE). Font licences are in
`apps/flutter/secretly_app/assets/fonts/`.

The name "Secretly" and the logo are trademarks and are **not** covered by the
licence. Fork freely; publish under your own name.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). A contributor agreement
([`CLA.md`](CLA.md)) is required, because the project is dual-licensed and
commercial licences are what fund it. You keep the copyright in your work.

Two rules worth knowing before you start:

- **Never create a second ratchet implementation.** Two implementations
  disagreeing is worse than one implementation's flaws.
- **A guard test must be able to fail.** Break the code it protects; if the test
  still passes, it protects nothing.

## Building

Pinned toolchains: Flutter `3.41.7` (`.flutter-version`), Rust `1.93.1`
(`rust-toolchain.toml`). Other versions may build, but only these two produce
the binaries we ship.

```bash
cd apps/flutter/secretly_app
flutter pub get
flutter analyze
flutter test

cd ../../..
cargo test --workspace
```

A runnable build needs server addresses passed at compile time — see
[`docs/BUILD.md`](docs/BUILD.md). Without them the app talks to `localhost`.

## What is not in this repository

Only source code is published here. Deliberately absent:

| | Why |
|---|---|
| Icons, stickers, wallpapers, profile decoration | licences permit use in the app, not redistribution as files |
| Firebase configuration | create your own project |
| Internal documents — incident write-ups, plans, runbooks | not relevant to reviewing the code |
| Signing keystores and any keys | they are not here and never will be |

The build runs; some decoration will be missing. Fonts **are** included, with
their licences.

## Project documents

[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) ·
[`CHANGELOG.md`](CHANGELOG.md) ·
[`AUTHORS`](AUTHORS) ·
[`docs/BUILD.md`](docs/BUILD.md)

## Русская версия

Описание на русском — [`README.ru.md`](README.ru.md).
