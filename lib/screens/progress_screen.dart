import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/models/achievement.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/theme.dart';
import 'package:screengate/widgets/stat_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final user = provider.currentUser;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final missions = provider.missions;
          final completedCount = missions
              .where((m) =>
                  m.status == MissionStatus.completed ||
                  m.status == MissionStatus.verified)
              .length;
          final activeCount = missions
              .where((m) =>
                  m.status == MissionStatus.inProgress ||
                  m.status == MissionStatus.pending)
              .length;
          final failedCount =
              missions.where((m) => m.status == MissionStatus.failed).length;

          return RefreshIndicator(
            color: CyberpunkColors.neonTeal,
            backgroundColor: CyberpunkColors.surface,
            onRefresh: () async {
              await provider.refreshUser();
              await provider.loadMissions();
            },
            child: ListView(
              padding: AppSpacing.paddingLg,
              children: [
                Text(
                  'Your Progress',
                  style: context.textStyles.headlineSmall!.bold,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track milestones, streaks, and stars in one place.',
                  style: context.textStyles.bodyMedium!
                      .withColor(CyberpunkColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.star,
                        label: 'TOTAL STARS',
                        value: '${user.totalStars}',
                        color: CyberpunkColors.neonOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_fire_department,
                        label: 'CURRENT STREAK',
                        value: '${user.currentStreak} days',
                        color: CyberpunkColors.neonTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.emoji_events_outlined,
                        label: 'LONGEST STREAK',
                        value: '${user.longestStreak} days',
                        color: CyberpunkColors.neonPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.shield_outlined,
                        label: 'LEVEL',
                        value: 'Lv. ${user.level}',
                        color: CyberpunkColors.neonMagenta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _XpProgressCard(
                    userStars: user.starsInCurrentLevel,
                    nextLevelStars: user.nextLevelStars),
                const SizedBox(height: 20),
                _MissionSummary(
                    active: activeCount,
                    completed: completedCount,
                    failed: failedCount),
                const SizedBox(height: 20),
                Text('Achievements',
                    style: context.textStyles.titleLarge!.bold),
                const SizedBox(height: 12),
                FutureBuilder<List<Achievement>>(
                  future: provider.achievementService.getAllAchievements(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final achievements = snapshot.data!.take(6).toList();
                    if (achievements.isEmpty) {
                      return Text(
                        'No achievements yet. Keep completing missions!',
                        style: context.textStyles.bodyMedium!
                            .withColor(CyberpunkColors.textSecondary),
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: achievements.map((achievement) {
                        return Container(
                          width: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: CyberpunkColors.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(achievement.icon,
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                achievement.name,
                                style: context.textStyles.labelSmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _XpProgressCard extends StatelessWidget {
  final int userStars;
  final int nextLevelStars;

  const _XpProgressCard(
      {required this.userStars, required this.nextLevelStars});

  @override
  Widget build(BuildContext context) {
    final progress = nextLevelStars == 0 ? 0.0 : userStars / nextLevelStars;

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
              Text('XP to next level', style: context.textStyles.labelMedium),
              Text(
                '$userStars/$nextLevelStars',
                style: context.textStyles.labelMedium!
                    .copyWith(color: CyberpunkColors.neonTeal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: CyberpunkColors.border),
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

class _MissionStatBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MissionStatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: context.textStyles.headlineSmall!
                  .copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.textStyles.labelMedium!
                  .withColor(CyberpunkColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionSummary extends StatelessWidget {
  final int active;
  final int completed;
  final int failed;

  const _MissionSummary(
      {required this.active, required this.completed, required this.failed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Missions', style: context.textStyles.titleLarge!.bold),
            Text('Total ${active + completed + failed}',
                style: context.textStyles.labelMedium!
                    .withColor(CyberpunkColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MissionStatBox(
                label: 'Active',
                value: active,
                color: CyberpunkColors.neonTeal),
            const SizedBox(width: 12),
            _MissionStatBox(
                label: 'Completed',
                value: completed,
                color: CyberpunkColors.neonOrange),
            const SizedBox(width: 12),
            _MissionStatBox(
                label: 'Failed',
                value: failed,
                color: CyberpunkColors.neonMagenta),
          ],
        ),
      ],
    );
  }
}
