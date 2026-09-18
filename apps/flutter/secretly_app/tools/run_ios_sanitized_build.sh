#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/run_ios_sanitized_build.sh [xcodebuild-simulator|flutter-simulator|exec <command...>]

Modes:
  xcodebuild-simulator  Copy the app into a clean temp mirror and run a Debug simulator xcodebuild.
  flutter-simulator     Copy the app into a clean temp mirror and run flutter build ios --simulator.
  exec                  Copy the app into a clean temp mirror and run the provided command there.

This helps when the workspace lives under macOS Documents/iCloud/File Provider paths and
generated iOS frameworks fail packaging with "resource fork, Finder information, or similar detritus not allowed".
The mirror keeps iOS build caches between runs, but it does not copy Android/macOS/Windows artifacts.
EOF
}

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync is required" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter is required" >&2
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "error: CocoaPods 'pod' is required" >&2
  exit 1
fi

copy_dir() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  rsync -a --delete \
    --exclude '.dart_tool/' \
    --exclude 'build/' \
    --exclude 'Pods/' \
    --exclude '.symlinks/' \
    --exclude '.gradle/' \
    --exclude '.cxx/' \
    --exclude '*.hprof' \
    --exclude '*.hprof.*' \
    --exclude '.java_pid*' \
    "$src/" "$dst/"
}

copy_file_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
  fi
}

refresh_ios_sources() {
  printf 'Refreshing Flutter metadata.\n'
  copy_file_if_exists "$app_dir/pubspec.yaml" "$mirror_dir/pubspec.yaml"
  copy_file_if_exists "$app_dir/pubspec.lock" "$mirror_dir/pubspec.lock"
  copy_file_if_exists "$app_dir/analysis_options.yaml" "$mirror_dir/analysis_options.yaml"
  copy_file_if_exists "$app_dir/l10n.yaml" "$mirror_dir/l10n.yaml"
  copy_file_if_exists "$app_dir/README.md" "$mirror_dir/README.md"

  printf 'Refreshing Dart sources and tools.\n'
  copy_dir "$app_dir/lib" "$mirror_dir/lib"
  copy_dir "$app_dir/tools" "$mirror_dir/tools"
  printf 'Refreshing iOS project files.\n'
  copy_dir "$app_dir/ios/Runner" "$mirror_dir/ios/Runner"
  copy_dir "$app_dir/ios/Runner.xcodeproj" "$mirror_dir/ios/Runner.xcodeproj"
  copy_dir "$app_dir/ios/Runner.xcworkspace" "$mirror_dir/ios/Runner.xcworkspace"
  # NSE (2026-07-17): the Notification Service Extension target must reach the
  # sanitized mirror or release IPAs would omit it (background fetch on iOS).
  if [ -d "$app_dir/ios/SecretlyNSE" ]; then
    copy_dir "$app_dir/ios/SecretlyNSE" "$mirror_dir/ios/SecretlyNSE"
  fi
  copy_dir "$app_dir/ios/Flutter" "$mirror_dir/ios/Flutter"
  if [ -d "$app_dir/ios/RunnerTests" ]; then
    copy_dir "$app_dir/ios/RunnerTests" "$mirror_dir/ios/RunnerTests"
  else
    rm -rf "$mirror_dir/ios/RunnerTests"
  fi
  copy_file_if_exists "$app_dir/ios/Podfile" "$mirror_dir/ios/Podfile"
  copy_file_if_exists "$app_dir/ios/Podfile.lock" "$mirror_dir/ios/Podfile.lock"

  if [ "${SECRETLY_SANITIZED_LINK_ASSETS:-0}" = "1" ]; then
    link_dir "$app_dir/assets" "$mirror_dir/assets"
    printf 'Linked assets into mirror.\n'
  elif [ "${SECRETLY_SANITIZED_SYNC_ASSETS:-0}" = "1" ] || [ ! -d "$mirror_dir/assets" ]; then
    copy_dir "$app_dir/assets" "$mirror_dir/assets"
  else
    printf 'Keeping cached assets in mirror; set SECRETLY_SANITIZED_SYNC_ASSETS=1 to refresh them.\n'
  fi

  if [ -d "$app_dir/third_party" ]; then
    if [ "${SECRETLY_SANITIZED_COPY_THIRD_PARTY:-0}" = "1" ]; then
      copy_third_party_dir "$app_dir/third_party" "$mirror_dir/third_party"
    elif [ ! -f "$mirror_dir/third_party/audiotags/pubspec.yaml" ] \
      || [ ! -f "$mirror_dir/third_party/audiotags/rust_builder/pubspec.yaml" ]; then
      link_dir "$app_dir/third_party" "$mirror_dir/third_party"
      printf 'Linked third_party path dependencies into mirror.\n'
    else
      printf 'Keeping cached third_party path dependencies in mirror.\n'
    fi
  else
    rm -rf "$mirror_dir/third_party"
  fi
}

