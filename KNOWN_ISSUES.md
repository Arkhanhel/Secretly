# Known issues

What is wrong with Secretly right now, in our own words, before anyone else
finds it.

The threat model ([`docs/THREAT_MODEL.md`](THREAT_MODEL.md)) says what the
system does and does not protect. This file is narrower and more practical: it
lists open defects and shortcuts, who is affected, and when we expect to fix
them. It exists because an auditor's first question is not "what did you build"
but "what do you already know is broken" — and the honest answer to that is
worth more than a clean-looking page.

Last updated: 26 September 2026. Entries are removed when the fix reaches
people, not when the code is written.

---

## Encryption and protocol

### Group calls are not end-to-end encrypted

Group calls go through our own LiveKit media server, which decodes them. Audio,
video and screen sharing are encrypted only between each device and that server,
so the operator could listen. One-to-one calls are unaffected: they are
end-to-end encrypted and travel directly between the two devices.

Until this ships, treat a group call as a call over a server you have to trust.

**Fix:** a key per participant, distributed over the existing end-to-end
channel; the server keeps only ciphertext. In development.

### A legacy handshake still opens sessions without a signature

Since version 1.8.58 the device that starts a conversation signs the handshake,
and a device that has signed once cannot be impersonated by our server. An older
wire format has no such check, so a malicious server can still present a first
message "from" any device id — including one of your own computers. It cannot
read the replies, which use the current format.

**Fix:** the next phone release refuses new sessions in the old format.

### Unsigned handshakes from older builds are still accepted

The check only refuses a device that has already proven it signs. A contact who
has not updated can therefore still be impersonated. This closes as people
update, and fully only when unsigned handshakes are refused for everyone —
a change that breaks delivery for anyone left behind, so it waits on the
rollout numbers. Threat model §5.10.

### Linking a computer trusts the key the server hands out

When you link a desktop app by QR code, the phone encrypts the account to the
computer's key as served by our key server. The fix — the computer's key
fingerprint inside the QR code, checked by the phone before anything is sent —
is in the code and reaches people with the next phone release. Until then a
malicious server could substitute a computer of its own during linking.

### Room membership is decided by the relay and is not signed

The server could add a member, or a device of a member, to a room; that member
then receives the room key. Such a member is visible in the member list, so this
is detectable rather than silent. Signed membership is grant work, not a
patch.

### One-time prekeys are not deleted after use

The private halves stay on the device, and the signed prekey is not rotated.
This weakens forward secrecy for a session that is re-established from an old
prekey. Scheduled.

### Attachments can be truncated

The attachment format has no end-of-file marker, and the decrypted size is not
compared with the size the sender announced. A server that drops the tail of a
file yields a shorter file rather than an error. Content that survives is still
authentic — each chunk is authenticated — but the file may be incomplete.

---

## Metadata

### The servers see more than routing

The full list is in the threat model (§5.2): room names, descriptions, avatars
and membership; who posted in a room and when; your profile as you publish it;
device build numbers and push tokens with notification preferences; who blocked
whom; one-to-one call sessions. Sender display names and group titles travel
beside the ciphertext so the relay can build a notification title, and reach
Apple or Google in that title unless you choose hidden previews.

We do not implement sealed sender or any mixing.

### Server backups are not encrypted at rest

Database backups sit on the same host as the servers, access-controlled but
unencrypted, kept about 14 days (the three most recent are kept regardless of
age). Encryption and an off-site copy are in progress. Backups made before
24 September 2026 may still contain notification previews from the period when
the relay stored them.

---

## Platforms

### iOS: the notification extension reads the device key outside the keychain

A copy of the device identity seed lives in the app group's settings so the
notification extension can use it. It moves into the keychain in the next
release.

### Media files are ordinary files

Sent and received attachments and voice transcripts are stored as regular files
protected by the operating system's storage encryption, not by the database key.
On iOS they are visible in the Files app and included in device backups; on
Windows they live in Documents, which OneDrive may sync. Being moved.

### Android storage has no integrity check

Secrets on Android are stored with AES-CBC through the platform keystore,
without an authentication tag. An attacker who can write to that store could
corrupt it undetectably. Planned (SEC-03); an earlier attempt was reverted
because it locked people out of their own keys.

### Auto-delete only covers your own devices

Messages older than the chosen period are removed from your devices. The other
side keeps their copy and sets their own timer. Downloaded files and voice
transcripts are not removed yet.

---

## Licensing and builds

### FFmpeg ships under the GPL

The app bundles the `full-gpl` build of FFmpegKit, which includes x264. FFmpeg
as shipped is therefore under the GPL, not the LGPL. Our own code stays
AGPL-3.0, and the two are compatible, but this blocks the commercial licence and
sits badly with app-store distribution. An earlier version of `NOTICE` claimed
the GPL build was not used; that claim was wrong and was corrected on
26 September 2026.

**Fix:** the LGPL build (`ffmpeg_kit_flutter_new_full`) with the platforms' own
hardware video encoders. The API is identical; the work is in retuning video
quality per platform and testing it on real devices.

### Builds are not reproducible

Two people building the same source do not get identical binaries. Store builds
additionally cannot be byte-compared with what you install, because Apple and
Google re-sign and re-package them. What can be checked today, and how, is in
[`docs/VERIFY.md`](VERIFY.md).

### Android needs Google services

Firebase Cloud Messaging is required for message delivery on Android; ML Kit
backs optional translation and the sticker cutout. There is no build without
them, which is also why the app is not on F-Droid.

---

## How to report something that is not here

[`SECURITY.md`](SECURITY.md) has the process and the timelines. If a finding is
already listed above, it is still worth reporting when you can show the impact
is worse than we describe.
