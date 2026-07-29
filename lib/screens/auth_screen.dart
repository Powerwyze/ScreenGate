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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _childNameController = TextEditingController();
  final _authManager = SupabaseAuthManager();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isRecoveringChild = false;
  bool _isPairingNewChild = false;
  String? _deviceRole;
  List<RememberedChild> _rememberedChildren = const [];
  RememberedChild? _selectedRememberedChild;

  @override
  void initState() {
    super.initState();
    _loadRememberedChildren();
  }

  Future<void> _loadRememberedChildren() async {
    final children = await FamilyService().getRememberedChildren();
    if (!mounted || children.isEmpty) return;
    setState(() {
      _rememberedChildren = children;
      _selectedRememberedChild = children.first;
      _deviceRole = 'child';
    });
  }

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
    if (_isRecoveringChild) {
      if (code.length != 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the 8-character child code.')),
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        await FamilyService().recoverChild(code);
        await context.read<AppProvider>().reloadProfile();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That child code did not work.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }
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

  Future<void> _signInRememberedChild() async {
    final child = _selectedRememberedChild;
    if (child == null || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the child password.')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    try {
      await FamilyService().signInRememberedChild(
        child: child,
        password: _passwordController.text,
      );
      await provider.reloadProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That password did not work. Ask your parent.'),
          ),
        );
      }
    } finally {
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
    if (_deviceRole == null) return _buildPhoneChoice();
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
                'One family account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667684),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Parents sign in. Kids join with the family code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667684)),
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
                    TextButton.icon(
                      onPressed: () => setState(() => _deviceRole = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Choose a different phone'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'v1.5.1',
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
    final usePassword = _rememberedChildren.isNotEmpty &&
        !_isPairingNewChild &&
        !_isRecoveringChild;
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
              Text(
                'Child Phone',
                style: TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isRecoveringChild
                    ? 'Enter this phone’s child code.'
                    : usePassword
                        ? 'Welcome back. Enter your password.'
                        : 'Enter the family code from your parent.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667684), fontSize: 17),
              ),
              const SizedBox(height: 44),
              if (usePassword) ...[
                DropdownButtonFormField<RememberedChild>(
                  initialValue: _selectedRememberedChild,
                  decoration: const InputDecoration(
                    labelText: 'Child',
                    prefixIcon: Icon(Icons.face_rounded),
                  ),
                  items: _rememberedChildren
                      .map(
                        (child) => DropdownMenuItem(
                          value: child,
                          child: Text(child.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (child) => setState(() {
                            _selectedRememberedChild = child;
                            _passwordController.clear();
                          }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted:
                      _isLoading ? null : (_) => _signInRememberedChild(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                ),
              ] else if (!_isRecoveringChild) ...[
                TextField(
                  controller: _childNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.face_rounded),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!usePassword)
                TextField(
                  controller: _familyCodeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: _isRecoveringChild ? 8 : 6,
                  style: const TextStyle(
                    color: Color(0xFF17324D),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _isRecoveringChild ? 'Recovery code' : 'Family code',
                    counterText: '',
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : usePassword
                          ? _signInRememberedChild
                          : _joinFamily,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(_isLoading
                      ? 'CONNECTING...'
                      : usePassword
                          ? 'OPEN MY QUESTS'
                          : _isRecoveringChild
                              ? 'OPEN MY QUESTS'
                              : 'JOIN MY FAMILY'),
                ),
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          if (usePassword) {
                            _isPairingNewChild = true;
                            _isRecoveringChild = false;
                          } else if (_isRecoveringChild) {
                            _isPairingNewChild = true;
                            _isRecoveringChild = false;
                          } else if (_rememberedChildren.isNotEmpty) {
                            _isPairingNewChild = false;
                            _isRecoveringChild = false;
                          } else {
                            _isPairingNewChild = false;
                            _isRecoveringChild = true;
                          }
                          _familyCodeController.clear();
                        }),
                child: Text(usePassword
                    ? 'Pair a different child'
                    : _isRecoveringChild
                        ? 'Use a family pairing code'
                        : _rememberedChildren.isEmpty
                            ? 'This phone was paired before'
                            : 'Back to child sign in'),
              ),
              if (!usePassword && !_isRecoveringChild)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isRecoveringChild = true;
                            _isPairingNewChild = false;
                            _familyCodeController.clear();
                          }),
                  child: const Text('Use a recovery code'),
                ),
              Text(
                usePassword
                    ? 'No pairing code needed.'
                    : 'Pairing is only needed once.',
                style: const TextStyle(
                    color: Color(0xFF0B8F87), fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _deviceRole = null),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Choose a different phone'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneChoice() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/ChatGPT_Image_Dec_2_2025_06_29_00_PM.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Whose phone is this?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF17324D),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pick one to get started.',
                    style: TextStyle(color: Color(0xFF667684), fontSize: 17),
                  ),
                  const SizedBox(height: 36),
                  _PhoneChoiceButton(
                    icon: Icons.family_restroom_rounded,
                    title: 'Parent',
                    subtitle: 'Sign in to the family account',
                    color: const Color(0xFF0B8F87),
                    onTap: () => setState(() => _deviceRole = 'parent'),
                  ),
                  const SizedBox(height: 16),
                  _PhoneChoiceButton(
                    icon: Icons.child_care_rounded,
                    title: 'Child',
                    subtitle: 'Join with the family code',
                    color: const Color(0xFFFF7A66),
                    onTap: () => setState(() => _deviceRole = 'child'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneChoiceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PhoneChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 104,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
        child: Row(
          children: [
            Icon(icon, size: 42),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 15, color: Colors.white)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
