package io.github.ialexpovad.povad

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.Parcel
import android.util.Log
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A rugged handheld's built-in expansion port. Its UART (/dev/ttyHSL1)
 * belongs to the handheld's device-control service: the service opens
 * it at a baud rate, powers the port's 3.3 V and 5 V rails, and moves bytes.
 * The service has no line-format, flow-control or modem-line setter, so only
 * 8N1 without flow control is accepted.
 *
 * Bytes are forwarded unchanged in both directions. One receiver thread
 * reads the service's buffer for the session's lifetime; read() returns what
 * it has queued without waiting, the same contract as [UsbSerialSession].
 */
object BuiltinExpansionPort {
    /** The device name the picker and the native selection use. */
    const val DEVICE_NAME = "builtin:expansion"
    
    private const val SERVICE_PACKAGE = "com.techinfo.devicemanager"
    private const val SERVICE_CLASS = "com.techinfo.devicemanager.service.DeviceControlService"
    private const val SERVICE_ACTION = "techinfo.intent.action.DEVICE_CONTROL"
    private const val BIND_TIMEOUT_MS = 3000L

    // The port's rails need a moment before the first byte reaches an
    // attached instrument.
    private const val POWER_SETTLE_MS = 300L
    private val claimed = AtomicBoolean()

    private fun serviceIntent() = Intent(SERVICE_ACTION)
        .setComponent(ComponentName(SERVICE_PACKAGE, SERVICE_CLASS))

    /** This handheld's device-control service, which owns the port, is installed. */
    fun present(context: Context): Boolean =
        context.packageManager.resolveService(serviceIntent(), 0) != null

    /** Invoked on the transport worker thread, never the main thread. */
    fun open(
        context: Context,
        baud: Int,
        dataBits: Int,
        parity: Int,
        stopBitsX10: Int,
        hardwareFlow: Boolean,
    ): UsbSession {
        if (!present(context)) throw IOException("No expansion port on this device")
        if (baud <= 0 || baud > 4_000_000) throw IOException("Unsupported baud rate")
        if (dataBits != 8 || parity.toChar() != 'N' || stopBitsX10 != 10 || hardwareFlow) {
            throw IOException("The expansion port supports 8N1 without flow control only")
        }
        if (!claimed.compareAndSet(false, true)) throw IOException("The expansion port is already open")
        val session = ExpansionSession(context.applicationContext) { claimed.set(false) }
        try {
            session.start(serviceIntent(), baud, BIND_TIMEOUT_MS, POWER_SETTLE_MS)
            return session
        } catch (error: Exception) {
            session.close()
            throw error
        }
    }
}

