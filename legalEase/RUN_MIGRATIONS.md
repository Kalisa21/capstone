# 🚀 Run Database Migrations - Quick Guide

## ⚠️ Current Error
"Database tables not created" - This means you need to run the SQL migrations in Supabase.

## ✅ Step-by-Step Fix (5 minutes)

### 1. Open Supabase Dashboard
👉 Go to: https://supabase.com/dashboard/project/azrieunnxzzvemkiistu

### 2. Open SQL Editor
Click **SQL Editor** in the left sidebar

### 3. Run First Migration
1. Click **New Query** button (top right)
2. Open file: `supabase/migrations/001_create_tables.sql`
3. Copy **EVERYTHING** from that file (Ctrl/Cmd + A, then Ctrl/Cmd + C)
4. Paste into SQL Editor
5. Click **Run** button (or Ctrl/Cmd + Enter)
6. Wait for ✅ "Success" message

### 4. Run Second Migration  
1. Click **New Query** again (create new query)
2. Open file: `supabase/migrations/002_create_profile_trigger.sql`
3. Copy **EVERYTHING** from that file
4. Paste into SQL Editor
5. Click **Run** button
6. Wait for ✅ "Success" message

### 5. Verify Tables Created
Run this query in SQL Editor:

```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('profiles', 'legal_topics', 'chat_messages');
```

**Should show:**
- ✅ profiles
- ✅ legal_topics  
- ✅ chat_messages

### 6. Test Sign Up
Go back to your Flutter app and try signing up again!

---

## 🐛 Troubleshooting

### If you see errors when running SQL:
- Make sure you're running it in **Supabase SQL Editor** (not locally)
- Check for any error messages in red
- Try running each migration separately

### If tables still don't exist:
- Check if you have permission to create tables
- Make sure you're in the correct Supabase project
- Try running the SQL statements one section at a time

---

**After migrations run successfully, sign up will work!** ✅