copy_third_party_dir() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$dst"
  rsync -a --delete \
    --exclude '.gradle/' \
    --exclude '.cxx/' \
    --exclude 'build/' \
    --exclude 'example/' \
    --exclude '*.hprof' \
    --exclude '*.hprof.*' \
    --exclude '.java_pid*' \
    "$src/" "$dst/"
}

link_dir() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
mirror_root="${SECRETLY_IOS_MIRROR_ROOT:-${TMPDIR:-/tmp}/secretly_ios_mirror}"
mirror_dir="$mirror_root/secretly_app"
derived_data_dir="$mirror_root/DerivedData"

mode="${1:-xcodebuild-simulator}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$mode" in
  xcodebuild-simulator)
    cmd=(
      xcodebuild
      -workspace ios/Runner.xcworkspace
      -scheme Runner
      -configuration Debug
      -sdk iphonesimulator
      -destination "generic/platform=iOS Simulator"
      CODE_SIGNING_ALLOWED=NO
      -derivedDataPath "$derived_data_dir"
      build
    )
    ;;
  flutter-simulator)
    cmd=(flutter build ios --simulator --debug --no-codesign)
    ;;
  exec)
    if [ "$#" -eq 0 ]; then
      usage >&2
      exit 1
    fi
    cmd=("$@")
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

mkdir -p "$mirror_root"
if [ "${SECRETLY_SANITIZED_CLEAN:-0}" = "1" ]; then
  rm -rf "$mirror_dir"
fi
mkdir -p "$mirror_dir"

# Keep the iOS caches that make repeated builds fast, but remove stale
# non-iOS platform trees from older mirrors so rsync never spends minutes
# walking Android/macOS build output for an iPhone build.
rm -rf \
  "$mirror_dir/android" \
  "$mirror_dir/macos" \
  "$mirror_dir/windows" \
  "$mirror_dir/linux" \
  "$mirror_dir/web"
rm -rf \
  "$mirror_dir/build "* \
  "$mirror_dir/android"/*.hprof \
  "$mirror_dir/android"/*.hprof.* \
  "$mirror_dir/android"/.java_pid* \
  "$mirror_dir/third_party/audiotags/android/.cxx" \
  "$mirror_dir/third_party/audiotags/android/build" \
  "$mirror_dir/third_party/audiotags/rust_builder/android/build"
if [ -d "$mirror_dir/build" ]; then
  find "$mirror_dir/build" -mindepth 1 -maxdepth 1 ! -name ios -exec rm -rf {} +
fi

printf 'Syncing iOS sanitized mirror: %s\n' "$mirror_dir"

if [ "${SECRETLY_SANITIZED_FULL_SYNC:-0}" != "1" ] \
  && [ -f "$mirror_dir/pubspec.yaml" ] \
  && [ -d "$mirror_dir/lib" ] \
  && [ -d "$mirror_dir/ios/Runner" ] \
  && [ -d "$mirror_dir/assets" ]; then
  printf 'Fast-refreshing existing iOS mirror; set SECRETLY_SANITIZED_FULL_SYNC=1 for a full resync.\n'
  refresh_ios_sources
else
  printf 'Bootstrapping iOS mirror with targeted refresh.\n'
  refresh_ios_sources
fi
printf 'Sanitized iOS mirror synced.\n'

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$mirror_dir" 2>/dev/null || true
fi

cd "$mirror_dir"
printf 'Resolving Flutter packages in sanitized mirror\n'
flutter pub get >/dev/null
printf 'Resolving iOS Pods in sanitized mirror\n'
(cd ios && pod install >/dev/null)
bash ./tools/verify_ios_push_config.sh "$PWD"

if [ "$mode" = "xcodebuild-simulator" ]; then
  flutter build ios --simulator --debug --no-codesign --config-only >/dev/null
fi

printf 'Running in sanitized mirror: %s\n' "$mirror_dir"
printf 'Command:'
for arg in "${cmd[@]}"; do
  printf ' %q' "$arg"
done
printf '\n'

"${cmd[@]}"