/*
 * Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
 * Original © 2020 Sasikanath Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.
 */

package com.pinnit.flutter

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.TileService

/**
 * Quick Settings tile: "new pinned note".
 *
 * The user pulls down the shade, taps the tile, and the app opens straight
 * into the blank editor — one tap from shade to "new note", no warm-up of the
 * main UI required. The tile is stateless (never active/inactive); it only
 * launches the activity with the `new_note` extra, which MainActivity
 * forwards to Dart via the pins channel (`openNewEditor`).
 */
class NewNoteTileService : TileService() {

    override fun onClick() {
        super.onClick()

        // Step 1 — tell the already-running Dart isolate to put a blank editor
        // on the Navigator *before* we bring up any UI. The engine is pre-warmed
        // in PinnitApplication and stays alive in the background, so this works
        // even when no Activity exists.
        val prepared = PinnitApplication.notifyNewEditor()

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("new_note", true)
        }

        val launch = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // API 34+ requires the PendingIntent variant.
                val pi = PendingIntent.getActivity(
                    this,
                    /* requestCode = */ 0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                startActivityAndCollapse(pi)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }

        if (prepared) {
            // Step 2 — give Dart a couple of frames to finish pushing the route
            // so the Activity's very first frame is already the editor. The
            // shade is animating away during those ~90 ms anyway, so nothing
            // feels delayed.
            Handler(Looper.getMainLooper()).postDelayed(launch, 90)
        } else {
            // Dart wasn't reachable (engine still starting) — fall back to the
            // old route; MainActivity forwards the extra to Dart itself.
            launch()
        }
    }
}
