import '../data/local/settings_local_data_source.dart';
import '../models/chat_settings.dart';

class SettingsService {
  SettingsService({required SettingsLocalDataSource settingsDataSource})
    : _settingsDataSource = settingsDataSource;

  final SettingsLocalDataSource _settingsDataSource;

  Future<ChatSettings> loadSettings() {
    return _settingsDataSource.loadSettings();
  }

  Future<void> saveSettings(ChatSettings settings) {
    return _settingsDataSource.saveSettings(settings);
  }
}
