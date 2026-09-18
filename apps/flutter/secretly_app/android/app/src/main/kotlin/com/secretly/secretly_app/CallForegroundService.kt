package com.secretly.secretly_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Foreground service that keeps the Flutter process alive during an active call.
 *
 * Android (especially MIUI / EMUI / OneUI) aggressively kills background
 * processes. A regular notification does NOT prevent this — only a Service
 * that has called startForeground() is guaranteed to survive. This service
 * uses phoneCall + microphone/camera foreground service types so the OS treats
 * WebRTC capture as an active call on Android 14+ instead of revoking mic/video
 * access when the Flutter UI goes to background.
 *
 * Lifecycle (driven by call_manager.dart via MethodChannel):
 *   start(callId, peerName, isVideo)  → called on connecting / connected
 *   stop()                             → called on ended / idle
 *
 * WakeLock: A PARTIAL_WAKE_LOCK is held for the duration to prevent CPU
 * throttling that would freeze WebRTC packet processing on some devices.
 */
class CallForegroundService : Service() {

    companion object {
        private const val TAG = "CallFgService"
        private const val CHANNEL_ID = "secretly_active_call"
        private const val NOTIFICATION_ID = 42001

        const val ACTION_START = "com.secretly.secretly_app.CALL_SERVICE_START"
        const val ACTION_STOP  = "com.secretly.secretly_app.CALL_SERVICE_STOP"
        const val ACTION_HANGUP = "com.secretly.secretly_app.CALL_SERVICE_HANGUP"

        const val EXTRA_CALL_ID         = "call_id"
        const val EXTRA_CALL_ATTEMPT_ID = "call_attempt_id"
        const val EXTRA_PEER_NAME       = "peer_name"
        const val EXTRA_IS_VIDEO        = "is_video"
        const val EXTRA_DECISION_TOKEN  = "decision_token"

        private const val WAKE_LOCK_TAG = "secretly:CallForegroundService"

        fun start(
            context: Context,
            callId: String,
            callAttemptId: String,
            peerName: String,
            isVideo: Boolean,
            decisionToken: String,
        ) {
            val intent = Intent(context.applicationContext, CallForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_CALL_ATTEMPT_ID, callAttemptId)
                putExtra(EXTRA_PEER_NAME, peerName)
                putExtra(EXTRA_IS_VIDEO, isVideo)
                putExtra(EXTRA_DECISION_TOKEN, decisionToken)
            }
            ContextCompat.startForegroundService(context.applicationContext, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context.applicationContext, CallForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.applicationContext.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var currentCallId: String = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        acquireWakeLock()
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "CallForegroundService created")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val callId         = (intent.getStringExtra(EXTRA_CALL_ID) ?: "").trim()
                val callAttemptId  = (intent.getStringExtra(EXTRA_CALL_ATTEMPT_ID) ?: callId).trim()
                val peerName       = (intent.getStringExtra(EXTRA_PEER_NAME) ?: "").trim()
                val isVideo        = intent.getBooleanExtra(EXTRA_IS_VIDEO, false)
                val decisionToken  = (intent.getStringExtra(EXTRA_DECISION_TOKEN) ?: "").trim()

                currentCallId = callId
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "start callId=${callId.take(8)} isVideo=$isVideo")
                }

                val notification = buildNotification(
                    callId = callId,
                    callAttemptId = callAttemptId,
                    peerName = peerName,
                    isVideo = isVideo,
                    decisionToken = decisionToken,
                )
                startForegroundCompat(notification, isVideo)
            }

            ACTION_STOP -> {
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "stop requested")
                }
                stopForegroundAndSelf()
            }

            ACTION_HANGUP -> {
                // Relay the hangup action back to the Flutter app, then stop.
                val callId        = (intent.getStringExtra(EXTRA_CALL_ID) ?: currentCallId).trim()
                val callAttemptId = (intent.getStringExtra(EXTRA_CALL_ATTEMPT_ID) ?: callId).trim()
                val decisionToken = (intent.getStringExtra(EXTRA_DECISION_TOKEN) ?: "").trim()
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "hangup from notification callId=${callId.take(8)}")
                }
                routeHangupToFlutter(callId = callId, callAttemptId = callAttemptId, decisionToken = decisionToken)
                stopForegroundAndSelf()
            }

            else -> {
                // Restarted by system after being killed — re-attach foreground
                // with a minimal notification. Flutter will send ACTION_STOP
                // once it realises the call is over.
                if (currentCallId.isEmpty()) {
                    stopForegroundAndSelf()
                } else {
                    startForegroundCompat(buildNotification(
                        callId = currentCallId,
                        callAttemptId = currentCallId,
                        peerName = "",
                        isVideo = false,
                        decisionToken = "",
                    ), isVideo = false)
                }
            }
        }
        // START_STICKY so the OS restarts us if killed while a call is active.
        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "CallForegroundService destroyed")
        }
        super.onDestroy()
    }

    // ── Foreground helpers ────────────────────────────────────────────────────

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun startForegroundCompat(notification: Notification, isVideo: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 14+ (and strictly enforced on 15/16 with targetSDK 34+)
                // throws SecurityException if we declare a MICROPHONE/CAMERA
                // foreground-service type WITHOUT the matching runtime permission
                // already granted. Only add each type when its permission is
                // actually held — the call signalling + OEM-kill protection still
                // works via PHONE_CALL while the user is granting mic/camera.
                if (hasPermission(android.Manifest.permission.RECORD_AUDIO)) {
                    serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                if (isVideo && hasPermission(android.Manifest.permission.CAMERA)) {
                    serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                }
            }
            // Defense-in-depth: never let a FGS-type/permission/background-start
            // race crash the call. Degrade gracefully to PHONE_CALL only, then to
            // no explicit type.
            try {
                startForeground(NOTIFICATION_ID, notification, serviceType)
            } catch (t: Throwable) {
                if (BuildConfig.DEBUG) {
                    Log.w(TAG, "startForeground(type=$serviceType) failed: $t")
                }
                try {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL,
                    )
                } catch (t2: Throwable) {
                    if (BuildConfig.DEBUG) {
                        Log.w(TAG, "startForeground(PHONE_CALL) failed: $t2")
                    }
                    try {
                        startForeground(NOTIFICATION_ID, notification)
                    } catch (_: Throwable) {
                        // Give up on foregrounding rather than crash the call.
                    }
                }
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundAndSelf() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(
        callId: String,
        callAttemptId: String,
        peerName: String,
        isVideo: Boolean,
        decisionToken: String,
    ): Notification {
        val displayName = peerName.ifBlank { getString(R.string.app_name) }
        val callTypeText = if (isVideo) getString(R.string.call_video) else getString(R.string.call_voice)

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        // Tap → open call screen
        val tapIntent = Intent(applicationContext, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, "restore")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        val tapPending = PendingIntent.getActivity(
            applicationContext, 42001, tapIntent, pendingFlags,
        )

        // Hangup action
        val hangupIntent = Intent(applicationContext, CallForegroundService::class.java).apply {
            action = ACTION_HANGUP
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(EXTRA_DECISION_TOKEN, decisionToken)
        }
        val hangupPending = PendingIntent.getService(
            applicationContext, 42002, hangupIntent, pendingFlags,
        )

        return NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayName)
            .setContentText(callTypeText)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(tapPending)
            .setColor(ContextCompat.getColor(applicationContext, android.R.color.holo_green_dark))
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    getString(R.string.notification_action_hang_up),
                    hangupPending,
                ).build()
            )
            .build()
    }

    // ── WakeLock ──────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG,
        ).also { lock ->
            // Maximum call duration: 4 hours. Auto-released by OS after that.
            lock.acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (_: RuntimeException) {}
        wakeLock = null
    }

    // ── Route hangup to Flutter ───────────────────────────────────────────────

    private fun routeHangupToFlutter(callId: String, callAttemptId: String, decisionToken: String) {
        // Route via MainActivity's EventChannel so Flutter CallManager gets a
        // hangup decision event even when the app is in background.
        val decisionIntent = Intent(applicationContext, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, "hangup")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        startActivity(decisionIntent)
    }

    // ── Notification channel ──────────────────────────────────────────────────

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel_active_call_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notification_channel_active_call_description)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
