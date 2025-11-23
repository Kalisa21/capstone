# Database Schema Recommendation for LegalEase App

Based on your app's features, I recommend **8-10 core tables** plus some optional tables for future expansion.

## 📊 Recommended Tables

### **Core Tables (8 Essential)**

#### 1. **profiles** (User Extended Info)
```sql
- id (uuid, primary key, references auth.users)
- user_id (uuid, unique, foreign key to auth.users)
- name (text)
- about (text) -- 'User' or 'Legal Practitioner'
- avatar_url (text, nullable)
- role (text) -- 'user', 'admin', 'practitioner'
- created_at (timestamp)
- updated_at (timestamp)
```

**Purpose**: Extends Supabase auth.users with additional profile data

---

#### 2. **legal_topics** (Categories/Topics)
```sql
- id (uuid, primary key)
- name (text, unique) -- 'criminal', 'civil', 'business', etc.
- slug (text, unique)
- description (text, nullable)
- icon_url (text, nullable)
- color_hex (text, nullable)
- order_index (integer)
- is_active (boolean, default true)
- created_at (timestamp)
```

**Purpose**: Stores legal topic categories (criminal law, civil law, business law, etc.)

---

#### 3. **legal_articles** (Legal Content)
```sql
- id (uuid, primary key)
- article_label (text) -- Article identifier/number
- title (text)
- content (text)
- summary (text, nullable)
- topic_id (uuid, foreign key to legal_topics)
- language (text) -- 'en', 'rw', 'fr'
- source_url (text, nullable)
- metadata (jsonb, nullable) -- Additional structured data
- embedding_vector (vector, nullable) -- For vector search (if using pgvector)
- is_active (boolean, default true)
- created_at (timestamp)
- updated_at (timestamp)
```

**Purpose**: Stores legal articles/content that can be searched and retrieved

---

#### 4. **chat_sessions** (Chat Conversations)
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles)
- title (text, nullable) -- Auto-generated or user-set
- language (text, default 'en') -- 'en', 'rw', 'fr'
- created_at (timestamp)
- updated_at (timestamp)
```

**Purpose**: Groups chat messages into conversations/sessions

---

#### 5. **chat_messages** (Individual Messages)
```sql
- id (uuid, primary key)
- session_id (uuid, foreign key to chat_sessions)
- user_id (uuid, foreign key to profiles)
- role (text) -- 'user' or 'assistant'
- content (text)
- article_references (jsonb, nullable) -- Array of article IDs referenced
- metadata (jsonb, nullable) -- Processing time, scores, etc.
- created_at (timestamp)
```

**Purpose**: Stores individual chat messages between user and AI

---

#### 6. **user_analytics** (Learning Progress)
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles)
- date (date)
- time_spent_minutes (integer, default 0)
- articles_viewed (integer, default 0)
- queries_made (integer, default 0)
- knowledge_score (decimal, nullable) -- Percentage 0-100
- topics_studied (jsonb, nullable) -- Array of topic IDs
- created_at (timestamp)
- updated_at (timestamp)
```

**Purpose**: Tracks user learning progress, time spent, knowledge score

---

#### 7. **user_favorites** (Bookmarks/Favorites)
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles)
- article_id (uuid, foreign key to legal_articles, nullable)
- topic_id (uuid, foreign key to legal_topics, nullable)
- notes (text, nullable)
- created_at (timestamp)
```

**Purpose**: Allows users to favorite/bookmark articles or topics

---

#### 8. **query_logs** (Admin Analytics)
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles, nullable)
- query_text (text)
- results_count (integer)
- processing_time_ms (decimal)
- accuracy_score (decimal, nullable)
- results_articles (jsonb, nullable) -- Array of article IDs returned
- error_message (text, nullable)
- created_at (timestamp)
```

**Purpose**: Logs all queries for admin analytics (query volume, accuracy, response time)

---

### **Optional Tables (2-3 for Enhanced Features)**

#### 9. **user_learning_history** (Detailed Activity)
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles)
- activity_type (text) -- 'view_article', 'search_query', 'favorite', etc.
- article_id (uuid, foreign key to legal_articles, nullable)
- topic_id (uuid, foreign key to legal_topics, nullable)
- metadata (jsonb, nullable)
- created_at (timestamp)
```

**Purpose**: Detailed activity tracking for learning analytics

---

#### 10. **admin_metrics** (Pre-calculated Stats)
```sql
- id (uuid, primary key)
- metric_type (text) -- 'daily_users', 'query_volume', 'accuracy_rate', etc.
- metric_date (date)
- metric_value (decimal)
- metadata (jsonb, nullable)
- created_at (timestamp)
- updated_at (timestamp)
```

**Purpose**: Pre-calculated metrics for faster dashboard loading

---

## 📋 Summary

### **Minimum Essential: 8 Tables**
1. profiles
2. legal_topics
3. legal_articles
4. chat_sessions
5. chat_messages
6. user_analytics
7. user_favorites
8. query_logs

### **Recommended for Full Features: 10 Tables**
Add the 2 optional tables above

---

## 🔐 Row Level Security (RLS) Recommendations

### **profiles**
- Users can READ/WRITE their own profile
- Admins can READ all profiles

### **legal_topics** / **legal_articles**
- Everyone can READ (public)
- Only admins can WRITE

### **chat_sessions** / **chat_messages**
- Users can READ/WRITE their own chats only
- Admins can READ all (for support)

### **user_analytics** / **user_favorites**
- Users can READ/WRITE their own data only
- Admins can READ all (for analytics)

### **query_logs**
- Users can READ their own queries
- Admins can READ all

---

## 🚀 Quick Start SQL

I can generate the complete SQL migration file with:
- All table definitions
- Foreign key constraints
- Indexes for performance
- RLS policies
- Seed data (initial topics)

Would you like me to create the SQL migration file?

---

## 📊 Estimated Storage

- **Small deployment**: ~50MB (up to 10,000 users, 1,000 articles)
- **Medium deployment**: ~500MB (up to 100,000 users, 10,000 articles)
- **Large deployment**: ~5GB+ (up to 1M users, 100,000+ articles)

---

**Recommended: Start with 8 core tables, add optional ones as needed!** ✅

