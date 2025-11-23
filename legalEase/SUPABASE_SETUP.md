# Supabase Integration Setup

This document explains how Supabase has been integrated into the LegalEase app.

## ✅ Completed Setup

### 1. **Packages Added**
- `supabase_flutter: ^2.0.0` - Supabase client for Flutter
- `flutter_dotenv: ^5.1.0` - Environment variable management

### 2. **Environment Variables**
Credentials are stored in `.env` file (not committed to git):
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Public anon key (safe for client-side)
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (server-side only, stored but not used in client)

### 3. **Files Created/Modified**

#### New Files:
- `.env` - Contains your Supabase credentials (gitignored)
- `.env.example` - Template file for environment variables
- `lib/services/supabase_service.dart` - Supabase service wrapper

#### Modified Files:
- `pubspec.yaml` - Added Supabase packages and .env asset
- `.gitignore` - Added .env to ignore list
- `lib/main.dart` - Initializes Supabase on app start
- `lib/screens/sign_in_screen.dart` - Integrated Supabase authentication
- `lib/screens/sign_up_screen.dart` - Integrated Supabase registration
- `lib/screens/profile_screen.dart` - Shows authenticated user info

### 4. **Features Implemented**

#### Authentication:
- ✅ User sign up with email/password
- ✅ User sign in with email/password
- ✅ User sign out
- ✅ Session persistence
- ✅ User profile display from Supabase auth

#### Service:
- ✅ Supabase client initialization
- ✅ Secure credential storage
- ✅ Helper methods for auth state

## 📋 Usage Examples

### Sign In
```dart
await SupabaseService.client.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'password123',
);
```

### Sign Up
```dart
await SupabaseService.client.auth.signUp(
  email: 'user@example.com',
  password: 'password123',
  data: {
    'name': 'John Doe',
    'about': 'Legal Practitioner',
  },
);
```

### Get Current User
```dart
final user = SupabaseService.currentUser;
final isAuthenticated = SupabaseService.isAuthenticated;
```

### Sign Out
```dart
await SupabaseService.signOut();
```

### Access Supabase Client
```dart
final client = SupabaseService.client;
// Use client for database queries, storage, etc.
```

## 🔒 Security Notes

1. **Anon Key**: Used in client-side code (safe to expose)
2. **Service Role Key**: Should NEVER be used in client-side code. Only for server-side operations.
3. **.env File**: Already added to `.gitignore` to prevent committing credentials

## 🚀 Next Steps

### Database Operations
You can now use Supabase for:
- Storing user profiles in `profiles` table
- Saving chat history
- Storing legal articles/knowledge base
- User analytics

Example:
```dart
// Insert data
await SupabaseService.client
  .from('profiles')
  .insert({'user_id': user.id, 'name': 'John'});

// Query data
final response = await SupabaseService.client
  .from('legal_articles')
  .select()
  .eq('category', 'criminal');
```

### Real-time Subscriptions
```dart
SupabaseService.client
  .from('legal_articles')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Handle real-time updates
  });
```

### Storage
```dart
await SupabaseService.client
  .storage
  .from('documents')
  .upload('file.pdf', fileBytes);
```

## ⚠️ Important

1. **Never commit `.env` file** - It's already in `.gitignore`
2. **Service Role Key** - Only use server-side, never expose in client
3. **Row Level Security (RLS)** - Configure in Supabase dashboard for data security

## 📝 Testing

After running `flutter pub get`, test the authentication:
1. Run the app
2. Try signing up with a new account
3. Sign in with the created account
4. Check profile screen for user info

---

**Setup completed successfully!** ✅

