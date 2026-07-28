import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/services/family_service.dart';
import 'package:taskassassin/services/screen_time_service.dart';

const _ink = Color(0xFF17324D);
const _teal = Color(0xFF0B8F87);
const _mint = Color(0xFFDDF4EE);
const _sun = Color(0xFFFFD166);
const _coral = Color(0xFFFF7A66);
const _paper = Color(0xFFF7FAF9);

String _timeText(int totalSeconds) {
  final safeSeconds = totalSeconds.clamp(0, 86400);
  final minutes = safeSeconds ~/ 60;
  final seconds = safeSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final user = provider.currentUser;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final tabs = user.accountRole == AccountRole.parent
            ? const [
                _ParentHome(),
                _QuestList(isParent: true),
                _FamilyScreen(),
                _SettingsScreen(),
              ]
            : const [
                _ChildHome(),
                _RewardsScreen(),
                _ProgressScreen(),
                _SettingsScreen(),
              ];
        final index = provider.currentTab.clamp(0, tabs.length - 1);
        return ColoredBox(color: _paper, child: tabs[index]);
      },
    );
  }
}

class _ParentHome extends StatefulWidget {
  const _ParentHome();

  @override
  State<_ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<_ParentHome> {
  late Future<List<FamilyChild>> _family = FamilyService().getChildren();
  String? _selectedChildId;
  Timer? _familyTimer;

  @override
  void initState() {
    super.initState();
    _familyTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) {
          setState(() => _family = FamilyService().getChildren());
        }
      },
    );
  }

  @override
  void dispose() {
    _familyTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<AppProvider>().refreshFamilyData();
    if (mounted) {
      setState(() => _family = FamilyService().getChildren());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final name = provider.currentUser!.codename;
    final pending = provider.missions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;

    return _Page(
      title: 'Hi, $name',
      subtitle: 'Your family at a glance',
      trailing: _RoundIcon(
        icon: Icons.notifications_none_rounded,
        onTap: () => context.push('/notifications'),
      ),
      children: [
        FutureBuilder<List<FamilyChild>>(
          future: _family,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _HeroPanel(
                icon: Icons.sync_rounded,
                title: 'Checking your family',
                body: 'Loading the phones connected to Questime.',
                action: 'LOADING',
                onTap: null,
              );
            }
            final children = snapshot.data ?? const <FamilyChild>[];
            if (children.isEmpty) {
              return _HeroPanel(
                icon: Icons.child_care_rounded,
                title: 'Add your child',
                body:
                    'Pair their phone to start quests and screen-time rewards.',
                action: 'PAIR A PHONE',
                onTap: () => _showPairingSoon(context),
              );
            }
            _selectedChildId ??= children.first.id;
            final selected = children.firstWhere(
              (child) => child.id == _selectedChildId,
              orElse: () => children.first,
            );
            final phoneCount = children.fold<int>(
              0,
              (count, child) => count + child.devices.length,
            );
            final selectedMissions = provider.missions
                .where((mission) => mission.userId == selected.id)
                .toList();
            final minutesLeft = (selected.devices.fold<int>(
                      0,
                      (seconds, device) => seconds + device.remainingSeconds,
                    ) /
                    60)
                .ceil();
            final completed = selectedMissions
                .where((mission) =>
                    mission.status == MissionStatus.completed ||
                    mission.status == MissionStatus.verified)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroPanel(
                  icon: Icons.devices_rounded,
                  title:
                      '$phoneCount child ${phoneCount == 1 ? 'phone' : 'phones'} connected',
                  body: 'Choose a child below to see their Questime activity.',
                  action: 'REFRESH',
                  onTap: _refresh,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selected.id,
                  decoration: const InputDecoration(
                    labelText: 'Focus on',
                    prefixIcon: Icon(Icons.child_care_rounded),
                  ),
                  items: children
                      .map((child) => DropdownMenuItem(
                            value: child.id,
                            child: Text(child.name),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedChildId = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        color: _mint,
                        icon: Icons.timer_outlined,
                        value: '$minutesLeft min',
                        label: 'time left',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        color: const Color(0xFFFFF1D0),
                        icon: Icons.task_alt_rounded,
                        value: '$completed/${selectedMissions.length}',
                        label: 'quests done',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _SectionTitle(
          title: 'Needs your attention',
          action: pending == 0 ? null : '$pending waiting',
        ),
        const SizedBox(height: 12),
        _AttentionRow(
          icon: pending == 0 ? Icons.check_circle_rounded : Icons.hourglass_top,
          color: pending == 0 ? _teal : _coral,
          title: pending == 0 ? 'All caught up' : '$pending quests to approve',
          subtitle: pending == 0
              ? 'Completed quests will appear here.'
              : 'Review completed quests and award time.',
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: 'Quick actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.add_task_rounded,
                label: 'New quest',
                color: _teal,
                onTap: () => context.push('/create-mission'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.schedule_rounded,
                label: 'Set limits',
                color: _coral,
                onTap: () => _showLimitsDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChildHome extends StatelessWidget {
  const _ChildHome();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final missions = provider.missions
        .where((mission) => mission.status != MissionStatus.verified)
        .toList();
    return _Page(
      title: 'Hey, ${provider.currentUser!.codename}!',
      subtitle: missions.isEmpty
          ? 'You are ready for a new quest.'
          : 'Pick one quest to start.',
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAY TIME',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text(_timeText(provider.availableRewardSeconds),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Icon(Icons.sports_esports_rounded, color: _sun, size: 52),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: "Today's quests"),
        const SizedBox(height: 12),
        if (missions.isEmpty)
          const _EmptyState(
            icon: Icons.celebration_rounded,
            title: 'No quests yet',
            body: 'Ask your parent to send your first quest.',
          )
        else
          ...missions.take(4).map((mission) => _QuestRow(mission: mission)),
      ],
    );
  }
}

class _QuestList extends StatelessWidget {
  final bool isParent;
  const _QuestList({required this.isParent});

  @override
  Widget build(BuildContext context) {
    final missions = context.watch<AppProvider>().missions;
    return _Page(
      title: isParent ? 'Quests' : 'Today',
      subtitle: isParent
          ? 'Small wins earn meaningful time.'
          : 'Finish a quest. Earn your time.',
      trailing: isParent
          ? _RoundIcon(
              icon: Icons.add_rounded,
              onTap: () => context.push('/create-mission'))
          : null,
      children: [
        if (missions.isEmpty)
          _EmptyState(
            icon: Icons.checklist_rounded,
            title: isParent ? 'Make the first quest' : 'Nothing here yet',
            body: isParent
                ? 'Choose one clear task your child can finish today.'
                : 'Your parent will add a quest for you.',
            action: isParent ? 'CREATE A QUEST' : null,
            onTap: isParent ? () => context.push('/create-mission') : null,
          )
        else
          ...missions.map((mission) => _QuestRow(mission: mission)),
      ],
    );
  }
}

class _FamilyScreen extends StatelessWidget {
  const _FamilyScreen();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Family',
      subtitle: 'The phones connected to Questime',
      children: [
        FutureBuilder<List<FamilyChild>>(
          future: FamilyService().getChildren(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final children = snapshot.data!;
            if (children.isEmpty) {
              return const _EmptyState(
                icon: Icons.family_restroom_rounded,
                title: 'Add your child',
                body: 'Install Questime on their phone, then pair it here.',
              );
            }
            return Column(
              children: children.expand((child) {
                if (child.devices.isEmpty) {
                  return [
                    _AttentionRow(
                      icon: Icons.phone_iphone_rounded,
                      color: _coral,
                      title: child.name,
                      subtitle: 'Paired, waiting for phone details',
                      actionIcon: Icons.key_rounded,
                      onAction: () => _showChildRecoveryCode(context, child),
                    )
                  ];
                }
                return child.devices.map((device) => _AttentionRow(
                      icon: device.platform == 'android'
                          ? Icons.android_rounded
                          : Icons.phone_iphone_rounded,
                      color: device.screenTimeAuthorized ? _teal : _coral,
                      title: '${child.name} · ${device.name}',
                      subtitle: device.screenTimeAuthorized
                          ? 'Screen time ready'
                          : 'Needs screen time setup',
                      actionIcon: Icons.key_rounded,
                      onAction: () => _showChildRecoveryCode(context, child),
                    ));
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showPairingSoon(context),
            icon: const Icon(Icons.link_rounded),
            label: const Text('PAIR A CHILD PHONE'),
          ),
        ),
      ],
    );
  }
}

class _RewardsScreen extends StatelessWidget {
  const _RewardsScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final minutes = provider.availableRewardMinutes;
    final time = _timeText(provider.availableRewardSeconds);
    return _Page(
      title: 'Rewards',
      subtitle: 'Time you earned by finishing quests',
      children: [
        _EmptyState(
          icon:
              minutes > 0 ? Icons.sports_esports_rounded : Icons.stars_rounded,
          title: minutes > 0 ? '$time ready' : 'No play time yet',
          body: minutes > 0
              ? 'Your approved quest time is ready to use.'
              : 'Finish a quest and ask your parent to approve it.',
        ),
      ],
    );
  }
}

class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final missions = provider.missions;
    final finished = missions
        .where((mission) =>
            mission.status == MissionStatus.verified ||
            mission.status == MissionStatus.completed ||
            mission.status == MissionStatus.failed)
        .toList();
    final stars = finished.fold<double>(
      0,
      (total, mission) => total + mission.starsEarned,
    );
    final passed =
        missions.where((mission) => mission.status == MissionStatus.verified);
    final completionRate = missions.isEmpty
        ? 0
        : ((passed.length / missions.length) * 100).round();
    return _Page(
      title: 'My progress',
      subtitle: 'Every finished quest counts',
      children: [
        Row(
          children: [
            Expanded(
                child: _Metric(
                    color: _mint,
                    icon: Icons.star_rounded,
                    value: stars.toStringAsFixed(
                        stars == stars.roundToDouble() ? 0 : 1),
                    label: 'stars')),
            const SizedBox(width: 12),
            Expanded(
                child: _Metric(
                    color: const Color(0xFFFFE5DF),
                    icon: Icons.task_alt_rounded,
                    value: '${finished.length}',
                    label: 'finished')),
          ],
        ),
        const SizedBox(height: 12),
        _AttentionRow(
          icon: Icons.insights_rounded,
          color: _teal,
          title: '$completionRate% of quests passed',
          subtitle: missions.isEmpty
              ? 'Your progress will appear after your first quest.'
              : '${passed.length} passed out of ${missions.length} total quests',
        ),
        if (finished.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Recent results'),
          const SizedBox(height: 10),
          ...finished.take(5).map(
                (mission) => _AttentionRow(
                  icon: mission.status == MissionStatus.verified
                      ? Icons.star_rounded
                      : Icons.hourglass_top_rounded,
                  color:
                      mission.status == MissionStatus.verified ? _sun : _coral,
                  title: mission.title,
                  subtitle: mission.starsEarned > 0
                      ? '${mission.starsEarned.toStringAsFixed(1)} stars'
                      : 'Waiting for approval',
                ),
              ),
        ],
      ],
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser!;
    return _Page(
      title: 'Settings',
      subtitle: user.email,
      children: [
        _SettingsRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: user.codename),
        _SettingsRow(
            icon: Icons.family_restroom_rounded,
            label: 'Account',
            value: user.accountRole == AccountRole.parent ? 'Parent' : 'Child'),
        if (user.accountRole == AccountRole.child) ...[
          const SizedBox(height: 20),
          const _ScreenTimeSetup(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.read<AppProvider>().signOut();
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('SIGN OUT'),
          ),
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;
  const _Page(
      {required this.title,
      required this.subtitle,
      required this.children,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Color(0xFF617384), fontSize: 16)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onTap;
  const _HeroPanel(
      {required this.icon,
      required this.title,
      required this.body,
      required this.action,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _teal, size: 36),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: Color(0xFF4F6972), fontSize: 15, height: 1.4)),
          const SizedBox(height: 18),
          FilledButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;
  const _Metric(
      {required this.color,
      required this.icon,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink, size: 26),
          const SizedBox(height: 18),
          Text(value,
              style: const TextStyle(
                  color: _ink, fontSize: 26, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Color(0xFF526879), fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionTitle({required this.title, this.action});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: _ink, fontSize: 19, fontWeight: FontWeight.w800))),
          if (action != null)
            Text(action!,
                style:
                    const TextStyle(color: _teal, fontWeight: FontWeight.w700)),
        ],
      );
}

class _AttentionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  const _AttentionRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      this.actionIcon,
      this.onAction});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE5E5))),
        child: Row(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF667684), fontSize: 13)),
              ])),
          if (onAction != null)
            IconButton(
              tooltip: 'Child login code',
              onPressed: onAction,
              icon: Icon(actionIcon),
            ),
        ]),
      );
}

