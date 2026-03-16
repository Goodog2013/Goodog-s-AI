import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/application/chat_service.dart';
import 'src/application/settings_service.dart';
import 'src/data/local/chat_workspace_local_data_source.dart';
import 'src/data/local/settings_local_data_source.dart';
import 'src/data/remote/lm_studio_api_client.dart';
import 'src/data/remote/web_search_client.dart';
import 'src/presentation/controllers/chat_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: "Goodog's AI",
      center: true,
      size: Size(1240, 840),
      minimumSize: Size(900, 620),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.transparent,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final preferences = await SharedPreferences.getInstance();
  final settingsDataSource = SettingsLocalDataSource(preferences: preferences);
  final workspaceDataSource = ChatWorkspaceLocalDataSource(
    preferences: preferences,
  );
  final apiClient = LmStudioApiClient();
  final webSearchClient = WebSearchClient();

  final settingsService = SettingsService(
    settingsDataSource: settingsDataSource,
  );
  final chatService = ChatService(
    apiClient: apiClient,
    workspaceDataSource: workspaceDataSource,
    webSearchClient: webSearchClient,
  );

  final chatController = ChatController(
    chatService: chatService,
    settingsService: settingsService,
  );

  runApp(GoodogsChatApp(chatController: chatController));
}
