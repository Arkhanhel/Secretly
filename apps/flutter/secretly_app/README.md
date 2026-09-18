# secretly_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS Build Note

If local iOS builds fail in this workspace with `resource fork, Finder information, or similar detritus not allowed`, run the build from a sanitized temp mirror instead of directly from `Documents`:

```bash
./tools/run_ios_sanitized_build.sh
```

The helper copies the app into `/tmp`, removes macOS extended attributes there, and runs a simulator build from the clean mirror.

## iOS Push Preflight

The iOS app now has an explicit push preflight check:

```bash
bash ./tools/verify_ios_push_config.sh
```

It fails fast if the workspace is missing any of the minimum requirements for Firebase/APNs push registration:

- `ios/Runner/GoogleService-Info.plist`
- Xcode project reference for `GoogleService-Info.plist`
- `aps-environment` in `ios/Runner/Runner.entitlements`
- `remote-notification` in `ios/Runner/Info.plist`

`./tools/run_ios_sanitized_build.sh` now runs this preflight automatically before building, so broken iOS push configuration is caught before a release or test build is produced.
