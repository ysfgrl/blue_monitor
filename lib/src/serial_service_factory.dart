import 'dart:io';

import 'android_usb_serial_service.dart';
import 'lib_serial_service.dart';
import 'serial_service.dart';

SerialService createSerialService() =>
    Platform.isAndroid ? AndroidUsbSerialService() : LibSerialService();
