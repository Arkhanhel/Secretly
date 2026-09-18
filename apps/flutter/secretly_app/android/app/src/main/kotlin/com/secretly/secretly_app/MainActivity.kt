package com.secretly.secretly_app

import android.annotation.SuppressLint
import android.app.NotificationManager
import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.ClipDescription
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Rational
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    companion object {
        // Tracks whether MainActivity is between onStart and onStop. Used by
        // SecretlyFirebaseMessagingService to decide whether to launch the
        // full-screen IncomingCallActivity automatically: when the user is
        // already inside the app, the heads-up notification alone is desired
        // (full-screen UI opens only via tap), so we skip the direct launch.
        @JvmStatic
        val isAppForeground: AtomicBoolean = AtomicBoolean(false)

        const val ACTION_CALL_DECISION = "com.secretly.secretly_app.CALL_DECISION"
        const val ACTION_OPEN_CONVO = "com.secretly.secretly_app.OPEN_CONVO"
        const val ACTION_MSG_REPLY = "com.secretly.secretly_app.ACTION_MSG_REPLY"
        const val ACTION_MSG_MARK_READ = "com.secretly.secretly_app.ACTION_MSG_MARK_READ"
        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_CALL_ATTEMPT_ID = "call_attempt_id"
        const val EXTRA_DECISION = "decision"
        const val EXTRA_CALL_DECISION_TOKEN = "call_decision_token"
        private const val PENDING_PREFS = "secretly_pending_actions"
        private const val PENDING_CALL_ID = "pending_call_id"
        private const val PENDING_CALL_ATTEMPT_ID = "pending_call_attempt_id"
        private const val PENDING_CALL_DECISION = "pending_call_decision"
        private const val PENDING_MEDIA_ACTION = "pending_media_action"
        private const val ACTIVE_CALL_ID = "active_call_id"
        private const val ACTIVE_CALL_ATTEMPT_ID = "active_call_attempt_id"
        private const val ACTIVE_CALL_DECISION_TOKEN = "active_call_decision_token"
        private var mediaActionSink: EventChannel.EventSink? = null

        /**
         * 🔴 ОТПРАВКА В ПРИЁМНИК НЕ ИМЕЕТ ПРАВА РОНЯТЬ ПРИЛОЖЕНИЕ (20.08.2026).
         *
         * Play Console, версия 531: `FlutterJNI.ensureAttachedToNative`
         * (RuntimeException) и `DartMessenger\$Reply.reply`
         * (IllegalStateException). Оба стека приходят из разрушения экрана.
         *
         * Причина: приёмник обнуляется только когда Dart САМ отписался
         * (`onCancel`). Экран, уничтоженный системой, этого не делает — поле
         * остаётся указывать на мёртвый движок, и первое же нажатие кнопки в
         * уведомлении (медиа, звонок, ответ на смс) бьёт в него.
         *
         * Направление отказа: событие остаётся НЕОТПРАВЛЕННЫМ (вызывающий
         * кладёт его в буфер), но приложение не падает.
         *
         * @return true, если отправка удалась.
         */
        @JvmStatic
        fun trySink(sink: EventChannel.EventSink?, payload: Any?): Boolean {
            if (sink == null) return false
            return try {
                sink.success(payload)
                true
            } catch (t: Throwable) {
                Log.w("NativeSink", "sink delivery failed: " + t.message)
                false
            }
        }

        /**
         * 🔴 ОТВЕТ В КАНАЛ ТОЖЕ НЕ ИМЕЕТ ПРАВА РОНЯТЬ ПРИЛОЖЕНИЕ (09.09.2026).
         *
         * Спутник [trySink] для другой половины канала. Правка 20.08 закрыла
         * приёмники событий, но ОТВЕТЫ `MethodChannel.Result` остались голыми —
         * и `FlutterJNI.ensureAttachedToNative` (RuntimeException) вместе с
         * `DartMessenger\$Reply.reply` (IllegalStateException) продолжили
         * приходить уже с версии 565.
         *
         * Все три оставшиеся точки отвечают на запрос разрешений для звонка,
         * то есть срабатывают ПОСЛЕ возврата из системного диалога — ровно
         * тогда, когда экран мог быть уничтожен системой, а движок отсоединён.
         *
         * Направление отказа: ответ не доходит, но приложение не падает. Ждать
         * его в этот момент уже некому — сторона Dart ушла вместе с движком.
         *
         * ⚠️ Обнуление поля ДО вызова (`pendingCallPermsResult = null`) —
         * защита от двойного ответа, он сам по себе исключение. Не убирать:
         * перехват ниже её не заменяет.
         *
         * @return true, если ответ доставлен.
         */
        @JvmStatic
        fun tryReply(result: MethodChannel.Result?, value: Any?): Boolean {
            if (result == null) return false
            return try {
                result.success(value)
                true
            } catch (t: Throwable) {
                Log.w("NativeReply", "channel reply failed: " + t.message)
                false
            }
        }

        /** Движок уходит — статическая ссылка на него обязана уйти вместе с ним. */
        @JvmStatic
        fun clearStaticSinks() {
            mediaActionSink = null
        }

        @JvmStatic
        fun emitOrBufferMediaAction(context: Context, action: String) {
            val normalized = action.trim().lowercase()
            if (normalized.isEmpty()) {
                return
            }
            if (!trySink(mediaActionSink, mapOf("action" to normalized))) {
                // Приёмника нет ИЛИ он умер вместе с движком — откладываем.
                context.applicationContext
                    .getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(PENDING_MEDIA_ACTION, normalized)
                    .apply()
                return
            }
            context.applicationContext
                .getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(PENDING_MEDIA_ACTION)
                .apply()
        }
    }

    private var callActionSink: EventChannel.EventSink? = null
    private var notifTapSink: EventChannel.EventSink? = null
    private var msgActionSink: EventChannel.EventSink? = null
    private var shareIntentSink: EventChannel.EventSink? = null
    private var pendingCallPermsResult: MethodChannel.Result? = null
    private val REQUEST_CODE_CALL_PERMS = 0xCA11
    private var networkPathSink: EventChannel.EventSink? = null
    private var networkPathCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingSharePayload: Map<String, Any?>? = null
    private var pipAutoEnterEnabled: Boolean = false
    private var pipAspectRatio: Rational = Rational(9, 16)
    private var pipEventsSink: EventChannel.EventSink? = null
    private var lastPipMode: Boolean = false

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallDecisionIntent(intent)
        handleOpenConvoIntent(intent)
        handleMsgActionIntent(intent)
        handleIncomingShareIntent(intent)
    }

    // Premium feature #4 — runtime launcher-icon switching. Maps the Dart-side
    // icon key to the <activity-alias> declared in AndroidManifest.xml. Exactly
    // one alias is enabled at a time; MainActivity itself is never disabled.
    private val iconAliasComponents: Map<String, String> = linkedMapOf(
        "default" to "MainActivityDefault",
        "midnight" to "MainActivityMidnight",
        "ocean" to "MainActivityOcean",
        "sunset" to "MainActivitySunset",
        "emerald" to "MainActivityEmerald",
        "graphite" to "MainActivityGraphite"
    )

    private fun applyLauncherIcon(rawName: String?) {
        val requested = rawName?.takeIf { it.isNotBlank() } ?: "default"
        val targetKey = if (iconAliasComponents.containsKey(requested)) requested else "default"
        val pm = applicationContext.packageManager
        val pkg = applicationContext.packageName
        for ((key, cls) in iconAliasComponents) {
            val component = ComponentName(pkg, "$pkg.$cls")
            val newState = if (key == targetKey) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(component, newState, PackageManager.DONT_KILL_APP)
        }
    }

    private fun currentEnabledIconAlias(): String {
        val pm = applicationContext.packageManager
        val pkg = applicationContext.packageName
        for ((key, cls) in iconAliasComponents) {
            val component = ComponentName(pkg, "$pkg.$cls")
            if (pm.getComponentEnabledSetting(component) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return key
            }
        }
        // No alias explicitly enabled yet → the manifest default is active.
        return "default"
    }

    // DELIVERY RELIABILITY (2026-07-16): universal "this app's settings page"
    // intent — the fallback target for every reliability deep link.
    private fun appDetailsSettingsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:$packageName"))

    // Try each intent in order until one resolves and launches; OEM settings
    // activities are undocumented and vanish between firmware versions, so
    // every candidate is best-effort.
    private fun tryStartActivities(candidates: List<Intent>): Boolean {
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // ActivityNotFound / SecurityException on this firmware — next.
            }
        }
        return false
    }

    // Last status/nav-bar icon contrast requested by Flutter (true = light bars
    // ⇒ dark icons, for a light theme). Cached so we can re-assert it when MIUI/
    // HyperOS resets the bars on resume/focus. `hasStatusBarPref` gates the
    // re-assert until Flutter has told us the real theme at least once.
    private var lastLightStatusBar = true
    private var hasStatusBarPref = false

    // Document reader: PDF page rendering runs off the UI thread (a big page can
    // take tens of ms and would jank the reader's swipe).
    private val pdfExecutor: java.util.concurrent.ExecutorService =
        java.util.concurrent.Executors.newSingleThreadExecutor()

    // Music tags fallback: MediaMetadataRetriever may take tens of ms on a big
    // file, so it runs off the UI thread too.
    private val musicTagsExecutor: java.util.concurrent.ExecutorService =
        java.util.concurrent.Executors.newSingleThreadExecutor()

    /** Title/artist via the SYSTEM parser, or null when it finds none. */
    private fun readMusicTags(path: String): Map<String, String>? {
        val retriever = android.media.MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val out = HashMap<String, String>()
            retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_TITLE)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let { out["title"] = it }
            retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_ARTIST)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let { out["artist"] = it }
            if (out.isEmpty()) null else out
        } catch (_: Throwable) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
                // best-effort
            }
        }
    }

    private fun openPdf(path: String): android.graphics.pdf.PdfRenderer {
        val file = java.io.File(path)
        if (!file.exists()) throw IllegalArgumentException("file is missing")
        val fd = android.os.ParcelFileDescriptor.open(
            file,
            android.os.ParcelFileDescriptor.MODE_READ_ONLY,
        )
        return android.graphics.pdf.PdfRenderer(fd)
    }

    private fun renderPdfPage(path: String, index: Int, targetWidth: Int): ByteArray {
        openPdf(path).use { renderer ->
            if (index < 0 || index >= renderer.pageCount) {
                throw IndexOutOfBoundsException("page $index of ${renderer.pageCount}")
            }
            renderer.openPage(index).use { page ->
                val scale = targetWidth.toFloat() / page.width.toFloat()
                val height = (page.height * scale).toInt().coerceAtLeast(1)
                val bitmap = android.graphics.Bitmap.createBitmap(
                    targetWidth,
                    height,
                    android.graphics.Bitmap.Config.ARGB_8888,
                )
                // PdfRenderer composites onto whatever is already there, so a
                // transparent bitmap yields ghosting on overlapping content.
                android.graphics.Canvas(bitmap).drawColor(android.graphics.Color.WHITE)
                page.render(
                    bitmap,
                    null,
                    null,
                    android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                )
                val out = java.io.ByteArrayOutputStream()
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                return out.toByteArray()
            }
        }
    }

    private fun applyStatusBarAppearance() {
        if (!hasStatusBarPref) return
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.isAppearanceLightStatusBars = lastLightStatusBar
        controller.isAppearanceLightNavigationBars = lastLightStatusBar
    }

    override fun onResume() {
        super.onResume()
        applyStatusBarAppearance()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyStatusBarAppearance()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/log").setMethodCallHandler { call, result ->
            if (call.method == "log") {
                val tag = call.argument<String>("tag") ?: "Secretly"
                val msg = call.argument<String>("msg") ?: ""
                // Dart side already gates this on SECRETLY_ENABLE_CALL_LOGS_IN_RELEASE
                // (default false). When that flag is on, route to logcat in both
                // debug and release — otherwise diag/op logs from instrumented
                // release builds get silently dropped here and devs can't
                // diagnose production bugs.
                Log.d(tag, msg)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Status/navigation bar icon contrast. MIUI/HyperOS ignores Flutter's
        // SystemUiOverlayStyle in edge-to-edge mode, leaving light-theme status
        // icons white (invisible on a light app background). Driving the
        // AndroidX WindowInsetsController natively, on the UI thread, is honored.
        // `light == true` ⇒ light bars ⇒ DARK icons (for a light theme).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/system_ui").setMethodCallHandler { call, result ->
            if (call.method == "setLightStatusBar") {
                val light = call.argument<Boolean>("light") ?: true
                lastLightStatusBar = light
                hasStatusBarPref = true
                runOnUiThread {
                    applyStatusBarAppearance()
                    // MIUI/HyperOS re-asserts its own bar style a beat after a
                    // theme change / resume; re-apply shortly after so the icons
                    // don't flip back to white in light theme.
                    window.decorView.postDelayed({ applyStatusBarAppearance() }, 250)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // SEC-11: скрытие содержимого экрана. `FLAG_SECURE` закрывает разом
        // снимок экрана, запись экрана и карточку в списке приложений — на
        // Android это один флаг на всё.
        //
        // 🔴 Включается ТОЛЬКО по явному выбору человека и по умолчанию
        // выключено (как в Signal). Флаг ломает не только злоумышленника:
        // перестают работать демонстрация экрана и часть средств доступности.
        // Включить его за человека — значит однажды молча лишить его звонка с
        // демонстрацией или экранного диктора.
        //
        // Флаг ставится на окно и переживает поворот и сворачивание, поэтому
        // повторно применять его на возобновлении не нужно.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/screen_privacy").setMethodCallHandler { call, result ->
            if (call.method == "setEnabled") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/app_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "supportsAlternateIcons" -> result.success(true)
                "getAlternateIconName" -> result.success(currentEnabledIconAlias())
                "setAlternateIcon" -> {
                    try {
                        applyLauncherIcon(call.argument<String>("name"))
                        result.success(true)
                    } catch (t: Throwable) {
                        Log.e("Secretly", "app_icon switch failed", t)
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/battery").setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val ignoring = pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                        if (pm?.isIgnoringBatteryOptimizations(packageName) == true) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        @SuppressLint("BatteryLife")
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            .setData(Uri.parse("package:$packageName"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w("Secretly", "battery optimization request failed: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // DELIVERY RELIABILITY (2026-07-16, delivery-wake audit): diagnostics +
        // deep links for the OS settings that silently break message delivery
        // on aggressive Android skins (battery optimization, Data Saver,
        // disabled notifications, OEM autostart). Read-only status + explicit
        // user-driven navigation — nothing is toggled programmatically.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/reliability").setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> {
                    val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val batteryUnrestricted = pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                    // Data Saver: only meaningful on API 24+. Statuses:
                    // 1=DISABLED (saver off), 2=WHITELISTED (saver on, app
                    // exempt), 3=ENABLED (saver on, background data BLOCKED).
                    val dataSaver = try {
                        val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        when (cm?.restrictBackgroundStatus) {
                            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_DISABLED -> "disabled"
                            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_WHITELISTED -> "whitelisted"
                            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED -> "enabled"
                            else -> "unknown"
                        }
                    } catch (_: Exception) {
                        "unknown"
                    }
                    val notificationsEnabled = try {
                        val nm = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        nm?.areNotificationsEnabled() ?: true
                    } catch (_: Exception) {
                        true
                    }
                    result.success(
                        mapOf(
                            "batteryUnrestricted" to batteryUnrestricted,
                            "dataSaver" to dataSaver,
                            "notificationsEnabled" to notificationsEnabled,
                            "manufacturer" to (Build.MANUFACTURER ?: "").lowercase(),
                        )
                    )
                }
                "openDataUsageSettings" -> {
                    // Lands on this app's "unrestricted data" toggle.
                    val ok = tryStartActivities(
                        listOf(
                            Intent(Settings.ACTION_IGNORE_BACKGROUND_DATA_RESTRICTIONS_SETTINGS)
                                .setData(Uri.parse("package:$packageName")),
                            appDetailsSettingsIntent(),
                        )
                    )
                    result.success(ok)
                }
                "openNotificationSettings" -> {
                    val ok = tryStartActivities(
                        listOf(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                            appDetailsSettingsIntent(),
                        )
                    )
                    result.success(ok)
                }
                "openAutostartSettings" -> {
                    // OEM autostart/battery managers have NO status API — the
                    // best we can do is land the user on the right screen.
                    // Known activities first, then vendor battery/app pages,
                    // then plain app details as the universal fallback.
                    val ok = tryStartActivities(
                        listOf(
                            // Xiaomi / Redmi / POCO (MIUI, HyperOS)
                            Intent().setComponent(
                                ComponentName(
                                    "com.miui.securitycenter",
                                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                                )
                            ),
                            // Huawei / Honor
                            Intent().setComponent(
                                ComponentName(
                                    "com.huawei.systemmanager",
                                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                                )
                            ),
                            // Oppo / Realme
                            Intent().setComponent(
                                ComponentName(
                                    "com.coloros.safecenter",
                                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                                )
                            ),
                            // Vivo
                            Intent().setComponent(
                                ComponentName(
                                    "com.vivo.permissionmanager",
                                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                                )
                            ),
                            // Samsung "sleeping apps" lives under battery care
                            Intent().setComponent(
                                ComponentName(
                                    "com.samsung.android.lool",
                                    "com.samsung.android.sm.battery.ui.BatteryActivity",
                                )
                            ),
                            appDetailsSettingsIntent(),
                        )
                    )
                    result.success(ok)
                }
                "openAppSettings" -> {
                    result.success(tryStartActivities(listOf(appDetailsSettingsIntent())))
                }
                else -> result.notImplemented()
            }
        }

        // A backup the user cannot find is not a backup. The app's own
        // documents directory is private storage: invisible to every file
        // manager and DELETED when the app is uninstalled — precisely the
        // moment a backup has to survive. This writes a copy into the public
        // Downloads collection instead, which survives uninstall and shows up
        // in Files. The payload is already encrypted with the user's backup
        // password, so a public folder is a safe home for it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/media_store").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val fileName = (call.argument<String>("fileName") ?: "").trim()
                    val sourcePath = (call.argument<String>("sourcePath") ?: "").trim()
                    // 🔴 ТИП ФАЙЛА ОБЯЗАТЕЛЕН (14.08.2026, жалоба владельца:
                    // «скачивается непонятно куда, в недавних не видно, а при
                    // пересылке превращается в .bin»).
                    //
                    // Здесь стояло жёсткое `application/octet-stream` для ЛЮБОГО
                    // файла. Для системы это значит «двоичный мусор»: установщик
                    // не предлагает поставить apk, проводник не открывает
                    // документ, а «Недавние» такой файл не показывают. Имя при
                    // этом могло быть правильным — по имени система тип НЕ
                    // выводит, она верит записи в MediaStore.
                    val mimeType = (call.argument<String>("mimeType") ?: "").trim()
                        .ifBlank { "application/octet-stream" }
                    if (fileName.isEmpty() || sourcePath.isEmpty()) {
                        result.error("bad_args", "fileName and sourcePath are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val source = File(sourcePath)
                        if (!source.exists()) {
                            result.error("no_source", "source file is missing", null)
                            return@setMethodCallHandler
                        }
                        val savedPath: String
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            // Scoped storage: MediaStore owns Downloads. Replace
                            // any previous copy with the same name so repeated
                            // auto-backups do not pile up "file (1)" duplicates.
                            val resolver = applicationContext.contentResolver
                            val collection = android.provider.MediaStore.Downloads
                                .getContentUri(android.provider.MediaStore.VOLUME_EXTERNAL_PRIMARY)
                            resolver.delete(
                                collection,
                                "${android.provider.MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
                                    "${android.provider.MediaStore.MediaColumns.RELATIVE_PATH} = ?",
                                arrayOf(fileName, "Download/Secretly/")
                            )
                            val values = android.content.ContentValues().apply {
                                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Download/Secretly/")
                                put(android.provider.MediaStore.MediaColumns.IS_PENDING, 1)
                            }
                            val uri = resolver.insert(collection, values)
                                ?: throw IllegalStateException("MediaStore refused the insert")
                            resolver.openOutputStream(uri)?.use { out ->
                                source.inputStream().use { input -> input.copyTo(out) }
                            } ?: throw IllegalStateException("MediaStore gave no output stream")
                            values.clear()
                            values.put(android.provider.MediaStore.MediaColumns.IS_PENDING, 0)
                            resolver.update(uri, values, null, null)
                            savedPath = "Download/Secretly/$fileName"
                        } else {
                            // Pre-Q: the public Downloads directory is a plain path.
                            val dir = File(
                                android.os.Environment.getExternalStoragePublicDirectory(
                                    android.os.Environment.DIRECTORY_DOWNLOADS
                                ),
                                "Secretly"
                            )
                            if (!dir.exists()) dir.mkdirs()
                            val target = File(dir, fileName)
                            source.copyTo(target, overwrite = true)
                            // 🔴 До Android 10 файл, просто положенный на диск,
                            // проводник и «Недавние» не видят, пока их указатель
                            // о нём не узнает. На Android 10+ об этом заботится
                            // сам MediaStore, здесь — приходится сказать вслух.
                            try {
                                android.media.MediaScannerConnection.scanFile(
                                    applicationContext,
                                    arrayOf(target.absolutePath),
                                    arrayOf(mimeType),
                                    null,
                                )
                            } catch (scanError: Exception) {
                                Log.w("SecretlyMediaStore", "media scan failed: ${scanError.message}")
                            }
                            savedPath = target.absolutePath
                        }
                        result.success(savedPath)
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = (call.argument<String>("text") ?: "").trim()
                    val subject = (call.argument<String>("subject") ?: "").trim()
                    if (text.isEmpty()) {
                        result.error("bad_args", "text is required", null)
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                                if (subject.isNotEmpty()) {
                                    putExtra(Intent.EXTRA_SUBJECT, subject)
                                }
                            }
                            startActivity(Intent.createChooser(sendIntent, null))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("share_failed", error.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/clipboard_media").setMethodCallHandler { call, result ->
            when (call.method) {
                "readImage" -> {
                    result.success(readClipboardImage())
                }

                "copyUri" -> {
                    val uri = (call.argument<String>("uri") ?: "").trim()
                    val mime = call.argument<String>("mime")?.trim()
                    if (uri.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(copyImageUriToCache(uri, mime, null))
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/file_open").setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val path = (call.argument<String>("path") ?: "").trim()
                    val mime = call.argument<String>("mime")?.trim()
                    if (path.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(openLocalFile(path, mime))
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/haptics").setMethodCallHandler { call, result ->
            when (call.method) {
                "keyboardTap" -> {
                    try {
                        val handled = window?.decorView?.performHapticFeedback(
                            HapticFeedbackConstants.KEYBOARD_TAP
                        ) == true
                        result.success(handled)
                    } catch (error: Exception) {
                        result.success(false)
                    }
                }

                "shortTap" -> {
                    try {
                        val durationMs = (call.argument<Int>("durationMs") ?: 10).coerceIn(6, 20)
                        val amplitude = (call.argument<Int>("amplitude") ?: 24).coerceIn(1, 64)
                        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                            manager?.defaultVibrator
                        } else {
                            @Suppress("DEPRECATION")
                            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                        }
                        if (vibrator == null || !vibrator.hasVibrator()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(
                                VibrationEffect.createOneShot(durationMs.toLong(), amplitude)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(durationMs.toLong())
                        }
                        result.success(true)
                    } catch (error: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/push_token").setMethodCallHandler { call, result ->
            when (call.method) {
                "storedFcmToken" -> result.success(
                    SecretlyFirebaseMessagingService.storedFcmToken(applicationContext)
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/picture_in_picture").setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isPictureInPictureSupported())
                "setAutoEnterEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    val aspectWidth = call.argument<Int>("aspectWidth") ?: 9
                    val aspectHeight = call.argument<Int>("aspectHeight") ?: 16
                    result.success(configurePictureInPicture(enabled, aspectWidth, aspectHeight))
                }
                "enter" -> {
                    val aspectWidth = call.argument<Int>("aspectWidth") ?: 9
                    val aspectHeight = call.argument<Int>("aspectHeight") ?: 16
                    result.success(enterPictureInPicture(aspectWidth, aspectHeight))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/picture_in_picture_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pipEventsSink = events
                    // Re-emit current state so a freshly-bound listener gets
                    // the latest value even if it subscribed after the change.
                    trySink(events, mapOf("isInPip" to lastPipMode))
                }

                override fun onCancel(arguments: Any?) {
                    pipEventsSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/network_path").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    networkPathSink = events
                    registerNetworkPathCallback()
                    emitNetworkPathSnapshot()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterNetworkPathCallback()
                    networkPathSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/call_ui").setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingNative" -> {
                    val callId = (call.argument<String>("callId") ?: "").trim()
                    val callAttemptId = (call.argument<String>("callAttemptId") ?: callId).trim()
                    val unknownName = getString(R.string.call_unknown)
                    val peerName = (call.argument<String>("peerName") ?: unknownName).trim()
                    val isVideo = call.argument<Boolean>("isVideo") == true
                    val avatarPath = call.argument<String>("avatarPath")?.trim()
                    if (callId.isEmpty()) {
                        result.error("bad_args", "callId is required", null)
                        return@setMethodCallHandler
                    }
                    if (BuildConfig.DEBUG) {
                        Log.d("NativeCallUi", "show incoming native isVideo=$isVideo")
                    }
                    val decisionToken = issueCallDecisionToken(callId, callAttemptId)
                    IncomingCallNotifier.show(
                        applicationContext,
                        callId,
                        callAttemptId,
                        decisionToken,
                        peerName,
                        isVideo,
                        avatarPath,
                        // createdAtMs removed: not available from call arguments
                    )
                    // No direct Activity launch: only heads-up notification is shown.
                    result.success(null)
                }

                // 🔴 ГРОМКАЯ СВЯЗЬ НА СОВРЕМЕННОМ ANDROID (12.08.2026).
                //
                // Полевая жалоба: громкую включил, выключить не смог — кнопка
                // нажимается, звук не меняется. В логе НИ ОДНОЙ строки о
                // маршруте: путь на Dart сводился к `Helper.setSpeakerphoneOn`
                // внутри `try/catch(_){}`, то есть молчаливый отказ выглядел
                // ровно как успех.
                //
                // `setSpeakerphoneOn` объявлен устаревшим в Android 12 (API 31).
                // В режиме разговора маршрутом владеет `setCommunicationDevice`,
                // и снять громкую можно только `clearCommunicationDevice`.
                // Устройство владельца: targetSdk 36.
                //
                // Возвращаем ПРАВДУ: применилось или нет, и какой маршрут стал
                // текущим. Догадка вместо ответа нам сегодня дорого стоила.
                "setCommunicationSpeaker" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        // До Android 12 современного механизма нет — пусть Dart
                        // идёт старым путём, но ЗНАЯ об этом.
                        result.success(mapOf("applied" to false, "reason" to "pre_api31"))
                        return@setMethodCallHandler
                    }
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        if (enabled) {
                            val speaker = am.availableCommunicationDevices.firstOrNull {
                                it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                            }
                            if (speaker == null) {
                                result.success(
                                    mapOf("applied" to false, "reason" to "no_speaker_device")
                                )
                                return@setMethodCallHandler
                            }
                            val ok = am.setCommunicationDevice(speaker)
                            result.success(
                                mapOf(
                                    "applied" to ok,
                                    "reason" to if (ok) "set_speaker" else "set_rejected",
                                    "current" to (am.communicationDevice?.type ?: -1),
                                )
                            )
                        } else {
                            // Снятие: система сама вернётся к своему выбору по
                            // умолчанию — наушнику, гарнитуре или Bluetooth.
                            am.clearCommunicationDevice()
                            result.success(
                                mapOf(
                                    "applied" to true,
                                    "reason" to "cleared",
                                    "current" to (am.communicationDevice?.type ?: -1),
                                )
                            )
                        }
                    } catch (t: Throwable) {
                        // Отдаём причину, а не проглатываем: слепота и была дефектом.
                        result.success(
                            mapOf(
                                "applied" to false,
                                "reason" to "threw_" + (t.javaClass.simpleName ?: "unknown"),
                            )
                        )
                    }
                }

                "showOngoingCallNative" -> {
                    val callId = (call.argument<String>("callId") ?: "").trim()
                    val callAttemptId = (call.argument<String>("callAttemptId") ?: callId).trim()
                    val peerName = (call.argument<String>("peerName") ?: "").trim()
                    val isVideo = call.argument<Boolean>("isVideo") == true
                    val avatarPath = call.argument<String>("avatarPath")?.trim()
                    if (callId.isNotEmpty()) {
                        if (BuildConfig.DEBUG) {
                            Log.d("NativeCallUi", "show ongoing native isVideo=$isVideo")
                        }
                        val decisionToken = issueCallDecisionToken(callId, callAttemptId)
                        IncomingCallNotifier.showOngoingCall(
                            context = applicationContext,
                            activity = this,
                            callId = callId,
                            callAttemptId = callAttemptId,
                            decisionToken = decisionToken,
                            peerName = peerName.ifEmpty { getString(R.string.call_unknown) },
                            isVideo = isVideo,
                            avatarPath = avatarPath,
                        )
                    }
                    result.success(null)
                }

                "hideOngoingCallNative" -> {
                    val callId = (call.argument<String>("callId") ?: "").trim()
                    val callAttemptId = (call.argument<String>("callAttemptId") ?: callId).trim()
                    if (BuildConfig.DEBUG) {
                        Log.d("NativeCallUi", "hide ongoing native")
                    }
                    clearCallDecisionToken(callId, callAttemptId)
                    IncomingCallNotifier.cancelOngoing(applicationContext, callId)
                    result.success(null)
                }

                // PR-G bug 20: explicit handler so Dart's _hideNativeIncomingUi
                // no longer falls through to result.notImplemented(). Prior to
                // this, every cancel/decline from Flutter raised a silent
                // MissingPluginException — the incoming notification stayed
                // visible and on rapid cancel+recall produced duplicates.
                "hideIncomingNative" -> {
                    val callId = (call.argument<String>("callId") ?: "").trim()
                    val callAttemptId = (call.argument<String>("callAttemptId") ?: callId).trim()
                    if (BuildConfig.DEBUG) {
                        Log.d("NativeCallUi", "hide incoming native callId=${callId.take(8)}")
                    }
                    if (callId.isNotEmpty()) {
                        clearCallDecisionToken(callId, callAttemptId)
                        IncomingCallNotifier.cancel(applicationContext, callId)
                    } else {
                        // Defensive: cancel ALL stray incoming notifications
                        // when caller didn't track a specific callId. Covers
                        // restart-from-killed and decisionToken-rotation paths.
                        IncomingCallNotifier.cancelAllIncoming(applicationContext)
                    }
                    result.success(null)
                }

                // 🔴 Отдаёт и очищает след о звонках, которые показала нативная
                // плашка при убитой Activity. Единственный способ для Dart
                // узнать о таком звонке: запись в ленту чата умеет писать
                // только он, а до этого следа знать было НЕЧЕГО.
                // См. MissedCallTrail.
                "drainMissedCallTrail" -> {
                    result.success(MissedCallTrail.drain(applicationContext))
                }

                // ── Foreground service for active call (process-survival) ──────────
                // Ensures Android (MIUI/EMUI/OneUI) cannot kill the Flutter process
                // while a WebRTC session is in progress.

                "startCallForegroundService" -> {
                    val callId        = (call.argument<String>("callId") ?: "").trim()
                    val callAttemptId = (call.argument<String>("callAttemptId") ?: callId).trim()
                    val peerName      = (call.argument<String>("peerName") ?: "").trim()
                    val isVideo       = call.argument<Boolean>("isVideo") == true
                    if (callId.isNotEmpty()) {
                        val decisionToken = issueCallDecisionToken(callId, callAttemptId)
                        try {
                            CallForegroundService.start(
                                context       = applicationContext,
                                callId        = callId,
                                callAttemptId = callAttemptId,
                                peerName      = peerName.ifEmpty { getString(R.string.app_name) },
                                isVideo       = isVideo,
                                decisionToken = decisionToken,
                            )
                            if (BuildConfig.DEBUG) {
                                Log.d("NativeCallUi", "CallForegroundService started callId=${callId.take(8)}")
                            }
                        } catch (e: Exception) {
                            Log.e("NativeCallUi", "Failed to start CallForegroundService: ${e.message}")
                        }
                    }
                    result.success(null)
                }

                "requestCallPermissions" -> {
                    // Only RUNTIME (dangerous) permissions can be requested via
                    // ActivityCompat.requestPermissions. FOREGROUND_SERVICE_MICROPHONE
                    // and FOREGROUND_SERVICE_CAMERA are "normal" install-time
                    // permissions on Android 14+ — they are granted at install
                    // automatically if declared in the manifest.
                    val needed = mutableListOf<String>()
                    try {
                        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            needed.add(android.Manifest.permission.RECORD_AUDIO)
                        }
                    } catch (_: Exception) {}

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                                needed.add(android.Manifest.permission.BLUETOOTH_CONNECT)
                            }
                        } catch (_: Exception) {}
                    }

                    if (needed.isEmpty()) {
                        result.success(true)
                    } else if (pendingCallPermsResult != null) {
                        // Another permission request is in-flight. Surface the
                        // current state rather than blocking the call flow.
                        val recordAudioGranted = ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.RECORD_AUDIO,
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(recordAudioGranted)
                    } else {
                        pendingCallPermsResult = result
                        try {
                            ActivityCompat.requestPermissions(
                                this,
                                needed.toTypedArray(),
                                REQUEST_CODE_CALL_PERMS,
                            )
                        } catch (error: Exception) {
                            Log.w("NativeCallUi", "requestPermissions failed: ${error.message}")
                            val pending = pendingCallPermsResult
                            pendingCallPermsResult = null
                            tryReply(pending, false)
                        }
                    }
                }

                "stopCallForegroundService" -> {
                    try {
                        CallForegroundService.stop(applicationContext)
                        if (BuildConfig.DEBUG) {
                            Log.d("NativeCallUi", "CallForegroundService stopped")
                        }
                    } catch (e: Exception) {
                        Log.e("NativeCallUi", "Failed to stop CallForegroundService: ${e.message}")
                    }
                    result.success(null)
                }

                // Switch to ring mode so Flutter's AudioPlayer routes through
                // the loudspeaker (STREAM_RING) instead of the earpiece.
                "setRingtoneMode" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        am.mode = AudioManager.MODE_RINGTONE
                    } catch (e: Exception) {
                        Log.w("NativeCallUi", "setRingtoneMode failed: ${e.message}")
                    }
                    result.success(null)
                }

                "clearAudioMode" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        am.mode = AudioManager.MODE_NORMAL
                    } catch (e: Exception) {
                        Log.w("NativeCallUi", "clearAudioMode failed: ${e.message}")
                    }
                    result.success(null)
                }

                // Android 14+: check if USE_FULL_SCREEN_INTENT is granted.
                // Returns true on pre-14 devices (always granted there).
                "canUseFullScreenIntent" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        nm.canUseFullScreenIntent()
                    } else {
                        true
                    }
                    result.success(granted)
                }

                // Open system settings so the user can grant USE_FULL_SCREEN_INTENT.
                // 🔴 ВИДИМОСТЬ РАЗРЕШЕНИЯ (13.08.2026). С Android 14 полноэкранное
                // намерение работает только с разрешением, и БЕЗ него оно молча
                // вырождается в обычную плашку — экран звонка не поднимается, а
                // причина нигде не видна. Замер, который не умеет провалиться,
                // не замер: отдаём правду в диагностику.
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        // До Android 14 разрешение не требуется вовсе.
                        result.success(mapOf("supported" to false, "granted" to true))
                    } else {
                        val granted = try {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE)
                                as android.app.NotificationManager
                            nm.canUseFullScreenIntent()
                        } catch (t: Throwable) {
                            false
                        }
                        result.success(mapOf("supported" to true, "granted" to granted))
                    }
                }

                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                        } catch (e: Exception) {
                            Log.w("NativeCallUi", "requestFullScreenIntentPermission failed: ${e.message}")
                        }
                    }
                    result.success(null)
                }

                // Returns the OEM family name used to surface autostart prompts:
                // "xiaomi", "huawei", "oppo", "vivo", "samsung", or "generic".
                "oemFamily" -> {
                    result.success(detectOemFamily())
                }

                // Opens the OEM-specific autostart / background-launch settings
                // screen so the user can permit the app to be woken by FCM
                // pushes while killed (the root cause of "incoming call doesn't
                // arrive when app is closed" on MIUI/HyperOS).
                "openAutostartSettings" -> {
                    result.success(openAutostartSettings())
                }

                // Opens the app's notification settings so the user can verify
                // that the "Incoming calls" channel is enabled (some OEM bulk
                // notification cleaners disable it after long inactivity).
                "openAppNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w("NativeCallUi", "openAppNotificationSettings failed: ${e.message}")
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/call_actions").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    callActionSink = events
                    emitPendingCallDecisionIfAny()
                    handleCallDecisionIntent(intent)
                }

                override fun onCancel(arguments: Any?) {
                    callActionSink = null
                }
            }
        )

        // ── Message notifications (native MessagingStyle) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/msg_notif").setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val convoId = (call.argument<String>("convoId") ?: "").trim()
                    val title = (call.argument<String>("title") ?: "").trim()
                    val body = (call.argument<String>("body") ?: "").trim()
                    val avatarPath = call.argument<String>("avatarPath")?.trim()
                    val playSound = call.argument<Boolean>("playSound") ?: true
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    if (convoId.isEmpty()) {
                        result.error("bad_args", "convoId is required", null)
                        return@setMethodCallHandler
                    }
                    MessageNotifier.show(
                        context = applicationContext,
                        convoId = convoId,
                        title = title.ifEmpty { getString(R.string.app_name) },
                        body = body.ifEmpty { getString(R.string.notification_message_new) },
                        avatarPath = avatarPath,
                        playSound = playSound,
                        vibrate = vibrate,
                    )
                    result.success(null)
                }

                "cancel" -> {
                    val convoId = (call.argument<String>("convoId") ?: "").trim()
                    if (convoId.isNotEmpty()) {
                        MessageNotifier.cancel(applicationContext, convoId)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/media_notif").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val state = MediaPlaybackService.MediaNotificationState.fromMap(call.arguments as? Map<*, *>)
                    if (state == null) {
                        result.error("bad_args", "state is required", null)
                        return@setMethodCallHandler
                    }
                    MediaPlaybackService.showOrUpdate(applicationContext, state)
                    result.success(null)
                }

                "clear" -> {
                    MediaPlaybackService.clear(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // ── In-app document reader (2026-07-29) ───────────────────────────────
        // Renders PDF pages with the SYSTEM renderer (android.graphics.pdf.
        // PdfRenderer) and hands Flutter plain PNG bytes, so the reader UI is
        // ours (same chrome as the photo viewer) while the parsing of an
        // UNTRUSTED file stays inside the OS component Google patches — we do not
        // bundle a PDF engine of our own into an E2EE app, and the APK does not
        // grow. Rendering happens on a worker thread; the page bitmap is drawn on
        // white first because PdfRenderer composites onto transparency.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/pdf").setMethodCallHandler { call, result ->
            when (call.method) {
                "pageCount" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    pdfExecutor.execute {
                        try {
                            val count = openPdf(path).use { renderer -> renderer.pageCount }
                            runOnUiThread { result.success(count) }
                        } catch (error: Throwable) {
                            runOnUiThread { result.error("pdf_open_failed", error.message, null) }
                        }
                    }
                }

                "renderPage" -> {
                    val path = call.argument<String>("path")
                    val index = call.argument<Int>("index") ?: 0
                    val targetWidth = (call.argument<Int>("width") ?: 1080).coerceIn(120, 4096)
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    pdfExecutor.execute {
                        try {
                            val png = renderPdfPage(path, index, targetWidth)
                            runOnUiThread { result.success(png) }
                        } catch (error: Throwable) {
                            runOnUiThread { result.error("pdf_render_failed", error.message, null) }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── Music tags fallback (17.09.2026) ─────────────────────────────────
        // Название и исполнитель песни, когда их не прочла библиотека тегов
        // (Rust): она не видит M4A, у которого служебный блок `moov` стоит после
        // данных (так по умолчанию пишет, например, ffmpeg), и такие песни
        // уходили без подписи. Читает система (MediaMetadataRetriever) — разбор
        // чужого файла остаётся в ОС. Dart: lib/media/music_tags.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/music_tags").setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("bad_args", "path is required", null)
                return@setMethodCallHandler
            }
            musicTagsExecutor.execute {
                val tags = readMusicTags(path)
                runOnUiThread { result.success(tags) }
            }
        }

        // ── Notification tap → open conversation EventChannel ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/notif_tap").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    notifTapSink = events
                    handleOpenConvoIntent(intent)
                }

                override fun onCancel(arguments: Any?) {
                    notifTapSink = null
                }
            }
        )

        // ── Message actions (reply / mark-read) from notification buttons ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/msg_actions").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    msgActionSink = events
                    handleMsgActionIntent(intent)
                }

                override fun onCancel(arguments: Any?) {
                    msgActionSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/media_actions").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mediaActionSink = events
                    emitPendingMediaActionIfAny()
                }

                override fun onCancel(arguments: Any?) {
                    mediaActionSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "secretly/share_intents").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareIntentSink = events
                    emitPendingSharePayloadIfAny()
                    handleIncomingShareIntent(intent)
                }

                override fun onCancel(arguments: Any?) {
                    shareIntentSink = null
                }
            }
        )

        handleCallDecisionIntent(intent)
        handleOpenConvoIntent(intent)
        handleMsgActionIntent(intent)
        handleIncomingShareIntent(intent)
    }

    private fun emitPendingMediaActionIfAny() {
        val sink = mediaActionSink ?: return
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val action = (prefs.getString(PENDING_MEDIA_ACTION, "") ?: "").trim().lowercase()
        if (action.isEmpty()) {
            return
        }
        if (trySink(sink, mapOf("action" to action))) {
            prefs.edit().remove(PENDING_MEDIA_ACTION).apply()
        }
    }

    private fun emitPendingSharePayloadIfAny() {
        val sink = shareIntentSink ?: return
        val payload = pendingSharePayload ?: return
        pendingSharePayload = null
        trySink(sink, payload)
    }

    private fun handleIncomingShareIntent(intent: Intent?) {
        val i = intent ?: return
        val action = i.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return
        }
        val payload = buildSharePayload(i) ?: return
        val sink = shareIntentSink
        if (sink == null) {
            pendingSharePayload = payload
        } else {
            pendingSharePayload = null
            trySink(sink, payload)
        }
        i.action = null
    }

    private fun buildSharePayload(intent: Intent): Map<String, Any?>? {
        val files = mutableListOf<Map<String, Any?>>()
        val fallbackMime = intent.type?.trim()?.takeIf { it.isNotEmpty() && it != "*/*" }
        val uris = if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            getShareStreamUris(intent)
        } else {
            getShareStreamUri(intent)?.let { listOf(it) } ?: emptyList()
        }
        for (uri in uris) {
            val copied = copySharedUriToCache(uri, fallbackMime)
            if (copied != null) {
                files.add(copied)
            }
        }
        val text = (intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: "").trim()
        if (files.isEmpty() && text.isEmpty()) {
            return null
        }
        return mapOf(
            "files" to files,
            "text" to text.takeIf { it.isNotEmpty() },
        )
    }

    private fun readClipboardImage(): Map<String, Any?>? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            ?: return null
        val clip = clipboard.primaryClip ?: return null
        val description = clipboard.primaryClipDescription
        if (description != null && !description.hasMimeType("image/*")) {
            var anyContentUri = false
            for (index in 0 until clip.itemCount) {
                if (clipboardItemUri(clip.getItemAt(index)) != null) {
                    anyContentUri = true
                    break
                }
            }
            if (!anyContentUri) return null
        }

        for (index in 0 until clip.itemCount) {
            val uri = clipboardItemUri(clip.getItemAt(index)) ?: continue
            val copied = copyImageUriToCache(uri.toString(), null, description)
            if (copied != null) return copied
        }
        return null
    }

    private fun openLocalFile(path: String, mime: String?): Boolean {
        return try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                return false
            }
            val uri = FileProvider.getUriForFile(
                this,
                "${BuildConfig.APPLICATION_ID}.fileprovider",
                file,
            )
            val resolvedMime = resolveLocalFileMime(file, mime)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, resolvedMime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (error: ActivityNotFoundException) {
            false
        } catch (error: Exception) {
            Log.w("Secretly", "open local file failed: ${error.message}")
            false
        }
    }

    private fun resolveLocalFileMime(file: File, mime: String?): String {
        val normalized = mime?.trim()?.lowercase().orEmpty()
        if (normalized.isNotEmpty() && normalized != "application/octet-stream") {
            return normalized
        }
        val ext = file.extension.trim().lowercase()
        if (ext.isNotEmpty()) {
            val guessed = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            if (!guessed.isNullOrBlank()) {
                return guessed
            }
        }
        return "*/*"
    }

    private fun clipboardItemUri(item: android.content.ClipData.Item): Uri? {
        item.uri?.let { return it }
        val rawText = item.text?.toString()?.trim().orEmpty()
        if (rawText.startsWith("content://") || rawText.startsWith("file://")) {
            return runCatching { Uri.parse(rawText) }.getOrNull()
        }
        return null
    }

    private fun copyImageUriToCache(
        rawUri: String,
        fallbackMime: String?,
        description: ClipDescription?,
    ): Map<String, Any?>? {
        val uri = runCatching { Uri.parse(rawUri) }.getOrNull() ?: return null
        val mime = imageMimeForUri(uri, fallbackMime, description) ?: return null
        return copySharedUriToCache(uri, mime)
    }

    private fun imageMimeForUri(
        uri: Uri,
        fallbackMime: String?,
        description: ClipDescription?,
    ): String? {
        val resolverMime = runCatching { applicationContext.contentResolver.getType(uri) }
            .getOrNull()
        val candidates = listOf(resolverMime, fallbackMime, guessMimeFromUri(uri))
        for (candidate in candidates) {
            val normalized = candidate?.trim()?.lowercase() ?: continue
            if (normalized.startsWith("image/")) return normalized
        }
        return if (description?.hasMimeType("image/*") == true) "image/jpeg" else null
    }

    @Suppress("DEPRECATION")
    private fun getShareStreamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
    }

    @Suppress("DEPRECATION")
    private fun getShareStreamUris(intent: Intent): List<Uri> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java).orEmpty()
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }
    }

    private fun copySharedUriToCache(uri: Uri, fallbackMime: String?): Map<String, Any?>? {
        return try {
            val resolver = applicationContext.contentResolver
            val mime = resolver.getType(uri)
                ?: fallbackMime
                ?: guessMimeFromUri(uri)
                ?: "application/octet-stream"
            val displayName = resolveDisplayName(uri) ?: "shared_${System.currentTimeMillis()}"
            val safeName = sanitizeFileName(displayName).ifBlank { "shared" }
            val incomingShareDir = File(this.cacheDir, "incoming_share").apply { mkdirs() }
            pruneOldShareCache(incomingShareDir)
            val outFile = File(incomingShareDir, "${System.currentTimeMillis()}_${UUID.randomUUID()}_$safeName")
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            mapOf(
                "path" to outFile.absolutePath,
                "mime" to mime,
                "name" to displayName,
            )
        } catch (error: Exception) {
            Log.w("SecretlyShare", "copy shared uri failed: ${error.message}")
            null
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        val resolver = applicationContext.contentResolver
        if (uri.scheme == "content") {
            try {
                resolver.query(uri, arrayOf("_display_name"), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex("_display_name")
                        if (index >= 0) {
                            val value = cursor.getString(index)?.trim()
                            if (!value.isNullOrEmpty()) return value
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }
        return uri.lastPathSegment
            ?.substringAfterLast('/')
            ?.substringAfterLast('\\')
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    private fun guessMimeFromUri(uri: Uri): String? {
        val ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString()).trim().lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }

    private fun sanitizeFileName(name: String): String {
        return name.trim().replace(Regex("[^A-Za-z0-9._-]"), "_").take(96)
    }

    private fun pruneOldShareCache(dir: File) {
        val cutoff = System.currentTimeMillis() - (3L * 24L * 60L * 60L * 1000L)
        dir.listFiles()?.forEach { file ->
            if (file.isFile && file.lastModified() < cutoff) {
                file.delete()
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipAutoEnterEnabled && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPictureInPicture(pipAspectRatio.numerator, pipAspectRatio.denominator)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        lastPipMode = isInPictureInPictureMode
        if (BuildConfig.DEBUG) {
            Log.d("Secretly", "picture-in-picture mode changed enabled=$isInPictureInPictureMode")
        }
        val sink = pipEventsSink
        if (sink != null) {
            runOnUiThread {
                try {
                    trySink(sink, mapOf("isInPip" to isInPictureInPictureMode))
                } catch (_: Exception) {
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_CALL_PERMS) {
            // RECORD_AUDIO is the only RUNTIME perm we strictly need for calls.
            // BLUETOOTH_CONNECT denial degrades BT routing but doesn't block the
            // call, so we report success when at least RECORD_AUDIO is granted.
            val grantedByPerm = permissions.zip(grantResults.toList()).toMap()
            val recordAudioGranted =
                grantedByPerm[android.Manifest.permission.RECORD_AUDIO] == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.RECORD_AUDIO,
                    ) == PackageManager.PERMISSION_GRANTED
            val pending = pendingCallPermsResult
            pendingCallPermsResult = null
            tryReply(pending, recordAudioGranted)
        }
    }

    override fun onStart() {
        super.onStart()
        isAppForeground.set(true)
    }

    override fun onStop() {
        isAppForeground.set(false)
        super.onStop()
    }

    override fun onPause() {
        super.onPause()
        // If the user dismissed the permission dialog by backgrounding the
        // activity, onRequestPermissionsResult may never fire — release the
        // pending Dart Future so the call flow doesn't hang indefinitely.
        val pending = pendingCallPermsResult
        if (pending != null) {
            val recordAudioGranted = ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.RECORD_AUDIO,
            ) == PackageManager.PERMISSION_GRANTED
            pendingCallPermsResult = null
            tryReply(pending, recordAudioGranted)
        }
    }

    private fun registerNetworkPathCallback() {
        if (networkPathCallback != null) return
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                emitNetworkPathSnapshot()
            }

            override fun onLost(network: Network) {
                emitNetworkPathSnapshot()
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                emitNetworkPathSnapshot()
            }
        }
        networkPathCallback = callback
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.registerDefaultNetworkCallback(callback)
            } else {
                manager.registerNetworkCallback(NetworkRequest.Builder().build(), callback)
            }
        } catch (error: Exception) {
            networkPathCallback = null
            if (BuildConfig.DEBUG) {
                Log.w("Secretly", "network path callback failed: ${error.message}")
            }
        }
    }

    private fun unregisterNetworkPathCallback() {
        val callback = networkPathCallback ?: return
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        try {
            manager.unregisterNetworkCallback(callback)
        } catch (_: Exception) {
        } finally {
            networkPathCallback = null
        }
    }

    private fun emitNetworkPathSnapshot() {
        val sink = networkPathSink ?: return
        val payload = buildNetworkPathSnapshot()
        runOnUiThread {
            trySink(sink, payload)
        }
    }

    private fun buildNetworkPathSnapshot(): Map<String, Any> {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return mapOf(
                "available" to false,
                "transports" to emptyList<String>(),
                "signature" to "unavailable",
            )
        val network = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.activeNetwork
        } else {
            null
        }
        val capabilities = network
            ?.let { manager.getNetworkCapabilities(it) }
            ?.takeIf { it.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) }
        val transports = linkedSetOf<String>()
        val available = capabilities != null
        val metered = available &&
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) != true
        if (capabilities != null) {
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                transports.add("wifi")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                transports.add("cellular")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                transports.add("ethernet")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                transports.add("vpn")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) {
                transports.add("bluetooth")
            }
        }
        val transportList = transports.toList().sorted()
        // F9 (2026-05-16, B1): include LinkProperties.interfaceName and
        // sorted DNS server list so handovers between two networks that
        // happen to reuse the same Network object identity (rare, but seen
        // on some MIUI/EMUI ROMs during VoLTE handover) still produce a
        // different signature. The Flutter recovery path keys off
        // forcePathChanged, so any handover that is invisible here means
        // ICE recovery only fires after WebRTC's ~30s disconnect timeout.
        val linkProperties = network?.let { manager.getLinkProperties(it) }
        val interfaceName = linkProperties?.interfaceName ?: ""
        val dnsServers = linkProperties?.dnsServers
            ?.map { it.hostAddress ?: it.toString() }
            ?.sorted()
            ?.joinToString(",")
            ?: ""
        val signature = listOf(
            transportList.joinToString("+"),
            network?.toString() ?: "",
            if (metered) "metered" else "unmetered",
            "if=$interfaceName",
            "dns=$dnsServers",
        ).joinToString("|")
        return mapOf(
            "available" to available,
            "transports" to transportList,
            "metered" to metered,
            "signature" to signature,
        )
    }

    private fun isPictureInPictureSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun safePictureInPictureRatio(aspectWidth: Int, aspectHeight: Int): Rational {
        val width = aspectWidth.coerceIn(1, 239)
        val height = aspectHeight.coerceIn(1, 239)
        return Rational(width, height)
    }

    private fun buildPictureInPictureParams(
        enabled: Boolean,
        aspectWidth: Int,
        aspectHeight: Int
    ): PictureInPictureParams? {
        if (!isPictureInPictureSupported()) {
            return null
        }
        pipAspectRatio = safePictureInPictureRatio(aspectWidth, aspectHeight)
        val builder = PictureInPictureParams.Builder().setAspectRatio(pipAspectRatio)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(enabled)
        }
        return builder.build()
    }

    private fun configurePictureInPicture(
        enabled: Boolean,
        aspectWidth: Int,
        aspectHeight: Int
    ): Boolean {
        pipAutoEnterEnabled = enabled
        val params = buildPictureInPictureParams(enabled, aspectWidth, aspectHeight) ?: return false
        return try {
            setPictureInPictureParams(params)
            true
        } catch (error: Exception) {
            Log.w("Secretly", "picture-in-picture configure failed: ${error.message}")
            false
        }
    }

    private fun enterPictureInPicture(aspectWidth: Int, aspectHeight: Int): Boolean {
        val params = buildPictureInPictureParams(true, aspectWidth, aspectHeight) ?: return false
        return try {
            enterPictureInPictureMode(params)
        } catch (error: Exception) {
            Log.w("Secretly", "picture-in-picture enter failed: ${error.message}")
            false
        }
    }

    private fun detectOemFamily(): String {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val brand = (Build.BRAND ?: "").lowercase()
        return when {
            manufacturer.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco") -> "xiaomi"
            manufacturer.contains("huawei") || brand.contains("honor") -> "huawei"
            manufacturer.contains("oppo") || brand.contains("realme") -> "oppo"
            manufacturer.contains("vivo") -> "vivo"
            manufacturer.contains("samsung") -> "samsung"
            else -> "generic"
        }
    }

    /**
     * Opens the OEM-specific autostart / background-launch settings screen so
     * the user can allow Secretly to be woken by FCM while killed. Returns
     * true if an OEM screen was opened, false if we fell back to the generic
     * app-details screen.
     */
    private fun openAutostartSettings(): Boolean {
        val candidates: List<Intent> = when (detectOemFamily()) {
            "xiaomi" -> listOf(
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    )
                ),
            )
            "huawei" -> listOf(
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    )
                ),
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity",
                    )
                ),
            )
            "oppo" -> listOf(
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                    )
                ),
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity",
                    )
                ),
            )
            "vivo" -> listOf(
                Intent().setComponent(
                    android.content.ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                    )
                ),
            )
            else -> emptyList()
        }
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Try next candidate; OEM activity may not exist on this build.
            } catch (e: Exception) {
                Log.w("NativeCallUi", "openAutostartSettings candidate failed: ${e.message}")
            }
        }
        // Fallback: app-details screen — better than nothing.
        return try {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
            false
        } catch (e: Exception) {
            Log.w("NativeCallUi", "openAutostartSettings fallback failed: ${e.message}")
            false
        }
    }

    private fun handleCallDecisionIntent(intent: Intent?) {
        val i = intent ?: return
        if (i.action != ACTION_CALL_DECISION) return
        val callId = (i.getStringExtra(EXTRA_CALL_ID) ?: "").trim()
        val callAttemptId = (i.getStringExtra(EXTRA_CALL_ATTEMPT_ID) ?: callId).trim()
        val decision = (i.getStringExtra(EXTRA_DECISION) ?: "").trim().lowercase()
        val decisionToken = (i.getStringExtra(EXTRA_CALL_DECISION_TOKEN) ?: "").trim()
        if (callId.isEmpty() || decision.isEmpty()) return
        if (!isValidCallDecisionToken(callId, callAttemptId, decisionToken)) {
            // 🔴 В РЕЛИЗЕ ЭТО БЫЛО МОЛЧА (13.08.2026). Замер холодного старта:
            // человек нажал «Принять», в чате появился «пропущенный вызов», а в
            // логе НИ ОДНОЙ строки о том, что стало с нажатием. Отброшенное
            // решение обязано называть себя — иначе разбирать нечего.
            Log.w("NativeCallUi", "call decision DROPPED invalid token decision=$decision callId=$callId")
            i.action = null
            return
        }
        // 🔴 "tap" — the user tapped the notification BODY — is NOT a decision.
        // It neither answers nor rejects, so it must not silence the ring: the
        // Accept / Decline buttons have to survive it. Everything that dismisses
        // the incoming UI below is therefore gated on `dismissesRing`.
        //
        // (2026-08-06) This branch used to cancel the notification and `return`
        // right here, on the assumption that Flutter would raise the incoming
        // screen from onAppLifecycleStateChanged. That holds only for an app
        // that was ALREADY alive. On a cold start the ring is posted by the
        // native FCM service and Dart knows nothing about the call, so the tap
        // killed the ring and told Flutter nothing — leaving the user in an
        // empty app with no way left to answer. The tap was worse than doing
        // nothing at all. It now travels the same delivery path as every other
        // decision; only the dismissal is withheld.
        val dismissesRing = decision != "tap"
        // 🔴 СЛЕД ПРОПУЩЕННОГО СНИМАЕТ ЛЮБОЕ РЕШЕНИЕ, А НЕ ТОЛЬКО КНОПКА
        // ПРИЁМНИКА (14.08.2026, замер звонка d41fdf11).
        //
        // `MissedCallTrail.remove` звался ровно из `CallActionReceiver`. Но
        // кнопки «Принять» и «Отклонить» на плашке — это `PendingIntent
        // .getActivity` прямо сюда, в MainActivity, мимо приёмника. Поэтому
        // след доживал до вычерпывания (`trail drain size=1` СРАЗУ ПОСЛЕ
        // «Принять»), и человек, взявший трубку, получал в ленте «пропущенный
        // вызов».
        //
        // `tap` не снимает: он не решение, звонок после него ещё можно принять.
        if (dismissesRing) {
            MissedCallTrail.remove(applicationContext, callId)
        }
        // Do NOT clear the intent action when the EventChannel sink is not yet
        // registered (cold-start scenario). Leave it intact so the second call
        // from onListen — where the sink IS available — can deliver the event.
        val sink = callActionSink
        if (sink == null) {
            Log.d("NativeCallUi", "call decision BUFFERED action=$decision callId=$callId")
            // A tap is deliberately NOT written to the pending-decision prefs.
            // There is one slot and the last writer wins, so a tap landing after
            // the user already pressed Answer would silently discard that answer.
            // Nothing is lost by skipping it: the intent action stays intact, so
            // the onListen pass — where the sink DOES exist — delivers the tap.
            if (dismissesRing) {
                // Cancel/dismiss the incoming notification / fullscreen UI immediately
                IncomingCallNotifier.cancel(applicationContext, callId)
                IncomingCallActivity.finishCurrent()
                val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
                prefs.edit()
                    .putString(PENDING_CALL_ID, callId)
                    .putString(PENDING_CALL_ATTEMPT_ID, callAttemptId)
                    .putString(PENDING_CALL_DECISION, decision)
                    .apply()
            }
            return
        }
        run {
            Log.d("NativeCallUi", "call decision EMITTED action=$decision callId=$callId")
        }
        if (dismissesRing) {
            // Cancel/dismiss the incoming notification / fullscreen UI now that
            // we received a concrete decision and will forward it to Flutter.
            IncomingCallNotifier.cancel(applicationContext, callId)
            IncomingCallActivity.finishCurrent()
        }
        trySink(
            sink,
            mapOf(
                "callId" to callId,
                "callAttemptId" to callAttemptId,
                "action" to decision,
            ),
        )
        // Same reasoning as the buffer branch: a tap is not a decision, so it
        // must not erase one that is waiting to be flushed.
        if (dismissesRing) {
            clearPendingCallDecision()
        }
        i.action = null
    }

    private fun emitPendingCallDecisionIfAny() {
        val sink = callActionSink ?: return
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
        val callId = (prefs.getString(PENDING_CALL_ID, "") ?: "").trim()
        val callAttemptId = (prefs.getString(PENDING_CALL_ATTEMPT_ID, callId) ?: callId).trim()
        val decision = (prefs.getString(PENDING_CALL_DECISION, "") ?: "").trim().lowercase()
        if (callId.isEmpty() || decision.isEmpty()) return
        // 🔴 Тоже было молча в релизе. Это ПОСЛЕДНЕЕ звено моста холодного
        // старта: нажатие сохранено в настройках, приложение поднялось, канал
        // событий подписался — и вот здесь решение уходит в приложение. Если в
        // логе нет ни «BUFFERED», ни этой строки, значит мост оборван, и видно
        // где именно.
        Log.d("NativeCallUi", "pending call decision DELIVERED action=$decision callId=$callId")
        // Cancel/dismiss any lingering incoming notification / UI before
        // delivering the buffered decision to Flutter.
        IncomingCallNotifier.cancel(applicationContext, callId)
        IncomingCallActivity.finishCurrent()
        // Решение снимается из буфера ТОЛЬКО если оно действительно доставлено:
        // иначе нажатие «Принять» пропадёт вместе с мёртвым движком.
        if (trySink(
                sink,
                mapOf(
                    "callId" to callId,
                    "callAttemptId" to callAttemptId,
                    "action" to decision,
                ),
            )
        ) {
            clearPendingCallDecision()
        }
    }

    override fun onDestroy() {
        // 🔴 Статическая ссылка на приёмник обязана уйти вместе с движком —
        // иначе нажатие в уведомлении после уничтожения экрана бьёт в мёртвый
        // движок (Play Console 531: FlutterJNI / DartMessenger).
        clearStaticSinks()
        super.onDestroy()
    }

    private fun clearPendingCallDecision() {
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
        prefs.edit()
            .remove(PENDING_CALL_ID)
            .remove(PENDING_CALL_ATTEMPT_ID)
            .remove(PENDING_CALL_DECISION)
            .apply()
    }

    private fun issueCallDecisionToken(callId: String, callAttemptId: String): String {
        val normalizedAttemptId = callAttemptId.ifBlank { callId }
        val token = UUID.randomUUID().toString()
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
        prefs.edit()
            .putString(ACTIVE_CALL_ID, callId)
            .putString(ACTIVE_CALL_ATTEMPT_ID, normalizedAttemptId)
            .putString(ACTIVE_CALL_DECISION_TOKEN, token)
            .apply()
        return token
    }

    private fun clearCallDecisionToken(callId: String, callAttemptId: String) {
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
        val storedCallId = (prefs.getString(ACTIVE_CALL_ID, "") ?: "").trim()
        val storedAttemptId =
            (prefs.getString(ACTIVE_CALL_ATTEMPT_ID, storedCallId) ?: storedCallId).trim()
        val normalizedAttemptId = callAttemptId.ifBlank { callId }
        if (storedCallId != callId || storedAttemptId != normalizedAttemptId) {
            return
        }
        prefs.edit()
            .remove(ACTIVE_CALL_ID)
            .remove(ACTIVE_CALL_ATTEMPT_ID)
            .remove(ACTIVE_CALL_DECISION_TOKEN)
            .apply()
    }

    private fun isValidCallDecisionToken(callId: String, callAttemptId: String, token: String): Boolean {
        if (token.isBlank()) {
            return false
        }
        val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, MODE_PRIVATE)
        val storedCallId = (prefs.getString(ACTIVE_CALL_ID, "") ?: "").trim()
        val storedAttemptId =
            (prefs.getString(ACTIVE_CALL_ATTEMPT_ID, storedCallId) ?: storedCallId).trim()
        val storedToken = (prefs.getString(ACTIVE_CALL_DECISION_TOKEN, "") ?: "").trim()
        val normalizedAttemptId = callAttemptId.ifBlank { callId }
        return storedCallId == callId &&
            storedAttemptId == normalizedAttemptId &&
            storedToken.isNotBlank() &&
            storedToken == token
    }

    private fun handleOpenConvoIntent(intent: Intent?) {
        val i = intent ?: return
        if (i.action != ACTION_OPEN_CONVO) return
        val convoId = (i.getStringExtra("convo_id") ?: "").trim()
        if (convoId.isEmpty()) return
        if (BuildConfig.DEBUG) {
            Log.i(
                "Sly/Diag",
                "event=notif.open_convo convo=" + convoId.take(8) +
                    " has_sink=" + (notifTapSink != null),
            )
        }
        // Cancel the notification since the user tapped it.
        MessageNotifier.cancel(applicationContext, convoId)
        val sink = notifTapSink ?: return
        trySink(sink, convoId)
        i.action = null
    }

    private fun handleMsgActionIntent(intent: Intent?) {
        val i = intent ?: return
        when (i.action) {
            ACTION_MSG_REPLY -> {
                val convoId = (i.getStringExtra(MessageActionReceiver.EXTRA_CONVO_ID) ?: "").trim()
                val text = (i.getStringExtra(MessageActionReceiver.KEY_TEXT_REPLY) ?: "").trim()
                if (convoId.isEmpty() || text.isEmpty()) return
                val sink = msgActionSink ?: return
                if (trySink(
                        sink,
                        mapOf(
                            "action" to "reply",
                            "convoId" to convoId,
                            "text" to text,
                        ),
                    )
                ) {
                    i.action = null
                }
            }
            ACTION_MSG_MARK_READ -> {
                val convoId = (i.getStringExtra(MessageActionReceiver.EXTRA_CONVO_ID) ?: "").trim()
                if (convoId.isEmpty()) return
                val sink = msgActionSink ?: return
                if (trySink(
                        sink,
                        mapOf(
                            "action" to "mark_read",
                            "convoId" to convoId,
                        ),
                    )
                ) {
                    i.action = null
                }
            }
        }
    }
}
