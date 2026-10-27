package io.github.ialexpovad.povad

import android.content.Context
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import java.io.IOException

/** Permission is requested by the Activity. Only the C++ worker calls open. */
object PovadUsbHost {
    @Volatile private lateinit var manager: UsbManager

    fun initialize(context: Context) {
        manager = context.applicationContext.getSystemService(Context.USB_SERVICE) as UsbManager
    }

    fun deviceList(): List<Map<String, Any>> =
        UsbSerialProber.getDefaultProber().findAllDrivers(manager).flatMap { driver ->
            val device = driver.device
            driver.ports.mapIndexed { index, _ ->
                mapOf(
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "portIndex" to index,
                    "portCount" to driver.ports.size,
                    // The adapter's own name from its USB descriptor, when it
                    // has one.
                    "productName" to (device.productName?.trim() ?: ""),
                )
            }
        }

    fun hasPermission(deviceName: String): Boolean =
        manager.deviceList[deviceName]?.let(manager::hasPermission) == true

    fun deviceForPermission(deviceName: String) = manager.deviceList[deviceName]

    /** Invoked by JNI on the transport worker, after Android permission. */
    @JvmStatic
    fun open(
        specification: String,
        baud: Int,
        dataBits: Int,
        parity: Int,
        stopBitsX10: Int,
        hardwareFlow: Boolean,
        dtr: Boolean,
        rts: Boolean,
    ): UsbSession {
        if (!specification.startsWith("usb:")) throw IOException("Select a USB serial device")
        val separator = specification.lastIndexOf(':')
        if (separator <= 4) throw IOException("Invalid USB serial selection")
        val deviceName = specification.substring(4, separator)
        val portIndex = specification.substring(separator + 1).toIntOrNull()
            ?: throw IOException("Invalid USB serial port index")
        val device = manager.deviceList[deviceName] ?: throw IOException("USB device disconnected")
        if (!manager.hasPermission(device)) throw IOException("USB permission not granted")
        val driver = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
            .firstOrNull { it.device.deviceName == deviceName }
            ?: throw IOException("USB serial driver unavailable")
        val port = driver.ports.getOrNull(portIndex) ?: throw IOException("USB serial port unavailable")
        val connection = manager.openDevice(device) ?: throw IOException("Cannot open USB device")
        var opened = false
        try {
            port.open(connection)
            opened = true
            val usbParity = when (parity.toChar()) {
                'N' -> UsbSerialPort.PARITY_NONE
                'E' -> UsbSerialPort.PARITY_EVEN
                'O' -> UsbSerialPort.PARITY_ODD
                else -> throw IOException("Unsupported parity")
            }
            val usbStopBits = if (stopBitsX10 == 10) {
                UsbSerialPort.STOPBITS_1
            } else {
                UsbSerialPort.STOPBITS_2
            }
            port.setParameters(baud, dataBits, usbStopBits, usbParity)
            if (hardwareFlow) port.setFlowControl(UsbSerialPort.FlowControl.RTS_CTS)
            if (dtr) port.setDTR(true)
            if (rts && !hardwareFlow) port.setRTS(true)
            return UsbSession(manager, deviceName, port, connection)
        } catch (error: Exception) {
            try {
                if (opened) port.close() else connection.close()
            } catch (_: Exception) {
                connection.close()
            }
            throw error
        }
    }
}

/**
 * Created, used, and closed by the C++ worker thread. It owns one reader
 * thread for its lifetime: reading continuously with the driver's queued
 * request is how a USB adapter keeps up with a long reply (its own receive
 * buffer lasts milliseconds), which polled short reads between other work
 * cannot. close() stops and joins the reader before the port is released.
 */
class UsbSession(
    private val manager: UsbManager,
    private val deviceName: String,
    private val port: UsbSerialPort,
    private val connection: UsbDeviceConnection,
) {
    private val lock = Object()
    private val received = ArrayDeque<ByteArray>()
    private var receivedOffset = 0
    private var receivedSize = 0
    @Volatile private var failure: String? = null
    @Volatile private var stopping = false
    private val reader = Thread({ readLoop() }, "povad-usb-read").apply { isDaemon = true }
    private var attachedCheckedAt = 0L

    init { reader.start() }

    private fun readLoop() {
        val buffer = ByteArray(16 * 1024)
        while (!stopping) {
            val count = try {
                port.read(buffer, 0)
            } catch (_: Exception) {
                if (!stopping) failure = "Android USB serial read failed or device detached"
                return
            }
            if (count <= 0) continue
            synchronized(lock) {
                if (receivedSize + count > MAX_BUFFERED) {
                    failure = "USB input queue overflow; delivery is uncertain"
                    return
                }
                received.addLast(buffer.copyOf(count))
                receivedSize += count
            }
        }
    }

    // The attachment check is a binder call to the USB service; it runs at
    // most twice a second. A detached device also fails the transfer itself.
    private fun checkAttached() {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - attachedCheckedAt < 500) return
        attachedCheckedAt = now
        if (!manager.deviceList.containsKey(deviceName)) throw IOException("USB device disconnected")
    }

    /** Bytes the reader has received, without waiting; 0 when none. */
    fun read(buffer: ByteArray): Int {
        failure?.let { throw IOException(it) }
        checkAttached()
        synchronized(lock) {
            var copied = 0
            while (copied < buffer.size && received.isNotEmpty()) {
                val front = received.first()
                val count = minOf(buffer.size - copied, front.size - receivedOffset)
                System.arraycopy(front, receivedOffset, buffer, copied, count)
                copied += count
                receivedOffset += count
                if (receivedOffset == front.size) {
                    received.removeFirst()
                    receivedOffset = 0
                }
            }
            receivedSize -= copied
            return copied
        }
    }

    fun write(buffer: ByteArray, length: Int): Int {
        if (length < 0 || length > buffer.size) throw IOException("Invalid USB write length")
        failure?.let { throw IOException(it) }
        checkAttached()
        // The driver either writes the full length or throws. A partial-write
        // exception is reported by C++ as uncertain delivery, never replayed.
        port.write(buffer, length, 100)
        return length
    }

    fun close() {
        stopping = true
        try {
            // Closing the port cancels the reader's queued request.
            port.close()
        } finally {
            reader.join(2000)
            connection.close()
        }
    }

    private companion object {
        const val MAX_BUFFERED = 1 shl 20
    }
}
