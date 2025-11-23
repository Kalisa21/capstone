import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/favorites_service.dart';
import '../services/legal_topics_service.dart';
import '../models/legal_topic.dart';
import '../services/supabase_service.dart';
import 'legal_topic_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final ValueNotifier<List<FavoriteItem>> _favoritesNotifier;
  List<FavoriteItem> _favorites = [];
  Map<String, LegalTopic> _topicCache = {};

  @override
  void initState() {
    super.initState();
    _favoritesNotifier = FavoritesService.instance.favoritesNotifier;
    _favorites = _favoritesNotifier.value;
    _favoritesNotifier.addListener(_handleFavoritesChanged);
    _loadFavorites();
    _loadTopics();
  }

  void _handleFavoritesChanged() {
    if (!mounted) return;
    setState(() {
      _favorites = _favoritesNotifier.value;
    });
  }

  Future<void> _loadFavorites() async {
    await FavoritesService.instance.refresh();
  }

  Future<void> _loadTopics() async {
    final topics = LegalTopicsService.instance.topics;
    _topicCache = {for (var topic in topics) topic.id: topic};
  }

  @override
  void dispose() {
    _favoritesNotifier.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<void> _removeFavorite(FavoriteItem favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: const Text('Are you sure you want to remove this favorite?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FavoritesService.instance.removeFavorite(favorite.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favorite removed')),
        );
      }
    }
  }

  Widget _buildFavoriteItem(FavoriteItem favorite) {
    if (favorite.isTopic) {
      final topic = _topicCache[favorite.topicId!];
      if (topic == null) {
        return const SizedBox.shrink();
      }

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.gavel, color: Colors.white),
          ),
          title: Text(topic.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.description),
              if (favorite.notes != null && favorite.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Note: ${favorite.notes}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeFavorite(favorite),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LegalTopicDetailScreen(topic: topic),
              ),
            );
          },
        ),
      );
    } else {
      // Article favorite
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.accent,
            child: const Icon(Icons.article, color: Colors.white),
          ),
          title: Text('Article ${favorite.articleId ?? 'Unknown'}'),
          subtitle: favorite.notes != null && favorite.notes!.isNotEmpty
              ? Text('Note: ${favorite.notes}')
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeFavorite(favorite),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.primary,
        appBar: AppBar(
          title: const Text('Favorites'),
          backgroundColor: AppTheme.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Please sign in to view favorites',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/signin'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppTheme.primary,
        actions: [
          if (_favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFavorites,
            ),
        ],
      ),
      body: _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.white70),
                  const SizedBox(height: 16),
                  const Text(
                    'No favorites yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the heart icon on topics or articles to save them',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: ListView.builder(
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  return _buildFavoriteItem(_favorites[index]);
                },
              ),
            ),
    );
  }
}

