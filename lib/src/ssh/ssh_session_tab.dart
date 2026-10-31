import 'package:flutter/material.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_session.dart';

import '../term/terminal_panel.dart';

class SshSessionTab extends StatelessWidget {
  const SshSessionTab({
    super.key,
    required this.active,
    required this.session
  });

  final bool active;
  final SshSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: session.done,
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TerminalPanel(
              key: ObjectKey(session),
              incoming: session.output,
              onOutput: session.send,
              onResize: session.resize,
              isConnected: true,
              active: active && session.isRunning,
              allowBackgroundOutput: true,
            ),
          ),
          if (session.message != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(session.message!)),
        ],
      ),
    );
  }
}
