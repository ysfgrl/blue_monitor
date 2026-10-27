import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_session.dart';
import '../term/terminal_panel.dart';

class SshSessionTab extends StatelessWidget {
  const SshSessionTab({
    super.key,
    required this.active,
    required this.session,
  });

  final bool active;
  final SshSession session;

  @override
  Widget build(BuildContext context){
    final output= session.session.stdout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TerminalPanel(
            key: ObjectKey(output),
            incoming: output,
            onOutput: session.send,
            onResize: session.resize,
            isConnected: true,
            active: active,
            allowBackgroundOutput: true,
          ),
        ),
      ],
    );
  }
}
