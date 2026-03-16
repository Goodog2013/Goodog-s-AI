import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../../models/chat_workspace.dart';

class ChatWorkspaceLocalDataSource {
  ChatWorkspaceLocalDataSource({required SharedPreferences preferences})
    : _preferences = preferences;

  static const _workspaceKey = 'chat_workspace_v2';
  static const _legacyHistoryKey = 'chat_history_v1';

  final SharedPreferences _preferences;

  Future<ChatWorkspace> loadWorkspace() async {
    final rawWorkspace = _preferences.getString(_workspaceKey);
    if (rawWorkspace != null && rawWorkspace.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawWorkspace);
        if (decoded is Map<String, dynamic>) {
          return ChatWorkspace.fromJson(decoded);
        }
      } on FormatException {
        return ChatWorkspace.initial();
      }
    }

    final legacyMessages = _loadLegacyMessages();
    if (legacyMessages.isNotEmpty) {
      final migratedThread = ChatThread.create(
        title: 'Основной чат',
      ).copyWith(messages: legacyMessages, updatedAt: DateTime.now());
      final migrated = ChatWorkspace(
        folders: const [],
        threads: <ChatThread>[migratedThread],
        activeThreadId: migratedThread.id,
        selectedFolderId: null,
      );
      await saveWorkspace(migrated);
      await _preferences.remove(_legacyHistoryKey);
      return migrated;
    }

    return ChatWorkspace.initial();
  }

  Future<void> saveWorkspace(ChatWorkspace workspace) async {
    final encoded = jsonEncode(workspace.toJson());
    await _preferences.setString(_workspaceKey, encoded);
  }

  List<ChatMessage> _loadLegacyMessages() {
    final rawHistory = _preferences.getString(_legacyHistoryKey);
    if (rawHistory == null || rawHistory.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawHistory);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => ChatMessage.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}
