import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/theme.dart';
import 'package:screengate/widgets/mission_card.dart';
import 'package:screengate/models/user.dart' as model_user;
import 'package:screengate/services/pwa_install_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const List<String> _filters = [
    'ALL',
    'EXECUTE',
    'EXECUTED',
    'FAILED',
    'SCHEDULED'
  ];
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    initPwaInstallPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final user = provider.currentUser;
            final handler = provider.currentHandler ??
                provider.handlerService.getDefaultHandler();

            if (user == null) {
              if (provider.isAuthenticated) {
                return FutureBuilder(
                  future: Future.delayed(const Duration(seconds: 2)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CyberpunkColors.neonTeal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('LOADING...',
                                style: context.textStyles.labelMedium),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_circle,
                                size: 48, color: CyberpunkColors.neonTeal),
                            const SizedBox(height: 12),
                            Text('COMPLETE YOUR PROFILE',
                                style: context.textStyles.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              'We couldn\'t find your profile. Tap below to finish onboarding.',
                              style: context.textStyles.bodyMedium!
                                  .withColor(CyberpunkColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => context.go('/onboarding'),
                              icon: Icon(Icons.rocket_launch,
                                  color: CyberpunkColors.background),
                              label: const Text('FINISH ONBOARDING'),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return Center(
                child:
                    CircularProgressIndicator(color: CyberpunkColors.neonTeal),
              );
            }

            final filteredMissions = _filterMissions(provider.missions);

            return RefreshIndicator(
              color: CyberpunkColors.neonTeal,
              backgroundColor: CyberpunkColors.surface,
              onRefresh: () async {
                await provider.refreshUser();
                await provider.loadMissions();
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with app name and handler status
                          _CyberpunkHeader(handler: handler, user: user),
                          const SizedBox(height: 16),
                          // Email List Sign-up Button (at top)
                          _EmailListButton(
                            onTap: () async {
                              final url = Uri.parse(
                                  'https://docs.google.com/forms/d/e/1FAIpQLSfOFl-YlIriHMdIxinbBAIeNc9sQ_vSuf5opaKvODSHAE-jMg/viewform?usp=header');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          // Invite a Friend Button
                          _InviteFriendButton(
                            onTap: () async {
                              final subject =
                                  Uri.encodeComponent('Check out ScreenGate!');
                              final body = Uri.encodeComponent(
                                  'Hey! I\'ve been using ScreenGate to turn completed tasks into screen time. You should check it out!');
                              final url = Uri.parse(
                                  'mailto:?subject=$subject&body=$body');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _DownloadWebAppButton(
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);

                              final blocker = getPwaInstallBlocker();
                              if (blocker != null ||
                                  !canShowPwaInstallPrompt()) {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content: Text(blocker ??
                                          'Add to Home Screen is not available right now.')),
                                );
                                return;
                              }

                              final accepted = await showPwaInstallPrompt();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    accepted
                                        ? 'Installation started—check your browser prompts.'
                                        : 'Install dismissed.',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // Stats Row - Level and Streak
                          Row(
                            children: [
                              Expanded(
                                child: _CyberpunkStatCard(
                                  icon: Icons.shield_outlined,
                                  label: 'LEVEL ${user.level}',
                                  value: '${user.totalStars}',
                                  valueLabel: 'STARS',
                                  color: CyberpunkColors.neonPurple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CyberpunkStatCard(
                                  icon: Icons.local_fire_department,
                                  label: 'STREAK',
                                  value: '${user.currentStreak}',
                                  valueLabel: 'DAYS',
                                  color: CyberpunkColors.neonOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // XP Progress Bar
                          _XpProgressCard(user: user),
                          const SizedBox(height: 16),
                          // Quick Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _CyberpunkButton(
                                  icon: Icons.show_chart,
                                  label: 'Progress',
                                  color: CyberpunkColors.neonMagenta,
                                  onTap: () {
                                    context.push('/progress');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CyberpunkButton(
                                  icon: Icons.emoji_events,
                                  label: 'Leaderboard',
                                  color: CyberpunkColors.neonTeal,
                                  onTap: () {
                                    context.push('/leaderboard');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Friends Section
                          FutureBuilder<List<model_user.User>>(
                            future: () async {
                              final prov = context.read<AppProvider>();
                              final uid = prov.currentUser!.id;
                              final ids = await prov.friendService
                                  .getAcceptedFriendUserIds(uid);
                              return prov.userService.getUsersByIds(ids);
                            }(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              final friends =
                                  snapshot.data ?? const <model_user.User>[];
                              if (friends.isEmpty)
                                return const SizedBox.shrink();

                              return _FriendsSection(friends: friends);
                            },
                          ),
                          const SizedBox(height: 8),
                          // Goals Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GOALS BY STATUS',
                                  style: context.textStyles.labelMedium),
                              Row(
                                children: [
                                  _SmallChipButton(
                                    icon: Icons.help_outline,
                                    label: 'GUIDE',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _SmallChipButton(
                                    icon: Icons.add,
                                    label: 'NEW GOAL',
                                    isPrimary: true,
                                    onTap: () =>
                                        context.push('/create-mission'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Filter Chips
                          _FilterChips(
                            filters: _filters,
                            selectedIndex: _selectedFilter,
                            onSelected: (index) =>
                                setState(() => _selectedFilter = index),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (filteredMissions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_outlined,
                                size: 48, color: CyberpunkColors.neonTeal),
                            const SizedBox(height: 16),
                            Text('NO GOALS HERE',
                                style: context.textStyles.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'No goals in the ${_filters[_selectedFilter]} tab yet.',
                              style: context.textStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final mission = filteredMissions[index];
                            return MissionCard(
                              mission: mission,
                              onTap: () => context.push('/mission-detail',
                                  extra: mission),
                            );
                          },
                          childCount: filteredMissions.length > 5
                              ? 5
                              : filteredMissions.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Mission> _filterMissions(List<Mission> missions) {
    List<Mission> filtered;

    switch (_selectedFilter) {
      case 1: // EXECUTE
        filtered = missions
            .where((m) => m.status == MissionStatus.inProgress)
            .toList();
        break;
      case 2: // EXECUTED
        filtered = missions
            .where((m) =>
                m.status == MissionStatus.completed ||
                m.status == MissionStatus.verified)
            .toList();
        break;
      case 3: // FAILED
        filtered =
            missions.where((m) => m.status == MissionStatus.failed).toList();
        break;
      case 4: // SCHEDULED
        filtered =
            missions.where((m) => m.status == MissionStatus.pending).toList();
        break;
      default:
        filtered = List.from(missions);
        break;
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }
}

class _CyberpunkHeader extends StatelessWidget {
  final dynamic handler;
  final model_user.User user;

  const _CyberpunkHeader({required this.handler, required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // App Logo - Using the ScreenGate logo image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/screengate_logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            // If the asset fails to load, render nothing to avoid any placeholder artifacts
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(width: 44, height: 44),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'TASK',
                    style: context.textStyles.titleLarge!
                        .copyWith(color: AppColors.cream),
                  ),
                  TextSpan(
                    text: 'ASSASSIN',
                    style: context.textStyles.titleLarge!
                        .copyWith(color: AppColors.checkGreen),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Handler Avatar
        Flexible(
          flex: 0,
          child: GestureDetector(
            onTap: () => context.push('/handler-chat'),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.checkGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.checkGreen.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    handler.avatar,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      handler.name.toString().toUpperCase(),
                      style: context.textStyles.labelSmall!.copyWith(
                        color: AppColors.checkGreen,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CyberpunkStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String valueLabel;
  final Color color;

  const _CyberpunkStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: CyberpunkColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: CyberpunkColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textStyles.labelSmall!
                      .copyWith(color: CyberpunkColors.textMuted),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: context.textStyles.headlineSmall!
                          .copyWith(color: color),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      valueLabel,
                      style:
                          context.textStyles.labelSmall!.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpProgressCard extends StatelessWidget {
  final model_user.User user;

  const _XpProgressCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final progress = user.starsInCurrentLevel / user.nextLevelStars;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: CyberpunkColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: CyberpunkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('XP Progress', style: context.textStyles.labelMedium),
              Text(
                '${user.starsInCurrentLevel}/${user.nextLevelStars}',
                style: context.textStyles.labelMedium!
                    .copyWith(color: CyberpunkColors.neonTeal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: CyberpunkColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            CyberpunkColors.neonMagenta,
                            CyberpunkColors.neonTeal
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color:
                                CyberpunkColors.neonTeal.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberpunkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CyberpunkButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.textStyles.labelLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsSection extends StatelessWidget {
  final List<model_user.User> friends;

  const _FriendsSection({required this.friends});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: CyberpunkColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: CyberpunkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 16, color: CyberpunkColors.textMuted),
              const SizedBox(width: 8),
              Text('ACTIVE FRIENDS', style: context.textStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      context.read<AppProvider>().setCurrentTab(2);
                      context.push('/direct-message', extra: friend);
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: CyberpunkColors.border,
                          backgroundImage: friend.avatarUrl != null
                              ? NetworkImage(friend.avatarUrl!)
                              : null,
                          child: friend.avatarUrl == null
                              ? Icon(Icons.person,
                                  color: CyberpunkColors.textMuted)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          friend.codename.toUpperCase(),
                          style: context.textStyles.labelSmall!.copyWith(
                            color: CyberpunkColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SmallChipButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? CyberpunkColors.neonTeal
              : CyberpunkColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isPrimary ? CyberpunkColors.neonTeal : CyberpunkColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isPrimary
                  ? CyberpunkColors.background
                  : CyberpunkColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.textStyles.labelSmall!.copyWith(
                color: isPrimary
                    ? CyberpunkColors.background
                    : CyberpunkColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FilterChips({
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CyberpunkColors.surfaceVariant
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? CyberpunkColors.neonTeal
                        : CyberpunkColors.border,
                  ),
                ),
                child: Text(
                  filters[index],
                  style: context.textStyles.labelSmall!.copyWith(
                    color: isSelected
                        ? CyberpunkColors.textPrimary
                        : CyberpunkColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmailListButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EmailListButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CyberpunkColors.neonTeal, CyberpunkColors.neonPurple],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: CyberpunkColors.neonTeal.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Download the App',
                style: context.textStyles.labelLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InviteFriendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InviteFriendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CyberpunkColors.neonMagenta, CyberpunkColors.neonOrange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: CyberpunkColors.neonMagenta.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Invite a Friend',
                style: context.textStyles.labelLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.share, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DownloadWebAppButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DownloadWebAppButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CyberpunkColors.neonTeal, CyberpunkColors.neonOrange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: CyberpunkColors.neonTeal.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_for_offline_outlined,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Download Webapp',
                style: context.textStyles.labelLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.home_outlined, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
