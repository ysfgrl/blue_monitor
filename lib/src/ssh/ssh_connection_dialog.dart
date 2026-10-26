import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ssh_bloc/ssh_bloc.dart';
import '../models/ssh_connection.dart';

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

  SshBloc get _bloc => context.read<SshBloc>();

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
    );
  }

  String? get _formPassword =>
      _password.text.isEmpty && widget.connection != null
      ? null
      : _password.text;

  void _test() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _tested = true);
    _bloc.add(
      SshConnectRequested(
        _connection(),
        password: _formPassword,
        testOnly: true,
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    _bloc.add(SshConnectionSaved(_connection(), password: _formPassword));
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
  Widget build(BuildContext context) => BlocConsumer<SshBloc, SshState>(
    listener: (context, state) {
      if (!_saving) return;
      if (state.lastSavedConnection?.id == _id) {
        _saving = false;
        Navigator.of(context).pop();
      } else if (state.profileError != null) {
        setState(() => _saving = false);
      }
    },
    builder: (context, state) {
      final busy = _saving || state.profilesBusy || state.isConnecting;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(
            widget.connection == null
                ? 'Yeni SSH bağlantısı'
                : 'Bağlantıyı düzenle',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                onChanged: () {
                  if (_tested && !state.isConnecting) {
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
                      decoration: const InputDecoration(
                        labelText: 'Bağlantı adı (isteğe bağlı)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _host,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Sunucu',
                        hintText: '192.168.1.10 veya sunucu adresi',
                      ),
                      validator: (value) =>
                          value == null ||
                              value.trim().isEmpty ||
                              RegExp(r'\s').hasMatch(value.trim())
                          ? 'Geçerli bir sunucu adresi girin.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _port,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Port'),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        return port == null || port < 1 || port > 65535
                            ? 'Port 1–65535 arasında olmalı.'
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
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı adı',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Kullanıcı adı girin.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        helperText: widget.connection == null
                            ? null
                            : 'Boş bırakırsanız kayıtlı şifre kullanılır.',
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Şifreyi gizle'
                              : 'Şifreyi göster',
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
                    if (_tested && state.message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.message!,
                        style: TextStyle(
                          color: state.hasError
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                    if (state.profileError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.profileError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _test,
                      icon: state.isConnecting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                      label: Text(
                        state.isConnecting
                            ? 'Bağlantı test ediliyor…'
                            : 'Bağlantıyı test et',
                      ),
                    ),
                    if (state.isConnecting)
                      TextButton(
                        onPressed: () =>
                            _bloc.add(const SshDisconnectRequested()),
                        child: const Text('Testi iptal et'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: !busy && state.profilesReady ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ],
        ),
      );
    },
  );
}
