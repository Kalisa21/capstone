import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/chat_sessions_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_overlay.dart';

class ChatbotScreen extends StatefulWidget {
  final String? sessionId;
  const ChatbotScreen({super.key, this.sessionId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  bool _overlayOpen = false;
  bool _isLoading = false;
  String? _currentSessionId;
  String _selectedLanguage = 'en'; // Default language
  bool _isGuestMode = false;
  bool _hasAskedFirstQuestion = false;
  bool _showSignInPrompt = false;

  // Base URL for FastAPI
  // Override via: --dart-define=API_BASE=http://192.168.1.67:8000
  // Using LAN backend default so physical devices can reach it.
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.67:8000',
  );

  // Start with no initial message
  final List<Map<String, String>> _msgs = [];

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    _isGuestMode = !SupabaseService.isAuthenticated;
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    if (!SupabaseService.isAuthenticated) {
      // Guest mode - no session needed
      _isGuestMode = true;
      return;
    }
    
    if (_currentSessionId == null) {
      // Create a new session
      _currentSessionId = await ChatSessionsService.instance.createSession(
        language: _selectedLanguage,
      );
    }
    await _loadChatHistory();
  }

  /// Load chat history from Supabase
  Future<void> _loadChatHistory() async {
    if (!SupabaseService.isAuthenticated) return;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Load messages for current session (or all if no session)
      var query = SupabaseService.client
          .from('chat_messages')
          .select()
          .eq('user_id', userId);
      
      if (_currentSessionId != null) {
        query = query.eq('session_id', _currentSessionId!);
      }
      
      final response = await query
          .order('created_at', ascending: true)
          .limit(50);

      if (mounted && response != null && response is List && response.isNotEmpty) {
        setState(() {
          for (final msg in response) {
            if (msg != null && 
                msg is Map<String, dynamic> && 
                msg['id'] != null && 
                msg['content'] != null &&
                msg['role'] != null) {
              final role = msg['role'].toString();
              final content = msg['content'].toString();
              if (content.isNotEmpty) {
                _msgs.add({
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
      // Continue silently - app works without history
    }
  }

  void _toggleOverlay() => setState(() => _overlayOpen = !_overlayOpen);

  /// Save message to Supabase chat_messages table
  Future<String?> _saveMessageToSupabase({
    required String role, // 'user' or 'assistant'
    required String content,
    String? sessionId,
    Map<String, dynamic>? metadata,
    List<String>? articleReferences,
  }) async {
    if (!SupabaseService.isAuthenticated) return null;

    try {
      final userId = SupabaseService.currentUser!.id;
      
      // Ensure a profile row exists to satisfy the foreign key
      try {
        final existing = await SupabaseService.client
            .from('profiles')
            .select('user_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (existing == null) {
          // Minimal profile
          final email = SupabaseService.currentUser!.email ?? 'user@example.com';
          final fallbackName = email.split('@').first;
          await SupabaseService.client.from('profiles').insert({
            'user_id': userId,
            'name': fallbackName,
            'about': 'User',
            'role': 'user',
          });
        }
      } catch (_) {
        // Ignore; trigger might have created it already
      }

      // Build message data, only including non-null values
      final messageData = <String, dynamic>{
        'user_id': userId,
        'role': role,
        'content': content,
      };
      
      // Only add optional fields if they are not null
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
        if (response != null && response is Map<String, dynamic> && response['id'] != null) {
          return response['id'].toString();
        }
        return null;
      }

      try {
        final id = await _doInsert();
        return id;
      } catch (pe) {
        // Retry once if foreign key fails (profile not yet committed)
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
      // Outer guard – any unexpected error
      debugPrint('Unexpected error in _saveMessageToSupabase: $e');
      return null;
    }
  }

  Future<void> _showSignInDialog() async {
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Continue as Guest or Sign Up?'),
        content: const Text(
          'To continue chatting and save your conversation history, please sign up. You can also continue as a guest for limited access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'guest'),
            child: const Text('Continue as Guest'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'signup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );

    if (result == 'signup') {
      Navigator.pushReplacementNamed(context, '/signup');
    } else if (result == 'guest') {
      setState(() {
        _isGuestMode = true;
        _showSignInPrompt = false;
      });
    }
  }

  Future<void> _send(String text) async {
    // Check if this is the first question and user is not authenticated
    if (!SupabaseService.isAuthenticated && !_hasAskedFirstQuestion) {
      // Allow first question in guest mode - will show prompt after response
      _hasAskedFirstQuestion = true;
    } else if (!SupabaseService.isAuthenticated && _hasAskedFirstQuestion && !_isGuestMode) {
      // After first question, show sign in prompt before allowing second question
      await _showSignInDialog();
      if (!_isGuestMode && !SupabaseService.isAuthenticated) {
        return; // User chose not to continue
      }
    }

    // Add user message to UI
    setState(() {
      _msgs.add({
        'id': DateTime.now().toIso8601String(),
        'from': 'user',
        'text': text,
      });
      _isLoading = true;
    });

    // Save user message to Supabase (only if authenticated)
    if (SupabaseService.isAuthenticated) {
      await _saveMessageToSupabase(
        role: 'user',
        content: text,
        sessionId: _currentSessionId,
      );

      // Update session timestamp
      if (_currentSessionId != null) {
        await ChatSessionsService.instance.updateSession(
          sessionId: _currentSessionId!,
        );
      }
    }

    try {
      // Call FastAPI endpoint
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
          // First pass: collect all article IDs
          final articleIds = <String>[];
          for (final result in results) {
            final articleId = result['id']?.toString();
            if (articleId != null) {
              articleIds.add(articleId);
            }
          }

          // Second pass: display and save each result
          for (final result in results) {
            // Extract fields from FastAPI response
            final articleId = result['id']?.toString();
            final articleLabel = result['article_label'] ?? 'Unknown Article';
            final articleText =
                result['article_text'] ?? 'No content available';
            final language = result['language'] ?? 'unknown';
            final score = result['similarity_score'] ?? 0.0;

            // Build formatted response
            final formattedResult =
                '''📋 $articleLabel (${language.toUpperCase()})
🎯 Relevance: ${(score * 100).toStringAsFixed(1)}%

$articleText''';

            // Add to UI
            setState(() {
              _msgs.add({
                'id': DateTime.now().toIso8601String(),
                'from': 'bot',
                'text': formattedResult.trim(),
              });
            });

            // Save each assistant message to Supabase (only if authenticated)
            if (SupabaseService.isAuthenticated) {
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

              // Update session timestamp
              if (_currentSessionId != null) {
                await ChatSessionsService.instance.updateSession(
                  sessionId: _currentSessionId!,
                );
              }
            }
          }
        } else {
          // No results found
          final noResultsMsg =
              'No relevant legal articles found for your query. Please try rephrasing your question.';

          setState(() {
            _msgs.add({
              'id': DateTime.now().toIso8601String(),
              'from': 'bot',
              'text': noResultsMsg,
            });
          });

          // Save to Supabase (only if authenticated)
          if (SupabaseService.isAuthenticated) {
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
        }
      } else {
        // Error response
        final errorMsg =
            '⚠️ ${response.statusCode}: ${response.reasonPhrase}\n${response.body}';

        setState(() {
          _msgs.add({
            'id': DateTime.now().toIso8601String(),
            'from': 'bot',
            'text': errorMsg,
          });
        });

        // Save error to Supabase (only if authenticated)
        if (SupabaseService.isAuthenticated) {
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
      }
    } catch (e) {
      // Connection error
      final errorMsg = '❌ Connection error: $e';

      setState(() {
        _msgs.add({
          'id': DateTime.now().toIso8601String(),
          'from': 'bot',
          'text': errorMsg,
        });
      });

      // Save error to Supabase (only if authenticated)
      if (SupabaseService.isAuthenticated) {
        await _saveMessageToSupabase(
          role: 'assistant',
          content: errorMsg,
          sessionId: _currentSessionId,
          metadata: {
            'error': true,
            'error_message': e.toString(),
          },
        );
      }
    } finally {
      setState(() => _isLoading = false);
      
      // After first question is answered, show sign in prompt if not authenticated
      if (!SupabaseService.isAuthenticated && _hasAskedFirstQuestion && !_isGuestMode && !_showSignInPrompt) {
        _showSignInPrompt = true;
        // Show dialog after a short delay to let user see the response
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showSignInDialog();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 🔹 Top Bar
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
                      if (Navigator.canPop(context))
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 48),
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
                      // Sign Up button in guest mode
                      if (_isGuestMode && !SupabaseService.isAuthenticated)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: _toggleOverlay,
                        tooltip: 'Menu',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 🔹 Guest mode banner
                if (_isGuestMode && _hasAskedFirstQuestion)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.25),
                          Colors.orange.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.orange[300],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guest Mode',
                                style: TextStyle(
                                  color: Colors.orange[100],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chat history won\'t be saved',
                                style: TextStyle(
                                  color: Colors.orange[200]?.withOpacity(0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 🔹 Welcome message (if no messages)
                if (_msgs.isEmpty && !_isLoading)
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
                                onTap: () => _send('What is a crime?'),
                              ),
                              _QuickQuestionChip(
                                text: 'Property rights',
                                onTap: () => _send('Property rights'),
                              ),
                              _QuickQuestionChip(
                                text: 'Business registration',
                                onTap: () => _send('Business registration'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // 🔹 Messages list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _msgs.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _msgs.length && _isLoading) {
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

                        final m = _msgs[i];
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

                // 🔹 Input Field
                ChatInput(onSend: _send),
              ],
            ),

            // 🔹 Overlay for new chat / history / language
            ChatOverlay(
              open: _overlayOpen,
              onClose: _toggleOverlay,
              selectedLanguage: _selectedLanguage,
              onLanguageSelected: (lang) {
                setState(() {
                  _selectedLanguage = lang;
                });
              },
              onNewChat: () {
                setState(() {
                  _msgs.clear();
                  _currentSessionId = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Quick question chip widget
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
