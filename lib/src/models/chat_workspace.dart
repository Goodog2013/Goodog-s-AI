import 'chat_folder.dart';
import 'chat_thread.dart';

class ChatWorkspace {
  const ChatWorkspace({
    required this.folders,
    required this.threads,
    required this.activeThreadId,
    required this.selectedFolderId,
  });

  final List<ChatFolder> folders;
  final List<ChatThread> threads;
  final String activeThreadId;
  final String? selectedFolderId;

  factory ChatWorkspace.initial() {
    final defaultThread = ChatThread.create(title: 'Новый чат');
    return ChatWorkspace(
      folders: const [],
      threads: <ChatThread>[defaultThread],
      activeThreadId: defaultThread.id,
      selectedFolderId: null,
    );
  }

  factory ChatWorkspace.fromJson(Map<String, dynamic> json) {
    final foldersJson = json['folders'];
    final parsedFolders = foldersJson is List
        ? foldersJson
              .whereType<Map>()
              .map((item) => ChatFolder.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <ChatFolder>[];

    final threadsJson = json['threads'];
    var parsedThreads = threadsJson is List
        ? threadsJson
              .whereType<Map>()
              .map((item) => ChatThread.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <ChatThread>[];

    if (parsedThreads.isEmpty) {
      parsedThreads = <ChatThread>[ChatThread.create(title: 'Новый чат')];
    }

    final folderIds = parsedFolders.map((folder) => folder.id).toSet();
    parsedThreads = parsedThreads
        .map((thread) {
          if (thread.folderId != null && !folderIds.contains(thread.folderId)) {
            return thread.copyWith(clearFolder: true);
          }
          return thread;
        })
        .toList(growable: false);

    final rawActiveId = json['activeThreadId'] as String?;
    final activeId = parsedThreads.any((thread) => thread.id == rawActiveId)
        ? rawActiveId!
        : parsedThreads.first.id;

    final rawSelectedFolder = json['selectedFolderId'] as String?;
    final selectedFolderId =
        rawSelectedFolder != null && folderIds.contains(rawSelectedFolder)
        ? rawSelectedFolder
        : null;

    return ChatWorkspace(
      folders: parsedFolders,
      threads: parsedThreads,
      activeThreadId: activeId,
      selectedFolderId: selectedFolderId,
    );
  }

  ChatWorkspace copyWith({
    List<ChatFolder>? folders,
    List<ChatThread>? threads,
    String? activeThreadId,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
  }) {
    return ChatWorkspace(
      folders: folders ?? this.folders,
      threads: threads ?? this.threads,
      activeThreadId: activeThreadId ?? this.activeThreadId,
      selectedFolderId: clearSelectedFolder
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
    );
  }

  ChatThread get activeThread {
    return threads.firstWhere(
      (thread) => thread.id == activeThreadId,
      orElse: () => threads.first,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'folders': folders.map((folder) => folder.toJson()).toList(),
      'threads': threads.map((thread) => thread.toJson()).toList(),
      'activeThreadId': activeThreadId,
      'selectedFolderId': selectedFolderId,
    };
  }
}
