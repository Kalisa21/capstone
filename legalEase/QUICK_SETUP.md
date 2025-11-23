# 🚀 Quick Setup Guide - Fix Database Error

## ❌ Current Error
```
Database error. Please make sure the database tables are created.
```

This means the database tables haven't been created in Supabase yet.

## ✅ Quick Fix (5 minutes)

### Step 1: Open Supabase Dashboard
1. Go to: **https://supabase.com/dashboard**
2. Select your project (the one with URL: `https://azrieunnxzzvemkiistu.supabase.co`)

### Step 2: Run First Migration
1. Click **SQL Editor** in the left sidebar
2. Click **New Query** button
3. Open this file: `supabase/migrations/001_create_tables.sql`
4. Copy **ALL** the content (Ctrl/Cmd + A, then Ctrl/Cmd + C)
5. Paste into the SQL Editor
6. Click **Run** (or press `Ctrl/Cmd + Enter`)
7. Wait for "Success" message ✅

### Step 3: Run Second Migration
1. Click **New Query** again (create a new query)
2. Open this file: `supabase/migrations/002_create_profile_trigger.sql`
3. Copy **ALL** the content
4. Paste into SQL Editor
5. Click **Run**
6. Wait for "Success" message ✅

### Step 4: Verify Tables Exist
Run this in SQL Editor to verify:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'profiles';
```

You should see `profiles` in the results.

### Step 5: Test Sign Up Again
Go back to your Flutter app and try signing up again!

---

## 📁 Migration Files Location

- **Main tables**: `supabase/migrations/001_create_tables.sql`
- **Profile trigger**: `supabase/migrations/002_create_profile_trigger.sql`

## 🆘 Still Getting Errors?

### Check if tables exist:
```sql
-- In Supabase SQL Editor, run:
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';
```

Should show:
- ✅ profiles
- ✅ legal_topics
- ✅ chat_messages
- ✅ user_analytics
- ✅ user_favorites
- ✅ user_topic_interests

### Check if trigger exists:
```sql
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

Should show: `on_auth_user_created`

### If tables don't exist:
- Make sure you ran the SQL in Supabase SQL Editor (not locally)
- Check for any error messages when running the SQL
- Try running each migration one at a time

---

**Once tables are created, sign up will work!** ✅


