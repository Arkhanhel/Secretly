# Known issues

What is wrong with Secretly right now, in our own words, before anyone else
finds it.

The threat model ([`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md)) says what the
system does and does not protect. This file is narrower and more practical: it
lists open defects and shortcuts, who is affected, and when we expect to fix
them. It exists because an auditor's first question is not "what did you build"
but "what do you already know is broken" — and the honest answer to that is
worth more than a clean-looking page.

Last updated: 8 October 2026. Entries are removed when the fix reaches
people, not when the code is written.

---

## Encryption and protocol

### Group call encryption is still rolling out

From 1.8.66 group calls can be end-to-end encrypted: each participant encrypts
their own frames with a key that only the other participants' devices receive.
A call shows a lock when this is on. Until the rollout finishes, some calls are
still created without it, and anyone on an older version can only join those.
Such a call is labelled "Not end-to-end encrypted": treat it as a call over a
server you have to trust. One-to-one calls are unaffected.

Limits of the first version:

- Up to 20 participants per encrypted call.
- A late joiner receives each sender's current key, so they could decrypt
  media from earlier in the call if someone had recorded it. Our media server
  does not record calls. A fresh key on every join is planned.
- There is no replay protection for frames within a track: the server can
  resend a frame it has already forwarded.
- Screen sharing from an iPhone is not available in encrypted calls yet.
- Who is in a call is decided by the relay (see "Room membership is decided by
  the relay" below). An added device shows up as a tile, and gets the keys
  only if it is listed among that member's devices.
- The servers still see call metadata: who is in the call and when, IP
  addresses, packet sizes and timing, and who is speaking. Threat model §3.5.

**Fix:** a fresh key on join and a higher participant limit after measuring
key setup on phones; making encryption required for all new calls once older
versions are gone.

### A legacy handshake still opens sessions without a signature

Since version 1.8.58 the device that starts a conversation signs the handshake,
and a device that has signed once cannot be impersonated by our server. An older
wire format has no such check, so a malicious server can still present a first
message "from" any device id — including one of your own computers. It cannot
read the replies, which use the current format.

**Fix:** a coming phone release refuses new sessions in the old format. It is
switched on from the server in stages, so that nobody still on an old version
loses delivery overnight.

### Unsigned handshakes from older builds are still accepted

The check only refuses a device that has already proven it signs. A contact who
has not updated can therefore still be impersonated. This closes as people
update, and fully only when unsigned handshakes are refused for everyone —
a change that breaks delivery for anyone left behind, so it waits on the
rollout numbers. Threat model §5.10.

### Linking a computer trusts the key the server hands out

When you link a desktop app by QR code, the phone encrypts the account to the
computer's key as served by our key server. Since 1.8.62 (build 635) the QR
code carries the computer's key fingerprint, and the phone checks it before
anything is sent. A phone on an older version still trusts the key the server
hands out, so a malicious server could substitute a computer of its own when
linking from such a phone.

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
whom; one-to-one call sessions; who takes part in group calls and when. A
private topic is a room of its own, so its name, its members and the room it
belongs to are visible like any room's; the names of ordinary topics travel
end-to-end encrypted. Sender display names and group titles travel
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
notification extension can use it. Moving it into the keychain is planned; it
needs testing on devices first, because a mistake there would stop
notifications from being decrypted in the background.

### The duress code is not deniable against forensics

From 1.8.66 a second app-lock code can open a separate, empty profile. The
real profile's database, files and secrets stay on the device under a
different namespace; the decoy cannot reach them. Anyone who can read the
device's storage directly (a forensic extraction, a rooted or jailbroken
device) can see that two profiles exist, and that two lock records exist. The
feature protects against a casual check of the unlocked phone, not against a
laboratory. Both codes take the same time to check, so timing does not reveal
the second one.

**Fix:** hidden-volume style storage, where the real profile is
indistinguishable from free space, is a separate project and is not planned
for this release.

### Message files carry only what is already encrypted

A `.secretly` file holds messages that were already encrypted for the
contact's devices. A message to a device that has never been in contact with
yours cannot be written into a file, because starting a session needs the
key server. Messages for the contact's other devices are in the file too and
are skipped on import; the file's signature proves which device made it, not
who the person is — that comes from the end-to-end session as usual.

### Social recovery trusts the people you choose

Guardians, acting together in the number you set, can restore your profile
without you. A person who obtains your recovery code can try to persuade them;
the four check words and the instruction to confirm by voice are the only
defence — there is no technical one. Recovery restores your identity, not your
message history: history comes back only from a safe backup. Guardians hold
their part inside the app's database; a guardian who loses their phone
without a backup loses the part, and you need to pick a replacement.

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

### FFmpeg ships under the GPL on desktop

Since 1.8.64 the iOS and Android apps ship the LGPL build of FFmpegKit, and video
is encoded by the system H.264 encoder. The macOS and Windows apps still bundle
the `full-gpl` build, which includes x264, so FFmpeg as shipped on desktop is
under the GPL, not the LGPL. Our own code stays
AGPL-3.0, and the two are compatible, but this blocks the commercial licence and
sits badly with app-store distribution. An earlier version of `NOTICE` claimed
the GPL build was not used; that claim was wrong and was corrected on
26 September 2026.

**Fix:** the same LGPL build on desktop, with the platforms' own hardware video
encoders, as already done on the phones.

### Builds are not reproducible

Two people building the same source do not get identical binaries. Store builds
additionally cannot be byte-compared with what you install, because Apple and
Google re-sign and re-package them. What can be checked today, and how, is in
[`docs/VERIFY.md`](docs/VERIFY.md).

### Android needs Google services

Firebase Cloud Messaging is required for message delivery on Android; ML Kit
backs optional translation and the sticker cutout. There is no build without
them, which is also why the app is not on F-Droid.

---

## How to report something that is not here

[`SECURITY.md`](SECURITY.md) has the process and the timelines. If a finding is
already listed above, it is still worth reporting when you can show the impact
is worse than we describe.
