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

    /// When the user taps a pinned notification's body, the native
    /// [PinnitPins] content intent carries the note's `uuid` here. Forward it
    /// to Dart so the editor opens for that note.
    private fun handleIntent(intent: Intent?) {
        val uuid = intent?.getStringExtra("uuid") ?: return
        val engine = FlutterEngineCache.getInstance().get(PinnitApplication.FLUTTER_ENGINE_ID)
            ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, PinnitApplication.PINS_CHANNEL)
        // Give the Flutter UI a moment to attach its Navigator before pushing.
        Handler(Looper.getMainLooper()).postDelayed({
            channel.invokeMethod("openEditor", uuid)
        }, 400)
    }
}
