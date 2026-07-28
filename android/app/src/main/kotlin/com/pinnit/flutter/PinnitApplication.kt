/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
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
                "shareFile" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String
                    val title = args?.get("title") as? String ?: "Export"
                    if (path != null) {
                        shareFile(path, title)
                        result.success(null)
                    } else {
                        result.error("ARG", "path required", null)
                    }
                }
                "saveFileToDownloads" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String
                    val name = args?.get("name") as? String ?: "pinnit_history.txt"
                    if (path != null) {
                        val ok = saveFileToDownloads(path, name)
                        result.success(ok)
                    } else {
                        result.error("ARG", "path required", null)
                    }
                }
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

    /// Share a local text file via the system share sheet (chooser), so the
    /// user can send the exported history .txt to any app (WeChat, cloud drive,
    /// Bluetooth…) without us touching scoped-storage permissions.
    ///
    /// The file must live under a path exposed by our [FileProvider]
    /// (`${applicationId}.fileprovider`, see `res/xml/file_paths.xml`) so other
    /// apps can read it under a temporary `FLAG_GRANT_READ_URI_PERMISSION`.
    private fun shareFile(path: String, title: String) {
        val file = java.io.File(path)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(
            applicationContext,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(intent, title)
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(chooser)
    }

    /// Save a local text file into the system Downloads folder so the user can
    /// open it later from any file manager without depending on a third-party
    /// sharing app. Uses MediaStore on API 29+ (no storage permission needed);
    /// falls back to the legacy public Downloads path on older devices.
    private fun saveFileToDownloads(srcPath: String, displayName: String): Boolean {
        val src = java.io.File(srcPath)
        if (!src.exists()) return false
        val resolver = applicationContext.contentResolver
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/Pinnit")
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return false
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                } ?: return false
                true
            } else {
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val target = java.io.File(dir, displayName)
                src.copyTo(target, overwrite = true)
                true
            }
        } catch (e: Exception) {
            false
        }
    }
}
