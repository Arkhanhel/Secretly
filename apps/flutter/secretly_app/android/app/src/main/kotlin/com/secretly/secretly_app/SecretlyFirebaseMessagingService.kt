package com.secretly.secretly_app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.util.PathUtils
import java.io.File
import java.util.UUID

class SecretlyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "SecretlyFCM"

        // Must match the keys in MainActivity to share the token store.
        private const val PREFS_PENDING = "secretly_pending_actions"
        private const val KEY_ACTIVE_CALL_ID = "active_call_id"
        private const val KEY_ACTIVE_CALL_ATTEMPT_ID = "active_call_attempt_id"
        private const val KEY_ACTIVE_CALL_DECISION_TOKEN = "active_call_decision_token"

        // Separate prefs shard for the FCM token so Flutter can read it.
        private const val PREFS_PUSH = "secretly_push_prefs"
        private const val KEY_FCM_TOKEN = "fcm_token_v1"

        fun storedFcmToken(context: Context): String? {
            return context.applicationContext
                .getSharedPreferences(PREFS_PUSH, Context.MODE_PRIVATE)
                .getString(KEY_FCM_TOKEN, null)
                ?.takeIf { it.isNotBlank() }
        }

        fun storeFcmToken(context: Context, token: String) {
            val normalized = token.trim()
            if (normalized.isEmpty()) return
            context.applicationContext
                .getSharedPreferences(PREFS_PUSH, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_FCM_TOKEN, normalized)
                .apply()
        }

        // Issues a decision token and writes it to the shared prefs so that
        // when MainActivity later reads the notification tap intent it can
        // validate the token. Mirrors MainActivity.issueCallDecisionToken().
        internal fun issueDecisionToken(
            context: Context,
            callId: String,
            callAttemptId: String,
        ): String {
            val normalizedAttemptId = callAttemptId.ifBlank { callId }
            val token = UUID.randomUUID().toString()
            context.applicationContext
                .getSharedPreferences(PREFS_PENDING, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_ACTIVE_CALL_ID, callId)
                .putString(KEY_ACTIVE_CALL_ATTEMPT_ID, normalizedAttemptId)
                .putString(KEY_ACTIVE_CALL_DECISION_TOKEN, token)
                .apply()
            return token
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        storeFcmToken(applicationContext, token)
        Log.d(TAG, "FCM token refreshed and stored")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val data = message.data
        val type = (data["type"] ?: "").trim()
        Log.d(TAG, "FCM message received type=$type")

        when (type) {
            "incoming_call" -> handleIncomingCall(data)
            else -> {
                // Generic relay wake. If it carries a call_invite_v1 hint we show
                // a native incoming call UI for killed/background app state so the
                // user hears the ringtone before Flutter processes the invite.
                val wakeKind = (data["wake_kind"] ?: "").trim()
                if (wakeKind == "call_invite_v1") {
                    handleCallInviteWake(data)
                } else if (wakeKind == "call_signal_wake_v1") {
                    handleCallSignalWake(data)
                }
                // NOTE (BUG-4, notifications audit 2026-06-12): we deliberately do
                // NOT raise a native banner for chat_message_v1 wakes here.
                //
                // Visible chat notifications are gated server-side by the relay via
                // the FCM `notification` block, which is only attached when
                // include_notification == true (conversation not muted AND not a
                // control envelope such as a read receipt — see
                // build_fcm_v1_message_payload / should_alert_for_message in the
                // relay). When that block is present the OS renders the banner
                // itself and this service is NOT invoked. The only chat wakes that
                // reach onMessageReceived are therefore data-only
                // (include_notification == false) — exactly the muted / silent
                // cases — so showing a banner from here would resurrect the
                // "muted rooms still notify" bug. Chat banners are owned by the OS
                // (notification block) and, while the engine is alive, by Flutter.
                //
                // Historical note: the previous `type == "chat_message_v1"` check
                // never matched (the relay sets data["type"] = "relay_pending" and
                // puts the kind in data["wake_kind"]), so this path was already
                // dead — it is now disabled intentionally rather than by accident.
                //
                // The Flutter background handler processes remaining wake kinds.
            }
        }
    }

    /**
     * Снимает нативную плашку входящего по сигналу об окончании звонка.
     *
     * 🔴 ЗАЧЕМ (07.08.2026, поле: «звонок отменил, но на андроиде до сих пор
     * висит уведомление о звонке»). Эта служба умела ТОЛЬКО показать плашку.
     * Погасить её имели право лишь `CallActionReceiver` (человек нажал кнопку),
     * `IncomingCallActivity` и `MainActivity` — то есть Flutter. Когда Activity
     * убита, снять плашку было НЕКОМУ, и она висела вечно.
     *
     * 🔴 ПОЧЕМУ ЭТО НЕ ПОТРЕБОВАЛО ПРАВОК РЕЛЕ И НЕ ДОБАВИЛО УТЕЧКИ. Реле уже
     * сегодня кладёт в этот пуш `action` (`hangup`/`decline`/`offer`/…),
     * `call_id`, `call_attempt_id` и `created_at_ms` — см. ветку
     * `call_signal_wake_v1` в relay/src/main.rs. Диспетчер просто не разбирал
     * этот вид пробуждения, и пуш проваливался в общий путь. Ни одного нового
     * поля наружу не уходит.
     *
     * 🔴 ЧЕГО ЗДЕСЬ НЕТ И БЫТЬ НЕ ДОЛЖНО — расшифровки. Сам сигнал зашифрован,
     * и трогать его в фоне запрещено инвариантом И-3: расшифровка только в
     * главном изоляте, иначе получаем двух писателей в ратчет. Решение
     * принимается ИСКЛЮЧИТЕЛЬНО по метаданным пуша.
     */
    private fun handleCallSignalWake(data: Map<String, String>) {
        val action = (data["action"] ?: data["call_action"] ?: "").trim().lowercase()
        // Прочие действия (offer/answer/ice/need_offer) — это ход живого звонка,
        // плашку они снимать не должны.
        if (action != "hangup" && action != "decline") return

        val callId = (data["call_id"] ?: data["callId"] ?: "").trim()
        if (callId.isEmpty()) {
            Log.w(TAG, "call_signal_wake_v1 $action missing call_id — ignored")
            return
        }

        // Та же проверка свежести, что у приглашения: задержавшийся или
        // переигранный отбой не имеет права снять плашку ЗАНОВО набранного
        // звонка.
        val createdAtMs = (data["created_at_ms"] ?: "").toLongOrNull()
        if (createdAtMs != null) {
            val ageMs = System.currentTimeMillis() - createdAtMs
            if (ageMs > 45_000L) {
                Log.d(
                    TAG,
                    "call_signal_wake_v1 $action discarded: stale age=${ageMs}ms callId=${callId.take(8)}"
                )
                return
            }
        }

        // 🔴 Точечно, БЕЗ общего сноса — см. `IncomingCallNotifier.cancel`.
        // Решение приходит из сети в произвольный момент, и снос снял бы
        // звонящий вызов другого человека.
        IncomingCallNotifier.cancel(applicationContext, callId, sweepOthers = false)
        Log.d(TAG, "Incoming call notification cancelled by $action callId=${callId.take(8)}")
    }

    /**
     * Shows native incoming call UI for a relay `call_invite_v1` wake push.
     * Performs a freshness check on `created_at_ms` so stale/replayed pushes
     * never produce a ghost ring.
     */
    private fun handleCallInviteWake(data: Map<String, String>) {
        val action = (data["action"] ?: data["call_action"] ?: "").trim().lowercase()
        val displayMode = (data["display_mode"] ?: data["displayMode"] ?: "").trim().lowercase()
        if ((action.isNotEmpty() && action != "invite") ||
            (displayMode.isNotEmpty() && displayMode != "incoming")
        ) {
            Log.d(TAG, "call_invite_v1 wake ignored: action=$action displayMode=$displayMode")
            return
        }

        val callId = (data["call_id"] ?: data["callId"] ?: "").trim()
        if (callId.isEmpty()) {
            Log.w(TAG, "call_invite_v1 wake missing call_id — ignored")
            return
        }
        val callAttemptId = (data["call_attempt_id"] ?: data["callAttemptId"] ?: "").trim()
            .ifBlank { callId }

        // Freshness guard: discard pushes older than 45 seconds so a delayed
        // or replayed wake cannot show a ghost incoming call on the device.
        val createdAtMs = (data["created_at_ms"] ?: "").toLongOrNull()
        if (createdAtMs != null) {
            val ageMs = System.currentTimeMillis() - createdAtMs
            if (ageMs > 45_000L) {
                Log.d(TAG, "call_invite_v1 wake discarded: stale age=${ageMs}ms callId=${callId.take(8)}")
                return
            }
        }

        // Derive a display name from caller_profile_id or notification_label
        // (relay resolves this server-side from the device's contact data).
        val unknownName = getString(R.string.call_unknown)
        val peerName = (
            data["peer_name"] ?: data["peerName"]
            ?: data["caller_display_name"]
            ?: data["notification_title"]
            ?: data["caller_profile_id"]
            ?: unknownName
        ).trim().ifBlank { unknownName }
        val isVideo = data["is_video"]?.equals("true", ignoreCase = true) == true

        showNativeIncomingCall(
            callId = callId,
            callAttemptId = callAttemptId,
            peerName = peerName,
            isVideo = isVideo,
            createdAtMs = createdAtMs ?: -1L,
            callerProfileId = data["caller_profile_id"],
        )
    }

    // NOTE: the former handleChatMessageWake() native banner was removed in the
    // 2026-06-12 notifications audit (BUG-4). Visible chat notifications are
    // gated server-side by the relay's FCM notification block; data-only chat
    // wakes that reach this service are always the muted / silent cases, so a
    // native banner here would wrongly fire for muted rooms and read receipts.
    // See the comment in onMessageReceived() for the full rationale.

    private fun handleIncomingCall(data: Map<String, String>) {
        val callId = (data["call_id"] ?: data["callId"] ?: "").trim()
        if (callId.isEmpty()) {
            Log.w(TAG, "incoming_call FCM message missing call_id — ignored")
            return
        }
        val callAttemptId = (data["call_attempt_id"] ?: data["callAttemptId"] ?: "").trim()
            .ifBlank { callId }
        val unknownName = getString(R.string.call_unknown)
        val peerName = (data["peer_name"] ?: data["peerName"] ?: unknownName).trim()
            .ifBlank { unknownName }
        val isVideo = data["is_video"]?.equals("true", ignoreCase = true) == true ||
            data["isVideo"]?.equals("true", ignoreCase = true) == true
        val createdAtMs = (data["created_at_ms"] ?: "").toLongOrNull() ?: -1L

        showNativeIncomingCall(
            callId = callId,
            callAttemptId = callAttemptId,
            peerName = peerName,
            isVideo = isVideo,
            createdAtMs = createdAtMs,
            callerProfileId = data["caller_profile_id"],
        )

        // След для Dart пишется внутри showNativeIncomingCall — там, где сходятся
        // ОБА пути показа плашки. См. MissedCallTrail.
    }

    // Resolve the caller's LOCAL contact avatar from the caller profile id the
    // push carries — E2EE-safe, because the file is a photo YOU saved locally
    // for a contact and nothing leaves the device. Flutter writes contact
    // avatars at <app_flutter>/contact_avatars/<safe>.png where
    // safe = profileId with every char outside [A-Za-z0-9_-] replaced by '_'
    // (see app_controller.dart _setContactAvatar). We deliberately DO NOT fall
    // back to the synced profile_meta photo (profile_avatars/<safe>_<hash>.png):
    // that one is gated by the peer's photo-audience privacy setting, which only
    // Flutter can evaluate — resolving it natively could show a "contacts-only"
    // photo to a non-contact. Non-contacts therefore fall back to initials here
    // and Flutter fills the photo (with the audience check) once it boots.
    private fun resolveLocalContactAvatarPath(callerProfileId: String?): String? {
        val pid = callerProfileId?.trim().orEmpty()
        if (pid.isEmpty()) return null
        return try {
            // PathUtils.getDataDirectory == path_provider getApplicationDocuments
            // == context.getDir("flutter", MODE_PRIVATE) == <data>/app_flutter.
            val docsDir = File(PathUtils.getDataDirectory(applicationContext))
            val safe = pid.replace(Regex("[^A-Za-z0-9_-]"), "_")
            val avatar = File(File(docsDir, "contact_avatars"), "$safe.png")
            if (avatar.exists() && avatar.length() > 0L) avatar.absolutePath else null
        } catch (e: Exception) {
            Log.w(TAG, "caller avatar resolve failed: ${e.message}")
            null
        }
    }

    private fun showNativeIncomingCall(
        callId: String,
        callAttemptId: String,
        peerName: String,
        isVideo: Boolean,
        createdAtMs: Long,
        callerProfileId: String? = null,
    ) {
        // Hold a wakelock for ~10s so Doze / aggressive battery managers
        // (MIUI, HyperOS, Samsung) cannot pause the FCM service before the
        // full-screen intent and IncomingCallActivity finish launching.
        val wakeLock = try {
            val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Secretly:IncomingCallWake",
            ).apply { acquire(10_000L) }
        } catch (e: Exception) {
            Log.w(TAG, "wakelock acquire failed: ${e.message}")
            null
        }

        // 🔴 УВЕДОМЛЕНИЕ ПОКАЗЫВАЕТСЯ ВСЕГДА (14.08.2026, требование владельца).
        //
        // Здесь стояла проверка «приложение открыто → плашку не показывать»: она
        // решала другую задачу — экран тогда открывался САМ, и плашка ложилась
        // поверх него. Теперь экран сам не открывается вовсе, а входящий звонок
        // обязан заявлять о себе В ЛЮБОМ случае: и когда приложение закрыто, и
        // когда человек в нём сидит. Решение открыть экран принимает человек,
        // нажав на уведомление.

        val decisionToken = issueDecisionToken(applicationContext, callId, callAttemptId)
        val avatarPath = resolveLocalContactAvatarPath(callerProfileId)
        try {
            IncomingCallNotifier.show(
                context = applicationContext,
                callId = callId,
                callAttemptId = callAttemptId,
                decisionToken = decisionToken,
                peerName = peerName,
                isVideo = isVideo,
                avatarPath = avatarPath,
                createdAtMs = createdAtMs,
            )
            Log.d(TAG, "Incoming call notification shown callId=${callId.take(8)}")

            // 🔴 След для Dart — ИМЕННО ЗДЕСЬ, а не у вызывающих (08.08.2026).
            // Показать плашку могут ДВА пути: `handleCallInviteWake`
            // (`wake_kind=call_invite_v1`, он и работает в проде) и
            // `handleIncomingCall` (`type=incoming_call`). Первая реализация
            // записывала след только во втором, и полевой тест показал ровно
            // это: плашка есть, отбой отработал, а след пуст и пузыря нет.
            // Здесь путь один на обоих, и разойтись они больше не могут.
            //
            // Внутри `try` намеренно: след имеет смысл только если плашка
            // ДЕЙСТВИТЕЛЬНО показана. Не показали — не о чем и помнить.
            MissedCallTrail.add(
                context = applicationContext,
                callId = callId,
                callAttemptId = callAttemptId,
                callerProfileId = callerProfileId,
                callerName = peerName,
                isVideo = isVideo,
                createdAtMs = createdAtMs,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show incoming call notification: ${e.message}")
        }

        // Backup: try to start IncomingCallActivity directly so it appears
        // even on devices that block automatic full-screen intent expansion
        // (e.g. MIUI/HyperOS without the "show pop-ups" permission). The
        // notification posted above legitimises this background start on
        // Android 10+ via the CATEGORY_CALL + USE_FULL_SCREEN_INTENT exception.
        //
        // Important UX rule: when the app is already in the foreground we MUST
        // NOT hijack the user's screen with the full-screen call window. The
        // heads-up notification alone is the correct cue; the full-screen UI
        // should open only on explicit tap. See MainActivity.isAppForeground.
        //
        // PR-H 2026-05-20: the original `isAppForeground` gate was too
        // permissive — it stayed true whenever the Activity lifecycle was
        // between onStart and onStop, INCLUDING the window where the user
        // pressed the power button and Android hasn't yet driven the
        // keyguard transition (Xiaomi/HyperOS, Samsung OneUI can delay
        // onStop by 3–10 s, or skip it entirely on quick power-power taps).
        // In that window the FCM-driven IncomingCallActivity launch was
        // suppressed and the fallback (setFullScreenIntent of the heads-up
        // notification) is unreliable on Android 14+ where the user may
        // have revoked USE_FULL_SCREEN_INTENT.
        //
        // The correct check is "foreground AND user can actually see the
        // chat right now" — i.e. screen is interactive AND device is not
        // locked. If either is false, we MUST launch the full-screen UI so
        // the lock screen wakes up with the incoming call.
        val screenInteractive = try {
            val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
            pm?.isInteractive == true
        } catch (e: Exception) {
            Log.w(TAG, "PowerManager.isInteractive check failed: ${e.message}")
            true // fail open — assume interactive, gate may suppress but
                 // we'd rather show a notification than no UI at all
        }
        val deviceLocked = try {
            val km = applicationContext.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.isKeyguardLocked == true
        } catch (e: Exception) {
            Log.w(TAG, "KeyguardManager.isKeyguardLocked check failed: ${e.message}")
            false // fail open — assume unlocked
        }
        val shouldSuppress = MainActivity.isAppForeground.get() && screenInteractive && !deviceLocked
        if (shouldSuppress) {
            Log.d(TAG, "App is foreground and screen unlocked — notification only")
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // 🔴 ПРЯМОЙ ЗАПУСК ИЗ ФОНА ЗАПРЕЩЁН С ANDROID 10 (13.08.2026).
            //
            // Система блокирует его молча: startActivity НЕ бросает, поэтому мы
            // писали в лог «IncomingCallActivity started directly from FCM», а в
            // системном логе рядом стояло «Background activity launch blocked» и
            // экран не поднимался. Замер владельца: приложение открылось без
            // экрана звонка.
            //
            // Поднимать экран из фона имеет право ТОЛЬКО полноэкранное намерение
            // уведомления (setFullScreenIntent, уже стоит). Оно срабатывает при
            // заблокированном или погашенном экране; на разблокированном система
            // намеренно показывает плашку — так же ведут себя все мессенджеры,
            // и нажатие на неё открывает экран звонка.
            Log.d(TAG, "background activity start not attempted (API>=29) — relying on full-screen intent")
        } else {
            try {
                val activityIntent = Intent(applicationContext, IncomingCallActivity::class.java).apply {
                    putExtra(MainActivity.EXTRA_CALL_ID, callId)
                    putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
                    putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
                    putExtra("peer_name", peerName)
                    putExtra("is_video", isVideo)
                    if (createdAtMs > 0L) putExtra("created_at_ms", createdAtMs)
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                    )
                }
                applicationContext.startActivity(activityIntent)
                Log.d(TAG, "IncomingCallActivity started directly from FCM")
            } catch (e: Exception) {
                Log.w(TAG, "Direct IncomingCallActivity start blocked: ${e.message}")
            }
        }

        // Release the wakelock now that the UI has been launched. The auto
        // 10s timeout above is a safety net in case any of the launches threw.
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (e: Exception) {
            Log.w(TAG, "wakelock release failed: ${e.message}")
        }
    }
}
