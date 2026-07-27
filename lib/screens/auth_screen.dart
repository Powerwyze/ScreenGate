import 'package:flutter/material.dart';
import 'package:taskassassin/auth/supabase_auth_manager.dart';
import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:taskassassin/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authManager = SupabaseAuthManager();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _authManager.createAccountWithEmail(
          context,
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _authManager.signInWithEmail(
          context,
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      // Navigation is handled centrally by main.dart once the profile is resolved.
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        String msg;
        if (err.toLowerCase().contains('email not confirmed') || err.contains('email_not_confirmed')) {
          msg = 'Check your inbox to verify your email, then sign in.';
        } else {
          msg = 'Authentication error: $err';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await _authManager.signInWithGoogle(context);
      
      // Navigation is handled centrally by main.dart once the profile is resolved.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendAvailable = SupabaseConfig.isInitialized;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Questime logo
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/ChatGPT_Image_Dec_2_2025_06_29_00_PM.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  // Avoid showing any bright fallback; hide if asset is missing
                  errorBuilder: (context, error, stackTrace) => const SizedBox(width: 100, height: 100),
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'QUES',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cream,
                      ),
                    ),
                    TextSpan(
                      text: 'TIME',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.checkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn Time Into Quests',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              if (!backendAvailable) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.checkGreen.withValues(alpha: 0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFLINE TEST BUILD',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.checkGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The app opened successfully. Backend sign-in is disabled in this sideload build until Supabase keys are provided at build time.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    FilledButton(
                      onPressed: backendAvailable ? _handleEmailAuth : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: AppColors.checkGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isSignUp ? 'SIGN UP' : 'SIGN IN'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: backendAvailable ? _handleGoogleSignIn : null,
                      icon: Icon(Icons.login, color: AppColors.steelBlue),
                      label: const Text('Sign in with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: AppColors.cream,
                        side: BorderSide(color: AppColors.steelBlue),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'v1.0.1',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
