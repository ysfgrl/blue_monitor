import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LanguageStore {
  LanguageStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'blue_terminal.language.v1';
  static const legacySettingsKey = 'blue_terminal.settings.v1';
  final SharedPreferencesAsync _preferences;

  Future<String> load() async {
    final languageCode = await _preferences.getString(_key);
    if (languageCode != null) return languageCode == 'en' ? 'en' : 'tr';

    final legacyValue = await _preferences.getString(legacySettingsKey);
    if (legacyValue == null) {
      final migratedCode = await _preferences.getString(_key);
      return migratedCode == 'en' ? 'en' : 'tr';
    }
    final json = jsonDecode(legacyValue);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('setting.invalidRecord');
    }
    final migratedCode = json['languageCode'] == 'en' ? 'en' : 'tr';
    await save(migratedCode);
    return migratedCode;
  }

  Future<void> save(String languageCode) {
    if (languageCode != 'tr' && languageCode != 'en') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    return _preferences.setString(_key, languageCode);
  }
}
