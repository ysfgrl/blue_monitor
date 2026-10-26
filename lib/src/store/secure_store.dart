import 'package:flutter_secure_storage/flutter_secure_storage.dart';
final secureStore = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    // This app does not share Keychain items with other applications.
    mOptions: MacOsOptions(
    accountName: "Blue Terminal",
    label: "Blue Terminal SSH",
    usesDataProtectionKeychain: false,
    ),
);