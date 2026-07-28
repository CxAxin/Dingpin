/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// Captures notifications posted by other apps and forwards the interesting
/// bits (package, app label, title, text) to Dart over the shared
/// [PinnitApplication.channel].
///
/// The user must grant access in system settings
/// (Settings -> Notification access). When granted, the system binds this
/// service and [onNotificationPosted] fires for every new notification.
class PinnitNotificationListenerService : NotificationListenerService() {

    companion object {
        /// Set while the service lives so Dart can ask it to cancel a specific
        /// third-party notification (used when "topping" a history entry).
        var instance: PinnitNotificationListenerService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        // Keep the process alive while the listener is active.
        PinnitForegroundService.start(this)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        PinnitForegroundService.start(this)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val sbn = sbn ?: return
        val notification = sbn.notification ?: return

        // Never record our own pinned / scheduled notifications.
        if (sbn.packageName == applicationContext.packageName) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

        val appName = try {
            val pm = packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(sbn.packageName, 0)).toString()
        } catch (e: Exception) {
            sbn.packageName
        }

        val map = mapOf(
            "packageName" to sbn.packageName,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "postedAt" to System.currentTimeMillis()
        )
        // Use the shared channel owned by the application's cached engine.
        PinnitApplication.channel.invokeMethod("onNotificationPosted", map)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val sbn = sbn ?: return

        // If one of our own pinned/scheduled notifications was swiped away by
        // the user (or an aggressive OEM that ignores Notification.FLAG_ONGOING),
        // tell Dart so it can re-post any remaining pinned notifications.
        if (sbn.packageName == applicationContext.packageName) {
            PinnitApplication.channel.invokeMethod(
                "onOwnNotificationRemoved",
                mapOf("id" to sbn.id)
            )
        }
    }
}
