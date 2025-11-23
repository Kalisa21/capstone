# Chat Messages Integration with Supabase

This document explains how the chatbot is integrated with Supabase `chat_messages` table and the FastAPI endpoint.

## ✅ What's Been Implemented

### 1. **Supabase Integration**
- All chat messages are saved to `chat_messages` table
- User messages saved with role `'user'`
- Assistant messages saved with role `'assistant'`
- Article references stored in `article_references` JSONB field
- Metadata (processing time, scores, etc.) stored in `metadata` JSONB field

### 2. **FastAPI Endpoint Integration**
- Connected to FastAPI endpoint: `http://0.0.0.0:8000/search`
- Request format matches your curl example:
  ```json
  {
    "query": "murder voluntary killing",
    "top_k": 1,
    "language_filter": "en",
    "min_score": 0
  }
  ```

### 3. **Features Added**

#### Chat History Loading
- ✅ Automatically loads last 50 messages from Supabase on screen open
- ✅ Displays previous conversations
- ✅ Only loads messages for authenticated users

#### Message Saving
- ✅ User messages saved immediately when sent
- ✅ Assistant responses saved with full metadata
- ✅ Article references extracted and stored
- ✅ Processing time and similarity scores stored

#### Language Selection
- ✅ Language can be changed via chat overlay menu
- ✅ Supports: English (`en`), Kinyarwanda (`rw`), French (`fr`)
- ✅ Language filter sent to FastAPI endpoint
- ✅ Default language: English

#### Error Handling
- ✅ Connection errors saved to database
- ✅ API errors logged with status codes
- ✅ User-friendly error messages displayed

## 📋 Code Changes

### `lib/screens/chatbot_screen.dart`
- Added Supabase integration
- Added `_loadChatHistory()` method
- Added `_saveMessageToSupabase()` method
- Updated `_send()` to save messages and call FastAPI
- Added language selection state
- Added authentication check

### `lib/widgets/chat_overlay.dart`
- Added language selection buttons
- Added "New Chat" functionality
- Visual feedback for selected language
- Better UI with selectable language buttons

## 🔌 API Integration Details

### Request Format
```dart
POST http://0.0.0.0:8000/search
Headers:
  - accept: application/json
  - Content-Type: application/json

Body:
{
  "query": "user query text",
  "top_k": 1,
  "language_filter": "en", // or "rw" or "fr"
  "min_score": 0
}
```

### Response Handling
- Extracts `results` array from response
- Extracts `total_results` count
- Extracts `processing_time_ms`
- Extracts `id`, `article_label`, `article_text`, `language`, `similarity_score` from each result
- Formats and displays results to user
- Saves all metadata including article IDs to Supabase

## 💾 Database Schema Usage

### chat_messages Table Fields Used:
- `id` - Auto-generated UUID
- `user_id` - Links to authenticated user (from profiles)
- `role` - `'user'` or `'assistant'`
- `content` - Message text
- `session_id` - Currently nullable (can add chat_sessions table later)
- `article_references` - Array of article IDs (from FastAPI response `id` field)
- `metadata` - Contains:
  - `article_id` - Article ID from FastAPI (e.g., 320)
  - `article_label` - Article label (e.g., "Article 107: Voluntary murder...")
  - `language` - Language code (e.g., "en")
  - `similarity_score` - Relevance score (0.0-1.0)
  - `processing_time_ms` - API processing time
  - `total_results` - Total number of results returned
  - `error` (when errors occur)

## 🚀 Usage Flow

1. **User opens chatbot screen**
   - Loads last 50 messages from Supabase (if authenticated)

2. **User types and sends message**
   - Message saved to Supabase immediately
   - FastAPI endpoint called with query and language filter
   - Response received and displayed

3. **Assistant responses saved**
   - Each result saved as separate assistant message
   - Article references extracted and stored
   - Metadata saved with full details

4. **Language selection**
   - User taps menu icon
   - Selects language (En/Rw/Fr)
   - Next queries use selected language filter

## 🔒 Security

- ✅ Authentication required to use chatbot
- ✅ Users can only see their own messages (RLS policy)
- ✅ Messages linked to authenticated user
- ✅ Admins can read all messages (for support)

## 📝 Example Flow

```dart
// 1. User sends: "murder voluntary killing"
// 2. Saved to Supabase:
{
  "user_id": "user-uuid",
  "role": "user",
  "content": "murder voluntary killing",
  "session_id": null,
  "metadata": null,
  "article_references": null
}

// 3. FastAPI called with:
{
  "query": "murder voluntary killing",
  "top_k": 1,
  "language_filter": "en",
  "min_score": 0
}

// 4. Response saved to Supabase:
{
  "user_id": "user-uuid",
  "role": "assistant",
  "content": "📋 Article 107: Voluntary murder and its punishment (EN)\n🎯 Relevance: 75.3%\n\nA person who intentionally kills another person commits murder...",
  "session_id": null,
  "metadata": {
    "article_id": "320",
    "article_label": "Article 107: Voluntary murder and its punishment",
    "language": "en",
    "similarity_score": 0.7530796527862549,
    "processing_time_ms": 82.65,
    "total_results": 1
  },
  "article_references": ["320"]
}
```

## ⚙️ Configuration

### API Base URL
Currently set to `http://0.0.0.0:8000` (default).
To change, use environment variable:
```bash
flutter run --dart-define=API_BASE=http://your-api-url:8000
```

For Android emulator, use:
```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
```

## 🐛 Troubleshooting

### Messages not saving?
- Check user is authenticated (`SupabaseService.isAuthenticated`)
- Check RLS policies are correctly set
- Check network connection to Supabase

### FastAPI not responding?
- Check API server is running on `http://0.0.0.0:8000`
- For Android emulator, use `http://10.0.2.2:8000`
- Check API endpoint `/search` is accessible

### Language filter not working?
- Verify selected language is valid (`en`, `rw`, or `fr`)
- Check FastAPI accepts `language_filter` parameter
- Defaults to `en` if not set

---

**Integration Status**: ✅ Complete and Ready to Use