Future<void> _showChildRecoveryCode(BuildContext context, FamilyChild child,
    {bool rotate = false}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => FutureBuilder<ChildRecoveryCode>(
      future: FamilyService().createChildRecoveryCode(child.id, rotate: rotate),
      builder: (context, snapshot) => AlertDialog(
        title: Text('${child.name}’s child code'),
        content: snapshot.connectionState != ConnectionState.done
            ? const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()))
            : snapshot.hasError
                ? const Text('Could not make a code. Please try again.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.data!.code,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Use this after reinstalling or signing out. Making a new code replaces the old one.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
        actions: [
          if (snapshot.hasData)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showChildRecoveryCode(context, child, rotate: true);
              },
              child: const Text('NEW CODE'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('DONE')),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap ??
            () => context
                .push(label == 'New quest' ? '/create-mission' : '/home'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE5E5))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 18),
            Text(label,
                style:
                    const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _QuestRow extends StatelessWidget {
  final Mission mission;
  const _QuestRow({required this.mission});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final canApprove =
        provider.currentUser?.accountRole == AccountRole.parent &&
            mission.status == MissionStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/mission-detail', extra: mission),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE5E5))),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _mint, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_rounded, color: _teal)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(mission.title,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      '${mission.rewardMinutes} min reward • ${mission.status.name}',
                      style: const TextStyle(color: Color(0xFF667684))),
                ])),
            if (canApprove)
              FilledButton(
                onPressed: () async {
                  await context.read<AppProvider>().approveMission(mission.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text('${mission.rewardMinutes} minutes approved'),
                    ));
                  }
                },
                child: const Text('APPROVE'),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A9AA6)),
          ]),
        ),
      ),
    );
  }
}

