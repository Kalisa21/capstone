# Database Migration Guide

## 🚀 Complete Setup (One File)

### Quick Start

1. **Go to Supabase Dashboard**
   - URL: https://supabase.com/dashboard/project/azrieunnxzzvemkiistu
   - Or: https://supabase.com/dashboard → Select your project

2. **Open SQL Editor**
   - Click **SQL Editor** in the left sidebar
   - Click **New Query** button

3. **Run Complete Setup**
   - Open file: `001_complete_setup.sql`
   - Copy **ALL** content (Ctrl/Cmd + A, then Ctrl/Cmd + C)
   - Paste into SQL Editor
   - Click **Run** (or press Ctrl/Cmd + Enter)
   - Wait for success message ✅

4. **Verify Setup**
   Run this in SQL Editor to verify:
   ```sql
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   ORDER BY table_name;
   ```
   
   Should show:
   - ✅ profiles
   - ✅ legal_topics
   - ✅ chat_messages
   - ✅ user_analytics
   - ✅ user_favorites
   - ✅ user_topic_interests

5. **Test Your App**
   - Go back to Flutter app
   - Try signing up - it should work now! ✅

---

## 📋 What Gets Created

### Tables (6)
1. **profiles** - User extended profiles
2. **legal_topics** - Legal topic categories
3. **chat_messages** - Chat messages between users and AI
4. **user_analytics** - Daily learning analytics
5. **user_favorites** - User bookmarks/favorites
6. **user_topic_interests** - Topic interest tracking

### Features
- ✅ Auto-create profile when user signs up (trigger)
- ✅ Row Level Security (RLS) on all tables
- ✅ Proper indexes for performance
- ✅ Seed data (5 initial legal topics)
- ✅ All foreign keys and constraints
- ✅ Safe to run multiple times (idempotent)

---

## 🔍 Verify Everything Works

### Check Tables Exist
```sql
SELECT COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'profiles', 
    'legal_topics', 
    'chat_messages', 
    'user_analytics', 
    'user_favorites', 
    'user_topic_interests'
  );
```
Should return: `6`

### Check Trigger Exists
```sql
SELECT trigger_name 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```
Should return: `on_auth_user_created`

### Check Seed Data
```sql
SELECT name, slug FROM legal_topics;
```
Should show 5 topics.

---

## 🐛 Troubleshooting

### Error: "relation already exists"
- This is fine! The migration is idempotent
- It will skip existing tables/triggers
- Just continue - it's working correctly

### Error: "permission denied"
- Make sure you're using the SQL Editor in Supabase Dashboard
- Check you have admin access to the project

### Tables created but sign up still fails
- Check if trigger exists (see above)
- Verify RLS policies are enabled
- Check if profiles table has the correct structure

---

## 📁 Migration Files

- **`001_complete_setup.sql`** - Complete setup (use this one!)

---

## ✅ After Running Migration

1. ✅ Tables created
2. ✅ Trigger set up (auto-creates profiles)
3. ✅ RLS policies enabled
4. ✅ Seed data inserted
5. ✅ Ready to use!

**Now try signing up in your app!** 🎉
