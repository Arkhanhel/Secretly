#!/usr/bin/env bash
# Make a built macOS .app launchable on machines WITHOUT Homebrew.
#
# Why this exists: the `ffmpeg_kit_flutter_new` GPL pod ships prebuilt av*
# frameworks (libavcodec/format/filter/util/device, libswresample, libswscale)
# that link 12 of their external deps by ABSOLUTE Homebrew paths
# (/opt/homebrew/opt/<pkg>/lib/lib*.dylib) instead of bundling them. The pod
# does NOT bundle those dylibs, so on a machine without Homebrew + every one of
# those formulae installed, dyld fails at launch:
#
#   dyld: Library not loaded: /opt/homebrew/opt/fontconfig/lib/libfontconfig.1.dylib
#
# …and the desktop app crashes on the splash before any UI. This is independent
# of any Dart code: the frameworks load at startup via the FFmpegKit plugin
# registration.
#
# This script makes the .app self-contained:
#   * libz / libiconv  → repointed to the real macOS system copies (/usr/lib).
#   * the other 10 deps → satisfied by tiny no-op stub dylibs bundled into
#     Contents/Frameworks and referenced via @rpath. They are font/text/SRT
#     libraries (fontconfig, freetype, harfbuzz, fribidi, graphite2, glib,
#     gettext, pcre2, libsamplerate, srt) that a plain decode / frame-grab /
#     scale never calls, so two-level-namespace lazy binding never resolves
#     their (absent) symbols. If a feature ever does call into them it degrades
#     gracefully (e.g. the video-thumbnail extraction returns null → the bubble
#     keeps its gradient play-card).
#
# Re-run after every `flutter build macos` / tools/desktop_build_macos.sh.
# Usage: tools/desktop_fix_ffmpeg_deps.sh [path/to/App.app]
#   default: build/macos/Build/Products/Debug/secretly_app.app

set -euo pipefail
cd "$(dirname "$0")/.."

# Default: the Debug product. Resolved by glob rather than a hardcoded name so
# it keeps working after the R-03 rename (secretly_app.app -> Secretly.app).
_default_app() {
  local d="build/macos/Build/Products/Debug"
  /usr/bin/find "$d" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null
}
APP="${1:-$(_default_app)}"
if [ -z "$APP" ]; then
  echo "error: no .app found under build/macos/Build/Products/Debug" >&2
  echo "       pass the bundle path explicitly: $0 path/to/App.app" >&2
  exit 1
fi
# -------------------------------------------------------------------------
# Signing identity — NOT ad-hoc when a stable one is available.
#
# This script re-signs everything it touches, and until 08.09.2026 it always
# signed ad-hoc. An ad-hoc signature changes with every build, so the login
# keychain's per-item ACLs never match and macOS re-asks for the password once
# per stored secret — ~12 prompts, and "Always Allow" never sticks. `00d28fad`
# fixed exactly this, but only in the RELEASE script; the debug path kept the
# storm. Measured on a live account: `startup.secrets_presence ms=28289` —
# twenty-eight seconds of a thirty-second boot spent waiting on dialogs.
#
# Deliberately WITHOUT `--options runtime`: the hardened runtime forbids the
# JIT a Flutter debug build needs. That flag belongs to the release path.
# -------------------------------------------------------------------------
. "$(dirname "$0")/desktop_sign_identity.sh"
SIGN_ID="$(secretly_pick_sign_identity)"
if [ -n "$SIGN_ID" ]; then
  echo "==> signing as: $SIGN_ID"
  echo "    (SECRETLY_SIGN_IDENTITY overrides; SECRETLY_FORCE_ADHOC=1 reverts"
  echo "     to ad-hoc and its keychain prompts)"
else
  echo "==> WARNING: no signing identity — falling back to an ad-hoc signature."
  echo "    Expect macOS to ask for the keychain password on EVERY launch,"
  echo "    once per stored secret."
fi

FW="$APP/Contents/Frameworks"
if [ ! -d "$FW" ]; then
  echo "error: no Frameworks dir at $FW (is the path an .app bundle?)" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'void __ffmpeg_dep_stub(void){}\n' > "$TMP/empty.c"

# stub-lib name : original absolute Homebrew install path
STUBS=(
  "libfontconfig.1.dylib:/opt/homebrew/opt/fontconfig/lib/libfontconfig.1.dylib"
  "libfreetype.6.dylib:/opt/homebrew/opt/freetype/lib/libfreetype.6.dylib"
  "libfribidi.0.dylib:/opt/homebrew/opt/fribidi/lib/libfribidi.0.dylib"
  "libintl.8.dylib:/opt/homebrew/opt/gettext/lib/libintl.8.dylib"
  "libglib-2.0.0.dylib:/opt/homebrew/opt/glib/lib/libglib-2.0.0.dylib"
  "libgraphite2.3.dylib:/opt/homebrew/opt/graphite2/lib/libgraphite2.3.dylib"
  "libharfbuzz.0.dylib:/opt/homebrew/opt/harfbuzz/lib/libharfbuzz.0.dylib"
  "libsamplerate.0.dylib:/opt/homebrew/opt/libsamplerate/lib/libsamplerate.0.dylib"
  "libpcre2-8.0.dylib:/opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib"
  "libsrt.1.5.dylib:/opt/homebrew/opt/srt/lib/libsrt.1.5.dylib"
)

