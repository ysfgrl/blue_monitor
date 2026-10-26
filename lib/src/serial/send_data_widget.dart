part of 'serial_terminal.dart';

class SendDataWidget extends StatefulWidget {
  const SendDataWidget({super.key, required this.isConnected, required this.isSending, required this.onSend,});

  final bool isConnected;
  final bool isSending;
  final Future<bool> Function(Uint8List bytes) onSend;

  @override
  State<SendDataWidget> createState() => _SendDataWidgetState();
}

class _SendDataWidgetState extends State<SendDataWidget> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _commandsScroll = ScrollController();
  final _commandStore = SavedCommandStore();
  List<SerialCommand> _commands = [];
  bool _loadingCommands = true;
  bool _commandsLoadFailed = false;
  bool _commandDialogOpen = false;
  bool _sendingCommand = false;
  InputMode _mode = InputMode.ascii;
  bool _cr = false;
  bool _lf = false;
  String? _inputError;

  bool get _isSending => widget.isSending || _sendingCommand;
  bool get _commandsLocked =>
      _isSending ||
      _commandDialogOpen ||
      _loadingCommands ||
      _commandsLoadFailed;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCommands());
  }

  Future<void> _loadCommands() async {
    setState(() {
      _loadingCommands = true;
      _commandsLoadFailed = false;
    });
    try {
      final commands = await _commandStore.load();
      if (mounted) setState(() => _commands = commands);
    } catch (_) {
      if (mounted) setState(() => _commandsLoadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingCommands = false);
    }
  }

  Future<void> _addCommand() async {
    if (_commandsLocked) return;
    setState(() => _commandDialogOpen = true);
    try {
      final command = await showDialog<SerialCommand>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SaveCommandDialog(
          initialText: _input.text,
          mode: _mode,
          cr: _cr,
          lf: _lf,
          existingNames: _commands
              .map((command) => command.name.toLowerCase())
              .toSet(),
          onSave: (command) async {
            final updated = [..._commands, command];
            await _commandStore.save(updated);
            if (mounted) setState(() => _commands = updated);
          },
        ),
      );
      if (!mounted || command == null) return;
      _selectCommand(command);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komut kaydedildi.')));
    } finally {
      if (mounted) setState(() => _commandDialogOpen = false);
    }
  }

  Future<void> _showCommands() async {
    if (_commandsLocked) return;
    setState(() => _commandDialogOpen = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CommandListDialog(
          commands: _commands,
          store: _commandStore,
          onChanged: (commands) {
            if (mounted) setState(() => _commands = commands);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _commandDialogOpen = false);
    }
  }

  void _selectCommand(SerialCommand command) {
    if (_isSending) return;
    setState(() {
      _input.value = TextEditingValue(
        text: command.text,
        selection: TextSelection.collapsed(offset: command.text.length),
      );
      _mode = command.mode;
      _cr = command.cr;
      _lf = command.lf;
      _inputError = null;
    });
    _inputFocus.requestFocus();
  }

  void _setMode(InputMode mode) {
    if (_isSending || mode == _mode) return;
    var text = _input.text;
    try {
      if (text.isNotEmpty) {
        final bytes = SerialHelper.encodeInput(text, _mode);
        if (mode == InputMode.ascii && bytes.any((byte) => byte > 127)) {
          throw const FormatException(
            'Veri ASCII dışında baytlar içeriyor. HEX olarak düzenleyebilirsiniz.',
          );
        }
        text = mode == InputMode.hex ? SerialHelper.formatHex(bytes) : ascii.decode(bytes);
      }
      setState(() {
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _mode = mode;
        _inputError = null;
      });
    } on FormatException catch (error) {
      setState(() => _inputError = error.message);
    }
    _inputFocus.requestFocus();
  }

  Future<void> _send() async {
    if (!widget.isConnected || _isSending) return;
    final text = _input.text;
    late final Uint8List bytes;
    try {
      bytes = Uint8List.fromList([
        ...SerialHelper.encodeInput(text, _mode),
        if (_cr) 0x0D,
        if (_lf) 0x0A,
      ]);
    } on FormatException catch (error) {
      setState(() => _inputError = error.message);
      _inputFocus.requestFocus();
      return;
    }
    if (_inputError != null) setState(() => _inputError = null);
    final success = await widget.onSend(bytes);
    if (!mounted) return;
    if (success && _input.text == text) _input.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _sendCommand(SerialCommand command) async {
    if (!widget.isConnected || _commandsLocked) return;
    late final Uint8List bytes;
    try {
      bytes = Uint8List.fromList([
        ...SerialHelper.encodeInput(command.text, command.mode),
        if (command.cr) 0x0D,
        if (command.lf) 0x0A,
      ]);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${command.name}: ${error.message}')),
      );
      return;
    }
    setState(() => _sendingCommand = true);
    try {
      await widget.onSend(bytes);
    } finally {
      if (mounted) setState(() => _sendingCommand = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _commandsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.isConnected && !_isSending;
    final commandButtonStyle = IconButton.styleFrom(
      fixedSize: const Size.square(32),
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      iconSize: 18,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SegmentedButton<InputMode>(
              segments: const [
                ButtonSegment(value: InputMode.ascii, label: Text('ASCII')),
                ButtonSegment(value: InputMode.hex, label: Text('HEX')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                visualDensity: const VisualDensity(horizontal: -2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: _isSending
                  ? null
                  : (value) => _setMode(value.single),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _endingCheckbox(
                  'CR',
                  _cr,
                  (value) => setState(() => _cr = value),
                ),
                const SizedBox(width: 4),
                _endingCheckbox(
                  'LF',
                  _lf,
                  (value) => setState(() => _lf = value),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('add-command'),
                  tooltip: 'Komut kaydet',
                  style: commandButtonStyle,
                  onPressed: _commandsLocked ? null : _addCommand,
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton(
                  key: const Key('manage-commands'),
                  tooltip: 'Kayıtlı komutları yönet',
                  style: commandButtonStyle,
                  onPressed: _commandsLocked ? null : _showCommands,
                  icon: const Icon(Icons.list_alt_rounded),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: _inputError == null ? 40 : null,
                child: TextField(
                  key: const Key('send-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  enabled: !_isSending,
                  style: _mono.copyWith(fontSize: 12, height: 1.3),
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? (_) => _send() : null,
                  onChanged: (_) {
                    if (_inputError != null) setState(() => _inputError = null);
                  },
                  decoration:
                      _controlDecoration(
                        _mode == InputMode.ascii ? 'ASCII' : 'HEX',
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: _mode == InputMode.ascii
                            ? 'Metin girin…'
                            : '41 42 0D 0A',
                        errorText: _inputError,
                        errorMaxLines: 4,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const Key('send-button'),
              tooltip: 'Gönder',
              style: IconButton.styleFrom(
                fixedSize: const Size.square(40),
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: canSend ? _send : null,
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
        _savedCommandsRow(canSend),
      ],
    );
  }

  Widget _savedCommandsRow(bool canSend) => Scrollbar(
    controller: _commandsScroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      key: const Key('saved-commands'),
      controller: _commandsScroll,
      scrollDirection: Axis.horizontal,
      primary: false,
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingCommands)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_commandsLoadFailed)
              TextButton.icon(
                key: const Key('retry-saved-commands'),
                onPressed: _loadCommands,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Komutlar yüklenemedi. Yeniden dene'),
              )
            else if (_commands.isEmpty)
              const Text(
                'Kayıtlı komut yok',
                style: TextStyle(color: _muted, fontSize: 11),
              )
            else
              for (final command in _commands)
                _savedCommandItem(command, canSend),
          ],
        ),
      ),
    ),
  );

  Widget _savedCommandItem(SerialCommand command, bool canSend) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        key: ValueKey('saved-command-${command.name}'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: canSend && !_commandsLocked
            ? () => _sendCommand(command)
            : null,
        child: Text(command.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _endingCheckbox(String label, bool value, ValueChanged<bool> onChanged,) => InkWell(
    onTap: _isSending ? null : () => onChanged(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          key: ValueKey('line-ending-${label.toLowerCase()}'),
          value: value,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: _isSending
              ? null
              : (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
