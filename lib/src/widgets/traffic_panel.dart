part of 'monitor_screen.dart';

enum _TrafficDisplayMode {
  ascii('ASCII'),
  hex('HEX'),
  both('İkisi');

  const _TrafficDisplayMode(this.label);

  final String label;
}

class TrafficPanel extends StatefulWidget {
  const TrafficPanel({
    super.key,
    required this.compact,
    required this.records,
    required this.rxBytes,
    required this.txBytes,
    required this.droppedRecords,
    required this.isConnected,
    required this.hasPorts,
    required this.onClear,
  });

  final bool compact;
  final List<TrafficRecord> records;
  final int rxBytes;
  final int txBytes;
  final int droppedRecords;
  final bool isConnected;
  final bool hasPorts;
  final VoidCallback onClear;

  @override
  State<TrafficPanel> createState() => _TrafficPanelState();
}

class _TrafficPanelState extends State<TrafficPanel> {
  final _scroll = ScrollController();
  bool _autoScroll = true;
  _TrafficDisplayMode _displayMode = _TrafficDisplayMode.ascii;
  bool _scrollScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.records.isNotEmpty) _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant TrafficPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && !identical(oldWidget.records, widget.records)) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted && _autoScroll && _scroll.hasClients) {
        final end = _scroll.position.maxScrollExtent;
        if ((end - _scroll.offset).abs() > 0.5) _scroll.jumpTo(end);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _setDisplay({bool? ascii, bool? hex}) {
    final showAscii = ascii ?? _displayMode != _TrafficDisplayMode.hex;
    final showHex = hex ?? _displayMode != _TrafficDisplayMode.ascii;
    if (!showAscii && !showHex) return;
    final mode = showAscii && showHex
        ? _TrafficDisplayMode.both
        : showAscii
        ? _TrafficDisplayMode.ascii
        : _TrafficDisplayMode.hex;
    if (mode == _displayMode) return;
    setState(() => _displayMode = mode);
    if (_autoScroll) _scrollToEnd();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = widget.compact || constraints.maxWidth < 600;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  MergeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: const Key('traffic-ascii'),
                          value: _displayMode != _TrafficDisplayMode.hex,
                          onChanged: (value) {
                            if (value != null) _setDisplay(ascii: value);
                          },
                        ),
                        const Text(
                          'ASCII',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  MergeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: const Key('traffic-hex'),
                          value:
                          _displayMode != _TrafficDisplayMode.ascii,
                          onChanged: (value) {
                            if (value != null) _setDisplay(hex: value);
                          },
                        ),
                        const Text('HEX', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(child: SizedBox()),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        key: const Key('traffic-follow'),
                        value: _autoScroll,
                        onChanged: (value) {
                          setState(() => _autoScroll = value!);
                          if (_autoScroll) _scrollToEnd();
                        },
                      ),
                      const Text(
                        'Takip et',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),


                  IconButton(
                    tooltip: 'Ekranı temizle',
                    onPressed: widget.onClear,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.records.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.hub_outlined,
                              size: 30,
                              color: _muted,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Veri bekleniyor',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.isConnected
                                  ? 'Gelen ve gönderilen baytlar burada görünecek.'
                                  : !widget.hasPorts
                                  ? 'Cihazınızı takın ve port listesini yenileyin.'
                                  : 'Portu ve baud hızını seçip bağlantıyı başlatın.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        if (_autoScroll &&
                            notification.depth == 0 &&
                            notification.metrics.pixels <
                                notification.metrics.maxScrollExtent - 0.5) {
                          _scrollToEnd();
                        }
                        return false;
                      },
                      child: Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        child: ListView.builder(
                          key: const Key('traffic-list'),
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: widget.records.length,
                          itemBuilder: (_, index) => _TrafficRow(
                            key: ObjectKey(widget.records[index]),
                            record: widget.records[index],
                            displayMode: _displayMode,
                          ),
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),
              child: SingleChildScrollView(
                primary: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.records.length} kayıt',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        if (compact) ...[
                          _counter('RX', widget.rxBytes, _rxColor),
                          _counter('TX', widget.txBytes, _txColor),
                        ],
                        Text(
                          widget.droppedRecords > 0
                              ? '${widget.droppedRecords} eski kayıt silindi'
                              : _displayMode == _TrafficDisplayMode.both
                              ? 'ASCII + HEX'
                              : _displayMode.label,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _counter(String label, int count, Color color) {
    return Text(
      '$label  $count B',
      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: color),
    );
  }
}

class _TrafficRow extends StatelessWidget {
  const _TrafficRow({
    super.key,
    required this.record,
    required this.displayMode,
  });

  final TrafficRecord record;
  final _TrafficDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final rx = record.direction == TrafficDirection.rx;
    final color = rx ? _rxColor : _txColor;
    final time = record.timestamp;
    String pad(int value, [int width = 2]) => '$value'.padLeft(width, '0');
    final stamp =
        '${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}'
        '.${pad(time.millisecond, 3)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 2),
          bottom: const BorderSide(color: Color(0xFF1E2938)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metadataWidth = min(
            constraints.maxWidth * 0.28,
            constraints.maxWidth < 600 ? 80.0 : 104.0,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: metadataWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rx ? '↓ RX' : '↑ TX'} · ${record.bytes.length} B',
                      style: _mono.copyWith(color: color, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Color(0xFF283343))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (displayMode != _TrafficDisplayMode.hex)
                        _data(
                          context,
                          'ASCII',
                          formatAscii(record.bytes),
                          () => asciiClipboardText(record.bytes),
                        ),
                      if (displayMode == _TrafficDisplayMode.both)
                        const SizedBox(height: 4),
                      if (displayMode != _TrafficDisplayMode.ascii)
                        _data(
                          context,
                          'HEX',
                          formatHex(record.bytes),
                          () => formatHex(record.bytes),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _data(
    BuildContext context,
    String label,
    String value,
    String Function() clipboardText,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        key: ValueKey('copy-${label.toLowerCase()}'),
        constraints: BoxConstraints(
            maxWidth: 21,
            maxHeight: 21
        ),
        padding: EdgeInsets.all(0),
        tooltip: '$label kopyala',
        onPressed: () => _copy(context, label, clipboardText()),
        icon: const Icon(Icons.content_copy_rounded, size: 18,),
      ),

      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label= ',
                  style: const TextStyle(color: _muted),
                ),
                TextSpan(text: value, ),
              ],
            ),
            style: _mono,
            maxLines: 1,
          ),
        ),
      ),
    ],
  );

  Future<void> _copy(BuildContext context, String label, String text) async {
    var message = '$label kopyalandı.';
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      message = '$label kopyalanamadı.';
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      );
  }
}
