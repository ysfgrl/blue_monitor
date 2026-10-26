import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../helper/local_shell_stub.dart'
    if (dart.library.io) '../../helper/local_shell.dart';

part 'local_event.dart';
part 'local_state.dart';

class LocalBloc extends Bloc<LocalEvent, LocalState> {
  LocalBloc() : super(const LocalState()) {
    on<LocalStartEvt>(_start);
    on<LocalExitEvt>(_exit);
  }

  final _shells = <int, LocalShell>{};
  int _nextTerminalId = 1;
  bool _closing = false;

  bool get _inactive => _closing || isClosed;

  LocalState _terminalState(
    Iterable<LocalTerminalSession> terminals, {
    String? error,
  }) {
    final sessions = List<LocalTerminalSession>.unmodifiable(terminals);
    return LocalState(
      status: sessions.any((session) => session.isRunning)
          ? LocalStatus.running
          : LocalStatus.idle,
      terminals: sessions,
      error: error,
    );
  }

  void _exit(LocalExitEvt event, Emitter<LocalState> emit) {
    if (_inactive) return;
    if (!state.terminals.any((terminal) => terminal.id == event.terminalId)) {
      return;
    }
    final shell = _shells.remove(event.terminalId);
    if (!event.closeTab && shell == null) return;
    String? error;
    try {
      shell?.close();
    } catch (exception) {
      error = 'local.closeFailed'.tr(
        namedArgs: {'error': exception.toString()},
      );
    }
    emit(
      _terminalState([
        for (final terminal in state.terminals)
          if (terminal.id != event.terminalId)
            terminal
          else if (!event.closeTab)
            LocalTerminalSession(
              id: terminal.id,
              output: terminal.output,
              status: LocalStatus.idle,
              exitCode: event.exitCode,
              error: event.error ?? error,
            ),
      ], error: event.closeTab ? error : null),
    );
  }

  void _start(LocalStartEvt event, Emitter<LocalState> emit) {
    if (_inactive) return;
    if (kIsWeb) {
      emit(const LocalState(status: LocalStatus.unsupported));
      return;
    }
    try {
      final shell = LocalShell();
      final id = _nextTerminalId++;
      _shells[id] = shell;
      emit(
        _terminalState([
          ...state.terminals,
          LocalTerminalSession(id: id, output: shell.output),
        ]),
      );
      unawaited(_observeExit(id, shell));
    } catch (error) {
      emit(
        _terminalState(
          state.terminals,
          error: 'local.openFailed'.tr(
            namedArgs: {
              'error': error is UnsupportedError
                  ? (error.message ?? error.toString()).tr()
                  : error.toString(),
            },
          ),
        ),
      );
    }
  }

  Future<void> _observeExit(int terminalId, LocalShell shell) async {
    int? exitCode;
    String? error;
    try {
      exitCode = await shell.exitCode;
    } catch (exception) {
      error = 'local.terminalError'.tr(
        namedArgs: {'error': exception.toString()},
      );
    }
    if (_inactive || !identical(_shells[terminalId], shell)) return;
    add(
      LocalExitEvt(
        terminalId: terminalId,
        exitCode: exitCode,
        error: error,
        closeTab: false,
      ),
    );
  }

  void send(int terminalId, Uint8List bytes) {
    if (!_inactive) _shells[terminalId]?.write(bytes);
  }

  void resize(int terminalId, int columns, int rows) {
    if (!_inactive) _shells[terminalId]?.resize(columns, rows);
  }

  @override
  Future<void> close() {
    _closing = true;
    for (final shell in _shells.values) {
      try {
        shell.close();
      } catch (_) {
        // Release the other sessions even if one process cannot be signalled.
      }
    }
    _shells.clear();
    return super.close();
  }
}
