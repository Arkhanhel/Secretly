#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="${1:-$(cd "$script_dir/.." && pwd)}"

ios_dir="$app_dir/ios"
runner_dir="$ios_dir/Runner"
google_services_plist="$runner_dir/GoogleService-Info.plist"
entitlements_plist="$runner_dir/Runner.entitlements"
info_plist="$runner_dir/Info.plist"
pbxproj="$ios_dir/Runner.xcodeproj/project.pbxproj"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

[ -d "$ios_dir" ] || fail "iOS project directory not found: $ios_dir"
[ -f "$entitlements_plist" ] || fail "Missing Runner.entitlements: $entitlements_plist"
[ -f "$info_plist" ] || fail "Missing Info.plist: $info_plist"
[ -f "$pbxproj" ] || fail "Missing Xcode project file: $pbxproj"

[ -f "$google_services_plist" ] || fail "Missing ios/Runner/GoogleService-Info.plist. iOS Firebase Messaging cannot initialize without it. Download the plist from Firebase Console for the Runner bundle id and place it in ios/Runner/."
grep -q '<key>GOOGLE_APP_ID</key>' "$google_services_plist" || fail "ios/Runner/GoogleService-Info.plist is present but does not look like a valid Firebase config (missing GOOGLE_APP_ID)."
grep -q 'GoogleService-Info.plist' "$pbxproj" || fail "Runner.xcodeproj does not reference GoogleService-Info.plist. Add the file to the Runner target in Xcode so it is copied into the app bundle."
grep -q '<key>aps-environment</key>' "$entitlements_plist" || fail "Runner.entitlements is missing aps-environment. APNs delivery will not work on device builds without this entitlement."
grep -q '<string>remote-notification</string>' "$info_plist" || fail "Info.plist is missing the remote-notification background mode. Silent/data pushes cannot wake the app without it."

project_bundle_id="$(awk -F'= ' '/PRODUCT_BUNDLE_IDENTIFIER = / && $2 !~ /RunnerTests/ { gsub(/;$/, "", $2); print $2; exit }' "$pbxproj")"
[ -n "$project_bundle_id" ] || fail "Unable to determine Runner PRODUCT_BUNDLE_IDENTIFIER from Runner.xcodeproj."

plist_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$google_services_plist" 2>/dev/null || true)"
[ -n "$plist_bundle_id" ] || fail "GoogleService-Info.plist is missing BUNDLE_ID."
[ "$plist_bundle_id" = "$project_bundle_id" ] || fail "GoogleService-Info.plist BUNDLE_ID ($plist_bundle_id) does not match Runner PRODUCT_BUNDLE_IDENTIFIER ($project_bundle_id)."

printf 'iOS push config preflight passed.\n'