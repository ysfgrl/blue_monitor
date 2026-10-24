import 'dart:js_interop';

import 'package:web/web.dart' as web;

// package:web 1.x does not include Web Serial bindings.
@JS('navigator.serial')
external WebSerial? get browserSerial;

extension type WebSerial(JSObject _) implements web.EventTarget, JSObject {
  external JSPromise<JSArray<WebSerialPort>> getPorts();
  external JSPromise<WebSerialPort> requestPort();
}

extension type WebSerialPort(JSObject _) implements web.EventTarget, JSObject {
  external WebSerialPortInfo getInfo();
  external JSPromise<JSAny?> open(WebSerialOptions options);
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> setSignals(WebSerialOutputSignals signals);
  external web.ReadableStream? get readable;
  external web.WritableStream? get writable;
}

extension type WebSerialOutputSignals._(JSObject _) implements JSObject {
  external factory WebSerialOutputSignals({
    bool dataTerminalReady,
    bool requestToSend,
  });
}

extension type WebSerialPortInfo(JSObject _) implements JSObject {
  external int? get usbVendorId;
  external int? get usbProductId;
}

extension type WebSerialOptions._(JSObject _) implements JSObject {
  external factory WebSerialOptions({
    required int baudRate,
    required int dataBits,
    required int stopBits,
    required String parity,
    required String flowControl,
    int bufferSize,
  });
}
