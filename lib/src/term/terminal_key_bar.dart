part of 'terminal_panel.dart';

class _TerminalKeyBar extends StatelessWidget {
  const _TerminalKeyBar({
    required this.enabled,
    required this.ctrlPressed,
    required this.keyboardOpen,
    required this.onKeyboardToggle,
    required this.onCtrlPressed,
    required this.onCtrlCPressed,
    required this.onKeyPressed,
  });

  final bool enabled;
  final bool ctrlPressed;
  final bool keyboardOpen;
  final VoidCallback onKeyboardToggle;
  final VoidCallback onCtrlPressed;
  final VoidCallback onCtrlCPressed;
  final ValueChanged<xterm.TerminalKey> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _ubuntuTerminalTheme.background,
          border: Border(
            top: BorderSide(
              color: _ubuntuTerminalTheme.foreground.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _button(
                'keyboard',
                keyboardOpen
                    ? context.tr('terminal.hideKeyboard')
                    : context.tr('terminal.showKeyboard'),
                onKeyboardToggle,
                icon: keyboardOpen
                    ? Icons.keyboard_hide_rounded
                    : Icons.keyboard_rounded,
                selected: keyboardOpen,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('terminal-special-keys'),
                scrollDirection: Axis.horizontal,
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      toggled: ctrlPressed,
                      child: _button(
                        context.tr('terminal.ctrl'),
                        context.tr('terminal.ctrlHint'),
                        onCtrlPressed,
                        selected: ctrlPressed,
                      ),
                    ),
                    _button(
                      context.tr('terminal.ctrlC'),
                      context.tr('terminal.sendCtrlC'),
                      onCtrlCPressed,
                    ),
                    _key(
                      context.tr('terminal.escape'),
                      context.tr('terminal.escapeHint'),
                      xterm.TerminalKey.escape,
                    ),
                    _key(
                      context.tr('terminal.tab'),
                      context.tr('terminal.tab'),
                      xterm.TerminalKey.tab,
                    ),
                    _key(
                      context.tr('terminal.enter'),
                      context.tr('terminal.enter'),
                      xterm.TerminalKey.enter,
                    ),
                    _key(
                      'left',
                      context.tr('terminal.arrowLeft'),
                      xterm.TerminalKey.arrowLeft,
                      icon: Icons.arrow_back_rounded,
                    ),
                    _key(
                      'up',
                      context.tr('terminal.arrowUp'),
                      xterm.TerminalKey.arrowUp,
                      icon: Icons.arrow_upward_rounded,
                    ),
                    _key(
                      'down',
                      context.tr('terminal.arrowDown'),
                      xterm.TerminalKey.arrowDown,
                      icon: Icons.arrow_downward_rounded,
                    ),
                    _key(
                      'right',
                      context.tr('terminal.arrowRight'),
                      xterm.TerminalKey.arrowRight,
                      icon: Icons.arrow_forward_rounded,
                    ),
                    _key(
                      context.tr('terminal.home'),
                      context.tr('terminal.startOfLine'),
                      xterm.TerminalKey.home,
                    ),
                    _key(
                      context.tr('terminal.end'),
                      context.tr('terminal.endOfLine'),
                      xterm.TerminalKey.end,
                    ),
                    _key(
                      context.tr('terminal.pageUp'),
                      context.tr('terminal.previousPage'),
                      xterm.TerminalKey.pageUp,
                    ),
                    _key(
                      context.tr('terminal.pageDown'),
                      context.tr('terminal.nextPage'),
                      xterm.TerminalKey.pageDown,
                    ),
                    _key(
                      context.tr('terminal.delete'),
                      context.tr('terminal.deleteHint'),
                      xterm.TerminalKey.delete,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(
    String label,
    String tooltip,
    xterm.TerminalKey key, {
    IconData? icon,
  }) => _button(label, tooltip, () => onKeyPressed(key), icon: icon);

  Widget _button(
    String label,
    String tooltip,
    VoidCallback onPressed, {
    IconData? icon,
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Tooltip(
      message: tooltip,
      child: TextButton(
        key: ValueKey('terminal-key-${label.toLowerCase()}'),
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: _ubuntuTerminalTheme.foreground,
          disabledForegroundColor: _ubuntuTerminalTheme.foreground.withValues(
            alpha: 0.3,
          ),
          backgroundColor: selected
              ? const Color(0xFFE95420).withValues(alpha: 0.4)
              : _ubuntuTerminalTheme.foreground.withValues(alpha: 0.06),
          textStyle: const TextStyle(fontFamily: 'UbuntuMono', fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: icon == null
            ? Text(label)
            : Icon(icon, size: 18, semanticLabel: tooltip),
      ),
    ),
  );
}
