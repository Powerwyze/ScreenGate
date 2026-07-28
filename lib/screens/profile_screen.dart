import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/theme.dart';
import 'package:taskassassin/models/achievement.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taskassassin/services/image_upload_service.dart';
import 'package:taskassassin/services/mission_service.dart';
import 'package:taskassassin/services/parent_gate_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _creatingWelcomeMission = false;
  final _picker = ImagePicker();

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    try {
      final picked = await _picker.pickImage(
          source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (picked == null) return;
      setState(() => _uploadingAvatar = true);

      final bytes = await picked.readAsBytes();
      final provider = context.read<AppProvider>();
      final user = provider.currentUser;
      if (user == null) {
        throw Exception('User not found. Please sign in again.');
      }

      final url = await ImageUploadService.instance
          .uploadUserAvatar(userId: user.id, bytes: bytes);

      await provider.userService.updateUser(user.copyWith(avatarUrl: url));
      await provider.refreshUser();
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _createWelcomeMission() async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    setState(() => _creatingWelcomeMission = true);
    try {
      final missionService = MissionService();
      await missionService.createWelcomeMission(user.id);
      await provider.loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Welcome mission created! Check your missions.')),
        );
      }
    } catch (e) {
      debugPrint('Welcome mission creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create welcome mission: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingWelcomeMission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                final provider = context.read<AppProvider>();
                final user = provider.currentUser;
                if (user == null) return;
                final unlocked = await requireParentPassword(
                  context,
                  email: user.email,
                  action: 'sign out',
                );
                if (!unlocked || !context.mounted) return;
                await provider.signOut();
                if (context.mounted) context.go('/auth');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign out failed')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => context.push('/bug-report'),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final user = provider.currentUser;
          final handler = provider.currentHandler;
          if (user == null) {
            if (provider.isAuthenticated) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Create your profile to view this page',
                        style: context.textStyles.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We couldn\'t find your profile. Tap below to finish onboarding.',
                        style: context.textStyles.bodyMedium!.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.go('/onboarding'),
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('Finish Onboarding'),
                      )
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (handler == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            backgroundImage: (provider.currentUser?.avatarUrl !=
                                    null)
                                ? NetworkImage(provider.currentUser!.avatarUrl!)
                                : null,
                            child: (provider.currentUser?.avatarUrl == null)
                                ? Text(
                                    handler.avatar,
                                    style: const TextStyle(fontSize: 36),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                padding: const EdgeInsets.all(6),
                              ),
                              icon: _uploadingAvatar
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_camera, size: 18),
                              onPressed:
                                  _uploadingAvatar ? null : _changeAvatar,
                              tooltip: 'Update profile photo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(user.codename,
                          style: context.textStyles.headlineMedium!.bold),
                      const SizedBox(height: 4),
                      Text(
                        'Level ${user.level} Agent',
                        style: context.textStyles.titleMedium!.withColor(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow(context, 'Total Stars',
                          user.totalStars.toString(), Icons.star),
                      const Divider(height: 24),
                      _buildStatRow(
                          context,
                          'Current Streak',
                          '${user.currentStreak} days',
                          Icons.local_fire_department),
                      const Divider(height: 24),
                      _buildStatRow(context, 'Longest Streak',
                          '${user.longestStreak} days', Icons.emoji_events),
                      const Divider(height: 24),
                      _buildStatRow(
                          context,
                          'Next Level',
                          '${user.starsInCurrentLevel}/${user.nextLevelStars} stars',
                          Icons.trending_up),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Handler', style: context.textStyles.titleLarge!.bold),
                    TextButton(
                      onPressed: () => context.push('/handler-selection'),
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Text(handler.avatar,
                          style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(handler.name,
                                style:
                                    context.textStyles.titleMedium!.semiBold),
                            const SizedBox(height: 4),
                            Text(
                              handler.category,
                              style: context.textStyles.bodySmall!.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Admin-only button to create welcome mission
                if (user.email == MissionService.adminEmail) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _creatingWelcomeMission
                          ? null
                          : _createWelcomeMission,
                      icon: _creatingWelcomeMission
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.rocket_launch),
                      label: const Text('Create Welcome Mission (Test)'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text('Life Goals', style: context.textStyles.titleLarge!.bold),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    user.lifeGoals,
                    style: context.textStyles.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
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
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: achievements.map((achievement) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            children: [
                              Text(achievement.icon,
                                  style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 4),
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

  Widget _buildStatRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: context.textStyles.bodyMedium),
        ),
        Text(value, style: context.textStyles.titleMedium!.semiBold),
      ],
    );
  }
}
