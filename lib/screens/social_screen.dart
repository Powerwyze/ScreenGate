import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/models/user.dart';
import 'package:screengate/models/friend.dart';
import 'package:screengate/theme.dart';
import 'package:screengate/widgets/social_feed.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberpunkColors.background,
      appBar: AppBar(
        backgroundColor: CyberpunkColors.background,
        title: Text(
          'SOCIAL',
          style: context.textStyles.titleLarge!.copyWith(
            color: CyberpunkColors.textPrimary,
            letterSpacing: 2.0,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: CyberpunkColors.neonTeal,
          labelColor: CyberpunkColors.neonTeal,
          unselectedLabelColor: CyberpunkColors.textMuted,
          dividerColor: CyberpunkColors.border,
          labelStyle: context.textStyles.labelSmall,
          unselectedLabelStyle: context.textStyles.labelSmall,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_rounded), text: 'FEED'),
            Tab(icon: Icon(Icons.people), text: 'FRIENDS'),
            Tab(icon: Icon(Icons.notifications), text: 'REQUESTS'),
            Tab(icon: Icon(Icons.leaderboard), text: 'BOARD'),
            Tab(icon: Icon(Icons.person_add), text: 'ADD'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SocialFeed(),
          _FriendsTab(),
          _RequestsTab(),
          _LeaderboardTab(),
          _AddFriendsTab(),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  List<Friend> _friends = [];
  Map<String, User> _friendUsers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final userId = provider.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final friends = await provider.friendService.getFriendsByUserId(userId);
    final friendUserIds = friends.map((f) => f.otherUserId(userId)).toList();
    final friendUsers = await provider.userService.getUsersByIds(friendUserIds);

    final friendUsersMap = <String, User>{};
    for (final user in friendUsers) {
      friendUsersMap[user.id] = user;
    }

    setState(() {
      _friends = friends;
      _friendUsers = friendUsersMap;
      _isLoading = false;
    });
  }

  Future<void> _removeFriend(Friend friend) async {
    final provider = context.read<AppProvider>();
    await provider.friendService.deleteFriend(friend.id);
    await _loadFriends();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AppProvider>().currentUser?.id ?? '';
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: CyberpunkColors.neonTeal));
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: CyberpunkColors.neonTeal),
            const SizedBox(height: 16),
            Text('NO FRIENDS YET', style: context.textStyles.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: AppSpacing.horizontalXl,
              child: Text(
                'Start adding friends to compete and collaborate!',
                style: context.textStyles.bodyMedium!
                    .withColor(CyberpunkColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: CyberpunkColors.neonTeal,
      backgroundColor: CyberpunkColors.surface,
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: AppSpacing.paddingMd,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final friendUser = _friendUsers[friend.otherUserId(currentUserId)];

          if (friendUser == null) return const SizedBox.shrink();

          return Container(
            margin: AppSpacing.verticalSm,
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: CyberpunkColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: CyberpunkColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      CyberpunkColors.neonTeal.withValues(alpha: 0.2),
                  child: Text(
                    friendUser.codename[0].toUpperCase(),
                    style: context.textStyles.titleMedium!.copyWith(
                      color: CyberpunkColors.neonTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendUser.codename.toUpperCase(),
                        style: context.textStyles.titleSmall!.copyWith(
                          color: CyberpunkColors.textPrimary,
                        ),
                      ),
                      Text(
                        'LVL ${friendUser.level} • ${friendUser.totalStars} STARS',
                        style: context.textStyles.labelSmall!.copyWith(
                          color: CyberpunkColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: CyberpunkColors.textMuted),
                  onPressed: () =>
                      _showFriendOptions(context, friend, friendUser),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFriendOptions(
      BuildContext context, Friend friend, User friendUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(context);
                context.read<AppProvider>().setCurrentTab(2);
                context.push('/direct-message', extra: friendUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Give a Task'),
              onTap: () {
                Navigator.pop(context);
                _assignMission(friendUser);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Remove Friend',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _removeFriend(friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _assignMission(User friendUser) {
    context.push('/create-mission', extra: friendUser);
  }
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<Friend> _requests = [];
  Map<String, User> _requestUsers = {};
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<Friend>>? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchRequests());
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final provider = context.read<AppProvider>();
    final userId = provider.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final requests = await provider.friendService.getPendingRequests(userId);
      await _applyRequests(requests);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Friend requests could not load.';
        _isLoading = false;
      });
    }
  }

  void _watchRequests() {
    final provider = context.read<AppProvider>();
    final userId = provider.currentUser?.id;
    if (userId == null) return;
    _requestSubscription?.cancel();
    _requestSubscription = provider.friendService
        .getPendingRequestsStream(userId)
        .listen(_applyRequests, onError: (Object error) {
      debugPrint('[Social] Friend request stream failed: $error');
    });
  }

  Future<void> _applyRequests(List<Friend> requests) async {
    final provider = context.read<AppProvider>();
    final requesterIds = requests.map((r) => r.userId).toList();
    final requestUsers = await provider.userService.getUsersByIds(requesterIds);

    final requestUsersMap = <String, User>{};
    for (final user in requestUsers) {
      requestUsersMap[user.id] = user;
    }

    if (!mounted) return;
    setState(() {
      _requests = requests;
      _requestUsers = requestUsersMap;
      _isLoading = false;
      _error = null;
    });
  }

  Future<void> _acceptRequest(Friend request) async {
    final provider = context.read<AppProvider>();
    await provider.friendService.acceptFriendRequest(request.id);
    await _loadRequests();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    }
  }

  Future<void> _declineRequest(Friend request) async {
    final provider = context.read<AppProvider>();
    await provider.friendService.declineFriendRequest(request.id);
    await _loadRequests();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Text('🔔',
                style: context.textStyles.displayMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('No Friend Requests',
                style: context.textStyles.titleLarge!.bold,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Padding(
              padding: AppSpacing.horizontalXl,
              child: Text(
                'New requests will show here.',
                style: context.textStyles.bodyMedium!.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: AppSpacing.paddingMd,
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          final requester = _requestUsers[request.userId];

          if (requester == null) return const SizedBox.shrink();

          return Card(
            margin: AppSpacing.verticalSm,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  requester.codename[0].toUpperCase(),
                  style: context.textStyles.titleMedium!.bold.withColor(
                    Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(requester.codename,
                  style: context.textStyles.titleMedium!.semiBold),
              subtitle:
                  Text('Level ${requester.level} • ${requester.totalStars} ⭐'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _acceptRequest(request),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.error),
                    onPressed: () => _declineRequest(request),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  List<User> _leaderboard = [];
  bool _isLoading = true;
  int? _currentUserRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final currentUserId = provider.currentUser?.id;

    final leaderboard = await provider.userService.getLeaderboard(limit: 50);

    int? rank;
    if (currentUserId != null) {
      rank = leaderboard.indexWhere((u) => u.id == currentUserId);
      if (rank != -1) rank += 1;
    }

    setState(() {
      _leaderboard = leaderboard;
      _currentUserRank = rank == -1 ? null : rank;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: CyberpunkColors.neonTeal));
    }

    return RefreshIndicator(
      color: CyberpunkColors.neonTeal,
      backgroundColor: CyberpunkColors.surface,
      onRefresh: _loadLeaderboard,
      child: Column(
        children: [
          if (_currentUserRank != null)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: CyberpunkColors.neonTeal.withValues(alpha: 0.15),
                border: Border(
                  bottom: BorderSide(
                      color: CyberpunkColors.neonTeal.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events,
                      color: CyberpunkColors.neonTeal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR RANK: #$_currentUserRank',
                    style: context.textStyles.labelLarge!.copyWith(
                      color: CyberpunkColors.neonTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: _leaderboard.length,
              itemBuilder: (context, index) {
                final user = _leaderboard[index];
                final rank = index + 1;
                final isCurrentUser =
                    user.id == context.read<AppProvider>().currentUser?.id;

                return Container(
                  margin: AppSpacing.verticalSm,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? CyberpunkColors.neonTeal.withValues(alpha: 0.1)
                        : CyberpunkColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isCurrentUser
                          ? CyberpunkColors.neonTeal.withValues(alpha: 0.5)
                          : CyberpunkColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildRankBadge(context, rank),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.codename.toUpperCase(),
                              style: context.textStyles.titleSmall!.copyWith(
                                color: CyberpunkColors.textPrimary,
                              ),
                            ),
                            Text(
                              'LVL ${user.level} • ${user.currentStreak} DAY STREAK',
                              style: context.textStyles.labelSmall!.copyWith(
                                color: CyberpunkColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${user.totalStars}',
                            style: context.textStyles.titleLarge!.copyWith(
                              color: CyberpunkColors.neonOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'STARS',
                            style: context.textStyles.labelSmall!.copyWith(
                              color: CyberpunkColors.neonOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank) {
    Color badgeColor;
    Color textColor;
    IconData? icon;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700);
      textColor = Colors.black;
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0);
      textColor = Colors.black;
      icon = Icons.emoji_events;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32);
      textColor = Colors.white;
      icon = Icons.emoji_events;
    } else {
      badgeColor = CyberpunkColors.cardBg;
      textColor = CyberpunkColors.textSecondary;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: textColor, size: 20)
            : Text(
                '#$rank',
                style: context.textStyles.labelMedium!.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _AddFriendsTab extends StatefulWidget {
  const _AddFriendsTab();

  @override
  State<_AddFriendsTab> createState() => _AddFriendsTabState();
}

class _AddFriendsTabState extends State<_AddFriendsTab> {
  final _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _sentRequests = {};
  final Set<String> _friendIds = {};
  final Map<String, Friend> _incomingRequests = {};
  List<User> _allUsers = [];
  bool _loadingAll = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
    _loadRelationships();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    setState(() => _loadingAll = true);
    try {
      final provider = context.read<AppProvider>();
      final currentUserId = provider.currentUser?.id;
      final users = await provider.userService.getAllUsers(limit: 500);
      final filtered = users.where((u) => u.id != currentUserId).toList();
      setState(() {
        _allUsers = filtered;
        _loadingAll = false;
      });
    } catch (e) {
      debugPrint('Error loading all users: $e');
      setState(() => _loadingAll = false);
    }
  }

  Future<void> _loadRelationships() async {
    try {
      final provider = context.read<AppProvider>();
      final currentUserId = provider.currentUser?.id;
      if (currentUserId == null) return;
      final connections =
          await provider.friendService.getConnections(currentUserId);
      if (!mounted) return;
      setState(() {
        _sentRequests
          ..clear()
          ..addAll(connections
              .where((item) =>
                  item.status == FriendStatus.pending &&
                  item.userId == currentUserId)
              .map((item) => item.friendUserId));
        _friendIds
          ..clear()
          ..addAll(connections
              .where((item) => item.status == FriendStatus.accepted)
              .map((item) => item.otherUserId(currentUserId)));
        _incomingRequests
          ..clear()
          ..addEntries(connections
              .where((item) =>
                  item.status == FriendStatus.pending &&
                  item.friendUserId == currentUserId)
              .map((item) => MapEntry(item.userId, item)));
      });
    } catch (e) {
      debugPrint('Error loading relationships: $e');
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadAllUsers(), _loadRelationships()]);
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final provider = context.read<AppProvider>();
    final currentUserId = provider.currentUser?.id;

    final results = await provider.userService.searchUsersByCodename(query);

    // Filter out current user
    final filteredResults =
        results.where((u) => u.id != currentUserId).toList();

    setState(() {
      _searchResults = filteredResults;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(User user) async {
    final provider = context.read<AppProvider>();
    final currentUserId = provider.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final relationship = await provider.friendService
          .sendFriendRequest(currentUserId, user.id);
      if (!mounted) return;
      setState(() {
        if (relationship.status == FriendStatus.accepted) {
          _friendIds.add(user.id);
          _incomingRequests.remove(user.id);
        } else {
          _sentRequests.add(user.id);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(relationship.status == FriendStatus.accepted
                ? 'You and ${user.codename} are now friends.'
                : 'Friend request sent to ${user.codename}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _acceptIncoming(User user) async {
    final request = _incomingRequests[user.id];
    if (request == null) return;
    try {
      await context
          .read<AppProvider>()
          .friendService
          .acceptFriendRequest(request.id);
      if (!mounted) return;
      setState(() {
        _incomingRequests.remove(user.id);
        _friendIds.add(user.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You and ${user.codename} are now friends.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept that request.')),
        );
      }
    }
  }

  Widget _relationshipButton(User user) {
    if (_friendIds.contains(user.id)) {
      return const Chip(
        avatar: Icon(Icons.check_rounded, size: 18),
        label: Text('Friends'),
      );
    }
    if (_incomingRequests.containsKey(user.id)) {
      return FilledButton(
        onPressed: () => _acceptIncoming(user),
        child: const Text('Accept'),
      );
    }
    if (_sentRequests.contains(user.id)) {
      return const TextButton(onPressed: null, child: Text('Sent'));
    }
    return FilledButton(
      onPressed: () => _sendFriendRequest(user),
      child: const Text('Add'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingAll = _searchController.text.isEmpty;

    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingMd,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by codename...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              if (value.length >= 2) {
                _searchUsers(value);
              } else {
                setState(() => _searchResults = []);
              }
            },
          ),
        ),
        if (!showingAll && _isSearching)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (!showingAll &&
            _searchResults.isEmpty &&
            _searchController.text.isNotEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔍', style: context.textStyles.displayMedium),
                  const SizedBox(height: 16),
                  Text('No Users Found',
                      style: context.textStyles.titleLarge!.bold),
                  const SizedBox(height: 8),
                  Padding(
                    padding: AppSpacing.horizontalXl,
                    child: Text(
                      'Try a different codename',
                      style: context.textStyles.bodyMedium!.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (!showingAll)
          Expanded(
            child: ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return Card(
                  margin: AppSpacing.verticalSm,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.codename[0].toUpperCase(),
                        style: context.textStyles.titleMedium!.bold.withColor(
                          Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(user.codename,
                        style: context.textStyles.titleMedium!.semiBold),
                    subtitle:
                        Text('Level ${user.level} • ${user.totalStars} ⭐'),
                    trailing: _relationshipButton(user),
                  ),
                );
              },
            ),
          )
        else
          Expanded(
            child: _loadingAll
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: _allUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allUsers[index];
                        return Card(
                          margin: AppSpacing.verticalSm,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                user.codename[0].toUpperCase(),
                                style: context.textStyles.titleMedium!.bold
                                    .withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(user.codename,
                                style:
                                    context.textStyles.titleMedium!.semiBold),
                            subtitle: Text(
                                'Level ${user.level} • ${user.totalStars} ⭐'),
                            trailing: _relationshipButton(user),
                          ),
                        );
                      },
                    ),
                  ),
          ),
      ],
    );
  }
}
