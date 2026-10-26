part of 'serial_terminal.dart';

class _CommandListDialog extends StatefulWidget {
  const _CommandListDialog({
    required this.commands,
    required this.store,
    required this.onChanged,
  });

  final List<SerialCommand> commands;
  final SavedCommandStore store;
  final ValueChanged<List<SerialCommand>> onChanged;

  @override
  State<_CommandListDialog> createState() => _CommandListDialogState();
}

class _CommandListDialogState extends State<_CommandListDialog> {
  late List<SerialCommand> _commands = List.of(widget.commands);
  bool _busy = false;
  String? _error;

  Future<void> _editCommand(SerialCommand command) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await showDialog<SerialCommand>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SaveCommandDialog(
          initialName: command.name,
          initialText: command.text,
          mode: command.mode,
          cr: command.cr,
          lf: command.lf,
          isEditing: true,
          existingNames: _commands
              .where((item) => item != command)
              .map((item) => item.name.toLowerCase())
              .toSet(),
          onSave: (edited) async {
            final updated = List<SerialCommand>.of(_commands);
            final index = updated.indexOf(command);
            if (index < 0) throw StateError('serial.commandNotFound');
            updated[index] = edited;
            await widget.store.save(updated);
            if (!mounted) return;
            setState(() => _commands = updated);
            widget.onChanged(updated);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCommand(SerialCommand command) async {
    if (_busy) return;
    final updated = List<SerialCommand>.of(_commands)..remove(command);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.save(updated);
      if (!mounted) return;
      setState(() => _commands = updated);
      widget.onChanged(updated);
    } catch (_) {
      if (mounted) setState(() => _error = 'serial.commandDeleteFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(context.tr('serial.savedCommands')),
        content: SizedBox(
          width: 520,
          height: min(440.0, MediaQuery.sizeOf(context).height * 0.55),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.tr(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: _commands.isEmpty
                    ? Center(child: Text(context.tr('serial.noSavedCommands')))
                    : ListView.separated(
                        key: const Key('command-management-list'),
                        itemCount: _commands.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (_, index) =>
                            _commandRow(_commands[index]),
                      ),
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('global.close')),
          ),
        ],
      ),
    );
  }

  Widget _commandRow(SerialCommand command) {
    final ending = command.cr && command.lf
        ? context.tr('global.crlf')
        : command.cr
        ? context.tr('global.cr')
        : command.lf
        ? context.tr('global.lf')
        : context.tr('global.noLineEnding');
    return Row(
      key: ValueKey('managed-command-${command.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                command.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'serial.commandSummary',
                  namedArgs: {
                    'mode': context.tr(
                      command.mode == InputMode.ascii
                          ? 'global.ascii'
                          : 'global.hex',
                    ),
                    'ending': ending,
                  },
                ),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                command.text.replaceAll('\r', r'\r').replaceAll('\n', r'\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _mono.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: ValueKey('edit-command-${command.name}'),
          tooltip: context.tr('global.edit'),
          onPressed: _busy ? null : () => _editCommand(command),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: ValueKey('delete-command-${command.name}'),
          tooltip: context.tr('global.delete'),
          onPressed: _busy ? null : () => _deleteCommand(command),
          icon: Icon(
            Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}
