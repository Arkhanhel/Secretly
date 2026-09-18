package com.secretly.secretly_app

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import java.lang.ref.WeakReference

/**
 * Transparent wake-shim for the incoming-call full-screen intent.
 *
 * A CallStyle incoming-call notification needs a full-screen intent so a
 * LOCKED / app-killed phone actually surfaces + rings it (MIUI/HyperOS keep it
 * silently in the shade otherwise). But we do NOT want the old black full-screen
 * takeover — the user wants the same native heads-up notification they get when
 * unlocked. So this activity draws NOTHING: it only turns the screen on (and
 * shows over the keyguard) so the CallStyle notification — with its Accept /
 * Decline actions and channel ringtone — becomes visible, then finishes.
 *
 * Accept / Decline are handled entirely by the notification's own PendingIntents
 * (see [IncomingCallNotifier]); this shim never touches the decision flow.
 */
class IncomingCallActivity : Activity() {
    companion object {
        private var currentRef: WeakReference<IncomingCallActivity>? = null

        fun finishCurrent() {
            currentRef?.get()?.finish()
            currentRef = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentRef = WeakReference(this)

        // Wake the screen and allow display over the keyguard so the notification
        // is visible on the lockscreen. No content view is set — the window stays
        // transparent (see IncomingCallTheme) and we finish immediately.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        val callId = (intent.getStringExtra(MainActivity.EXTRA_CALL_ID) ?: "").trim()
        val createdAtMs = intent.getLongExtra("created_at_ms", -1L)

        // Freshness guard: a delayed / replayed push for an old invite should
        // clear the (possibly re-posted) notification instead of ringing.
        if (createdAtMs > 0L && System.currentTimeMillis() - createdAtMs > 45_000L) {
            if (BuildConfig.DEBUG) {
                Log.d(
                    "NativeCallUi",
                    "incoming shim dismissed stale invite age=${System.currentTimeMillis() - createdAtMs}ms"
                )
            }
            if (callId.isNotEmpty()) {
                try {
                    IncomingCallNotifier.cancel(applicationContext, callId)
                } catch (_: Exception) {}
            }
        }

        // Done — the CallStyle notification is the UI. Finish so no window paints.
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (currentRef?.get() == this) {
            currentRef = null
        }
    }
}
