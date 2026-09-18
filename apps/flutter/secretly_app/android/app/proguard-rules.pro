# AndroidX Window APIs are optional OEM/runtime integrations. R8 should not
# fail the release build when these classes are absent on the classpath.
-dontwarn androidx.window.extensions.WindowExtensions
-dontwarn androidx.window.extensions.WindowExtensionsProvider
-dontwarn androidx.window.extensions.area.ExtensionWindowAreaPresentation
-dontwarn androidx.window.extensions.layout.DisplayFeature
-dontwarn androidx.window.extensions.layout.FoldingFeature
-dontwarn androidx.window.extensions.layout.WindowLayoutComponent
-dontwarn androidx.window.extensions.layout.WindowLayoutInfo
-dontwarn androidx.window.sidecar.SidecarDeviceState
-dontwarn androidx.window.sidecar.SidecarDisplayFeature
-dontwarn androidx.window.sidecar.SidecarInterface$SidecarCallback
-dontwarn androidx.window.sidecar.SidecarInterface
-dontwarn androidx.window.sidecar.SidecarProvider
-dontwarn androidx.window.sidecar.SidecarWindowLayoutInfo

# ffmpeg_kit_flutter_new (com.antonkarpenko.ffmpegkit fork): the native
# libffmpegkit_abidetect.so binds Java methods (e.g. AbiDetect.getNativeCpuAbi)
# via JNI RegisterNatives in JNI_OnLoad. Those methods look unused to R8's
# static analysis, so R8 strips/renames them in release builds -> JNI_OnLoad
# returns "Bad JNI version" -> the whole GeneratedPluginRegistrant aborts and
# every plugin after ffmpeg (shared_preferences, etc.) fails to register.
# Keep the native-bound classes and their members intact.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.antonkarpenko.smartexception.** { *; }
-keepclasseswithmembernames class com.antonkarpenko.ffmpegkit.** {
    native <methods>;
}
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.antonkarpenko.smartexception.**