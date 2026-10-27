package io.github.ialexpovad.povad

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import java.io.IOException
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Platform callbacks are serialized through a worker-owned session. */
object PovadBleHost {
    private lateinit var context: Context
    private var active: BleSession? = null

    fun initialize(value: Context) { context = value.applicationContext }

    @SuppressLint("MissingPermission")
    fun restoreNameAfterCrash() {
        if (!permitted()) return
        val prefs = context.getSharedPreferences("povad_ble_name", Context.MODE_PRIVATE)
        val previous = prefs.getString("previous", null) ?: return
        context.getSystemService(BluetoothManager::class.java)?.adapter?.name = previous
        prefs.edit().remove("previous").apply()
    }

    fun available(): Boolean {
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) &&
            adapter?.isEnabled == true && adapter.isMultipleAdvertisementSupported &&
            adapter.bluetoothLeAdvertiser != null
    }

    fun permitted(): Boolean = Build.VERSION.SDK_INT < 31 ||
        (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED)

    @JvmStatic
    @Synchronized
    fun open(name: String, service: String, write: String, notify: String,
             limit: Int, maxAgeMs: Int, requirePairing: Boolean): BleSession {
        if (active != null) throw IOException("Bluetooth adapter already has a Povad BLE bridge")
        if (!permitted()) throw IOException("Bluetooth permission is required")
        if (!available()) throw IOException("BLE advertising is unavailable or Bluetooth is off")
        return BleSession(context, name, uuid(service), uuid(write), uuid(notify), limit, maxAgeMs,
            requirePairing)
            .also { it.start(); active = it }
    }

    @Synchronized
    fun release(session: BleSession) { if (active === session) active = null }

    private fun uuid(value: String): UUID = UUID.fromString(
        if (value.length == 4) "0000$value-0000-1000-8000-00805f9b34fb" else value
    )
}

