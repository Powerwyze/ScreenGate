enum BugSeverity { low, medium, high, critical }

enum BugStatus { open, inProgress, resolved, closed }

class BugReport {
  final String id;
  final String userId;
  final String userEmail;
  final String title;
  final String description;
  final BugSeverity severity;
  final BugStatus status;
  final String? deviceInfo;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  BugReport({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    this.deviceInfo,
    this.appVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_email': userEmail,
        'title': title,
        'description': description,
        'severity': severity.name,
        'status': status.name,
        'device_info': deviceInfo,
        'app_version': appVersion,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BugReport.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return BugReport(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: BugSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => BugSeverity.medium,
      ),
      status: BugStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BugStatus.open,
      ),
      deviceInfo: json['device_info'] as String?,
      appVersion: json['app_version'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  BugReport copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? title,
    String? description,
    BugSeverity? severity,
    BugStatus? status,
    String? deviceInfo,
    String? appVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BugReport(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userEmail: userEmail ?? this.userEmail,
        title: title ?? this.title,
        description: description ?? this.description,
        severity: severity ?? this.severity,
        status: status ?? this.status,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        appVersion: appVersion ?? this.appVersion,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
