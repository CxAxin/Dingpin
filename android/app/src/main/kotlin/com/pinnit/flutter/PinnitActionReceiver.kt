/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Receives the copy / unpin taps from a pinned notification's action
 * buttons. Running as a BroadcastReceiver on the always-alive app process
 * (kept alive by [PinnitForegroundService]) means it fires reliably whether or
 * not the Flutter UI is currently on screen.
 */
class PinnitActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        val action = intent.getStringExtra("action") ?: return
        val uuid = intent.getStringExtra("uuid") ?: return

        when (action) {
            PinnitPins.ACTION_COPY -> {
                val title = intent.getStringExtra("title") ?: ""
                val body = intent.getStringExtra("content") ?: ""
                val text = listOf(title, body)
                    .filter { it.isNotBlank() }
                    .joinToString("\n")
                if (text.isNotBlank()) {
                    val cm =
                        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(
                        ClipData.newPlainText(
                            context.getString(R.string.clipboard_label),
                            text,
                        )
                    )
                    showToast(context, context.getString(R.string.copied_toast))
                }
            }

            PinnitPins.ACTION_UNPIN -> {
                // Tell Dart to flip the pin flag in the DB and refresh the
                // in-app list. Dart then cancels the system notification, which
                // (via the listener) triggers repinAll — but the DB already
                // says "unpinned", so it won't come back.
                notifyUnpinToDart(uuid)
            }
        }
    }

    private fun notifyUnpinToDart(uuid: String) {
        val engine = FlutterEngineCache.getInstance().get(PinnitApplication.FLUTTER_ENGINE_ID)
            ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, PinnitApplication.PINS_CHANNEL)
        channel.invokeMethod("unpin", uuid)
    }

    private fun showToast(context: Context, message: String) {
        // Background toasts are restricted on Android 12+, but the copy still
        // succeeds; ignore any failure silently.
        try {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        } catch (_: Exception) {
        }
    }
}
