import 'package:flutter/foundation.dart';
import 'package:screengate/models/bug_report.dart';
import 'package:screengate/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class BugReportService {
  final _uuid = const Uuid();

  BugReportService();

  Future<void> submitBugReport({
    required String title,
    required String description,
    required BugSeverity severity,
    String? deviceInfo,
    String? appVersion,
  }) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bugReport = BugReport(
        id: _uuid.v4(),
        userId: user.id,
        userEmail: user.email ?? 'unknown',
        title: title,
        description: description,
        severity: severity,
        status: BugStatus.open,
        deviceInfo: deviceInfo,
        appVersion: appVersion ?? '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await SupabaseService.insert('bug_reports', bugReport.toJson());
      debugPrint('[BugReportService] Bug report submitted: ${bugReport.id}');
    } catch (e) {
      debugPrint('[BugReportService] Error submitting bug report: $e');
      rethrow;
    }
  }

  Future<List<BugReport>> getUserBugReports() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return [];

      final results = await SupabaseService.select(
        'bug_reports',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      return results.map((json) => BugReport.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[BugReportService] Error getting user bug reports: $e');
      return [];
    }
  }

  Future<BugReport?> getBugReportById(String bugReportId) async {
    try {
      final data = await SupabaseService.selectSingle('bug_reports',
          filters: {'id': bugReportId});
      if (data == null) return null;
      return BugReport.fromJson(data);
    } catch (e) {
      debugPrint('[BugReportService] Error getting bug report by id: $e');
      return null;
    }
  }
}
