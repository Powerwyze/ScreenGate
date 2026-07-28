import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/theme.dart';
import 'package:taskassassin/services/family_service.dart';

class CreateMissionScreen extends StatefulWidget {
  const CreateMissionScreen({super.key, this.assignee});

  /// Optional friend to assign this mission to.
  final User? assignee;

  @override
  State<CreateMissionScreen> createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _completedStateController = TextEditingController();
  DateTime? _deadline;
  MissionType _type = MissionType.selfAssigned;
  User? _assignee;
  List<FamilyChild> _children = const [];
  FamilyChild? _selectedChild;
  int _rewardMinutes = 15;
  bool _loadingChildren = true;

  @override
  void initState() {
    super.initState();
    _assignee = widget.assignee;
    if (_assignee != null) {
      _type = MissionType.friendAssigned;
    }
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final children = await FamilyService().getChildren();
      if (!mounted) return;
      setState(() {
        _children = children;
        _selectedChild = children.isEmpty ? null : children.first;
        _loadingChildren = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _completedStateController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  Future<void> _createMission() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final isParent = user.accountRole == AccountRole.parent;
    if (isParent && _selectedChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair a child phone first.')),
      );
      return;
    }
    final targetUserId = _selectedChild?.id ?? _assignee?.id ?? user.id;
    final isAssignment = targetUserId != user.id;
    final missionType = isAssignment ? MissionType.friendAssigned : _type;

    try {
      final mission = await provider.missionService.createMission(
        userId: targetUserId,
        title: _titleController.text,
        description: _descriptionController.text,
        completedState: _completedStateController.text,
        type: missionType,
        deadline: _deadline,
        assignedByUserId: isAssignment ? user.id : null,
        assignedToUserId: isAssignment ? targetUserId : null,
        rewardMinutes: _rewardMinutes,
      );

      if (mission.userId == user.id) {
        await provider.addMission(mission);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAssignment
                  ? 'Quest sent to ${_selectedChild?.name ?? _assignee?.codename ?? 'child'}'
                  : 'Quest created',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating mission: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Quest'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (context.read<AppProvider>().currentUser?.accountRole ==
                  AccountRole.parent) ...[
                if (_loadingChildren)
                  const LinearProgressIndicator()
                else if (_children.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.link_off_rounded),
                    title: Text('No child phone paired'),
                    subtitle: Text('Pair a child from the Family tab first.'),
                  )
                else
                  DropdownButtonFormField<FamilyChild>(
                    initialValue: _selectedChild,
                    decoration: const InputDecoration(
                      labelText: 'Who is this quest for?',
                      prefixIcon: Icon(Icons.child_care_rounded),
                    ),
                    items: _children
                        .map((child) => DropdownMenuItem(
                              value: child,
                              child: Text(child.name),
                            ))
                        .toList(),
                    onChanged: (child) =>
                        setState(() => _selectedChild = child),
                  ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'What needs to be done?',
                  hintText: 'e.g., Clean the garage',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What needs to be done?',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _completedStateController,
                decoration: InputDecoration(
                  labelText: 'Completed State',
                  hintText: 'How will you know it\'s done?',
                  prefixIcon: const Icon(Icons.check_circle),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _rewardMinutes,
                decoration: const InputDecoration(
                  labelText: 'Screen time reward',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [10, 15, 20, 30, 45, 60]
                    .map((minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minutes'),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _rewardMinutes = value ?? 15),
              ),
              const SizedBox(height: 16),
              if (_assignee != null) ...[
                ListTile(
                  tileColor: CyberpunkColors.surfaceVariant,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  leading: const Icon(Icons.person_add_alt),
                  title: Text('Assigning to ${_assignee!.codename}'),
                  subtitle: Text('They will receive this mission'),
                ),
                const SizedBox(height: 16),
              ],
              InkWell(
                onTap: _selectDeadline,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Deadline (Optional)',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: Text(
                    _deadline == null
                        ? 'Select deadline'
                        : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _createMission,
                child: const Padding(
                  padding: AppSpacing.paddingMd,
                  child: Text('Create Quest'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
