package com.hack.relay.relay

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "relay/hwptt")
        PttAccessibilityService.sink = { action -> ch.invokeMethod("key", action) }
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setArmed" -> {
                    PttAccessibilityService.armed = call.arguments as Boolean
                    result.success(null)
                }
                "isEnabled" -> result.success(serviceEnabled())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun serviceEnabled(): Boolean {
        val me = ComponentName(this, PttAccessibilityService::class.java).flattenToString()
        val list = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return list.split(':').any { it.equals(me, ignoreCase = true) }
    }
}
