#!/usr/bin/env bash
# Shared signing-identity selection for the macOS desktop scripts.
#
# Source it, then call `secretly_pick_sign_identity`; it echoes the identity to
# sign with, or nothing when there is none to be had.
#
# WHY THIS EXISTS AS ITS OWN FILE — the keychain prompt storm, twice.
#
# Secretly keeps its secrets in the macOS *login* keychain (the shared code
# sets `useDataProtectionKeyChain: false`). Items there carry an ACL that
# trusts a specific code signature. An **ad-hoc** signature is derived from the
# binary's own contents, so it changes on EVERY build — the ACL never matches
# the new binary, and macOS re-asks for every single item. There are ~12 of
# them (db passphrase, crypto key, per-profile secrets, per-device keys,
# entitlement state), which is why an ad-hoc build asks for the keychain
# password roughly ten times per launch and why "Always Allow" never sticks.
#
# `00d28fad` fixed that — but only in `desktop_release_macos.sh`. The DEBUG
# path (`desktop_fix_ffmpeg_deps.sh`, which re-signs the bundle after repairing
# the ffmpeg dependencies) kept signing ad-hoc, so the storm survived in the
# build developers actually run all day. Measured on a live account 08.09.2026:
# `startup.secrets_presence ms=28289` — twenty-eight seconds of a thirty-second
# boot spent waiting on keychain dialogs, plus `OSStatus error 13` at startup.
#
# One copy, sourced by both, so the next fix lands in both places.
#
# ENV
#   SECRETLY_SIGN_IDENTITY   Name it yourself; auto-selection is skipped.
#   SECRETLY_FORCE_ADHOC=1   Skip auto-selection and sign ad-hoc. Only to
#                            reproduce the old behaviour and its prompts.

# Echoes the chosen identity, or nothing. Never fails the caller.
secretly_pick_sign_identity() {
  local identity="${SECRETLY_SIGN_IDENTITY:-}"
  if [ -n "$identity" ]; then
    printf '%s' "$identity"
    return 0
  fi
  if [ -n "${SECRETLY_FORCE_ADHOC:-}" ]; then
    return 0
  fi

  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  # Preference order, most appropriate first. A developer machine often holds
  # certificates for unrelated accounts, so project-matching patterns come
  # before the generic ones — picking a stranger's certificate would still stop
  # the prompts, but it is not what anyone means by "sign the app".
  #   `find-identity` prints:  1) <sha1> "Apple Development: name (TEAMID)"
  local pattern candidate
  for pattern in \
      "Developer ID Application" \
      "Apple Development: secretly" \
      "Apple Distribution: Secretly" \
      "Apple Development"; do
    # `|| true` is load-bearing: grep exits 1 when a pattern does not match, and
    # under `set -euo pipefail` that status propagates out of the command
    # substitution and kills the calling script. The first pattern here
    # (Developer ID) legitimately misses on most machines.
    candidate="$(printf '%s\n' "$identities" | grep "$pattern" | head -1 \
      | sed -E 's/^[^"]*"([^"]+)".*$/\1/' || true)"
    if [ -n "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 0
}