private class ExpansionSession(
    private val context: Context,
    private val released: () -> Unit,
) : UsbSession, ServiceConnection {
    private val serviceReady = CountDownLatch(1)
    private val closed = AtomicBoolean()
    private val lock = Object()
    private val received = ArrayDeque<ByteArray>()
    private var receivedOffset = 0
    private var receivedSize = 0
    @Volatile private var service: IBinder? = null
    @Volatile private var failure: String? = null
    @Volatile private var handle = 0
    private var bound = false
    private var reader: Thread? = null

    fun start(intent: Intent, baud: Int, bindTimeoutMs: Long, powerSettleMs: Long) {
        bound = context.bindService(intent, this, Context.BIND_AUTO_CREATE)
        if (!bound) throw IOException("Device service unavailable")
        if (!serviceReady.await(bindTimeoutMs, TimeUnit.MILLISECONDS) || service == null) {
            throw IOException("Device service did not answer")
        }
        handle = call(CALL_OPEN) {
            writeString(SERIAL_PATH)
            writeInt(baud)
        }.use { it.readInt() }
        if (handle <= 0) throw IOException("Device service refused the port")
        writeNode(POWER_3V3, "1")
        writeNode(POWER_5V, "1")
        Log.i(TAG, "stage=powered baud=$baud")
        if (powerSettleMs > 0) Thread.sleep(powerSettleMs)
        reader = Thread({ readLoop() }, "povad-expansion-read").apply {
            isDaemon = true
            start()
        }
    }

    override fun onServiceConnected(name: ComponentName, binder: IBinder) {
        if (!closed.get()) service = binder
        serviceReady.countDown()
    }

    override fun onServiceDisconnected(name: ComponentName) {
        service = null
        if (!closed.get()) failure = "Expansion port device service disconnected"
    }

    private fun readLoop() {
        val scratch = ByteArray(OEM_READ_BYTES)
        try {
            while (!closed.get()) {
                val count = call(CALL_READ) {
                    writeInt(handle)
                    writeInt(OEM_READ_BYTES)
                    writeInt(OEM_READ_BYTES)
                }.use { reply ->
                    val count = reply.readInt()
                    reply.readByteArray(scratch)
                    count
                }
                if (count < 0 || count > OEM_READ_BYTES) {
                    throw IOException("Expansion port read count invalid")
                }
                if (count == 0) {
                    Thread.sleep(2)
                    continue
                }
                synchronized(lock) {
                    if (receivedSize + count > MAX_BUFFERED) {
                        throw IOException("Expansion port input queue overflow; delivery is uncertain")
                    }
                    received.addLast(scratch.copyOf(count))
                    receivedSize += count
                }
            }
        } catch (_: InterruptedException) {
            // close() stops the reader.
        } catch (error: IOException) {
            if (!closed.get()) failure = error.message ?: "Expansion port read failed"
        }
    }

    override fun read(buffer: ByteArray): Int {
        failure?.let { throw IOException(it) }
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

    override fun write(buffer: ByteArray, length: Int): Int {
        if (length < 0 || length > buffer.size) throw IOException("Invalid expansion port write length")
        failure?.let { throw IOException(it) }
        if (length == 0) return 0
        val frame = buffer.copyOf(length)
        val written = call(CALL_WRITE) {
            writeInt(handle)
            writeByteArray(frame)
            writeInt(frame.size)
        }.use { it.readInt() }
        // A short write is reported by C++ as uncertain delivery, never replayed.
        return written
    }

    /** Powers the port down and releases it. */
    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        val thread = reader
        thread?.interrupt()
        thread?.join(2000)
        if (service != null && handle > 0) {
            try { writeNode(POWER_3V3, "0") } catch (_: IOException) {}
            try { writeNode(POWER_5V, "0") } catch (_: IOException) {}
            try {
                call(CALL_CLOSE) { writeInt(handle) }.recycle()
            } catch (_: IOException) {
                // The service may already be gone; the rails were asked off.
            }
            handle = 0
        }
        if (bound) {
            try { context.unbindService(this) } catch (_: IllegalArgumentException) {}
            bound = false
        }
        service = null
        Log.i(TAG, "stage=closed")
        released()
    }

    private fun writeNode(path: String, value: String) {
        call(CALL_WRITE_NODE) {
            writeString(path)
            writeString(value)
        }.recycle()
    }

    /** One device-service transaction; the caller recycles the reply. */
    private fun call(code: Int, arguments: Parcel.() -> Unit): Parcel {
        val binder = service ?: throw IOException("Device service disconnected")
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            data.writeInterfaceToken(DESCRIPTOR)
            data.arguments()
            if (!binder.transact(code, data, reply, 0)) {
                throw IOException("Device service rejected call $code")
            }
            reply.readException()
            return reply
        } catch (error: Exception) {
            reply.recycle()
            if (error is IOException) throw error
            throw IOException("Device service call $code failed", error)
        } finally {
            data.recycle()
        }
    }

    private inline fun <T> Parcel.use(block: (Parcel) -> T): T =
        try { block(this) } finally { recycle() }

    private companion object {
        const val TAG = "PovadExpansion"
        const val DESCRIPTOR = "com.techinfo.devicemanager.IDeviceControlInterface"
        const val SERIAL_PATH = "/dev/ttyHSL1"
        const val POWER_3V3 = "/sys/class/ext_dev/function/ext_dev_3v3_enable"
        const val POWER_5V = "/sys/class/ext_dev/function/ext_dev_5v_enable"
        const val OEM_READ_BYTES = 4048
        const val CALL_WRITE_NODE = 1
        const val CALL_OPEN = 3
        const val CALL_READ = 4
        const val CALL_WRITE = 5
        const val CALL_CLOSE = 6
        const val MAX_BUFFERED = 1 shl 20
    }
}
