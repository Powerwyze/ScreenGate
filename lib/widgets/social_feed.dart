import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/social_post.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/services/social_service.dart';
import 'package:screengate/theme.dart';

class SocialFeed extends StatefulWidget {
  const SocialFeed({super.key});

  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  FeedScope _scope = FeedScope.public;
  List<SocialPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await provider.socialService.getFeed(
        viewerId: user.id,
        scope: _scope,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The feed could not load. Pull down to try again.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;
    final post = _posts[index];
    final liked = !post.isLikedByMe;
    setState(() {
      _posts = [..._posts]..[index] = post.copyWith(
          isLikedByMe: liked,
          likeCount: post.likeCount + (liked ? 1 : -1),
        );
    });
    try {
      await provider.socialService.toggleLike(
        post: post,
        userId: user.id,
        userName: user.codename,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [..._posts]..[index] = post;
      });
      _showError('Could not update that like.');
    }
  }

  Future<void> _openComments(int index) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberpunkColors.surface,
      builder: (_) => _CommentsSheet(post: _posts[index]),
    );
    if (added == true && mounted) {
      final post = _posts[index];
      setState(() {
        _posts = [..._posts]..[index] =
            post.copyWith(commentCount: post.commentCount + 1);
      });
    }
  }

  Future<void> _deletePost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this task from the feed?'),
        content: const Text('It will no longer be shared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppProvider>().socialService.deletePost(post.id);
      if (!mounted) return;
      setState(
          () => _posts = _posts.where((item) => item.id != post.id).toList());
    } catch (_) {
      _showError('Could not remove that shared task.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<FeedScope>(
              segments: const [
                ButtonSegment(
                  value: FeedScope.public,
                  icon: Icon(Icons.public_rounded),
                  label: Text('Everyone'),
                ),
                ButtonSegment(
                  value: FeedScope.friends,
                  icon: Icon(Icons.people_rounded),
                  label: Text('Friends'),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (value) {
                setState(() => _scope = value.first);
                _load();
              },
            ),
          ),
        ),
        Expanded(child: _buildFeed(user?.id)),
      ],
    );
  }

  Widget _buildFeed(String? currentUserId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(
              _scope == FeedScope.public
                  ? Icons.public_rounded
                  : Icons.people_outline_rounded,
              size: 52,
              color: CyberpunkColors.neonTealBright,
            ),
            const SizedBox(height: 12),
            Text(
              _scope == FeedScope.public
                  ? 'No shared tasks yet'
                  : 'No shared friend tasks yet',
              style: context.textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _scope == FeedScope.public
                  ? 'Finished tasks will show here.'
                  : 'Finished friend tasks will show here.',
              style: context.textStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _PostCard(
            post: post,
            isMine: post.userId == currentUserId,
            onLike: () => _toggleLike(index),
            onComments: () => _openComments(index),
            onDelete: () => _deletePost(post),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final SocialPost post;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.isMine,
    required this.onLike,
    required this.onComments,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CyberpunkColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CyberpunkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: post.authorName, imageUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: context.textStyles.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Icon(
                          post.visibility == PostVisibility.public
                              ? Icons.public_rounded
                              : Icons.people_rounded,
                          size: 14,
                          color: CyberpunkColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _relativeTime(post.createdAt),
                          style: context.textStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMine)
                PopupMenuButton<String>(
                  tooltip: 'Shared task options',
                  onSelected: (_) => onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove from feed'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 18,
                color: CyberpunkColors.neonTealBright,
              ),
              const SizedBox(width: 6),
              Text(
                'TASK FINISHED',
                style: context.textStyles.labelMedium?.copyWith(
                  color: CyberpunkColors.neonTealBright,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.taskTitle,
            style: context.textStyles.titleLarge?.copyWith(
              color: CyberpunkColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (post.taskDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.taskDescription,
              style: context.textStyles.bodyMedium?.copyWith(
                color: CyberpunkColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (post.taskPhotoUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  post.taskPhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: CyberpunkColors.surface,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index + 1 <= post.starsEarned
                      ? Icons.star_rounded
                      : index + .5 <= post.starsEarned
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded,
                  size: 20,
                  color: CyberpunkColors.neonOrangeBright,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                post.starsEarned > 0
                    ? '${post.starsEarned.toStringAsFixed(1)} stars'
                    : 'Finished',
                style: context.textStyles.labelMedium,
              ),
            ],
          ),
          if (post.content != 'Task completed.') ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              style: context.textStyles.bodyMedium?.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: CyberpunkColors.border),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  post.isLikedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.isLikedByMe
                      ? CyberpunkColors.neonMagenta
                      : CyberpunkColors.textSecondary,
                ),
                label: Text('${post.likeCount}'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onComments,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text('${post.commentCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final SocialPost post;
  const _CommentsSheet({required this.post});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  List<SocialComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  bool _addedComment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await context
          .read<AppProvider>()
          .socialService
          .getComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await provider.socialService.addComment(
        post: widget.post,
        userId: user.id,
        userName: user.codename,
        content: _controller.text,
      );
      _controller.clear();
      _addedComment = true;
      await _load();
      if (mounted) setState(() => _sending = false);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comments',
                        style: context.textStyles.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context, _addedComment),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('No comments yet.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Avatar(
                                    name: comment.authorName,
                                    imageUrl: comment.authorAvatarUrl,
                                    radius: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: CyberpunkColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.authorName,
                                            style:
                                                context.textStyles.labelLarge,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(comment.content),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 1000,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          counterText: '',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send comment',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const _Avatar({required this.name, this.imageUrl, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: CyberpunkColors.neonTeal.withValues(alpha: 0.2),
      foregroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: CyberpunkColors.neonTealBright,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

String _relativeTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${createdAt.toLocal().month}/${createdAt.toLocal().day}';
}
