#!/usr/bin/env bash
# Secretly Desktop — macOS RELEASE build, sign, notarize, package.
#
# Companion to tools/desktop_build_macos.sh (which is --debug only). This is the
# shippable path: AOT --release, the ffmpeg self-containment fix, optional
# Developer ID signing + notarization, and an optional DMG.
#
# Implements DESKTOP_COMPLETION_TZ_2026-07-21 §7: R-01 (release build),
# R-02 (target assertion), R-07 (sign embedded natives inside-out),
# R-08 (ffmpeg dylib fix), R-10 (iCloud xattr trap).
#
# ---------------------------------------------------------------------------
# USAGE
#
#   bash tools/desktop_release_macos.sh                 # auto-picks a stable identity
#   SECRETLY_SIGN_IDENTITY="Developer ID Application: … (3HF84UAL32)" \
#     bash tools/desktop_release_macos.sh               # name the identity yourself
#   SECRETLY_SIGN_IDENTITY="…" SECRETLY_NOTARY_PROFILE=secretly \
#     bash tools/desktop_release_macos.sh               # + notarize & staple
#   SECRETLY_MAKE_DMG=1 bash tools/desktop_release_macos.sh   # + DMG
#
# ENV
#   SECRETLY_SIGN_IDENTITY   Signing identity. Unset → auto-selected (Developer
#                            ID first, then a Secretly Apple Development cert).
#                            A STABLE identity is what stops the macOS keychain
#                            prompt storm — see the signing section below.
#   SECRETLY_FORCE_ADHOC=1   Skip auto-selection and sign ad-hoc. Only to
#                            reproduce the old behaviour; the app will then ask
#                            for the keychain password on every launch.
#   SECRETLY_NOTARY_PROFILE  `xcrun notarytool` keychain profile name. Requires
#                            SECRETLY_SIGN_IDENTITY. Create once with:
#                              xcrun notarytool store-credentials secretly \
#                                --apple-id <id> --team-id 3HF84UAL32 --password <app-specific>
#   SECRETLY_MAKE_DMG=1      Build a DMG next to the .app.
#   SECRETLY_LOCAL_DEV=1     Skip production endpoints (use in-code localhost).
#   SECRETLY_KEYS_BASE_URL / SECRETLY_RELAY_HTTP_BASE_URL / SECRETLY_RELAY_WS_URL
#                            Per-env endpoint overrides.
#
# NOTE: this script never flips store prices, never touches prod config flags,
# and never uploads anything. Notarization submits the binary to Apple only when
# SECRETLY_NOTARY_PROFILE is explicitly set.
# ---------------------------------------------------------------------------

set -euo pipefail

# Make a failure impossible to miss. A caller that pipes this script into
# `tail`/`tee` sees the PIPE's exit code, not ours, so a mid-script death can
# otherwise look like a clean run — which is exactly how a silently-skipped
# signing step once produced an "successful" ad-hoc build.
trap 's=$?; [ $s -ne 0 ] && echo "" && echo "!!! desktop_release_macos.sh FAILED at line $LINENO (exit $s) — the artifact is NOT complete" >&2; exit $s' ERR

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"

# R-02: the desktop entry point is NOT the default main.dart. Building the wrong
# target silently ships the MOBILE app in a desktop window — assert it exists.
TARGET="lib/main_desktop.dart"
if [ ! -f "$PROJECT_DIR/$TARGET" ]; then
  echo "error: desktop target $TARGET not found — refusing to build." >&2
  echo "       (the default lib/main.dart is the MOBILE app; never ship it as desktop)" >&2
  exit 1
fi

# -------------------------------------------------------------------------
# R-10 / R-12: keep Xcode's product dir OUTSIDE iCloud.
#
# The repo lives under an iCloud-synced path; the file-provider daemon stamps
# new files with com.apple.fileprovider / com.apple.FinderInfo xattrs, and
# codesign refuses to sign anything carrying them. Symlinking build/macos to a
# cache dir sidesteps the race entirely. `flutter clean` wipes build/, so this
# has to be re-established on every run.
# -------------------------------------------------------------------------
EXTERNAL_BUILD="$HOME/Library/Caches/secretly_app_build_macos"
mkdir -p "$EXTERNAL_BUILD" "$PROJECT_DIR/build"
if [ -L "$PROJECT_DIR/build/macos" ]; then
  current="$(readlink "$PROJECT_DIR/build/macos")"
  if [ "$current" != "$EXTERNAL_BUILD" ]; then
    rm "$PROJECT_DIR/build/macos"
    ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
  fi
elif [ -e "$PROJECT_DIR/build/macos" ]; then
  rm -rf "$PROJECT_DIR/build/macos"
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
else
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
fi
echo "==> build/macos -> $(readlink "$PROJECT_DIR/build/macos")"

