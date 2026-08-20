import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/theme.dart';

class MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: AppSpacing.verticalSm,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: CyberpunkColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: CyberpunkColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with status and type
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: context.textStyles.titleSmall!.copyWith(
                          color: CyberpunkColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (mission.deadline != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: mission.isOverdue
                                  ? CyberpunkColors.error
                                  : CyberpunkColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Due: ${DateFormat('yyyy-MM-dd').format(mission.deadline!)}',
                              style: context.textStyles.labelSmall!.copyWith(
                                color: mission.isOverdue
                                    ? CyberpunkColors.error
                                    : CyberpunkColors.textMuted,
                              ),
                            ),
                            if (mission.type == MissionType.aiSuggested ||
                                mission.type == MissionType.friendAssigned) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.person,
                                  size: 12, color: CyberpunkColors.neonOrange),
                              const SizedBox(width: 2),
                              Text(
                                'FROM: ${_getTypeText().toUpperCase()}',
                                style: context.textStyles.labelSmall!.copyWith(
                                  color: CyberpunkColors.neonOrange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mission.status == MissionStatus.pending ||
                        mission.status == MissionStatus.inProgress)
                      _ActionButton(
                        label: 'START',
                        color: CyberpunkColors.neonTeal,
                        onTap: onTap,
                      ),
                    if (mission.status == MissionStatus.completed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            icon: Icons.refresh,
                            onTap: () {},
                          ),
                          const SizedBox(width: 4),
                          _ActionButton(
                            label: 'DONE',
                            color: CyberpunkColors.textMuted,
                            onTap: onTap,
                          ),
                        ],
                      ),
                    if (mission.status == MissionStatus.verified)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check,
                              color: CyberpunkColors.neonGreen, size: 16),
                        ],
                      ),
                    const SizedBox(width: 4),
                    _ActionButton(
                      icon: Icons.close,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
            // Stars (if earned)
            if (mission.starsEarned > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < mission.starsEarned
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: CyberpunkColors.neonOrange,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTypeText() {
    switch (mission.type) {
      case MissionType.selfAssigned:
        return 'Self';
      case MissionType.aiSuggested:
        return 'AI';
      case MissionType.friendAssigned:
        return 'Friend';
      case MissionType.recurring:
        return 'Recurring';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    this.label,
    this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CyberpunkColors.cardBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: CyberpunkColors.border),
          ),
          child: Icon(icon, size: 14, color: CyberpunkColors.textMuted),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.15) ?? CyberpunkColors.cardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color ?? CyberpunkColors.border),
        ),
        child: Text(
          label ?? '',
          style: context.textStyles.labelSmall!.copyWith(
            color: color ?? CyberpunkColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
