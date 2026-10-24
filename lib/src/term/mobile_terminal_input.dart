part of 'terminal_panel.dart';

/// Keeps the mobile IME connection independent of terminal repaints and resizing.
class _MobileTerminalInput extends StatefulWidget {
  const _MobileTerminalInput({
    super.key,
    required this.terminal,
    required this.focusNode,
    required this.enabled,
    required this.keyboardEnabled,
    required this.child,
  });

  final xterm.Terminal terminal;
  final FocusNode focusNode;
  final bool enabled;
  final bool keyboardEnabled;
  final Widget child;

  @override
  State<_MobileTerminalInput> createState() => _MobileTerminalInputState();
}

class _MobileTerminalInputState extends State<_MobileTerminalInput>
    with TextInputClient {
  // A character before the caret lets IMEs report Backspace on an empty input.
  static const _initialValue = TextEditingValue(
    text: ' ',
    selection: TextSelection.collapsed(offset: 1),
  );

  TextInputConnection? _connection;
  TextEditingValue _editingValue = _initialValue;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _MobileTerminalInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _closeConnection();
    }
    if (!widget.enabled ||
        !widget.keyboardEnabled ||
        !widget.focusNode.hasFocus) {
      _closeConnection();
    } else if (!oldWidget.enabled ||
        !oldWidget.keyboardEnabled ||
        oldWidget.terminal != widget.terminal) {
      _closeConnection();
      requestKeyboard();
    }
  }

  void _onFocusChanged() {
    if (widget.enabled && widget.keyboardEnabled && widget.focusNode.hasFocus) {
      if (_connection?.attached != true) requestKeyboard();
    } else {
      _closeConnection();
    }
  }

  void requestKeyboard() {
    if (!widget.enabled || !widget.keyboardEnabled) return;
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
      return;
    }
    if (_connection?.attached != true) {
      _editingValue = _initialValue;
      _connection = TextInput.attach(
        this,
        const TextInputConfiguration(
          inputType: TextInputType.visiblePassword,
          inputAction: TextInputAction.done,
          keyboardAppearance: Brightness.dark,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
        ),
      );
      _connection!.setEditingState(_editingValue);
    }
    _connection!.show();
  }

  void _closeConnection() {
    final connection = _connection;
    _connection = null;
    connection?.close();
    _editingValue = _initialValue;
  }

  void _resetEditingValue() {
    // Keep the framework and the IME in sync after each committed insertion.
    _editingValue = _initialValue;
    _connection?.setEditingState(_editingValue);
  }

  @override
  TextEditingValue get currentTextEditingValue => _editingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (!widget.enabled || _connection?.attached != true) return;
    if (value == _editingValue) return;
    _editingValue = value;
    // Do not send an unfinished accented character or IME candidate twice.
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    _commitEditingValue();
  }

  void _commitEditingValue() {
    final text = _editingValue.text;
    _resetEditingValue();
    if (text.isEmpty) {
      widget.terminal.keyInput(xterm.TerminalKey.backspace);
      return;
    }
    final inserted = text.startsWith(_initialValue.text)
        ? text.substring(_initialValue.text.length)
        : text;
    // Keyboards may insert a newline instead of invoking performAction.
    final lines = inserted.split(RegExp(r'\r\n|\r|\n'));
    for (var index = 0; index < lines.length; index++) {
      if (index > 0) widget.terminal.keyInput(xterm.TerminalKey.enter);
      if (lines[index].isNotEmpty) widget.terminal.textInput(lines[index]);
    }
  }

  @override
  void performAction(TextInputAction action) {
    if (!widget.enabled || _connection?.attached != true) return;
    if (action == TextInputAction.done ||
        action == TextInputAction.newline ||
        action == TextInputAction.send) {
      _commitEditingValue();
      widget.terminal.keyInput(xterm.TerminalKey.enter);
    }
  }

  @override
  void connectionClosed() {
    _connection?.connectionClosedReceived();
    _connection = null;
    _editingValue = _initialValue;
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
