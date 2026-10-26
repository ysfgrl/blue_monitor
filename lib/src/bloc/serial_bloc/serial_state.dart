part of 'serial_bloc.dart';

enum ConnectionStatus { disconnected, connecting, connected, disconnecting }

enum TrafficDirection { rx, tx }

enum MonitorType { normal, terminal }

@immutable
class TrafficRecord {
  TrafficRecord(this.direction, List<int> bytes, this.timestamp)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final TrafficDirection direction;
  final Uint8List bytes;
  final DateTime timestamp;
}

@immutable
class SerialState {
  const SerialState({
    this.type = MonitorType.normal,
    this.status = ConnectionStatus.disconnected,
    this.ports = const [],
    this.records = const [],
    this.selectedPort,
    this.error,
    this.isRefreshing = false,
    this.isSending = false,
    this.historyBytes = 0,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.droppedRecords = 0,
  });

  final MonitorType type;
  final ConnectionStatus status;
  final List<SerialInfo> ports;
  final List<TrafficRecord> records;
  final String? selectedPort;
  final String? error;
  final bool isRefreshing;
  final bool isSending;
  final int historyBytes;
  final int rxBytes;
  final int txBytes;
  final int droppedRecords;

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.disconnecting;

  SerialState copyWith({
    MonitorType? type,
    ConnectionStatus? status,
    Iterable<SerialInfo>? ports,
    Iterable<TrafficRecord>? records,
    String? selectedPort,
    bool clearSelectedPort = false,
    String? error,
    bool clearError = false,
    bool? isRefreshing,
    bool? isSending,
    int? historyBytes,
    int? rxBytes,
    int? txBytes,
    int? droppedRecords,
  }) => SerialState(
    type: type ?? this.type,
    status: status ?? this.status,
    ports: ports == null ? this.ports : List<SerialInfo>.unmodifiable(ports),
    records: records == null
        ? this.records
        : List<TrafficRecord>.unmodifiable(records),
    selectedPort: clearSelectedPort ? null : selectedPort ?? this.selectedPort,
    error: clearError ? null : error ?? this.error,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isSending: isSending ?? this.isSending,
    historyBytes: historyBytes ?? this.historyBytes,
    rxBytes: rxBytes ?? this.rxBytes,
    txBytes: txBytes ?? this.txBytes,
    droppedRecords: droppedRecords ?? this.droppedRecords,
  );
}
