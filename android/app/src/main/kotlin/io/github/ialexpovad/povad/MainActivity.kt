package io.github.ialexpovad.povad

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionAction = "io.github.ialexpovad.povad.USB_PERMISSION"
    private var permissionResult: MethodChannel.Result? = null
    private var permissionDeviceName: String? = null
    private var receiverRegistered = false
    private var nativeLibraryAvailable = false

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != permissionAction &&
                intent.action != UsbManager.ACTION_USB_DEVICE_DETACHED) return
            val device = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
            }
            val requested = permissionDeviceName
            if (device?.deviceName != requested || requested == null) return
            val granted = intent.action == permissionAction &&
                intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) &&
                PovadUsbHost.hasPermission(requested)
            permissionResult?.success(granted)
            permissionResult = null
            permissionDeviceName = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PovadUsbHost.initialize(applicationContext)
        nativeLibraryAvailable = try {
            System.loadLibrary("povad_core")
            true
        } catch (_: UnsatisfiedLinkError) {
            false
        }
        val filter = IntentFilter(permissionAction)
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(permissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(permissionReceiver, filter)
        }
        receiverRegistered = true
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "povad/usb_host")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(
                        nativeLibraryAvailable &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
                    )
                    "list" -> result.success(PovadUsbHost.deviceList())
                    "permission" -> {
                        val name = call.argument<String>("deviceName")
                        val device = name?.let(PovadUsbHost::deviceForPermission)
                        if (device == null) {
                            result.error("USB_MISSING", "USB device is no longer connected", null)
                        } else if (PovadUsbHost.hasPermission(name)) {
                            result.success(true)
                        } else if (permissionResult != null) {
                            result.error("USB_BUSY", "Another USB permission request is pending", null)
                        } else {
                            permissionResult = result
                            permissionDeviceName = name
                            val intent = Intent(permissionAction).setPackage(packageName)
                            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                            val pending = PendingIntent.getBroadcast(this, 0, intent, flags)
                            val manager = getSystemService(Context.USB_SERVICE) as UsbManager
                            try {
                                manager.requestPermission(device, pending)
                            } catch (_: SecurityException) {
                                permissionResult = null
                                permissionDeviceName = null
                                result.error("USB_PERMISSION", "Cannot request USB permission", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        permissionResult?.error("USB_CLOSED", "USB permission request was interrupted", null)
        permissionResult = null
        permissionDeviceName = null
        if (receiverRegistered) unregisterReceiver(permissionReceiver)
        receiverRegistered = false
        super.onDestroy()
    }
}
