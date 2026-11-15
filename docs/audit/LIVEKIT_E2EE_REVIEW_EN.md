# Where end-to-end encryption can quietly stop working in LiveKit's Flutter client

A review of the frame-encryption path in `livekit_client` for Flutter and in the
native frame cryptor it relies on (`flutter_webrtc`), written while building
encrypted group calls for [Secretly](https://secretlyapp.com).

The failure mode we care about is the dangerous kind: the call keeps working,
the lock stays on screen, and media goes out unencrypted anyway. Every item
below is a place where that can happen, with the code location that causes it.

| | |
|---|---|
| Versions reviewed | `livekit_client` **2.13.1** and `flutter_webrtc` **1.6.2+hotfix.4** — current releases on 13 October 2026. Earlier findings were made against 2.4.0 and 0.12.12, and each was re-checked against the current source. |
| Verdicts | Every "fixed" and "still present" below is backed by code read in the current release, with a file and line. A changelog entry alone was never accepted as evidence. |
| Native layer | The prebuilt libwebrtc binaries (m150) are not in the source tree. Findings that depend on them are marked as such rather than guessed. |
| Filed upstream | Not yet. §5 lists what we intend to file. |

`LK` below is `livekit_client-2.13.1/lib/src`, `FW` is
`flutter_webrtc-1.6.2+hotfix.4`.

---

## 1. Why we looked, and what we did with the answer

We needed group calls the media server cannot listen to. LiveKit offers that
through its encryption manager: one room-level switch, and the SDK attaches a
frame cryptor to every sender and receiver.

We read that path before trusting it, and decided not to use it. Secretly
creates the LiveKit room without the encryption manager and drives the native
frame cryptor itself, with its own key distribution over the messaging
protocol's end-to-end sessions. The reasons are below: too many of the paths
that attach a cryptor are asynchronous, best-effort, or decided by the server's
answer, and a failure on any of them is silent. That decision is the part most
useful to other projects.

## 2. Still present in the current release

### 2.1 A second, unencrypted sender for the camera — **critical**

With dynacast on, a server message listing a codec the publisher does not use
makes the client publish an additional codec. `publishAdditionalCodecForPublication`
(`LK/participant/local.dart:958-1042`) adds a new sender with no cryptor; its
add-track request carries no encryption field (`:1011-1030`); and it emits no
event the encryption manager listens to. The camera then goes out twice: once
encrypted, once not, while the app shows the call as encrypted.

The setting meant to prevent this does nothing. The "disable backup codec when
encrypted" option (`LK/core/room.dart:305-312`) gates a branch at
`local.dart:987-990` that is never reached, because `computeTrackBackupEncodings`
(`LK/utils.dart:545-559`) never returns null.

*A common misreading:* the JavaScript SDK stopped publishing a backup codec
under encryption in its 1.15.3 release, and a 2.11.0 Flutter changelog line
mentions the backup codec's sender. Neither is a fix for this path in the
Flutter client: the 2.11.0 line is about video degradation preference.

### 2.2 The server can now switch dynacast on — **critical, new in 2.13**

New code lets the server override the publisher's codec: if the codec requested
by the app is not in the server's `enabledPublishCodecs`, the client takes the
server's first codec (`LK/participant/local.dart:297-306`). If that codec is VP9
or AV1, the client then turns dynacast on for the **whole room**
(`:310-314`), overriding the application's own `dynacast: false`.

This defeats the usual application-level defence against §2.1. An application
that turned dynacast off precisely to avoid the unencrypted backup sender no
longer controls that setting; a server — misconfigured or hostile — does.

**What we do:** after publishing, we read the room's effective dynacast setting
and, if the server has switched it on, we unpublish and end the encrypted call.
We also reject VP9 and AV1 publications outright.

### 2.3 The server decides whether your own track is encrypted — **high**

The client requests AES-GCM for its own track, but whether a cryptor is attached
is decided from the server's reply (`LK/publication/track_publication.dart:61-64`).
An encryption value the client does not recognise is mapped to "none"
(`LK/extensions.dart:227-232`) — a default that fails open. Tracks labelled AV1
are never encrypted (`LK/e2ee/e2ee_manager.dart:51-52`), and with §2.2 the
server can choose that label.

VP9 is now encrypted; that part is fixed (`e2ee_manager.dart:51-52, 89`).

### 2.4 The cryptor is attached after negotiation — **high**

The sender's cryptor is created in an asynchronous handler after the publication
event, which fires after negotiation and after capture has started
(`LK/participant/local.dart:251` for audio, `:556` for video). Negotiation is not
awaited (`LK/core/engine.dart:349-355`). A full reconnect republishes every track
the same way (`local.dart:645-659`). The first frames can leave before the
cryptor exists; how many depends on timing and needs measuring.

### 2.5 An exception leaves a track with no cryptor — **high**

The encryption manager's handlers are asynchronous, and a thrown exception
inside them — a null sender or receiver, a platform error rethrown at
`FW/lib/src/native/frame_cryptor_impl.dart:165-166, 191-192` — leaves the track
running with no cryptor. Nothing catches it (`LK/managers/event.dart:171-195`).

One trigger is a plain crash: `mimeType.split('/')[1]`
(`e2ee_manager.dart:88`) throws `RangeError` on a track whose mime type has no
slash, so no cryptor is ever created for it.

### 2.6 The receiver plays what it never decrypted — **medium (integrity)**

A remote track labelled "none" plays without a decryptor
(`e2ee_manager.dart:89-92`). Frames that arrive before the decryptor is attached
are decoded and played; the remote track starts before the asynchronous handler
runs (`LK/participant/remote.dart:248-256`, with a new pending queue at
`room.dart:712-760`). Frames ending in configured "magic bytes" pass undecrypted,
and the server supplies its own trailer (`key_provider.dart:22, 82`;
`room.dart:585-587`). This is an integrity problem — a server can inject media —
rather than a confidentiality one.

### 2.7 The readiness signal can be lost — **medium**

The encryption manager attaches its state handler after two awaited platform
calls (`e2ee_manager.dart:64, 101`, after `:166-168` and `:184-186`), and
`FrameCryptorImpl` drops events while no callback is set
(`FW/lib/src/native/frame_cryptor_impl.dart:260`). An application that waits for
"ok" before unmuting can wait forever.

### 2.8 Stale cryptors and keys — **medium**

Republishing sends no unpublish events (`local.dart:645-659`), the key index is
looked up by first match (`e2ee_manager.dart:218-226`), and the key provider is
never disposed anywhere in the library, so key material lives in native memory
for the life of the process.

### 2.9 One key for everything a participant sends — **low**

One key covers all of a participant's tracks and, now, their data packets as
well (`e2ee_manager.dart:124-127, 159-168, 177-186`).

## 3. Fixed since 2.4.0

| Finding | Where it is fixed |
|---|---|
| Key material logged in base64 at INFO by `_setKey`, and printed by `ratchetKey` | `LK/e2ee/key_provider.dart:144` now logs only participant and index; `e2ee_manager.dart:133-139` |
| `discardFrameWhenCryptorNotReady` dropped by `BaseKeyProvider.create` | `key_provider.dart:85`, and carried through to all three native plugins |
| VP9 tracks bypassing the cryptor | `e2ee_manager.dart:51-52, 89` |
| On iOS and macOS, a cryptor state event fired before the Dart listener attached was **discarded** | `FW/common/darwin/Classes/FlutterRTCFrameCryptor.m:41-55, 650-657` now buffers it, as Android already did |

The last fix matters beyond LiveKit. An application that, like ours, keeps a
track muted until the cryptor reports ready will see that report on Android but
can miss it on iOS and macOS with older `flutter_webrtc` — and stay silent. We
believe this caused a "no audio, microphone never activates" failure we saw only
on iPhone; it is being verified on devices.

## 4. Native layer: not re-verifiable from source

These rest on disassembly of the shipped binaries and need the libwebrtc m150
source (`api/crypto/frame_crypto_transformer.*`, and the Objective-C, JNI and
C++ wrappers) to confirm or withdraw:

- the C++ copy constructor of the key provider options losing the "discard"
  flag (the old wrapper header omits it; the m150 header is not available
  locally);
- an INFO-level log line containing the raw key, salt and derived key. This
  matters more now: `flutter_webrtc` 1.6 added a public switch,
  `Helper.setLogger` (`FW/lib/src/helper.dart:32-34`), that routes native logs
  into Dart. It is off by default; an application that turns it on during an
  encrypted call may write keys to its own logs;
- PBKDF2 with 100 000 iterations in `setKey` on the platform thread (the
  synchronous call itself is confirmed in source:
  `FlutterWebRTCPlugin.java:134-135`, `FlutterWebRTCPlugin.m:233-235`);
- the unencrypted first byte of Opus payloads, events emitted only on state
  change, and IV construction.

One earlier claim of ours — that the Windows plugin truncates the key provider
options — **did not hold** against the binary and is withdrawn. Two small
Windows issues remain in source: no key-provider null check on the receiver
branch (`flutter_frame_cryptor.cc:201-205`) and an unlocked event queue
(`flutter_common.cc:149-157, 193-201`).

## 5. What we intend to file, and how

To `livekit/client-sdk-flutter`, one issue each, with a minimal reproduction
against a local SFU:

1. Unencrypted backup-codec sender, and the ineffective setting meant to prevent
   it (§2.1).
2. Server-forced dynacast through the codec fallback (§2.2).
3. Encryption of the publisher's own track decided by the server, with an
   unknown value failing open (§2.3).
4. Cryptor attached after negotiation (§2.4).
5. Exceptions in the asynchronous handlers, including the `RangeError` (§2.5).
6. Lost readiness signal (§2.7).
7. Stale cryptors and an undisposed key provider (§2.8).

And §2.6 as one design question rather than a bug. To `flutter-webrtc`: the two
small Windows issues in §4. Before filing §2.4 we will measure how many frames
actually leave unencrypted, so the report states a number, not a possibility.

We will offer the checks we run in our own CI with each report. They assert
that the room is created without the encryption manager, that media is
published muted and unmuted only after the cryptor reports ready, that VP9 and
AV1 are rejected, that a server-switched dynacast ends the call, and that no
native logging switch is ever called.

## 6. Licence and contact

This document is released under CC BY 4.0. Our implementation is AGPL-3.0; the
transport library extracted from the same work is MPL-2.0.

Security contact: security@secretlyapp.com. These findings concern a
third-party library, not Secretly's own protocol; for the latter see
`docs/THREAT_MODEL.md`.
