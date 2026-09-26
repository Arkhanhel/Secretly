# Security Policy

## Reporting a vulnerability

Email **security@secretlyapp.com** with `SECURITY` in the subject line.

Please include:

- what the issue is and what an attacker gains from it;
- steps to reproduce, or the code path involved;
- affected version — the build number is shown in the app under
  Settings → Diagnostics;
- whether you intend to publish, and on what timeline.

If you prefer encrypted contact, say so in a first message without details and we
will exchange keys.

**Please do not open a public issue for security problems**, and please do not
test against our production servers in a way that affects other users. Rate-limit
your own testing.

## What to expect

| Stage | Timeline |
|---|---|
| Acknowledgement of your report | 3 working days |
| Initial assessment: severity, whether we can reproduce | 10 working days |
| Fix or mitigation for critical issues | as fast as we can; you will be told what is happening |
| Fix for other issues | within 90 days |
| Public disclosure | coordinated with you — by default once a fix has shipped, and no later than 90 days after your report unless we agree otherwise |

We are a very small team. If a deadline slips, you will hear from us before it
does, not after.

## Supported versions

We fix security issues in the current release on each platform and do not
backport. On 26 September 2026 that is Android 1.8.61, macOS 1.8.61 and
Windows 1.8.61; the App Store still serves iOS 1.8.39, with 1.8.61 in
TestFlight. [docs/VERIFY.md](docs/VERIFY.md) lists every released build with
its checksum and the git tag of its source.

## Scope

**In scope**

- The messaging client (Android, iOS, macOS, Windows).
- The keys server and relay server.
- Cryptographic protocol design and implementation.
- Anything that contradicts a claim made in
  [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).

**Out of scope**

- Denial of service against our infrastructure.
- Findings that require a rooted or already-compromised device.
- Social engineering of our team or users.
- Missing hardening headers on marketing pages.
- Known limitations already documented in the threat model — unless you can show
  the impact is worse than we described. That is a valid and welcome report.

## Known issues

We publish our own limitations rather than waiting for someone to find them.
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) §5 lists what we know is imperfect,
including areas we have not yet reviewed ourselves.

If your finding is in that list, it is still worth reporting when you can
demonstrate practical impact.

## Recognition

We will credit you by the name or handle you choose, in the release notes of the
fix and in this repository, unless you prefer to stay anonymous.

We do not run a paid bug bounty — the project has no funding for one. We will not
pretend otherwise.

## Regulatory reporting (EU)

We follow the reporting timelines of the EU Cyber Resilience Act. For an
actively exploited vulnerability or a severe incident affecting Secretly, we
notify through ENISA's Single Reporting Platform, with CERT.LV as the
coordinating CSIRT: an early warning within 24 hours of becoming aware of it, a
notification within 72 hours, and a final report within 14 days after a fix is
available (within a month for an incident). We tell affected users as well.

## Our commitments

- We will not threaten legal action against good-faith security research.
- We will not ask you to stay silent indefinitely. If we cannot fix something, we
  will say so and you are free to publish.
- We will tell users when a vulnerability affected them, including when it is
  embarrassing for us.
