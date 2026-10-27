import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/ssh/ssh_session_list_tab.dart';

import '../bloc/env_bloc/env_bloc.dart';
import '../bloc/ssh/ssh_list_bloc.dart';
import '../bloc/ssh/connection/session/ssh_session_bloc.dart';
import '../bloc/ssh/connection/ssh_connection_bloc.dart';
import '../models/ssh_connection.dart';
import '../store/ssh.dart';
import 'ssh_connection_dialog.dart';
import 'ssh_session_tab.dart';

class SshTerminal extends StatelessWidget {
  const SshTerminal({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<EnvBloc, EnvState>(
    builder: (context, state) {
      final selected = state.selected;
      if (selected == null) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/')),
            title: Text(context.tr('ssh.title')),
          ),
          body: Center(
            child:
                state.status == EnvStatus.init ||
                    state.status == EnvStatus.loading
                ? const CircularProgressIndicator()
                : FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.layers_outlined),
                    label: Text(context.tr('setting.selectEnvironment')),
                  ),
          ),
        );
      }
      return BlocProvider<SshListBloc>(
        key: ValueKey(selected.id),
        lazy: false,
        create: (context) {
          final bloc = SshListBloc(
            store: SshConnectionStore(envId: selected.id),
          );
          // if (!kIsWeb) bloc.add(const SshConnectionsRequested());
          return bloc;
        },
        child: const _SshTerminalView(),
      );
    },
  );
}

class _SshTerminalView extends StatefulWidget {
  const _SshTerminalView();

  @override
  State<_SshTerminalView> createState() => _SshTerminalState();
}

class _SshTerminalState extends State<_SshTerminalView>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _connectionSubscriptions =
      <SshConnectionBloc, StreamSubscription<SshConnectionState>>{};
  int _selectedIndex = 0;
  int _lastOpenedSessionId = 0;
  SshSessionBloc? _selectedSession;
  bool _editingConnection = false;
  String? _seenMessage;
  SshListBloc get _bloc => context.read<SshListBloc>();

  List<SshSessionBloc> get _sessions => [
    for (final connection in _connectionSubscriptions.keys)
      ...connection.state.sessions,
  ]..sort((a, b) => a.id.compareTo(b.id));

  void _watchConnections(SshListState state) {
    final connections = {
      for (final connection in state.connections)
        _bloc.connectionBlocFor(connection),
    };
    for (final connection in _connectionSubscriptions.keys.toList()) {
      if (!connections.contains(connection)) {
        unawaited(_connectionSubscriptions.remove(connection)!.cancel());
      }
    }
    for (final connection in connections) {
      if (_connectionSubscriptions.containsKey(connection)) continue;
      var previous = connection.state.sessions;
      _connectionSubscriptions[connection] = connection.stream.listen((state) {
        if (!mounted || identical(previous, state.sessions)) return;
        previous = state.sessions;
        _syncSessions(_sessions);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _watchConnections(_bloc.state);
    final sessions = _sessions;
    _lastOpenedSessionId = sessions.isEmpty ? 0 : sessions.last.id;
    _createController(sessions.length);
  }

  void _createController(int sessionCount) {
    _tabs = TabController(
      length: sessionCount + 1,
      initialIndex: _selectedIndex,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_selectedIndex != _tabs.index) {
      setState(() {
        _selectedIndex = _tabs.index;
        _selectedSession = _selectedIndex == 0
            ? null
            : _sessions[_selectedIndex - 1];
      });
    }
  }

  void _openConnection(SshConnection connection) {
    FocusScope.of(context).unfocus();
    _bloc.add(SshSessionOpened(connection));
  }

  void _closeConnection(SshSessionBloc session) =>
      _bloc.add(SshSessionClosed(session));

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

  void _syncSessions(List<SshSessionBloc> sessions) {
    final opening =
        sessions.isNotEmpty && sessions.last.id > _lastOpenedSessionId;
    if (opening) _lastOpenedSessionId = sessions.last.id;
    final selected = _selectedSession == null
        ? -1
        : sessions.indexOf(_selectedSession!);
    final nextIndex = opening
        ? sessions.length
        : _selectedSession == null
        ? 0
        : selected >= 0
        ? selected + 1
        : _selectedIndex.clamp(0, sessions.length);
    setState(() {
      _selectedIndex = nextIndex;
      _selectedSession = nextIndex == 0 ? null : sessions[nextIndex - 1];
      if (_tabs.length != sessions.length + 1) {
        _tabs.dispose();
        _createController(sessions.length);
      } else if (_tabs.index != nextIndex) {
        _tabs.index = nextIndex;
      }
    });
  }

  void _stateChanged(BuildContext context, SshListState state) {
    _watchConnections(state);
    _syncSessions(_sessions);
    if (state.message != _seenMessage) {
      _seenMessage = state.message;
      if (_seenMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_seenMessage!)));
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in _connectionSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<SshListBloc, SshListState>(
    listener: _stateChanged,
    builder: (context, state) {
      final sessions = _sessions;
      return Scaffold(
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
                          for (final session in sessions)
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
                                    onPressed: () => _closeConnection(session),
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
                                child: SshSessionListTab(),
                              ),
                            ),
                          ),
                          for (var index = 0; index < sessions.length; index++)
                            // Keep the direct Stack child keyed so other tabs
                            // retain their Bloc and single-subscription stream.
                            Offstage(
                              key: ValueKey(
                                'ssh-session-${sessions[index].id}',
                              ),
                              offstage: _selectedIndex != index + 1,
                              child: TickerMode(
                                enabled: _selectedIndex == index + 1,
                                child: SshSessionTab(
                                  bloc: sessions[index],
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
      );
    },
  );

}
