import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'legal_topics_service.dart';

class AdminAnalyticsService {
  AdminAnalyticsService._();
  static final AdminAnalyticsService instance = AdminAnalyticsService._();

  /// Get total number of registered users
  Future<int> getTotalUsers() async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('user_id');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting total users: $e');
      return 0;
    }
  }

  /// Get active users (users who made queries in last 7 days)
  Future<int> getActiveUsers({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('user_id')
          .gte('created_at', cutoffDate.toIso8601String());
      
      // Count distinct users
      final userIds = <String>{};
      if (response is List) {
        for (final row in response) {
          if (row['user_id'] != null) {
            userIds.add(row['user_id'].toString());
          }
        }
      }
      return userIds.length;
    } catch (e) {
      debugPrint('Error getting active users: $e');
      return 0;
    }
  }

  /// Get total queries made
  Future<int> getTotalQueries() async {
    try {
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('id')
          .eq('role', 'user');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting total queries: $e');
      return 0;
    }
  }

  /// Get queries in last N days
  Future<int> getQueriesInPeriod({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('id')
          .eq('role', 'user')
          .gte('created_at', cutoffDate.toIso8601String());
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting queries in period: $e');
      return 0;
    }
  }

  /// Get average response time from metadata
  Future<double> getAverageResponseTime() async {
    try {
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('metadata')
          .eq('role', 'assistant')
          .not('metadata', 'is', null)
          .limit(100);

      if (response is List && response.isNotEmpty) {
        double totalTime = 0;
        int count = 0;
        for (final row in response) {
          final metadata = row['metadata'];
          if (metadata is Map && metadata['processing_time_ms'] != null) {
            final time = (metadata['processing_time_ms'] as num).toDouble();
            totalTime += time;
            count++;
          }
        }
        return count > 0 ? (totalTime / count) / 1000 : 0.0; // Convert to seconds
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error getting average response time: $e');
      return 0.0;
    }
  }

  /// Get most popular topics (by user interactions)
  Future<List<Map<String, dynamic>>> getPopularTopics({int limit = 5}) async {
    try {
      // Get topics from user_analytics
      final response = await SupabaseService.client
          .from('user_analytics')
          .select('topics_studied')
          .not('topics_studied', 'is', null);

      final topicCounts = <String, int>{};
      if (response is List) {
        for (final row in response) {
          final topics = row['topics_studied'];
          if (topics is List) {
            for (final topicId in topics) {
              final id = topicId.toString();
              topicCounts[id] = (topicCounts[id] ?? 0) + 1;
            }
          }
        }
      }

      // Get topic names
      final topics = LegalTopicsService.instance.topics;
      final popular = <Map<String, dynamic>>[];
      for (final entry in topicCounts.entries) {
        final topic = topics.firstWhere(
          (t) => t.id == entry.key,
          orElse: () => topics.first,
        );
        if (topic.id == entry.key) {
          popular.add({
            'id': topic.id,
            'name': topic.title,
            'count': entry.value,
          });
        }
      }

      popular.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      return popular.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting popular topics: $e');
      return [];
    }
  }

  /// Get user growth (new signups in last 7 days)
  Future<int> getNewSignups({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final response = await SupabaseService.client
          .from('profiles')
          .select('user_id')
          .gte('created_at', cutoffDate.toIso8601String());
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting new signups: $e');
      return 0;
    }
  }

  /// Get total topics count
  Future<int> getTotalTopics() async {
    try {
      return LegalTopicsService.instance.topics.length;
    } catch (e) {
      debugPrint('Error getting total topics: $e');
      return 0;
    }
  }

  /// Get active topics count
  Future<int> getActiveTopics() async {
    try {
      return LegalTopicsService.instance.topics.where((t) => t.isActive).length;
    } catch (e) {
      debugPrint('Error getting active topics: $e');
      return 0;
    }
  }

  /// Get queries per day for last N days
  Future<List<Map<String, dynamic>>> getQueriesPerDay({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('created_at')
          .eq('role', 'user')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: true);

      final dailyCounts = <String, int>{};
      if (response is List) {
        for (final row in response) {
          final createdAt = row['created_at']?.toString();
          if (createdAt != null) {
            final date = DateTime.parse(createdAt);
            final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
          }
        }
      }

      return dailyCounts.entries.map((e) => {
        'date': e.key,
        'count': e.value,
      }).toList();
    } catch (e) {
      debugPrint('Error getting queries per day: $e');
      return [];
    }
  }

  /// Get comprehensive admin stats
  Future<AdminStats> getAdminStats() async {
    try {
      final totalUsers = await getTotalUsers();
      final activeUsers = await getActiveUsers(days: 7);
      final totalQueries = await getTotalQueries();
      final queriesLast7Days = await getQueriesInPeriod(days: 7);
      final queriesLast30Days = await getQueriesInPeriod(days: 30);
      final avgResponseTime = await getAverageResponseTime();
      final newSignups = await getNewSignups(days: 7);
      final totalTopics = await getTotalTopics();
      final activeTopics = await getActiveTopics();
      final popularTopics = await getPopularTopics(limit: 5);

      return AdminStats(
        totalUsers: totalUsers,
        activeUsers: activeUsers,
        totalQueries: totalQueries,
        queriesLast7Days: queriesLast7Days,
        queriesLast30Days: queriesLast30Days,
        averageResponseTime: avgResponseTime,
        newSignups: newSignups,
        totalTopics: totalTopics,
        activeTopics: activeTopics,
        popularTopics: popularTopics,
      );
    } catch (e) {
      debugPrint('Error getting admin stats: $e');
      return AdminStats.empty();
    }
  }
}

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int totalQueries;
  final int queriesLast7Days;
  final int queriesLast30Days;
  final double averageResponseTime;
  final int newSignups;
  final int totalTopics;
  final int activeTopics;
  final List<Map<String, dynamic>> popularTopics;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalQueries,
    required this.queriesLast7Days,
    required this.queriesLast30Days,
    required this.averageResponseTime,
    required this.newSignups,
    required this.totalTopics,
    required this.activeTopics,
    required this.popularTopics,
  });

  factory AdminStats.empty() {
    return AdminStats(
      totalUsers: 0,
      activeUsers: 0,
      totalQueries: 0,
      queriesLast7Days: 0,
      queriesLast30Days: 0,
      averageResponseTime: 0.0,
      newSignups: 0,
      totalTopics: 0,
      activeTopics: 0,
      popularTopics: [],
    );
  }

  // Calculate percentage changes
  int get queriesChangePercent {
    if (queriesLast30Days == 0) return 0;
    final previousPeriod = queriesLast30Days - queriesLast7Days;
    if (previousPeriod == 0) return 0;
    return ((queriesLast7Days - previousPeriod) / previousPeriod * 100).round();
  }

  int get activeUsersChangePercent {
    // Estimate based on total users growth
    if (totalUsers == 0) return 0;
    return (newSignups * 100 / totalUsers).round();
  }
}

