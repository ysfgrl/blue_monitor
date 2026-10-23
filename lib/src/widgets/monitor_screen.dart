import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../byte_codec.dart';
import '../monitor_controller.dart';
import '../saved_commands.dart';
import '../serial_service.dart';
import '../serial_service_factory.dart';

part 'header.dart';
part 'command_list_dialog.dart';
part 'port_selection_widget.dart';
part 'save_command_dialog.dart';
part 'send_data_widget.dart';
part 'terminal_panel.dart';
part 'terminal_key_bar.dart';
part 'android_terminal_input.dart';
part 'traffic_panel.dart';

enum MonitorType { normal, terminal }

const _rxColor = Color(0xFF5EE0B5);
const _txColor = Color(0xFFFFC878);
const _muted = Color(0xFF94A4BA);
const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6);

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, this.service});

  final SerialService? service;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final MonitorController _monitor;
  MonitorType _type = MonitorType.normal;

  @override
  void initState() {
    super.initState();
    _monitor = MonitorController(widget.service ?? createSerialService());
    _monitor.addListener(_onMonitorChanged);
    unawaited(_monitor.refreshPorts());
  }

  void _onMonitorChanged() {
    if (mounted) setState(() {});
  }

  void _setType(MonitorType type) {
    if (_monitor.status != ConnectionStatus.disconnected || _type == type)
      return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _type = type);
  }

  @override
  void dispose() {
    _monitor.removeListener(_onMonitorChanged);
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                type: _type,
                                onTypeChanged:
                                    _monitor.status ==
                                        ConnectionStatus.disconnected
                                    ? _setType
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _panel(
                                padding: EdgeInsets.all(compact ? 10 : 12),
                                child: PortSelectionWidget(
                                  ports: _monitor.ports,
                                  selectedPort: _monitor.selectedPort,
                                  isConnected: _monitor.isConnected,
                                  isBusy: _monitor.isBusy,
                                  isRefreshing: _monitor.isRefreshing,
                                  isSending: _monitor.isSending,
                                  onPortChanged: _monitor.selectPort,
                                  onRefresh: _monitor.refreshPorts,
                                  onConnect: _monitor.connect,
                                  onDisconnect: _monitor.disconnect,
                                ),
                              ),
                              if (_monitor.error != null) ...[
                                const SizedBox(height: 8),
                                _errorBanner(),
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
                                  child: IndexedStack(
                                    index: _type.index,
                                    sizing: StackFit.expand,
                                    children: [
                                      ExcludeFocus(
                                        excluding: _type != MonitorType.normal,
                                        child: TrafficPanel(
                                          compact: compact,
                                          records: _monitor.records,
                                          rxBytes: _monitor.rxBytes,
                                          txBytes: _monitor.txBytes,
                                          droppedRecords:
                                              _monitor.droppedRecords,
                                          isConnected: _monitor.isConnected,
                                          hasPorts: _monitor.ports.isNotEmpty,
                                          onClear: _monitor.clearHistory,
                                        ),
                                      ),
                                      TerminalPanel(
                                        monitor: _monitor,
                                        active: _type == MonitorType.terminal,
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
                    excluding: _type != MonitorType.normal,
                    child: Visibility(
                      visible: _type == MonitorType.normal,
                      maintainState: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _panel(
                            padding: EdgeInsets.all(compact ? 10 : 12),
                            child: SendDataWidget(
                              isConnected: _monitor.isConnected,
                              isSending: _monitor.isSending,
                              onSend: _monitor.send,
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
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
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

  Widget _errorBanner() {
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
                  _monitor.error!,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bildirimi kapat',
            onPressed: _monitor.clearError,
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
