import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goodogs_chat/src/application/chat_service.dart';
import 'package:goodogs_chat/src/data/local/chat_workspace_local_data_source.dart';
import 'package:goodogs_chat/src/data/remote/lm_studio_api_client.dart';
import 'package:goodogs_chat/src/data/remote/web_search_client.dart';
import 'package:goodogs_chat/src/models/chat_message.dart';
import 'package:goodogs_chat/src/models/chat_settings.dart';
import 'package:goodogs_chat/src/models/user_profile.dart';
import 'package:goodogs_chat/src/models/web_search_result.dart';

class _CountingApiClient extends LmStudioApiClient {
  _CountingApiClient({required this.reply});

  final String reply;
  int callCount = 0;

  @override
  Future<String> createChatCompletion({
    required ChatSettings settings,
    required List<ChatMessage> messages,
  }) async {
    callCount += 1;
    return reply;
  }
}

class _FakeWebSearchClient extends WebSearchClient {
  _FakeWebSearchClient({this.previewResult});

  final WebSearchResult? previewResult;

  @override
  Future<WebSearchResult?> fetchPagePreview(String rawText) async {
    return previewResult;
  }

  @override
  Future<List<WebSearchResult>> search({
    required String query,
    int maxResults = 4,
  }) async {
    return const <WebSearchResult>[];
  }
}

Future<ChatService> _buildService({
  required _CountingApiClient apiClient,
  required _FakeWebSearchClient webSearchClient,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final workspaceDataSource = ChatWorkspaceLocalDataSource(preferences: prefs);
  return ChatService(
    apiClient: apiClient,
    workspaceDataSource: workspaceDataSource,
    webSearchClient: webSearchClient,
  );
}

void main() {
  test(
    'URL mode returns deterministic web summary and bypasses model',
    () async {
      final api = _CountingApiClient(reply: 'Галлюцинация без источников');
      final webClient = _FakeWebSearchClient(
        previewResult: const WebSearchResult(
          title: 'How I Obtained /OP In Survival Minecraft',
          url: 'https://www.youtube.com/watch?v=Pc-iuAIJH5c',
          snippet:
              'URL: https://www.youtube.com/watch?v=Pc-iuAIJH5c\n'
              'TITLE: How I Obtained /OP In Survival Minecraft\n'
              'CONTENT:\nКанал: DragonMC. Источник: YouTube oEmbed.',
        ),
      );
      final service = await _buildService(
        apiClient: api,
        webSearchClient: webClient,
      );
      final settings = ChatSettings.defaults().copyWith(webSearchEnabled: true);
      final profile = UserProfile.initial(id: 'u1', name: 'Тест');
      final conversation = <ChatMessage>[
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content:
              'https://www.youtube.com/watch?v=Pc-iuAIJH5c что это за видео',
          createdAt: DateTime(2026, 3, 17),
        ),
      ];

      final result = await service.getAssistantReply(
        settings: settings,
        profile: profile,
        conversation: conversation,
      );

      expect(api.callCount, 0);
      expect(
        result.message.content,
        contains('Проверил ссылку по реальным веб-данным.'),
      );
      expect(
        result.message.content,
        contains('How I Obtained /OP In Survival Minecraft'),
      );
      expect(result.message.content, contains('без домыслов'));
    },
  );

  test('URL mode with failed fetch returns strict no-data message', () async {
    final api = _CountingApiClient(reply: 'Галлюцинация без источников');
    final webClient = _FakeWebSearchClient(
      previewResult: const WebSearchResult(
        title: 'Ошибка загрузки страницы',
        url: 'https://example.com',
        snippet: 'URL: https://example.com\nERROR: Сайт вернул HTTP 403.',
        isError: true,
      ),
    );
    final service = await _buildService(
      apiClient: api,
      webSearchClient: webClient,
    );
    final settings = ChatSettings.defaults().copyWith(webSearchEnabled: true);
    final profile = UserProfile.initial(id: 'u2', name: 'Тест');
    final conversation = <ChatMessage>[
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        content: 'https://example.com что там',
        createdAt: DateTime(2026, 3, 17),
      ),
    ];

    final result = await service.getAssistantReply(
      settings: settings,
      profile: profile,
      conversation: conversation,
    );

    expect(api.callCount, 0);
    expect(result.message.content, contains('Не удалось открыть ссылку'));
    expect(result.message.content, contains('Я не буду импровизировать'));
  });
}
