package io.github.ialexpovad.povad

import android.app.Application
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** The engine, and therefore the Dart owner of the bridge, outlives an Activity. */
class PovadApplication : Application() {
    private var engine: FlutterEngine? = null
    private var activity = WeakReference<MainActivity>(null)

    override fun onCreate() {
        super.onCreate()
        PovadUsbHost.initialize(this)
    }

    fun engine(): FlutterEngine {
        engine?.let { return it }
        val created = FlutterEngine(this)
        engine = created
        MethodChannel(created.dartExecutor.binaryMessenger, "povad/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val selection = call.argument<String>("selection") ?: ""
                        val separator = selection.lastIndexOf(':')
                        val deviceName = if (selection.startsWith("usb:") && separator > 4) {
                            selection.substring(4, separator)
                        } else null
                        if (deviceName == null || !PovadUsbHost.hasPermission(deviceName)) {
                            result.error("USB_PERMISSION", "Select and allow a USB serial device", null)
                        } else {
                            activity.get()?.requestNotificationPermissionIfNeeded()
                            val intent = Intent(this, PovadBridgeService::class.java)
                                .putExtra("status", call.argument<String>("status"))
                                .putExtra("generation", call.argument<Number>("generation")?.toLong() ?: 0L)
                            try {
                                if (Build.VERSION.SDK_INT >= 26) {
                                    startForegroundService(intent)
                                } else {
                                    startService(intent)
                                }
                                result.success(true)
                            } catch (error: RuntimeException) {
                                result.error("BACKGROUND_UNAVAILABLE", error.message, null)
                            }
                        }
                    }
                    "update" -> {
                        PovadBridgeService.updateNotification(
                            this,
                            call.argument<String>("status") ?: "Povad",
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, PovadBridgeService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        return created
    }

    fun setActivity(value: MainActivity?) {
        activity = WeakReference(value)
    }

    fun notifyServiceStopped(generation: Long) {
        engine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, "povad/background")
                .invokeMethod("serviceStopped", generation)
        }
    }
}