# -------------------------------------------------------------------------
# Production endpoints (same defaults as the debug helper). Without these the
# binary falls back to localhost and the desktop hangs on "Подключение…".
# -------------------------------------------------------------------------
KEYS_BASE_URL="${SECRETLY_KEYS_BASE_URL:-https://keys.secretlyapp.com}"
RELAY_HTTP_BASE_URL="${SECRETLY_RELAY_HTTP_BASE_URL:-https://relay.secretlyapp.com}"
RELAY_WS_URL="${SECRETLY_RELAY_WS_URL:-wss://relay.secretlyapp.com/ws}"

DART_DEFINES=()
if [ -z "${SECRETLY_LOCAL_DEV:-}" ]; then
  DART_DEFINES+=("--dart-define=SECRETLY_KEYS_BASE_URL=$KEYS_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_HTTP_BASE_URL=$RELAY_HTTP_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_WS_URL=$RELAY_WS_URL")
  echo "==> endpoints: keys=$KEYS_BASE_URL relay=$RELAY_HTTP_BASE_URL ws=$RELAY_WS_URL"
else
  echo "==> SECRETLY_LOCAL_DEV=1 — using in-code default endpoints"
fi

# Release builds must never boot the mock identity. Guard against a stray env.
if [ -n "${SECRETLY_DESKTOP_TEST_MODE:-}" ]; then
  echo "error: SECRETLY_DESKTOP_TEST_MODE is set — that mock-identity mode must" >&2
  echo "       never be baked into a release build. Unset it and re-run." >&2
  exit 1
fi

# -------------------------------------------------------------------------
# R-01: the actual AOT release build.
# -------------------------------------------------------------------------
echo "==> flutter build macos --release --target=$TARGET"
flutter build macos --release --target="$TARGET" \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"} "$@"

APP_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
APP="$(/usr/bin/find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "error: no .app produced under $APP_DIR" >&2
  exit 1
fi
echo "==> built: $APP"

# -------------------------------------------------------------------------
# R-08: make the bundle launchable without Homebrew (ffmpeg absolute-path deps).
# MUST run BEFORE signing — it rewrites load commands inside the frameworks,
# which would otherwise invalidate their signatures.
# -------------------------------------------------------------------------
echo "==> fixing ffmpeg dylib dependencies"
bash "$PROJECT_DIR/tools/desktop_fix_ffmpeg_deps.sh" "$APP"

# -------------------------------------------------------------------------
# R-07: sign inside-out. `codesign --deep` is explicitly NOT used — it is
# unreliable for nested frameworks and Apple discourages it. We sign every
# embedded dylib/framework first, then the outer bundle, with the hardened
# runtime + entitlements that notarization requires.
# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# Signing identity.
#
# WHY THIS MATTERS BEYOND DISTRIBUTION — the keychain prompt storm.
#
# Secretly keeps its secrets in the macOS *login* keychain (the shared code
# sets `useDataProtectionKeyChain: false`). Items there carry an ACL that
# trusts a specific code signature. An **ad-hoc** signature is derived from the
# binary's own contents, so it changes on EVERY build — the ACL never matches
# the new binary, and macOS re-asks for every single item.
#
# There are ~12 such items (db passphrase, crypto key, per-profile secrets,
# per-device keys, entitlement state), which is why an ad-hoc build asks for
# the keychain password roughly ten times on every launch, and why clicking
# "Always Allow" never sticks.
#
# Signing with ANY stable identity fixes it: approve once per item, and the
# approval survives every later build. So we pick one automatically when the
# caller did not name one.
#
# Note: signing uses a private key from the keychain, so the FIRST signing run
# pops a macOS authorization dialog for that key. Approve it with "Always
# Allow" and later builds are silent.
# -------------------------------------------------------------------------
# The selection itself lives in tools/desktop_sign_identity.sh so the DEBUG
# path (desktop_fix_ffmpeg_deps.sh) uses the very same rules. It did not until
# 08.09.2026, and the storm this section describes survived there for a month.
. "$PROJECT_DIR/tools/desktop_sign_identity.sh"
IDENTITY="$(secretly_pick_sign_identity)"

if [ -n "$IDENTITY" ] && [ -z "${SECRETLY_SIGN_IDENTITY:-}" ]; then
  echo "==> auto-selected signing identity: $IDENTITY"
  echo "    (SECRETLY_SIGN_IDENTITY overrides; SECRETLY_FORCE_ADHOC=1 keeps"
  echo "     the old ad-hoc behaviour and its keychain prompts)"
fi

if [ -z "$IDENTITY" ]; then
  echo "==> WARNING: no signing identity — falling back to an ad-hoc signature."
  echo "    Expect macOS to ask for the keychain password on EVERY launch,"
  echo "    once per stored secret, because an ad-hoc signature changes with"
  echo "    every build and the keychain ACL can never match it."
fi

