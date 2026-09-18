#!/usr/bin/env bash
# Desktop macOS build helper for Secretly.
#
# Why this exists: the project lives under ~/Documents (iCloud Drive). macOS's
# file-provider daemon stamps every newly-created file in that subtree with
# `com.apple.fileprovider.fpfs#P` + `com.apple.FinderInfo` xattrs. Modern
# `codesign` refuses to sign anything carrying that "detritus", and any in-build
# xattr-strip step loses the race against file-provider re-stamping the .app
# directory between Xcode's CopySwiftLibs phase and its implicit CodeSign.
#
# The robust workaround is to put Xcode's product directory OUTSIDE iCloud.
# We do that by symlinking `build/macos` → `~/Library/Caches/secretly_app_build_macos`.
# Flutter and Xcode follow the symlink transparently; the .app is built outside
# iCloud and gets signed without detritus errors.
#
# Symlink survives normal builds, `flutter pub get`, and `pod install`, but
# `flutter clean` wipes `build/`. Re-run this script after a clean.

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
EXTERNAL_BUILD="$HOME/Library/Caches/secretly_app_build_macos"

mkdir -p "$EXTERNAL_BUILD" "$PROJECT_DIR/build"

if [ -L "$PROJECT_DIR/build/macos" ]; then
  current="$(readlink "$PROJECT_DIR/build/macos")"
  if [ "$current" != "$EXTERNAL_BUILD" ]; then
    rm "$PROJECT_DIR/build/macos"
    ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
  fi
elif [ -e "$PROJECT_DIR/build/macos" ]; then
  # Real directory in the way (e.g. just after `flutter clean` re-created it).
  rm -rf "$PROJECT_DIR/build/macos"
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
else
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
fi

echo "build/macos -> $(readlink "$PROJECT_DIR/build/macos")"

# -------------------------------------------------------------------------
# Production endpoints.
#
# Without these --dart-define flags the binary falls back to the in-code
# defaults (http://127.0.0.1:8081 for keys, http://127.0.0.1:8082 for relay).
# A headless desktop pointed at localhost shows "Подключение…" forever and
# the QR pairing flow silently fails because keys.secretlyapp.com is never
# reached. We bake the production endpoints in by default and provide an
# escape hatch (SECRETLY_LOCAL_DEV=1) for developers running local servers.
# -------------------------------------------------------------------------

KEYS_BASE_URL_DEFAULT="https://keys.secretlyapp.com"
RELAY_HTTP_BASE_URL_DEFAULT="https://relay.secretlyapp.com"
RELAY_WS_URL_DEFAULT="wss://relay.secretlyapp.com/ws"

# Allow per-env overrides (SECRETLY_KEYS_BASE_URL=… bash tools/desktop_build_macos.sh)
KEYS_BASE_URL="${SECRETLY_KEYS_BASE_URL:-$KEYS_BASE_URL_DEFAULT}"
RELAY_HTTP_BASE_URL="${SECRETLY_RELAY_HTTP_BASE_URL:-$RELAY_HTTP_BASE_URL_DEFAULT}"
RELAY_WS_URL="${SECRETLY_RELAY_WS_URL:-$RELAY_WS_URL_DEFAULT}"

DART_DEFINES=()
if [ -z "${SECRETLY_LOCAL_DEV:-}" ]; then
  DART_DEFINES+=("--dart-define=SECRETLY_KEYS_BASE_URL=$KEYS_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_HTTP_BASE_URL=$RELAY_HTTP_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_WS_URL=$RELAY_WS_URL")
  echo "endpoints: keys=$KEYS_BASE_URL relay=$RELAY_HTTP_BASE_URL ws=$RELAY_WS_URL"
else
  echo "SECRETLY_LOCAL_DEV=1 — skipping production --dart-defines (using in-code defaults)"
fi

# -------------------------------------------------------------------------
# GIPHY GIF API key.
#
# 🔴 БЕЗ ЭТОГО ВКЛАДКА GIF В ОКНЕ ПУСТАЯ — и выглядит это как «не работает»,
# хотя работает всё, кроме ключа. Телефонные сборки его кладут давно
# (tools/macos_build_{ios,android}_release.sh), десктопная — нет: до 16.09.2026
# у окна и вкладки-то не было, стояла заглушка «GIF-поиск скоро».
#
# Ключ КЛИЕНТСКИЙ: GIPHY их такими и задумывал, он уезжает внутрь приложения.
# Умолчание — та же бесплатная бета-выдача, что у телефонных сборок (100
# запросов в час на ключ). Переопределяется SECRETLY_GIPHY_API_KEY.
# -------------------------------------------------------------------------
GIPHY_API_KEY="${SECRETLY_GIPHY_API_KEY:-HUMYlLn3WGTANXmZFyVjWz2KXugbjFuz}"
if [ -n "$GIPHY_API_KEY" ]; then
  DART_DEFINES+=("--dart-define=GIPHY_API_KEY=$GIPHY_API_KEY")
fi

# -------------------------------------------------------------------------
# Desktop test-mode (opt-in).
#
# Default OFF. When ON, AppController boots with a hardcoded mock identity
# ('desktop-test-id' / 'desktop-test-device') and skips the real keys/relay
# clients — useful for UI development without a running server, but breaks
# real QR pairing + sync. Enable only for offline mock runs:
#
#   SECRETLY_DESKTOP_TEST_MODE=1 bash tools/desktop_build_macos.sh
#
# Until 2026-05-19 this gate was effectively always-on (constant true for
# every desktop platform), which silently broke production sync. See
# `_desktopTestStartupMode` in lib/app/app_controller.dart.
# -------------------------------------------------------------------------
if [ -n "${SECRETLY_DESKTOP_TEST_MODE:-}" ]; then
  DART_DEFINES+=("--dart-define=SECRETLY_DESKTOP_TEST_MODE=true")
  echo "SECRETLY_DESKTOP_TEST_MODE=1 — booting with mock identity (no real keys/relay)"
fi

# Note: `"${arr[@]+"${arr[@]}"}"` is the safe expansion that survives both
# `set -u` and bash 3.2's empty-array quirk (matters when SECRETLY_LOCAL_DEV=1).
#
# NOT `exec`: the build is only half the job — see the ffmpeg step below.
flutter build macos --debug --target=lib/main_desktop.dart \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"} "$@"

# -------------------------------------------------------------------------
# Make the freshly-built .app actually launchable.
#
# The `ffmpeg_kit_flutter_new` pod links a dozen of its dependencies by
# ABSOLUTE Homebrew paths and does not bundle them, so a straight
# `flutter build macos` produces a bundle that dies in dyld before a single
# frame is drawn:
#
#   Termination Reason: Namespace DYLD, Code 1, Library missing
#   Library not loaded: /opt/homebrew/opt/fontconfig/lib/libfontconfig.1.dylib
#   Referenced from: .../Frameworks/libswresample.framework/.../libswresample
#
# That is a full Apple crash report, at launch, every time — and it is what a
# desktop session cost on 08.09.2026 before someone remembered the second
# script. The release pipeline has always run this step
# (tools/desktop_release_macos.sh); the debug one did not, which meant the
# build path people actually use day to day was the broken one.
#
# Idempotent and quick, so it runs unconditionally rather than behind a flag.
# -------------------------------------------------------------------------
echo "==> making the bundle launchable (ffmpeg deps + re-sign)"
bash "$PROJECT_DIR/tools/desktop_fix_ffmpeg_deps.sh"
