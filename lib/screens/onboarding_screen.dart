import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/models/handler.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/theme.dart';
import 'package:taskassassin/supabase/supabase_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _codenameController = TextEditingController();
  final _lifeGoalsController = TextEditingController();
  Handler? _selectedHandler;
  AccountRole? _accountRole;
  int _currentPage = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _codenameController.dispose();
    _lifeGoalsController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_accountRole == null || _codenameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Choose Parent or Child, then add your name.')),
      );
      return;
    }

    if (_accountRole == AccountRole.parent) {
      _completeParentOnboarding();
      return;
    }

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeParentOnboarding() async {
    final defaultHandler =
        context.read<AppProvider>().handlerService.getDefaultHandler();
    await _complete(
      handlerId: defaultHandler.id,
      lifeGoals: 'Help my family build healthy habits.',
    );
  }

  Future<void> _complete({String? handlerId, String? lifeGoals}) async {
    final selectedHandlerId = handlerId ?? _selectedHandler?.id;
    final selectedLifeGoals = lifeGoals ?? _lifeGoalsController.text.trim();
    if (_codenameController.text.isEmpty ||
        _accountRole == null ||
        selectedHandlerId == null ||
        selectedLifeGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    // Ensure user is authenticated before attempting to create profile
    final isAuthed = context.read<AppProvider>().isAuthenticated;
    final supaUser = SupabaseConfig.auth.currentUser;
    if (!isAuthed || supaUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please sign in first. Redirecting to the sign-in screen...'),
        ),
      );
      context.go('/auth');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.completeOnboarding(
        codename: _codenameController.text.trim(),
        handlerId: selectedHandlerId,
        lifeGoals: selectedLifeGoals,
        accountRole: _accountRole!,
      );

      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      // Show a helpful message instead of appearing stuck
      final error = e.toString();
      String msg;
      if (error.contains('row-level security') ||
          error.contains('permission denied')) {
        msg =
            'Saving your profile was blocked by database security (RLS). Please try again, or contact support.';
      } else if (error.contains('No authenticated user')) {
        msg = 'You are signed out. Please sign in and try again.';
      } else if (error.toLowerCase().contains('email not confirmed') ||
          error.toLowerCase().contains('verification')) {
        msg =
            'Please verify your email first. We sent you a verification link.';
      } else {
        msg = 'Something went wrong while saving. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildHandlerSelectionPage(),
                  _buildLifeGoalsPage(),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.paddingLg,
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_currentPage == 2 ? () => _complete() : _nextPage),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_buttonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (_currentPage == 2) return 'Finish';
    if (_currentPage == 0 && _accountRole == AccountRole.parent) {
      return 'Set Up My Family';
    }
    return 'Continue';
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: AppSpacing.paddingXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/ChatGPT_Image_Dec_2_2025_06_29_00_PM.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Logo failed to load: $error');
                  return const Icon(Icons.task_alt,
                      size: 120, color: AppColors.checkGreen);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Welcome to\n',
                    style: context.textStyles.titleLarge!
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: 'QUESTIME',
                    style: context.textStyles.displaySmall!.bold
                        .copyWith(color: AppColors.checkGreen),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Turn important tasks into quests, then earn time for fun.',
            style: context.textStyles.bodyLarge!.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Text('Who uses this phone?',
              style: context.textStyles.titleMedium!.bold),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleChoice(
                  role: AccountRole.parent,
                  icon: Icons.family_restroom,
                  title: 'Parent',
                  subtitle: 'I make and approve quests',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleChoice(
                  role: AccountRole.child,
                  icon: Icons.stars_rounded,
                  title: 'Child',
                  subtitle: 'I complete my quests',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codenameController,
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'e.g., Maya',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 16),
          _SignedInEmailHint(),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'v1.5.1',
              style:
                  context.textStyles.bodySmall?.withColor(AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChoice({
    required AccountRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _accountRole == role;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title: $subtitle',
      child: InkWell(
        onTap: () => setState(() => _accountRole = role),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 148),
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outline.withValues(alpha: 0.4),
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 36,
                  color: selected ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(title, style: context.textStyles.titleMedium!.bold),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandlerSelectionPage() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final handlers = provider.handlerService.getAllHandlers();
        final categories = provider.handlerService.getHandlerCategories();

        return SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Choose Your Handler',
                style: context.textStyles.headlineMedium!.bold,
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI coach who will guide, motivate, and verify your missions.',
                style: context.textStyles.bodyMedium!.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ...categories.map((category) {
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
                        style: context.textStyles.titleMedium!.semiBold,
                      ),
                    ),
                    ...categoryHandlers
                        .map((handler) => _buildHandlerCard(handler)),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ],
          ),
        );
      },
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
            Text(handler.avatar, style: const TextStyle(fontSize: 32)),
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

  Widget _buildLifeGoalsPage() {
    return SingleChildScrollView(
      padding: AppSpacing.paddingXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Set Your Life Goals',
            style: context.textStyles.headlineMedium!.bold,
          ),
          const SizedBox(height: 8),
          Text(
            'Your Handler will use these to suggest relevant missions and provide personalized motivation.',
            style: context.textStyles.bodyMedium!.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _lifeGoalsController,
            decoration: InputDecoration(
              labelText: 'What do you want to achieve?',
              hintText: 'e.g., Start a business, get fit, learn coding',
              prefixIcon: const Icon(Icons.flag),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          if (_selectedHandler != null) ...[
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Text(_selectedHandler!.avatar,
                      style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedHandler!.greetingMessage,
                      style: context.textStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignedInEmailHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final email = context.read<AppProvider>().isAuthenticated
        ? (SupabaseConfig.auth.currentUser?.email ?? '')
        : '';
    if (email.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.email, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Signed in as $email',
              style: context.textStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
