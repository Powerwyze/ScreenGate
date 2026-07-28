import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:taskassassin/models/handler.dart';
import 'package:taskassassin/supabase/supabase_config.dart';

class AIService {
  static const String _functionName = 'chatgpt-chat';

  Map<String, dynamic> _handlerPayload(Handler handler) => {
    'id': handler.id,
    'name': handler.name,
    'category': handler.category,
    'description': handler.description,
    'personalityStyle': handler.personalityStyle,
    'personality_style': handler.personalityStyle,
    'avatar': handler.avatar,
    'greetingMessage': handler.greetingMessage,
    'greeting_message': handler.greetingMessage,
  };

  Future<Map<String, dynamic>> _invokeChatGpt(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await SupabaseConfig.client.functions.invoke(
      _functionName,
      body: {'action': action, ...payload},
    );

    final data = response.data;
    Map<String, dynamic> parsed;

    if (data is Map) {
      parsed = Map<String, dynamic>.from(data);
    } else if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is! Map) {
        throw Exception('Unexpected AI response format');
      }
      parsed = Map<String, dynamic>.from(decoded);
    } else {
      throw Exception('Empty AI response');
    }

    if (parsed['error'] != null) {
      final error = parsed['error'].toString();
      final details = parsed['details'];
      throw Exception(details == null ? error : '$error: $details');
    }

    return parsed;
  }

  int _clampStars(int value) {
    if (value < 1) return 1;
    if (value > 5) return 5;
    return value;
  }

  int _coerceStars(dynamic value) {
    if (value is int) return _clampStars(value);
    if (value is double) return _clampStars(value.round());
    if (value is String) return _clampStars(int.tryParse(value) ?? 3);
    return 3;
  }

  Future<Map<String, dynamic>> verifyMission({
    String? missionId,
    required String missionTitle,
    required String missionDescription,
    required String completedState,
    required Handler handler,
    String? beforePhotoUrl,
    String? afterPhotoUrl,
    String? beforePhotoDescription,
    String? afterPhotoDescription,
  }) async {
    if (afterPhotoUrl == null || afterPhotoUrl.isEmpty) {
      debugPrint('[AIService] Strict verify: missing AFTER image -> cannot verify');
      return {
        'stars': 1,
        'feedback': 'I can\'t verify completion without an AFTER photo that clearly shows the result. Please upload an after photo matching the done criteria.',
      };
    }

    try {
      final result = await _invokeChatGpt('verifyMission', {
        'missionId': missionId,
        'missionTitle': missionTitle,
        'missionDescription': missionDescription,
        'completedState': completedState,
        'handler': _handlerPayload(handler),
        'beforePhotoUrl': beforePhotoUrl,
        'afterPhotoUrl': afterPhotoUrl,
        'beforePhotoDescription': beforePhotoDescription,
        'afterPhotoDescription': afterPhotoDescription,
      });

      return {
        'stars': _coerceStars(result['stars']),
        'feedback': result['feedback']?.toString() ?? 'Great job completing this quest!',
      };
    } catch (e) {
      debugPrint('[AIService] Verify mission error: $e');
      return _mockVerificationResponse();
    }
  }

  Future<String> getHandlerResponse({
    required Handler handler,
    required List<Map<String, String>> conversationHistory,
    required String userMessage,
    String? userProfileContext,
  }) async {
    try {
      final result = await _invokeChatGpt('chatWithHandler', {
        'handler': _handlerPayload(handler),
        'history': conversationHistory,
        'userMessage': userMessage,
        'userProfileContext': userProfileContext,
      });

      final text = result['text']?.toString() ?? '';
      debugPrint('[AIService] Handler response length: ${text.length}');
      return text.isNotEmpty ? text : 'I am here to help!';
    } catch (e) {
      debugPrint('[AIService] Get handler response error: $e');
      return 'I am here to help! (AI temporarily unavailable)';
    }
  }

  Future<String> chatWithHandler({
    required Handler handler,
    required List<Map<String, String>> conversationHistory,
    required String userMessage,
    String? userProfileContext,
  }) => getHandlerResponse(
    handler: handler,
    conversationHistory: conversationHistory,
    userMessage: userMessage,
    userProfileContext: userProfileContext,
  );

  Future<List<String>> generateMissionSuggestions({
    required String userGoals,
    required Handler handler,
    int count = 3,
  }) async {
    try {
      final result = await _invokeChatGpt('generateMissionSuggestions', {
        'userGoals': userGoals,
        'handler': _handlerPayload(handler),
        'count': count,
      });

      final missions = result['missions'];
      if (missions is List) {
        return missions.map((mission) => mission.toString()).toList();
      }

      return ['Complete a daily quest', 'Practice a new skill', 'Help someone today'];
    } catch (e) {
      debugPrint('[AIService] Generate mission suggestions error: $e');
      return ['Complete a daily quest', 'Practice a new skill', 'Help someone today'];
    }
  }

  Map<String, dynamic> _mockVerificationResponse() {
    return {
      'stars': 3,
      'feedback': 'Good effort. AI verification is temporarily unavailable, so Questime could not fully inspect this proof.',
    };
  }
}
