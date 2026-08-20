enum ChatRole { user, handler }

class ChatMessage {
  final String id;
  final String userId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'role': role.name,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        role: ChatRole.values.firstWhere((e) => e.name == json['role']),
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  ChatMessage copyWith({
    String? id,
    String? userId,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
}
