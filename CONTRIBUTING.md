# Contributing

Secretly is written and maintained by **Yurii Arkhanhelskyi**; the application
is published in the app stores by **SIA Secretly** (Valmiera, Latvia).

Everyone taking part is expected to follow our
[Code of Conduct](CODE_OF_CONDUCT.md).

Thank you for the interest. Here is what to know before your first change.

## 🔴 First, about rights

The project runs on an open-core model: the code is AGPL-3.0, and a commercial
licence is sold to organisations for which AGPL does not work. Revenue from
those licences is what keeps the project alive.

For that sale to be lawful, one party must hold sufficient rights to the whole
codebase. So with your first change we will ask you to sign a
[contributor agreement](CLA.md), granting the rights holder the right to use
your contribution, including in commercial builds.

**You keep your copyright and all your rights.** The agreement grants us a
permission; it does not take one away from you. You remain free to use your own
code anywhere. This is how the Apache Software Foundation, Element and Mattermost
work.

Signed once, it covers all your future changes.

If that condition does not suit you, say so before you spend time on code. We
will understand.

## Security — not through issues

Found a vulnerability? **Do not open a public issue.** The process is in
[SECURITY.md](SECURITY.md): email security@secretlyapp.com with `SECURITY` in
the subject.

This applies to anything that contradicts [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).

## What to know about the code

**Cryptography is not changed casually.** `apps/flutter/secretly_app/lib/ratchet/`
is the Double Ratchet
implementation. Any change there must come with an analysis of what it changes
in the protocol's properties. Cosmetic changes in that directory are not
accepted.

🔴 **Never create a second ratchet implementation.** Two implementations
disagreeing is worse than one implementation's flaws.

**A test must be able to fail.** We hold a rule: a guard test is validated by
breaking the code it guards. If the test still passes on broken code, it guards
nothing. Every security fix in this repository was checked that way.

**Assets are not in the repository.** Icons, stickers and profile decoration are
not published: their licences permit use in the application, not redistribution
as files. The build runs; some decoration will be empty. This is expected.

**Formatting.** The tree was formatted with an older Dart release, and running
`dart format` over it produces a very large unrelated diff. Format only the lines
you touched, or your change will be unreviewable.

## Before sending a change

```bash
cd apps/flutter/secretly_app
flutter analyze          # must be clean
flutter test             # the whole suite, not only your file
cd ../../..
cargo test --workspace   # if you touched a server
```

Use the pinned toolchains — Flutter `3.41.7`, Rust `1.93.1`. A different version
may produce an unrelated diff or a failure that is not yours.

Commit messages in Conventional Commits format, in English or Russian.

## What we will certainly accept

- A bug fix with a test that catches it.
- Documentation corrections, especially a mismatch between a document and the
  code. Those are the most valuable — we found one ourselves and it mattered
  more than half the bugs.
- A new interface translation.
- Accessibility improvements.

## What to discuss before writing code

- Changes to the protocol or the storage format.
- New dependencies, especially copyleft ones. 🔴 The FFmpeg package with the
  `-gpl` suffix cannot be used: it would make the commercial half of the model
  impossible, and that half funds the project.
- Large interface rework.

Open an issue describing the intent before you start. That way nobody spends a
week for nothing.
