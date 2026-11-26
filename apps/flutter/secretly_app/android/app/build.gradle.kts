plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import org.gradle.api.GradleException
import java.util.Properties

fun isReleaseTaskRequested(taskNames: List<String>): Boolean {
    if (taskNames.isEmpty()) {
        return false
    }

    return taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true) ||
            taskName.contains("bundle", ignoreCase = true)
    }
}

fun requireKeystoreProperty(properties: Properties, key: String): String {
    return (properties.getProperty(key) ?: "").trim().ifEmpty {
        throw GradleException("Secretly: key.properties missing '$key'")
    }
}

android {
    namespace = "com.secretly.secretly_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    val hasReleaseKeystore = keystorePropertiesFile.exists()
    val releaseTaskRequested = isReleaseTaskRequested(gradle.startParameter.taskNames)
    val arm64OnlyNativeBuild = releaseTaskRequested ||
        (project.findProperty("secretly.arm64Only")?.toString()?.equals("true", ignoreCase = true) == true)
    // 🔴 НАБОР АРХИТЕКТУР — ИЗ ТОГО, ЧТО ЗАПРОСИЛ FLUTTER, А НЕ «ВСЕГДА arm64».
    //
    // Раньше любая сборка выпуска жёстко оставляла только `arm64-v8a`. Пока
    // выпуск был один, это совпадало с замыслом; с появлением облегчённой
    // сборки под дешёвые телефоны (`--target-platform android-arm`) совпадать
    // перестало: Flutter кладёт в пакет библиотеки armeabi-v7a, а упаковка их
    // тут же выбрасывала — получался APK БЕЗ нативных библиотек, который
    // падает на первом же обращении к ним.
    //
    // Flutter передаёт выбор свойством `-Ptarget-platform` (`android-arm`,
    // `android-arm64`, через запятую). Пустое значение (кто-то позвал Gradle
    // напрямую) оставляет прежнее поведение — только arm64.
    val abiByPlatform = mapOf(
        "android-arm" to "armeabi-v7a",
        "android-arm64" to "arm64-v8a",
        "android-x86" to "x86",
        "android-x64" to "x86_64",
    )
    val requestedAbis = (project.findProperty("target-platform")?.toString() ?: "")
        .split(',')
        .mapNotNull { abiByPlatform[it.trim()] }
        .toSet()
    val keptAbis = if (requestedAbis.isEmpty()) setOf("arm64-v8a") else requestedAbis
    // 🔴 ЛЁГКАЯ СБОРКА — СВОЙСТВОМ GRADLE, А НЕ РАЗНОВИДНОСТЬЮ (flavor).
    //
    // ТЗ Э7 предлагало product flavors `full`/`lite`. С ними задачи Flutter
    // становятся пофлаворными, и `flutter build apk|appbundle` БЕЗ `--flavor`
    // перестаёт существовать — а именно так собирает выпуск
    // tools/macos_build_android_release.sh. Ломать выпущенный конвейер ради
    // облегчённой сборки нельзя, поэтому переключатель — свойство, как уже
    // сделано рядом для набора архитектур.
    //
    // Пара к нему на стороне Dart — `--dart-define=SECRETLY_LITE=true`:
    // Gradle выбрасывает библиотеки, Dart перестаёт предлагать то, что без
    // них не работает. Сборочный скрипт выставляет оба флага вместе; если
    // выставить только этот, приложение не упадёт (плагины проверяют наличие
    // библиотеки сами), но будет показывать недоступные возможности.
    val liteBuild =
        project.findProperty("secretly.lite")?.toString()?.equals("true", ignoreCase = true) == true
    if (hasReleaseKeystore) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    } else if (releaseTaskRequested) {
        throw GradleException(
            "Secretly: release task requested but android/key.properties is missing. " +
                "Refusing to fall back to debug signing.",
        )
    }

    val releaseStoreFilePath = if (hasReleaseKeystore) {
        requireKeystoreProperty(keystoreProperties, "storeFile")
    } else {
        ""
    }
    val releaseStorePassword = if (hasReleaseKeystore) {
        requireKeystoreProperty(keystoreProperties, "storePassword")
    } else {
        ""
    }
    val releaseKeyAlias = if (hasReleaseKeystore) {
        requireKeystoreProperty(keystoreProperties, "keyAlias")
    } else {
        ""
    }
    val releaseKeyPassword = if (hasReleaseKeystore) {
        requireKeystoreProperty(keystoreProperties, "keyPassword")
    } else {
        ""
    }
    if (hasReleaseKeystore) {
        val releaseStoreFile = rootProject.file(releaseStoreFilePath)
        if (!releaseStoreFile.exists()) {
            throw GradleException(
                "Secretly: release keystore file not found: ${releaseStoreFile.path}",
            )
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = rootProject.file(releaseStoreFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.secretly.secretly_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ffmpeg_kit_flutter_new (video trim/crop editor) requires API 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (arm64OnlyNativeBuild) {
            ndk {
                abiFilters += keptAbis
            }
        }
    }

    packaging {
        jniLibs {
            excludes += setOf("**/libnoise.so")
            if (arm64OnlyNativeBuild) {
                excludes += abiByPlatform.values
                    .filterNot { keptAbis.contains(it) }
                    .map { "**/$it/**" }
                    .toSet()
            }
            if (liteBuild) {
                // Список — в <app>/tools/lite_excluded_libs.txt, ОДИН на сборку и
                // на проверку готового APK: когда их было два, в сборке
                // 12.10.2026 остались libwhisper.so и libparakeet.so.
                // Распознавание штрих-кодов в списке отсутствует намеренно:
                // без него не прочитать QR привязки устройства.
                // Путь — внутри каталога приложения: выпуск собирается из
                // «очищенного зеркала», и файл вне этого каталога там не
                // существует.
                val liteList = rootProject.file("../tools/lite_excluded_libs.txt")
                if (!liteList.isFile) {
                    throw GradleException(
                        "Secretly: не найден список библиотек облегчённой сборки: $liteList",
                    )
                }
                val patterns = liteList.readLines()
                    .map { it.trim() }
                    .filter { it.isNotEmpty() && !it.startsWith("#") }
                if (patterns.isEmpty()) {
                    throw GradleException("Secretly: список библиотек облегчённой сборки пуст")
                }
                excludes += patterns.map { "**/$it" }.toSet()
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 🔴 НАТИВНЫЕ СИМВОЛЫ В БАНДЛ (09.09.2026).
            //
            // Без этого Play Console показывает нативные кадры голыми адресами:
            // трасса ANR владельца пришла с четырнадцатью строками вида
            // `pc 0x0000000000ae72e8 … split_config.arm64_v8a.apk` и назвать по
            // ней виновника было нечем. Проверка бандла 565 подтвердила: файлы
            // символов лежали только для восьми сторонних библиотек, а для
            // остальных — ни одного.
            //
            // `SYMBOL_TABLE` даёт имена функций, но без тяжёлого DWARF: этого
            // достаточно, чтобы читать `libc __memcpy`, `libwhisper` и прочие
            // нативные падения.
            //
            // ⚠️ Размер приложения НЕ растёт: символы кладутся в
            // `BUNDLE-METADATA/`, а Play вырезает эти данные перед раздачей —
            // на устройство они не попадают.
            //
            // ⚠️ Кадры кода на Dart этим НЕ покрываются: они живут внутри
            // снимка AOT в `libapp.so`, и их имена достаёт только
            // `--split-debug-info` вместе с `flutter symbolize`. Флаг сборки
            // добавлен отдельно — см. docs/СИМВОЛИЗАЦИЯ_ТРАСС.md.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
        debug {
            // Coexist alongside the release-signed production app on a device:
            // debug installs as com.secretly.secretly_app.debug (uses
            // src/debug/google-services.json). Lets us screenshot/test without
            // uninstalling the real app. Release build is unaffected.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        // 🔴 PROFILE ТОЖЕ УХОДИТ В `.debug`, И ЭТО НЕ КОСМЕТИКА (15.09.2026).
        //
        // Отладочная сборка на телефоне не годится для проверки скорости: она
        // идёт по JIT, и одна подпись запроса к релею занимает у неё ПОЛТОРЫ
        // СЕКУНДЫ (замер на живом устройстве: `sign_ms=1376`). Из-за этого
        // срабатывают таймауты ключей и почты, и приложение выглядит сломанным,
        // хотя сломана только скорость.
        //
        // Честная проверка — сборка `--profile`: тот же AOT, что в релизе.
        // Но по умолчанию она берёт applicationId РЕЛИЗА, и поставить её на
        // телефон можно было бы только снеся настоящее приложение вместе с
        // историей и ключами. Поэтому суффикс тот же, что у отладочной: обе
        // живут рядом с выпущенной и заменяют друг друга, а не её.
        //
        // `src/profile/google-services.json` — копия отладочного: плагин Google
        // ищет файл по ИМЕНИ ТИПА СБОРКИ, а не по applicationId, и без этой
        // копии сборка падает с «No matching client found».
        maybeCreate("profile").apply {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-profile"
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("debug", "release")
        }
    }
}

flutter {
    source = "../.."
}

// Redirect the Android app module's build output directory to the path where
// Flutter tools expects to find the APK: {flutter_project_root}/build/app/
// The default (android/app/build/) is not discoverable by 'flutter build apk'.
layout.buildDirectory.set(rootProject.rootDir.parentFile.resolve("build/app"))

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.13.1")
    // Play Vitals п. 15 (15.11.2026): темы приложения — AppCompat (окно
    // отпечатка local_auth на Android ≤ 9). Та же версия, что уже приходит
    // через androidx.biometric, — объявлена явно, чтобы ресурсы приложения
    // могли на неё ссылаться.
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.media:media:1.7.0")
    // Required to extend FirebaseMessagingService for native background call delivery.
    // The firebase_messaging Flutter plugin uses 'implementation' (not 'api'), so the
    // classes are not transitively exposed to the :app module.
    implementation("com.google.firebase:firebase-messaging:24.1.2")
    // 16 KB page-size fix (Play Console, 2026-07-23). shared_preferences_android
    // pulls an old androidx.datastore whose prebuilt libdatastore_shared_counter.so
    // is 4 KB-aligned and crashes on 16 KB-page devices. Our own native code is
    // already fine (flutter.ndkVersion = r28); only this transitive .so lags.
    // Force the current datastore, whose .so ships 16 KB-aligned LOAD segments —
    // verified with readelf on the built bundle. Gradle picks the higher version,
    // so datastore-core comes along at the same version.
    implementation("androidx.datastore:datastore-preferences:1.1.7")
    // Нативное окно оценки Google Play (24.11.2026, app_review_prompt.dart).
    // Только Java/Kotlin, без .so — проверка 16 КБ не затронута.
    implementation("com.google.android.play:review:2.0.2")
}
