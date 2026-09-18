package com.secretly.secretly_app

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.File

object IncomingCallNotifier {
    private const val CHANNEL_INCOMING_ID = "secretly_incoming_calls"
    private const val CHANNEL_ONGOING_ID  = "secretly_ongoing_calls"

    // AUD-048 fix: Notification identity is (tag, id). Using a fixed numeric id
    // per category together with a per-call tag (= callId) guarantees uniqueness
    // across concurrent calls without relying on callId.hashCode(), which is
    // not collision-free for arbitrary strings. PendingIntent requestCodes still
    // need stable Ints; we derive them from the callId's full SHA-256 so that
    // collisions are cryptographically improbable.
    private const val INCOMING_NOTIF_ID   = 1
    private const val ONGOING_NOTIF_ID    = 2

    /// 🔴 ОБЯЗАН совпадать с `CallManager.ringTimeoutSeconds` (45 с). Дольше
    /// этого срока звонок не живёт ни на одной стороне, значит и плашке звонить
    /// дольше незачем. Разъедутся числа — плашка либо переживёт звонок, либо
    /// погаснет раньше, чем человек успеет ответить.
    private const val RING_TIMEOUT_MS = 45_000L

    private const val INCOMING_TAG_PREFIX = "secretly_incoming:"
    private const val ONGOING_TAG_PREFIX  = "secretly_ongoing:"

    private fun incomingTag(callId: String) = INCOMING_TAG_PREFIX + callId
    private fun ongoingTag(callId: String)  = ONGOING_TAG_PREFIX + callId

    private fun stableRequestCode(callId: String, slot: Int): Int {
        // SHA-256 first 4 bytes as signed int, XOR'd with slot (0..7) so that
        // multiple PendingIntents per call don't collide.
        val digest = java.security.MessageDigest.getInstance("SHA-256")
            .digest(callId.toByteArray(Charsets.UTF_8))
        val base = ((digest[0].toInt() and 0xFF) shl 24) or
                   ((digest[1].toInt() and 0xFF) shl 16) or
                   ((digest[2].toInt() and 0xFF) shl 8)  or
                    (digest[3].toInt() and 0xFF)
        return base xor slot
    }

    // ── Incoming call notification ─────────────────────────────────────────

    fun show(context: Context, callId: String, callAttemptId: String, decisionToken: String, peerName: String, isVideo: Boolean, avatarPath: String? = null, createdAtMs: Long = -1L) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureIncomingChannel(context, manager)

        // PR-G bug 20: sweep ANY older incoming notification before posting
        // the new one. On rapid cancel+recall (caller hangs up then redials
        // before the receiver's FSM had time to drain the hangup signal) the
        // previous-call's notification would otherwise stack on top of the
        // new one — producing the "duplicate native notifications" observed
        // in production. Cancel by full prefix sweep so we don't depend on
        // any particular older callId being known to this process.
        try {
            val active = manager.activeNotifications
            if (active != null) {
                for (sbn in active) {
                    val tag = sbn.tag ?: continue
                    if (tag.startsWith(INCOMING_TAG_PREFIX) &&
                        tag != incomingTag(callId) &&
                        sbn.id == INCOMING_NOTIF_ID
                    ) {
                        try { manager.cancel(tag, INCOMING_NOTIF_ID) } catch (_: Exception) {}
                    }
                }
            }
        } catch (_: Exception) {
            // Best-effort.
        }

        val appName = context.getString(R.string.app_name)
        val displayName = peerName.ifBlank { context.getString(R.string.call_unknown) }

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        // ── Full-screen intent → IncomingCallActivity (2026-07-08) ────────────
        // The full-screen intent is REQUIRED for a locked / app-killed phone to
        // actually surface + RING the call — especially on MIUI/HyperOS, which
        // silently keeps a CallStyle notification without one in the shade
        // (symptom: "звонок вообще не приходит когда телефон заблокирован").
        // IncomingCallActivity is now a TRANSPARENT wake-shim: it turns the
        // screen on and finishes immediately WITHOUT drawing anything, so the
        // visible UI is this CallStyle notification (Accept/Decline) on the
        // lockscreen — the same native look the user likes when unlocked, no
        // more black takeover screen.
        val fullScreenIntent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra("peer_name", displayName)
            putExtra("is_video", isVideo)
            if (createdAtMs > 0L) putExtra("created_at_ms", createdAtMs)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
        val fullScreenPending = PendingIntent.getActivity(
            context, stableRequestCode(callId, 0), fullScreenIntent, pendingFlags,
        )

