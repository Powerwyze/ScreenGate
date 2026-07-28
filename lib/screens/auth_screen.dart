import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taskassassin/auth/supabase_auth_manager.dart';
import 'package:taskassassin/providers/app_provider.dart';
import 'package:taskassassin/services/family_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _deviceRole = String.fromEnvironment(
    'DEVICE_ROLE',
    defaultValue: 'parent',
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _childNameController = TextEditingController();
  final _authManager = SupabaseAuthManager();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _familyCodeController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily() async {
    final code = _familyCodeController.text.trim();
    final name = _childNameController.text.trim();
    if (code.length != 6 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add your name and the 6-letter family code.')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    provider.setPairingChild(true);
    try {
      await FamilyService().joinAsChild(code: code, childName: name);
      await provider.reloadProfile();
    } catch (error) {
      if (mounted) {
        final message = error.toString().toLowerCase().contains('expired') ||
                error.toString().toLowerCase().contains('invalid')
            ? 'That family code is not valid. Ask your parent for a new one.'
            : 'Could not join the family. Please try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      provider.setPairingChild(false);
      if (mounted) setState(() => _isLoading = false);
    }
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
        final normalizedError = err.toLowerCase();
        if (normalizedError.contains('email not confirmed') ||
            err.contains('email_not_confirmed')) {
          msg = 'Check your inbox to verify your email, then sign in.';
        } else if (normalizedError.contains('failed host lookup') ||
            normalizedError.contains('socketexception') ||
            normalizedError.contains('network')) {
          msg =
              'Questime can\'t reach its server right now. Please try again soon.';
        } else {
          msg = 'Authentication error: $err';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deviceRole == 'child') return _buildChildPhone();

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
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(width: 100, height: 100),
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'QUES',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF17324D),
                              ),
                    ),
                    TextSpan(
                      text: 'TIME',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B8F87),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn Time Into Quests',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667684),
                    ),
              ),
              const SizedBox(height: 48),
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
                      onPressed: _handleEmailAuth,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF0B8F87),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isSignUp ? 'SIGN UP' : 'SIGN IN'),
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
                            color: const Color(0xFF8A9AA6),
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

  Widget _buildChildPhone() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF4EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: Color(0xFF0B8F87),
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Child Phone',
                style: TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the family code from your parent.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667684), fontSize: 17),
              ),
              const SizedBox(height: 44),
              TextField(
                controller: _childNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.face_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _familyCodeController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  labelText: 'Family code',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _joinFamily,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(_isLoading ? 'JOINING...' : 'JOIN MY FAMILY'),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'No email or password needed.',
                style: TextStyle(
                  color: Color(0xFF0B8F87),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
