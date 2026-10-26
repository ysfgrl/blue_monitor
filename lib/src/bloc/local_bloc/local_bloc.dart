import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../helper/local_shell_stub.dart'
    if (dart.library.io) '../../local/local_shell.dart';

part 'local_event.dart';
part 'local_state.dart';

class LocalBloc extends Bloc<LocalEvent, LocalState> {
  LocalShell? _shell;
  LocalBloc() : super(const LocalState()) {
    on<LocalStartEvt>(_start);
    on<LocalExitEvt>(_exit);
  }

  void _exit(LocalExitEvt event, Emitter<LocalState> emit) {

  }
  void _start(LocalStartEvt event, Emitter<LocalState> emit) {
    if (kIsWeb) {
      emit(const LocalState(status: LocalStatus.unsupported));
      return;
    }
    try {
      final shell = LocalShell();
      _shell = shell;
      emit(LocalState(
          status: LocalStatus.running,
          output: shell.output,
          shell: LocalShell()
      ));
      unawaited(_observeExit(shell));
    } catch (error) {
      emit(LocalState(
          error: 'Yerel terminal açılamadı: $error',
      ));
    }
  }


  Future<void> _observeExit(LocalShell shell) async {
    int? exitCode;
    String? error;
    try {
      exitCode = await shell.exitCode;
    } catch (exception) {
      error = 'Yerel terminal hatası: $exception';
    }
    if (isClosed || !identical(_shell, shell)) return;
    add(_LocalExited(shell, exitCode: exitCode, error: error));
  }

  void send(Uint8List bytes) {
    if (!isClosed && state.isRunning) _shell?.write(bytes);
  }

  void resize(int columns, int rows) {
    if (!isClosed && state.isRunning) {
      _shell?.resize(columns, rows);
    }
  }

  @override
  Future<void> close() {
    _shell?.close();
    _shell = null;
    return super.close();
  }
}
