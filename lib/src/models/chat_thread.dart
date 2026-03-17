import 'chat_message.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.folderId,
    required this.messages,
    required this.manualContextStartCount,
    required this.manualTurnsUsed,
    required this.createdAt,
    required this.updatedAt,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final String? folderId;
  final List<ChatMessage> messages;
  final int manualContextStartCount;
  final int manualTurnsUsed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  factory ChatThread.create({required String title, String? folderId}) {
    final now = DateTime.now();
    return ChatThread(
      id: _generateId(),
      title: title.trim().isEmpty ? 'Новый чат' : title.trim(),
      folderId: folderId,
      messages: const [],
      manualContextStartCount: 0,
      manualTurnsUsed: 0,
      createdAt: now,
      updatedAt: now,
      isFavorite: false,
    );
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final rawMessages = json['messages'];
    final parsedMessages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map((item) => ChatMessage.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <ChatMessage>[];
    final parsedNonSystemCount = parsedMessages
        .where((message) => message.role != ChatRole.system)
        .length;
    final rawManualStart = json['manualContextStartCount'];
    final manualContextStartCount = rawManualStart is int
        ? rawManualStart
        : parsedNonSystemCount;
    final rawManualTurns = json['manualTurnsUsed'];
    final manualTurnsUsed = rawManualTurns is int
        ? rawManualTurns
        : _countUserMessagesSince(
            parsedMessages,
            start: manualContextStartCount,
          );

    return ChatThread(
      id: json['id'] as String? ?? _generateId(),
      title: json['title'] as String? ?? 'Чат',
      folderId: json['folderId'] as String?,
      messages: parsedMessages,
      manualContextStartCount: manualContextStartCount.clamp(
        0,
        parsedNonSystemCount,
      ),
      manualTurnsUsed: manualTurnsUsed < 0 ? 0 : manualTurnsUsed,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  ChatThread copyWith({
    String? id,
    String? title,
    String? folderId,
    bool clearFolder = false,
    List<ChatMessage>? messages,
    int? manualContextStartCount,
    int? manualTurnsUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      messages: messages ?? this.messages,
      manualContextStartCount:
          manualContextStartCount ?? this.manualContextStartCount,
      manualTurnsUsed: manualTurnsUsed ?? this.manualTurnsUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get preview {
    if (messages.isEmpty) {
      return 'Пустой чат';
    }
    final last = messages.last.content.trim();
    if (last.isEmpty) {
      return 'Сообщение без текста';
    }
    return last;
  }

  int get messageCount => messages.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'folderId': folderId,
      'messages': messages.map((message) => message.toJson()).toList(),
      'manualContextStartCount': manualContextStartCount,
      'manualTurnsUsed': manualTurnsUsed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  static int _countUserMessagesSince(
    List<ChatMessage> messages, {
    required int start,
  }) {
    final nonSystem = messages
        .where((message) => message.role != ChatRole.system)
        .toList(growable: false);
    final safeStart = start.clamp(0, nonSystem.length);
    var count = 0;
    for (var i = safeStart; i < nonSystem.length; i++) {
      if (nonSystem[i].role == ChatRole.user) {
        count++;
      }
    }
    return count;
  }

  static String _generateId() {
    return 'chat_${DateTime.now().microsecondsSinceEpoch}';
  }
}