if [ -n "$IDENTITY" ]; then
  ENTITLEMENTS="$PROJECT_DIR/macos/Runner/Release.entitlements"
  if [ ! -f "$ENTITLEMENTS" ]; then
    echo "error: entitlements not found at $ENTITLEMENTS" >&2
    exit 1
  fi
  echo "==> signing inside-out as: $IDENTITY"

  # A secure timestamp is a NOTARIZATION requirement, and it costs a network
  # round-trip to Apple's timestamp server per signed item — with dozens of
  # embedded frameworks that turns a local build into a multi-minute stall, and
  # it hangs outright when the network is unavailable. Request it only when we
  # are actually going to notarize.
  if [ -n "${SECRETLY_NOTARY_PROFILE:-}" ]; then
    TS_FLAG="--timestamp"
  else
    TS_FLAG="--timestamp=none"
    echo "    (no notarization requested — skipping secure timestamps)"
  fi

  # Nested code first (deepest last-modified order is irrelevant; depth order is).
  while IFS= read -r nested; do
    [ -n "$nested" ] || continue
    codesign --force "$TS_FLAG" --options runtime \
      --sign "$IDENTITY" "$nested"
  done < <(/usr/bin/find "$APP/Contents/Frameworks" \
            \( -name '*.dylib' -o -name '*.framework' -o -name '*.so' \) \
            -depth 2>/dev/null || true)

  # Helper executables / XPC services, if any.
  while IFS= read -r helper; do
    [ -n "$helper" ] || continue
    codesign --force "$TS_FLAG" --options runtime \
      --sign "$IDENTITY" "$helper"
  done < <(/usr/bin/find "$APP/Contents" -type d \
            \( -name '*.xpc' -o -name '*.app' \) -mindepth 2 -depth 2>/dev/null || true)

  # Finally the outer bundle.
  codesign --force "$TS_FLAG" --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP"

  echo "==> verifying signature"
  codesign --verify --deep --strict --verbose=2 "$APP"
  # RK-5 guard: the encrypted-DB stack (sqlite3mc) is one of the embedded
  # natives. If it failed to sign or got stripped, the app opens with a broken
  # PRAGMA key at runtime — surface it here rather than in the field.
  if ! /usr/bin/find "$APP/Contents/Frameworks" -iname '*sqlite3*' | grep -q .; then
    echo "WARNING: no sqlite3/sqlite3mc artefact found under Frameworks." >&2
    echo "         Verify the encrypted database still opens in this build." >&2
  fi
else
  echo "==> SECRETLY_SIGN_IDENTITY unset — leaving Flutter's ad-hoc signature."
  echo "    This build runs on THIS machine only; Gatekeeper blocks it elsewhere."
fi

# -------------------------------------------------------------------------
# R-06: notarize + staple (opt-in, requires a real Developer ID signature).
# -------------------------------------------------------------------------
NOTARY_PROFILE="${SECRETLY_NOTARY_PROFILE:-}"
if [ -n "$NOTARY_PROFILE" ]; then
  if [ -z "$IDENTITY" ]; then
    echo "error: SECRETLY_NOTARY_PROFILE set but SECRETLY_SIGN_IDENTITY is not." >&2
    echo "       Apple only notarizes Developer ID-signed code." >&2
    exit 1
  fi
  ZIP="$APP_DIR/$(basename "${APP%.app}")-notarize.zip"
  echo "==> submitting to Apple notary service (profile: $NOTARY_PROFILE)"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> stapling ticket"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm -f "$ZIP"
else
  echo "==> SECRETLY_NOTARY_PROFILE unset — skipping notarization."
fi

# -------------------------------------------------------------------------
# R-12: optional DMG.
# -------------------------------------------------------------------------
if [ -n "${SECRETLY_MAKE_DMG:-}" ]; then
  DMG="$APP_DIR/Secretly.dmg"
  echo "==> packaging $DMG"
  rm -f "$DMG"
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  /usr/bin/hdiutil create -volname "Secretly" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  if [ -n "$IDENTITY" ]; then
    codesign --force "$TS_FLAG" --sign "$IDENTITY" "$DMG"
  fi
  echo "==> DMG: $DMG"
fi

echo
echo "=============================================================="
echo " RELEASE ARTIFACT: $APP"
[ -n "${SECRETLY_MAKE_DMG:-}" ] && echo " DMG:              $APP_DIR/Secretly.dmg"
echo
echo " Signed:     $([ -n "$IDENTITY" ] && echo "Developer ID ($IDENTITY)" || echo "ad-hoc (local only)")"
echo " Notarized:  $([ -n "$NOTARY_PROFILE" ] && echo "yes" || echo "no")"
echo
echo " Smoke-test before distributing:"
echo "   1. open \"$APP\"  — must reach the UI (not crash on splash)"
echo "   2. pair with the phone by QR, send + receive a message"
echo "   3. confirm the encrypted DB opened (chat history persists across restart)"
echo "=============================================================="
