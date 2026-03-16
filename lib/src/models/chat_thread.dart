import 'chat_message.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.folderId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final String? folderId;
  final List<ChatMessage> messages;
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

    return ChatThread(
      id: json['id'] as String? ?? _generateId(),
      title: json['title'] as String? ?? 'Чат',
      folderId: json['folderId'] as String?,
      messages: parsedMessages,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      messages: messages ?? this.messages,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  static String _generateId() {
    return 'chat_${DateTime.now().microsecondsSinceEpoch}';
  }
}
