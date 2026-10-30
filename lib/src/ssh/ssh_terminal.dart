import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/env/env_list_bloc.dart';
import '../bloc/ssh/connection/ssh_connection_bloc.dart';
import '../bloc/ssh/connection/ssh_session.dart';
import '../bloc/ssh/ssh_list_bloc.dart';
import 'ssh_list.dart';
import 'ssh_session_tab.dart';

class SshTerminal extends StatelessWidget {
  const SshTerminal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/')), title: Text(context.tr('ssh.title'))),
      body: BlocBuilder<EnvListBloc, EnvListState>(
        builder: (context, envState) {
          if (kIsWeb) return Center(child: Text(context.tr('ssh.webUnsupported')));
          final selected = envState.selected;
          if (selected == null) return Center(child: Text(context.tr('ssh.selectEnvironment')));
          return BlocProvider<SshListBloc>.value(key: ValueKey(selected.model.id), value: selected.ssh, child: const _SshTerminalView());
        },
      ),
    );
  }
}

class _SshTerminalView extends StatefulWidget {
  const _SshTerminalView();

  @override
  State<_SshTerminalView> createState() => _SshTerminalState();
}

class _SshTerminalState extends State<_SshTerminalView> with TickerProviderStateMixin {
  late TabController _tabs;
  late final SshListBloc _listBloc;
  final _connectionSubscriptions = <SshConnectionBloc, StreamSubscription<SshConnectionState>>{};
  List<({SshConnectionBloc bloc, SshSession session})> _sessions = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this)..addListener(_onTabChanged);
    _listBloc = context.read<SshListBloc>();
    _syncConnections(_listBloc.state);
    if (_listBloc.state.status == SshListStatus.init) _listBloc.add(const SshLoadListEvent());
  }

  void _onTabChanged() {
    if (_selectedIndex != _tabs.index) setState(() => _selectedIndex = _tabs.index);
  }

  void _syncConnections(SshListState state) {
    for (final bloc in _connectionSubscriptions.keys.toList()) {
      if (!state.connections.contains(bloc)) unawaited(_connectionSubscriptions.remove(bloc)!.cancel());
    }
    for (final bloc in state.connections) {
      _connectionSubscriptions.putIfAbsent(bloc, () => bloc.stream.listen((_) => _syncTabs()));
    }
    _syncTabs();
  }

  void _syncTabs() {
    if (!mounted) return;
    final next = [for (final bloc in _listBloc.state.connections) for (final session in bloc.sessions) (bloc: bloc, session: session)];
    if (next.length == _sessions.length && List.generate(next.length, (index) => identical(next[index].session, _sessions[index].session)).every((same) => same)) return;
    final active = _selectedIndex > 0 && _selectedIndex <= _sessions.length ? _sessions[_selectedIndex - 1].session : null;
    final added = next.where((entry) => !_sessions.any((old) => identical(old.session, entry.session))).firstOrNull;
    final activeIndex = next.indexWhere((entry) => identical(entry.session, active));
    final index = added != null ? next.indexOf(added) + 1 : activeIndex >= 0 ? activeIndex + 1 : 0;
    final previous = _tabs;
    setState(() {
      _sessions = next;
      _selectedIndex = index;
      _tabs = TabController(length: next.length + 1, initialIndex: index, vsync: this)..addListener(_onTabChanged);
    });
    previous.removeListener(_onTabChanged);
    previous.dispose();
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
  Widget build(BuildContext context) {
    return BlocListener<SshListBloc, SshListState>(
      listener: (context, state) => _syncConnections(state),
      child: Column(
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
                Tab(key: const ValueKey('ssh-connections-tab'), text: context.tr('ssh.connections')),
                for (final entry in _sessions)
                  Tab(
                    key: ObjectKey(entry.session),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(context.tr('ssh.tabTitle', namedArgs: {'name': entry.bloc.state.connection.name, 'id': '${entry.session.id}'}), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: context.tr('global.closeTab'),
                          onPressed: () => entry.bloc.add(SshConnectionSessionClosed(entry.session.id)),
                          icon: const Icon(Icons.close, size: 16),
                          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
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
                  child: TickerMode(enabled: _selectedIndex == 0, child: ExcludeFocus(excluding: _selectedIndex != 0, child: const SshListTab())),
                ),
                for (var index = 0; index < _sessions.length; index++)
                  Offstage(
                    key: ObjectKey(_sessions[index].session),
                    offstage: _selectedIndex != index + 1,
                    child: TickerMode(
                      enabled: _selectedIndex == index + 1,
                      child: ExcludeFocus(
                        excluding: _selectedIndex != index + 1,
                        child: SshSessionTab(active: _selectedIndex == index + 1, session: _sessions[index].session),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
