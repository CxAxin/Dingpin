/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Reuse the engine pre-warmed in [PinnitApplication] so the notification
    /// listener and the UI share the same Dart isolate.
    override fun getCachedEngineId(): String {
        return PinnitApplication.FLUTTER_ENGINE_ID
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /// Two launch routes reach this point:
    ///  * the Quick Settings tile carries `new_note` — open a blank editor;
    ///  * a pinned notification's content intent carries `uuid` — open the
    ///    editor for that note.
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("new_note", false)) {
            invokeOnChannel("openNewEditor", null)
            return
        }
        val uuid = intent.getStringExtra("uuid") ?: return
        invokeOnChannel("openEditor", uuid)
    }

    /// Forward a launch request to Dart over the pins channel.
    ///
    /// No artificial delay here on purpose. Previously this waited 400 ms,
    /// which meant the home screen was on screen for ~400 ms before the editor
    /// slid in — the "flash of the main screen" the tile launch used to have.
    /// The Dart side now retries on its own if the Navigator isn't attached
    /// yet, and the tile pre-pushes the route before the Activity even starts.
    private fun invokeOnChannel(method: String, arg: String?) {
        val engine = FlutterEngineCache.getInstance().get(PinnitApplication.FLUTTER_ENGINE_ID)
            ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, PinnitApplication.PINS_CHANNEL)
        // Send immediately (so the editor is on screen before the first frame)
        // and re-send a couple of times afterwards. On a cold start the Dart
        // handler may not be registered yet and a dropped call would silently
        // open nothing. Duplicates are safe — the Dart side de-dupes by time
        // window and by uuid.
        val handler = Handler(Looper.getMainLooper())
        for (delay in longArrayOf(0, 150, 400)) {
            handler.postDelayed({ channel.invokeMethod(method, arg) }, delay)
        }
    }
}
