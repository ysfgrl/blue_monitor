package com.ysfgrl.blue_monitor_lib

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.hoho.android.usbserial.driver.SerialTimeoutException
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** USB host serial implementation; all serial I/O runs outside the platform thread. */
class BlueMonitorLibPlugin : FlutterPlugin, BlueMonitorLibApi, MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var context: Context
    private lateinit var usb: UsbManager
    private lateinit var channel: MethodChannel
    private lateinit var workers: java.util.concurrent.ExecutorService
    private val sessions = linkedMapOf<String, Connection>()
    private val opening = linkedMapOf<String, OpenRequest>()
    private val permissionRequests = mutableSetOf<Int>()
    private var dataSink: PigeonEventSink<SerialDataMessage>? = null
    private var stateSink: PigeonEventSink<SerialConnectionMessage>? = null
    private var attached = false
    private var permissionAction = ""

    private class OpenRequest(
        val info: SerialInfoMessage,
        val port: UsbSerialPort,
        val config: SerialConfigMessage,
        val callback: (Result<Unit>) -> Unit,
    )

    private class Connection(
        val info: SerialInfoMessage,
        val port: UsbSerialPort,
        val deviceConnection: UsbDeviceConnection,
    ) {
        val closed = AtomicBoolean(false)
        val writer = Executors.newSingleThreadExecutor()
        lateinit var reader: SerialInputOutputManager
    }

    private val dataHandler = object : SerialDataReceivedStreamHandler() {
        override fun onListen(p0: Any?, sink: PigeonEventSink<SerialDataMessage>) {
            dataSink = sink
        }
        override fun onCancel(p0: Any?) { dataSink = null }
    }
    private val stateHandler = object : SerialConnectionChangedStreamHandler() {
        override fun onListen(p0: Any?, sink: PigeonEventSink<SerialConnectionMessage>) {
            stateSink = sink
        }
        override fun onCancel(p0: Any?) { stateSink = null }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (!attached) return
            when (intent.action) {
                permissionAction -> {
                    val deviceId = intent.getIntExtra("requestDeviceId", -1)
                    permissionRequests.remove(deviceId)
                    opening.values.filter { it.port.device.deviceId == deviceId }.toList().forEach {
                        if (usb.hasPermission(it.port.device)) openPort(it)
                        else failOpen(it, FlutterError("usb-permission-denied", "USB access was denied."))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = deviceExtra(intent) ?: return
                    opening.values.filter { it.port.device.deviceName == device.deviceName }.toList().forEach {
                        failOpen(it, FlutterError("device-disconnected", "USB device disconnected."))
                    }
                    sessions.values.filter { it.port.device.deviceName == device.deviceName }.toList().forEach {
                        closeConnection(it, "USB device disconnected.")
                    }
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun deviceExtra(intent: Intent): UsbDevice? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        else intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        usb = context.getSystemService(Context.USB_SERVICE) as UsbManager
        workers = Executors.newCachedThreadPool()
        permissionAction = "${context.packageName}.BLUE_MONITOR_USB_PERMISSION.${UUID.randomUUID()}"
        val filter = IntentFilter(permissionAction).apply { addAction(UsbManager.ACTION_USB_DEVICE_DETACHED) }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
        attached = true
        BlueMonitorLibApi.setUp(binding.binaryMessenger, this)
        SerialDataReceivedStreamHandler.register(binding.binaryMessenger, dataHandler)
        SerialConnectionChangedStreamHandler.register(binding.binaryMessenger, stateHandler)
        channel = MethodChannel(binding.binaryMessenger, "blue_monitor_lib")
        channel.setMethodCallHandler(this)
    }

    private fun discover(): List<Pair<SerialInfoMessage, UsbSerialPort>> =
        UsbSerialProber.getDefaultProber().findAllDrivers(usb).flatMap { driver ->
            driver.ports.map { port ->
                val device = driver.device
                val product = device.productName?.takeIf { it.isNotBlank() } ?: driver.javaClass.simpleName
                val path = "usb:${device.deviceName}:${port.portNumber}"
                SerialInfoMessage("$product (${port.portNumber})", path) to port
            }
        }.sortedBy { it.first.path }

    override fun getSerialList(callback: (Result<List<SerialInfoMessage>>) -> Unit) {
        callback(runCatching { discover().map { it.first } })
    }

    override fun getConnectedPorts(callback: (Result<List<SerialInfoMessage>>) -> Unit) {
        callback(Result.success(sessions.values.filter { !it.closed.get() }.map { it.info }))
    }

    override fun connect(path: String, config: SerialConfigMessage, callback: (Result<Unit>) -> Unit) {
        if (sessions.containsKey(path) || opening.containsKey(path)) {
            callback(Result.failure(FlutterError("port-busy", "Port is already open or opening.")))
            return
        }
        if (config.baudRate !in 1..Int.MAX_VALUE.toLong() || config.dataBits !in 5L..8L) {
            callback(Result.failure(FlutterError("invalid-config", "Invalid baud rate or data bits.")))
            return
        }
        val found = runCatching { discover().find { it.first.path == path } }
        if (found.isFailure || found.getOrNull() == null) {
            callback(Result.failure(found.exceptionOrNull() ?: FlutterError("port-not-found", "USB serial port was not found.")))
            return
        }
        val (info, port) = found.getOrThrow()!!
        val request = OpenRequest(info, port, config, callback)
        opening[path] = request
        if (usb.hasPermission(port.device)) {
            openPort(request)
        } else if (permissionRequests.add(port.device.deviceId)) {
            try {
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                val intent = Intent(permissionAction).setPackage(context.packageName)
                    .putExtra("requestDeviceId", port.device.deviceId)
                val pending = PendingIntent.getBroadcast(context, port.device.deviceId, intent, flags)
                usb.requestPermission(port.device, pending)
            } catch (error: Throwable) {
                permissionRequests.remove(port.device.deviceId)
                failOpen(request, error)
            }
        }
    }

    private fun failOpen(request: OpenRequest, error: Throwable) {
        if (opening[request.info.path] !== request) return
        opening.remove(request.info.path)
        request.callback(Result.failure(error))
    }

    private fun openPort(request: OpenRequest) {
        workers.execute {
            var deviceConnection: UsbDeviceConnection? = null
            try {
                deviceConnection = usb.openDevice(request.port.device)
                    ?: throw FlutterError("open-failed", "USB device could not be opened.")
                val port = request.port
                port.open(deviceConnection)
                val stopBits = when (request.config.stopBits) {
                    SerialStopBits.ONE -> UsbSerialPort.STOPBITS_1
                    SerialStopBits.ONE_POINT_FIVE -> UsbSerialPort.STOPBITS_1_5
                    SerialStopBits.TWO -> UsbSerialPort.STOPBITS_2
                }
                val parity = when (request.config.parity) {
                    SerialParity.NONE -> UsbSerialPort.PARITY_NONE
                    SerialParity.ODD -> UsbSerialPort.PARITY_ODD
                    SerialParity.EVEN -> UsbSerialPort.PARITY_EVEN
                    SerialParity.MARK -> UsbSerialPort.PARITY_MARK
                    SerialParity.SPACE -> UsbSerialPort.PARITY_SPACE
                }
                port.setParameters(request.config.baudRate.toInt(), request.config.dataBits.toInt(), stopBits, parity)
                val flow = when (request.config.flowControl) {
                    SerialFlowControl.NONE -> UsbSerialPort.FlowControl.NONE
                    SerialFlowControl.RTS_CTS -> UsbSerialPort.FlowControl.RTS_CTS
                    SerialFlowControl.XON_XOFF -> UsbSerialPort.FlowControl.XON_XOFF
                }
                if (!port.supportedFlowControl.contains(flow)) {
                    throw FlutterError("unsupported-config", "This USB serial driver does not support $flow flow control.")
                }
                port.flowControl = flow
                val connection = Connection(request.info, port, deviceConnection)
                connection.reader = SerialInputOutputManager(port, object : SerialInputOutputManager.Listener {
                    override fun onNewData(data: ByteArray) {
                        val bytes = data.copyOf()
                        main.post {
                            if (attached && sessions[connection.info.path] === connection && !connection.closed.get()) {
                                dataSink?.success(SerialDataMessage(connection.info.path, bytes))
                            }
                        }
                    }
                    override fun onRunError(error: Exception) {
                        main.post {
                            if (attached && sessions[connection.info.path] === connection && !connection.closed.get()) {
                                closeConnection(connection, error.message ?: "Serial read failed.")
                            }
                        }
                    }
                })
                main.post {
                    if (!attached || opening[request.info.path] !== request) {
                        closeResources(connection)
                    } else {
                        opening.remove(request.info.path)
                        sessions[request.info.path] = connection
                        try {
                            connection.reader.start()
                            stateSink?.success(SerialConnectionMessage(request.info.path, SerialConnectionState.CONNECTED))
                            request.callback(Result.success(Unit))
                        } catch (error: Throwable) {
                            sessions.remove(request.info.path)
                            closeResources(connection)
                            request.callback(Result.failure(error))
                        }
                    }
                }
            } catch (error: Throwable) {
                runCatching { request.port.close() }
                runCatching { deviceConnection?.close() }
                main.post { if (attached) failOpen(request, error) }
            }
        }
    }

    private fun closeResources(connection: Connection, completed: (Throwable?) -> Unit = {}) {
        connection.closed.set(true)
        connection.writer.shutdown()
        // A separate worker closes the port to interrupt a pending USB read/write.
        // This also handles opens which complete after the Flutter engine detaches.
        Thread({
            val stopFailure = runCatching { connection.reader.stop() }.exceptionOrNull()
            val closeFailure = runCatching { connection.port.close() }.exceptionOrNull()
            val usbFailure = runCatching { connection.deviceConnection.close() }.exceptionOrNull()
            val failure = stopFailure ?: closeFailure ?: usbFailure
            main.post { completed(failure) }
        }, "blue-monitor-close").start()
    }

    private fun closeConnection(connection: Connection, reason: String? = null, completed: (Throwable?) -> Unit = {}) {
        if (!connection.closed.compareAndSet(false, true)) {
            completed(null)
            return
        }
        // Keep the path reserved until the descriptor has actually closed.
        closeResources(connection) { failure ->
            val current = sessions[connection.info.path] === connection
            if (current) sessions.remove(connection.info.path)
            if (attached && current) {
                stateSink?.success(SerialConnectionMessage(
                    connection.info.path, SerialConnectionState.DISCONNECTED,
                    reason ?: failure?.message,
                ))
            }
            completed(failure)
        }
    }

    override fun disconnect(path: String, callback: (Result<Unit>) -> Unit) {
        opening[path]?.let { failOpen(it, FlutterError("connect-cancelled", "Connection cancelled.")) }
        val connection = sessions[path]
        if (connection == null) {
            callback(Result.success(Unit))
        } else {
            closeConnection(connection) { error ->
                if (attached) callback(if (error == null) Result.success(Unit) else Result.failure(error))
            }
        }
    }

    override fun write(path: String, data: ByteArray, timeoutMs: Long, callback: (Result<Long>) -> Unit) {
        val connection = sessions[path]
        if (connection == null || connection.closed.get()) {
            callback(Result.failure(FlutterError("port-not-connected", "Port is not connected.")))
            return
        }
        if (data.isEmpty()) {
            callback(Result.success(0L))
            return
        }
        // USB driver timeout=0 means infinite, whereas our API defines it as
        // nonblocking. Reject it rather than silently blocking a USB worker.
        if (timeoutMs !in 1..Int.MAX_VALUE.toLong()) {
            callback(Result.failure(FlutterError("unsupported-timeout", "Android USB writes require a positive timeout within Int range.")))
            return
        }
        val bytes = data.copyOf()
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        connection.writer.execute {
            val result = runCatching {
                if (connection.closed.get()) throw FlutterError("port-closed", "Port closed before write completed.")
                val remaining = deadline - SystemClock.elapsedRealtime()
                if (remaining <= 0) 0L else {
                    try {
                        connection.port.write(bytes, remaining.toInt())
                        bytes.size.toLong()
                    } catch (error: SerialTimeoutException) {
                        if (error.bytesTransferred < 0) throw FlutterError("write-timeout", "Partial byte count is unknown.")
                        error.bytesTransferred.coerceAtMost(bytes.size).toLong()
                    }
                }
            }
            main.post {
                if (attached) {
                    val error = result.exceptionOrNull()
                    callback(result)
                    if (error != null && error !is FlutterError && sessions[path] === connection) {
                        closeConnection(connection, error.message ?: "Serial write failed.")
                    }
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getPlatformVersion") result.success("Android ${Build.VERSION.RELEASE}")
        else result.notImplemented()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        context.unregisterReceiver(receiver)
        BlueMonitorLibApi.setUp(binding.binaryMessenger, null)
        EventChannel(binding.binaryMessenger,
            "dev.flutter.pigeon.blue_monitor_lib.BlueMonitorLibEvents.serialDataReceived",
            MessagesPigeonMethodCodec).setStreamHandler(null)
        EventChannel(binding.binaryMessenger,
            "dev.flutter.pigeon.blue_monitor_lib.BlueMonitorLibEvents.serialConnectionChanged",
            MessagesPigeonMethodCodec).setStreamHandler(null)
        channel.setMethodCallHandler(null)
        dataSink = null
        stateSink = null
        opening.values.toList().forEach { failOpen(it, FlutterError("plugin-detached", "Flutter engine detached.")) }
        permissionRequests.clear()
        sessions.values.toList().forEach { closeConnection(it) }
        workers.shutdown()
    }
}
