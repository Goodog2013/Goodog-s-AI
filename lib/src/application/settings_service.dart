import 'dart:math';

import '../data/local/settings_local_data_source.dart';
import '../models/chat_settings.dart';

class SettingsService {
  SettingsService({required SettingsLocalDataSource settingsDataSource})
    : _settingsDataSource = settingsDataSource;

  final SettingsLocalDataSource _settingsDataSource;
  final Random _random = Random.secure();

  Future<ChatSettings> loadSettings() {
    return _settingsDataSource.loadSettings();
  }

  Future<void> saveSettings(ChatSettings settings) {
    return _settingsDataSource.saveSettings(settings);
  }

  Future<ChatSettings> ensureProfileIdentity(ChatSettings settings) async {
    var changed = false;
    var nextSettings = settings;

    if (settings.profileId.trim().isEmpty) {
      changed = true;
      nextSettings = nextSettings.copyWith(profileId: _generateProfileId());
    }
    if (settings.profileName.trim().isEmpty) {
      changed = true;
      nextSettings = nextSettings.copyWith(
        profileName: ChatSettings.defaultProfileName,
      );
    }

    if (changed) {
      await saveSettings(nextSettings);
    }
    return nextSettings;
  }

  String _generateProfileId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(899999) + 100000;
    return 'u_$millis$suffix';
  }
}
