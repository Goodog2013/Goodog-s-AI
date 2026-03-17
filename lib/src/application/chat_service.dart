import '../data/local/chat_workspace_local_data_source.dart';
import '../data/remote/lan_gateway_client.dart';
import '../data/remote/lm_studio_api_client.dart';
import '../data/remote/web_search_client.dart';
import '../models/app_language.dart';
import '../models/auth_account.dart';
import '../models/auth_session.dart';
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

  Future<AuthSession?> restoreAuthSession({
    required ChatSettings settings,
  }) async {
    if (!settings.lanGatewayEnabled) {
      return null;
    }
    try {
      return await _lanGatewayClient.fetchAuthSession(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
      );
    } on LanGatewayException catch (error) {
      throw ChatApiException(error.message);
    }
  }

  Future<AuthSession> register({
    required ChatSettings settings,
    required String login,
    required String password,
    required String email,
    required String name,
  }) async {
    if (!settings.lanGatewayEnabled) {
      throw const ChatApiException(
        'Регистрация доступна только через LAN-шлюз.',
      );
    }
    try {
      return await _lanGatewayClient.register(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
        login: login,
        password: password,
        email: email,
        name: name,
      );
    } on LanGatewayException catch (error) {
      throw ChatApiException(error.message);
    }
  }

  Future<AuthSession> login({
    required ChatSettings settings,
    required String login,
    required String password,
  }) async {
    if (!settings.lanGatewayEnabled) {
      throw const ChatApiException('Вход доступен только через LAN-шлюз.');
    }
    try {
      return await _lanGatewayClient.login(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
        login: login,
        password: password,
      );
    } on LanGatewayException catch (error) {
      throw ChatApiException(error.message);
    }
  }

  Future<void> logout({required ChatSettings settings}) async {
    if (!settings.lanGatewayEnabled) {
      return;
    }
    try {
      await _lanGatewayClient.logout(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
      );
    } on LanGatewayException catch (error) {
      throw ChatApiException(error.message);
    }
  }

  UserProfile localProfileFromSettings(ChatSettings settings) {
    final profileId = settings.profileId.trim();
    final profileName = settings.profileName.trim();
    return UserProfile.initial(
      id: profileId.isEmpty ? 'local_user' : profileId,
      name: profileName.isEmpty ? ChatSettings.defaultProfileName : profileName,
    );
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
    final webPayload = shouldUseWebByIntent
        ? await _buildWebContextPayload(
            settings: settings,
            userQuery: latestUserInput,
          )
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
      ChatMessage.system(
        'User name is ${profile.displayName}. Address user by this name when appropriate.',
      ),
      if (settings.webSearchEnabled)
        ChatMessage.system(_noHallucinationInstruction),
    ];

    if (shouldUseWebByIntent) {
      if (webPayload == null || !webPayload.hasReliableData) {
        return AssistantReplyResult(
          message: ChatMessage.assistant(
            _buildWebUnavailableReply(
              payload: webPayload,
              userQuery: latestUserInput,
            ),
          ),
          profile: profile,
          account: null,
          contextMessages: contextMessages,
        );
      }

      if (webPayload.containsUrl) {
        return AssistantReplyResult(
          message: ChatMessage.assistant(_buildDirectUrlReply(webPayload)),
          profile: profile,
          account: null,
          contextMessages: contextMessages,
        );
      }
    }

    final requestMessages = <ChatMessage>[
      ...baseSystemMessages,
      if (shouldUseWebByIntent) ChatMessage.system(_webModeInstruction),
      if (webPayload != null) ChatMessage.system(webPayload.context),
      ...contextMessages,
    ];

    String firstAssistantText;
    UserProfile nextProfile = profile;
    AuthAccount? nextAccount;
    if (settings.lanGatewayEnabled) {
      final gatewayResult = await _lanGatewayRequest(
        settings: settings,
        messages: requestMessages,
      );
      firstAssistantText = gatewayResult.reply;
      nextProfile = gatewayResult.profile ?? profile;
      nextAccount = gatewayResult.account;
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
        account: nextAccount,
        contextMessages: contextMessages,
      );
    }

    if (shouldUseWebByIntent) {
      final intentPayload = webPayload;
      if (intentPayload == null) {
        return AssistantReplyResult(
          message: ChatMessage.assistant(
            _buildWebUnavailableReply(
              payload: null,
              userQuery: latestUserInput,
            ),
          ),
          profile: nextProfile,
          account: nextAccount,
          contextMessages: contextMessages,
        );
      }

      final hasFallbackSignal = _needsWebFallback(firstAssistantText);
      final hasSourceUrls = _containsAnySourceUrl(
        firstAssistantText,
        intentPayload.results,
      );
      if (hasFallbackSignal || !hasSourceUrls) {
        return AssistantReplyResult(
          message: ChatMessage.assistant(
            _buildSearchResultsReply(
              payload: intentPayload,
              userQuery: latestUserInput,
            ),
          ),
          profile: nextProfile,
          account: nextAccount,
          contextMessages: contextMessages,
        );
      }
    }

    final shouldRetryWithWeb =
        !shouldUseWebByIntent && _needsWebFallback(firstAssistantText);
    if (!shouldRetryWithWeb) {
      return AssistantReplyResult(
        message: ChatMessage.assistant(firstAssistantText),
        profile: nextProfile,
        account: nextAccount,
        contextMessages: contextMessages,
      );
    }

    final fallbackWebPayload = await _buildWebContextPayload(
      settings: settings,
      userQuery: latestUserInput,
    );
    if (fallbackWebPayload == null || !fallbackWebPayload.hasReliableData) {
      return AssistantReplyResult(
        message: ChatMessage.assistant(
          _buildWebUnavailableReply(
            payload: fallbackWebPayload,
            userQuery: latestUserInput,
          ),
        ),
        profile: nextProfile,
        account: nextAccount,
        contextMessages: contextMessages,
      );
    }

    final retryMessages = <ChatMessage>[
      ...baseSystemMessages,
      ChatMessage.system(_webModeInstruction),
      ChatMessage.system(_webFallbackInstruction),
      ChatMessage.system(fallbackWebPayload.context),
      ...contextMessages,
    ];

    if (settings.lanGatewayEnabled) {
      final gatewayResult = await _lanGatewayRequest(
        settings: settings,
        messages: retryMessages,
      );
      final fallbackText = gatewayResult.reply;
      final hasFallbackSignal = _needsWebFallback(fallbackText);
      final hasSourceUrls = _containsAnySourceUrl(
        fallbackText,
        fallbackWebPayload.results,
      );
      if (hasFallbackSignal || !hasSourceUrls) {
        return AssistantReplyResult(
          message: ChatMessage.assistant(
            _buildSearchResultsReply(
              payload: fallbackWebPayload,
              userQuery: latestUserInput,
            ),
          ),
          profile: gatewayResult.profile ?? nextProfile,
          account: gatewayResult.account ?? nextAccount,
          contextMessages: contextMessages,
        );
      }
      return AssistantReplyResult(
        message: ChatMessage.assistant(fallbackText),
        profile: gatewayResult.profile ?? nextProfile,
        account: gatewayResult.account ?? nextAccount,
        contextMessages: contextMessages,
      );
    }

    final secondAssistantText = await _apiClient.createChatCompletion(
      settings: settings,
      messages: retryMessages,
    );
    final hasFallbackSignal = _needsWebFallback(secondAssistantText);
    final hasSourceUrls = _containsAnySourceUrl(
      secondAssistantText,
      fallbackWebPayload.results,
    );
    if (hasFallbackSignal || !hasSourceUrls) {
      return AssistantReplyResult(
        message: ChatMessage.assistant(
          _buildSearchResultsReply(
            payload: fallbackWebPayload,
            userQuery: latestUserInput,
          ),
        ),
        profile: nextProfile,
        account: nextAccount,
        contextMessages: contextMessages,
      );
    }

    return AssistantReplyResult(
      message: ChatMessage.assistant(secondAssistantText),
      profile: nextProfile,
      account: nextAccount,
      contextMessages: contextMessages,
    );
  }

  Future<GatewayChatResult> _lanGatewayRequest({
    required ChatSettings settings,
    required List<ChatMessage> messages,
  }) async {
    try {
      return await _lanGatewayClient.requestChat(
        gatewayBaseUrl: settings.normalizedLanGatewayUrl,
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
    final source = autoContextRefresh
        ? conversation
        : (fixedContext ?? const <ChatMessage>[]);
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

  Future<_WebContextPayload?> _buildWebContextPayload({
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

    final context = _formatWebContext(
      results: collected,
      containsUrl: containsUrl,
      urlDataLoaded: urlDataLoaded,
      searchQuery: searchQuery,
      searchDataLoaded: searchDataLoaded,
      searchErrorMessage: searchErrorMessage,
    );
    final hasReliableData = containsUrl ? urlDataLoaded : searchDataLoaded;
    return _WebContextPayload(
      context: context,
      containsUrl: containsUrl,
      hasReliableData: hasReliableData,
      searchQuery: searchQuery,
      searchErrorMessage: searchErrorMessage,
      results: List<WebSearchResult>.unmodifiable(collected),
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

  String _buildWebUnavailableReply({
    required _WebContextPayload? payload,
    required String userQuery,
  }) {
    final normalizedQuery = userQuery.trim();
    if (payload == null) {
      return 'Не удалось получить веб-данные для запроса "$normalizedQuery". '
          'Я не буду импровизировать. Проверьте интернет, доступ к сайту и попробуйте снова.';
    }

    if (payload.containsUrl) {
      final first = payload.results.isNotEmpty ? payload.results.first : null;
      final error = first == null ? '' : _extractErrorLine(first.snippet);
      if (error.isNotEmpty) {
        return 'Не удалось открыть ссылку и получить проверяемые данные: $error\n'
            'Я не буду импровизировать. Попробуйте позже или пришлите текст страницы.';
      }
      return 'Не удалось открыть ссылку и получить проверяемые данные. '
          'Я не буду импровизировать. Попробуйте позже или пришлите текст страницы.';
    }

    final searchQuery = payload.searchQuery?.trim();
    final details = payload.searchErrorMessage?.trim();
    final title = searchQuery == null || searchQuery.isEmpty
        ? normalizedQuery
        : searchQuery;
    if (details != null && details.isNotEmpty) {
      return 'По веб-поиску "$title" не удалось получить надежные источники: $details\n'
          'Я не буду импровизировать. Повторите запрос позже.';
    }
    return 'По веб-поиску "$title" не удалось получить надежные источники. '
        'Я не буду импровизировать. Уточните запрос или повторите позже.';
  }

  String _buildDirectUrlReply(_WebContextPayload payload) {
    final result = payload.results.firstWhere(
      (item) => !item.isError,
      orElse: () => payload.results.first,
    );
    final snippet = result.snippet.trim();
    final content = _extractContentBlock(snippet);
    final briefContent = content.isEmpty
        ? 'Надежные текстовые данные не извлечены.'
        : _truncateText(content, 520);

    final buffer = StringBuffer();
    buffer.writeln('Проверил ссылку по реальным веб-данным.');
    buffer.writeln('URL: ${result.url}');
    buffer.writeln('Заголовок: ${result.title}');
    buffer.writeln('Данные: $briefContent');
    buffer.writeln(
      'Это все подтвержденные данные, которые удалось извлечь без домыслов.',
    );
    return buffer.toString().trim();
  }

  String _buildSearchResultsReply({
    required _WebContextPayload payload,
    required String userQuery,
  }) {
    final reliable = payload.results
        .where((item) => !item.isError)
        .take(4)
        .toList(growable: false);
    if (reliable.isEmpty) {
      return _buildWebUnavailableReply(payload: payload, userQuery: userQuery);
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Показываю только подтвержденные веб-данные без импровизации:',
    );
    for (var i = 0; i < reliable.length; i++) {
      final item = reliable[i];
      buffer.writeln('${i + 1}) ${item.title}');
      buffer.writeln('URL: ${item.url}');
      final preview = _extractBestSnippet(item.snippet);
      if (preview.isNotEmpty) {
        buffer.writeln('Фрагмент: ${_truncateText(preview, 220)}');
      }
    }
    return buffer.toString().trim();
  }

  bool _containsAnySourceUrl(String text, List<WebSearchResult> results) {
    if (results.isEmpty) {
      return false;
    }
    final normalized = text.toLowerCase();
    for (final result in results) {
      final url = result.url.trim().toLowerCase();
      if (url.isNotEmpty && normalized.contains(url)) {
        return true;
      }
      final host = _extractHost(url);
      if (host.isNotEmpty && normalized.contains(host)) {
        return true;
      }
    }
    return false;
  }

  String _extractHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return '';
    }
    return uri.host.toLowerCase();
  }

  String _extractErrorLine(String snippet) {
    for (final line in snippet.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().startsWith('ERROR:')) {
        return trimmed.substring(6).trim();
      }
    }
    return '';
  }

  String _extractContentBlock(String snippet) {
    final marker = 'CONTENT:';
    final index = snippet.indexOf(marker);
    if (index < 0) {
      return _extractBestSnippet(snippet);
    }
    return snippet.substring(index + marker.length).trim();
  }

  String _extractBestSnippet(String snippet) {
    final lines = snippet
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
              !line.toUpperCase().startsWith('URL:') &&
              !line.toUpperCase().startsWith('TITLE:') &&
              !line.toUpperCase().startsWith('ERROR:') &&
              !line.toUpperCase().startsWith('CONTENT:'),
        )
        .toList(growable: false);
    return lines.join(' ').trim();
  }

  String _truncateText(String text, int maxChars) {
    if (text.length <= maxChars) {
      return text;
    }
    return '${text.substring(0, maxChars)}...';
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
      'Отвечай строго по этому блоку, не придумывай факты и используй только факты из контекста. '
      'В конце обязательно добавь раздел "Источники:" и укажи URL из веб-контекста.';

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

class _WebContextPayload {
  const _WebContextPayload({
    required this.context,
    required this.containsUrl,
    required this.hasReliableData,
    required this.searchQuery,
    required this.searchErrorMessage,
    required this.results,
  });

  final String context;
  final bool containsUrl;
  final bool hasReliableData;
  final String? searchQuery;
  final String? searchErrorMessage;
  final List<WebSearchResult> results;
}

class AssistantReplyResult {
  const AssistantReplyResult({
    required this.message,
    required this.profile,
    required this.account,
    required this.contextMessages,
  });

  final ChatMessage message;
  final UserProfile profile;
  final AuthAccount? account;
  final List<ChatMessage> contextMessages;
}
