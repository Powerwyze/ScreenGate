enum AccountRole {
  parent,
  child;

  static AccountRole fromJson(dynamic value) {
    return value == AccountRole.child.name
        ? AccountRole.child
        : AccountRole.parent;
  }
}

enum UsageMode {
  family,
  solo;

  static UsageMode fromJson(dynamic value) =>
      value == UsageMode.solo.name ? UsageMode.solo : UsageMode.family;
}

class User {
  final String id;
  final String? authUserId;
  final String codename;
  final String email;
  final String? avatarUrl;
  final String selectedHandlerId;
  final String lifeGoals;
  final AccountRole accountRole;
  final UsageMode usageMode;
  final int totalStars;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    this.authUserId,
    required this.codename,
    required this.email,
    this.avatarUrl,
    required this.selectedHandlerId,
    required this.lifeGoals,
    required this.accountRole,
    this.usageMode = UsageMode.family,
    required this.totalStars,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.createdAt,
    required this.updatedAt,
  });

  int get nextLevelStars => 100;
  int get starsInCurrentLevel => totalStars % 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'auth_user_id': authUserId,
        'codename': codename,
        'email': email,
        'avatar_url': avatarUrl,
        'selected_handler_id': selectedHandlerId,
        'life_goals': lifeGoals,
        'account_role': accountRole.name,
        'usage_mode': usageMode.name,
        'total_stars': totalStars,
        'level': level,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return User(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String?,
      codename: json['codename'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      selectedHandlerId: json['selected_handler_id'] as String,
      lifeGoals: json['life_goals'] as String,
      accountRole: AccountRole.fromJson(json['account_role']),
      usageMode: UsageMode.fromJson(json['usage_mode']),
      totalStars: json['total_stars'] as int,
      level: json['level'] as int,
      currentStreak: json['current_streak'] as int,
      longestStreak: json['longest_streak'] as int,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  User copyWith({
    String? id,
    String? authUserId,
    String? codename,
    String? email,
    String? avatarUrl,
    String? selectedHandlerId,
    String? lifeGoals,
    AccountRole? accountRole,
    UsageMode? usageMode,
    int? totalStars,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        authUserId: authUserId ?? this.authUserId,
        codename: codename ?? this.codename,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        selectedHandlerId: selectedHandlerId ?? this.selectedHandlerId,
        lifeGoals: lifeGoals ?? this.lifeGoals,
        accountRole: accountRole ?? this.accountRole,
        usageMode: usageMode ?? this.usageMode,
        totalStars: totalStars ?? this.totalStars,
        level: level ?? this.level,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
