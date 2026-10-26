import 'dart:async';
import 'dart:typed_data';

class LocalShell {
  LocalShell({int rows = 24, int columns = 80}) {
    throw UnsupportedError('Tarayıcıda yerel sistem kabuğu açılamıyor.');
  }
  Stream<Uint8List> get output => const Stream.empty();
  Future<int> get exitCode => Future.value(0);
  void write(Uint8List bytes) {}
  void resize(int columns, int rows) {}
  void close() {}
}
