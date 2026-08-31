enum PostVisibility {
  public,
  friends;

  static PostVisibility fromJson(dynamic value) => values.firstWhere(
        (item) => item.name == value,
        orElse: () => PostVisibility.public,
      );
}

class SocialPost {
  final String id;
  final String userId;
  final String missionId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final String taskTitle;
  final String taskDescription;
  final String? taskPhotoUrl;
  final double starsEarned;
  final DateTime completedAt;
  final PostVisibility visibility;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.missionId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.taskTitle,
    required this.taskDescription,
    this.taskPhotoUrl,
    required this.starsEarned,
    required this.completedAt,
    required this.visibility,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
  });

  factory SocialPost.fromJson(
    Map<String, dynamic> json, {
    required String authorName,
    String? authorAvatarUrl,
    int likeCount = 0,
    int commentCount = 0,
    bool isLikedByMe = false,
  }) =>
      SocialPost(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        missionId: json['mission_id'] as String,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: json['content'] as String,
        taskTitle: json['task_title'] as String,
        taskDescription: json['task_description'] as String? ?? '',
        taskPhotoUrl: json['task_photo_url'] as String?,
        starsEarned: (json['stars_earned'] as num?)?.toDouble() ?? 0,
        completedAt: DateTime.parse(json['completed_at'] as String),
        visibility: PostVisibility.fromJson(json['visibility']),
        createdAt: DateTime.parse(json['created_at'] as String),
        likeCount: likeCount,
        commentCount: commentCount,
        isLikedByMe: isLikedByMe,
      );

  SocialPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) =>
      SocialPost(
        id: id,
        userId: userId,
        missionId: missionId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: content,
        taskTitle: taskTitle,
        taskDescription: taskDescription,
        taskPhotoUrl: taskPhotoUrl,
        starsEarned: starsEarned,
        completedAt: completedAt,
        visibility: visibility,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      );
}

class SocialComment {
  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory SocialComment.fromJson(
    Map<String, dynamic> json, {
    required String authorName,
    String? authorAvatarUrl,
  }) =>
      SocialComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
