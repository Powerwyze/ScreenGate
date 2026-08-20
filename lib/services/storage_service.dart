import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  Future<void> saveString(String key, String value) async {
    try {
      await _prefs!.setString(key, value);
    } catch (e) {
      debugPrint('Error saving string to storage: $e');
    }
  }

  String? getString(String key) {
    try {
      return _prefs!.getString(key);
    } catch (e) {
      debugPrint('Error getting string from storage: $e');
      return null;
    }
  }

  Future<void> saveJson(String key, Map<String, dynamic> json) async {
    try {
      await saveString(key, jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving JSON to storage: $e');
    }
  }

  Map<String, dynamic>? getJson(String key) {
    try {
      final str = getString(key);
      if (str == null) return null;
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting JSON from storage: $e');
      return null;
    }
  }

  Future<void> saveJsonList(String key, List<Map<String, dynamic>> list) async {
    try {
      await saveString(key, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving JSON list to storage: $e');
    }
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    try {
      final str = getString(key);
      if (str == null || str.isEmpty) return [];
      final decoded = jsonDecode(str);
      if (decoded is! List) return [];
      return List<Map<String, dynamic>>.from(
          decoded.map((e) => e as Map<String, dynamic>));
    } catch (e) {
      debugPrint('Error getting JSON list from storage ($key): $e');
      return [];
    }
  }

  Future<void> remove(String key) async {
    try {
      await _prefs!.remove(key);
    } catch (e) {
      debugPrint('Error removing key from storage: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _prefs!.clear();
    } catch (e) {
      debugPrint('Error clearing storage: $e');
    }
  }
}
