import 'package:flutter_test/flutter_test.dart';
import 'package:screengate/models/friend.dart';
import 'package:screengate/models/social_post.dart';

void main() {
  test('friend resolves the other profile from either side', () {
    final relationship = Friend(
      id: 'relationship',
      userId: 'sender',
      friendUserId: 'recipient',
      status: FriendStatus.accepted,
      createdAt: DateTime.utc(2026),
    );

    expect(relationship.otherUserId('sender'), 'recipient');
    expect(relationship.otherUserId('recipient'), 'sender');
  });

  test('social post reads visibility and engagement data', () {
    final post = SocialPost.fromJson(
      {
        'id': 'post',
        'user_id': 'author',
        'content': 'Finished my task',
        'visibility': 'friends',
        'created_at': '2026-08-26T12:00:00.000Z',
      },
      authorName: 'Taylor',
      likeCount: 2,
      commentCount: 1,
      isLikedByMe: true,
    );

    expect(post.visibility, PostVisibility.friends);
    expect(post.likeCount, 2);
    expect(post.commentCount, 1);
    expect(post.isLikedByMe, isTrue);
  });
}
