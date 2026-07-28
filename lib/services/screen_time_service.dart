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

class ScreenTimeService {
  static const _channel = MethodChannel('com.powerwyze.questime/screen_time');

  Future<ScreenTimeStatus> status() async {
    if (!Platform.isIOS) {
      return ScreenTimeStatus(
        platform: Platform.isAndroid ? 'android' : Platform.operatingSystem,
        deviceName: Platform.isAndroid ? 'Android phone' : 'Device',
        osVersion: Platform.operatingSystemVersion,
        supported: false,
        authorized: false,
      );
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('status');
      return ScreenTimeStatus(
        platform: 'ios',
        deviceName: data?['deviceName'] as String? ?? 'iPhone',
        osVersion: data?['osVersion'] as String? ?? '',
        supported: data?['supported'] as bool? ?? false,
        authorized: data?['authorized'] as bool? ?? false,
      );
    } on PlatformException {
      return ScreenTimeStatus(
        platform: 'ios',
        deviceName: 'iPhone',
        osVersion: Platform.operatingSystemVersion,
        supported: false,
        authorized: false,
      );
    }
  }

  Future<ScreenTimeStatus> requestAuthorization() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod<void>('requestAuthorization');
    }
    final result = await status();
    await registerDevice(result);
    return result;
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
      'p_app_version': '1.0.1',
      'p_screen_time_authorized': value.authorized,
    });
  }
}
