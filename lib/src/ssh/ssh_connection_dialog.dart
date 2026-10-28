import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serial_monitor/src/bloc/ssh/store.dart';
import 'package:serial_monitor/src/helper/dialog.dart';
import '../models/ssh_connection.dart';

class SshConnectionDialog extends StatefulWidget {
  const SshConnectionDialog({
    super.key, 
    required this.store,
    this.connection
  });
  final SshConnection? connection;
  final SshConnectionStore store;
  static Future<bool?> show(BuildContext context, {
    required SshConnectionStore store,
    SshConnection? connection
  }){
    return context.blueDialog<bool>(
        title: Text(context.tr(connection == null
            ? 'ssh.newConnection'
            : 'ssh.editConnection')),
        icon: Icon(connection == null ? Icons.add_rounded : Icons.edit_outlined),
        child: SshConnectionDialog(
          store: store,
          connection: connection,
        )
    );
  }

  @override
  State<SshConnectionDialog> createState() => _SshConnectionDialogState();
}

class _SshConnectionDialogState extends State<SshConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final connection = widget.connection;
    _id = connection?.id ?? SshConnection.newId();
    _name = TextEditingController(text: connection?.name ?? '');
    _host = TextEditingController(text: connection?.host ?? '');
    _port = TextEditingController(text: '${connection?.port ?? 22}');
    _username = TextEditingController(text: connection?.username ?? '');
  }


  bool get _canReusePassword {
    final saved = widget.connection;
    return saved != null &&
        _host.text.trim().toLowerCase() == saved.host.toLowerCase() &&
        int.tryParse(_port.text.trim()) == saved.port &&
        _username.text.trim() == saved.username;
  }
  String? get _formPassword => _password.text.isEmpty && widget.connection != null
          ? null
          : _password.text;

  void _save() async{
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final host = _host.text.trim();
    final username = _username.text.trim();
    final newConnection = SshConnection(
      id: _id,
      name: _name.text.trim().isEmpty ? '$username@$host' : _name.text.trim(),
      host: host,
      port: int.parse(_port.text.trim()),
      username: username,
      password: _formPassword??"",
    );
    var res = await widget.store.save(newConnection);

    if(res == true){
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('ssh.connectionName'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              enabled: !_saving,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('ssh.host'),
                hintText: context.tr('ssh.hostHint'),
              ),
              validator: (value) =>
              value == null ||
                  value.trim().isEmpty ||
                  RegExp(r'\s').hasMatch(value.trim())
                  ? context.tr('ssh.invalidHost')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('global.port'),
              ),
              validator: (value) {
                final port = int.tryParse(value?.trim() ?? '');
                return port == null || port < 1 || port > 65535
                    ? context.tr('ssh.invalidPort')
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              enabled: !_saving,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('ssh.username'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('ssh.usernameRequired')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              validator: (value) =>
              widget.connection != null &&
                  (value?.isEmpty ?? true) &&
                  !_canReusePassword
                  ? context.tr('ssh.passwordRequired')
                  : null,
              enabled: !_saving,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('ssh.password'),
                helperText: widget.connection == null
                    ? null
                    : context.tr('ssh.savedPasswordHint'),
                suffixIcon: IconButton(
                  tooltip: _showPassword
                      ? context.tr('ssh.hidePassword')
                      : context.tr('ssh.showPassword'),
                  onPressed: _saving
                      ? null
                      : () => setState(
                        () => _showPassword = !_showPassword,
                  ),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(context.tr('global.cancel')),
                ),
                FilledButton.icon(
                  // onPressed: !busy && state.isReady ? _save : null,
                  onPressed: !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? context.tr('global.saving') : context.tr('global.save'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );

  }
}
