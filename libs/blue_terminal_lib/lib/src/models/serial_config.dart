import 'serial_flow_control.dart';
import 'serial_parity.dart';
import 'serial_stop_bits.dart';

/// Settings applied when a serial port is opened.
class SerialConfig {
  const SerialConfig({
    this.baudRate = 115200,
    this.dataBits = 8,
    this.stopBits = SerialStopBits.one,
    this.parity = SerialParity.none,
    this.flowControl = SerialFlowControl.none,
  });

  final int baudRate;
  final int dataBits;
  final SerialStopBits stopBits;
  final SerialParity parity;
  final SerialFlowControl flowControl;
}
