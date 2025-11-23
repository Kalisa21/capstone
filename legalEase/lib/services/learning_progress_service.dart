import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class LearningProgressService {
  LearningProgressService._();
  static final LearningProgressService instance = LearningProgressService._();

  final ValueNotifier<LearningProgress?> progressNotifier =
      ValueNotifier<LearningProgress?>(null);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;
    await refresh();
  }

  LearningProgress? get progress => progressNotifier.value;

  Future<void> refresh() async {
    if (!SupabaseService.isAuthenticated) {
      progressNotifier.value = null;
      return;
    }

    try {
      final userId = SupabaseService.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Get today's progress
      final response = await SupabaseService.client
          .from('user_analytics')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (response != null) {
        progressNotifier.value = LearningProgress.fromMap(
          Map<String, dynamic>.from(response as Map),
        );
      } else {
        // Create default progress for today
        progressNotifier.value = LearningProgress(
          id: '',
          userId: userId,
          date: DateTime.now(),
          timeSpentMinutes: 0,
          articlesViewed: 0,
          queriesMade: 0,
          knowledgeScore: 0.0,
          topicsStudied: [],
        );
      }
    } catch (e) {
      debugPrint('Error loading learning progress: $e');
      progressNotifier.value = null;
    }
  }

  Future<void> recordActivity({
    required String activityType,
    String? articleId,
    String? topicId,
    int? timeSpentMinutes,
  }) async {
    if (!SupabaseService.isAuthenticated) return;

    try {
      final userId = SupabaseService.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Get or create today's analytics
      final existing = await SupabaseService.client
          .from('user_analytics')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      final updates = <String, dynamic>{};

      if (activityType == 'view_article') {
        updates['articles_viewed'] = (existing?['articles_viewed'] ?? 0) + 1;
      } else if (activityType == 'chat_query') {
        updates['queries_made'] = (existing?['queries_made'] ?? 0) + 1;
      }

      if (timeSpentMinutes != null && timeSpentMinutes > 0) {
        updates['time_spent_minutes'] =
            (existing?['time_spent_minutes'] ?? 0) + timeSpentMinutes;
      }

      if (topicId != null) {
        final topicsStudied = List<String>.from(
          existing?['topics_studied'] ?? [],
        );
        if (!topicsStudied.contains(topicId)) {
          topicsStudied.add(topicId);
        }
        updates['topics_studied'] = topicsStudied;
      }

      // Calculate knowledge score (simple formula: based on articles viewed and queries)
      if (updates.isNotEmpty) {
        final articlesViewed = updates['articles_viewed'] ?? existing?['articles_viewed'] ?? 0;
        final queriesMade = updates['queries_made'] ?? existing?['queries_made'] ?? 0;
        final topicsCount = (updates['topics_studied'] ?? existing?['topics_studied'] ?? []).length;
        
        // Simple scoring: articles (40%) + queries (30%) + topics (30%)
        final score = (articlesViewed * 0.4 + queriesMade * 0.3 + topicsCount * 10 * 0.3)
            .clamp(0.0, 100.0);
        updates['knowledge_score'] = score;
      }

      if (existing != null) {
        await SupabaseService.client
            .from('user_analytics')
            .update(updates)
            .eq('id', existing['id']);
      } else {
        await SupabaseService.client.from('user_analytics').insert({
          'user_id': userId,
          'date': today,
          ...updates,
        });
      }

      await refresh();
    } catch (e) {
      debugPrint('Error recording activity: $e');
    }
  }

  Future<List<LearningProgress>> getWeeklyProgress() async {
    if (!SupabaseService.isAuthenticated) return [];

    try {
      final userId = SupabaseService.currentUser!.id;
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final weekAgoStr = weekAgo.toIso8601String().split('T')[0];

      final response = await SupabaseService.client
          .from('user_analytics')
          .select()
          .eq('user_id', userId)
          .gte('date', weekAgoStr)
          .order('date', ascending: true);

      return (response as List<dynamic>)
          .map((row) => LearningProgress.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading weekly progress: $e');
      return [];
    }
  }
}

class LearningProgress {
  final String id;
  final String userId;
  final DateTime date;
  final int timeSpentMinutes;
  final int articlesViewed;
  final int queriesMade;
  final double knowledgeScore;
  final List<String> topicsStudied;

  LearningProgress({
    required this.id,
    required this.userId,
    required this.date,
    this.timeSpentMinutes = 0,
    this.articlesViewed = 0,
    this.queriesMade = 0,
    this.knowledgeScore = 0.0,
    this.topicsStudied = const [],
  });

  factory LearningProgress.fromMap(Map<String, dynamic> map) {
    return LearningProgress(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      date: map['date'] != null
          ? DateTime.parse(map['date'].toString())
          : DateTime.now(),
      timeSpentMinutes: map['time_spent_minutes'] is int
          ? map['time_spent_minutes'] as int
          : int.tryParse(map['time_spent_minutes']?.toString() ?? '0') ?? 0,
      articlesViewed: map['articles_viewed'] is int
          ? map['articles_viewed'] as int
          : int.tryParse(map['articles_viewed']?.toString() ?? '0') ?? 0,
      queriesMade: map['queries_made'] is int
          ? map['queries_made'] as int
          : int.tryParse(map['queries_made']?.toString() ?? '0') ?? 0,
      knowledgeScore: map['knowledge_score'] is num
          ? (map['knowledge_score'] as num).toDouble()
          : double.tryParse(map['knowledge_score']?.toString() ?? '0') ?? 0.0,
      topicsStudied: map['topics_studied'] is List
          ? List<String>.from(map['topics_studied'])
          : [],
    );
  }
}

