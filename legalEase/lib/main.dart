import 'package:flutter/material.dart';

import 'routes.dart';
import 'services/chat_service.dart';
import 'services/chat_sessions_service.dart';
import 'services/favorites_service.dart';
import 'services/learning_progress_service.dart';
import 'services/legal_topics_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Supabase: $e');
  }

  // Initialize ChatService (loads API_BASE_URL from .env if present)
  try {
    await ChatService.instance.initialize();
    debugPrint('✅ ChatService initialized with baseUrl=${ChatService.instance.baseUrl}');
  } catch (e) {
    debugPrint('❌ Error initializing ChatService: $e');
  }

  try {
    await LegalTopicsService.instance.initialize();
    debugPrint('✅ Legal topics initialized');
  } catch (e) {
    debugPrint('❌ Error initializing legal topics: $e');
  }

  try {
    await FavoritesService.instance.initialize();
    debugPrint('✅ Favorites service initialized');
  } catch (e) {
    debugPrint('❌ Error initializing favorites service: $e');
  }

  try {
    await ChatSessionsService.instance.initialize();
    debugPrint('✅ Chat sessions service initialized');
  } catch (e) {
    debugPrint('❌ Error initializing chat sessions service: $e');
  }

  try {
    await LearningProgressService.instance.initialize();
    debugPrint('✅ Learning progress service initialized');
  } catch (e) {
    debugPrint('❌ Error initializing learning progress service: $e');
  }

  runApp(const LegalEaseApp());
}

class LegalEaseApp extends StatelessWidget {
  const LegalEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LegalEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: Routes.splash,
      routes: Routes.routesMap,
    );
  }
}
