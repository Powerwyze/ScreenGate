import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
// Storage upload is centralized in ImageUploadService
import 'package:taskassassin/services/image_upload_service.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/theme.dart';
import 'package:intl/intl.dart';
// Removed heavy image manipulation; reusing reliable avatar upload pipeline

enum _PickSource { camera, gallery }

// Note: If we want to reintroduce stamping later, we can add an optional
// transformer here. For now, we prioritize reliability and reuse the
// known-good avatar upload pipeline.

class MissionDetailScreen extends StatefulWidget {
  final Mission mission;

  const MissionDetailScreen({super.key, required this.mission});

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  late Mission _mission;
  final _imagePicker = ImagePicker();
  bool _isVerifying = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
  }

  Future<void> _addPhoto(bool isBefore) async {
    // Let user choose Camera or Upload
    final choice = await showModalBottomSheet<_PickSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, _PickSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Upload from Gallery'),
                onTap: () => Navigator.pop(context, _PickSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;
    if (choice == _PickSource.camera) {
      await _capturePhoto(isBefore);
    } else {
      await _uploadFromGallery(isBefore);
    }
  }

  Future<void> _capturePhoto(bool isBefore) async {
    try {
      // On mobile, request camera permission before opening the camera.
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status.isPermanentlyDenied
                    ? 'Camera permission permanently denied. Enable it in Settings to take photos.'
                    : 'Camera permission denied.'),
                action: status.isPermanentlyDenied
                    ? SnackBarAction(
                        label: 'Open Settings',
                        onPressed: openAppSettings,
                      )
                    : null,
              ),
            );
          }
          return;
        }
      }

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;
      await _processAndUpload(image, isBefore);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<void> _uploadFromGallery(bool isBefore) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;
      await _processAndUpload(image, isBefore);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _processAndUpload(XFile image, bool isBefore) async {
    try {
      setState(() => _isUploading = true);
      final provider = context.read<AppProvider>();

      // Read bytes and upload using the same reliable flow as profile avatar
      final bytes = await image.readAsBytes();
      debugPrint('[MissionDetail] Picked image bytes: ${bytes.length}');
      debugPrint(
          '[MissionDetail] Platform kIsWeb=$kIsWeb, isBefore=$isBefore, missionId=${_mission.id}');

      final downloadUrl = await ImageUploadService.instance.uploadMissionPhoto(
        missionId: _mission.id,
        isBefore: isBefore,
        bytes: bytes,
      );
      debugPrint('[MissionDetail] Uploaded. URL length: ${downloadUrl.length}');

      debugPrint('[MissionDetail] Updating mission photos in Firestore...');
      await provider.missionService.updateMissionPhotos(
        missionId: _mission.id,
        beforePhotoUrl: isBefore ? downloadUrl : null,
        afterPhotoUrl: !isBefore ? downloadUrl : null,
      );
      debugPrint(
          '[MissionDetail] Firestore mission photo update complete. Refreshing mission...');

      final updated = await provider.missionService.getMissionById(_mission.id);
      if (updated != null) {
        setState(() => _mission = updated);
        await provider.updateMission(updated);
        debugPrint(
            '[MissionDetail] Mission refreshed. beforeUrl=${updated.beforePhotoUrl?.substring(0, math.min(updated.beforePhotoUrl?.length ?? 0, 40))}... afterUrl=${updated.afterPhotoUrl?.substring(0, math.min(updated.afterPhotoUrl?.length ?? 0, 40))}...');
      }

      if (!isBefore && _mission.beforePhotoUrl != null) {
        _showVerifyDialog();
      }
    } catch (e) {
      debugPrint('[MissionDetail] Error in _processAndUpload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to your parent?'),
        content: const Text(
            'Your parent will review both photos and approve your screen time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _submitForParentReview();
            },
            child: const Text('SEND'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForParentReview() async {
    setState(() => _isVerifying = true);
    final provider = context.read<AppProvider>();
    try {
      await provider.missionService.updateMissionStatus(
        _mission.id,
        MissionStatus.completed,
      );

      final updated = await provider.missionService.getMissionById(_mission.id);
      if (updated != null && mounted) {
        setState(() => _mission = updated);
        await provider.updateMission(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent to your parent for approval.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send the quest: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _redoMission() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.missionService.redoMission(_mission.id);
      final refreshed =
          await provider.missionService.getMissionById(_mission.id);
      if (refreshed != null) {
        setState(() => _mission = refreshed);
        await provider.updateMission(refreshed);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Quest reset. Add a new after photo to try again.')),
        );
      }
    } catch (e) {
      debugPrint('[MissionDetail] Redo mission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting mission: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Details'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_mission.title,
                style: context.textStyles.headlineMedium!.bold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _mission.status.name.toUpperCase(),
                style: context.textStyles.labelSmall!.bold.withColor(
                  theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('Description', _mission.description),
            const SizedBox(height: 16),
            _buildSection('Completed State', _mission.completedState),
            if (_mission.deadline != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.calendar_today,
                'Deadline',
                DateFormat('MMM dd, yyyy').format(_mission.deadline!),
              ),
            ],
            _buildInfoRow(Icons.category, 'Type', _mission.type.name),
            const SizedBox(height: 24),
            Text('Photo Evidence', style: context.textStyles.titleLarge!.bold),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoCard(
                    'Before Photo',
                    _mission.beforePhotoUrl,
                    () => _addPhoto(true),
                    Icons.photo_camera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoCard(
                    'After Photo',
                    _mission.afterPhotoUrl,
                    () => _addPhoto(false),
                    Icons.photo_camera,
                  ),
                ),
              ],
            ),
            if (_isUploading) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Uploading photo...')
                ],
              ),
            ],
            if (_mission.starsEarned > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < _mission.starsEarned
                              ? Icons.star
                              : Icons.star_border,
                          size: 32,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _mission.aiFeedback ?? 'Great job!',
                      style: context.textStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if ((_mission.status == MissionStatus.pending ||
                    _mission.status == MissionStatus.inProgress) &&
                _mission.beforePhotoUrl != null &&
                _mission.afterPhotoUrl != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isVerifying ? null : _submitForParentReview,
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SEND TO PARENT'),
                ),
              ),
            ],
            if (_mission.status == MissionStatus.failed) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _redoMission,
                icon: Icon(Icons.refresh,
                    color: Theme.of(context).colorScheme.primary),
                label: const Text('Try Quest Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.textStyles.titleMedium!.semiBold),
        const SizedBox(height: 8),
        Text(
          content,
          style: context.textStyles.bodyMedium!.withColor(
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: AppSpacing.verticalXs,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: context.textStyles.bodyMedium!.semiBold),
          Text(value, style: context.textStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(
      String title, String? photoUrl, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Image.network(photoUrl, fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add photo',
                      style: context.textStyles.bodySmall!.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(title, style: context.textStyles.labelSmall!.semiBold),
              ),
            ),
            if (photoUrl != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.tertiary),
              ),
          ],
        ),
      ),
    );
  }
}
