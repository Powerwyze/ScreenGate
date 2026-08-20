class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String criteria;
  final int starsRequired;
  final String category;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.criteria,
    required this.starsRequired,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'criteria': criteria,
        'stars_required': starsRequired,
        'category': category,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        criteria: json['criteria'] as String,
        starsRequired: json['stars_required'] as int,
        category: json['category'] as String,
      );

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? criteria,
    int? starsRequired,
    String? category,
  }) =>
      Achievement(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        criteria: criteria ?? this.criteria,
        starsRequired: starsRequired ?? this.starsRequired,
        category: category ?? this.category,
      );
}

class UserAchievement {
  final String id;
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;

  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': unlockedAt.toIso8601String(),
        'earned_at': unlockedAt
            .toIso8601String(), // Alias for unlocked_at for firestore index
      };

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return UserAchievement(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      achievementId: json['achievement_id'] as String,
      unlockedAt: parseDate(json['unlocked_at'] ?? json['earned_at']),
    );
  }

  UserAchievement copyWith({
    String? id,
    String? userId,
    String? achievementId,
    DateTime? unlockedAt,
  }) =>
      UserAchievement(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        achievementId: achievementId ?? this.achievementId,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
}
