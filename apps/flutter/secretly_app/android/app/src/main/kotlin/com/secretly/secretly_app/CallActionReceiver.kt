package com.secretly.secretly_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles Accept / Decline actions fired from the incoming-call notification.
 *
 * Each action relaunches [MainActivity] with ACTION_CALL_DECISION so the
 * Dart side receives the decision through the existing EventChannel pipeline.
 */
class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ACCEPT = "com.secretly.secretly_app.ACTION_ACCEPT_CALL"
        const val ACTION_DECLINE = "com.secretly.secretly_app.ACTION_DECLINE_CALL"
        const val ACTION_HANGUP = "com.secretly.secretly_app.ACTION_HANGUP_CALL"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callId = (intent.getStringExtra(MainActivity.EXTRA_CALL_ID) ?: "").trim()
        val callAttemptId = (intent.getStringExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID) ?: callId).trim()
        val decisionToken =
            (intent.getStringExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN) ?: "").trim()
        if (callId.isEmpty()) return
        val decision = when (intent.action) {
            ACTION_ACCEPT -> "accept"
            ACTION_DECLINE -> "decline"
            ACTION_HANGUP -> "hangup"
            else -> return
        }

        if (BuildConfig.DEBUG) {
            Log.d("CallActionReceiver", "notification call action=$decision")
        }

        // Cancel the incoming notification immediately.
        IncomingCallNotifier.cancel(context, callId)

        // 🔴 Звонок ОТРАБОТАН человеком — снимаем след, иначе принятый разговор
        // отразился бы в ленте как пропущенный. Отбой звонившего след не
        // снимает: там пропущенный настоящий. См. MissedCallTrail.
        MissedCallTrail.remove(context, callId)

        // Finish the fullscreen IncomingCallActivity if it is showing.
        // It may live in a separate task, so FLAG_ACTIVITY_CLEAR_TOP alone
        // would not dismiss it — we call finishCurrent() explicitly.
        IncomingCallActivity.finishCurrent()

        // Forward the decision to MainActivity → Flutter EventChannel.
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CALL_DECISION
            putExtra(MainActivity.EXTRA_CALL_ID, callId)
            putExtra(MainActivity.EXTRA_CALL_ATTEMPT_ID, callAttemptId)
            putExtra(MainActivity.EXTRA_CALL_DECISION_TOKEN, decisionToken)
            putExtra(MainActivity.EXTRA_DECISION, decision)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        context.startActivity(launchIntent)
    }
}
