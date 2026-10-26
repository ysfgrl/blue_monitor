import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/ssh_bloc/ssh_bloc.dart';
import '../models/ssh_connection.dart';
import 'ssh_connection_dialog.dart';
import 'ssh_host_key_listener.dart';
import 'ssh_session_tab.dart';

class SshTerminal extends StatefulWidget {
  const SshTerminal({super.key});

  @override
  State<SshTerminal> createState() => _SshTerminalState();
}

class _SshTerminalTab {
  const _SshTerminalTab({required this.id, required this.connection});

  final int id;
  final SshConnection connection;
}

class _SshTerminalState extends State<SshTerminal>
    with TickerProviderStateMixin {
  final _sessions = <_SshTerminalTab>[];
  late TabController _tabs;
  int _selectedIndex = 0;
  int _nextId = 1;
  bool _editingConnection = false;
  String? _seenMessage;

  SshBloc get _bloc => context.read<SshBloc>();

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    _tabs = TabController(
      length: _sessions.length + 1,
      initialIndex: _selectedIndex,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_selectedIndex != _tabs.index) {
      setState(() => _selectedIndex = _tabs.index);
    }
  }

  void _openConnection(SshConnection connection) {
    FocusScope.of(context).unfocus();
    setState(() {
      _tabs.dispose();
      _sessions.add(_SshTerminalTab(id: _nextId++, connection: connection));
      _selectedIndex = _sessions.length;
      _createController();
    });
  }

  void _closeConnection(int id) {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;
    final selectedId = _selectedIndex == 0
        ? null
        : _sessions[_selectedIndex - 1].id;
    setState(() {
      _tabs.dispose();
      _sessions.removeAt(index);
      if (selectedId == null) {
        _selectedIndex = 0;
      } else {
        final selected = _sessions.indexWhere(
          (session) => session.id == selectedId,
        );
        _selectedIndex = selected >= 0
            ? selected + 1
            : _selectedIndex.clamp(0, _sessions.length);
      }
      _createController();
    });
  }

  void _showConnections() => _tabs.animateTo(0);

  Future<void> _editConnection([SshConnection? connection]) async {
    if (_editingConnection) return;
    final bloc = _bloc;
    setState(() => _editingConnection = true);
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: SshConnectionDialog(connection: connection),
        ),
      );
    } finally {
      if (mounted) setState(() => _editingConnection = false);
    }
  }

  void _stateChanged(BuildContext context, SshState state) {
    if (state.profileMessage != _seenMessage) {
      _seenMessage = state.profileMessage;
      if (_seenMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_seenMessage!)));
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SshHostKeyListener(
    child: BlocConsumer<SshBloc, SshState>(
      listener: _stateChanged,
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/')),
          title: Text(context.tr('ssh.title')),
        ),
        body: SafeArea(
          child: kIsWeb
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      context.tr('ssh.webUnsupported'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(
                            key: ValueKey('ssh-connections-tab'),
                            text: context.tr('ssh.connections'),
                          ),
                          for (final session in _sessions)
                            Tab(
                              key: ValueKey('ssh-tab-${session.id}'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 180,
                                    ),
                                    child: Text(
                                      context.tr(
                                        'ssh.tabTitle',
                                        namedArgs: {
                                          'name': session.connection.name,
                                          'id': session.id.toString(),
                                        },
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: context.tr('global.closeTab'),
                                    onPressed: () =>
                                        _closeConnection(session.id),
                                    icon: const Icon(Icons.close, size: 16),
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Offstage(
                            key: const ValueKey('ssh-connections'),
                            offstage: _selectedIndex != 0,
                            child: TickerMode(
                              enabled: _selectedIndex == 0,
                              child: ExcludeFocus(
                                excluding: _selectedIndex != 0,
                                child: _buildConnections(state),
                              ),
                            ),
                          ),
                          for (var index = 0; index < _sessions.length; index++)
                            // Keep the direct Stack child keyed so other tabs
                            // retain their Bloc and single-subscription stream.
                            Offstage(
                              key: ValueKey(
                                'ssh-session-${_sessions[index].id}',
                              ),
                              offstage: _selectedIndex != index + 1,
                              child: TickerMode(
                                enabled: _selectedIndex == index + 1,
                                child: SshSessionTab(
                                  connection: _sessions[index].connection,
                                  active:
                                      _selectedIndex == index + 1 &&
                                      !_editingConnection,
                                  onShowConnections: _showConnections,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
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
                context.tr('ssh.savedConnections'),
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
                  child: Text(context.tr('ssh.reloadConnections')),
                ),
              ],
              Expanded(
                child: state.profilesReady && state.connections.isEmpty
                    ? Center(child: Text(context.tr('ssh.noSavedConnections')))
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
                                  ? () => _openConnection(connection)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: context.tr('global.connect'),
                                    onPressed: enabled
                                        ? () => _openConnection(connection)
                                        : null,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('global.edit'),
                                    onPressed: enabled
                                        ? () => _editConnection(connection)
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('ssh.deleteConnection'),
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
                  child: Text(context.tr('global.cancelConnection')),
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
                label: Text(context.tr('ssh.addConnection')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
