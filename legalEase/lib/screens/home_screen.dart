import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/case_card.dart';
import '../models/legal_topic.dart';
import '../services/legal_topics_service.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'legal_topic_detail_screen.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_overlay.dart';
import '../services/supabase_service.dart';
import '../services/favorites_service.dart';
import '../services/learning_progress_service.dart';
import '../services/analytics_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  File? _profileImageFile;
  static const _kProfileImagePathKey = 'user_profile_image_path';

  // NEW: dynamic analytics state
  final math.Random _rand = math.Random();
  double _gaugeProgress = 0.76; // 76%
  int _timeSpentHours = 2;
  late List<double> _learningBars = List<double>.generate(
    12,
    (_) => 20 + _rand.nextInt(40).toDouble(),
  );

  int _selectedChip = 0;
  late final ValueNotifier<List<LegalTopic>> _topicsNotifier;
  List<LegalTopic> _topics = const [];

  // Chatbot state
  bool _overlayOpen = false;
  bool _isLoading = false;
  String? _currentSessionId;
  String _selectedLanguage = 'en';
  final List<Map<String, String>> _chatMessages = [];
  
  // Base URL for FastAPI
  // For Android emulator override with --dart-define=API_BASE=http://10.0.2.2:8000
  // For desktop/web/iOS simulators default localhost works.
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8000',
  );

  @override
  void initState() {
    super.initState();
    _topicsNotifier = LegalTopicsService.instance.topicsNotifier;
    _topics = _topicsNotifier.value.where((topic) => topic.isActive).toList();
    _topicsNotifier.addListener(_handleTopicsChanged);
    _loadProfileImage();
    _loadChatHistory();
  }

  void _handleTopicsChanged() {
    if (!mounted) return;
    setState(() {
      _topics = _topicsNotifier.value.where((topic) => topic.isActive).toList();
    });
  }

  @override
  void dispose() {
    _topicsNotifier.removeListener(_handleTopicsChanged);
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kProfileImagePathKey);
    if (path != null && mounted) {
      final f = File(path);
      if (await f.exists()) {
        setState(() => _profileImageFile = f);
      }
    }
  }

  Future<void> _saveImage(File original) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(
        '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await original.copy(target.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProfileImagePathKey, target.path);
      if (mounted) setState(() => _profileImageFile = target);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProfileImagePathKey, original.path);
      if (mounted) setState(() => _profileImageFile = original);
    }
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickProfileImage() async {
    // Desktop & web: open native file picker directly
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: 'Select profile image',
      );
      if (result == null || result.files.isEmpty) {
        _notify('No file selected');
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _notify('Invalid file');
        return;
      }
      await _saveImage(File(path));
      return;
    }

    // Mobile: offer gallery, camera, or files
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery / Photos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Files'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'files') {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) {
        _notify('No file selected');
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _notify('Invalid file');
        return;
      }
      await _saveImage(File(path));
      return;
    }

    final picker = ImagePicker();
    final src = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked = await picker.pickImage(
        source: src,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) {
        _notify('No image selected');
        return;
      }
      await _saveImage(File(picked.path));
    } catch (e) {
      _notify('Failed: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // Chatbot methods
  Future<void> _loadChatHistory() async {
    if (!SupabaseService.isAuthenticated) return;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      final response = await SupabaseService.client
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(50);

      if (mounted && response is List && response.isNotEmpty) {
        setState(() {
          for (final msg in response) {
            if (msg is Map<String, dynamic> && 
                msg['id'] != null && 
                msg['content'] != null &&
                msg['role'] != null) {
              final role = msg['role'].toString();
              final content = msg['content'].toString();
              if (content.isNotEmpty) {
                _chatMessages.add({
                  'id': msg['id'].toString(),
                  'from': role == 'assistant' ? 'bot' : 'user',
                  'text': content,
                });
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<String?> _saveMessageToSupabase({
    required String role,
    required String content,
    String? sessionId,
    Map<String, dynamic>? metadata,
    List<String>? articleReferences,
  }) async {
    if (!SupabaseService.isAuthenticated) return null;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      try {
        final existing = await SupabaseService.client
            .from('profiles')
            .select('user_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (existing == null) {
          final email = SupabaseService.currentUser!.email ?? 'user@example.com';
          final fallbackName = email.split('@').first;
          await SupabaseService.client.from('profiles').insert({
            'user_id': userId,
            'name': fallbackName,
            'about': 'User',
            'role': 'user',
          });
        }
      } catch (_) {}

      final messageData = <String, dynamic>{
        'user_id': userId,
        'role': role,
        'content': content,
      };
      
      if (sessionId != null && sessionId.isNotEmpty) {
        messageData['session_id'] = sessionId;
      }
      if (metadata != null && metadata.isNotEmpty) {
        messageData['metadata'] = metadata;
      }
      if (articleReferences != null && articleReferences.isNotEmpty) {
        messageData['article_references'] = articleReferences;
      }

      Future<String?> _doInsert() async {
        final response = await SupabaseService.client
            .from('chat_messages')
            .insert(messageData)
            .select()
            .single();
        if (response is Map<String, dynamic> && response['id'] != null) {
          return response['id'].toString();
        }
        return null;
      }

      try {
        final id = await _doInsert();
        return id;
      } catch (pe) {
        final msg = pe.toString().toLowerCase();
        if (msg.contains('23503') || (msg.contains('foreign key') && msg.contains('user_id'))) {
          await Future.delayed(const Duration(milliseconds: 200));
          try {
            final id = await _doInsert();
            return id;
          } catch (_) {}
        }
        debugPrint('DB error saving chat: $pe');
        return null;
      }
    } catch (e) {
      debugPrint('Unexpected error in _saveMessageToSupabase: $e');
      return null;
    }
  }

  Future<void> _sendChatMessage(String text) async {
    if (!SupabaseService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to use the chatbot')),
      );
      return;
    }

    setState(() {
      _chatMessages.add({
        'id': DateTime.now().toIso8601String(),
        'from': 'user',
        'text': text,
      });
      _isLoading = true;
    });

    await _saveMessageToSupabase(
      role: 'user',
      content: text,
      sessionId: _currentSessionId,
    );

    // Track learning activity
    await LearningProgressService.instance.recordActivity(
      activityType: 'chat_query',
    );

    try {
      final uri = Uri.parse('$apiBase/search');
      final response = await http.post(
        uri,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': text,
          'top_k': 1,
          'language_filter': _selectedLanguage,
          'min_score': 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        final totalResults = data['total_results'] ?? 0;
        final processingTime = data['processing_time_ms'] ?? 0.0;

        if (results.isNotEmpty) {
          final articleIds = <String>[];
          for (final result in results) {
            final articleId = result['id']?.toString();
            if (articleId != null) {
              articleIds.add(articleId);
            }
          }

          for (final result in results) {
            final articleId = result['id']?.toString();
            final articleLabel = result['article_label'] ?? 'Unknown Article';
            final articleText = result['article_text'] ?? 'No content available';
            final language = result['language'] ?? 'unknown';
            final score = result['similarity_score'] ?? 0.0;

            final formattedResult = '''📋 $articleLabel (${language.toUpperCase()})
🎯 Relevance: ${(score * 100).toStringAsFixed(1)}%

$articleText''';

            setState(() {
              _chatMessages.add({
                'id': DateTime.now().toIso8601String(),
                'from': 'bot',
                'text': formattedResult.trim(),
              });
            });

            await _saveMessageToSupabase(
              role: 'assistant',
              content: formattedResult.trim(),
              sessionId: _currentSessionId,
              metadata: {
                if (articleId != null) 'article_id': articleId,
                'article_label': articleLabel,
                'language': language,
                'similarity_score': score,
                'processing_time_ms': processingTime,
                'total_results': totalResults,
              },
              articleReferences: articleIds.isNotEmpty ? articleIds : null,
            );
          }
        } else {
          final noResultsMsg = 'No relevant legal articles found for your query. Please try rephrasing your question.';

          setState(() {
            _chatMessages.add({
              'id': DateTime.now().toIso8601String(),
              'from': 'bot',
              'text': noResultsMsg,
            });
          });

          await _saveMessageToSupabase(
            role: 'assistant',
            content: noResultsMsg,
            sessionId: _currentSessionId,
            metadata: {
              'total_results': 0,
              'processing_time_ms': processingTime,
              'has_results': false,
            },
          );
        }
      } else {
        final errorMsg = '⚠️ ${response.statusCode}: ${response.reasonPhrase}\n${response.body}';

        setState(() {
          _chatMessages.add({
            'id': DateTime.now().toIso8601String(),
            'from': 'bot',
            'text': errorMsg,
          });
        });

        await _saveMessageToSupabase(
          role: 'assistant',
          content: errorMsg,
          sessionId: _currentSessionId,
          metadata: {
            'error': true,
            'status_code': response.statusCode,
          },
        );
      }
    } catch (e) {
      final errorMsg = '❌ Connection error: $e';

      setState(() {
        _chatMessages.add({
          'id': DateTime.now().toIso8601String(),
          'from': 'bot',
          'text': errorMsg,
        });
      });

      await _saveMessageToSupabase(
        role: 'assistant',
        content: errorMsg,
        sessionId: _currentSessionId,
        metadata: {
          'error': true,
          'error_message': e.toString(),
        },
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleChatOverlay() => setState(() => _overlayOpen = !_overlayOpen);

  Widget _buildLearningProgressContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadAnalyticsData(),
      builder: (context, snapshot) {
        final progress = LearningProgressService.instance.progress ?? LearningProgress(
          id: '',
          userId: SupabaseService.currentUser?.id ?? '',
          date: DateTime.now(),
        );

        final stats = snapshot.data?['stats'] as AnalyticsStats?;
        final recentTopics = snapshot.data?['recentTopics'] as List<LegalTopic>? ?? [];
        final totalTime = stats?.totalTimeSpent ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Knowledge Score Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Knowledge Score',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: progress.knowledgeScore / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${progress.knowledgeScore.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  _buildProgressCard(
                    'Time Spent',
                    _formatTime(totalTime),
                    Icons.access_time,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildProgressCard(
                    'Articles',
                    '${stats?.totalArticlesViewed ?? progress.articlesViewed}',
                    Icons.article,
                    Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _buildProgressCard(
                    'Queries',
                    '${stats?.totalQueries ?? progress.queriesMade}',
                    Icons.chat,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildProgressCard(
                    'Topics',
                    '${stats?.totalTopicsStudied ?? progress.topicsStudied.length}',
                    Icons.gavel,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Topics Section
              if (recentTopics.isNotEmpty) ...[
                const Text(
                  'Recent Topics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentTopics.length,
                    itemBuilder: (context, index) {
                      final topic = recentTopics[index];
                      return Container(
                        width: 200,
                        margin: EdgeInsets.only(
                          right: index < recentTopics.length - 1 ? 12 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gavel,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                topic.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Training Time Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, color: AppTheme.accent, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Training Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow('Total Time Spent', _formatTime(totalTime)),
                    const SizedBox(height: 12),
                    _buildStatRow('Total Articles Viewed', '${stats?.totalArticlesViewed ?? 0}'),
                    const SizedBox(height: 12),
                    _buildStatRow('Total Queries Made', '${stats?.totalQueries ?? 0}'),
                    const SizedBox(height: 12),
                    _buildStatRow('Average Knowledge Score', '${(stats?.averageScore ?? 0.0).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadAnalyticsData() async {
    final stats = await AnalyticsService.instance.getAnalyticsStats();
    final recentTopics = await AnalyticsService.instance.getRecentTopics();
    return {
      'stats': stats,
      'recentTopics': recentTopics,
    };
  }

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesContent() {
    return FutureBuilder<List<FavoriteItem>>(
      future: FavoritesService.instance.refresh().then((_) => FavoritesService.instance.favorites),
      builder: (context, snapshot) {
        final favorites = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // Filter to only topic favorites
        final topicFavorites = favorites.where((f) => f.isTopic).toList();
        
        // Get topic details
        final topics = LegalTopicsService.instance.topics;
        final favoriteTopics = topicFavorites
            .map((fav) {
              if (fav.topicId == null) return null;
              final topic = topics.firstWhere(
                (t) => t.id == fav.topicId,
                orElse: () => topics.first,
              );
              return {'favorite': fav, 'topic': topic};
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>()
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Favorite Topics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (favoriteTopics.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.favorite_border, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No favorite topics yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the heart icon on topics to save them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...favoriteTopics.map((item) {
                  final favorite = item['favorite'] as FavoriteItem;
                  final topic = item['topic'] as LegalTopic;
                  final imagePath = _resolveTopicImage(topic);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _LegalTopicDetailCard(
                      topic: topic,
                      imagePath: imagePath,
                      onTap: () async {
                        // Track learning activity
                        await LearningProgressService.instance.recordActivity(
                          activityType: 'view_article',
                          topicId: topic.id,
                        );
                        
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LegalTopicDetailScreen(topic: topic),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpContent() {
    // Default FAQs - always show these
    final defaultFaqs = const [
      _Faq(
        'How do I search for a law or article?',
        'Use the search bar on the Home tab. Type keywords like "business registration" or an article number.',
      ),
      _Faq(
        'Can I filter results by category?',
        'Yes. Use the topic chips (criminal, civil, business, etc.) to narrow your results.',
      ),
      _Faq(
        'How do I chat with the legal assistant?',
        'Tap the Chatbot tab in the bottom navigation bar and ask your question.',
      ),
      _Faq(
        'Why am I not seeing responses from the chatbot?',
        'Ensure your API is running and the app points to the correct base URL (Android emulator uses 10.0.2.2).',
      ),
      _Faq(
        'Can I save or bookmark a result?',
        'Tap the heart icon on topic cards to save them for quick access later.',
      ),
      _Faq(
        'How do I view my learning progress?',
        'Tap the Analytics tab in the bottom navigation bar to see your knowledge score, time spent, and recent topics.',
      ),
      _Faq(
        'Can I access my chat history?',
        'Yes! Your chat conversations are automatically saved. Tap the Chatbot tab to continue previous conversations.',
      ),
    ];

    return FutureBuilder<List<PopularQuestion>>(
      future: AnalyticsService.instance.getPopularQuestions(limit: 10),
      builder: (context, snapshot) {
        // Handle errors silently - always show default FAQs
        if (snapshot.hasError) {
          debugPrint('Error loading FAQs: ${snapshot.error}');
        }

        final popularQuestions = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // Use popular questions if available, otherwise use defaults
        final faqsToShow = popularQuestions.isNotEmpty
            ? popularQuestions.map((pq) => _Faq(
                  pq.question,
                  pq.answer,
                )).toList()
            : defaultFaqs;

        // Debug: Log FAQ count
        debugPrint('FAQs to show: ${faqsToShow.length}');

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Info banner
              if (popularQuestions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Based on frequently asked questions from chat history',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Rwanda laws link card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.gavel, color: Colors.black87),
                  title: const Text(
                    'Rwanda laws',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Open external legal resource',
                    style: TextStyle(color: Colors.black54),
                  ),
                  trailing: const Icon(
                    Icons.open_in_new,
                    color: Colors.black54,
                  ),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://rwandalii.org/akn/rw/act/law/2018/68/eng@2018-09-27',
                    );
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // FAQ list - always show FAQs
              _FaqListCard(faqs: faqsToShow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      // Home content redesigned
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: greeting + profile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title area
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Hello, Willy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                // Profile button (keeps existing navigation)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      onPressed: () => Navigator.pushNamed(context, '/chat-sessions'),
                      tooltip: 'Chat Sessions',
                    ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                      onLongPress: _pickProfileImage,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImageFile != null
                        ? FileImage(_profileImageFile!)
                        : null,
                    child: _profileImageFile == null
                        ? Icon(Icons.person, color: AppTheme.primary)
                        : null,
                  ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search with filter button
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56, // increased height to match the look
                    child: CustomSearchBar(placeholder: 'Search'),
                  ),
                ),
                const SizedBox(width: 10),
                Ink(
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  child: SizedBox.square(
                    dimension: 56, // match search height
                    child: IconButton(
                      onPressed: () {
                        // TODO: hook up a filter screen if you have one
                        // Navigator.pushNamed(context, '/filters');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(), // keep size at 56x56
                      icon: Icon(
                        Icons.tune,
                        color: AppTheme.primary,
                        size: 22, // comfortable icon size for 56dp button
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              ' Explore topics',
              // Adapt the text if you want: e.g. 'Select your next topic'
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _buildTopicPicker(),

            const SizedBox(height: 24),

            // Spacer for the floating nav bar
            const SizedBox(height: 40),
          ],
        ),
      );
    } else if (_selectedIndex == 1) {
      // Analytics tab - show Learning Progress screen
      return _buildLearningProgressContent();
    } else if (_selectedIndex == 2) {
      // Favorites tab - Show favorite legal topics
      return _buildFavoritesContent();
    } else if (_selectedIndex == 3) {
      // Help/Knowledge tab - Show FAQs from chat history
      return _buildHelpContent();
    } else if (_selectedIndex == 4) {
      // Chatbot tab
      return Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Legal Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rwandan law expert',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: _toggleChatOverlay,
                      tooltip: 'Menu',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Welcome message (if no messages)
              if (_chatMessages.isEmpty && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to Legal Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Ask me anything about Rwandan law. I\'m here to help you understand legal topics and find relevant articles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _QuickQuestionChip(
                              text: 'What is a crime?',
                              onTap: () => _sendChatMessage('What is a crime?'),
                            ),
                            _QuickQuestionChip(
                              text: 'Property rights',
                              onTap: () => _sendChatMessage('Property rights'),
                            ),
                            _QuickQuestionChip(
                              text: 'Business registration',
                              onTap: () => _sendChatMessage('Business registration'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Messages list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _chatMessages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _chatMessages.length && _isLoading) {
                        // Show loading bubble with animation
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12, top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Thinking...",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final m = _chatMessages[i];
                      final isBot = m['from'] == 'bot';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: isBot
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isBot ? Colors.white : AppTheme.accent,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isBot ? 4 : 20),
                                bottomRight: Radius.circular(isBot ? 20 : 4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isBot)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.gavel,
                                          size: 14,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Legal Assistant',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'You',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  m['text']!,
                                  style: TextStyle(
                                    color: isBot ? Colors.black87 : Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Input Field
              ChatInput(onSend: _sendChatMessage),
            ],
          ),

          // Overlay for new chat / history / language
          ChatOverlay(
            open: _overlayOpen,
            onClose: _toggleChatOverlay,
            selectedLanguage: _selectedLanguage,
            onLanguageSelected: (lang) {
              setState(() {
                _selectedLanguage = lang;
              });
            },
            onNewChat: () {
              setState(() {
                _chatMessages.clear();
                _currentSessionId = null;
              });
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTopicPicker() {
    final topics = _topics;

    if (topics.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Text(
            'Topics for you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'No legal topics yet. Check back soon!',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    final categoryKeys = <String>{};
    for (final topic in topics) {
      final key = (topic.category ?? '').trim().toLowerCase();
      if (key.isNotEmpty) {
        categoryKeys.add(key);
      }
    }

    final categories = ['all', ...categoryKeys.toList()..sort()];
    var selectedIndex = _selectedChip;
    if (selectedIndex >= categories.length) {
      selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedChip = 0);
        }
      });
    }

    final selectedKey = categories[selectedIndex];
    final filteredTopics = selectedKey == 'all'
        ? topics
        : topics
              .where(
                (topic) =>
                    (topic.category ?? '').trim().toLowerCase() == selectedKey,
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isSelected = index == selectedIndex;
              final label = _formatCategoryLabel(categories[index]);
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedChip = index);
                },
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                selectedColor: AppTheme.accent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        // Full Details Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All Legal Topics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (filteredTopics.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Could add a "View All" screen here if needed
                },
                child: Text(
                  'View All (${filteredTopics.length})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Full detail topic cards
        if (filteredTopics.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 48,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No topics available',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Topics will appear here once added',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredTopics.length > 3 ? 3 : filteredTopics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final topic = filteredTopics[index];
              final imagePath = _resolveTopicImage(topic);
              return _LegalTopicDetailCard(
                topic: topic,
                imagePath: imagePath,
                onTap: () async {
                  // Track learning activity
                  await LearningProgressService.instance.recordActivity(
                    activityType: 'view_article',
                    topicId: topic.id,
                  );
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          LegalTopicDetailScreen(topic: topic),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  String _formatCategoryLabel(String key) {
    if (key == 'all') return 'All';
    final parts = key
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase());
    final label = parts.join(' ');
    return label.isEmpty ? 'General' : label;
  }

  String _resolveTopicImage(LegalTopic topic) {
    final image = topic.effectiveImage;
    if (image != null && image.isNotEmpty) {
      return image;
    }

    final key = topic.slug.toLowerCase();
    if (key.contains('criminal')) return 'assets/criminal.png';
    if (key.contains('civil')) return 'assets/civil.png';
    if (key.contains('business')) return 'assets/business.png';
    if (key.contains('tax')) return 'assets/taxation.png';
    if (key.contains('personal') || key.contains('injury')) {
      return 'assets/pi.png';
    }
    if (key.contains('human')) return 'assets/gavel.png';
    return 'assets/gavel.png';
  }

  void _refreshDashboard() {
    setState(() {
      _gaugeProgress = 0.3 + _rand.nextDouble() * 0.6; // 0.3..0.9
      _timeSpentHours = 1 + _rand.nextInt(5); // 1..5 hrs
      _learningBars = List<double>.generate(
        12,
        (_) => 16 + _rand.nextInt(44).toDouble(),
      );
    });
  }

  Widget _floatingNavBar(BuildContext context) {
    final items = const [
      (Icons.home, 'Home'),
      (Icons.bar_chart, 'Analytics'),
      (Icons.favorite, 'Favorites'),
      (Icons.lightbulb, 'Help'),
      (Icons.chat, 'Chatbot'),
    ];

    Color selectedColor = AppTheme.accent;
    Color unselectedColor = Colors.black54;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final (icon, label) = items[i];
            final isSelected = _selectedIndex == i;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => _onItemTapped(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? selectedColor : unselectedColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? selectedColor : unselectedColor,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _floatingNavBar(context),
          ),
      ),
    );
  }
}

// A placeholder carousel mimicking the big stacked cards.
// Replace its internal content with your real data later.
class _CardStackPlaceholder extends StatefulWidget {
  // NEW: optional images for the cards (asset paths or URLs)
  final List<String> images;
  const _CardStackPlaceholder({this.images = const []});

  @override
  State<_CardStackPlaceholder> createState() => _CardStackPlaceholderState();
}

class _CardStackPlaceholderState extends State<_CardStackPlaceholder> {
  late final PageController _controller;

  String _prettyTitleFromPath(String src) {
    if (src.isEmpty) return 'Topic';
    final name = src.split('/').last.split('.').first;
    if (name.isEmpty) return 'Topic';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper: asset or network image with safe fallback
  Widget _cardImage(String src) {
    final border = BorderRadius.circular(24);
    if (src.startsWith('http')) {
      return ClipRRect(
        borderRadius: border,
        child: Image.network(
          src,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: border,
        child: Image.asset(
          src,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images; // keep empty to use plain white cards
    final itemCount = imgs.isNotEmpty ? imgs.length : 4;

    return SizedBox(
      height: 340,
      child: PageView.builder(
        controller: _controller,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              children: [
                // Shadow/backdrop (unchanged)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade300.withOpacity(0.25),
                          Colors.black.withOpacity(0.15),
                        ],
                      ),
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                // Foreground card with optional image
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imgs.isNotEmpty) _cardImage(imgs[index]),
                        if (imgs.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.black.withOpacity(
                                0.12,
                              ), // light tint
                            ),
                          ),
                        // Heart/favorite (unchanged)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white70,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.favorite_border,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        // Bottom info + See more (unchanged)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'civil',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Legal',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'views',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Bottom action: See more only (removed title/subtitle/reviews)
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // NEW: open topic overlay with derived title
                                    final title = _prettyTitleFromPath(
                                      imgs[index],
                                    );
                                    TopicOverlay.show(
                                      context,
                                      title: title,
                                      imagePath: imgs[index],
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('See more'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Small circular icon used in the section header
Widget _circleIcon(IconData icon) {
  return Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: Colors.black87, size: 20),
  );
}

// Simple divider line for list inside white cards
class _DividerLine extends StatelessWidget {
  const _DividerLine();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0x11000000));
  }
}

// Recent deal row (company + manager)
class _DealRow extends StatelessWidget {
  final String letter;
  final String company;
  final String manager;
  const _DealRow({
    required this.letter,
    required this.company,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.shade100,
            child: Text(letter, style: const TextStyle(color: Colors.black87)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              company,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  manager.isNotEmpty ? manager[0] : '?',
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(manager, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

// Semicircle gauge as in the mock
class SemiCircleGauge extends StatelessWidget {
  final double progress; // 0..1
  final Color backgroundColor;
  final Gradient gradient;
  const SemiCircleGauge({
    super.key,
    required this.progress,
    required this.backgroundColor,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SemiCirclePainter(
        progress: progress.clamp(0.0, 1.0),
        backgroundColor: backgroundColor,
        gradient: gradient,
      ),
      size: const Size(double.infinity, 160),
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Gradient gradient;

  _SemiCirclePainter({
    required this.progress,
    required this.backgroundColor,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 18.0;
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2 - 16, size.height - 16);

    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = backgroundColor
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round;

    const start = math.pi;
    const totalSweep = math.pi;

    // background arc
    canvas.drawArc(rect, start, totalSweep, false, bg);
    // progress arc
    canvas.drawArc(rect, start, totalSweep * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _SemiCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gradient != gradient;
  }
}

// FAQ list card widget
class _FaqListCard extends StatelessWidget {
  final List<_Faq> faqs;
  const _FaqListCard({required this.faqs});

  @override
  Widget build(BuildContext context) {
    if (faqs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No FAQs available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // card on dark background
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: faqs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No FAQs available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 1, color: Color(0x11000000)),
              itemBuilder: (context, i) {
                final item = faqs[i];
                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      item.q,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    iconColor: Colors.black54,
                    collapsedIconColor: Colors.black45,
                    children: [
                      Text(
                        item.a,
                        style: const TextStyle(color: Colors.black54, height: 1.35),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

// Quick question chip widget for chatbot
class _QuickQuestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _QuickQuestionChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LegalTopicDetailCard extends StatefulWidget {
  final LegalTopic topic;
  final String? imagePath;
  final VoidCallback onTap;

  const _LegalTopicDetailCard({
    required this.topic,
    required this.imagePath,
    required this.onTap,
  });

  @override
  State<_LegalTopicDetailCard> createState() => _LegalTopicDetailCardState();
}

class _LegalTopicDetailCardState extends State<_LegalTopicDetailCard> {
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    if (!SupabaseService.isAuthenticated) return;
    final isFav = await FavoritesService.instance.isFavorite(
      topicId: widget.topic.id,
    );
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (!SupabaseService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add favorites')),
      );
      return;
    }

    setState(() => _isLoading = true);
    if (_isFavorite) {
      final favoriteId = await FavoritesService.instance.getFavoriteId(
        topicId: widget.topic.id,
      );
      if (favoriteId != null) {
        await FavoritesService.instance.removeFavorite(favoriteId);
      }
    } else {
      await FavoritesService.instance.addFavorite(topicId: widget.topic.id);
    }
    setState(() {
      _isLoading = false;
      _isFavorite = !_isFavorite;
    });
  }

  Widget _buildImage() {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.9),
              AppTheme.primary.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.gavel,
            size: 48,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    }

    if (widget.imagePath!.startsWith('http')) {
      return Image.network(
        widget.imagePath!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 160,
          color: AppTheme.primary.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Image.asset(
      widget.imagePath!,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        color: AppTheme.primary.withOpacity(0.3),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: _buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.topic.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.topic.categoryLabel.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.topic.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87.withOpacity(0.7),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Read more',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.grey,
                              ),
                        onPressed: _toggleFavorite,
                        tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                      ),
                      if (widget.topic.isActive)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
