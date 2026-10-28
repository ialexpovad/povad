package io.github.ialexpovad.povad

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val permissionAction = "io.github.ialexpovad.povad.USB_PERMISSION"
    private var permissionResult: MethodChannel.Result? = null
    private var permissionDeviceName: String? = null
    private var receiverRegistered = false
    private var nativeLibraryAvailable = false
    private var blePermissionResult: MethodChannel.Result? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as PovadApplication).engine()

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        (application as PovadApplication).setActivity(this)
    }

    override fun onPause() {
        (application as PovadApplication).setActivity(null)
        super.onPause()
    }

    fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9268)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 9269) {
            blePermissionResult?.success(PovadBleHost.permitted() && PovadBleHost.available())
            blePermissionResult = null
        }
    }

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
        PovadBleHost.initialize(applicationContext)
        nativeLibraryAvailable = try {
            System.loadLibrary("povad_core")
            true
        } catch (error: UnsatisfiedLinkError) {
            Log.e("PovadUsbHost", "Native USB worker could not load", error)
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
                    "nativeAvailable" -> result.success(nativeLibraryAvailable)
                    "available" -> result.success(
                        nativeLibraryAvailable &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
                    )
                    "list" -> result.success(PovadUsbHost.deviceList())
                    "permission" -> {
                        val name = call.argument<String>("deviceName")
                        val device = name?.let(PovadUsbHost::deviceForPermission)
                        if (name != null && PovadUsbHost.isBuiltin(name)) {
                            result.success(true)
                        } else if (device == null) {
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "povad/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cacheDir" -> result.success(cacheDir.absolutePath)
                    "install" -> result.success(installUpdate(call.argument<String>("path")))
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "povad/ble_host")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> {
                        if (PovadBleHost.permitted()) {
                            result.success(PovadBleHost.available())
                        } else if (blePermissionResult != null) {
                            result.error("BLE_BUSY", "Bluetooth permission request is pending", null)
                        } else if (Build.VERSION.SDK_INT >= 31) {
                            blePermissionResult = result
                            requestPermissions(arrayOf(
                                Manifest.permission.BLUETOOTH_CONNECT,
                                Manifest.permission.BLUETOOTH_ADVERTISE,
                            ), 9269)
                        } else {
                            result.success(PovadBleHost.available())
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        if (!flutterEngine.dartExecutor.isExecutingDart) {
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }
    }

    /**
     * Hands a verified APK to Android's package installer. Android asks the
     * user to confirm, and checks that the signing certificate matches.
     */
    private fun installUpdate(path: String?): String {
        val updates = File(cacheDir, "povad-update").canonicalFile
        val file = path?.let { File(it).canonicalFile }
        if (file == null || !file.isFile || !file.path.startsWith(updates.path + File.separator)) {
            return "missing"
        }
        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
            )
            return "permission"
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return "started"
    }

    override fun onDestroy() {
        blePermissionResult?.error("BLE_CLOSED", "Bluetooth permission request was interrupted", null)
        blePermissionResult = null
        permissionResult?.error("USB_CLOSED", "USB permission request was interrupted", null)
        permissionResult = null
        permissionDeviceName = null
        if (receiverRegistered) unregisterReceiver(permissionReceiver)
        receiverRegistered = false
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, "povad/usb_host").setMethodCallHandler(null)
            MethodChannel(it, "povad/update").setMethodCallHandler(null)
            MethodChannel(it, "povad/ble_host").setMethodCallHandler(null)
        }
        (application as PovadApplication).setActivity(null)
        super.onDestroy()
    }
}