@SuppressLint("MissingPermission")
class BleSession(
    private val context: Context,
    private val name: String,
    private val serviceId: UUID,
    private val writeId: UUID,
    private val notifyId: UUID,
    private val limit: Int,
    private val maxAgeMs: Int,
    /** Bonded, encrypted access; false is open like a BLE UART module (BT24). */
    private val requirePairing: Boolean,
) {
    private fun unpaired(device: BluetoothDevice) =
        requirePairing && device.bondState != BluetoothDevice.BOND_BONDED

    private data class QueuedWrite(val bytes: ByteArray, val receivedAt: Long)
    private val manager = context.getSystemService(BluetoothManager::class.java)
    private val adapter: BluetoothAdapter = manager.adapter
    private val advertiser = adapter.bluetoothLeAdvertiser
    private var server: BluetoothGattServer? = null
    private var notifier: BluetoothGattCharacteristic? = null
    private val lock = Any()
    private val incoming = ArrayDeque<QueuedWrite>()
    private var incomingOffset = 0
    private var incomingSize = 0
    private var owner: BluetoothDevice? = null
    private var disconnected = false
    private var notifyPending = false
    private var notifyStartedAt = 0L
    private var mtu = 23
    private var event = 0
    private var fault: String? = null
    private var closed = false
    private val serviceReady = CountDownLatch(1)
    private val advertisingReady = CountDownLatch(1)
    private var serviceStatus = -1
    private var advertisingStatus = -1
    private var previousAdapterName: String? = null

    private val callback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            Log.i("PovadBleHost", "GATT service publication status=$status")
            serviceStatus = status
            serviceReady.countDown()
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            Log.i("PovadBleHost", "GATT link state=$newState status=$status")
            synchronized(lock) {
                if (newState == BluetoothProfile.STATE_DISCONNECTED && owner?.address == device.address) {
                    disconnected = true
                }
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, value: Int) {
            Log.i("PovadBleHost", "GATT negotiated MTU=$value")
            synchronized(lock) { if (owner?.address == device.address) mtu = value }
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice, requestId: Int, offset: Int,
            descriptor: BluetoothGattDescriptor,
        ) {
            val status: Int
            val value: ByteArray?
            synchronized(lock) {
                when {
                    descriptor.uuid != CCCD -> {
                        status = BluetoothGatt.GATT_FAILURE
                        value = null
                    }
                    unpaired(device) -> {
                        event = 3
                        status = BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION
                        value = null
                    }
                    else -> {
                        val current = if (owner?.address == device.address && !disconnected) {
                            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        } else {
                            BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                        }
                        if (offset > current.size) {
                            status = BluetoothGatt.GATT_INVALID_OFFSET
                            value = null
                        } else {
                            status = BluetoothGatt.GATT_SUCCESS
                            value = current.copyOfRange(offset, current.size)
                        }
                    }
                }
            }
            if (server?.sendResponse(device, requestId, status, offset, value) != true) {
                synchronized(lock) { fault = "BLE descriptor response failed" }
            }
            Log.i("PovadBleHost", "GATT descriptor read response status=$status")
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray,
        ) {
            var status = BluetoothGatt.GATT_FAILURE
            synchronized(lock) {
                if (descriptor.uuid == CCCD && !preparedWrite && offset == 0 &&
                    value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                    status = when {
                        unpaired(device) -> {
                            event = 3
                            BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION
                        }
                        owner != null && owner?.address != device.address -> {
                            event = 2
                            BluetoothGatt.GATT_FAILURE
                        }
                        else -> {
                            owner = device
                            disconnected = false
                            event = 1
                            BluetoothGatt.GATT_SUCCESS
                        }
                    }
                } else if (descriptor.uuid == CCCD &&
                    value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
                    if (owner?.address == device.address) disconnected = true
                    status = BluetoothGatt.GATT_SUCCESS
                }
            }
            if (responseNeeded && server?.sendResponse(device, requestId, status, 0, null) != true) {
                synchronized(lock) { fault = "BLE subscription response failed" }
            }
            Log.i("PovadBleHost", "GATT subscription response status=$status")
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray,
        ) {
            var status = BluetoothGatt.GATT_FAILURE
            synchronized(lock) {
                status = when {
                    characteristic.uuid != writeId || preparedWrite || offset != 0 ||
                        (requirePairing && !responseNeeded) -> BluetoothGatt.GATT_INVALID_OFFSET
                    unpaired(device) -> {
                        event = 3
                        BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION
                    }
                    // A client may write before it subscribes: the first one
                    // to do either owns the bridge until it leaves.
                    owner == null -> {
                        owner = device
                        disconnected = false
                        event = 1
                        if (value.size > limit - incomingSize) {
                            fault = "BLE input queue overflow; delivery is uncertain"
                            BluetoothGatt.GATT_FAILURE
                        } else {
                            incoming.addLast(QueuedWrite(value.clone(), android.os.SystemClock.elapsedRealtime()))
                            incomingSize += value.size
                            BluetoothGatt.GATT_SUCCESS
                        }
                    }
                    owner?.address != device.address || disconnected -> {
                        event = 2
                        BluetoothGatt.GATT_FAILURE
                    }
                    value.size > limit - incomingSize -> {
                        fault = "BLE input queue overflow; delivery is uncertain"
                        BluetoothGatt.GATT_FAILURE
                    }
                    else -> {
                        incoming.addLast(QueuedWrite(value.clone(), android.os.SystemClock.elapsedRealtime()))
                        incomingSize += value.size
                        BluetoothGatt.GATT_SUCCESS
                    }
                }
            }
            if (responseNeeded && server?.sendResponse(device, requestId, status, 0, null) != true) {
                synchronized(lock) { fault = "BLE write response failed; delivery is uncertain" }
            }
            Log.i("PovadBleHost", "GATT write response status=$status bytes=${value.size}")
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.w("PovadBleHost", "GATT notification status=$status")
            }
            synchronized(lock) {
                if (owner?.address != device.address || disconnected) return@synchronized
                notifyPending = false
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fault = "BLE notification failed; delivery is uncertain"
                }
            }
        }
    }

    fun start() {
        try {
            val gatt = manager.openGattServer(context, callback) ?: throw IOException("Cannot open GATT server")
            server = gatt
            val service = BluetoothGattService(serviceId, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            // Open mode serves clients of BLE UART modules (BT24, HM-10)
            // that never pair; it accepts both write kinds, as they do.
            val write = BluetoothGattCharacteristic(
                writeId,
                if (requirePairing) BluetoothGattCharacteristic.PROPERTY_WRITE
                else BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                if (requirePairing) BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED
                else BluetoothGattCharacteristic.PERMISSION_WRITE,
            )
            val notify = BluetoothGattCharacteristic(
                notifyId, BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                if (requirePairing) BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED
                else BluetoothGattCharacteristic.PERMISSION_READ,
            )
            notify.addDescriptor(BluetoothGattDescriptor(
                CCCD,
                if (requirePairing) BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED or
                    BluetoothGattDescriptor.PERMISSION_WRITE_ENCRYPTED
                else BluetoothGattDescriptor.PERMISSION_READ or
                    BluetoothGattDescriptor.PERMISSION_WRITE,
            ))
            service.addCharacteristic(write)
            service.addCharacteristic(notify)
            notifier = notify
            if (!gatt.addService(service) || !serviceReady.await(3, TimeUnit.SECONDS) ||
                serviceStatus != BluetoothGatt.GATT_SUCCESS) throw IOException("Cannot publish GATT service")
            previousAdapterName = adapter.name
            if (previousAdapterName != name) {
                context.getSharedPreferences("povad_ble_name", Context.MODE_PRIVATE)
                    .edit().putString("previous", previousAdapterName).commit()
                if (!adapter.setName(name)) throw IOException("Cannot set BLE advertising name")
            }
            val data = AdvertiseData.Builder().addServiceUuid(ParcelUuid(serviceId)).build()
            val response = AdvertiseData.Builder().setIncludeDeviceName(true).build()
            advertiser.startAdvertising(
                AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                    .setConnectable(true).build(), data, response,
                object : AdvertiseCallback() {
                    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                        advertisingStatus = 0
                        advertisingReady.countDown()
                    }
                    override fun onStartFailure(errorCode: Int) {
                        advertisingStatus = errorCode
                        advertisingReady.countDown()
                    }
                }.also { advertiseCallback = it },
            )
            if (!advertisingReady.await(3, TimeUnit.SECONDS) || advertisingStatus != 0) {
                throw IOException("Cannot start BLE advertising ($advertisingStatus)")
            }
            Log.i("PovadBleHost", "GATT advertising started")
        } catch (error: Exception) {
            close()
            throw error
        }
    }

    private var advertiseCallback: AdvertiseCallback? = null

    fun poll(): Int = synchronized(lock) {
        if (incoming.isNotEmpty() &&
            android.os.SystemClock.elapsedRealtime() - incoming.first().receivedAt > maxAgeMs) {
            fault = "BLE input queue timed out; delivery is uncertain"
        }
        if (notifyPending && android.os.SystemClock.elapsedRealtime() - notifyStartedAt > maxAgeMs) {
            fault = "BLE notification queue timed out; delivery is uncertain"
        }
        fault?.let { throw IOException(it) }
        val result = event
        event = 0
        result
    }

    fun connected(): Boolean = synchronized(lock) { owner != null }

    fun pending(): Boolean = synchronized(lock) { incomingSize != 0 || notifyPending }

    fun read(buffer: ByteArray): Int = synchronized(lock) {
        fault?.let { throw IOException(it) }
        if (disconnected) return@synchronized 0
        if (incoming.isEmpty()) return@synchronized -1
        val front = incoming.first().bytes
        val n = minOf(buffer.size, front.size - incomingOffset)
        front.copyInto(buffer, 0, incomingOffset, incomingOffset + n)
        incomingOffset += n
        incomingSize -= n
        if (incomingOffset == front.size) {
            incoming.removeFirst()
            incomingOffset = 0
        }
        n
    }

    fun write(buffer: ByteArray, length: Int): Int {
        val target: BluetoothDevice
        val characteristic: BluetoothGattCharacteristic
        val count: Int
        synchronized(lock) {
            fault?.let { throw IOException(it) }
            target = owner ?: return 0
            if (disconnected || notifyPending) return 0
            characteristic = notifier ?: return 0
            count = minOf(length, maxOf(20, mtu - 3), 512)
            notifyPending = true
            notifyStartedAt = android.os.SystemClock.elapsedRealtime()
        }
        val bytes = buffer.copyOfRange(0, count)
        val started = if (Build.VERSION.SDK_INT >= 33) {
            server?.notifyCharacteristicChanged(target, characteristic, false, bytes) ==
                android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = bytes
            @Suppress("DEPRECATION")
            server?.notifyCharacteristicChanged(target, characteristic, false) == true
        }
        if (!started) {
            synchronized(lock) { notifyPending = false }
            return 0
        }
        return count
    }

    fun closeClient(): Boolean {
        val previous: BluetoothDevice?
        synchronized(lock) {
            previous = owner
            owner = null
            disconnected = false
            notifyPending = false
            incoming.clear()
            incomingSize = 0
            incomingOffset = 0
        }
        previous?.let { server?.cancelConnection(it) }
        return true
    }

    fun close(): Boolean {
        if (closed) return true
        try {
            advertiseCallback?.let { advertiser.stopAdvertising(it) }
            advertiseCallback = null
            closeClient()
            server?.clearServices()
            server?.close()
            server = null
            previousAdapterName?.let {
                if (it != name) adapter.name = it
                context.getSharedPreferences("povad_ble_name", Context.MODE_PRIVATE)
                    .edit().remove("previous").apply()
            }
            closed = true
            PovadBleHost.release(this)
            return true
        } catch (_: RuntimeException) {
            return false
        }
    }

    companion object {
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
