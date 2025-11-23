import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  final ValueNotifier<List<FavoriteItem>> favoritesNotifier =
      ValueNotifier<List<FavoriteItem>>([]);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;
    await refresh();
  }

  List<FavoriteItem> get favorites => List.unmodifiable(favoritesNotifier.value);

  Future<void> refresh() async {
    if (!SupabaseService.isAuthenticated) {
      favoritesNotifier.value = [];
      return;
    }

    try {
      final userId = SupabaseService.currentUser!.id;
      final response = await SupabaseService.client
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final favorites = (response as List<dynamic>)
          .map((row) => FavoriteItem.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();

      favoritesNotifier.value = favorites;
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      favoritesNotifier.value = [];
    }
  }

  Future<bool> addFavorite({
    String? articleId,
    String? topicId,
    String? notes,
  }) async {
    if (!SupabaseService.isAuthenticated) return false;
    if (articleId == null && topicId == null) return false;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Check if already favorited
      var query = SupabaseService.client
          .from('user_favorites')
          .select()
          .eq('user_id', userId);
      
      if (articleId != null) {
        query = query.eq('article_id', articleId);
      } else if (topicId != null) {
        query = query.eq('topic_id', topicId);
      }
      
      final existing = await query.maybeSingle();

      if (existing != null) {
        // Update notes if provided
        if (notes != null) {
          await SupabaseService.client
              .from('user_favorites')
              .update({'notes': notes})
              .eq('id', existing['id']);
        }
        await refresh();
        return true;
      }

      await SupabaseService.client.from('user_favorites').insert({
        'user_id': userId,
        if (articleId != null) 'article_id': articleId,
        if (topicId != null) 'topic_id': topicId,
        if (notes != null) 'notes': notes,
      });

      await refresh();
      return true;
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String favoriteId) async {
    if (!SupabaseService.isAuthenticated) return false;

    try {
      await SupabaseService.client
          .from('user_favorites')
          .delete()
          .eq('id', favoriteId);

      await refresh();
      return true;
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return false;
    }
  }

  Future<bool> isFavorite({String? articleId, String? topicId}) async {
    if (!SupabaseService.isAuthenticated) return false;
    if (articleId == null && topicId == null) return false;

    try {
      final userId = SupabaseService.currentUser!.id;
      var query = SupabaseService.client
          .from('user_favorites')
          .select('id')
          .eq('user_id', userId);
      
      if (articleId != null) {
        query = query.eq('article_id', articleId);
      } else if (topicId != null) {
        query = query.eq('topic_id', topicId);
      }
      
      final response = await query.maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }

  Future<String?> getFavoriteId({String? articleId, String? topicId}) async {
    if (!SupabaseService.isAuthenticated) return null;
    if (articleId == null && topicId == null) return null;

    try {
      final userId = SupabaseService.currentUser!.id;
      var query = SupabaseService.client
          .from('user_favorites')
          .select('id')
          .eq('user_id', userId);
      
      if (articleId != null) {
        query = query.eq('article_id', articleId);
      } else if (topicId != null) {
        query = query.eq('topic_id', topicId);
      }
      
      final response = await query.maybeSingle();

      return response?['id']?.toString();
    } catch (e) {
      debugPrint('Error getting favorite ID: $e');
      return null;
    }
  }
}

class FavoriteItem {
  final String id;
  final String? articleId;
  final String? topicId;
  final String? notes;
  final DateTime createdAt;

  FavoriteItem({
    required this.id,
    this.articleId,
    this.topicId,
    this.notes,
    required this.createdAt,
  });

  bool get isArticle => articleId != null;
  bool get isTopic => topicId != null;

  factory FavoriteItem.fromMap(Map<String, dynamic> map) {
    return FavoriteItem(
      id: map['id']?.toString() ?? '',
      articleId: map['article_id']?.toString(),
      topicId: map['topic_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }
}