class _ScreenTimeSetup extends StatefulWidget {
  const _ScreenTimeSetup();
  @override
  State<_ScreenTimeSetup> createState() => _ScreenTimeSetupState();
}

class _ScreenTimeSetupState extends State<_ScreenTimeSetup> {
  late Future<ScreenTimeStatus> _status = ScreenTimeService().status();
  List<ControlledApp> _apps = const [];
  Set<String> _selectedPackages = {};
  int _remainingSeconds = 0;
  bool _loadingApps = true;
  Timer? _balanceTimer;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
    _balanceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshBalance(),
    );
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    try {
      final configuration = await ScreenTimeService().getConfiguration();
      if (mounted && configuration.remainingSeconds != _remainingSeconds) {
        setState(() => _remainingSeconds = configuration.remainingSeconds);
      }
    } catch (_) {
      // The setup card remains usable while Android is changing permissions.
    }
  }

  Future<void> _loadConfiguration() async {
    try {
      final results = await Future.wait([
        ScreenTimeService().getInstalledApps(),
        ScreenTimeService().getConfiguration(),
      ]);
      if (!mounted) return;
      final configuration = results[1] as ScreenTimeConfiguration;
      setState(() {
        _apps = results[0] as List<ControlledApp>;
        _selectedPackages = configuration.packages;
        _remainingSeconds = configuration.remainingSeconds;
        _loadingApps = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _enable() async {
    await ScreenTimeService().requestAuthorization();
    if (mounted) setState(() => _status = ScreenTimeService().status());
  }

  Future<void> _checkAgain() async {
    setState(() => _status = ScreenTimeService().status());
    await _loadConfiguration();
  }

  Future<void> _chooseApps() async {
    if (_apps.isEmpty) return;
    final draft = Set<String>.from(_selectedPackages);
    final saved = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose play apps'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _apps
                  .map(
                    (app) => CheckboxListTile(
                      value: draft.contains(app.packageName),
                      title: Text(app.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (selected) => setDialogState(() {
                        if (selected == true) {
                          draft.add(app.packageName);
                        } else {
                          draft.remove(app.packageName);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, draft),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await ScreenTimeService().configureAndroid(
        packages: saved,
        awardedMinutes: context.read<AppProvider>().availableRewardMinutes,
      );
      await _loadConfiguration();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save play apps: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScreenTimeStatus>(
        future: _status,
        builder: (context, snapshot) {
          final status = snapshot.data;
          if (status?.platform != 'android') {
            return _EmptyState(
              icon: status?.authorized == true
                  ? Icons.verified_user_rounded
                  : Icons.phonelink_lock_rounded,
              title: status?.authorized == true
                  ? 'Screen Time is ready'
                  : 'Turn on Screen Time',
              body:
                  'A parent must approve Apple Family Controls on this iPhone.',
              action: status?.authorized == true ? null : 'TURN ON',
              onTap: status?.authorized == true ? null : _enable,
            );
          }

          final chosenNames = _apps
              .where((app) => _selectedPackages.contains(app.packageName))
              .map((app) => app.name)
              .take(3)
              .join(', ');
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Play app limits',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _SetupStep(
                  number: '1',
                  title: _selectedPackages.isEmpty
                      ? 'Choose play apps'
                      : '${_selectedPackages.length} apps chosen',
                  detail: chosenNames.isEmpty
                      ? 'Pick a game or video app to test.'
                      : chosenNames,
                  complete: _selectedPackages.isNotEmpty,
                  action: _loadingApps ? null : _chooseApps,
                  actionLabel: _selectedPackages.isEmpty ? 'CHOOSE' : 'CHANGE',
                ),
                const SizedBox(height: 14),
                _SetupStep(
                  number: '2',
                  title: status?.authorized == true
                      ? 'Phone permission is on'
                      : 'Turn on Questime',
                  detail: status?.authorized == true
                      ? 'Questime can now stop selected apps.'
                      : 'On the next screen, tap Questime and turn it on.',
                  complete: status?.authorized == true,
                  action: status?.authorized == true ? _checkAgain : _enable,
                  actionLabel: status?.authorized == true ? 'CHECK' : 'TURN ON',
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _mint,
                  child: Text(
                    '${_timeText(_remainingSeconds)} available on this phone',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String title;
  final String detail;
  final bool complete;
  final VoidCallback? action;
  final String actionLabel;

  const _SetupStep({
    required this.number,
    required this.title,
    required this.detail,
    required this.complete,
    required this.action,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: complete ? _teal : const Color(0xFFE8EEEE),
            foregroundColor: complete ? Colors.white : _ink,
            child: complete
                ? const Icon(Icons.check_rounded, size: 20)
                : Text(number,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail, style: const TextStyle(color: Color(0xFF667684))),
              ],
            ),
          ),
          TextButton(onPressed: action, child: Text(actionLabel)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onTap;
  const _EmptyState(
      {required this.icon,
      required this.title,
      required this.body,
      this.action,
      this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE5E5))),
        child: Column(children: [
          Icon(icon, size: 48, color: _teal),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667684), height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onTap, child: Text(action!))
          ],
        ]),
      );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDDE5E5)))),
        child: Row(children: [
          Icon(icon, color: _teal),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _ink, fontSize: 16, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(color: Color(0xFF667684))),
        ]),
      );
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      IconButton.filledTonal(onPressed: onTap, icon: Icon(icon, color: _ink));
}

void _showPairingSoon(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _PairingCodeDialog(),
  );
}

