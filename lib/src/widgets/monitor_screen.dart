import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:blue_monitor_lib/blue_monitor_lib.dart' show SerialInfo;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../byte_codec.dart';
import '../serial_bloc/serial_bloc.dart';
import '../saved_commands.dart';

part 'header.dart';
part 'command_list_dialog.dart';
part 'port_selection_widget.dart';
part 'save_command_dialog.dart';
part 'send_data_widget.dart';
part 'terminal_panel.dart';
part 'terminal_key_bar.dart';
part 'android_terminal_input.dart';
part 'traffic_panel.dart';

const _rxColor = Color(0xFF5EE0B5);
const _txColor = Color(0xFFFFC878);
const _muted = Color(0xFF94A4BA);
const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6);

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SerialBloc>(
      create: (_) => SerialBloc()..add(const SerialPortsRefreshRequested()),
      child: const _MonitorView(),
    );
  }
}

class _MonitorView extends StatelessWidget {
  const _MonitorView();

  Future<bool> _send(SerialBloc monitor, Uint8List bytes) {
    if (monitor.isClosed) return Future.value(false);
    final event = SerialSendRequested(bytes, queueIfBusy: false);
    monitor.add(event);
    return event.result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SerialBloc, SerialState>(
      builder: (context, state) {
        final monitor = context.read<SerialBloc>();
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = true;
                final padding = compact ? 12.0 : 24.0;
                return Padding(
                  padding: EdgeInsets.only(left: padding, right: padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          key: const Key('workspace-scroll'),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MonitorHeader(
                                    compact: compact,
                                    type: state.type,
                                    onTypeChanged:
                                        state.status ==
                                            ConnectionStatus.disconnected
                                        ? (type) {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            monitor.add(
                                              SerialTypeChanged(type),
                                            );
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _panel(
                                    context,
                                    padding: EdgeInsets.all(compact ? 10 : 12),
                                    child: PortSelectionWidget(
                                      ports: state.ports,
                                      selectedPort: state.selectedPort,
                                      isConnected: state.isConnected,
                                      isBusy: state.isBusy,
                                      isRefreshing: state.isRefreshing,
                                      isSending: state.isSending,
                                      onPortChanged: (path) =>
                                          monitor.add(SerialPortSelected(path)),
                                      onRefresh: () async => monitor.add(
                                        const SerialPortsRefreshRequested(),
                                      ),
                                      onConnect: (baudRate) async =>
                                          monitor.add(
                                            SerialConnectionRequested(baudRate),
                                          ),
                                      onDisconnect: () async => monitor.add(
                                        const SerialDisconnectionRequested(),
                                      ),
                                    ),
                                  ),
                                  if (state.error != null) ...[
                                    const SizedBox(height: 8),
                                    _errorBanner(
                                      context,
                                      state.error!,
                                      () => monitor.add(
                                        const SerialErrorDismissed(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            SliverLayoutBuilder(
                              builder: (context, sliver) {
                                final height = max(
                                  220.0,
                                  sliver.viewportMainAxisExtent -
                                      sliver.precedingScrollExtent,
                                );
                                return SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: height,
                                    child: _panel(
                                      context,
                                      child: IndexedStack(
                                        index: state.type.index,
                                        sizing: StackFit.expand,
                                        children: [
                                          ExcludeFocus(
                                            excluding:
                                                state.type !=
                                                MonitorType.normal,
                                            child: TrafficPanel(
                                              compact: compact,
                                              records: state.records,
                                              rxBytes: state.rxBytes,
                                              txBytes: state.txBytes,
                                              droppedRecords:
                                                  state.droppedRecords,
                                              isConnected: state.isConnected,
                                              hasPorts: state.ports.isNotEmpty,
                                              onClear: () => monitor.add(
                                                const SerialHistoryCleared(),
                                              ),
                                            ),
                                          ),
                                          TerminalPanel(
                                            active:
                                                state.type ==
                                                MonitorType.terminal,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ExcludeFocus(
                        excluding: state.type != MonitorType.normal,
                        child: Visibility(
                          visible: state.type == MonitorType.normal,
                          maintainState: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              _panel(
                                context,
                                padding: EdgeInsets.all(compact ? 10 : 12),
                                child: SendDataWidget(
                                  isConnected: state.isConnected,
                                  isSending: state.isSending,
                                  onSend: (bytes) => _send(monitor, bytes),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _panel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF283343)),
      ),
      child: child,
    );
  }

  Widget _errorBanner(
    BuildContext context,
    String message,
    VoidCallback onDismiss,
  ) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bildirimi kapat',
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

InputDecoration _controlDecoration(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
);
