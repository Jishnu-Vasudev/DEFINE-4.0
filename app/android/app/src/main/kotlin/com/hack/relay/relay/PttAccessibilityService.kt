package com.hack.relay.relay

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

// Hardware push-to-talk: volume up/down become the talk button, also on the lock screen.
// Keys are only consumed while the app has armed it (setting on, signed in); otherwise volume works normally.
class PttAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var armed = false
        @Volatile var running = false
        var sink: ((String) -> Unit)? = null // set by MainActivity, forwards "down"/"up" to Flutter
    }

    private val main = Handler(Looper.getMainLooper())
    private var heldKey = -1

    override fun onServiceConnected() {
        running = true
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (!armed || sink == null || (code != KeyEvent.KEYCODE_VOLUME_UP && code != KeyEvent.KEYCODE_VOLUME_DOWN)) return false
        when (event.action) {
            KeyEvent.ACTION_DOWN -> if (event.repeatCount == 0 && heldKey == -1) {
                heldKey = code
                main.post { sink?.invoke("down") }
            }
            KeyEvent.ACTION_UP -> if (code == heldKey) {
                heldKey = -1
                main.post { sink?.invoke("up") }
            }
        }
        return true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {
        if (heldKey != -1) main.post { sink?.invoke("up") }
        heldKey = -1
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }
}
