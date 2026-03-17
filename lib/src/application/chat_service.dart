import '../data/local/chat_workspace_local_data_source.dart';
import '../data/remote/lan_gateway_client.dart';
import '../data/remote/lm_studio_api_client.dart';
import '../data/remote/web_search_client.dart';
import '../models/app_language.dart';
import '../models/chat_message.dart';
import '../models/chat_settings.dart';
import '../models/chat_workspace.dart';
import '../models/user_profile.dart';
import '../models/web_search_result.dart';
import 'web_intent_parser.dart';

class ChatService {
  ChatService({
    required LmStudioApiClient apiClient,
    required ChatWorkspaceLocalDataSource workspaceDataSource,
    WebSearchClient? webSearchClient,
    LanGatewayClient? lanGatewayClient,
  }) : _apiClient = apiClient,
       _workspaceDataSource = workspaceDataSource,
       _webSearchClient = webSearchClient ?? WebSearchClient(),
       _lanGatewayClient = lanGatewayClient ?? LanGatewayClient();

  final LmStudioApiClient _apiClient;
  final ChatWorkspaceLocalDataSource _workspaceDataSource;
  final WebSearchClient _webSearchClient;
  final LanGatewayClient _lanGatewayClient;

  Future<ChatWorkspace> loadWorkspace() {
    return _workspaceDataSource.loadWorkspace();
  }

  Future<void> saveWorkspace(ChatWorkspace workspace) {
    return _workspaceDataSource.saveWorkspace(workspace);
  }

