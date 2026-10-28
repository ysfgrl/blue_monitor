import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_session.dart';
import 'package:serial_monitor/src/ssh/ssh_list.dart';

import '../bloc/ssh/ssh_list_bloc.dart';
import '../bloc/ssh/connection/ssh_connection_bloc.dart';
import '../models/ssh_connection.dart';
import 'ssh_connection_dialog.dart';
import 'ssh_session_tab.dart';

class SshTerminal extends StatelessWidget {
  const SshTerminal({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(context.tr('ssh.title')),
      ),
      body: BlocBuilder<EnvListBloc, EnvListState>(
        builder: (context, envState) {
          return BlocProvider<SshListBloc>.value(
            key: ValueKey(envState.selected!.model.id),
            value: envState.selected!.ssh,
            child: const _SshTerminalView(),
          );
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

class _SshTerminalState extends State<_SshTerminalView>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _connectionSubscriptions = <SshConnectionBloc, StreamSubscription<SshConnectionState>>{};
  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 1,
      initialIndex: _selectedIndex,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_selectedIndex != _tabs.index) {
      setState(() {
        _selectedIndex = _tabs.index;
      });
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
  Widget build(BuildContext context){
    return  BlocBuilder<SshListBloc,SshListState>(
      builder: (context, state) {
        if(state.status == SshListStatus.init) {
          context.read<SshListBloc>().add(SshLoadListEvent());
        }
        List<SshSession> sessions = [];
        for(var bloc in state.connections){
          sessions.addAll(bloc.sessions);
        }
        return Column(
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
                                  'name': "session.connection.name",
                                  'id': session.id.toString(),
                                },
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: context.tr('global.closeTab'),
                            onPressed: (){

                            },
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
                        child: SshListTab(),
                      ),
                    ),
                  ),
                  for (var index = 0; index < sessions.length; index++)
                    Offstage(
                      key: ValueKey(
                        'ssh-session-${sessions[index].id}',
                      ),
                      offstage: _selectedIndex != index + 1,
                      child: TickerMode(
                        enabled: _selectedIndex == index + 1,
                        child: SshSessionTab(
                          active: _selectedIndex == index + 1,
                          session: sessions[index],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      },
    );
  }


}
