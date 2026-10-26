import 'package:easy_localization/easy_localization.dart';
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
      title: Text(context.tr('local.title')),
    ),
    body: SafeArea(
      child: BlocBuilder<LocalBloc, LocalState>(
        builder: (context, state) => _buildTerminal(context, state),
      ),
    ),
  );

  Widget _buildTerminal(BuildContext context, LocalState state) {
    if (kIsWeb || state.status == LocalStatus.unsupported) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            context.tr('local.webUnsupported'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (state.terminals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null) ...[
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                key: const Key('new-local-terminal'),
                onPressed: () =>
                    context.read<LocalBloc>().add(const LocalStartEvt()),
                icon: const Icon(Icons.add),
                label: Text(context.tr('local.newTerminal')),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(child: _LocalTerminalWorkspace(terminals: state.terminals)),
      ],
    );
  }
}

class _LocalTerminalWorkspace extends StatefulWidget {
  const _LocalTerminalWorkspace({required this.terminals});

  final List<LocalTerminalSession> terminals;

  @override
  State<_LocalTerminalWorkspace> createState() =>
      _LocalTerminalWorkspaceState();
}

class _LocalTerminalWorkspaceState extends State<_LocalTerminalWorkspace>
    with TickerProviderStateMixin {
  late TabController _tabs;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    _tabs = TabController(
      length: widget.terminals.length,
      initialIndex: _selectedIndex,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_selectedIndex != _tabs.index) {
      setState(() => _selectedIndex = _tabs.index);
    }
  }

  @override
  void didUpdateWidget(covariant _LocalTerminalWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.terminals.map((terminal) => terminal.id).toList();
    final newIds = widget.terminals.map((terminal) => terminal.id).toList();
    if (oldIds.length == newIds.length &&
        oldIds.asMap().entries.every(
          (entry) => newIds[entry.key] == entry.value,
        )) {
      return;
    }
    final selectedId = oldIds[_selectedIndex];
    final added = newIds.where((id) => !oldIds.contains(id));
    if (added.isNotEmpty) {
      _selectedIndex = newIds.indexOf(added.last);
    } else {
      final index = newIds.indexOf(selectedId);
      _selectedIndex = index >= 0
          ? index
          : _selectedIndex < newIds.length
          ? _selectedIndex
          : newIds.length - 1;
    }
    _tabs.dispose();
    _createController();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LocalBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelPadding: const EdgeInsets.only(left: 12, right: 4),
                  tabs: [
                    for (final terminal in widget.terminals)
                      Tab(
                        key: ValueKey('local-tab-${terminal.id}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr(
                                'local.tabTitle',
                                namedArgs: {'id': terminal.id.toString()},
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              key: ValueKey(
                                'close-local-terminal-${terminal.id}',
                              ),
                              tooltip: context.tr(
                                'global.closeNamed',
                                namedArgs: {
                                  'title': context.tr(
                                    'local.tabTitle',
                                    namedArgs: {'id': terminal.id.toString()},
                                  ),
                                },
                              ),
                              onPressed: () => bloc.add(
                                LocalExitEvt(terminalId: terminal.id),
                              ),
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
              IconButton(
                key: const Key('add-local-terminal'),
                tooltip: context.tr('local.newTerminal'),
                onPressed: () => bloc.add(const LocalStartEvt()),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var index = 0; index < widget.terminals.length; index++)
                _buildSession(
                  context,
                  bloc,
                  widget.terminals[index],
                  index == _selectedIndex,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSession(
    BuildContext context,
    LocalBloc bloc,
    LocalTerminalSession terminal,
    bool selected,
  ) {
    final message =
        terminal.error ??
        (terminal.exitCode == null
            ? null
            : 'local.shellExited'.tr(
                context: context,
                namedArgs: {'code': terminal.exitCode.toString()},
              ));
    // Key the direct Stack child so closing another tab preserves this panel
    // and its single-subscription PTY stream.
    return Offstage(
      key: ValueKey(terminal.id),
      offstage: !selected,
      child: TickerMode(
        enabled: selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TerminalPanel(
                incoming: terminal.output,
                onOutput: (bytes) => bloc.send(terminal.id, bytes),
                onResize: (columns, rows) =>
                    bloc.resize(terminal.id, columns, rows),
                isConnected: true,
                active: selected && terminal.isRunning,
                allowBackgroundOutput: true,
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  message,
                  style: terminal.error == null
                      ? null
                      : TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
