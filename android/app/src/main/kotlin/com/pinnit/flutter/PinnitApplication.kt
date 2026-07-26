/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/// Pre-warms a single [FlutterEngine] for the whole app's lifetime so the
/// [PinnitNotificationListenerService] can stream captured notifications to
/// Dart even when no UI is on screen.
///
/// It also hosts the shared [MethodChannel] used for the (system-owned)
/// notification-access permission flow. Registering the handler here — rather
/// than in the listener service — guarantees the Flutter side can always reach
/// it, even before the user has granted notification access (at which point
/// the listener service is not yet created by the system).
class PinnitApplication : Application() {

    companion object {
        const val FLUTTER_ENGINE_ID = "pinnit_engine"
        const val CHANNEL_NAME = "pinnit/notification_listener"
        const val PINS_CHANNEL = "pinnit/pins"

        /// Shared channel instance used by the listener service to push
        /// captured notifications to Dart.
        lateinit var channel: MethodChannel
            private set

        /// Channel used to drive the native pinned-notification layer
        /// ([PinnitPins] / [PinnitActionReceiver]) from Dart and back.
        lateinit var pinsChannel: MethodChannel
            private set
    }

    override fun onCreate() {
        super.onCreate()

        // Start the lightweight foreground service so pinned notifications and
        // the notification listener survive aggressive battery management.
        PinnitForegroundService.start(this)

        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        // Register plugins on the cached engine so sqflite / local
        // notifications / etc. work from the background listener too.
        GeneratedPluginRegistrant.registerWith(engine)
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, engine)

        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        registerListenerChannel()

        pinsChannel = MethodChannel(engine.dartExecutor.binaryMessenger, PINS_CHANNEL)
        registerPinsChannel()
    }

    /// Handles Dart → native calls for the pinned-notification layer.
    ///   * `showPinned`  — post / refresh a pinned notification (native side).
    ///   * `cancelPinned` — remove a pinned notification from the shade.
    private fun registerPinsChannel() {
        pinsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showPinned" -> {
                    val args = call.arguments as? Map<*, *>
                    val uuid = args?.get("uuid") as? String ?: ""
                    val title = args?.get("title") as? String
                    val content = args?.get("content") as? String
                    PinnitPins.show(applicationContext, uuid, title, content)
                    result.success(null)
                }
                "cancelPinned" -> {
                    val uuid = call.arguments as? String
                    if (uuid != null) PinnitPins.cancel(applicationContext, uuid)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Handles Dart → native calls for the permission flow. The handler lives
    /// on the application's engine, so it survives regardless of whether the
    /// MainActivity or the listener service is currently alive.
    private fun registerListenerChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openListenerSettings" -> {
                    try {
                        openNotificationListenerSettings()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SETTINGS", e.message, null)
                    }
                }
                "isListenerEnabled" -> result.success(isListenerEnabled())
                else -> result.notImplemented()
            }
        }
    }

    /// Open the system "Notification access" screen.
    ///
    /// On MIUI / HyperOS (Xiaomi) and Android 12+ the generic
    /// [Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS] intent is often
    /// ignored, so we try a few known fallbacks before giving up and letting
    /// the UI show manual instructions.
    private fun openNotificationListenerSettings() {
        val pkg = packageName
        val tries = mutableListOf<Intent>()

        // 1. Generic action — works on AOSP / most ROMs.
        tries.add(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )

        // 2. Explicit Settings activity for notification access.
        tries.add(
            Intent().setComponent(
                ComponentName(
                    "com.android.settings",
                    "com.android.settings.Settings\$NotificationAccessSettingsActivity"
                )
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )

        // 3. Xiaomi / HyperOS: the app's notification-access page directly.
        tries.add(
            Intent().setComponent(
                ComponentName(
                    "com.android.settings",
                    "com.android.settings.applications.NotifyUsageSettingsActivity"
                )
            ).putExtra("packageName", pkg)
                .putExtra("app_package_name", pkg)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        // 3b. Alternate MIUI activity name.
        tries.add(
            Intent().setComponent(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.notification.permission.NotificationAccessPermissionActivity"
                )
            ).putExtra("packageName", pkg)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )

        for (intent in tries) {
            if (canResolve(intent)) {
                startActivity(intent)
                return
            }
        }

        // Last resort: just open the app's own settings detail page.
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(android.net.Uri.parse("package:$pkg"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(fallback)
    }

    private fun canResolve(intent: Intent): Boolean {
        return try {
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null
        } catch (e: Exception) {
            false
        }
    }

    private fun isListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        return enabledListeners?.contains(packageName) ?: false
    }
}
