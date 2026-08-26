enum FriendStatus { pending, accepted }

class Friend {
  final String id;
  final String userId;
  final String friendUserId;
  final FriendStatus status;
  final DateTime createdAt;

  Friend({
    required this.id,
    required this.userId,
    required this.friendUserId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'friend_user_id': friendUserId,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        friendUserId: json['friend_user_id'] as String,
        status: FriendStatus.values.firstWhere((e) => e.name == json['status']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Friend copyWith({
    String? id,
    String? userId,
    String? friendUserId,
    FriendStatus? status,
    DateTime? createdAt,
  }) =>
      Friend(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        friendUserId: friendUserId ?? this.friendUserId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );

  String otherUserId(String currentUserId) =>
      userId == currentUserId ? friendUserId : userId;
}
