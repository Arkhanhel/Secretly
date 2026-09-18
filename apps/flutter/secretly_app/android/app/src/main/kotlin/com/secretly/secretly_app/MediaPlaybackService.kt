package com.secretly.secretly_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle

class MediaPlaybackService : Service() {
    companion object {
        private const val CHANNEL_ID = "secretly_media_playback"
        private const val NOTIFICATION_ID = 42004

        private const val ACTION_UPDATE = "com.secretly.secretly_app.MEDIA_UPDATE"
        private const val ACTION_CLEAR = "com.secretly.secretly_app.MEDIA_CLEAR"
        const val ACTION_PLAY = "com.secretly.secretly_app.MEDIA_PLAY"
        const val ACTION_PAUSE = "com.secretly.secretly_app.MEDIA_PAUSE"
        const val ACTION_PLAY_PAUSE = "com.secretly.secretly_app.MEDIA_PLAY_PAUSE"
        const val ACTION_NEXT = "com.secretly.secretly_app.MEDIA_NEXT"
        const val ACTION_PREVIOUS = "com.secretly.secretly_app.MEDIA_PREVIOUS"
        const val ACTION_STOP = "com.secretly.secretly_app.MEDIA_STOP"

        private const val EXTRA_TRACK_ID = "track_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_ARTIST = "artist"
        private const val EXTRA_ALBUM = "album"
        private const val EXTRA_ARTWORK_PATH = "artwork_path"
        private const val EXTRA_PLAYING = "playing"
        private const val EXTRA_POSITION_MS = "position_ms"
        private const val EXTRA_DURATION_MS = "duration_ms"
        private const val EXTRA_CAN_SKIP_PREVIOUS = "can_skip_previous"
        private const val EXTRA_CAN_SKIP_NEXT = "can_skip_next"

        fun showOrUpdate(context: Context, state: MediaNotificationState) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, MediaPlaybackService::class.java).apply {
                action = ACTION_UPDATE
                putExtras(state.toBundle())
            }
            if (state.playing) {
                ContextCompat.startForegroundService(appContext, intent)
            } else {
                appContext.startService(intent)
            }
        }

        fun clear(context: Context) {
            val appContext = context.applicationContext
            appContext.startService(
                Intent(appContext, MediaPlaybackService::class.java).apply {
                    action = ACTION_CLEAR
                },
            )
        }
    }

    data class MediaNotificationState(
        val trackId: String,
        val title: String,
        val artist: String,
        val album: String,
        val artworkPath: String?,
        val playing: Boolean,
        val positionMs: Long,
        val durationMs: Long,
        val canSkipPrevious: Boolean,
        val canSkipNext: Boolean,
    ) {
        fun toBundle(): Bundle {
            return Bundle().apply {
                putString(EXTRA_TRACK_ID, trackId)
                putString(EXTRA_TITLE, title)
                putString(EXTRA_ARTIST, artist)
                putString(EXTRA_ALBUM, album)
                putString(EXTRA_ARTWORK_PATH, artworkPath)
                putBoolean(EXTRA_PLAYING, playing)
                putLong(EXTRA_POSITION_MS, positionMs)
                putLong(EXTRA_DURATION_MS, durationMs)
                putBoolean(EXTRA_CAN_SKIP_PREVIOUS, canSkipPrevious)
                putBoolean(EXTRA_CAN_SKIP_NEXT, canSkipNext)
            }
        }

        companion object {
            fun fromMap(args: Map<*, *>?): MediaNotificationState? {
                if (args == null) {
                    return null
                }
                val title = (args["title"] as? String)?.trim().orEmpty().ifEmpty { "Secretly" }
                return MediaNotificationState(
                    trackId = (args["trackId"] as? String)?.trim().orEmpty(),
                    title = title,
                    artist = (args["artist"] as? String)?.trim().orEmpty(),
                    album = (args["album"] as? String)?.trim().orEmpty(),
                    artworkPath = (args["artworkPath"] as? String)?.trim()?.ifEmpty { null },
                    playing = args["playing"] as? Boolean ?: false,
                    positionMs = longValue(args["positionMs"]),
                    durationMs = longValue(args["durationMs"]),
                    canSkipPrevious = args["canSkipPrevious"] as? Boolean ?: false,
                    canSkipNext = args["canSkipNext"] as? Boolean ?: false,
                )
            }

            fun fromIntent(intent: Intent): MediaNotificationState {
                val title = (intent.getStringExtra(EXTRA_TITLE) ?: "").trim().ifEmpty { "Secretly" }
                return MediaNotificationState(
                    trackId = (intent.getStringExtra(EXTRA_TRACK_ID) ?: "").trim(),
                    title = title,
                    artist = (intent.getStringExtra(EXTRA_ARTIST) ?: "").trim(),
                    album = (intent.getStringExtra(EXTRA_ALBUM) ?: "").trim(),
                    artworkPath = intent.getStringExtra(EXTRA_ARTWORK_PATH)?.trim()?.ifEmpty { null },
                    playing = intent.getBooleanExtra(EXTRA_PLAYING, false),
                    positionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L),
                    durationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L),
                    canSkipPrevious = intent.getBooleanExtra(EXTRA_CAN_SKIP_PREVIOUS, false),
                    canSkipNext = intent.getBooleanExtra(EXTRA_CAN_SKIP_NEXT, false),
                )
            }

            private fun longValue(value: Any?): Long {
                return when (value) {
                    is Long -> value
                    is Int -> value.toLong()
                    is Double -> value.toLong()
                    is Float -> value.toLong()
                    is Number -> value.toLong()
                    else -> 0L
                }
            }
        }
    }

    private lateinit var notificationManager: NotificationManagerCompat
    private lateinit var mediaSession: MediaSessionCompat
    private var isForegroundNotification = false

    override fun onCreate() {
        super.onCreate()
        notificationManager = NotificationManagerCompat.from(this)
        ensureNotificationChannel()
        mediaSession = MediaSessionCompat(this, "SecretlyMediaSession").apply {
            setSessionActivity(buildContentPendingIntent())
            isActive = true
            setCallback(
                object : MediaSessionCompat.Callback() {
                    override fun onPlay() {
                        emitAction("play")
                    }

                    override fun onPause() {
                        emitAction("pause")
                    }

                    override fun onSkipToNext() {
                        emitAction("next")
                    }

                    override fun onSkipToPrevious() {
                        emitAction("previous")
                    }

                    override fun onStop() {
                        emitAction("stop")
                        clearAndStop()
                    }
                },
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> applyState(MediaNotificationState.fromIntent(intent))
            ACTION_CLEAR -> clearAndStop()
            ACTION_PLAY -> emitAction("play")
            ACTION_PAUSE -> emitAction("pause")
            ACTION_PLAY_PAUSE -> emitAction("play_pause")
            ACTION_NEXT -> emitAction("next")
            ACTION_PREVIOUS -> emitAction("previous")
            ACTION_STOP -> {
                emitAction("stop")
                clearAndStop()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (isForegroundNotification) {
            stopForeground(true)
            isForegroundNotification = false
        }
        mediaSession.release()
        super.onDestroy()
    }

    private fun applyState(state: MediaNotificationState) {
        mediaSession.isActive = true
        updateMediaSession(state)
        val notification = buildNotification(state)
        if (state.playing) {
            startForeground(NOTIFICATION_ID, notification)
            isForegroundNotification = true
            return
        }

        if (isForegroundNotification) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                stopForeground(false)
            }
            isForegroundNotification = false
        }
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun clearAndStop() {
        notificationManager.cancel(NOTIFICATION_ID)
        if (isForegroundNotification) {
            stopForeground(true)
            isForegroundNotification = false
        }
        mediaSession.isActive = false
        mediaSession.setMetadata(MediaMetadataCompat.Builder().build())
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0L, 0f)
                .setActions(0L)
                .build(),
        )
        stopSelf()
    }

    private fun updateMediaSession(state: MediaNotificationState) {
        val actions =
            PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_STOP or
                (if (state.canSkipPrevious) PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS else 0L) or
                (if (state.canSkipNext) PlaybackStateCompat.ACTION_SKIP_TO_NEXT else 0L)

        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(
                    if (state.playing) {
                        PlaybackStateCompat.STATE_PLAYING
                    } else {
                        PlaybackStateCompat.STATE_PAUSED
                    },
                    state.positionMs.coerceAtLeast(0L),
                    if (state.playing) 1f else 0f,
                )
                .build(),
        )

        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, state.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, state.artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, state.album)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, state.durationMs)

        loadArtworkBitmap(state.artworkPath)?.let { artwork ->
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artwork)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, artwork)
        }

        mediaSession.setMetadata(metadataBuilder.build())
    }

    private fun buildNotification(state: MediaNotificationState): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(state.title)
            .setContentText(state.artist.ifEmpty { getString(R.string.app_name) })
            .setSubText(state.album.ifEmpty { null })
            .setContentIntent(buildContentPendingIntent())
            .setDeleteIntent(buildServicePendingIntent(ACTION_STOP, 91))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(state.playing)

        loadArtworkBitmap(state.artworkPath)?.let(builder::setLargeIcon)

        val compactActionIndexes = mutableListOf<Int>()
        var actionIndex = 0

        if (state.canSkipPrevious) {
            builder.addAction(
                NotificationCompat.Action(
                    android.R.drawable.ic_media_previous,
                    getString(R.string.notification_media_previous),
                    buildServicePendingIntent(ACTION_PREVIOUS, 11),
                ),
            )
            compactActionIndexes += actionIndex
            actionIndex += 1
        }

        builder.addAction(
            NotificationCompat.Action(
                if (state.playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (state.playing) getString(R.string.notification_media_pause) else getString(R.string.notification_media_play),
                buildServicePendingIntent(ACTION_PLAY_PAUSE, 12),
            ),
        )
        compactActionIndexes += actionIndex
        actionIndex += 1

        if (state.canSkipNext) {
            builder.addAction(
                NotificationCompat.Action(
                    android.R.drawable.ic_media_next,
                    getString(R.string.notification_media_next),
                    buildServicePendingIntent(ACTION_NEXT, 13),
                ),
            )
            compactActionIndexes += actionIndex
            actionIndex += 1
        }

        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_menu_close_clear_cancel,
                getString(R.string.notification_media_stop),
                buildServicePendingIntent(ACTION_STOP, 14),
            ),
        )

        val mediaStyle = MediaStyle().setMediaSession(mediaSession.sessionToken)
        if (compactActionIndexes.isNotEmpty()) {
            mediaStyle.setShowActionsInCompactView(*compactActionIndexes.take(3).toIntArray())
        }
        builder.setStyle(mediaStyle)

        return builder.build()
    }

    private fun buildContentPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 10, intent, flags)
    }

    private fun buildServicePendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, MediaPlaybackService::class.java).apply {
            this.action = action
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, requestCode, intent, flags)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel_media_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notification_channel_media_description)
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun loadArtworkBitmap(artworkPath: String?): Bitmap? {
        val normalizedPath = artworkPath?.trim().orEmpty()
        if (normalizedPath.isNotEmpty()) {
            BitmapFactory.decodeFile(normalizedPath)?.let { return it }
        }
        return BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
    }

    private fun emitAction(action: String) {
        MainActivity.emitOrBufferMediaAction(applicationContext, action)
    }
}