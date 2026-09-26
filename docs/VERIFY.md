# Verifying a Secretly build

This page exists so that a claim we make about our software can be checked by
someone who does not trust us. It is also honest about what cannot be checked
yet, because a verification page that overstates what it proves is worse than
no page at all.

Last updated: 26 September 2026.

---

## 1. What you can verify today

### Rebuild the client from source

Almost everything needed to produce a build equivalent to the one in the stores
is public: the source, the pinned toolchains and the compile-time values below.
The one exception is our GIPHY API key.

| Input | Value |
|---|---|
| Source | https://github.com/Arkhanhel/Secretly |
| Flutter | `3.41.7` — pinned in `.flutter-version` |
| Rust | `1.93.1` — pinned in `rust-toolchain.toml` |
| Java (Android) | 17, Temurin |
| Dependency versions | frozen in `pubspec.lock` and `Cargo.lock` |

Compile-time values that decide which servers the app trusts — all four are
public by nature, and the last one is the **public** half of the key that signs
our configuration endpoint:

```
--dart-define=SECRETLY_KEYS_BASE_URL=https://keys.secretlyapp.com
--dart-define=SECRETLY_RELAY_HTTP_BASE_URL=https://relay.secretlyapp.com
--dart-define=SECRETLY_RELAY_WS_URL=wss://relay.secretlyapp.com/ws
--dart-define=SECRETLY_CONFIG_PUBLIC_KEY_B64=hMHcn5pjtUYmlbZziWlPWNxJJKOE7WlNadebVxF+cdk=
```

Store builds also set values that do not touch the security path: the version
and build number (`SECRETLY_APP_VERSION`, `SECRETLY_APP_BUILD_NUMBER`), a build
marker, fallback addresses of our own hosts for when DNS fails
(`SECRETLY_HTTP_DNS_FALLBACKS`, with the WebSocket fallback switched on),
`SECRETLY_ROOM_SENDER_KEY=true`, and, when a rollout needs it, a
feature flag such as `SECRETLY_PREKEY_UNTIL_CONFIRMED`. One value is private:
`GIPHY_API_KEY`. A rebuild therefore differs from ours at least in that string.

Full instructions: [`docs/BUILD.md`](BUILD.md).

### Check what the application talks to

Run the client you built against your own network capture. In normal use it
reaches:

- `keys.secretlyapp.com` and `relay.secretlyapp.com` — the two servers above;
  the relay host also runs our TURN/STUN server and, under `/livekit`, the media
  server for group calls;
- Apple (APNs) or Google (Firebase Cloud Messaging) for push notifications;
- `updates.secretlyapp.com` — desktop updates only.

