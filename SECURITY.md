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
| Public disclosure | coordinated with you |

We are a very small team. If a deadline slips, you will hear from us before it
does, not after.

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

## Our commitments

- We will not threaten legal action against good-faith security research.
- We will not ask you to stay silent indefinitely. If we cannot fix something, we
  will say so and you are free to publish.
- We will tell users when a vulnerability affected them, including when it is
  embarrassing for us.
