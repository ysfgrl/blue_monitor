import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/ssh_bloc/ssh_bloc.dart';
import '../term/terminal_panel.dart';
import '../models/ssh_connection.dart';
import 'ssh_connection_dialog.dart';

class SshTerminal extends StatefulWidget {
  const SshTerminal({super.key});

  @override
  State<SshTerminal> createState() => _SshTerminalState();
}

class _SshTerminalState extends State<SshTerminal> {
  String? _seenMessage;
  DialogRoute<bool>? _hostKeyRoute;

  SshBloc get _bloc => context.read<SshBloc>();

  Future<void> _editConnection([SshConnection? connection]) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (_) => SshConnectionDialog(connection: connection),
  );

  void _stateChanged(BuildContext context, SshState state) {
    if (state.profileMessage != _seenMessage) {
      _seenMessage = state.profileMessage;
      if (_seenMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_seenMessage!)));
      }
    }
    final challenge = state.hostKeyChallenge;
    if (challenge == null) {
      final route = _hostKeyRoute;
      _hostKeyRoute = null;
      if (route != null && route.isActive)
        route.navigator?.removeRoute(route, false);
    } else if (_hostKeyRoute == null) {
      unawaited(_showHostKey(challenge));
    }
  }

  Future<void> _showHostKey(SshHostKeyChallenge challenge) async {
    final bloc = _bloc;
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SSH sunucusuna güvenilsin mi?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${challenge.host}:${challenge.port} sunucusuna ilk kez bağlanıyorsunuz.',
              ),
              const SizedBox(height: 12),
              Text('Anahtar türü: ${challenge.type}'),
              const SizedBox(height: 8),
              SelectableText(challenge.fingerprint),
              const SizedBox(height: 12),
              const Text('Parmak izini sunucunun sahibiyle doğrulayın.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Güven ve bağlan'),
          ),
        ],
      ),
    );
    _hostKeyRoute = route;
    final trusted = await Navigator.of(context).push(route) ?? false;
    if (identical(_hostKeyRoute, route)) _hostKeyRoute = null;
    if (!bloc.isClosed && bloc.state.hostKeyChallenge?.id == challenge.id) {
      bloc.add(SshHostKeyAnswered(challenge.id, trusted: trusted));
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<SshBloc, SshState>(
    listener: _stateChanged,
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('SSH terminal'),
        actions: [
          if (state.isConnected)
            IconButton(
              tooltip: 'Bağlantıyı kes',
              onPressed: () => _bloc.add(const SshDisconnectRequested()),
              icon: const Icon(Icons.link_off_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: kIsWeb
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Doğrudan SSH bağlantısı tarayıcıda desteklenmiyor.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : state.output == null
            ? _buildConnections(state)
            : _buildTerminal(state),
      ),
    ),
  );

  Widget _buildTerminal(SshState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Text(
          state.activeConnection?.destination ?? '',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Expanded(
        child: TerminalPanel(
          incoming: state.output!,
          onOutput: _bloc.send,
          onResize: _bloc.resize,
          // Preserve terminal history after the remote shell exits.
          isConnected: true,
          active: state.isConnected,
        ),
      ),
      if (!state.isConnected)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: _statusText(state)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _bloc.add(const SshNewConnectionRequested()),
                icon: const Icon(Icons.list_rounded),
                label: const Text('Kayıtlı bağlantılar'),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _statusText(SshState state) => Text(
    state.message ?? '',
    style: state.hasError
        ? TextStyle(color: Theme.of(context).colorScheme.error)
        : null,
  );

  Widget _buildConnections(SshState state) {
    final enabled = !state.isConnecting && !state.profilesBusy;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kayıtlı bağlantılar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (state.profilesBusy) const LinearProgressIndicator(),
              if (state.profileError != null) ...[
                Text(
                  state.profileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: state.profilesBusy
                      ? null
                      : () => _bloc.add(const SshConnectionsRequested()),
                  child: const Text('Kayıtları yeniden yükle'),
                ),
              ],
              Expanded(
                child: state.profilesReady && state.connections.isEmpty
                    ? const Center(child: Text('Kayıtlı SSH bağlantısı yok.'))
                    : ListView.builder(
                        itemCount: state.connections.length,
                        itemBuilder: (context, index) {
                          final connection = state.connections[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                connection.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                connection.destination,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: enabled
                                  ? () => _bloc.add(
                                      SshConnectRequested(connection),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Bağlan',
                                    onPressed: enabled
                                        ? () => _bloc.add(
                                            SshConnectRequested(connection),
                                          )
                                        : null,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Düzenle',
                                    onPressed: enabled
                                        ? () => _editConnection(connection)
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Kaydı sil',
                                    onPressed: enabled
                                        ? () => _bloc.add(
                                            SshConnectionDeleted(connection.id),
                                          )
                                        : null,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (state.isConnecting) ...[
                const LinearProgressIndicator(),
                TextButton(
                  onPressed: () => _bloc.add(const SshDisconnectRequested()),
                  child: const Text('Bağlantıyı iptal et'),
                ),
              ] else if (state.hasError) ...[
                _statusText(state),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: enabled && state.profilesReady
                    ? () => _editConnection()
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Yeni bağlantı ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