        // ── Content tap → MainActivity ("tap" decision; brings app to fg) ──
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, "tap")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        val contentPending = PendingIntent.getActivity(
            context, stableRequestCode(callId, 1), contentIntent, pendingFlags,
        )

        // ── Accept action ──
        // Use Activity PendingIntent (not BroadcastReceiver) so tapping Answer
        // always brings the app to foreground on OEM builds with strict
        // background-start restrictions.
        val acceptIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, "accept")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        val acceptPending = PendingIntent.getActivity(
            context, stableRequestCode(callId, 2), acceptIntent, pendingFlags,
        )

        // ── Decline action ──
        val declineIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, "decline")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        val declinePending = PendingIntent.getActivity(
            context, stableRequestCode(callId, 3), declineIntent, pendingFlags,
        )

        val deleteIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DECLINE
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
        }
        val deletePending = PendingIntent.getBroadcast(
            context, stableRequestCode(callId, 6), deleteIntent, pendingFlags,
        )

        // ── Build caller person for rich notification ──
        val callerBuilder = Person.Builder()
            .setName(displayName)
            .setImportant(true)

        if (!avatarPath.isNullOrBlank()) {
            try {
                val file = File(avatarPath)
                if (file.exists() && file.length() > 0) {
                    val raw = BitmapFactory.decodeFile(file.absolutePath)
                    if (raw != null) {
                        val cropped = MessageNotifier.circularCrop(raw)
                        callerBuilder.setIcon(IconCompat.createWithBitmap(cropped))
                    }
                }
            } catch (_: Exception) {}
        }

        val caller = callerBuilder.build()

        val callText = if (isVideo) {
            context.getString(R.string.call_incoming_video)
        } else {
            context.getString(R.string.call_incoming_voice)
        }

        // AUD-047 fix: do not leak caller identity onto lockscreens. The main
        // notification is VISIBILITY_PRIVATE (hidden on secure lockscreens)
        // and we attach a redacted public variant that only shows the generic
        // "Incoming call" text without peer name or avatar.
        val publicNotification = NotificationCompat.Builder(context, CHANNEL_INCOMING_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(appName)
            .setContentText(callText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setColor(ContextCompat.getColor(context, android.R.color.holo_green_dark))
            .build()

        // 🔴 СОБСТВЕННЫЙ СРОК ЖИЗНИ ПЛАШКИ (08.08.2026, поле: «звонок отменил, но
        // на андроид не отменился, до сих пор звонок идёт входящий»).
        //
        // Снять плашку могут трое: человек, Dart и пуш об отбое (Э-1). Полевой
        // замер показал, что ПУШ ТЕРЯЕТСЯ: на одном звонке отбой пришёл через
        // 6,7 с, на следующем — не пришёл вовсе, и плашка звонила минутами.
        //
        // 🔴 Раньше самотаймер был отвергнут как «лечение симптома» — исходя из
        // того, что сигнал надёжен. Он НЕ надёжен: FCM не гарантирует доставку
        // data-сообщений, а Doze и квоты высокого приоритета режут их тем
        // сильнее, чем чаще они идут (за 30 секунд теста устройство получило
        // около двадцати пушей). Э-1 остаётся быстрым путём, а это — страховка:
        // звонок физически не может звонить дольше, чем он вообще жив.
        //
        // Срок считается от createdAtMs, а НЕ от «сейчас»: задержавшийся пуш не
        // имеет права продлить звон на полные 45 секунд сверх настоящего
        // возраста звонка. Пол в 5 секунд — чтобы почти просроченный пуш всё же
        // успел показаться, а не мигнул и исчез.
        val ringAgeMs = if (createdAtMs > 0L) {
            (System.currentTimeMillis() - createdAtMs).coerceAtLeast(0L)
        } else {
            0L
        }
        val ringLeftMs = (RING_TIMEOUT_MS - ringAgeMs).coerceAtLeast(5_000L)

        val notification = NotificationCompat.Builder(context, CHANNEL_INCOMING_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayName)
            .setContentText(callText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .setAutoCancel(false)
            .setOngoing(true)
            .setTimeoutAfter(ringLeftMs)
            .setFullScreenIntent(fullScreenPending, true)
            .setContentIntent(contentPending)
            .setDeleteIntent(deletePending)
            .setColor(ContextCompat.getColor(context, android.R.color.holo_green_dark))
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: CallStyle already provides Accept / Decline buttons.
                    setStyle(
                        NotificationCompat.CallStyle.forIncomingCall(
                            caller, declinePending, acceptPending,
                        )
                    )
                } else {
                    // Pre-Android 12: add manual action buttons.
                    addAction(
                        NotificationCompat.Action.Builder(
                            android.R.drawable.ic_menu_close_clear_cancel,
                            context.getString(R.string.notification_action_decline),
                            declinePending,
                        ).build()
                    )
                    addAction(
                        NotificationCompat.Action.Builder(
                            android.R.drawable.ic_menu_call,
                            context.getString(R.string.notification_action_answer),
                            acceptPending,
                        ).build()
                    )
                }
            }
            .build()

        manager.notify(incomingTag(callId), INCOMING_NOTIF_ID, notification)
    }

    /**
     * [sweepOthers] управляет общим сносом. По умолчанию `true` — поведение всех
     * прежних мест вызова не меняется.
     *
     * 🔴 `false` нужен ровно одному вызывающему: гашению по пушу об отбое
     * (`call_signal_wake_v1`, 07.08.2026). Там снос опасен, потому что решение
     * приходит из сети в произвольный момент, и отбой звонка А снёс бы ЗВОНЯЩИЙ
     * вызов Б от другого человека. Осиротевших плашек при этом бояться не нужно:
     * [show] сметает всё старое перед показом новой (PR-G bug 20, строки 56-78),
     * то есть защита от дублей живёт на стороне показа и без сноса здесь.
     */
    fun cancel(context: Context, callId: String?, sweepOthers: Boolean = true) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = callId?.trim().orEmpty()
        if (id.isEmpty()) return
        manager.cancel(incomingTag(id), INCOMING_NOTIF_ID)
        // PR-G bug 20: also sweep any stray incoming notifications. On rapid
        // cancel+recall the FSM may have lost track of an older callId — without
        // a sweep that orphaned notification would linger as a duplicate.
        if (sweepOthers) cancelAllIncoming(context)
    }

    /// PR-G bug 20: cancel EVERY notification whose tag starts with
    /// [INCOMING_TAG_PREFIX]. Used (a) when an explicit cancel arrives for an
    /// unknown callId and (b) right before [show] posts a brand-new incoming
    /// notification so a freshly-recalled invite cannot duplicate a stale
    /// notification that the previous-call's cancel never managed to clear.
    fun cancelAllIncoming(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            val active = manager.activeNotifications ?: return
            for (sbn in active) {
                val tag = sbn.tag ?: continue
                if (tag.startsWith(INCOMING_TAG_PREFIX) && sbn.id == INCOMING_NOTIF_ID) {
                    try {
                        manager.cancel(tag, INCOMING_NOTIF_ID)
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {
            // activeNotifications can throw SecurityException on some OEMs when
            // the app does not hold post-notification permission yet — best-effort.
        }
    }

    // ── Ongoing call notification ──────────────────────────────────────────

    fun showOngoingCall(
        context: Context,
        activity: Activity,
        callId: String,
        callAttemptId: String,
        decisionToken: String,
        peerName: String,
        isVideo: Boolean,
        avatarPath: String? = null,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureOngoingChannel(context, manager)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
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
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val contentIntent = PendingIntent.getActivity(
            context,
            stableRequestCode(callId, 4),
            tapIntent,
            pendingFlags,
        )

        val title = if (peerName.isNotBlank()) peerName else context.getString(R.string.call_voice)
        val text = if (isVideo) {
            context.getString(R.string.call_ongoing_video)
        } else {
            context.getString(R.string.call_ongoing_voice)
        }

        // ── End-call action (decline = end for ongoing) ──
        val endCallIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_HANGUP
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
        }
        val endCallPending = PendingIntent.getBroadcast(
            context,
            stableRequestCode(callId, 5),
            endCallIntent,
            pendingFlags,
        )

        // AUD-047 fix: redacted public variant for ongoing call. The
        // lockscreen sees only a generic active-call label without peer
        // identity or video/audio type.
        val publicOngoing = NotificationCompat.Builder(context, CHANNEL_ONGOING_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.app_name))
            .setContentText(context.getString(R.string.call_active))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setColor(ContextCompat.getColor(context, android.R.color.holo_green_dark))
            .build()

        val builder = NotificationCompat.Builder(context, CHANNEL_ONGOING_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicOngoing)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setColor(ContextCompat.getColor(context, android.R.color.holo_green_dark))
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    context.getString(R.string.notification_action_hang_up),
                    endCallPending,
                ).build()
            )

        // Add avatar as large icon if available.
        if (!avatarPath.isNullOrBlank()) {
            try {
                val file = File(avatarPath)
                if (file.exists() && file.length() > 0) {
                    val raw = BitmapFactory.decodeFile(file.absolutePath)
                    if (raw != null) {
                        builder.setLargeIcon(MessageNotifier.circularCrop(raw))
                    }
                }
            } catch (_: Exception) {}
        }

        manager.notify(ongoingTag(callId), ONGOING_NOTIF_ID, builder.build())
    }

    fun cancelOngoing(context: Context, callId: String?) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = callId?.trim().orEmpty()
        if (id.isEmpty()) return
        manager.cancel(ongoingTag(id), ONGOING_NOTIF_ID)
    }

    // ── Channel helpers ────────────────────────────────────────────────────

    private fun ensureIncomingChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // IMPORTANT: this must be idempotent. The previous implementation called
        // `deleteNotificationChannel` + `createNotificationChannel` on every show,
        // which created a small window where NotificationManagerService had stale
        // channel state. On aggressive OEM builds (Xiaomi/HyperOS, Huawei, OPPO,
        // some Samsung firmwares) the immediately-following `notify()` would
        // silently drop the heads-up + full-screen intent — observed symptom:
        // "incoming call notification sometimes doesn't appear when screen is
        // locked / app is killed".
        //
        // Once a channel is created, the user owns its settings (importance,
        // sound, vibration). Recreating it to "pick up config changes" is a
        // user-hostile anti-pattern that Android explicitly discourages.
        val existing = manager.getNotificationChannel(CHANNEL_INCOMING_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_INCOMING_ID,
            context.getString(R.string.notification_channel_incoming_calls_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notification_channel_incoming_calls_description)
            // AUD-047 fix: channel-level default visibility is PRIVATE, so OS
            // honors publicVersion redaction on secure lockscreens. Users can
            // still toggle this per-channel in system settings.
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 400L, 200L, 400L, 200L, 400L)
            // Bypass DND so locked-screen + Doze calls still surface.
            setBypassDnd(true)
            // Play the device's default ringtone on STREAM_RING (loudspeaker).
            // IncomingCallActivity cancels this notification immediately on launch
            // and takes over with its own Ringtone, so there is no double-ring.
            // When IncomingCallActivity cannot auto-launch (e.g. USE_FULL_SCREEN_INTENT
            // not granted on Android 14+), the notification itself rings.
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val audioAttr = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(ringtoneUri, audioAttr)
        }
        manager.createNotificationChannel(channel)
    }

    private fun ensureOngoingChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val existing = manager.getNotificationChannel(CHANNEL_ONGOING_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ONGOING_ID,
            context.getString(R.string.notification_channel_ongoing_calls_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.notification_channel_ongoing_calls_description)
            // AUD-047 fix: keep ongoing call status channel private by default;
            // publicVersion above provides the redacted lockscreen view.
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
