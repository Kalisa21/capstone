# Fix Authentication Error - "Database error saving new user"

## ❌ Error You're Seeing
```
Sign up failed: AuthRetryableFetchException
Database error saving new user
statusCode: 500
```

## 🔍 Root Cause
The error occurs because:
1. User is created in `auth.users` ✅
2. But profile creation fails in `profiles` table ❌
   - Table might not exist yet
   - Or trigger isn't set up to auto-create profiles

## ✅ Solution: Run Database Migrations

### Step 1: Run the Main Migration
1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **SQL Editor**
4. Create a **New Query**
5. Copy and paste the **entire content** of `001_create_tables.sql`
6. Click **Run** (or press Ctrl/Cmd + Enter)

This creates:
- ✅ `profiles` table
- ✅ `legal_topics` table  
- ✅ `chat_messages` table
- ✅ `user_analytics` table
- ✅ `user_favorites` table
- ✅ `user_topic_interests` table
- ✅ RLS policies

### Step 2: Run the Profile Trigger Migration
1. In the same SQL Editor
2. Create a **New Query**
3. Copy and paste the **entire content** of `002_create_profile_trigger.sql`
4. Click **Run**

This creates:
- ✅ Trigger to auto-create profile when user signs up
- ✅ Function to handle new user creation

## 🔍 Verify Migration Success

Run this query in SQL Editor to verify:

```sql
-- Check if profiles table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'profiles';

-- Check if trigger exists
SELECT trigger_name 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Check if function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';
```

You should see:
- ✅ `profiles` in table list
- ✅ `on_auth_user_created` in trigger list
- ✅ `handle_new_user` in routine list

## 🧪 Test Sign Up Again

After running migrations:
1. Go back to your Flutter app
2. Try signing up again
3. Profile should be created automatically ✅

## 🐛 If Still Not Working

### Check RLS Policies
Make sure users can insert into profiles. Run this:

```sql
-- Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'profiles';
```

Should show `rowsecurity = true`

### Check Policies
```sql
-- View all policies on profiles
SELECT * FROM pg_policies 
WHERE tablename = 'profiles';
```

You should see policies allowing:
- Users to INSERT their own profile
- Users to SELECT their own profile

### Manual Profile Test
Try manually creating a profile to test:

```sql
-- Get your user ID (after signing up)
SELECT id, email FROM auth.users LIMIT 1;

-- Then try to insert (replace USER_ID_HERE with actual ID)
INSERT INTO profiles (user_id, name, about, role)
VALUES ('USER_ID_HERE', 'Test User', 'User', 'user');
```

If this fails, check:
1. Table exists
2. RLS policies are correct
3. User has proper permissions

## ✅ Expected Result

After migrations:
- ✅ User signs up successfully
- ✅ Profile created automatically via trigger
- ✅ User can sign in
- ✅ Profile shows in profile screen

---

**Migration Files Location:**
- `supabase/migrations/001_create_tables.sql`
- `supabase/migrations/002_create_profile_trigger.sql`


