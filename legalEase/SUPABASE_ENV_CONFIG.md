# Supabase Environment Configuration

This document explains how Supabase credentials are loaded for both development and production (APK) builds.

## Overview

The `SupabaseService` automatically switches between development and production modes:

- **Development**: Loads credentials from `.env` file
- **Production (APK)**: Loads credentials from `--dart-define` flags

No manual switching required - it detects the environment automatically!

## Implementation

### Service Code (`lib/services/supabase_service.dart`)

```dart
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
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file not found - this is expected in production builds
      // We'll use --dart-define values instead
    }

    // Priority: --dart-define (production) > .env file (development)
    final supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ).isEmpty
        ? (dotenv.env['SUPABASE_URL']?.trim() ?? '')
        : const String.fromEnvironment('SUPABASE_URL');

    final supabaseAnonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ).isEmpty
        ? (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '')
        : const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'Supabase URL and Anon Key must be provided.\n'
        'For development: Add them to .env file\n'
        'For production: Pass via --dart-define flags:\n'
        '  --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _client = Supabase.instance.client;
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
```

### Usage in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (automatically uses .env in dev, --dart-define in production)
  try {
    await SupabaseService.initialize();
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Supabase: $e');
  }

  runApp(const MyApp());
}
```

## Setup Instructions

### Development Setup

1. Create a `.env` file in the project root:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

2. Make sure `.env` is in `pubspec.yaml` assets:
```yaml
flutter:
  assets:
    - .env
```

3. Run the app normally:
```bash
flutter run
```

### Production APK Build

When building an APK, `.env` files are not bundled. Use `--dart-define` flags instead:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

Or for a split APK (smaller file size):
```bash
flutter build apk --split-per-abi --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

### Windows PowerShell (Escape Quotes)

For Windows PowerShell, escape the quotes:
```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="your-anon-key-here"
```

### Using a Build Script

Create a `build_apk.ps1` (Windows) or `build_apk.sh` (Linux/Mac) script:

**Windows (`build_apk.ps1`):**
```powershell
$supabaseUrl = "https://your-project.supabase.co"
$supabaseKey = "your-anon-key-here"

flutter build apk --release `
  --dart-define=SUPABASE_URL="$supabaseUrl" `
  --dart-define=SUPABASE_ANON_KEY="$supabaseKey"
```

**Linux/Mac (`build_apk.sh`):**
```bash
#!/bin/bash
SUPABASE_URL="https://your-project.supabase.co"
SUPABASE_ANON_KEY="your-anon-key-here"

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

## How It Works

1. **Development Mode**:
   - `dotenv.load()` successfully loads `.env` file
   - `String.fromEnvironment()` returns empty string (no --dart-define flags)
   - Falls back to `dotenv.env['SUPABASE_URL']` and `dotenv.env['SUPABASE_ANON_KEY']`

2. **Production Mode (APK)**:
   - `dotenv.load()` fails silently (`.env` not bundled in APK)
   - `String.fromEnvironment()` returns values from `--dart-define` flags
   - Uses those values directly

## Null Safety

All values are properly null-safe:
- `String.fromEnvironment()` with `defaultValue: ''` ensures non-null strings
- `dotenv.env['KEY']?.trim() ?? ''` handles null/empty cases
- Empty string checks before initialization prevent runtime errors

## Testing

### Test Development Mode
```bash
# Make sure .env file exists with correct credentials
flutter run
```

### Test Production Mode Locally
```bash
# Build with --dart-define flags (simulates APK behavior)
flutter run --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

## Troubleshooting

### Error: "Supabase URL and Anon Key must be provided"

**In Development:**
- Check that `.env` file exists in project root
- Verify `.env` is listed in `pubspec.yaml` assets
- Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set in `.env`

**In Production (APK):**
- Make sure you're passing `--dart-define` flags when building
- Check that flag values are not empty
- Verify flags are passed correctly (no typos)

### Sign In/Sign Up Fails in APK

- Verify credentials are correct in `--dart-define` flags
- Check that Supabase project is active and accessible
- Ensure network permissions are set in `AndroidManifest.xml`
- Test with `flutter run --release` with `--dart-define` flags first

## Security Notes

- ✅ **Anon Key**: Safe to include in APK (it's public by design)
- ✅ **Service Role Key**: Never include in client builds (server-side only)
- ✅ **.env File**: Already in `.gitignore` (not committed to git)
- ⚠️ **--dart-define Flags**: Visible in compiled APK, but anon key is safe to expose

