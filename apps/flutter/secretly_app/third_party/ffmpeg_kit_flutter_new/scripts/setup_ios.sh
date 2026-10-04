#!/bin/bash

# Secretly modification (2026-10-04): the iOS build uses the LGPL "full"
# variant (no x264, no GPL components), pinned by SHA-256. Video is encoded
# with the system encoder (h264_videotoolbox) instead of libx264.
set -e
IOS_URL="https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.0.0-full/ffmpeg-kit-ios-full-8.0.0.zip"
IOS_SHA256="59fbc8c0a9d5f742a53c9f5d5e5cd53573c3a3bb76f370e947db38d1c537c137"
mkdir -p Frameworks
curl -fL $IOS_URL -o frameworks.zip
echo "$IOS_SHA256  frameworks.zip" | shasum -a 256 -c -
unzip -o frameworks.zip -d Frameworks
rm -rf frameworks.zip Frameworks/__MACOSX

# Delete bitcode from all frameworks
xcrun bitcode_strip -r Frameworks/ffmpegkit.framework/ffmpegkit -o Frameworks/ffmpegkit.framework/ffmpegkit
xcrun bitcode_strip -r Frameworks/libavcodec.framework/libavcodec -o Frameworks/libavcodec.framework/libavcodec
xcrun bitcode_strip -r Frameworks/libavdevice.framework/libavdevice -o Frameworks/libavdevice.framework/libavdevice
xcrun bitcode_strip -r Frameworks/libavfilter.framework/libavfilter -o Frameworks/libavfilter.framework/libavfilter
xcrun bitcode_strip -r Frameworks/libavformat.framework/libavformat -o Frameworks/libavformat.framework/libavformat
xcrun bitcode_strip -r Frameworks/libavutil.framework/libavutil -o Frameworks/libavutil.framework/libavutil
xcrun bitcode_strip -r Frameworks/libswresample.framework/libswresample -o Frameworks/libswresample.framework/libswresample
xcrun bitcode_strip -r Frameworks/libswscale.framework/libswscale -o Frameworks/libswscale.framework/libswscale