  Future<UserProfile> syncProfile({required ChatSettings settings}) async {
    final profileId = settings.profileId.trim();
    final profileName = settings.profileName.trim();
    final localProfile = UserProfile.initial(
      id: profileId.isEmpty ? 'local_user' : profileId,
      name: profileName.isEmpty ? ChatSettings.defaultProfileName : profileName,
    );

    if (!settings.lanGatewayEnabled) {
      return localProfile;
    }

    try {
      return await _lanGatewayClient.syncProfile(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
        profileId: localProfile.id,
        profileName: localProfile.displayName,
      );
    } on LanGatewayException catch (error) {
      if (error.isCancelled) {
        throw const ChatApiException(
          LmStudioApiClient.cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw ChatApiException(error.message);
    }
  }

  Future<AssistantReplyResult> getAssistantReply({
    required ChatSettings settings,
    required UserProfile profile,
    required List<ChatMessage> conversation,
    List<ChatMessage>? fixedContext,
  }) async {
    if (profile.isBanned) {
      throw const ChatApiException('Ваш профиль заблокирован администратором.');
    }

    final prompt = settings.systemPrompt.trim();
    final latestUserInput = _latestUserMessage(conversation);
    final answerLanguage = AppLanguage.byCode(
      settings.languageCode,
    ).englishName;
    final shouldUseWebByIntent =
        settings.webSearchEnabled &&
        latestUserInput != null &&
        WebIntentParser.requestsWeb(latestUserInput);
    final webContext = shouldUseWebByIntent
        ? await _buildWebContext(settings: settings, userQuery: latestUserInput)
        : null;

    final contextMessages = _buildContextMessages(
      conversation: conversation,
      fixedContext: fixedContext,
      maxContextMessages: profile.limits.maxContextMessages,
      autoContextRefresh: profile.limits.autoContextRefresh,
    );

    final baseSystemMessages = <ChatMessage>[
      if (prompt.isNotEmpty) ChatMessage.system(prompt),
      ChatMessage.system(
        'Always answer in $answerLanguage unless the user explicitly asks for another language.',
      ),
      if (settings.webSearchEnabled)
        ChatMessage.system(_noHallucinationInstruction),
    ];

    final requestMessages = <ChatMessage>[
      ...baseSystemMessages,
      if (shouldUseWebByIntent) ChatMessage.system(_webModeInstruction),
      if (webContext != null) ChatMessage.system(webContext),
      ...contextMessages,
    ];

    String firstAssistantText;
    UserProfile nextProfile = profile;
    if (settings.lanGatewayEnabled) {
      final gatewayResult = await _lanGatewayRequest(
        settings: settings,
        profile: profile,
        messages: requestMessages,
      );
      firstAssistantText = gatewayResult.reply;
      nextProfile = gatewayResult.profile;
    } else {
      firstAssistantText = await _apiClient.createChatCompletion(
        settings: settings,
        messages: requestMessages,
      );
    }

    if (!settings.webSearchEnabled || latestUserInput == null) {
      return AssistantReplyResult(
        message: ChatMessage.assistant(firstAssistantText),
        profile: nextProfile,
        contextMessages: contextMessages,
      );
    }

    final shouldRetryWithWeb =
        !shouldUseWebByIntent && _needsWebFallback(firstAssistantText);
    if (!shouldRetryWithWeb) {
      return AssistantReplyResult(
        message: ChatMessage.assistant(firstAssistantText),
        profile: nextProfile,
        contextMessages: contextMessages,
      );
    }

    final fallbackWebContext = await _buildWebContext(
      settings: settings,
      userQuery: latestUserInput,
    );
    final retryMessages = <ChatMessage>[
      ...baseSystemMessages,
      ChatMessage.system(_webModeInstruction),
      ChatMessage.system(_webFallbackInstruction),
      if (fallbackWebContext != null) ChatMessage.system(fallbackWebContext),
      ...contextMessages,
    ];

    if (settings.lanGatewayEnabled) {
      final gatewayResult = await _lanGatewayRequest(
        settings: settings,
        profile: nextProfile,
        messages: retryMessages,
      );
      return AssistantReplyResult(
        message: ChatMessage.assistant(gatewayResult.reply),
        profile: gatewayResult.profile,
        contextMessages: contextMessages,
      );
    }

    final secondAssistantText = await _apiClient.createChatCompletion(
      settings: settings,
      messages: retryMessages,
    );
    return AssistantReplyResult(
      message: ChatMessage.assistant(secondAssistantText),
      profile: nextProfile,
      contextMessages: contextMessages,
    );
  }

  Future<GatewayChatResult> _lanGatewayRequest({
    required ChatSettings settings,
    required UserProfile profile,
    required List<ChatMessage> messages,
  }) async {
    try {
      return await _lanGatewayClient.requestChat(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
        profileId: profile.id,
        profileName: profile.displayName,
        model: settings.model,
        temperature: settings.temperature,
        messages: messages,
      );
    } on LanGatewayException catch (error) {
      if (error.isCancelled) {
        throw const ChatApiException(
          LmStudioApiClient.cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw ChatApiException(error.message);
    }
  }

  List<ChatMessage> _buildContextMessages({
    required List<ChatMessage> conversation,
    required int maxContextMessages,
    required bool autoContextRefresh,
    List<ChatMessage>? fixedContext,
  }) {
    final source = autoContextRefresh && fixedContext == null
        ? conversation
        : (fixedContext ?? conversation);
    final nonSystem = source
        .where((m) => m.role != ChatRole.system)
        .toList(growable: false);
    if (nonSystem.length <= maxContextMessages) {
      return nonSystem;
    }
    return nonSystem
        .sublist(nonSystem.length - maxContextMessages, nonSystem.length)
        .toList(growable: false);
  }

  void cancelActiveReply() {
    _apiClient.cancelActiveRequest();
    _lanGatewayClient.cancelActiveRequest();
  }

  void dispose() {
    _apiClient.dispose();
    _webSearchClient.dispose();
    _lanGatewayClient.dispose();
  }

  Future<String?> _buildWebContext({
    required ChatSettings settings,
    required String userQuery,
  }) async {
    if (!settings.webSearchEnabled) {
      return null;
    }

    final normalizedUserQuery = userQuery.trim();
    if (normalizedUserQuery.length < 3) {
      return null;
    }

    final containsUrl = WebIntentParser.containsUrl(normalizedUserQuery);
    final collected = <WebSearchResult>[];
    final seenUrls = <String>{};
    var urlDataLoaded = false;
    var searchDataLoaded = false;
    String? searchErrorMessage;
    String? searchQuery;

    if (containsUrl) {
      try {
        final directPreview = await _webSearchClient.fetchPagePreview(
          normalizedUserQuery,
        );
        if (directPreview != null && !seenUrls.contains(directPreview.url)) {
          collected.add(directPreview);
          seenUrls.add(directPreview.url);
          urlDataLoaded = !directPreview.isError;
        }
      } on WebSearchException {
        // Keep formatted status for failed URL fetch.
      }
    } else {
      searchQuery = WebIntentParser.buildSearchQuery(normalizedUserQuery);
      try {
        final searchResults = await _webSearchClient.search(
          query: searchQuery,
          maxResults: settings.webSearchMaxResults,
        );
        for (final item in searchResults) {
          if (!seenUrls.contains(item.url)) {
            collected.add(item);
            seenUrls.add(item.url);
          }
        }
        searchDataLoaded = collected.isNotEmpty;
      } on WebSearchException catch (error) {
        searchErrorMessage = error.message;
      }
    }

    return _formatWebContext(
      results: collected,
      containsUrl: containsUrl,
      urlDataLoaded: urlDataLoaded,
      searchQuery: searchQuery,
      searchDataLoaded: searchDataLoaded,
      searchErrorMessage: searchErrorMessage,
    );
  }

  String? _latestUserMessage(List<ChatMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role == ChatRole.user) {
        final text = message.content.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  String _formatWebContext({
    required List<WebSearchResult> results,
    required bool containsUrl,
    required bool urlDataLoaded,
    String? searchQuery,
    required bool searchDataLoaded,
    String? searchErrorMessage,
  }) {
    final now = DateTime.now();
    final date = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
    final buffer = StringBuffer();

    buffer.writeln('Контекст из интернета (дата: $date).');
    buffer.writeln(
      'У тебя есть доступ к интернет-данным через этот блок. Используй источники ниже как фактическую базу для ответа.',
    );
    buffer.writeln(
      'Если источники противоречивы, укажи это прямо и приведи ссылки.',
    );
    buffer.writeln(
      'Отвечай только на основе этого контекста. Если данных недостаточно, прямо скажи об этом и не выдумывай.',
    );
    buffer.writeln(
      'Если внутри источника есть блоки URL/TITLE/CONTENT или URL/ERROR, считай их реальными результатами веб-инструмента.',
    );

    if (containsUrl) {
      if (urlDataLoaded) {
        buffer.writeln('Статус ссылки: данные по URL успешно получены.');
      } else {
        buffer.writeln('Статус ссылки: получить данные по URL не удалось.');
        buffer.writeln(
          'В этом случае нельзя угадывать содержимое страницы. Скажи пользователю, что нужно повторить запрос позже или дать дополнительный текст.',
        );
      }
    } else {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        buffer.writeln('Запрос веб-поиска: $searchQuery');
      }
      if (searchDataLoaded) {
        buffer.writeln('Статус веб-поиска: результаты успешно получены.');
      } else if (searchErrorMessage != null && searchErrorMessage.isNotEmpty) {
        buffer.writeln('Статус веб-поиска: ошибка получения данных.');
        buffer.writeln('Ошибка: $searchErrorMessage');
      } else {
        buffer.writeln('Статус веб-поиска: источники не найдены.');
      }
    }

    if (results.isEmpty) {
      return buffer.toString().trim();
    }

    for (var i = 0; i < results.length; i++) {
      final item = results[i];
      buffer.writeln('${i + 1}) ${item.title}');
      if (item.snippet.isNotEmpty) {
        buffer.writeln('Фрагмент: ${item.snippet}');
      }
      if (item.isError) {
        buffer.writeln('Статус источника: ошибка получения данных.');
      }
      buffer.writeln('Источник: ${item.url}');
    }

    return buffer.toString().trim();
  }

  String _twoDigits(int value) {
    if (value < 10) {
      return '0$value';
    }
    return value.toString();
  }

  static const String _webModeInstruction =
      'Режим веб-доступа включен по запросу пользователя (ссылка или явная команда посмотреть в интернете). '
      'У тебя есть доступ к интернет-данным через блок "Контекст из интернета". '
      'Отвечай строго по этому блоку, не придумывай факты, не заявляй, что интернета нет, '
      'и при наличии URL/TITLE/CONTENT используй их как единственный источник о ссылке или веб-запросе.';

  static const String _webFallbackInstruction =
      'Предыдущий ответ был недостаточно уверенным. Сформируй новый финальный ответ только на основе веб-контекста. '
      'Если данных все равно не хватает, прямо укажи это без импровизации.';

  static const String _noHallucinationInstruction =
      'Если не знаешь фактический ответ или не можешь его проверить, не импровизируй. '
      'Начни ответ с маркера [[WEB_FALLBACK]] и кратко укажи, каких данных не хватает.';

  bool _needsWebFallback(String assistantText) {
    final normalized = assistantText.toLowerCase().replaceAll('ё', 'е').trim();
    if (normalized.isEmpty) {
      return true;
    }
    if (normalized.contains('[[web_fallback]]')) {
      return true;
    }

    for (final signal in _fallbackSignals) {
      if (normalized.contains(signal)) {
        return true;
      }
    }
    return false;
  }

  static const List<String> _fallbackSignals = <String>[
    'не знаю',
    'не уверен',
    'не могу проверить',
    'не могу подтвердить',
    'нет данных',
    'недостаточно данных',
    'у меня нет доступа к интернету',
    'без доступа к интернету',
    'i do not know',
    "i don't know",
    'not sure',
    'cannot verify',
    'no data',
    'no access to internet',
    'need web access',
  ];
}

class AssistantReplyResult {
  const AssistantReplyResult({
    required this.message,
    required this.profile,
    required this.contextMessages,
  });

  final ChatMessage message;
  final UserProfile profile;
  final List<ChatMessage> contextMessages;
}
