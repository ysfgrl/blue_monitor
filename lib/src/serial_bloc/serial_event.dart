part of 'serial_bloc.dart';

@immutable
sealed class SerialEvent {
  const SerialEvent();
}

final class SerialPortsRefreshRequested extends SerialEvent {
  const SerialPortsRefreshRequested();
}

final class _SerialPortAccessStarted extends SerialEvent {
  const _SerialPortAccessStarted();
}

final class _SerialPortAccessCompleted extends SerialEvent {
  const _SerialPortAccessCompleted({this.port, this.error});
  final SerialInfo? port;
  final Object? error;
}

final class SerialPortSelected extends SerialEvent {
  const SerialPortSelected(this.path);
  final String? path;
}

final class SerialTypeChanged extends SerialEvent {
  const SerialTypeChanged(this.type);
  final MonitorType type;
}

final class SerialConnectionRequested extends SerialEvent {
  const SerialConnectionRequested(this.baudRate);
  final int baudRate;
}

final class SerialDisconnectionRequested extends SerialEvent {
  const SerialDisconnectionRequested();
}

final class SerialSendRequested extends SerialEvent {
  SerialSendRequested(Uint8List bytes, {this.queueIfBusy = true})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final bool queueIfBusy;
  final _completion = Completer<bool>();

  /// Allows the send input to clear only after a successful transfer.
  Future<bool> get result => _completion.future;
}

final class SerialErrorDismissed extends SerialEvent {
  const SerialErrorDismissed();
}

final class SerialHistoryCleared extends SerialEvent {
  const SerialHistoryCleared();
}

final class _SerialDataReceived extends SerialEvent {
  const _SerialDataReceived(this.bytes);
  final Uint8List bytes;
}

final class _SerialConnectionFailed extends SerialEvent {
  const _SerialConnectionFailed(this.error);
  final Object error;
}

final class _SerialWriteCompleted extends SerialEvent {
  const _SerialWriteCompleted(this.write, {this.count, this.error});
  final SerialSendRequested write;
  final int? count;
  final Object? error;
}
