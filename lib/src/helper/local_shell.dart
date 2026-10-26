import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

class LocalShell {
  LocalShell({int rows = 24, int columns = 80}) {
    if (Platform.isIOS) {
      throw UnsupportedError('iOS üzerinde yerel sistem kabuğu açılamıyor.');
    }
    final environment = Map<String, String>.from(Platform.environment)
      ..['TERM'] = 'xterm-256color'
      ..['COLORTERM'] = 'truecolor';
    final String executable;
    if (Platform.isWindows) {
      executable = environment['COMSPEC'] ?? 'cmd.exe';
    } else if (Platform.isAndroid) {
      executable = '/system/bin/sh';
    } else {
      final preferred = environment['SHELL'];
      executable = preferred != null && File(preferred).existsSync()
          ? preferred
          : File('/bin/bash').existsSync()
          ? '/bin/bash'
          : '/bin/sh';
    }
    final home = environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    _pty = Pty.start(
      executable,
      arguments: Platform.isWindows ? const [] : const ['-i'],
      workingDirectory: home != null && Directory(home).existsSync()
          ? home
          : Directory.current.path,
      environment: environment,
      rows: rows,
      columns: columns,
    );
    output = _pty.output;
    exitCode = _pty.exitCode.then((code) {
      _exited = true;
      return code;
    });
  }

  late final Pty _pty;
  late final Stream<Uint8List> output;
  late final Future<int> exitCode;
  bool _exited = false;
  bool _closed = false;

  void write(Uint8List bytes) {
    if (!_closed && !_exited) _pty.write(bytes);
  }

  void resize(int columns, int rows) {
    if (!_closed && !_exited && columns > 0 && rows > 0) {
      _pty.resize(rows, columns);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_exited) {
      _pty.kill(
        Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sighup,
      );
    }
  }
}
