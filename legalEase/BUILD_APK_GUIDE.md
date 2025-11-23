# Quick Guide: Building APK with Supabase Credentials

## Problem Solved ✅

The APK was failing to authenticate because `.env` files are **not bundled** in APK builds. The app now automatically:
- Uses `.env` file in **development** (when running `flutter run`)
- Uses `--dart-define` flags in **production** (when building APK)

## Quick Start

### Step 1: Get Your Supabase Credentials

From your `.env` file, copy these values:
- `SUPABASE_URL` (e.g., `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY` (the long key starting with `eyJ...`)

### Step 2: Update Build Script

Edit `build_apk.ps1` and replace:
```powershell
$SUPABASE_URL = "YOUR_SUPABASE_URL_HERE"
$SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY_HERE"
```

With your actual values:
```powershell
$SUPABASE_URL = "https://your-project.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Step 3: Build the APK

Run the build script:
```powershell
.\build_apk.ps1
```

Or build manually:
```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="your-anon-key-here"
```

### Step 4: Install and Test

1. Find your APK: `build\app\outputs\flutter-apk\app-release.apk`
2. Install on your device: `adb install build\app\outputs\flutter-apk\app-release.apk`
3. Test sign in with your credentials

## Manual Build Command (Alternative)

If you prefer not to use the script:

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="YOUR_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_KEY"
```

**Important**: Replace `YOUR_URL` and `YOUR_KEY` with actual values from your `.env` file.

## Troubleshooting

### "Invalid login credentials" Error

1. **Verify credentials in build command**: Make sure the `--dart-define` values match your `.env` file exactly
2. **Check Supabase project**: Ensure your Supabase project is active
3. **Test in development first**: Run `flutter run` to verify credentials work with `.env`
4. **Check network**: Ensure device has internet connection

### "Supabase URL and Anon Key must be provided" Error

- You forgot to include `--dart-define` flags when building
- Check that flag values are not empty
- Verify no typos in flag names (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)

### Build Fails

- Run `flutter clean` then try again
- Ensure Flutter SDK is up to date: `flutter doctor`
- Check that you're in the project root directory

## What Changed

### Updated Files:
- ✅ `lib/services/supabase_service.dart` - Now supports both `.env` and `--dart-define`
- ✅ `build_apk.ps1` - Build script template (you need to add your credentials)

### How It Works:

1. **Development** (`flutter run`):
   - Loads `.env` file ✅
   - Uses credentials from `.env` ✅

2. **Production** (`flutter build apk`):
   - `.env` file not bundled in APK ❌
   - Uses `--dart-define` flags ✅
   - Credentials embedded in APK ✅

## Security Note

The Supabase **anon key** is safe to include in APK builds - it's designed to be public. However:
- ✅ Anon key in APK: **Safe** (public by design)
- ❌ Service role key: **Never** include in client builds

## Next Steps

1. Update `build_apk.ps1` with your credentials
2. Run `.\build_apk.ps1`
3. Install APK on device
4. Test sign in/sign up functionality

---

**Need help?** Check `SUPABASE_ENV_CONFIG.md` for detailed documentation.

