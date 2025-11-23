import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;

  /// Initialize Supabase with credentials
  /// 
  /// In production (APK): Loads from --dart-define flags
  /// In development: Loads from .env file
  /// 
  /// Automatically switches between dev and production based on availability
  static Future<void> initialize() async {
    // Try to load .env file (for development)
    // This will fail silently in production/APK builds where .env is not bundled
    try {
      await dotenv.load(fileName: '.env'); // Load .env file for development
    } catch (e) {
      // .env file not found - this is expected in production builds
      // We'll use --dart-define values instead
    }

    // Priority: --dart-define (production) > .env file (development)
    const ddUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const ddAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    String supabaseUrl = ddUrl;
    String supabaseAnonKey = ddAnon;
    String source = 'dart-define';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      // Fallback to .env
      await dotenv.load(fileName: '.env');
      supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
      source = '.env';
    }

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('Supabase credentials missing. Provide .env or pass --dart-define SUPABASE_URL/SUPABASE_ANON_KEY.');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _client = Supabase.instance.client;
    debugPrint('[supabase] Initialized via $source (url prefix: ${supabaseUrl.substring(0, 24)}...)');
  }

  /// Get the Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase has not been initialized. Call SupabaseService.initialize() first.');
    }
    return _client!;
  }

  /// Get service role key (for server-side operations only)
  /// WARNING: Never expose this in client-side code
  static String? get serviceRoleKey {
    final fromDefine = const String.fromEnvironment(
      'SUPABASE_SERVICE_ROLE_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
  }

  /// Get the current user
  static User? get currentUser => client.auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Sign out the current user
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}