Optional features reach third parties, and only when you use them:
`fonts.gstatic.com` (animated emoji), `api.giphy.com` (GIF search),
`huggingface.co` (the speech-recognition model, checked against a fixed
SHA-256), Google's model manager (translation models), the operating system's
speech recognition (dictation), websites whose links you send (link previews
are built on the sender's device), and the App Store or Google Play for
purchases.

There is no analytics SDK, no crash reporter that leaves the device by default,
and no third-party telemetry — and you do not have to take our word for it,
because the network layer is in `apps/flutter/secretly_app/lib/transport/`.

### Check the claims in the threat model

[`docs/THREAT_MODEL.md`](THREAT_MODEL.md) §7 lists each security claim next to
the file and symbol that implements it, so a reviewer can go straight to the
code rather than search for it. §5 lists what we know is imperfect.

---

## 2. Artefacts we published or uploaded

SHA-256 sums of the exact files we published ourselves or handed to Apple and
Google, with the git tag of the source each was built from.

| Release | Platform | File | Date | SHA-256 | Source |
|---|---|---|---|---|---|
| 1.8.61 (631) | Android | `secretly-production-1.8.61-631-store631.aab` | 2026-09-26 | `ad87f9c8e649d7c51b69505ab943b390ac1fb31b73cfe624f0ca45bcc466e7ec` | `v1.8.61-631-android` |
| 1.8.61 (631) | Windows | `Secretly-1.8.61-631-windows-x64.zip` | 2026-09-26 | `5e29c8936dde8f04e4b3444407f0907a84b2baf6793f99f89c2c957c35fc4347` | `v1.8.61-631-windows` |
| 1.8.61 (630) | macOS | `Secretly-1.8.61-630.dmg` | 2026-09-25 | `bc21172346b41af4d6ba4c199f47357dda297b711ce9fc0132504ca7fbaaf26d` | `v1.8.61-630` |
| 1.8.61 (630) | Windows | `Secretly-1.8.61-630-windows-x64.zip` | 2026-09-25 | `7465e38bfbc7853750c3ace547adeaf8e0a82f0f4e84fbbd634ee9e73bf4a2e4` | `v1.8.61-630` |
| 1.8.61 (630) | iOS | `secretly-production-1.8.61-630-store630.ipa` | 2026-09-26 | `50ad5814edc362c848bd907645719d40ebb7e9d45b823e7afc28ccbc039ffbea` | `v1.8.61-630` |
| 1.8.39 (588) | Android | `secretly-production-1.8.39-588-store588.aab` | 2026-09-05 | `0441577c7ee0161acfcba4d4c40d90b5eedbf96395a7f05c8de0eff8dd57e31a` | — |
| 1.8.39 (588) | iOS | `secretly-production-1.8.39-588-store588.ipa` | 2026-09-05 | `049d83a97a81090d5b983f4e45a2884bfaf91b875e4eea8bd96de412de146f15` | — |

What is where on 26 September 2026: Google Play serves 1.8.61 (631); the App
Store still serves 1.8.39 (588), with 1.8.61 (630) in TestFlight; the desktop
apps update themselves to macOS 1.8.61 (630) and Windows 1.8.61 (631).

**Desktop files come straight from us**, from `updates.secretlyapp.com`, so the
file you download is byte-for-byte the file listed above. Compute its SHA-256 —
`shasum -a 256` on macOS, `certutil -hashfile <file> SHA256` on Windows — and
compare. A match proves you received exactly what we published; it does not yet
prove that file was built from the tagged source (see §3).

**Read this before you compare a store build with what you installed.**

For Android and iOS you will not get a match, and that is not a sign of
tampering:

- **Google Play** does not distribute our file. An Android App Bundle is split
  by Google into per-device APKs and **re-signed with Google's key** under Play
  App Signing. What lands on your phone has a different hash by design.
- **Apple** re-signs and re-packages the IPA during distribution, and encrypts
  the main binary per account. A byte comparison is not possible at all.

So these sums prove one narrow thing: that the file we uploaded on that date is
the file whose hash is printed here, and that we have not quietly swapped it
since. They do not prove that your installed copy came from our source. Nobody
who ships through those stores can prove that, and projects that publish store
checksums without saying so are describing a check that does not work.

---

## 3. What is missing, and when it will be here

**A directly downloadable, signed APK with a published checksum.** This is the
one artefact that makes verification real: you download it from our site,
compute its SHA-256, compare it with the value published here, and check the
signing certificate fingerprint. No store stands in the middle.

It does not exist yet. Until it does, the honest summary is: *you can rebuild
our client from source and inspect what it does; you cannot byte-compare the
copy you installed from a store.*

Planned, in this order:

1. A signed APK on the download page, with its SHA-256 and the signing
   certificate fingerprint listed here.
2. ~~A git tag per release~~ — done from 1.8.61 (630) on: each row above points
   at the exact source it was built from. Builds 588 and earlier predate the
   repository going public and have no public tag — we are not going to invent
   one retroactively.
3. Reproducible builds, so that two people building the same tag with the same
   pinned toolchain get byte-identical output. This is hard on Flutter and we
   are not promising a date.

---

## 4. If something does not match

If you rebuild from source and find behaviour that contradicts anything in the
threat model or on this page, that is a finding and we want it:
**security@secretlyapp.com**, `SECURITY` in the subject. See
[`SECURITY.md`](../SECURITY.md) for what to expect and by when.

We will publish the correction, including when it is embarrassing for us.
