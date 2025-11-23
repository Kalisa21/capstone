# ✅ Fix: "Trigger already exists" Error

## ❌ Error You Saw
```
ERROR: 42710: trigger "on_auth_user_created" for relation "users" already exists
```

## ✅ Solution

The trigger already exists! This means it was created before. You have two options:

### Option 1: Run the Fixed Migration (Recommended)
1. Open Supabase SQL Editor
2. Copy and paste the content from: `002_create_profile_trigger_FIXED.sql`
3. Click **Run**

This will drop the old trigger and recreate it (safe to run).

### Option 2: Just Drop and Recreate Manually
Run this in SQL Editor:

```sql
-- Drop existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Recreate it
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### Option 3: Verify It's Working
The trigger might already be working! Check if it exists:

```sql
SELECT trigger_name 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

If you see `on_auth_user_created`, the trigger is already set up ✅

## 🧪 Test It

Try signing up a new user in your app. If a profile is automatically created, the trigger is working!

---

**The updated migration file (`002_create_profile_trigger.sql`) is now fixed and safe to run multiple times.**
