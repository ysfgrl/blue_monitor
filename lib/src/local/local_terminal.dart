import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../term/terminal_panel.dart';
import 'local_shell_stub.dart' if (dart.library.io) 'local_shell.dart';

class LocalTerminal extends StatefulWidget {
  const LocalTerminal({super.key});

  @override
  State<LocalTerminal> createState() => _LocalTerminalState();
}

class _LocalTerminalState extends State<LocalTerminal> {
  LocalShell? _shell;
  bool _running = false;
  int? _exitCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    try {
      final shell = LocalShell();
      _shell = shell;
      _running = true;
      unawaited(_observeExit(shell));
    } catch (error) {
      _error = 'Yerel terminal açılamadı: $error';
    }
  }

  Future<void> _observeExit(LocalShell shell) async {
    try {
      final code = await shell.exitCode;
      if (!mounted) return;
      setState(() {
        _running = false;
        _exitCode = code;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Yerel terminal hatası: $error';
      });
    }
  }

  void _send(Uint8List bytes) {
    if (_running) _shell?.write(bytes);
  }

  void _restart() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => const LocalTerminal()),
    );
  }

  @override
  void dispose() {
    _shell?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Local terminal')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Yerel terminal tarayıcıda desteklenmiyor.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final shell = _shell;
    final status =
        _error ??
        (_exitCode == null ? null : 'Kabuk kapandı. Çıkış kodu: $_exitCode');
    return Scaffold(
      appBar: AppBar(title: const Text('Local terminal')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shell != null)
              Expanded(
                child: TerminalPanel(
                  incoming: shell.output,
                  onOutput: _send,
                  onResize: shell.resize,
                  isConnected: true,
                  active: _running,
                ),
              )
            else
              const Spacer(),
            if (status != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        style: _error == null
                            ? null
                            : TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yeniden aç'),
                    ),
                  ],
                ),
              ),
            if (shell == null) const Spacer(),
          ],
        ),
      ),
    );
  }
}
