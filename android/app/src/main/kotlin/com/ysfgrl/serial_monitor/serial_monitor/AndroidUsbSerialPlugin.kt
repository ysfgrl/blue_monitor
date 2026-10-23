package com.ysfgrl.serial_monitor.serial_monitor

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.hoho.android.usbserial.driver.SerialTimeoutException
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/** Serializes USB operations off the UI thread and reports completed writes. */
class AndroidUsbSerialPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var manager: UsbManager
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var sink: EventChannel.EventSink? = null
    private var port: UsbSerialPort? = null
    private var reader: SerialInputOutputManager? = null
    private var pending: PendingOpen? = null
    private var session = 0
    private var nextRequest = 0
    @Volatile private var disposed = false

    private data class PendingOpen(
        val port: UsbSerialPort,
        val baudRate: Int,
        val request: Int,
        val result: MethodChannel.Result,
    )

    private val permissionAction get() = "${context.packageName}.USB_SERIAL_PERMISSION"

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            @Suppress("DEPRECATION")
            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE) ?: return
            enqueue {
                if (intent.action == UsbManager.ACTION_USB_DEVICE_DETACHED) {
                    if (pending?.port?.device?.deviceName == device.deviceName) {
                        cancelPending("USB cihazı bağlantı açılırken çıkarıldı.")
                    }
                    if (port?.device?.deviceName == device.deviceName) {
                        val failedSession = session
                        releasePort()
                        emitError(failedSession, "USB cihazı çıkarıldı.")
                    }
                } else if (intent.action == permissionAction) {
                    val opening = pending ?: return@enqueue
                    if (opening.request != intent.getIntExtra("request", -1) ||
                        opening.port.device.deviceName != device.deviceName) return@enqueue
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) &&
                        manager.hasPermission(device)) {
                        finishOpen(opening)
                    } else {
                        cancelPending("USB erişim izni verilmedi. Yeniden bağlanıp Android izin penceresinde izin verin.")
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        methods = MethodChannel(binding.binaryMessenger, "serial_monitor/usb")
        events = EventChannel(binding.binaryMessenger, "serial_monitor/usb/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        val filter = IntentFilter(permissionAction).apply {
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    private fun enqueue(action: () -> Unit) {
        if (disposed) return
        try {
            worker.execute(action)
        } catch (_: RejectedExecutionException) {
            // The engine was detached while an I/O callback was being queued.
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        enqueue {
            try {
                when (call.method) {
                    "listPorts" -> {
                        val ports = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
                            .flatMap { driver ->
                                driver.ports.map { candidate ->
                                    val device = candidate.device
                                    val description = listOfNotNull(
                                        device.manufacturerName, device.productName,
                                    ).distinct().joinToString(" ")
                                    mapOf(
                                        "name" to portName(candidate),
                                        "description" to if (driver.ports.size > 1)
                                            "$description · Port ${candidate.portNumber + 1}"
                                        else description,
                                    )
                                }
                            }.sortedBy { it["name"] }
                        main.post { result.success(ports) }
                    }
                    "open" -> beginOpen(call, result)
                    "write" -> write(call, result)
                    "close" -> {
                        cancelPending("USB bağlantısı açılırken iptal edildi.")
                        releasePort()
                        main.post { result.success(null) }
                    }
                    else -> main.post { result.notImplemented() }
                }
            } catch (error: Exception) {
                Log.e(TAG, "USB ${call.method} failed", error)
                main.post { result.error("USB_${call.method.uppercase()}",
                    "USB işlemi başarısız: ${error.message}", null) }
            }
        }
    }

    private fun portName(candidate: UsbSerialPort): String =
        if (candidate.portNumber == 0) candidate.device.deviceName
        else "${candidate.device.deviceName}#${candidate.portNumber}"

    private fun beginOpen(call: MethodCall, result: MethodChannel.Result) {
        check(port == null && pending == null) { "Önce mevcut bağlantıyı kapatın." }
        val name = requireNotNull(call.argument<String>("name"))
        val baudRate = requireNotNull(call.argument<Int>("baudRate"))
        require(baudRate > 0) { "Geçersiz baud hızı." }
        val candidate = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
            .flatMap { it.ports }.firstOrNull { portName(it) == name }
            ?: throw IllegalStateException("USB seri cihazı bulunamadı. Port listesini yenileyin.")
        val opening = PendingOpen(candidate, baudRate, ++nextRequest, result)
        pending = opening
        if (manager.hasPermission(candidate.device)) {
            finishOpen(opening)
        } else {
            val intent = Intent(permissionAction).setPackage(context.packageName)
                .putExtra("request", opening.request)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
            try {
                manager.requestPermission(candidate.device,
                    PendingIntent.getBroadcast(context, opening.request, intent, flags))
            } catch (error: Exception) {
                pending = null
                throw error
            }
        }
    }

    private fun finishOpen(opening: PendingOpen) {
        pending = null
        val candidate = opening.port
        val connection = try {
            manager.openDevice(candidate.device)
        } catch (error: Exception) {
            main.post { opening.result.error("USB_OPEN", "USB cihazına erişilemiyor: ${error.message}", null) }
            return
        }
        if (connection == null) {
            main.post { opening.result.error("USB_OPEN", "USB cihazına erişilemiyor.", null) }
            return
        }
        try {
            candidate.open(connection)
            candidate.setParameters(opening.baudRate, UsbSerialPort.DATABITS_8,
                UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            candidate.flowControl = UsbSerialPort.FlowControl.NONE
            val controls = candidate.supportedControlLines
            if (controls.contains(UsbSerialPort.ControlLine.DTR)) candidate.dtr = true
            if (controls.contains(UsbSerialPort.ControlLine.RTS)) candidate.rts = true
            val openedSession = ++session
            port = candidate
            reader = SerialInputOutputManager(candidate, object : SerialInputOutputManager.Listener {
                override fun onNewData(data: ByteArray) {
                    emit(mapOf("type" to "data", "session" to openedSession, "bytes" to data.copyOf()))
                }

                override fun onRunError(error: Exception) {
                    enqueue {
                        if (port === candidate && session == openedSession) {
                            releasePort()
                            emitError(openedSession, "USB veri bağlantısı koptu: ${error.message}")
                        }
                    }
                }
            }).also {
                it.readTimeout = 200
                it.start()
            }
            Log.d(TAG, "Opened ${candidate.driver.javaClass.simpleName} at ${opening.baudRate} baud")
            main.post { opening.result.success(openedSession) }
        } catch (error: Exception) {
            reader?.setListener(null)
            reader?.stop()
            reader = null
            port = null
            runCatching { candidate.close() }
            connection.close()
            Log.e(TAG, "USB open failed", error)
            main.post { opening.result.error("USB_OPEN", "USB portu açılamadı: ${error.message}", null) }
        }
    }

    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val active = port ?: throw IllegalStateException("Bağlı bir USB portu yok.")
        check(call.argument<Int>("session") == session) { "USB bağlantısı değişti." }
        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
        val written = try {
            // This call waits for the USB transfer rather than merely queuing it.
            active.write(bytes, WRITE_TIMEOUT_MS)
            bytes.size
        } catch (timeout: SerialTimeoutException) {
            timeout.bytesTransferred.coerceIn(0, bytes.size)
        }
        Log.d(TAG, "TX requested=${bytes.size} written=$written")
        main.post { result.success(written) }
    }

    private fun cancelPending(message: String) {
        val opening = pending ?: return
        pending = null
        main.post { opening.result.error("USB_CANCELLED", message, null) }
    }

    private fun releasePort() {
        reader?.setListener(null)
        reader?.stop()
        reader = null
        val active = port
        port = null
        if (active != null) runCatching { active.close() }
    }

    private fun emitError(failedSession: Int, message: String) =
        emit(mapOf("type" to "error", "session" to failedSession, "message" to message))

    private fun emit(event: Map<String, Any>) {
        main.post { if (!disposed) sink?.success(event) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        disposed = true
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        context.unregisterReceiver(receiver)
        worker.execute {
            cancelPending("Seri port servisi kapatıldı.")
            releasePort()
        }
        worker.shutdown()
    }

    companion object {
        private const val TAG = "SerialMonitorUsb"
        private const val WRITE_TIMEOUT_MS = 2000
    }
}
