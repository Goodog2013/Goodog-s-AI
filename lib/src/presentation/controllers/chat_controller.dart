import 'package:flutter/foundation.dart';

import '../../application/chat_service.dart';
import '../../application/settings_service.dart';
import '../../data/remote/lm_studio_api_client.dart';
import '../../models/chat_folder.dart';
import '../../models/chat_message.dart';
import '../../models/chat_settings.dart';
import '../../models/chat_thread.dart';
import '../../models/chat_workspace.dart';
import '../../models/plan_limits.dart';
import '../../models/user_profile.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ChatService chatService,
    required SettingsService settingsService,
  }) : _chatService = chatService,
       _settingsService = settingsService;

  final ChatService _chatService;
  final SettingsService _settingsService;

  ChatWorkspace _workspace = ChatWorkspace.initial();
  ChatSettings _settings = ChatSettings.defaults();
  UserProfile _profile = UserProfile.initial(
    id: 'local_user',
    name: ChatSettings.defaultProfileName,
  );

  final Map<String, List<ChatMessage>> _frozenContextByThread = {};

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _lastError;
  String _searchQuery = '';

  ChatSettings get settings => _settings;
  UserProfile get profile => _profile;
  PlanLimits get limits => _profile.limits;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String get searchQuery => _searchQuery;
  bool get hasSearchQuery => _searchQuery.trim().isNotEmpty;

  bool get isCurrentUserBanned => _profile.isBanned;
  bool get autoContextRefreshEnabled => limits.autoContextRefresh;
  int get activeContextMessagesCount {
    if (limits.autoContextRefresh) {
      final nonSystemCount = activeThread.messages
          .where((m) => m.role != ChatRole.system)
          .length;
      return nonSystemCount.clamp(0, limits.maxContextMessages);
    }
    return _frozenContextByThread[activeThread.id]?.length ?? 0;
  }

  bool get canCreateFolder => _workspace.folders.length < limits.maxFolders;
  bool get canCreateThread => _workspace.threads.length < limits.maxChats;

  String? get selectedFolderId => _workspace.selectedFolderId;
  String get activeThreadId => _workspace.activeThreadId;
  ChatThread get activeThread => _workspace.activeThread;
  List<ChatMessage> get messages => activeThread.messages;

  List<ChatFolder> get folders {
    final sorted = [..._workspace.folders];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  List<ChatFolder> get filteredFolders {
    if (!hasSearchQuery) {
      return folders;
    }
    final query = _normalize(_searchQuery);
    return folders
        .where((folder) => _normalize(folder.name).contains(query))
        .toList();
  }

  List<ChatThread> get allThreads {
    final sorted = [..._workspace.threads];
    sorted.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  List<ChatThread> get visibleThreads {
    final scoped = _threadsInSelectedScope();
    if (!hasSearchQuery) {
      return scoped;
    }
    final query = _normalize(_searchQuery);
    return scoped
        .where((thread) => _threadMatchesQuery(thread, query))
        .toList();
  }

  List<ChatThread> get favoriteThreads {
    final scoped = _threadsInSelectedScope().where(
      (thread) => thread.isFavorite,
    );
    if (!hasSearchQuery) {
      return scoped.toList(growable: false);
    }
    final query = _normalize(_searchQuery);
    return scoped
        .where((thread) => _threadMatchesQuery(thread, query))
        .toList();
  }

  ChatThread? threadById(String threadId) {
    for (final thread in _workspace.threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  bool canMoveThreadToFolder({
    required String threadId,
    required String? folderId,
  }) {
    final thread = threadById(threadId);
    if (thread == null) {
      return false;
    }
    return thread.folderId != folderId;
  }

  List<ChatThread> _threadsInSelectedScope() {
    final folderId = _workspace.selectedFolderId;
    if (folderId == null) {
      return allThreads;
    }
    return allThreads.where((thread) => thread.folderId == folderId).toList();
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final loadedSettings = await _settingsService.loadSettings();
      final normalizedSettings = await _settingsService.ensureProfileIdentity(
        loadedSettings,
      );
      final loadedWorkspace = await _chatService.loadWorkspace();
      _settings = normalizedSettings;
      _workspace = loadedWorkspace;
      _profile = UserProfile.initial(
        id: _settings.profileId,
        name: _settings.profileName,
      );
      _lastError = null;
      await syncProfile(notify: false);
    } catch (_) {
      _lastError = 'Не удалось загрузить локальные данные приложения.';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> applySettings(ChatSettings settings) async {
    final normalized = await _settingsService.ensureProfileIdentity(settings);
    _settings = normalized;
    await _settingsService.saveSettings(normalized);
    await syncProfile(notify: false);
    notifyListeners();
  }

  Future<void> syncProfile({bool notify = true}) async {
    try {
      final synced = await _chatService.syncProfile(settings: _settings);
      _profile = synced;
      if (_profile.isBanned) {
        _lastError = 'Ваш профиль заблокирован администратором.';
      } else {
        _lastError = null;
      }
    } on ChatApiException catch (error) {
      _lastError = error.message;
    } catch (_) {
      _lastError = 'Не удалось синхронизировать профиль.';
    } finally {
      if (notify) {
        notifyListeners();
      }
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> createThread({String? title, String? folderId}) async {
    if (!canCreateThread) {
      _lastError = 'Лимит тарифа: максимум ${limits.maxChats} чатов.';
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final newThread = ChatThread.create(
      title: title ?? 'Новый чат',
      folderId: folderId ?? _workspace.selectedFolderId,
    ).copyWith(createdAt: now, updatedAt: now);

    final nextWorkspace = _workspace.copyWith(
      threads: [newThread, ..._workspace.threads],
      activeThreadId: newThread.id,
      selectedFolderId: newThread.folderId,
    );
    await _commitWorkspace(nextWorkspace);
    if (!limits.autoContextRefresh) {
      _frozenContextByThread[newThread.id] = const <ChatMessage>[];
    }
  }

  Future<void> renameThread({
    required String threadId,
    required String newTitle,
  }) async {
    final title = newTitle.trim();
    if (title.isEmpty) {
      return;
    }
    final updatedThreads = _workspace.threads
        .map((thread) {
          if (thread.id != threadId) {
            return thread;
          }
          return thread.copyWith(title: title, updatedAt: DateTime.now());
        })
        .toList(growable: false);
    await _commitWorkspace(_workspace.copyWith(threads: updatedThreads));
  }

  Future<void> toggleThreadFavorite(String threadId) async {
    final updatedThreads = _workspace.threads
        .map((thread) {
          if (thread.id != threadId) {
            return thread;
          }
          return thread.copyWith(
            isFavorite: !thread.isFavorite,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);
    await _commitWorkspace(_workspace.copyWith(threads: updatedThreads));
  }

  Future<void> deleteThread(String threadId) async {
    if (_workspace.threads.length <= 1) {
      await clearHistory();
      return;
    }

    final remaining = _workspace.threads
        .where((thread) => thread.id != threadId)
        .toList(growable: false);
    if (remaining.isEmpty) {
      return;
    }

    _frozenContextByThread.remove(threadId);

    final currentActive = _workspace.activeThreadId;
    final nextActive = currentActive == threadId
        ? remaining.first.id
        : currentActive;
    await _commitWorkspace(
      _workspace.copyWith(threads: remaining, activeThreadId: nextActive),
    );
  }

  Future<void> moveThreadToFolder({
    required String threadId,
    required String? folderId,
    bool selectDestination = false,
  }) async {
    final updatedThreads = _workspace.threads
        .map((thread) {
          if (thread.id != threadId) {
            return thread;
          }
          return thread.copyWith(
            folderId: folderId,
            clearFolder: folderId == null,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);

    final nextWorkspace = _workspace.copyWith(
      threads: updatedThreads,
      selectedFolderId: selectDestination
          ? folderId
          : _workspace.selectedFolderId,
      clearSelectedFolder:
          selectDestination &&
          folderId == null &&
          _workspace.selectedFolderId != null,
    );
    await _commitWorkspace(nextWorkspace);
  }

  Future<void> selectThread(String threadId) async {
    if (!_workspace.threads.any((thread) => thread.id == threadId)) {
      return;
    }
    final thread = _workspace.threads.firstWhere((item) => item.id == threadId);
    final nextWorkspace = _workspace.copyWith(
      activeThreadId: threadId,
      selectedFolderId: thread.folderId,
      clearSelectedFolder: thread.folderId == null,
    );
    await _commitWorkspace(nextWorkspace, notify: true);
  }

  Future<void> selectFolder(String? folderId) async {
    if (folderId != null &&
        !_workspace.folders.any((folder) => folder.id == folderId)) {
      return;
    }

    var nextActiveId = _workspace.activeThreadId;
    final filteredThreads = folderId == null
        ? allThreads
        : allThreads.where((thread) => thread.folderId == folderId).toList();
    if (filteredThreads.isNotEmpty &&
        !filteredThreads.any((thread) => thread.id == nextActiveId)) {
      nextActiveId = filteredThreads.first.id;
    }

    final nextWorkspace = _workspace.copyWith(
      selectedFolderId: folderId,
      activeThreadId: nextActiveId,
      clearSelectedFolder: folderId == null,
    );
    await _commitWorkspace(nextWorkspace, notify: true);
  }

  Future<void> createFolder(String name) async {
    if (!canCreateFolder) {
      _lastError = 'Лимит тарифа: максимум ${limits.maxFolders} папок.';
      notifyListeners();
      return;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final folder = ChatFolder.create(name: trimmed);
    final nextWorkspace = _workspace.copyWith(
      folders: [..._workspace.folders, folder],
      selectedFolderId: folder.id,
    );
    await _commitWorkspace(nextWorkspace);
  }

  Future<void> renameFolder({
    required String folderId,
    required String newName,
  }) async {
    final name = newName.trim();
    if (name.isEmpty) {
      return;
    }

    final updatedFolders = _workspace.folders
        .map((folder) {
          if (folder.id != folderId) {
            return folder;
          }
          return folder.copyWith(name: name, updatedAt: DateTime.now());
        })
        .toList(growable: false);
    await _commitWorkspace(_workspace.copyWith(folders: updatedFolders));
  }

  Future<void> deleteFolder(String folderId) async {
    final updatedFolders = _workspace.folders
        .where((folder) => folder.id != folderId)
        .toList(growable: false);
    final updatedThreads = _workspace.threads
        .map((thread) {
          if (thread.folderId != folderId) {
            return thread;
          }
          return thread.copyWith(clearFolder: true, updatedAt: DateTime.now());
        })
        .toList(growable: false);

    final nextWorkspace = _workspace.copyWith(
      folders: updatedFolders,
      threads: updatedThreads,
      clearSelectedFolder: _workspace.selectedFolderId == folderId,
    );
    await _commitWorkspace(nextWorkspace);
  }

  Future<void> clearHistory() async {
    final clearedThread = activeThread.copyWith(
      messages: const [],
      updatedAt: DateTime.now(),
    );
    _frozenContextByThread.remove(clearedThread.id);
    final updatedThreads = _workspace.threads
        .map((thread) => thread.id == clearedThread.id ? clearedThread : thread)
        .toList(growable: false);
    await _commitWorkspace(_workspace.copyWith(threads: updatedThreads));
  }

  Future<void> refreshContextForActiveThread() async {
    final trimmed = _trimContext(
      activeThread.messages,
      max: limits.maxContextMessages,
    );
    _frozenContextByThread[activeThread.id] = trimmed;
    _lastError = null;
    notifyListeners();
  }

  Future<String?> sendMessage(String inputText) async {
    final text = inputText.trim();
    if (text.isEmpty) {
      return null;
    }
    if (_isLoading) {
      return 'Дождитесь завершения текущего ответа.';
    }
    if (_profile.isBanned) {
      _lastError = 'Ваш профиль заблокирован администратором.';
      notifyListeners();
      return _lastError;
    }

    _lastError = null;
    final now = DateTime.now();
    final userMessage = ChatMessage.user(text);
    final title = _deriveTitle(activeThread.title, text);
    final updatedThread = activeThread.copyWith(
      title: title,
      messages: [...activeThread.messages, userMessage],
      updatedAt: now,
    );

    _workspace = _replaceThread(updatedThread);
    _isLoading = true;
    notifyListeners();

    try {
      await _chatService.saveWorkspace(_workspace);

      final List<ChatMessage>? fixedContext = limits.autoContextRefresh
          ? null
          : (_frozenContextByThread[updatedThread.id] ??
                _trimContext(
                  updatedThread.messages,
                  max: limits.maxContextMessages,
                ));
      if (fixedContext != null) {
        _frozenContextByThread[updatedThread.id] = fixedContext;
      }

      final assistantResult = await _chatService.getAssistantReply(
        settings: _settings,
        profile: _profile,
        conversation: updatedThread.messages,
        fixedContext: fixedContext,
      );
      _profile = assistantResult.profile;
      if (_profile.isBanned) {
        throw const ChatApiException(
          'Ваш профиль заблокирован администратором.',
        );
      }

      final withAssistant = updatedThread.copyWith(
        messages: [...updatedThread.messages, assistantResult.message],
        updatedAt: DateTime.now(),
      );
      _workspace = _replaceThread(withAssistant);
      await _chatService.saveWorkspace(_workspace);
      return null;
    } on ChatApiException catch (error) {
      if (error.isCancelled) {
        _lastError = null;
        return null;
      }
      _lastError = error.message;
      return error.message;
    } catch (_) {
      _lastError = 'Неизвестная ошибка при отправке сообщения.';
      return _lastError;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ChatMessage> _trimContext(
    List<ChatMessage> messages, {
    required int max,
  }) {
    final nonSystem = messages
        .where((m) => m.role != ChatRole.system)
        .toList(growable: false);
    if (nonSystem.length <= max) {
      return nonSystem;
    }
    return nonSystem.sublist(nonSystem.length - max, nonSystem.length);
  }

  void stopGenerating() {
    if (!_isLoading) {
      return;
    }
    _chatService.cancelActiveReply();
  }

  ChatWorkspace _replaceThread(ChatThread updatedThread) {
    final updatedThreads = _workspace.threads
        .map((thread) => thread.id == updatedThread.id ? updatedThread : thread)
        .toList(growable: false);
    return _workspace.copyWith(
      threads: updatedThreads,
      activeThreadId: updatedThread.id,
      selectedFolderId: updatedThread.folderId,
      clearSelectedFolder: updatedThread.folderId == null,
    );
  }

  String _deriveTitle(String currentTitle, String userInput) {
    final trimmedInput = userInput.trim();
    if (trimmedInput.isEmpty) {
      return currentTitle;
    }

    final generic = {'Новый чат', 'Чат'};
    if (!generic.contains(currentTitle)) {
      return currentTitle;
    }

    const max = 34;
    if (trimmedInput.length <= max) {
      return trimmedInput;
    }
    return '${trimmedInput.substring(0, max)}...';
  }

  bool _threadMatchesQuery(ChatThread thread, String query) {
    final inTitle = _normalize(thread.title).contains(query);
    final inPreview = _normalize(thread.preview).contains(query);
    return inTitle || inPreview;
  }

  String _normalize(String value) {
    return value.toLowerCase().trim();
  }

  Future<void> _commitWorkspace(
    ChatWorkspace workspace, {
    bool notify = true,
  }) async {
    _workspace = workspace;
    await _chatService.saveWorkspace(_workspace);
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
