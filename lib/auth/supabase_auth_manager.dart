import 'package:flutter/material.dart';
import 'package:taskassassin/auth/auth_manager.dart';
import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:taskassassin/models/user.dart' as app_user;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthManager extends AuthManager with EmailSignInManager {
  @override
  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
      debugPrint('[SupabaseAuth] Signed out successfully');
    } catch (e) {
      debugPrint('[SupabaseAuth] Sign out error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(BuildContext context) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw 'No user logged in';

      // Delete user from Supabase (will cascade delete all related data)
      await SupabaseService.delete('users', filters: {'id': userId});
      await SupabaseConfig.auth.admin.deleteUser(userId);

      debugPrint('[SupabaseAuth] User deleted successfully');
    } catch (e) {
      debugPrint('[SupabaseAuth] Delete user error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateEmail(
      {required String email, required BuildContext context}) async {
    try {
      await SupabaseConfig.auth.updateUser(UserAttributes(email: email));
      debugPrint('[SupabaseAuth] Email updated to: $email');
    } catch (e) {
      debugPrint('[SupabaseAuth] Update email error: $e');
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(
      {required String email, required BuildContext context}) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
      debugPrint('[SupabaseAuth] Password reset email sent to: $email');
    } catch (e) {
      debugPrint('[SupabaseAuth] Reset password error: $e');
      rethrow;
    }
  }

  @override
  Future<app_user.User?> signInWithEmail(
      BuildContext context, String email, String password) async {
    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Sign in failed';
      }

      debugPrint('[SupabaseAuth] Signed in with email: $email');
      return await _getUserProfile(response.user!);
    } catch (e) {
      debugPrint('[SupabaseAuth] Sign in error: $e');
      rethrow;
    }
  }

  @override
  Future<app_user.User?> createAccountWithEmail(
      BuildContext context, String email, String password) async {
    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Sign up failed';
      }

      // If email confirmation is required, Supabase returns no session.
      // In that case, do NOT attempt profile creation (RLS will block it).
      if (response.session == null) {
        debugPrint(
            '[SupabaseAuth] Created account, email confirmation required for: $email');
        throw 'Email not confirmed. We sent a verification link to $email. Please verify, then sign in.';
      }

      debugPrint('[SupabaseAuth] Created account with email: $email');
      return await _getUserProfile(response.user!);
    } catch (e) {
      debugPrint('[SupabaseAuth] Create account error: $e');
      rethrow;
    }
  }

  /// Profiles are created by onboarding after the user chooses a role.
  Future<app_user.User?> _getUserProfile(User supabaseUser) async {
    try {
      final existingUser = await SupabaseService.selectSingle(
        'users',
        filters: {'id': supabaseUser.id},
      );
      return existingUser == null ? null : app_user.User.fromJson(existingUser);
    } catch (e) {
      debugPrint('[SupabaseAuth] Get user profile error: $e');
      return null;
    }
  }
}
