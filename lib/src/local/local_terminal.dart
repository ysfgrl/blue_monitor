import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/local_bloc/local_bloc.dart';
import '../term/terminal_panel.dart';

class LocalTerminal extends StatelessWidget {
  const LocalTerminal({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => context.go('/')),
      title: const Text('Local terminal'),
    ),
    body: SafeArea(
      child: BlocBuilder<LocalBloc, LocalState>(
        builder: (context, state) => _buildTerminal(context, state),
      ),
    ),
  );

  Widget _buildTerminal(BuildContext context, LocalState state) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Yerel terminal tarayıcıda desteklenmiyor.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final bloc = context.read<LocalBloc>();
    final output = state.output;
    final status =
        state.error ??
        (state.exitCode == null
            ? null
            : 'Kabuk kapandı. Çıkış kodu: ${state.exitCode}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (output != null)
          Expanded(
            child: TerminalPanel(
              key: ObjectKey(output),
              incoming: output,
              onOutput: bloc.send,
              onResize: bloc.resize,
              isConnected: true,
              active: state.isRunning,
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
                    style: state.error == null
                        ? null
                        : TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: (){
                   // bloc.add(const LocalRestartRequested())
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeniden aç'),
                ),
              ],
            ),
          ),
        if (output == null) const Spacer(),
      ],
    );
  }
}
