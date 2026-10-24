part of 'monitor_screen.dart';

const _ubuntuTerminalTheme = xterm.TerminalTheme(
  cursor: Color(0xFFFFFFFF),
  selection: Color(0x40FFFFFF),
  foreground: Color(0xFFEEEEEC),
  background: Color(0xFF300A24),
  black: Color(0xFF2E3436),
  red: Color(0xFFCC0000),
  green: Color(0xFF4E9A06),
  yellow: Color(0xFFC4A000),
  blue: Color(0xFF3465A4),
  magenta: Color(0xFF75507B),
  cyan: Color(0xFF06989A),
  white: Color(0xFFD3D7CF),
  brightBlack: Color(0xFF555753),
  brightRed: Color(0xFFEF2929),
  brightGreen: Color(0xFF8AE234),
  brightYellow: Color(0xFFFCE94F),
  brightBlue: Color(0xFF729FCF),
  brightMagenta: Color(0xFFAD7FA8),
  brightCyan: Color(0xFF34E2E2),
  brightWhite: Color(0xFFEEEEEC),
  searchHitBackground: Color(0xFFFCE94F),
  searchHitBackgroundCurrent: Color(0xFFE95420),
  searchHitForeground: Color(0xFF300A24),
);

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key, required this.active});

  final bool active;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel>
    with WidgetsBindingObserver {
  final _focus = FocusNode();
  final _androidInputKey = GlobalKey<_AndroidTerminalInputState>();
  GlobalKey<xterm.TerminalViewState> _terminalViewKey =
      GlobalKey<xterm.TerminalViewState>();
  late final SerialBloc _monitor;
  late xterm.Terminal _terminal;
  late StreamSubscription<Uint8List> _incoming;
  ByteConversionSink? _decoder;
  bool _connected = false;
  bool _ctrlPressed = false;
  bool _keyboardRequested = false;
  bool _keyboardWasVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monitor = context.read<SerialBloc>();
    _attachMonitor();
  }

  void _attachMonitor() {
    _connected = _monitor.state.isConnected;
    _resetTerminal();
    _incoming = _monitor.incomingBytes.listen((bytes) {
      _decoder?.add(bytes);
    });
  }

  void _resetTerminal() {
    _decoder?.close();
    _ctrlPressed = false;
    _keyboardRequested = false;
    _keyboardWasVisible = false;
    _terminalViewKey = GlobalKey<xterm.TerminalViewState>();
    _terminal = _TerminalWithCtrl(
      isCtrlPressed: () => _ctrlPressed,
      onCtrlUsed: _clearCtrl,
      maxLines: 5000,
      platform: xterm.TerminalTargetPlatform.linux,
      onOutput: _sendOutput,
    );
    _decoder = const Utf8Decoder(
      allowMalformed: true,
    ).startChunkedConversion(_TerminalTextSink(_terminal));
  }

  void _sendOutput(String output) {
    if (!widget.active || !_monitor.state.isConnected || output.isEmpty) return;
    if (_monitor.isClosed) return;
    _monitor.add(SerialSendRequested(Uint8List.fromList(utf8.encode(output))));
  }

  void _clearCtrl() {
    if (_ctrlPressed && mounted) setState(() => _ctrlPressed = false);
  }

  void _toggleCtrl() {
    if (!widget.active || !_monitor.state.isConnected) return;
    setState(() => _ctrlPressed = !_ctrlPressed);
    _keepKeyboardFocus();
  }

  void _pressTerminalKey(xterm.TerminalKey key) {
    if (!widget.active || !_monitor.state.isConnected) return;
    _terminal.keyInput(key);
    _keepKeyboardFocus();
  }

  void _keepKeyboardFocus() {
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  void _toggleKeyboard() {
    if (!widget.active || !_monitor.state.isConnected) return;
    setState(() => _keyboardRequested = !_keyboardRequested);
    if (!_keyboardRequested) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_keyboardRequested ||
          !widget.active ||
          !_monitor.state.isConnected) {
        return;
      }
      _keepKeyboardFocus();
      if (Theme.of(context).platform == TargetPlatform.android) {
        _androidInputKey.currentState?.requestKeyboard();
      } else {
        _terminalViewKey.currentState?.requestKeyboard();
      }
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final visible = View.of(context).viewInsets.bottom > 0;
    // The system Back/Hide action also revokes automatic reopening on focus.
    if (_keyboardWasVisible && !visible && _keyboardRequested) {
      setState(() => _keyboardRequested = false);
    }
    _keyboardWasVisible = visible;
  }

  void _onConnectionChanged(SerialState state) {
    final connected = state.isConnected;
    if (connected && !_connected) {
      _terminal.onOutput = null;
      _resetTerminal();
      setState(() {});
    } else if (!connected && _connected) {
      _clearCtrl();
      if (_keyboardRequested) setState(() => _keyboardRequested = false);
      _decoder?.close();
      _decoder = null;
    }
    if (connected && !_connected) _focusTerminal();
    _connected = connected;
  }

  void _focusTerminal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && _monitor.state.isConnected) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _focusTerminal();
    if (!widget.active) {
      _ctrlPressed = false;
      _keyboardRequested = false;
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_incoming.cancel());
    _terminal.onOutput = null;
    _decoder?.close();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final android = Theme.of(context).platform == TargetPlatform.android;
    final mobile = android || Theme.of(context).platform == TargetPlatform.iOS;
    final enabled = widget.active && _monitor.state.isConnected;
    Widget terminalView = xterm.TerminalView(
      _terminal,
      key: _terminalViewKey,
      focusNode: _focus,
      readOnly: !enabled,
      // Android's IME is handled separately; xterm still handles physical keys.
      hardwareKeyboardOnly: android || (mobile && !_keyboardRequested),
      padding: const EdgeInsets.all(12),
      keyboardType: TextInputType.multiline,
      theme: _ubuntuTerminalTheme,
      textStyle: const xterm.TerminalStyle(
        fontFamily: 'UbuntuMono',
        fontSize: 14,
        height: 1.2,
      ),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
            CopySelectionTextIntent.copy,
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true):
            PasteTextIntent(SelectionChangedCause.keyboard),
      },
    );
    if (android) {
      terminalView = _AndroidTerminalInput(
        key: _androidInputKey,
        terminal: _terminal,
        focusNode: _focus,
        enabled: enabled,
        keyboardEnabled: _keyboardRequested,
        child: terminalView,
      );
    }
    return BlocListener<SerialBloc, SerialState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (_, state) => _onConnectionChanged(state),
      child: ExcludeFocus(
        excluding: !widget.active,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: terminalView),
              _TerminalKeyBar(
                enabled: enabled,
                ctrlPressed: _ctrlPressed,
                keyboardOpen: _keyboardRequested,
                onKeyboardToggle: _toggleKeyboard,
                onCtrlPressed: _toggleCtrl,
                onKeyPressed: _pressTerminalKey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalTextSink implements Sink<String> {
  const _TerminalTextSink(this.terminal);

  final xterm.Terminal terminal;

  @override
  void add(String text) => terminal.write(text);

  @override
  void close() {}
}

/// Applies the mobile Ctrl key to user input without altering terminal replies.
class _TerminalWithCtrl extends xterm.Terminal {
  _TerminalWithCtrl({
    required this.isCtrlPressed,
    required this.onCtrlUsed,
    super.maxLines,
    super.platform,
    super.onOutput,
  });

  final bool Function() isCtrlPressed;
  final VoidCallback onCtrlUsed;

  @override
  bool keyInput(
    xterm.TerminalKey key, {
    bool shift = false,
    bool alt = false,
    bool ctrl = false,
  }) {
    final virtualCtrl = isCtrlPressed();
    final modifier =
        key == xterm.TerminalKey.control ||
        key == xterm.TerminalKey.shift ||
        key == xterm.TerminalKey.alt ||
        key == xterm.TerminalKey.meta;
    final handled = super.keyInput(
      key,
      shift: shift,
      alt: alt,
      ctrl: ctrl || (virtualCtrl && !modifier),
    );
    if (virtualCtrl && !modifier && handled) onCtrlUsed();
    return handled;
  }

  @override
  void textInput(String text) {
    if (!isCtrlPressed() || text.isEmpty) {
      super.textInput(text);
      return;
    }
    onCtrlUsed();
    final first = String.fromCharCode(text.runes.first);
    var code = first.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7A) code -= 0x20;
    final control = switch (code) {
      0x20 => 0,
      0x3F => 0x7F,
      >= 0x40 && <= 0x5F => code & 0x1F,
      _ => null,
    };
    super.textInput(
      '${control == null ? first : String.fromCharCode(control)}${text.substring(first.length)}',
    );
  }

  @override
  void paste(String text) {
    if (isCtrlPressed()) onCtrlUsed();
    super.paste(text);
  }
}
