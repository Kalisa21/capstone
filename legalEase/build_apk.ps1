# Build APK Script for LegalEase App
# This script builds a release APK with Supabase credentials from --dart-define flags

# IMPORTANT: Replace these values with your actual Supabase credentials
# You can find these in your .env file or Supabase dashboard
$SUPABASE_URL = "YOUR_SUPABASE_URL_HERE"
$SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY_HERE"

# Optional: Uncomment and set if you need API_BASE_URL for production
# $API_BASE_URL = "YOUR_API_BASE_URL_HERE"

Write-Host "Building release APK..." -ForegroundColor Green
Write-Host "Using Supabase URL: $SUPABASE_URL" -ForegroundColor Yellow

# Build the APK with --dart-define flags
if ($API_BASE_URL) {
    flutter build apk --release `
        --dart-define=SUPABASE_URL="$SUPABASE_URL" `
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" `
        --dart-define=API_BASE="$API_BASE_URL"
} else {
    flutter build apk --release `
        --dart-define=SUPABASE_URL="$SUPABASE_URL" `
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ APK built successfully!" -ForegroundColor Green
    Write-Host "APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
} else {
    Write-Host "`n❌ Build failed. Check the error messages above." -ForegroundColor Red
    exit 1
}

