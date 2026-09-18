#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/run_sanitized_flutter.sh [--clean] [--with-ios-pods] [--verify-ios-push] exec <command...>

Copies the Flutter app into a clean /tmp mirror and runs the given command from
there. The mirror keeps build, .dart_tool, and Pods between runs unless --clean
is passed, so repeated macOS builds can reuse caches while avoiding Documents /
File Provider xattrs.
EOF
}

clean=0
with_ios_pods=0
verify_ios_push=0
cmd=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --clean)
      clean=1
      shift
      ;;
    --with-ios-pods)
      with_ios_pods=1
      shift
      ;;
    --verify-ios-push)
      verify_ios_push=1
      shift
      ;;
    exec)
      shift
      if [ "$#" -eq 0 ]; then
        usage >&2
        exit 1
      fi
      cmd=("$@")
      break
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
done

if [ "${#cmd[@]}" -eq 0 ]; then
  usage >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync is required" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter is required" >&2
  exit 1
fi

if [ "$with_ios_pods" -eq 1 ] && ! command -v pod >/dev/null 2>&1; then
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

link_dir() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
mirror_root="${SECRETLY_SANITIZED_MIRROR_ROOT:-${TMPDIR:-/tmp}/secretly_flutter_mirror}"
mirror_dir="$mirror_root/secretly_app"

mkdir -p "$mirror_root"
if [ "$clean" -eq 1 ]; then
  rm -rf "$mirror_dir"
fi
mkdir -p "$mirror_dir"

# Keep generated native build output out of the mirror. These directories can
# contain gigabytes of stale CMake/Gradle state (for example audiotags .cxx
# Debug trees) and walking them over File Provider backed paths makes release
# builds look frozen before compilation even starts.
rm -rf \
  "$mirror_dir/build" \
  "$mirror_dir/build "* \
  "$mirror_dir/ios" \
  "$mirror_dir/macos" \
  "$mirror_dir/windows" \
  "$mirror_dir/linux" \
  "$mirror_dir/web" \
  "$mirror_dir/android/build" \
  "$mirror_dir/android/app/build" \
  "$mirror_dir/android/.gradle" \
  "$mirror_dir/android/.cxx" \
  "$mirror_dir/android/app/.cxx" \
  "$mirror_dir/android/"*.hprof \
  "$mirror_dir/android/"*.hprof.* \
  "$mirror_dir/android/.java_pid"* \
  "$mirror_dir/third_party/audiotags/android/.cxx" \
  "$mirror_dir/third_party/audiotags/android/build" \
  "$mirror_dir/third_party/audiotags/rust_builder/android/build"

rsync_args=(
  -a --delete
  --exclude '/.git/'
  --exclude '/.dart_tool/'
  --exclude '/.idea/'
  --exclude '/.DS_Store'
  --exclude '/build/'
  --exclude '/build */'
  --exclude '/flutter_*.log'
  --exclude '/android/.gradle/'
  --exclude '/android/.cxx/'
  --exclude '/android/build/'
  --exclude '/android/app/.cxx/'
  --exclude '/android/app/build/'
  --exclude '/android/*.hprof'
  --exclude '/android/*.hprof.*'
  --exclude '/android/.java_pid*'
  --exclude '/**/*.hprof'
  --exclude '/**/*.hprof.*'
  --exclude '/**/.java_pid*'
  --exclude '/third_party/**/.gradle/'
  --exclude '/third_party/**/.cxx/'
  --exclude '/third_party/**/build/'
  --exclude '/third_party/**/example/'
  --exclude '/macos/Pods/'
  --exclude '/macos/Flutter/ephemeral/'
  --exclude '/windows/build/'
  --exclude '/linux/build/'
  --exclude '/ios/Pods/'
  --exclude '/ios/.symlinks/'
  --exclude '/ios/Flutter/Generated.xcconfig'
  --exclude '/ios/Flutter/flutter_export_environment.sh'
  --exclude '/ios/Flutter/ephemeral/'
)

printf 'Syncing sanitized Flutter mirror: %s\n' "$mirror_dir"

