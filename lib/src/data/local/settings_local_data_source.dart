import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_settings.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource({required SharedPreferences preferences})
    : _preferences = preferences;

  static const _settingsKey = 'chat_settings_v1';
  final SharedPreferences _preferences;

  Future<ChatSettings> loadSettings() async {
    final rawJson = _preferences.getString(_settingsKey);
    if (rawJson == null || rawJson.isEmpty) {
      return ChatSettings.defaults();
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return ChatSettings.fromJson(decoded);
      }
      return ChatSettings.defaults();
    } on FormatException {
      return ChatSettings.defaults();
    }
  }

  Future<void> saveSettings(ChatSettings settings) async {
    final encoded = jsonEncode(settings.toJson());
    await _preferences.setString(_settingsKey, encoded);
  }
}
