
import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
class SshSession {
  final SSHSession session;
  late final StreamController<Uint8List> _incoming;
  late final  StreamSubscription<Uint8List> _stdout;
  late final  StreamSubscription<Uint8List> _stderr;
  late final  int id;
  SshSession({
    required this.id,
    required this.session
  }){
    _incoming = StreamController<Uint8List>();
    _incoming = StreamController<Uint8List>();
    _stdout = session.stdout.listen(
      _receive,
      onError: _streamError,
      onDone: _completeOutput,
    );
    _stderr = session.stderr.listen(
      _receive,
      onError: _streamError,
      onDone: _completeOutput,
    );
  }


  void _streamError(Object error){
    var err = _describeError(error);
  }
  void _receive(Uint8List bytes){
    _incoming.add(bytes);
  }

  void send(Uint8List bytes) {
    session.write(bytes);
  }

  void resize(int columns, int rows) {
    session.resizeTerminal(columns, rows);
  }

  Future<void> stopSession() async {
    session.close();
    _stdout.cancel();
    _stderr.cancel();
    await _incoming.close();
  }
  void _completeOutput() {

  }
  String _describeError(Object error) {
    if (error is TimeoutException) return 'ssh.connectionTimedOut'.tr();
    return 'ssh.connectionError'.tr(namedArgs: {'error': error.toString()});
  }

}