echo "==> bundling ${#STUBS[@]} stub dylibs into Contents/Frameworks"
for e in "${STUBS[@]}"; do
  lib="${e%%:*}"
  clang -dynamiclib -arch arm64 -o "$FW/$lib" -install_name "@rpath/$lib" "$TMP/empty.c"
  codesign --force --sign "${SIGN_ID:--}" "$FW/$lib"
done

echo "==> repointing external refs in the av* frameworks"
for f in libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale; do
  bin="$FW/$f.framework/Versions/A/$f"
  [ -f "$bin" ] || { echo "   skip $f (not bundled)"; continue; }
  for e in "${STUBS[@]}"; do
    lib="${e%%:*}"; src="${e##*:}"
    install_name_tool -change "$src" "@rpath/$lib" "$bin" 2>/dev/null || true
  done
  install_name_tool -change /opt/homebrew/opt/zlib/lib/libz.1.dylib /usr/lib/libz.1.dylib "$bin" 2>/dev/null || true
  install_name_tool -change /opt/homebrew/opt/libiconv/lib/libiconv.2.dylib /usr/lib/libiconv.2.dylib "$bin" 2>/dev/null || true
  codesign --force --sign "${SIGN_ID:--}" "$FW/$f.framework"
done

# 🔴 В ВЫПУСКЕ ГЛУБОКАЯ ПЕРЕПОДПИСЬ ЗАПРЕЩЕНА. `--deep` проходит по ВСЕМУ
# вложенному коду и переподписывает его заново — в том числе помощников Sparkle
# (Updater, Autoupdate, Downloader, Installer), которые приходят подписанными
# самим Sparkle, с hardened runtime. После нашей переподписи они теряли его и
# получали отладочное право get-task-allow, и Apple отказывала в заверении:
# 23.09.2026 выпуск 1.8.53 вернулся со статусом Invalid ровно по этим четырём.
#
# Выпускному скрипту эта переподпись и не нужна: он сам подписывает всё
# вложенное настоящим сертификатом сразу после починки. Поэтому он выставляет
# SECRETLY_FFMPEG_FIX_NO_RESIGN=1, и здесь остаётся только правка библиотек.
if [ "${SECRETLY_FFMPEG_FIX_NO_RESIGN:-0}" = "1" ]; then
  echo "==> done — libraries patched; the release script signs the bundle"
  exit 0
fi

echo "==> deep re-signing the app bundle"

# `codesign --force` REPLACES the signature, and a signature carries the
# entitlements. Re-signing without --entitlements therefore silently strips
# them — including com.apple.security.app-sandbox.
#
# That is not cosmetic. A sandboxed macOS app's "Documents" directory is
# ~/Library/Containers/<bundle>/Data/Documents; an unsandboxed one gets the
# real ~/Documents. So dropping the entitlement moves the database. The app
# then boots against a DIFFERENT secretly.db, finds no profile, and offers to
# pair as a new device — while the real history sits untouched in the other
# path. Two live databases, diverging silently, decided by a signing flag.
#
# So: recover the entitlements the build produced and put them back. Prefer
# what is actually embedded in the bundle (correct by construction, whatever
# the configuration); fall back to the project file matching the build config
# when the bundle has already been stripped by an earlier run of this script.
ENT_TMP="$(mktemp -t secretly_ent).plist"
trap 'rm -f "$ENT_TMP"' EXIT

if codesign -d --entitlements :"$ENT_TMP" "$APP" 2>/dev/null && [ -s "$ENT_TMP" ]; then
  echo "    entitlements: recovered from the bundle"
else
  # CWD is the app root (the script cd's there above), so these stay relative.
  case "$APP" in
    */Release/*) ENT_SRC="macos/Runner/Release.entitlements" ;;
    *)           ENT_SRC="macos/Runner/DebugProfile.entitlements" ;;
  esac
  if [ -f "$ENT_SRC" ]; then
    cp "$ENT_SRC" "$ENT_TMP"
    echo "    entitlements: bundle was stripped, restoring from $(basename "$ENT_SRC")"
  else
    : > "$ENT_TMP"
    echo "    WARNING: no entitlements found — app will run UNSANDBOXED and use ~/Documents"
  fi
fi

# Nested libraries and frameworks are signed above WITHOUT entitlements, which
# is correct: entitlements belong to the main executable only.
if [ -s "$ENT_TMP" ]; then
  codesign --force --deep --sign "${SIGN_ID:--}" --entitlements "$ENT_TMP" "$APP"
else
  codesign --force --deep --sign "${SIGN_ID:--}" "$APP"
fi

if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "app-sandbox"; then
  echo "    verified: app-sandbox entitlement present (database stays in the container)"
else
  echo "    WARNING: app-sandbox NOT present after signing — this build will read ~/Documents"
fi

remaining="$(for f in libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale; do
  b="$FW/$f.framework/Versions/A/$f"; [ -f "$b" ] && otool -L "$b" 2>/dev/null | grep "/opt/homebrew" || true
done)"
if [ -n "$remaining" ]; then
  echo "WARNING: some /opt/homebrew refs remain:" >&2
  echo "$remaining" >&2
  exit 2
fi
echo "==> done — $APP is now launchable without Homebrew"
