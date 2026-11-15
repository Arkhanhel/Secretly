# Modifications to ffmpeg_kit_flutter_new 4.2.1

This directory is a copy of the Flutter plugin
[ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new)
4.2.1 (LGPL-3.0, see `LICENSE`), vendored into Secretly on 2026-10-04 so that
the mobile apps can ship the LGPL build of FFmpeg instead of the GPL one.

Changes made by the Secretly project:

- `scripts/setup_ios.sh` downloads the LGPL `8.0.0-full` iOS frameworks instead
  of `8.0.0-full-gpl`, and verifies the archive by SHA-256.
- `android/build.gradle` depends on `com.antonkarpenko:ffmpeg-kit-full:2.1.0`
  (LGPL) instead of `ffmpeg-kit-full-gpl:2.1.0`.
- The `example/` app is not included.
- `android/.../FFmpegKitFlutterPlugin.java` checks once whether the FFmpeg
  native libraries are present (`isNativeAvailable`) before touching
  `FFmpegKitConfig`, whose static initialiser loads them. The lightweight
  Android build ships without those libraries; without this check the plugin
  would throw while attaching to the activity and the app would not start.
  Method calls then answer with the error `NATIVE_UNAVAILABLE`.

macOS and Windows are unchanged: the desktop apps keep the GPL build of FFmpeg
(distributed with its license text and source information).

The FFmpeg libraries are linked dynamically (separate frameworks / shared
libraries), so they can be replaced by a modified version as the LGPL requires.
