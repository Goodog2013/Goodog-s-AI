class ChatFolder {
  const ChatFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ChatFolder.create({required String name}) {
    final now = DateTime.now();
    return ChatFolder(
      id: _generateId(),
      name: name.trim().isEmpty ? 'Новая папка' : name.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ChatFolder.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ChatFolder(
      id: json['id'] as String? ?? _generateId(),
      name: json['name'] as String? ?? 'Папка',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  ChatFolder copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String _generateId() {
    return 'folder_${DateTime.now().microsecondsSinceEpoch}';
  }
}
