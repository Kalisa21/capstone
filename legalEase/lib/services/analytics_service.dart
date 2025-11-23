import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../models/legal_topic.dart';
import 'legal_topics_service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Get recent topics viewed by the user
  Future<List<LegalTopic>> getRecentTopics({int limit = 5}) async {
    if (!SupabaseService.isAuthenticated) return [];

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Get recent topics from user_analytics
      final response = await SupabaseService.client
          .from('user_analytics')
          .select('topics_studied')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(10);

      final allTopics = <String>{};
      for (final row in response as List<dynamic>) {
        if (row['topics_studied'] is List) {
          final topics = List<String>.from(row['topics_studied'] as List);
          allTopics.addAll(topics);
        }
      }

      // Get topic details
      final topics = LegalTopicsService.instance.topics;
      final recentTopics = <LegalTopic>[];
      for (final topicId in allTopics.take(limit)) {
        final topic = topics.firstWhere(
          (t) => t.id == topicId,
          orElse: () => topics.first,
        );
        if (!recentTopics.any((t) => t.id == topic.id)) {
          recentTopics.add(topic);
        }
      }

      return recentTopics;
    } catch (e) {
      debugPrint('Error getting recent topics: $e');
      return [];
    }
  }

  /// Get total time spent across all days
  Future<int> getTotalTimeSpent() async {
    if (!SupabaseService.isAuthenticated) return 0;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      final response = await SupabaseService.client
          .from('user_analytics')
          .select('time_spent_minutes')
          .eq('user_id', userId);

      int total = 0;
      for (final row in response as List<dynamic>) {
        final minutes = row['time_spent_minutes'];
        if (minutes is int) {
          total += minutes;
        } else if (minutes is num) {
          total += minutes.toInt();
        }
      }

      return total;
    } catch (e) {
      debugPrint('Error getting total time spent: $e');
      return 0;
    }
  }

  /// Get most frequently asked questions from chat history
  Future<List<PopularQuestion>> getPopularQuestions({int limit = 10}) async {
    if (!SupabaseService.isAuthenticated) return [];

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Get all messages (both user and assistant) ordered by creation time
      final allMessages = await SupabaseService.client
          .from('chat_messages')
          .select('id, content, role, session_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      // Count frequency of similar questions and find their answers
      final questionData = <String, Map<String, dynamic>>{};

      // Process messages to pair questions with answers
      for (int i = 0; i < (allMessages as List).length; i++) {
        final row = allMessages[i];
        final role = row['role']?.toString() ?? '';
        final content = row['content']?.toString().trim() ?? '';
        
        if (role == 'user' && content.isNotEmpty && content.length >= 10) {
          // Normalize question (lowercase, remove extra spaces)
          final normalized = content.toLowerCase().trim();
          
          // Group similar questions
          String? key;
          for (final existingKey in questionData.keys) {
            if (_areSimilar(normalized, existingKey.toLowerCase())) {
              key = existingKey;
              break;
            }
          }
          
          key ??= content; // Use original if no similar found
          
          // Initialize or update question data
          if (!questionData.containsKey(key)) {
            questionData[key] = {
              'count': 0,
              'lastAsked': DateTime.parse(row['created_at'].toString()),
              'answer': '',
              'answerDate': null,
            };
          }
          
          questionData[key]!['count'] = (questionData[key]!['count'] as int) + 1;
          
          final createdAt = DateTime.parse(row['created_at'].toString());
          if (createdAt.isAfter(questionData[key]!['lastAsked'] as DateTime)) {
            questionData[key]!['lastAsked'] = createdAt;
          }
          
          // Find the corresponding answer (next assistant message)
          // Try to find in same session first, then any following message
          final sessionId = row['session_id'];
          final questionTime = DateTime.parse(row['created_at'].toString());
          String? foundAnswer;
          DateTime? answerDate;
          
          // Look for the next assistant message (within reasonable time window)
          for (int j = i + 1; j < allMessages.length && j < i + 10; j++) {
            final nextRow = allMessages[j];
            final nextRole = nextRow['role']?.toString() ?? '';
            final nextTime = DateTime.parse(nextRow['created_at'].toString());
            
            // Don't look too far ahead (more than 5 minutes)
            if (nextTime.difference(questionTime).inMinutes > 5) {
              break;
            }
            
            if (nextRole == 'assistant') {
              final answerContent = nextRow['content']?.toString().trim() ?? '';
              if (answerContent.isNotEmpty && answerContent.length > 10) {
                // Prefer answer from same session
                if (sessionId != null && nextRow['session_id'] == sessionId) {
                  foundAnswer = answerContent;
                  answerDate = nextTime;
                  break; // Found in same session, use this one
                } else if (foundAnswer == null) {
                  // Use this as fallback if no same-session answer found yet
                  foundAnswer = answerContent;
                  answerDate = nextTime;
                }
              }
            } else if (nextRole == 'user') {
              // If we already found an answer, stop here
              // Otherwise, continue looking (might be multi-turn conversation)
              if (foundAnswer != null) {
                break;
              }
            }
          }
          
          // Update answer if we found one (prefer more recent answers)
          if (foundAnswer != null && foundAnswer.isNotEmpty) {
            final currentAnswerDate = questionData[key]!['answerDate'] as DateTime?;
            if (currentAnswerDate == null || 
                (answerDate != null && answerDate.isAfter(currentAnswerDate))) {
              questionData[key]!['answer'] = foundAnswer;
              questionData[key]!['answerDate'] = answerDate;
              debugPrint('Found answer for "${key.substring(0, key.length > 50 ? 50 : key.length)}": ${foundAnswer.substring(0, foundAnswer.length > 100 ? 100 : foundAnswer.length)}...');
            }
          } else {
            debugPrint('No answer found for question: "${key.substring(0, key.length > 50 ? 50 : key.length)}"');
          }
        }
      }

      // Sort by frequency and get top questions
      final sortedQuestions = questionData.entries.toList()
        ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

      final results = sortedQuestions.take(limit).map((entry) {
        final data = entry.value;
        final answer = data['answer'] as String? ?? '';
        debugPrint('FAQ: "${entry.key}" -> Answer length: ${answer.length}');
        return PopularQuestion(
          question: entry.key,
          answer: answer.isNotEmpty 
              ? answer
              : 'No answer available. Use the chatbot to get a response.',
          count: data['count'] as int,
          lastAsked: data['lastAsked'] as DateTime,
        );
      }).toList();
      
      debugPrint('Total FAQs with answers: ${results.where((r) => r.answer.isNotEmpty && !r.answer.contains('No answer available')).length}');
      return results;
    } catch (e) {
      debugPrint('Error getting popular questions: $e');
      return [];
    }
  }

  /// Check if two questions are similar (simple similarity check)
  bool _areSimilar(String q1, String q2) {
    // Simple similarity: check if one contains the other or share significant words
    if (q1.length < 10 || q2.length < 10) return false;
    
    final words1 = q1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = q2.split(' ').where((w) => w.length > 3).toSet();
    
    if (words1.isEmpty || words2.isEmpty) return false;
    
    final commonWords = words1.intersection(words2);
    final similarity = commonWords.length / 
        (words1.length + words2.length - commonWords.length);
    
    return similarity > 0.5; // 50% word overlap
  }

  /// Get statistics for analytics
  Future<AnalyticsStats> getAnalyticsStats() async {
    if (!SupabaseService.isAuthenticated) {
      return AnalyticsStats(
        totalTimeSpent: 0,
        totalArticlesViewed: 0,
        totalQueries: 0,
        totalTopicsStudied: 0,
        averageScore: 0.0,
      );
    }

    try {
      final userId = SupabaseService.currentUser!.id;
      
      final response = await SupabaseService.client
          .from('user_analytics')
          .select()
          .eq('user_id', userId);

      int totalTime = 0;
      int totalArticles = 0;
      int totalQueries = 0;
      final allTopics = <String>{};
      double totalScore = 0.0;
      int scoreCount = 0;

      for (final row in response as List<dynamic>) {
        totalTime += (row['time_spent_minutes'] as num?)?.toInt() ?? 0;
        totalArticles += (row['articles_viewed'] as num?)?.toInt() ?? 0;
        totalQueries += (row['queries_made'] as num?)?.toInt() ?? 0;
        
        if (row['topics_studied'] is List) {
          allTopics.addAll(List<String>.from(row['topics_studied'] as List));
        }
        
        final score = row['knowledge_score'];
        if (score != null) {
          totalScore += (score as num).toDouble();
          scoreCount++;
        }
      }

      return AnalyticsStats(
        totalTimeSpent: totalTime,
        totalArticlesViewed: totalArticles,
        totalQueries: totalQueries,
        totalTopicsStudied: allTopics.length,
        averageScore: scoreCount > 0 ? totalScore / scoreCount : 0.0,
      );
    } catch (e) {
      debugPrint('Error getting analytics stats: $e');
      return AnalyticsStats(
        totalTimeSpent: 0,
        totalArticlesViewed: 0,
        totalQueries: 0,
        totalTopicsStudied: 0,
        averageScore: 0.0,
      );
    }
  }
}

class PopularQuestion {
  final String question;
  final String answer;
  final int count;
  final DateTime lastAsked;

  PopularQuestion({
    required this.question,
    required this.answer,
    required this.count,
    required this.lastAsked,
  });
}

class AnalyticsStats {
  final int totalTimeSpent;
  final int totalArticlesViewed;
  final int totalQueries;
  final int totalTopicsStudied;
  final double averageScore;

  AnalyticsStats({
    required this.totalTimeSpent,
    required this.totalArticlesViewed,
    required this.totalQueries,
    required this.totalTopicsStudied,
    required this.averageScore,
  });
}

