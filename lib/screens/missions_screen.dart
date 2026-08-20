import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/theme.dart';
import 'package:screengate/widgets/mission_card.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  MissionStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-mission'),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          var missions = provider.missions;
          if (_filterStatus != null) {
            missions =
                missions.where((m) => m.status == _filterStatus).toList();
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.horizontalMd,
                child: Row(
                  children: [
                    _buildFilterChip('All', _filterStatus == null),
                    _buildFilterChip(
                        'Pending', _filterStatus == MissionStatus.pending),
                    _buildFilterChip('In Progress',
                        _filterStatus == MissionStatus.inProgress),
                    _buildFilterChip(
                        'Completed', _filterStatus == MissionStatus.completed),
                    _buildFilterChip(
                        'Verified', _filterStatus == MissionStatus.verified),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: missions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📋', style: context.textStyles.displayMedium),
                            const SizedBox(height: 16),
                            Text(
                              'No missions found',
                              style: context.textStyles.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a mission to get started',
                              style: context.textStyles.bodyMedium!.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: AppSpacing.paddingMd,
                        itemCount: missions.length,
                        itemBuilder: (context, index) {
                          final mission = missions[index];
                          return MissionCard(
                            mission: mission,
                            onTap: () =>
                                context.push('/mission-detail', extra: mission),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: AppSpacing.horizontalXs,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (label == 'All') {
              _filterStatus = null;
            } else {
              _filterStatus = MissionStatus.values.firstWhere(
                (s) =>
                    s.name.toLowerCase().replaceAll('_', ' ') ==
                    label.toLowerCase(),
                orElse: () => MissionStatus.pending,
              );
            }
          });
        },
      ),
    );
  }
}
