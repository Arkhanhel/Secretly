package com.secretly.secretly_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.RemoteInput

/**
 * Handles Reply and Mark-as-Read actions fired from message notifications.
 *
 * Each action relaunches [MainActivity] with ACTION_MSG_REPLY or
 * ACTION_MSG_MARK_READ so the Dart side receives the event through the
 * existing EventChannel pipeline.
 */
class MessageActionReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "MessageActionReceiver"
        const val ACTION_REPLY = "com.secretly.secretly_app.ACTION_MSG_REPLY"
        const val ACTION_MARK_READ = "com.secretly.secretly_app.ACTION_MSG_MARK_READ"
        const val EXTRA_CONVO_ID = "convo_id"
        const val KEY_TEXT_REPLY = "key_text_reply"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val convoId = (intent.getStringExtra(EXTRA_CONVO_ID) ?: "").trim()
        if (convoId.isEmpty()) return

        when (intent.action) {
            ACTION_REPLY -> {
                val remoteInput = RemoteInput.getResultsFromIntent(intent)
                val replyText = remoteInput?.getCharSequence(KEY_TEXT_REPLY)?.toString()?.trim() ?: ""
                if (replyText.isEmpty()) return
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "reply action received")
                }

                // Cancel the notification.
                MessageNotifier.cancel(context, convoId)

                // Forward to MainActivity → Flutter EventChannel.
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    action = MainActivity.ACTION_MSG_REPLY
                    putExtra(EXTRA_CONVO_ID, convoId)
                    putExtra(KEY_TEXT_REPLY, replyText)
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                }
                context.startActivity(launchIntent)
            }

            ACTION_MARK_READ -> {
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "mark-read action received")
                }

                // Cancel the notification.
                MessageNotifier.cancel(context, convoId)

                // Forward to MainActivity → Flutter EventChannel.
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    action = MainActivity.ACTION_MSG_MARK_READ
                    putExtra(EXTRA_CONVO_ID, convoId)
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                }
                context.startActivity(launchIntent)
            }

            else -> return
        }
    }
}
