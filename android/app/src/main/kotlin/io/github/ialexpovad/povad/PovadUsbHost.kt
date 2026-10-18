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

/** This object is created, used, and closed only by the C++ worker thread. */
class UsbSession(
    private val manager: UsbManager,
    private val deviceName: String,
    private val port: UsbSerialPort,
    private val connection: UsbDeviceConnection,
) {
    fun read(buffer: ByteArray): Int {
        if (!manager.deviceList.containsKey(deviceName)) throw IOException("USB device disconnected")
        return port.read(buffer, buffer.size, 5)
    }

    fun write(buffer: ByteArray, length: Int): Int {
        if (length < 0 || length > buffer.size) throw IOException("Invalid USB write length")
        if (!manager.deviceList.containsKey(deviceName)) throw IOException("USB device disconnected")
        // The driver either writes the full length or throws. A partial-write
        // exception is reported by C++ as uncertain delivery, never replayed.
        port.write(buffer, length, 100)
        return length
    }

    fun close() {
        try {
            port.close()
        } finally {
            connection.close()
        }
    }
}
