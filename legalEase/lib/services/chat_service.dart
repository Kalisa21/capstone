// Removed unnecessary dart:convert import after refactor.

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  late final String _baseUrl;
  late final ApiService _api;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    // dotenv should already be loaded in SupabaseService.initialize()
    _baseUrl = dotenv.env['API_BASE_URL']?.trim() ??
      const String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000');
    _api = ApiService(baseUrl: _baseUrl);
    _initialized = true;
  }

  String get baseUrl => _baseUrl;

  Future<String> sendMessage(String message) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final resp = await _api.post('/search', body: {'query': message, 'top_k': 1});
      if (!resp.isOk) {
        return 'Error: ${resp.error}';
      }
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isEmpty) return 'No response received.';
        final first = results.first;
        if (first is Map && first['article_text'] is String) {
          return first['article_text'] as String;
        }
      }
      return 'No response text.';
    } catch (e) {
      return 'Failed to connect to server: $e';
    }
  }
}
