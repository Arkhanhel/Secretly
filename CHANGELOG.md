# Changelog

Notable changes to Secretly. Dates are the day the change reached a published
build, not the day it was written.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow the scheme `MAJOR.MINOR.PATCH+BUILD`, where the build number is
what the app stores show.

---

## [Unreleased]

Planned as 1.8.67 for iOS, Android, macOS and Windows. Version 1.8.66
(build 654) was prepared but never published, so its changes are listed here
too. Nothing listed here has reached a published build yet; the section gets
its version and date on release day.

### Security
- Group calls: end-to-end encryption. Each participant encrypts their own
  audio and video frames (AES-128-GCM, WebRTC frame encryption) with a random
  key that is sent to the other participants' devices over the same
  end-to-end sessions as messages. The media server forwards frames it cannot
  decrypt. Up to 20 participants per encrypted call. The key changes when
  someone leaves, is removed or is banned. A lock in the call shows that
  encryption is on; a call without it is labelled "Not end-to-end encrypted".
- The rollout is gradual: while it lasts, a signed server setting decides
  what share of new calls is created encrypted, and older versions can only
  join calls without encryption. A running encrypted call cannot be switched
  to an unencrypted one.
- Group calls: if the server tries to switch on adaptive video layers
  (dynacast) during an encrypted call, the call now ends instead of continuing.
  The updated LiveKit client accepts that switch from the server, and with it on
  the server could ask for a second copy of the camera stream that would leave
  without encryption. A server can still make an encrypted call fail; it cannot
  make it continue unencrypted.
- Duress code: setting it up now has its own screen and explanation. It used to
  reuse the app-password screen, so it looked exactly like changing your real
  password.
- Group calls: the server can no longer switch on a participant's
  microphone, camera or screen sharing. Signals from the server can only
  switch them off; turning them on is always a local action of the user.
  This applies to all group calls, encrypted or not.

- Photos and videos: location and other metadata are now removed before
  sending from JPEG, PNG, WebP, GIF, HEIC/HEIF/AVIF and MP4/MOV, without
  re-encoding (orientation and colour profile are kept). Before, only the
  first EXIF block of JPEG files up to 24 MB was cleaned. A file that cannot
  be cleaned is re-encoded; if that fails too, it is not sent and the reason is
  shown. "Send as file" still sends the original.
- Android: a failed read from the device keystore no longer deletes the
  profile secret, the auto-backup password, the app-lock secret or the support
  key. Temporary errors are retried. If the app-lock secret cannot be read,
  the lock stays locked instead of turning itself off.
- Server responses that decide whose keys a message is encrypted to are now
  signed by the server and checked by the app. Refusing an unsigned or wrong
  response is rolled out gradually by a signed server setting; a banner says
  when a response failed the check.
- Prekeys: signed prekeys carry an id and can be rotated (off by default);
  the server keeps at most 200 one-time keys per device.
- Builds now trust a second, prepared config-signing key, so the server's key
  can be replaced later without older builds losing trust in their settings.
- Call relay (TURN) usernames no longer contain the device ID.
- Rooms: a message from a sender the device cannot identify is held back
  instead of accepted; a room key is sent on request only to members and your
  own devices. Calls: signals for a running call are accepted only from the
  other participant and your own devices, and their age is judged by server
  time, not the phone's clock.
- In the build but off until a signed server setting switches them on:
  message length padding (also for room broadcasts), and disappearing
  messages that are removed on both sides.

### Added
- Duress code (phones): a second app-lock code that opens a separate, empty
  profile instead of yours. The real profile stays on the device, invisible
  from the decoy; optionally the second code erases the real profile first.
  Failed unlock attempts now back off (5 s after 3, up to 5 minutes after 9),
  and an optional limit erases everything after 10 failed attempts. Both
  codes are checked with the same amount of work, so timing does not reveal
  whether a second code exists. Limits: this protects against a "show me
  your phone" check, not against device forensics; biometrics always open
  the real profile; to return from the decoy, relaunch the app and enter the
  real code.
