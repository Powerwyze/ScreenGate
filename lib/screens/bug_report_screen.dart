import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/bug_report.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/theme.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  BugSeverity _severity = BugSeverity.medium;
  bool _isSubmitting = false;

  String _getDeviceInfo() {
    if (kIsWeb) return 'Web';
    return defaultTargetPlatform.name;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<AppProvider>();
      await provider.bugReportService.submitBugReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _severity,
        deviceInfo: _getDeviceInfo(),
        appVersion: '1.0.0',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bug report submitted successfully! Thank you for your feedback.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting bug report: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Help us improve ScreenGate by reporting bugs or issues you encounter.',
                        style: context.textStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Bug Title',
                  style: context.textStyles.titleMedium!.semiBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Brief description of the issue',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('Severity', style: context.textStyles.titleMedium!.semiBold),
              const SizedBox(height: 8),
              SegmentedButton<BugSeverity>(
                segments: const [
                  ButtonSegment(
                    value: BugSeverity.low,
                    label: Text('Low'),
                    icon: Icon(Icons.info_outline),
                  ),
                  ButtonSegment(
                    value: BugSeverity.medium,
                    label: Text('Medium'),
                    icon: Icon(Icons.warning_amber),
                  ),
                  ButtonSegment(
                    value: BugSeverity.high,
                    label: Text('High'),
                    icon: Icon(Icons.error_outline),
                  ),
                  ButtonSegment(
                    value: BugSeverity.critical,
                    label: Text('Critical'),
                    icon: Icon(Icons.report),
                  ),
                ],
                selected: {_severity},
                onSelectionChanged: (Set<BugSeverity> newSelection) {
                  setState(() => _severity = newSelection.first);
                },
              ),
              const SizedBox(height: 24),
              Text('Description',
                  style: context.textStyles.titleMedium!.semiBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Please describe the bug in detail:\n\n• What were you trying to do?\n• What happened?\n• What did you expect to happen?\n• Steps to reproduce (if applicable)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 20) {
                    return 'Please provide more details (at least 20 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitBugReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Bug Report'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
