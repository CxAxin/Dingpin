/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/// A lightweight foreground service that keeps the app process alive so that
/// pinned notifications survive aggressive OEM battery management and so the
/// [PinnitNotificationListenerService] can keep recording history.
///
/// It is started automatically when the listener service is bound, on boot, and
/// when the user opens the app. On Android 14+ it uses the `specialUse`
/// foreground-service type.
class PinnitForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "pinnit_service"
        const val CHANNEL_NAME = "顶顶 后台服务"
        const val NOTIFICATION_ID = 0x4E87 // "Nu" ;)

        fun start(context: Context) {
            val intent = Intent(context, PinnitForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        // If the service is killed, restart it with the last intent.
        return START_STICKY
    }

    /// The user swiped the app out of recents. On aggressive OEMs (MIUI /
    /// HyperOS) this normally also kills the foreground service, which would
    /// take the pinned notifications down with it. Restart it so they survive
    /// — this only works if the user has granted "Autostart" in the OEM's
    /// settings (see the in-app guidance).
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            start(this)
        } catch (_: Exception) {
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "保持通知固定和监听服务运行"
            setShowBadge(false)
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("顶顶 正在运行")
            .setContentText("固定通知和通知历史监听服务保持活跃")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
