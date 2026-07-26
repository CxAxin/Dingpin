/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Native implementation of the "pinned to the panel" notification.
 *
 * We post these from Kotlin (instead of the Flutter local-notifications
 * plugin) so the action buttons ("复制" / "取消固定") are delivered to a native
 * [PinnitActionReceiver] BroadcastReceiver. The plugin's
 * `onDidReceiveNotificationResponse` only fires dependably while the app is in
 * the foreground, but pinned notifications are tapped from the shade where the
 * UI is in the background — so a native receiver is the reliable path.
 */
object PinnitPins {

    const val CHANNEL_ID = "pinnit_pinned"
    const val CHANNEL_NAME = "固定通知"
    const val CHANNEL_DESC = "固定到通知栏的通知"
    const val ACTION_COPY = "copy"
    const val ACTION_UNPIN = "unpin"

    /** Stable, positive 32-bit id — MUST match [NotificationService.idOf]. */
    fun idOf(uuid: String): Int {
        val hex = uuid.replace("-", "").take(8)
        val parsed = hex.toLongOrNull(16) ?: uuid.hashCode().toLong()
        return (parsed and 0x7FFFFFFF).toInt()
    }

    fun show(context: Context, uuid: String, title: String?, content: String?) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = CHANNEL_DESC
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        val contentIntent = PendingIntent.getActivity(
            context,
            idOf(uuid),
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("uuid", uuid)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val copyIntent = actionIntent(context, uuid, ACTION_COPY, title, content, 1)
        val unpinIntent = actionIntent(context, uuid, ACTION_UNPIN, title, content, 2)

        val builder = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(if (title.isNullOrBlank()) "固定通知" else title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .addAction(0, "复制", copyIntent)
            .addAction(0, "取消固定", unpinIntent)

        if (!content.isNullOrBlank()) {
            builder.style = Notification.BigTextStyle().bigText(content)
        }

        nm.notify(idOf(uuid), builder.build())
    }

    fun cancel(context: Context, uuid: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(idOf(uuid))
    }

    private fun actionIntent(
        context: Context,
        uuid: String,
        action: String,
        title: String?,
        content: String?,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, PinnitActionReceiver::class.java).apply {
            putExtra("action", action)
            putExtra("uuid", uuid)
            putExtra("title", title)
            putExtra("content", content)
        }
        return PendingIntent.getBroadcast(
            context,
            (idOf(uuid) shl 3) + requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
