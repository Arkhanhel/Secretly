package com.secretly.secretly_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.File
import java.security.MessageDigest

/**
 * Shows rich Telegram-style [MessagingStyle] notifications for incoming messages.
 *
 * Features:
 *  - Contact avatar as notification icon (circular crop)
 *  - Sender name + message preview
 *  - Reply action with inline RemoteInput
 *  - Mark-as-read action
 *  - Tap → opens conversation in Flutter
 *  - Per-conversation grouping (newer messages replace older notification)
 */
object MessageNotifier {
    private const val TAG = "MessageNotifier"
    private const val CHANNEL_ID = "secretly_messages_v2"
    private const val GROUP_KEY = "secretly_messages_group"
    private const val NOTIF_TAG_PREFIX = "secretly_msg:"
    private const val NOTIF_ID = 1
    private const val LARGE_AVATAR_DP = 64
    private const val SHORTCUT_AVATAR_DP = 96

    private fun notificationTag(convoId: String) = NOTIF_TAG_PREFIX + convoId

    private fun conversationShortcutId(convoId: String) =
        "secretly_msg_" + stableDigestHex(convoId).take(24)

    private fun stableDigestHex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xFF) }

    private fun stableRequestCode(convoId: String, slot: Int): Int {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(convoId.toByteArray(Charsets.UTF_8))
        val base = ((digest[0].toInt() and 0xFF) shl 24) or
            ((digest[1].toInt() and 0xFF) shl 16) or
            ((digest[2].toInt() and 0xFF) shl 8) or
            (digest[3].toInt() and 0xFF)
        return base xor slot
    }

    /**
     * Show (or update) a message notification for a conversation.
     *
     * @param convoId   stable conversation identifier (used to deduplicate)
     * @param title     sender / conversation display name
     * @param body      decrypted message preview
     * @param avatarPath absolute path to the sender's avatar file on disk (nullable)
     * @param playSound whether the notification should trigger sound
     * @param vibrate   whether the notification should trigger vibration
     */
    fun show(
        context: Context,
        convoId: String,
        title: String,
        body: String,
        avatarPath: String?,
        playSound: Boolean,
        vibrate: Boolean,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(context, manager)

        val appName = context.getString(R.string.app_name)
        val newMessageText = context.getString(R.string.notification_message_new)
        val replyText = context.getString(R.string.notification_action_reply)
        val markReadText = context.getString(R.string.notification_action_mark_read)
        val displayName = title.ifBlank { appName }
        val tag = notificationTag(convoId)

        var largeAvatarBitmap: Bitmap? = null
        var shortcutAvatarIcon: IconCompat? = null
        if (!avatarPath.isNullOrBlank()) {
            try {
                val file = File(avatarPath)
                if (file.exists() && file.length() > 0) {
                    val raw = BitmapFactory.decodeFile(file.absolutePath)
                    if (raw != null) {
                        largeAvatarBitmap = circularCrop(raw, dpToPx(context, LARGE_AVATAR_DP))
                        shortcutAvatarIcon = IconCompat.createWithAdaptiveBitmap(
                            centerCropSquare(raw, dpToPx(context, SHORTCUT_AVATAR_DP)),
                        )
                    } else if (BuildConfig.DEBUG) {
                        Log.w(TAG, "avatar decode returned null")
                    }
                }
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) {
                    Log.w(TAG, "avatar load failed", e)
                }
            }
        }

        val sender = Person.Builder()
            .setName(displayName)
            .setImportant(true)
            .build()

        val shortcutId = conversationShortcutId(convoId)
        publishConversationShortcut(
            context = context,
            shortcutId = shortcutId,
            convoId = convoId,
            displayName = displayName,
            avatarIcon = shortcutAvatarIcon,
        )

        val style = NotificationCompat.MessagingStyle(
            Person.Builder().setName(appName).build(),
        )
        if (convoId.startsWith("group:")) {
            style.setConversationTitle(displayName)
        }
        style.addMessage(
            body.ifBlank { newMessageText },
            System.currentTimeMillis(),
            sender,
        )

        // ── Content intent → launch Flutter and open conversation ──
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_CONVO
            putExtra("convo_id", convoId)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val contentPending = PendingIntent.getActivity(
            context, stableRequestCode(convoId, 0), contentIntent, pendingFlags,
        )

        // ── Reply action (inline RemoteInput) ──
        val remoteInput = RemoteInput.Builder(MessageActionReceiver.KEY_TEXT_REPLY)
            .setLabel(replyText)
            .build()

        val replyIntent = Intent(context, MessageActionReceiver::class.java).apply {
            action = MessageActionReceiver.ACTION_REPLY
            putExtra(MessageActionReceiver.EXTRA_CONVO_ID, convoId)
        }
        val replyPendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val replyPending = PendingIntent.getBroadcast(
            context, stableRequestCode(convoId, 1), replyIntent, replyPendingFlags,
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            replyText,
            replyPending,
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(false)
            .build()

        // ── Mark-as-read action ──
        val markReadIntent = Intent(context, MessageActionReceiver::class.java).apply {
            action = MessageActionReceiver.ACTION_MARK_READ
            putExtra(MessageActionReceiver.EXTRA_CONVO_ID, convoId)
        }
        val markReadPending = PendingIntent.getBroadcast(
            context, stableRequestCode(convoId, 2), markReadIntent, pendingFlags,
        )
        val markReadAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            markReadText,
            markReadPending,
        ).build()

        // ── Build notification ──
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayName)
            .setContentText(body.ifBlank { newMessageText })
            .setStyle(style)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .setGroup(GROUP_KEY)
            .setShortcutId(shortcutId)
            .addPerson(sender)
            .setPriority(
                if (playSound) NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT
            )
            .setDefaults(0)  // We control sound/vibrate per-call below.
            .addAction(replyAction)
            .addAction(markReadAction)

        if (largeAvatarBitmap != null) {
            builder.setLargeIcon(largeAvatarBitmap)
        }

        // Sound/vibration handled at the channel level on O+, but we set
        // the builder flags for pre-O and also so the notification manager
        // knows the intent.
        if (!playSound) {
            builder.setSilent(true)
        }

        manager.notify(tag, NOTIF_ID, builder.build())
        Log.i(
            "Sly/Diag",
            "event=notif.posted convo=" + convoId.take(8) +
                " has_avatar=" + (largeAvatarBitmap != null) +
                " sound=" + playSound +
                " vibrate=" + vibrate,
        )
    }

    /**
     * Cancel the notification for a specific conversation (e.g. when the user
     * opens that chat in the app).
     */
    fun cancel(context: Context, convoId: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notificationTag(convoId), NOTIF_ID)
        Log.i(
            "Sly/Diag",
            "event=notif.cancelled convo=" + convoId.take(8),
        )
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun ensureChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_messages_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notification_channel_messages_description)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun publishConversationShortcut(
        context: Context,
        shortcutId: String,
        convoId: String,
        displayName: String,
        avatarIcon: IconCompat?,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_CONVO
            putExtra("convo_id", convoId)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
        val shortcut = ShortcutInfoCompat.Builder(context, shortcutId)
            .setShortLabel(displayName.take(32).ifBlank { context.getString(R.string.app_name) })
            .setLongLabel(displayName.ifBlank { context.getString(R.string.app_name) })
            .setIntent(intent)
            .setLongLived(true)
            .apply {
                if (avatarIcon != null) setIcon(avatarIcon)
            }
            .build()
        try {
            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) {
                Log.w(TAG, "conversation shortcut publish failed", e)
            }
        }
    }

    private fun dpToPx(context: Context, dp: Int): Int =
        (dp * context.resources.displayMetrics.density).toInt().coerceAtLeast(dp)

    /**
     * Crop a bitmap into a circle (for avatar icons).
     */
    internal fun circularCrop(source: Bitmap, outputSizePx: Int? = null): Bitmap {
        val size = minOf(source.width, source.height)
        val targetSize = outputSizePx?.coerceAtLeast(1) ?: size
        val output = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply {
            isAntiAlias = true
        }
        val rect = Rect(0, 0, targetSize, targetSize)
        canvas.drawCircle(targetSize / 2f, targetSize / 2f, targetSize / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val left = (source.width - size) / 2
        val top = (source.height - size) / 2
        canvas.drawBitmap(source, Rect(left, top, left + size, top + size), rect, paint)
        return output
    }

    private fun centerCropSquare(source: Bitmap, outputSizePx: Int): Bitmap {
        val size = minOf(source.width, source.height)
        val targetSize = outputSizePx.coerceAtLeast(1)
        val output = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply { isAntiAlias = true }
        val left = (source.width - size) / 2
        val top = (source.height - size) / 2
        canvas.drawBitmap(
            source,
            Rect(left, top, left + size, top + size),
            Rect(0, 0, targetSize, targetSize),
            paint,
        )
        return output
    }
}