- Social recovery: choose 2 to 5 guardians among your contacts and how many
  of them are needed (at least 2). Your identity — the same contents as the
  recovery kit, including the account identity key — is encrypted with a
  random key, and that key is split between the guardians (Shamir's scheme);
  fewer guardians than the threshold learn nothing. On a new phone you show
  a code with four check words; each guardian confirms the words with you by
  voice and sends their part. When enough parts arrive, the app restores
  your profile; contacts see no safety-number change.
- Calls under censorship: when the app reaches the servers through a mirror,
  CDN, proxy, SOCKS or Tor, one-to-one calls go only through the server and,
  where the server offers it, only through TURN over TLS on port 443 — no
  direct connection and no plain UDP that would give the call away. Group
  calls do the same, but only where the server offers TURN over TLS on 443:
  with nothing to fall back to, forbidding a direct connection would end the
  call for everyone in it rather than protect them.
- Messages without network: Settings → Network → "Send without network"
  writes your end-to-end encrypted messages to a contact from the last week
  into a `.secretly` file, signed with your device key; carry it any way you
  like. The recipient opens it, and the messages go through the usual
  receive path — same decryption, de-duplication and receipts. Only
  messages already encrypted for that contact can travel this way. Such a
  file can also be opened from another app: on Android through "Share →
  Secretly", on iOS through "Open in". Opening a file directly from a file
  manager works only where the manager reports the file's own type; from
  Settings → Network → "Open a message file" it always works.
- A lightweight Android build, distributed as a direct APK outside Google
  Play: 73 MiB instead of 136, or 65 MiB for older 32-bit phones. It leaves
  out on-device translation, voice transcription and video processing, and
  fetches decorative profile icons and chat wallpapers only when they are
  shown. Nothing about security changes, and QR scanning stays — without it a
  device cannot be linked. Each fetched file is verified against a hash that
  ships inside the signed package.
- Network screen (phones): one tap points Secretly at Orbot, so traffic can
  go through Tor where Tor itself is reachable. Secretly cannot tell whether
  Orbot is running, so the screen says plainly that you install and start it
  yourself.
- Private topics in rooms: a topic with its own member list, chosen from the
  room's members, and its own room key, so its messages reach only those
  members. Up to 20 per room. Room admins decide whether members may create
  them. Leaving or being removed from the room also removes you from its
  private topics.

- Stickers: a pack can be closed or open, chosen when it is created. A
  closed pack is shared only by its author; recipients see a lock.
- Server backup: you can delete your backup from the server. A wrong password
  and a temporary lock are explained in words, with the time the lock ends;
  repeated guesses lock only the guesser's network, not your profile.
- Settings on the phone and the desktop are regrouped, with short
  explanations and a "How it works" page for the network settings.
- Profile frames and covers: the old ones are redrawn as live scenes, and
  there is a new exclusive collection. Six frames and four covers are free;
  the rest are Premium.
- Translation: the translate button explains why a translation failed.

### Fixed
- The recovery kit and the safe backup now carry the account identity key.
  Restoring from either used to create a new one, so every contact saw
  "safety number changed" after a restore and a pinned key no longer matched.
  Kits and backups created by older versions restore as before, without the
  key.
- Room topics created on one device now reach every member, including people
  who join later. Messages sent in a topic no longer land in the main thread
  for members whose app did not know the topic.
- A room message that did not reach a member is sent to them again, once, as
  the same sealed ciphertext. Only messages sent after the member joined and
  within the last 3 days are resent; messages deleted for everyone are not.
- Android: a background pass that ran out of time could hold up decryption of
  incoming messages for up to 2 minutes. In a group call this delayed the
  call keys, so the other participants could not be heard.
- Android: a background fetch no longer closes the database under the
  running app.
- Android: a group call now runs as a foreground service, so it keeps going
  with the screen off; "Hang up" in the notification leaves the call.
- Windows: the app no longer crashes during calls.
- Desktop: the "Synced" indicator no longer flickers after a restart; the
  wallpaper is laid out as on the phone; the Windows installer refreshes the
  icon cache, so shortcuts show the new icon.
- Desktop: the app lock also covers the photo, video and file viewer windows.

- Backups: when a backup cannot be created, the reason is shown in plain
  words with a button to set the backup password; uploads run one at a time
  instead of twice at once; a backup made by a newer version can be restored;
  the first automatic backup no longer overwrites a full backup on the server
  with an empty one.
- Notifications: tapping a notification while the app is closed opens the
  chat (Android and iPhone).
- Calls: picture-in-picture on Android no longer collapses back when opened;
  on iPhone it shows the contact card instead of a grey window, works on
  iOS 27, and the camera turns off while a video call is minimised.
- iPhone: the local proxy used in blocked networks is restarted when the
  system closes its socket; messages could stop arriving.
- Rooms: mute, pin and archive settings of a room are no longer reset.
- Disappearing messages: a timer change dated in the future is capped.

### Changed
- Calls: the media stack is updated to LiveKit 2.13.1 and WebRTC m150 on every
  platform. One change in it matters for encryption: on iPhone and Mac, a
  signal that the frame encryptor is ready could be lost if it arrived a moment
  too early, and since an encrypted call keeps audio off until that signal
  arrives, the call could stay silent. That signal is now held until the app is
  listening. This is being verified on devices before release.
- Phone: the group call screen is simpler. Encryption is shown by a lock in
  the top bar, participant status by icons, and there is one Join button.
- Desktop: calls, the mini call window and the photo, video and file viewers
  open as separate system windows; motion is smoother throughout the app.
- Desktop: animated decorations (live frames, emoji statuses, wallpaper
  drift) move while you use the window and pause 10 seconds after your last
  action. An idle window used about a quarter of a CPU core redrawing them;
  now it uses under 1 %.
- Large attachments are encrypted and decrypted off the main thread, so the
  app no longer freezes on big photos and videos.
- iPhone: the app uses the scene lifecycle (UIScene) that iOS 27 requires.

---

## [1.8.64] — 2026-10-05

Build 645 (iOS TestFlight, Android; macOS and Windows from 4–5 October).
Source: tag `v1.8.64-645`.

### Changed
- iOS and Android now ship the LGPL build of FFmpeg (FFmpegKit "full" variant,
  no x264 or other GPL components). Video is encoded by the system H.264
  encoder (MediaCodec on Android, VideoToolbox on iOS, with OpenH264 as the iOS
  fallback). The plugin is vendored in
  `apps/flutter/secretly_app/third_party/ffmpeg_kit_flutter_new` with its
  changes listed in `MODIFICATIONS.md`; the release scripts refuse a mobile
  package that contains a GPL build. The licenses screen on the phone lists
  FFmpeg under LGPL-3.0 with the license texts.

### Fixed
- Group calls: after "Leave", "End for everyone" or being removed, the call
  engine is released on the phone too, so the microphone no longer stays on.

### Security
- Linking a computer: when the computer's QR code carries its key but the
  server does not confirm it (or the request fails), the phone now refuses
  and sends nothing. QR codes from older computers without a key work as
  before.

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