if [ "${SECRETLY_SANITIZED_FULL_SYNC:-0}" != "1" ] \
  && [ "$clean" -eq 0 ] \
  && [ -f "$mirror_dir/pubspec.yaml" ] \
  && [ -d "$mirror_dir/lib" ] \
  && [ -d "$mirror_dir/android/app" ] \
  && [ -d "$mirror_dir/assets" ]; then
  printf 'Fast-refreshing existing sanitized Flutter mirror; set SECRETLY_SANITIZED_FULL_SYNC=1 for a full resync.\n'

  copy_file_if_exists "$app_dir/pubspec.yaml" "$mirror_dir/pubspec.yaml"
  copy_file_if_exists "$app_dir/pubspec.lock" "$mirror_dir/pubspec.lock"
  copy_file_if_exists "$app_dir/analysis_options.yaml" "$mirror_dir/analysis_options.yaml"
  copy_file_if_exists "$app_dir/l10n.yaml" "$mirror_dir/l10n.yaml"
  copy_file_if_exists "$app_dir/README.md" "$mirror_dir/README.md"

  copy_dir "$app_dir/lib" "$mirror_dir/lib"
  copy_dir "$app_dir/test" "$mirror_dir/test"
  copy_dir "$app_dir/tools" "$mirror_dir/tools"
  copy_dir "$app_dir/android" "$mirror_dir/android"

  if [ "${SECRETLY_SANITIZED_LINK_ASSETS:-0}" = "1" ]; then
    link_dir "$app_dir/assets" "$mirror_dir/assets"
    printf 'Linked assets into mirror.\n'
  elif [ "${SECRETLY_SANITIZED_SYNC_ASSETS:-0}" = "1" ] || [ ! -d "$mirror_dir/assets" ]; then
    copy_dir "$app_dir/assets" "$mirror_dir/assets"
  else
    printf 'Keeping cached assets in mirror; set SECRETLY_SANITIZED_SYNC_ASSETS=1 to refresh them.\n'
  fi

  if [ -d "$app_dir/third_party" ]; then
    # Re-link if ANY vendored package is missing from the cached mirror. The old
    # check looked only at audiotags, so a newly-vendored path package (e.g.
    # liquid_glass_widgets) was silently left out of a cached mirror and pub get
    # failed with "could not find package ... at third_party/...". (2026-07-23)
    third_party_relink=0
    for pkg_pubspec in "$app_dir"/third_party/*/pubspec.yaml; do
      [ -e "$pkg_pubspec" ] || continue
      pkg_name="$(basename "$(dirname "$pkg_pubspec")")"
      if [ ! -f "$mirror_dir/third_party/$pkg_name/pubspec.yaml" ]; then
        third_party_relink=1
        break
      fi
    done
    if [ "$third_party_relink" -eq 1 ]; then
      link_dir "$app_dir/third_party" "$mirror_dir/third_party"
      printf 'Linked third_party path dependencies into mirror.\n'
    else
      printf 'Keeping cached third_party path dependencies in mirror.\n'
    fi
  else
    rm -rf "$mirror_dir/third_party"
  fi
else
  if [ "${SECRETLY_SANITIZED_LINK_ASSETS:-0}" = "1" ]; then
    rsync_args+=(--exclude 'assets/')
  elif [ "${SECRETLY_SANITIZED_SYNC_ASSETS:-0}" != "1" ] && [ -d "$mirror_dir/assets" ]; then
    rsync_args+=(--exclude 'assets/')
  fi
  if [ "${SECRETLY_SANITIZED_SYNC_ASSETS:-0}" != "1" ] && [ -d "$mirror_dir/third_party" ]; then
    rsync_args+=(--exclude 'third_party/')
  fi
  rsync "${rsync_args[@]}" "$app_dir/" "$mirror_dir/"
  if [ "${SECRETLY_SANITIZED_LINK_ASSETS:-0}" = "1" ]; then
    link_dir "$app_dir/assets" "$mirror_dir/assets"
    printf 'Linked assets into mirror.\n'
  fi
fi
printf 'Sanitized Flutter mirror synced.\n'

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$mirror_dir" 2>/dev/null || true
fi

cd "$mirror_dir"
flutter pub get >/dev/null

if [ "$with_ios_pods" -eq 1 ]; then
  (cd ios && pod install >/dev/null)
fi

if [ "$verify_ios_push" -eq 1 ]; then
  bash ./tools/verify_ios_push_config.sh "$PWD"
fi

printf 'Running in sanitized mirror: %s\n' "$mirror_dir"
printf 'Command:'
for arg in "${cmd[@]}"; do
  printf ' %q' "$arg"
done
printf '\n'

"${cmd[@]}"