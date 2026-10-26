import Cocoa
import Darwin
import FlutterMacOS
import IOKit

private final class DataEvents: SerialDataReceivedStreamHandler {
  var sink: PigeonEventSink<SerialDataMessage>?
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<SerialDataMessage>) { self.sink = sink }
  override func onCancel(withArguments arguments: Any?) { sink = nil }
}

private final class ConnectionEvents: SerialConnectionChangedStreamHandler {
  var sink: PigeonEventSink<SerialConnectionMessage>?
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<SerialConnectionMessage>) { self.sink = sink }
  override func onCancel(withArguments arguments: Any?) { sink = nil }
}

private final class PendingWrite {
  let data: Data
  let deadline: TimeInterval
  let completion: (Result<Int64, Error>) -> Void
  var offset = 0

  init(data: Data, timeoutMs: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
    self.data = data
    self.deadline = ProcessInfo.processInfo.systemUptime + Double(timeoutMs) / 1000
    self.completion = completion
  }
}

private final class SerialPort {
  let fd: Int32
  let path: String
  let device: String
  var writes: [PendingWrite] = []

  init(fd: Int32, path: String) {
    self.fd = fd
    self.path = path
    self.device = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
  }

  deinit { Darwin.close(fd) }
}

public class BlueTerminalLibPlugin: NSObject, FlutterPlugin, BlueTerminalLibApi {
  private let dataEvents = DataEvents()
  private let connectionEvents = ConnectionEvents()
  private var ports: [String: SerialPort] = [:]
  private var timer: DispatchSourceTimer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BlueTerminalLibPlugin()
    BlueTerminalLibApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
    SerialDataReceivedStreamHandler.register(with: registrar.messenger, streamHandler: instance.dataEvents)
    SerialConnectionChangedStreamHandler.register(with: registrar.messenger, streamHandler: instance.connectionEvents)
    registrar.publish(instance)
  }

  private func failure(_ code: String, _ message: String? = nil) -> PigeonError {
    PigeonError(code: code, message: message ?? String(cString: strerror(errno)), details: nil)
  }

  func getSerialList(completion: @escaping (Result<[SerialInfoMessage], Error>) -> Void) {
    var iterator: io_iterator_t = 0
    let status = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOSerialBSDClient"), &iterator)
    guard status == KERN_SUCCESS else {
      completion(.failure(failure("list-failed", "IOKit serial discovery failed: \(status)")))
      return
    }
    defer { IOObjectRelease(iterator) }
    var paths = Set<String>()
    while true {
      let service = IOIteratorNext(iterator)
      if service == 0 { break }
      if let value = IORegistryEntryCreateCFProperty(service, "IOCalloutDevice" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
         let path = value as? String {
        paths.insert(path)
      }
      IOObjectRelease(service)
    }
    completion(.success(paths.sorted().map { SerialInfoMessage(name: ($0 as NSString).lastPathComponent, path: $0) }))
  }

  func getConnectedPorts(completion: @escaping (Result<[SerialInfoMessage], Error>) -> Void) {
    completion(.success(ports.keys.sorted().map { SerialInfoMessage(name: ($0 as NSString).lastPathComponent, path: $0) }))
  }

  private func findPort(_ path: String) -> SerialPort? {
    let device = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    return ports[path] ?? ports.values.first { $0.device == device }
  }

  func connect(path: String, config: SerialConfigMessage, completion: @escaping (Result<Void, Error>) -> Void) {
    guard !path.isEmpty, !path.utf8.contains(0) else {
      completion(.failure(failure("invalid-path", "Port path is empty or contains a null byte")))
      return
    }
    guard findPort(path) == nil else {
      completion(.failure(failure("port-busy", "Port is already connected")))
      return
    }
    let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC)
    guard fd >= 0 else {
      completion(.failure(failure("open-failed")))
      return
    }
    let port = SerialPort(fd: fd, path: path)
    do {
      guard ioctl(fd, TIOCEXCL) == 0 else { throw failure("open-failed") }
      try configure(fd, config)
      if path == "/dev/cu.Bluetooth-Incoming-Port" || path == "/dev/tty.Bluetooth-Incoming-Port" {
        // RFCOMM exposes virtual modem lines too. Advertise that this endpoint
        // is ready without toggling control lines on physical USB devices.
        var signals = Int32(TIOCM_DTR | TIOCM_RTS)
        guard ioctl(fd, TIOCMBIS, &signals) == 0 else { throw failure("configure-failed") }
        guard tcflow(fd, TCOON) == 0 else { throw failure("configure-failed") }
      }
    } catch {
      completion(.failure(error))
      return
    }
    ports[path] = port
    startPolling()
    connectionEvents.sink?.success(SerialConnectionMessage(path: path, state: .connected))
    completion(.success(()))
  }

  private func configure(_ fd: Int32, _ config: SerialConfigMessage) throws {
    guard (5...8).contains(config.dataBits), config.baudRate > 0, config.baudRate <= Int64(UInt32.max) else {
      throw failure("configure-failed", "Invalid baud rate or data bits")
    }
    guard config.stopBits != .onePointFive, config.parity != .mark, config.parity != .space else {
      throw failure("configure-failed", "macOS does not support 1.5 stop bits or mark/space parity")
    }
    var settings = termios()
    guard tcgetattr(fd, &settings) == 0 else { throw failure("configure-failed") }
    cfmakeraw(&settings)
    settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
    // cfmakeraw preserves modem flow control. Clear every Darwin hardware
    // handshake flag before applying the requested mode; inherited DSR/DCD
    // output gating can otherwise hold writes on Bluetooth serial ports.
    let hardwareFlow = tcflag_t(CRTSCTS | CDTR_IFLOW | CDSR_OFLOW | CCAR_OFLOW)
    settings.c_cflag &= ~(tcflag_t(CSIZE | CSTOPB | PARENB | PARODD) | hardwareFlow)
    settings.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY | INPCK | ISTRIP)
    let sizes = [CS5, CS6, CS7, CS8]
    settings.c_cflag |= tcflag_t(sizes[Int(config.dataBits) - 5])
    if config.stopBits == .two { settings.c_cflag |= tcflag_t(CSTOPB) }
    if config.parity != .none {
      settings.c_cflag |= tcflag_t(PARENB)
      settings.c_iflag |= tcflag_t(INPCK)
      if config.parity == .odd { settings.c_cflag |= tcflag_t(PARODD) }
    }
    if config.flowControl == .rtsCts { settings.c_cflag |= tcflag_t(CRTSCTS) }
    if config.flowControl == .xonXoff { settings.c_iflag |= tcflag_t(IXON | IXOFF) }
    withUnsafeMutableBytes(of: &settings.c_cc) { bytes in
      bytes[Int(VMIN)] = 1
      bytes[Int(VTIME)] = 0
    }
    // Apply a standard speed before IOSSIOSPEED, which also supports custom baud rates.
    guard cfsetispeed(&settings, speed_t(B9600)) == 0,
          cfsetospeed(&settings, speed_t(B9600)) == 0,
          tcsetattr(fd, TCSANOW, &settings) == 0 else { throw failure("configure-failed") }
    var speed = speed_t(config.baudRate)
    // IOKit/serial/ioss.h: _IOW('T', 2, speed_t).
    let setSpeed = UInt(0x80000000 | (MemoryLayout<speed_t>.size << 16) | (0x54 << 8) | 2)
    guard ioctl(fd, setSpeed, &speed) == 0 else { throw failure("configure-failed") }
  }

  func disconnect(path: String, completion: @escaping (Result<Void, Error>) -> Void) {
    if let port = findPort(path) { closePort(port.path) }
    completion(.success(()))
  }

  private func closePort(_ path: String, error: String? = nil) {
    guard let port = ports.removeValue(forKey: path) else { return }
    let pending = port.writes
    port.writes.removeAll()
    for write in pending {
      write.completion(.failure(failure("port-closed", error ?? "Port closed before write completed")))
    }
    connectionEvents.sink?.success(SerialConnectionMessage(path: path, state: .disconnected, error: error))
    if ports.isEmpty {
      timer?.cancel()
      timer = nil
    }
  }

  func write(path: String, data: FlutterStandardTypedData, timeoutMs: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
    guard timeoutMs >= 0 else {
      completion(.failure(failure("invalid-timeout", "Timeout must be nonnegative")))
      return
    }
    guard let port = findPort(path) else {
      completion(.failure(failure("port-not-connected", "Port is not connected")))
      return
    }
    if data.data.isEmpty || (timeoutMs == 0 && !port.writes.isEmpty) {
      completion(.success(0))
      return
    }
    let pending = PendingWrite(data: data.data, timeoutMs: timeoutMs, completion: completion)
    if timeoutMs == 0 {
      do {
        try advanceWrite(port, pending)
        completion(.success(Int64(pending.offset)))
      } catch {
        completion(.failure(error))
        closePort(port.path, error: String(describing: error))
      }
    } else {
      port.writes.append(pending)
    }
  }

  private func advanceWrite(_ port: SerialPort, _ pending: PendingWrite) throws {
    let count = pending.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
      Darwin.write(port.fd, bytes.baseAddress!.advanced(by: pending.offset), min(65536, bytes.count - pending.offset))
    }
    if count > 0 {
      trace("TX", path: port.path, data: pending.data.subdata(in: pending.offset..<(pending.offset + count)))
      pending.offset += count
    }
    if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR {
      throw failure("write-failed")
    }
  }

  private func trace(_ direction: String, path: String, data: Data) {
    #if DEBUG
    let hex = data.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ")
    NSLog("[blue_terminal_lib] %@ %@ %ld bytes: %@", direction, path, data.count, hex)
    #endif
  }

  private func startPolling() {
    guard timer == nil else { return }
    // All descriptors are nonblocking. Keep each main-thread tick bounded.
    let source = DispatchSource.makeTimerSource(queue: .main)
    source.schedule(deadline: .now(), repeating: .milliseconds(10))
    source.setEventHandler { [weak self] in self?.pollPorts() }
    timer = source
    source.resume()
  }

  private func pollPorts() {
    for port in Array(ports.values) {
      var status = pollfd(fd: port.fd, events: Int16(POLLIN), revents: 0)
      let result = Darwin.poll(&status, 1, 0)
      var error: String?
      if result < 0 && errno != EINTR { error = String(cString: strerror(errno)) }
      if status.revents & Int16(POLLIN) != 0 {
        var bytes = [UInt8](repeating: 0, count: 4096)
        for _ in 0..<4 {
          let count = bytes.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            Darwin.read(port.fd, buffer.baseAddress!, buffer.count)
          }
          if count > 0 {
            let data = Data(bytes.prefix(count))
            trace("RX", path: port.path, data: data)
            dataEvents.sink?.success(SerialDataMessage(path: port.path, data: FlutterStandardTypedData(bytes: data)))
          } else {
            if count == 0 { error = "Serial device disconnected" }
            else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { error = String(cString: strerror(errno)) }
            break
          }
        }
      }
      if status.revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 { error = "Serial device disconnected" }
      if error == nil, let pending = port.writes.first {
        do {
          if ProcessInfo.processInfo.systemUptime < pending.deadline { try advanceWrite(port, pending) }
          if pending.offset == pending.data.count || ProcessInfo.processInfo.systemUptime >= pending.deadline {
            port.writes.removeFirst()
            pending.completion(.success(Int64(pending.offset)))
          }
        } catch let writeError {
          error = String(describing: writeError)
        }
      }
      if let error = error { closePort(port.path, error: error) }
    }
  }

  deinit {
    timer?.cancel()
    for port in ports.values {
      for pending in port.writes {
        pending.completion(.failure(PigeonError(code: "port-closed", message: "Plugin detached", details: nil)))
      }
    }
  }
}
