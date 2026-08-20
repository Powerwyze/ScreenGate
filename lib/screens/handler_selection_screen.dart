import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/handler.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/theme.dart';

class HandlerSelectionScreen extends StatefulWidget {
  const HandlerSelectionScreen({super.key});

  @override
  State<HandlerSelectionScreen> createState() => _HandlerSelectionScreenState();
}

class _HandlerSelectionScreenState extends State<HandlerSelectionScreen> {
  Handler? _selectedHandler;

  Future<void> _selectHandler() async {
    if (_selectedHandler == null) return;

    final provider = context.read<AppProvider>();
    await provider.updateHandler(_selectedHandler!.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Handler changed to ${_selectedHandler!.name}')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Handler'),
        actions: [
          if (_selectedHandler != null)
            TextButton(
              onPressed: _selectHandler,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final handlers = provider.handlerService.getAllHandlers();
          final categories = provider.handlerService.getHandlerCategories();

          return ListView(
            padding: AppSpacing.paddingMd,
            children: categories.map((category) {
              final categoryHandlers =
                  handlers.where((h) => h.category == category).toList();
              if (categoryHandlers.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: AppSpacing.verticalSm,
                    child: Text(
                      category,
                      style: context.textStyles.titleLarge!.bold,
                    ),
                  ),
                  ...categoryHandlers
                      .map((handler) => _buildHandlerCard(handler)),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildHandlerCard(Handler handler) {
    final isSelected = _selectedHandler?.id == handler.id;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedHandler = handler),
      child: Container(
        margin: AppSpacing.verticalXs,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(handler.avatar, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(handler.name,
                      style: context.textStyles.titleMedium!.semiBold),
                  const SizedBox(height: 4),
                  Text(
                    handler.description,
                    style: context.textStyles.bodySmall!
                        .withColor(theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
