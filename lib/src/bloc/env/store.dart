import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'env_model.dart';

final _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  mOptions: MacOsOptions(
    accountName: 'Blue Terminal',
    label: 'Blue Terminal Environments',
    usesDataProtectionKeychain: false,
  ),
);
class EnvStore {
  const EnvStore({FlutterSecureStorage? storage});

  static const _listKey = 'blue_terminal.environments.v1';
  static const _selectedKey = 'blue_terminal.environments.selected.v1';

  Future<List<EnvModel>> list() async {
    final value = await _storage.read(key: _listKey);
    if (value == null) return const [];
    final json = jsonDecode(value);
    if (json is! List) {
      return [];
    }
    final environments = json.map(EnvModel.fromJson).toList();
    final ids = <String>{};
    final names = <String>{};
    for (final env in environments) {
      if (!ids.add(env.id) || !names.add(env.name.toLowerCase())) {
        continue;
      }
    }
    return List<EnvModel>.unmodifiable(environments);
  }

  Future<void> _writeList(List<EnvModel> environments) => _storage.write(
    key: _listKey,
    value: jsonEncode(environments.map((env) => env.toJson()).toList()),
  );

  Future<String?> getSelected() => _storage.read(key: _selectedKey);

  Future<void> select(EnvModel env) => _storage.write(key: _selectedKey, value: env.id);

  Future<String?> add(EnvModel env) async {
    final environments = await list();
    if (!env.isValid || environments.any((item) => item.id == env.id)) {
      return 'setting.invalidEnvironment';
    }
    if (environments.any(
      (item) => item.name.trim().toLowerCase() == env.name.trim().toLowerCase(),
    )) {
      return 'setting.environmentNameExists';
    }
    await _writeList([...environments, env]);
    return null;
  }

  Future<String?> update(EnvModel env) async {
    final environments = await list();
    if (!env.isValid || !environments.any((item) => item.id == env.id)) {
      return 'setting.invalidEnvironment';
    }
    if (environments.any((item) =>
        item.id != env.id &&
        item.name.trim().toLowerCase() == env.name.trim().toLowerCase())) {
      return 'setting.environmentNameExists';
    }
    await _writeList([
      for (final item in environments) item.id == env.id ? env : item,
    ]);
    return null;
  }

  Future<void> delete(EnvModel env) async {
    final environments = await list();
    await _writeList(environments.where((item) => item.id != env.id).toList());
    if (await getSelected() == env.id) {
      await _storage.delete(key: _selectedKey);
    }
  }
}
const  envStore = EnvStore();
