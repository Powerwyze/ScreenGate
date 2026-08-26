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
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final PostVisibility visibility;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
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
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: json['content'] as String,
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
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: content,
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
