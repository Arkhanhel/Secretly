# Secretly

[![CI](https://github.com/Arkhanhel/Secretly/actions/workflows/ci.yml/badge.svg)](https://github.com/Arkhanhel/Secretly/actions/workflows/ci.yml)
[![Licence: AGPL v3](https://img.shields.io/badge/licence-AGPL--3.0-blue.svg)](LICENSE)

An end-to-end encrypted messenger where an account is just a keypair your phone
generates. No phone number, no email address, no analytics SDK. There is nothing
to register, and nothing that ties the account to a name on a document.

Android and iOS are in the stores:
[Google Play](https://play.google.com/store/apps/details?id=com.secretly.secretly_app) ·
[App Store](https://apps.apple.com/app/id6760417329) ·
[secretlyapp.com](https://www.secretlyapp.com).
Desktop apps for macOS and Windows are available from
[secretlyapp.com/download](https://www.secretlyapp.com/download). The macOS app
is signed, notarized by Apple and updates itself; the Windows app is, for now,
an unsigned zip without an installer.

Written and maintained by Yurii Arkhanhelskyi. Published in the app stores by
SIA Secretly, Valmiera, Latvia.

## Why it works this way

In a lot of countries you cannot buy a SIM card without a passport, and the
carrier keeps the record. So any messenger that asks for your phone number has
already asked you for a state-issued identity, before a single message gets
encrypted. For plenty of people that is the part that actually matters: not what
they said, but that they spoke to someone at all.

That is the problem this is built around. Whether it succeeds is something you
can check yourself, which is most of the reason the code is here.

## What is in the repository

About 478,000 lines of our own code, counted with `wc -l`:

| | lines |
|---|---|
| Client, Dart and Flutter — phone and desktop share one codebase | 332,931 |
| Client tests | 86,739 |
| `server/relay` — message transport, rooms, calls, blob storage | 34,772 |
| `server/keys` — identities, prekey bundles, encrypted backups, entitlements | 13,560 |
| Android, iOS, macOS and Windows platform code | 9,606 |
| `core/rust/secretly_core` — crypto primitives shared over FFI | 201 |

Generated localisations add another 22,000 lines and are not counted above.
Neither is the vendored code under `third_party/`, which is about 484,000 lines
on its own — mostly whisper.cpp and ggml for on-device speech recognition. The
interface ships in eight languages.

Encryption is Double Ratchet with X3DH key agreement and Ed25519 identities.
Media and archives use XChaCha20-Poly1305, the local database is SQLCipher,
calls are DTLS-SRTP.

[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) is the place to start reading.

## Security

Please read [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) before you conclude
anything about what this protects. It lists what we defend against, and section
5 lists what we do not: there is no certificate pinning, the relay sees metadata,
key material is not zeroed because Dart is garbage-collected, and the Double
Ratchet implementation is ours rather than a reviewed library. We would rather
you found that in our own documentation than in a blog post.

Two things we fixed after finding them ourselves, both described in the threat
model: until September 2026 the initiator of a session was not authenticated by
a signature, so a malicious server could impersonate a device (1.8.58 and later
sign the handshake); and the app sent the first characters of each message to
the server for notification previews (the relay discards them since 24 September
2026, and 1.8.59 no longer sends them).

No independent audit has been done. We will not say otherwise until one has.

Found something? [`SECURITY.md`](SECURITY.md) has the process. Please do not open
a public issue for it — people are using this in places where an unfixed
disclosure is dangerous for them.

## Licence

Copyright (C) 2025-2026 Yurii Arkhanhelskyi.

GNU Affero General Public License v3, full text in [`LICENSE`](LICENSE).

There is an additional permission under section 7 for distribution through app
stores, because the AGPL alone makes that legally murky and we did not want
forks stuck outside the stores while we were inside them. It is in
[`LICENSE-EXCEPTION`](LICENSE-EXCEPTION) and it applies to you as much as to us.

Third-party components are in [`NOTICE`](NOTICE); font licences sit next to the
fonts in `apps/flutter/secretly_app/assets/fonts/`.

The name and the logo are trademarks and are not covered by the licence. Fork it
if you like — just ship it under your own name.

## Building

Use Flutter 3.41.7 and Rust 1.93.1. Both are pinned, in `.flutter-version` and
`rust-toolchain.toml`. Other versions will probably work, but those two are what
the released binaries were built with.

```bash
cd apps/flutter/secretly_app
flutter pub get
flutter analyze
flutter test

cd ../../..
cargo test --workspace
```

That compiles and tests everything. It does not give you a working app: server
addresses are passed at compile time, and without them the client talks to
`localhost`. [`docs/BUILD.md`](docs/BUILD.md) has the flags and how to run the
servers. [`docs/VERIFY.md`](docs/VERIFY.md) has the checksums of what we upload
to the stores, and an honest account of why you cannot byte-compare them with
what you installed.

## What is missing from this repository

Icons, stickers, wallpapers and profile decoration are not here. Their licences
let us use them inside the application but not hand the files around, so the
build generates empty placeholders instead. The app runs; some of it looks bare.
Fonts are included, licences and all.

Firebase configuration is not here either — make your own project. Nor are
internal documents, which have nothing to do with reviewing code. Signing keys
have never been in this repository and never will be.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) covers the details. The short version is
that we ask for a contributor agreement ([`CLA.md`](CLA.md)), because commercial
licences are what pay for the project and selling one requires holding the
rights. You keep the copyright in your own work.

Two things worth knowing before you write code. Do not add a second ratchet
implementation, ever — two of them disagreeing is a worse problem than one of
them being imperfect. And when you write a test that guards something, break the
code it guards and watch it fail. A guard test that still passes on broken code
is guarding nothing, and we have found a few of those.

## Also here

[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) ·
[`CHANGELOG.md`](CHANGELOG.md) ·
[`AUTHORS`](AUTHORS) ·
[`README.ru.md`](README.ru.md) — то же самое по-русски
