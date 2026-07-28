import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class ScreenTimeStatus {
  final String platform;
  final String deviceName;
  final String osVersion;
  final bool supported;
  final bool authorized;

  const ScreenTimeStatus({
    required this.platform,
    required this.deviceName,
    required this.osVersion,
    required this.supported,
    required this.authorized,
  });
}

class ControlledApp {
  final String packageName;
  final String name;

  const ControlledApp({required this.packageName, required this.name});

  factory ControlledApp.fromJson(Map<Object?, Object?> json) => ControlledApp(
        packageName: json['packageName'] as String,
        name: json['name'] as String,
      );
}

class ScreenTimeConfiguration {
  final Set<String> packages;
  final int remainingSeconds;

  const ScreenTimeConfiguration({
    required this.packages,
    required this.remainingSeconds,
  });
}

class ScreenTimeService {
  static const _channel = MethodChannel('com.powerwyze.questime/screen_time');

  Future<ScreenTimeStatus> status() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return ScreenTimeStatus(
        platform: Platform.operatingSystem,
        deviceName: 'Device',
        osVersion: Platform.operatingSystemVersion,
        supported: false,
        authorized: false,
      );
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('status');
      return ScreenTimeStatus(
        platform: Platform.isAndroid ? 'android' : 'ios',
        deviceName: data?['deviceName'] as String? ??
            (Platform.isAndroid ? 'Android phone' : 'iPhone'),
        osVersion: data?['osVersion'] as String? ?? '',
        supported: data?['supported'] as bool? ?? false,
        authorized: data?['authorized'] as bool? ?? false,
      );
    } on PlatformException {
      return ScreenTimeStatus(
        platform: Platform.isAndroid ? 'android' : 'ios',
        deviceName: Platform.isAndroid ? 'Android phone' : 'iPhone',
        osVersion: Platform.operatingSystemVersion,
        supported: false,
        authorized: false,
      );
    }
  }

  Future<ScreenTimeStatus> requestAuthorization() async {
    if (Platform.isIOS || Platform.isAndroid) {
      await _channel.invokeMethod<void>('requestAuthorization');
    }
    final result = await status();
    await registerDevice(result);
    return result;
  }

  Future<List<ControlledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return const [];
    final rows = await _channel
        .invokeListMethod<Map<Object?, Object?>>('getInstalledApps');
    return rows?.map(ControlledApp.fromJson).toList() ?? const [];
  }

  Future<ScreenTimeConfiguration> getConfiguration() async {
    if (!Platform.isAndroid) {
      return const ScreenTimeConfiguration(
          packages: <String>{}, remainingSeconds: 0);
    }
    final data =
        await _channel.invokeMapMethod<Object?, Object?>('getConfiguration');
    return ScreenTimeConfiguration(
      packages: ((data?['packages'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      remainingSeconds: (data?['remainingSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> configureAndroid({
    Set<String>? packages,
    required int awardedMinutes,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('configure', {
      if (packages != null) 'packages': packages.toList(),
      'awardedMinutes': awardedMinutes,
    });
  }

  Future<void> registerCurrentDevice({required String role}) async {
    await registerDevice(await status(), role: role);
  }

  Future<void> registerDevice(ScreenTimeStatus value,
      {String role = 'child'}) async {
    final preferences = await SharedPreferences.getInstance();
    var installationId = preferences.getString('questime_installation_id');
    installationId ??= const Uuid().v4();
    await preferences.setString('questime_installation_id', installationId);

    await SupabaseConfig.client.rpc('register_questime_device', params: {
      'p_installation_id': installationId,
      'p_platform': value.platform,
      'p_device_role': role,
      'p_device_name': value.deviceName,
      'p_os_version': value.osVersion,
      'p_app_version': '1.1.0',
      'p_screen_time_authorized': value.authorized,
    });
  }
}
