import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';

class SshSession {
  SshSession({required this.id, required this.session}) {
    _stdout = session.stdout.listen(_receive, onError: _streamError, onDone: () => _complete(_stdoutDone));
    _stderr = session.stderr.listen(_receive, onError: _streamError, onDone: () => _complete(_stderrDone));
    done = _observeExit();
  }

  final SSHSession session;
  final int id;
  final _incoming = StreamController<Uint8List>();
  final _stdoutDone = Completer<void>();
  final _stderrDone = Completer<void>();
  late final StreamSubscription<Uint8List> _stdout;
  late final StreamSubscription<Uint8List> _stderr;
  late final Future<void> done;
  bool _closed = false;
  bool _exited = false;
  String? message;

  Stream<Uint8List> get output => _incoming.stream;
  bool get isRunning => !_closed && !_exited;

  void _complete(Completer<void> completion) {
    if (!completion.isCompleted) completion.complete();
  }

  void _streamError(Object error) {
    message = 'ssh.connectionError'.tr(namedArgs: {'error': error.toString()});
    session.close();
  }

  void _receive(Uint8List bytes) {
    if (!_incoming.isClosed) _incoming.add(bytes);
  }

  Future<void> _observeExit() async {
    try {
      await session.done;
      await Future.wait([_stdoutDone.future, _stderrDone.future]);
      final code = session.exitCode;
      message ??= code == null ? 'ssh.sessionEnded'.tr() : 'ssh.sessionExited'.tr(namedArgs: {'code': '$code'});
    } catch (error) {
      message = 'ssh.connectionError'.tr(namedArgs: {'error': error.toString()});
    } finally {
      _exited = true;
      if (!_incoming.isClosed) unawaited(_incoming.close());
    }
  }

  void send(Uint8List bytes) {
    if (isRunning) session.write(bytes);
  }

  void resize(int columns, int rows) {
    if (isRunning && columns > 0 && rows > 0) session.resizeTerminal(columns, rows);
  }

  Future<void> stopSession() async {
    if (_closed) return;
    _closed = true;
    session.close();
    await Future.wait([_stdout.cancel(), _stderr.cancel()]);
    _complete(_stdoutDone);
    _complete(_stderrDone);
    // An unopened tab may not yet have subscribed to the buffered output.
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}
