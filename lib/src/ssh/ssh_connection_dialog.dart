import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ssh/ssh_list_bloc.dart';
import '../bloc/ssh/connection/ssh_connection_bloc.dart';
import '../models/ssh_connection.dart';
import 'ssh_host_key_listener.dart';

class SshConnectionDialog extends StatefulWidget {
  const SshConnectionDialog({super.key, this.connection});
  final SshConnection? connection;
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
  bool _tested = false;

  SshListBloc get _bloc => context.read<SshListBloc>();
  SshConnectionBloc? _testBloc;

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

  SshConnection _connection() {
    final host = _host.text.trim();
    final username = _username.text.trim();
    return SshConnection(
      id: _id,
      name: _name.text.trim().isEmpty ? '$username@$host' : _name.text.trim(),
      host: host,
      port: int.parse(_port.text.trim()),
      username: username,
      password: _password.text.isEmpty && _canReusePassword
          ? widget.connection!.password
          : _password.text,
    );
  }

  bool get _canReusePassword {
    final saved = widget.connection;
    return saved != null &&
        _host.text.trim().toLowerCase() == saved.host.toLowerCase() &&
        int.tryParse(_port.text.trim()) == saved.port &&
        _username.text.trim() == saved.username;
  }

  void _test() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final previous = _testBloc;
    final bloc = SshConnectionBloc(connection: _connection());
    setState(() {
      _tested = true;
      _testBloc = bloc;
    });
    if (previous != null) unawaited(previous.close());
    bloc.add(const SshConnectRequested(testOnly: true));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    // _bloc.add(SshConnectionSaved(_connection()));
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    final bloc = _testBloc;
    if (bloc != null) unawaited(bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<SshListBloc, SshListState>(
    listener: (context, state) {
      // if (!_saving) return;
      // if (state.lastSavedConnection?.id == _id) {
      //   _saving = false;
      //   Navigator.of(context).pop();
      // } else if (state.error != null) {
      //   setState(() => _saving = false);
      // }
    },
    builder: (context, state) {
      final bloc = _testBloc;
      if (bloc == null) {
        return _buildDialog(context, state, null);
      }
      return BlocProvider<SshConnectionBloc>.value(
        key: ObjectKey(bloc),
        value: bloc,
        child: SshHostKeyListener(
          child: BlocBuilder<SshConnectionBloc, SshConnectionState>(
            builder: (context, connectionState) =>
                _buildDialog(context, state, connectionState),
          ),
        ),
      );
    },
  );

  Widget _buildDialog(
    BuildContext context,
    SshListState state,
    SshConnectionState? connectionState,
  ) {
    final isConnecting = connectionState?.isConnecting ?? false;
    final testMessage = connectionState?.message;
    // final busy = _saving || state.isBusy || isConnecting;
    final busy = _saving ||  isConnecting;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          widget.connection == null
              ? context.tr('ssh.newConnection')
              : context.tr('ssh.editConnection'),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              onChanged: () {
                if (_tested && !isConnecting) {
                  setState(() => _tested = false);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('ssh.connectionName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _host,
                    enabled: !busy,
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
                    enabled: !busy,
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
                    enabled: !busy,
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
                    enabled: !busy,
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
                        onPressed: busy
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
                  if (_tested && testMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      testMessage,
                      style: TextStyle(
                        color: (connectionState?.hasError ?? false)
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _test,
                    icon: isConnecting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded),
                    label: Text(
                      isConnecting
                          ? context.tr('ssh.testingConnection')
                          : context.tr('ssh.testConnection'),
                    ),
                  ),
                  if (isConnecting)
                    TextButton(
                      onPressed: () =>
                          _testBloc?.add(const SshDisconnectRequested()),
                      child: Text(context.tr('ssh.cancelTest')),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('global.cancel')),
          ),
          FilledButton.icon(
            // onPressed: !busy && state.isReady ? _save : null,
            onPressed: !busy ? _save : null,
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
      ),
    );
  }
}
