# Building Secretly

This document exists so that a reviewer can build the client from source and get
a working application, rather than one that silently talks to `localhost`.

## Toolchains

Both are pinned in the repository. Other versions may work; only these two
produce the builds we ship.

| | Version | Pinned in |
|---|---|---|
| Flutter | 3.41.7 | `.flutter-version` |
| Dart | bundled with Flutter | — |
| Rust | 1.93.1 | `rust-toolchain.toml` |
| Java | 17 (Temurin) | Android build only |
| Xcode | 15 or newer | iOS and macOS only |

Dependency versions are frozen in `apps/flutter/secretly_app/pubspec.lock` and
`Cargo.lock`. Do not regenerate them to build.

## Quick check — does it compile?

This needs no servers and no configuration:

```bash
cd apps/flutter/secretly_app
flutter pub get
flutter analyze
flutter test

cd ../../..
cargo test --workspace
```

`flutter test` runs the whole suite. Some tests are slow; `--concurrency=1` is
what our CI uses.

## A build that actually runs

The client takes its server addresses at compile time. Without them it falls
back to `localhost` and appears broken.

```bash
cd apps/flutter/secretly_app

flutter build apk --release \
  --dart-define=SECRETLY_KEYS_BASE_URL=https://keys.example.org \
  --dart-define=SECRETLY_RELAY_HTTP_BASE_URL=https://relay.example.org \
  --dart-define=SECRETLY_RELAY_WS_URL=wss://relay.example.org/ws \
  --dart-define=SECRETLY_CONFIG_PUBLIC_KEY_B64=<base64 public key>
```

Substitute your own hosts. Four values are required:

| Flag | What it is |
|---|---|
| `SECRETLY_KEYS_BASE_URL` | key server: identities, prekey bundles, backups |
| `SECRETLY_RELAY_HTTP_BASE_URL` | relay over HTTPS |
| `SECRETLY_RELAY_WS_URL` | relay WebSocket endpoint |
| `SECRETLY_CONFIG_PUBLIC_KEY_B64` | public half of the key that signs `/v1/config`; the client refuses an unsigned or wrongly signed configuration |

Generate the signing keypair yourself — the private half stays on your key
server as `SECRETLY_KEYS_CONFIG_SIGNING_KEY`. Ours is not in this repository and
never will be.

### Optional flags

`SECRETLY_BUILD_MARKER`, `SECRETLY_APP_VERSION`, `SECRETLY_APP_BUILD_NUMBER`
label the build. `SECRETLY_ROOM_SENDER_KEY` enables the shared room key path.
`SECRETLY_HTTP_DNS_FALLBACKS` and
`SECRETLY_ENABLE_HTTP_DNS_FALLBACKS_FOR_WEBSOCKETS` help where DNS is
interfered with. `GIPHY_API_KEY` enables the GIF picker and is optional — get
your own key from Giphy; without it that one feature is disabled and nothing
else changes.

Flags whose names contain `FORCE_PREMIUM`, `DEMO_DATA` or `CALL_LOGS` exist for
development. Leave them unset for anything you intend to use.

## Running the servers

```bash
cargo build --release -p secretly_keys -p secretly_relay
```

Both are configured entirely through environment variables. The minimum:

```bash
# key server
SECRETLY_ENV=prod \
SECRETLY_KEYS_DB=/var/lib/secretly/keys.db \
SECRETLY_KEYS_CONFIG_SIGNING_KEY=<private signing key> \
SECRETLY_INTERNAL_KEY=<shared secret between the two servers> \
  ./target/release/secretly_keys

# relay
SECRETLY_ENV=prod \
SECRETLY_BLOBS_DIR=/var/lib/secretly/blobs \
SECRETLY_INTERNAL_KEY=<the same shared secret> \
  ./target/release/secretly_relay
```

Push notifications need Apple credentials (`SECRETLY_APNS_*`) and a Firebase
project. Neither is required to exchange messages: without them delivery happens
while the app is open.

The full list of variables is in the source — `server/keys/src/` and
`server/relay/src/` read them through `env::var`, and each has a documented
default.

## Reproducing a published build

[`docs/VERIFY.md`](VERIFY.md) lists the SHA-256 of every artefact we upload to
the stores, together with the exact `--dart-define` values those builds were
made with.

Read it before comparing hashes. Google Play splits an App Bundle into
per-device APKs and re-signs them with Google's key; Apple re-signs and
re-encrypts the IPA. Neither installed copy can be byte-compared with the file
we uploaded — by anyone, including us. What you *can* do today is rebuild from
this source with the pinned toolchains and inspect what the result does. A
directly downloadable signed APK with a published checksum, which would make a
real comparison possible, is on the way; `VERIFY.md` says where that stands.

If your build behaves differently from what the threat model claims, that is a
finding we want to hear about: security@secretlyapp.com.

## What you will notice is missing

Icons, stickers, wallpapers and profile decoration are not in this repository —
their licences allow use inside the application but not redistribution as files.
The build generates empty placeholders for them. The application runs; some
decoration is blank. See `NOTICE`.
