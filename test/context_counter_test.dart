import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goodogs_chat/src/application/chat_service.dart';
import 'package:goodogs_chat/src/application/settings_service.dart';
import 'package:goodogs_chat/src/data/local/chat_workspace_local_data_source.dart';
import 'package:goodogs_chat/src/data/local/settings_local_data_source.dart';
import 'package:goodogs_chat/src/data/remote/lm_studio_api_client.dart';
import 'package:goodogs_chat/src/models/chat_message.dart';
import 'package:goodogs_chat/src/models/chat_settings.dart';
import 'package:goodogs_chat/src/presentation/controllers/chat_controller.dart';

class _FakeLmStudioApiClient extends LmStudioApiClient {
  _FakeLmStudioApiClient();

  int _replyIndex = 0;

  @override
  Future<String> createChatCompletion({
    required ChatSettings settings,
    required List<ChatMessage> messages,
  }) async {
    _replyIndex += 1;
    return 'Ответ $_replyIndex';
  }
}

Future<ChatController> _buildController() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final settingsDataSource = SettingsLocalDataSource(preferences: prefs);
  final workspaceDataSource = ChatWorkspaceLocalDataSource(preferences: prefs);
  final settingsService = SettingsService(
    settingsDataSource: settingsDataSource,
  );
  final chatService = ChatService(
    apiClient: _FakeLmStudioApiClient(),
    workspaceDataSource: workspaceDataSource,
  );
  final controller = ChatController(
    chatService: chatService,
    settingsService: settingsService,
  );
  await controller.initialize();
  return controller;
}

void main() {
  test('manual context increments, blocks, and resets correctly', () async {
    final controller = await _buildController();
    addTearDown(controller.dispose);

    expect(controller.autoContextRefreshEnabled, isFalse);
    expect(controller.activeContextMessagesCount, 0);
    expect(controller.limits.maxContextMessages, 5);

    for (var i = 1; i <= 5; i++) {
      final error = await controller.sendMessage('Сообщение $i');
      expect(error, isNull);
      expect(controller.activeContextMessagesCount, i);
    }

    final overflowError = await controller.sendMessage('Сообщение 6');
    expect(overflowError, isNotNull);
    expect(controller.activeContextMessagesCount, 5);

    await controller.refreshContextForActiveThread();
    expect(controller.activeContextMessagesCount, 0);

    final afterResetError = await controller.sendMessage('После сброса');
    expect(afterResetError, isNull);
    expect(controller.activeContextMessagesCount, 1);
  });
}
