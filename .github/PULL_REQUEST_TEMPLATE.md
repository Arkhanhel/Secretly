<!--
  Thank you for the work. A few things make review much faster.
  If this is your first pull request here, read CONTRIBUTING.md first — a
  contributor agreement (../CLA.md) is needed before a change can be merged.
-->

## What this changes

<!-- One or two sentences. What is different after this is merged? -->

## Why

<!-- The problem being solved. Link an issue if there is one. -->

## How it was tested

<!--
  Which tests you added or ran, and on what.
  For a fix: how you confirmed the test fails without your change. We hold a
  rule that a guard test must be able to fail — if it passes on broken code, it
  guards nothing.
-->

## Checklist

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes — the whole suite, not only the file I touched
- [ ] `cargo test --workspace` passes, if I touched a server
- [ ] New source files carry the SPDX header (three lines, see any existing file)
- [ ] I formatted only the lines I touched — running `dart format` over the tree
      produces a very large unrelated diff
- [ ] I have signed the [CLA](../CLA.md), or I am doing so in a comment below

## Cryptography

- [ ] This change does not touch `apps/flutter/secretly_app/lib/ratchet/`,
      `.../lib/security/` or the key handling in `server/keys`

<!--
  If it does, describe what property of the protocol changes and why it is
  still sound. Cosmetic changes in those directories are not accepted, and a
  second ratchet implementation is never accepted — two implementations
  disagreeing is worse than one implementation's flaws.
-->

## Anything a reviewer should know

<!-- Trade-offs, things you were unsure about, parts you would like a second
     opinion on. "I do not know" is a useful answer here. -->
