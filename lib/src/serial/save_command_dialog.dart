part of 'serial_terminal.dart';

class _SaveCommandDialog extends StatefulWidget {
  const _SaveCommandDialog({required this.initialText, required this.mode, required this.cr, required this.lf, required this.existingNames, required this.onSave, this.initialName = '', this.isEditing = false,});

  final String initialText;
  final InputMode mode;
  final bool cr;
  final bool lf;
  final Set<String> existingNames;
  final Future<void> Function(SerialCommand command) onSave;
  final String initialName;
  final bool isEditing;

  @override
  State<_SaveCommandDialog> createState() => _SaveCommandDialogState();
}

class _SaveCommandDialogState extends State<_SaveCommandDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _text = TextEditingController(text: widget.initialText);
  late InputMode _mode = widget.mode;
  late bool _cr = widget.cr;
  late bool _lf = widget.lf;
  bool _saving = false;
  String? _saveError;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final command = SerialCommand(
      name: _name.text.trim(),
      text: _text.text,
      mode: _mode,
      cr: _cr,
      lf: _lf,
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(command);
      if (mounted) Navigator.of(context).pop(command);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Komut kaydedilemedi. Tekrar deneyin.';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ending = _cr && _lf
        ? 'CRLF'
        : _cr
        ? 'CR'
        : _lf
        ? 'LF'
        : 'Yok';
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.isEditing ? 'Komutu düzenle' : 'Komut kaydet'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('command-name'),
                    controller: _name,
                    autofocus: true,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Komut adı'),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Komut adı girin.';
                      if (widget.existingNames.contains(name.toLowerCase())) {
                        return 'Bu adla kayıtlı bir komut var.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<InputMode>(
                    key: const Key('command-mode'),
                    expandedInsets: EdgeInsets.zero,
                    segments: const [
                      ButtonSegment(
                        value: InputMode.ascii,
                        label: Text('ASCII'),
                      ),
                      ButtonSegment(value: InputMode.hex, label: Text('HEX')),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSelectionChanged: _saving
                        ? null
                        : (selection) =>
                              setState(() => _mode = selection.single),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('command-text'),
                    controller: _text,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 5,
                    style: _mono,
                    decoration: InputDecoration(
                      labelText: _mode == InputMode.ascii
                          ? 'Komut (ASCII)'
                          : 'Komut (HEX)',
                      hintText: _mode == InputMode.ascii
                          ? 'Metin girin…'
                          : '41 42 0D 0A',
                      errorMaxLines: 4,
                    ),
                    validator: (value) {
                      try {
                        SerialHelper.encodeInput(value ?? '', _mode);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_mode == InputMode.ascii ? 'ASCII' : 'HEX'} · Satır sonu: $ending',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          key: const Key('command-cr'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('CR'),
                          value: _cr,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _cr = value ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          key: const Key('command-lf'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('LF'),
                          value: _lf,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _lf = value ?? false),
                        ),
                      ),
                    ],
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Güncelle' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}
