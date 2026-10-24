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
    this.onRequestPort,
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
  final VoidCallback? onRequestPort;

  @override
  State<PortSelectionWidget> createState() => _PortSelectionWidgetState();
}

class _PortSelectionWidgetState extends State<PortSelectionWidget> {
  int _baudRate = 115200;

  @override
  Widget build(BuildContext context) {
    final locked = widget.isConnected || widget.isBusy;
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
            decoration: _controlDecoration('Port').copyWith(
              suffixIcon: widget.onRequestPort == null
                  ? null
                  : IconButton(
                      key: const Key('request-port-button'),
                      tooltip: 'Port seç ve izin ver',
                      onPressed: locked || widget.isRefreshing
                          ? null
                          : widget.onRequestPort,
                      icon: const Icon(Icons.add, size: 20),
                    ),
            ),
            hint: Text(
              widget.isRefreshing
                  ? 'Portlar taranıyor…'
                  : widget.onRequestPort != null
                  ? 'Port seçin (+)'
                  : 'Port bulunamadı',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              ...widget.ports.map((port) {
                return DropdownMenuItem(
                  value: port.path,
                  child: Text(
                    widget.onRequestPort != null && port.name.isNotEmpty
                        ? port.name
                        : port.path,
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
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            key: const Key('baud-dropdown'),
            initialValue: _baudRate,
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: _controlDecoration('Baud'),
            items: [
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
                DropdownMenuItem(
                  value: rate,
                  child: Text(
                    '$rate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: locked
                ? null
                : (value) {
                    if (value != null) setState(() => _baudRate = value);
                  },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('connect-button'),
          tooltip: widget.isConnected ? 'Bağlantıyı kes' : 'Bağlan',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: widget.isConnected
                ? const Color(0xFF3D2C27)
                : const Color(0xFF347129),
            foregroundColor: widget.isConnected ? _txColor : null,
          ),
          onPressed: canConnect
              ? () {
                  if (widget.isConnected) {
                    widget.onDisconnect();
                  } else {
                    widget.onConnect(_baudRate);
                  }
                }
              : null,
          icon: Icon(
            widget.isConnected ? Icons.link_off : Icons.power_settings_new,
            size: 20,
          ),
        ),
      ],
    );
  }
}
