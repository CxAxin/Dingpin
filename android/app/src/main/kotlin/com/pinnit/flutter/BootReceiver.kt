package com.pinnit.flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Re-starts the foreground service after the device boots so that pinned
/// notifications and history listening come back automatically.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            PinnitForegroundService.start(context)
        }
    }
}
