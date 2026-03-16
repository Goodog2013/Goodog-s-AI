enum ChatRole { system, user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.user(String content, {String? id, DateTime? createdAt}) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: ChatRole.user,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory ChatMessage.assistant(
    String content, {
    String? id,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: ChatRole.assistant,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory ChatMessage.system(
    String content, {
    String? id,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? _generateId(),
      role: ChatRole.system,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? _generateId(),
      role: _roleFromString(json['role'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: _parseCreatedAt(json['createdAt'] as String?),
    );
  }

  String get roleValue {
    switch (role) {
      case ChatRole.system:
        return 'system';
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': roleValue,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, String> toApiJson() {
    return {'role': roleValue, 'content': content};
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  static DateTime _parseCreatedAt(String? value) {
    if (value == null) {
      return DateTime.now();
    }
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  static ChatRole _roleFromString(String? role) {
    switch (role) {
      case 'system':
        return ChatRole.system;
      case 'assistant':
        return ChatRole.assistant;
      case 'user':
      default:
        return ChatRole.user;
    }
  }
}
