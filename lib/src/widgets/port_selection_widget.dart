part of 'monitor_screen.dart';

class PortSelectionWidget extends StatefulWidget {
  const PortSelectionWidget({
    super.key,
    required this.ports,
    required this.selectedPort,
    required this.isConnected,
    required this.isBusy,
    required this.isRefreshing,
    required this.isSending,
    required this.onPortChanged,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<SerialInfo> ports;
  final String? selectedPort;
  final bool isConnected;
  final bool isBusy;
  final bool isRefreshing;
  final bool isSending;
  final ValueChanged<String?> onPortChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int baudRate) onConnect;
  final Future<void> Function() onDisconnect;

  @override
  State<PortSelectionWidget> createState() => _PortSelectionWidgetState();
}

class _PortSelectionWidgetState extends State<PortSelectionWidget> {
  final _baud = TextEditingController(text: '115200');
  final _baudFocus = FocusNode();

  @override
  void dispose() {
    _baud.dispose();
    _baudFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.isConnected || widget.isBusy;
    final iconOnly = true;
    final label = "";
    final baud = Tooltip(
      message: '8N1 · Akış kontrolü kapalı',
      child: SizedBox(
        height: 48,
        child: TextField(
          key: const Key('baud-input'),
          controller: _baud,
          focusNode: _baudFocus,
          enabled: !locked,
          style: const TextStyle(fontSize: 14),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _controlDecoration('Baud').copyWith(
            suffixIcon: PopupMenuButton<int>(
              tooltip: 'Yaygın baud hızları',
              enabled: !locked,
              icon: const Icon(Icons.expand_more, size: 20),
              onSelected: (value) => _baud.text = '$value',
              itemBuilder: (_) => [
                for (final rate in [
                  1200,
                  2400,
                  4800,
                  9600,
                  19200,
                  38400,
                  57600,
                  115200,
                  230400,
                  460800,
                  921600,
                  1500000,
                ])
                  PopupMenuItem(value: rate, child: Text('$rate')),
              ],
            ),
          ),
        ),
      ),
    );
    final canConnect =
        !widget.isBusy &&
        !widget.isSending &&
        !widget.isRefreshing &&
        widget.selectedPort != null;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<String>(
            key: ValueKey('port-${widget.selectedPort}'),
            initialValue: widget.selectedPort,
            isExpanded: true,
            style: const TextStyle(fontSize: 14),
            decoration: _controlDecoration('Port'),
            hint: Text(
              widget.isRefreshing ? 'Portlar taranıyor…' : 'Port bulunamadı',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              ...widget.ports.map((port) {
                return DropdownMenuItem(
                  value: port.path,
                  child: Text(
                    port.name.isEmpty || port.name == port.path
                        ? port.path
                        : '${port.path} — ${port.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              DropdownMenuItem(
                value: "refresh",
                child: Text(
                  "Refresh",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: locked || widget.isRefreshing
                ? null
                : (value) {
                    if (value == "refresh") {
                      widget.onRefresh();
                      return;
                    }
                    widget.onPortChanged(value);
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: baud),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const Key('connect-button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 16),
            backgroundColor: widget.isConnected
                ? const Color(0xFF3D2C27)
                : null,
            foregroundColor: widget.isConnected ? _txColor : null,
          ),
          onPressed: canConnect
              ? () {
                  if (widget.isConnected) {
                    widget.onDisconnect();
                  } else {
                    widget.onConnect(int.tryParse(_baud.text) ?? 0);
                  }
                }
              : null,
          icon: Icon(
            widget.isConnected ? Icons.link_off : Icons.power_settings_new,
            size: 20,
          ),
          label: Text(label),
        ),
      ],
    );
  }
}
