import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taskassassin/supabase/supabase_config.dart';

class ParentGateService {
  const ParentGateService();

  Future<bool> verify({
    required String email,
    required String password,
  }) async {
    final client = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user != null;
    } on AuthException {
      return false;
    } finally {
      await client.dispose();
    }
  }
}

Future<bool> requireParentPassword(
  BuildContext context, {
  required String email,
  required String action,
}) async {
  final controller = TextEditingController();
  var checking = false;
  var errorText = '';

  Future<void> verify(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
  ) async {
    if (controller.text.isEmpty) {
      setDialogState(() => errorText = 'Enter the parent password.');
      return;
    }
    setDialogState(() {
      checking = true;
      errorText = '';
    });
    final valid = await const ParentGateService().verify(
      email: email,
      password: controller.text,
    );
    if (!dialogContext.mounted) return;
    if (valid) {
      Navigator.pop(dialogContext, true);
    } else {
      setDialogState(() {
        checking = false;
        errorText = 'That password is not correct.';
      });
    }
  }

  final approved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Parent check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the parent password to $action.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              enabled: !checking,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Parent password',
                errorText: errorText.isEmpty ? null : errorText,
              ),
              onSubmitted: checking
                  ? null
                  : (_) => verify(dialogContext, setDialogState),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                checking ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed:
                checking ? null : () => verify(dialogContext, setDialogState),
            child: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('UNLOCK'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return approved == true;
}
