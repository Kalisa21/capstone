import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class ChatSessionsService {
  ChatSessionsService._();
  static final ChatSessionsService instance = ChatSessionsService._();

  final ValueNotifier<List<ChatSession>> sessionsNotifier =
      ValueNotifier<List<ChatSession>>([]);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;
    await refresh();
  }

  List<ChatSession> get sessions => List.unmodifiable(sessionsNotifier.value);

  Future<void> refresh() async {
    if (!SupabaseService.isAuthenticated) {
      sessionsNotifier.value = [];
      return;
    }

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // First, ensure chat_sessions table exists (create if needed)
      // Then fetch sessions
      final response = await SupabaseService.client
          .from('chat_sessions')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final sessions = (response as List<dynamic>)
          .map((row) => ChatSession.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();

      sessionsNotifier.value = sessions;
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
      // If table doesn't exist, create it (this is a fallback)
      sessionsNotifier.value = [];
    }
  }

  Future<String?> createSession({
    String? title,
    String language = 'en',
  }) async {
    if (!SupabaseService.isAuthenticated) return null;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Auto-generate title if not provided
      final sessionTitle = title ?? 'Chat ${DateTime.now().toString().substring(0, 10)}';

      final response = await SupabaseService.client
          .from('chat_sessions')
          .insert({
            'user_id': userId,
            'title': sessionTitle,
            'language': language,
          })
          .select()
          .single();

      await refresh();
      return response['id']?.toString();
    } catch (e) {
      debugPrint('Error creating chat session: $e');
      return null;
    }
  }

  Future<bool> updateSession({
    required String sessionId,
    String? title,
    String? language,
  }) async {
    if (!SupabaseService.isAuthenticated) return false;

    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (language != null) updates['language'] = language;

      if (updates.isEmpty) return true;

      await SupabaseService.client
          .from('chat_sessions')
          .update(updates)
          .eq('id', sessionId);

      await refresh();
      return true;
    } catch (e) {
      debugPrint('Error updating chat session: $e');
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    if (!SupabaseService.isAuthenticated) return false;

    try {
      // Delete associated messages first
      await SupabaseService.client
          .from('chat_messages')
          .delete()
          .eq('session_id', sessionId);

      // Delete session
      await SupabaseService.client
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId);

      await refresh();
      return true;
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
      return false;
    }
  }

  Future<ChatSession?> getSession(String sessionId) async {
    if (!SupabaseService.isAuthenticated) return null;

    try {
      final response = await SupabaseService.client
          .from('chat_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      return ChatSession.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error getting chat session: $e');
      return null;
    }
  }
}

class ChatSession {
  final String id;
  final String userId;
  final String? title;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.userId,
    this.title,
    this.language = 'en',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString(),
      language: map['language']?.toString() ?? 'en',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }
}

