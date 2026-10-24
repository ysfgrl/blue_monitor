import 'package:pigeon/pigeon.dart';

// Pigeon has one swiftOut option. The generation script also writes that output
// to the macOS plugin, since the Swift bindings support both Apple platforms.
const macosSwiftOut =
    'macos/blue_terminal_lib/Sources/blue_terminal_lib/Messages.g.swift';

// Generate all platforms with: dart run tool/generate_pigeon.dart
// The script handles Linux/Windows event-channel generation limitations.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform_interface/blue_terminal_lib_messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/ysfgrl/blue_terminal_lib/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.ysfgrl.blue_terminal_lib'),
    swiftOut: 'ios/blue_terminal_lib/Sources/blue_terminal_lib/Messages.g.swift',
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'blue_terminal_lib'),
    gobjectHeaderOut: 'linux/messages.g.h',
    gobjectSourceOut: 'linux/messages.g.cc',
    gobjectOptions: GObjectOptions(module: 'BlueTerminal'),
    dartPackageName: 'blue_terminal_lib',
  ),
)
@HostApi()
abstract class BlueTerminalLibApi {
  /// Lists serial ports available on the system, including ports already open.
  @async
  List<SerialInfoMessage> getSerialList();

  /// Returns ports currently opened by this plugin instance.
  @async
  List<SerialInfoMessage> getConnectedPorts();

  /// Opens [path] for reading and writing and applies [config].
  /// An already connected path must fail without replacing its connection.
  @async
  void connect(String path, SerialConfigMessage config);

  /// Closes [path] and releases its reader. An already closed port is a no-op.
  @async
  void disconnect(String path);

  /// Writes raw bytes, returning the actual number accepted by the port.
  /// [timeoutMs] must be nonnegative; zero requests a nonblocking write.
  @async
  int write(String path, Uint8List data, int timeoutMs);
}

/// Events from all connections. Subscribe before connecting to avoid losing
/// initial data. Cancelling a subscription does not disconnect any ports.
@EventChannelApi()
abstract class BlueTerminalLibEvents {
  /// Raw chunks, without assumptions about text encoding or frame boundaries.
  SerialDataMessage serialDataReceived();

  /// Includes explicit connect/disconnect and unexpected device removal.
  SerialConnectionMessage serialConnectionChanged();
}

enum SerialParity { none, odd, even, mark, space }

enum SerialStopBits { one, onePointFive, two }

enum SerialFlowControl { none, rtsCts, xonXoff }

enum SerialConnectionState { connected, disconnected }

class SerialConfigMessage {
  SerialConfigMessage({
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.parity,
    required this.flowControl,
  });

  int baudRate;
  int dataBits;
  SerialStopBits stopBits;
  SerialParity parity;
  SerialFlowControl flowControl;
}

class SerialInfoMessage {
  SerialInfoMessage({required this.name, required this.path});

  String name;
  String path;
}

class SerialDataMessage {
  SerialDataMessage({required this.path, required this.data});

  String path;
  Uint8List data;
}

class SerialConnectionMessage {
  SerialConnectionMessage({
    required this.path,
    required this.state,
    this.error,
  });

  String path;
  SerialConnectionState state;

  /// Populated when a connection is lost due to an I/O error.
  String? error;
}
