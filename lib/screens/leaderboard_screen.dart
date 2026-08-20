import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/user.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
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
      final idx = leaderboard.indexWhere((u) => u.id == currentUserId);
      if (idx != -1) {
        rank = idx + 1;
      }
    }

    if (!mounted) return;
    setState(() {
      _leaderboard = leaderboard;
      _currentUserRank = rank;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: CyberpunkColors.neonTeal))
          : RefreshIndicator(
              color: CyberpunkColors.neonTeal,
              backgroundColor: CyberpunkColors.surface,
              onRefresh: _loadLeaderboard,
              child: Column(
                children: [
                  if (_currentUserRank != null)
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: CyberpunkColors.neonTeal.withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                              color: CyberpunkColors.neonTeal
                                  .withValues(alpha: 0.4)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events,
                              color: CyberpunkColors.neonTeal, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Your Rank: #$_currentUserRank',
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
                      padding: AppSpacing.paddingLg,
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        final user = _leaderboard[index];
                        final rank = index + 1;
                        final isCurrentUser = user.id ==
                            context.read<AppProvider>().currentUser?.id;

                        return Container(
                          margin: AppSpacing.verticalSm,
                          padding: AppSpacing.paddingMd,
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? CyberpunkColors.neonTeal
                                    .withValues(alpha: 0.12)
                                : CyberpunkColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isCurrentUser
                                  ? CyberpunkColors.neonTeal
                                      .withValues(alpha: 0.4)
                                  : CyberpunkColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildRankBadge(rank),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.codename.toUpperCase(),
                                      style: context.textStyles.titleSmall!
                                          .copyWith(
                                        color: CyberpunkColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'LVL ${user.level} • ${user.currentStreak} DAY STREAK',
                                      style: context.textStyles.labelSmall!
                                          .copyWith(
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
                                    style:
                                        context.textStyles.titleLarge!.copyWith(
                                      color: CyberpunkColors.neonOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'STARS',
                                    style:
                                        context.textStyles.labelSmall!.copyWith(
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
            ),
    );
  }

  Widget _buildRankBadge(int rank) {
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