void _showLimitsDialog(BuildContext context) {
  showDialog<void>(context: context, builder: (_) => const _LimitsDialog());
}

class _LimitsDialog extends StatefulWidget {
  const _LimitsDialog();
  @override
  State<_LimitsDialog> createState() => _LimitsDialogState();
}

class _LimitsDialogState extends State<_LimitsDialog> {
  late final Future<List<FamilyChild>> _children =
      FamilyService().getChildren();
  FamilyChild? _child;
  double _dailyLimit = 90;
  int _reward = 15;
  bool _saving = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Screen time limits'),
        content: FutureBuilder<List<FamilyChild>>(
          future: _children,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final children = snapshot.data!;
            _child ??= children.isEmpty ? null : children.first;
            if (children.isEmpty) {
              return const Text('Pair a child phone first.');
            }
            return StatefulBuilder(builder: (context, update) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<FamilyChild>(
                  initialValue: _child,
                  decoration: const InputDecoration(labelText: 'Child'),
                  items: children
                      .map((child) => DropdownMenuItem(
                          value: child, child: Text(child.name)))
                      .toList(),
                  onChanged: (value) => update(() => _child = value),
                ),
                const SizedBox(height: 18),
                Text('${_dailyLimit.round()} minutes each day'),
                Slider(
                  value: _dailyLimit,
                  min: 0,
                  max: 240,
                  divisions: 16,
                  label: '${_dailyLimit.round()} min',
                  onChanged: (value) => update(() => _dailyLimit = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _reward,
                  decoration:
                      const InputDecoration(labelText: 'Default quest reward'),
                  items: const [10, 15, 20, 30, 45, 60]
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('$value minutes')))
                      .toList(),
                  onChanged: (value) => update(() => _reward = value ?? 15),
                ),
              ]);
            });
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          FilledButton(
            onPressed: _saving || _child == null
                ? null
                : () async {
                    setState(() => _saving = true);
                    await FamilyService().saveScreenTimeRule(
                      childUserId: _child!.id,
                      dailyLimitMinutes: _dailyLimit.round(),
                      rewardMinutes: _reward,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('SAVE'),
          ),
        ],
      );
}

class _PairingCodeDialog extends StatefulWidget {
  const _PairingCodeDialog();

  @override
  State<_PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<_PairingCodeDialog> {
  late Future<FamilyPairingCode> _code;

  @override
  void initState() {
    super.initState();
    _code = FamilyService().createPairingCode();
  }

  void _refresh() {
    setState(() => _code = FamilyService().createPairingCode());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Pair the child phone',
        style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
      ),
      content: FutureBuilder<FamilyPairingCode>(
        future: _code,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return SizedBox(
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not make a code.',
                      style: TextStyle(color: _ink)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _refresh, child: const Text('TRY AGAIN')),
                ],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Type this code on the Child Phone:',
                style: TextStyle(color: Color(0xFF667684)),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snapshot.data!.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'This code works once and expires in 15 minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667684), fontSize: 13),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('DONE')),
      ],
    );
  }
}
