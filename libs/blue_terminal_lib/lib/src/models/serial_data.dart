import 'dart:typed_data';

/// A raw chunk from [path]; a chunk is not necessarily a complete message.
class SerialData {
  SerialData({required this.path, required Uint8List data})
    : data = Uint8List.fromList(data).asUnmodifiableView();

  final String path;
  final Uint8List data;
}
