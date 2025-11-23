-- ============================================================
-- LegalEase App - Complete Database Setup
-- ============================================================
-- Run this ENTIRE file in Supabase SQL Editor
-- This creates all tables, triggers, policies, and seed data
-- Safe to run multiple times (idempotent)
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- HELPER FUNCTION: Update updated_at timestamp
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  about TEXT, -- 'User' or 'Legal Practitioner'
  avatar_url TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'practitioner')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for profiles
DROP INDEX IF EXISTS idx_profiles_user_id;
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
DROP INDEX IF EXISTS idx_profiles_role;
CREATE INDEX idx_profiles_role ON profiles(role);

-- Trigger for profiles updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 2. LEGAL_TOPICS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS legal_topics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL, -- 'criminal', 'civil', 'business', etc.
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  icon_url TEXT,
  image_base64 TEXT,
  color_hex TEXT,
  order_index INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for legal_topics
DROP INDEX IF EXISTS idx_legal_topics_slug;
CREATE INDEX idx_legal_topics_slug ON legal_topics(slug);
DROP INDEX IF EXISTS idx_legal_topics_is_active;
CREATE INDEX idx_legal_topics_is_active ON legal_topics(is_active);
DROP INDEX IF EXISTS idx_legal_topics_order;
CREATE INDEX idx_legal_topics_order ON legal_topics(order_index);

-- ============================================================
-- 3. CHAT_MESSAGES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID, -- Foreign key to chat_sessions (nullable for now)
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  article_references JSONB, -- Array of article IDs referenced
  metadata JSONB, -- Processing time, scores, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for chat_messages
DROP INDEX IF EXISTS idx_chat_messages_user_id;
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
DROP INDEX IF EXISTS idx_chat_messages_session_id;
CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);
DROP INDEX IF EXISTS idx_chat_messages_created_at;
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
DROP INDEX IF EXISTS idx_chat_messages_role;
CREATE INDEX idx_chat_messages_role ON chat_messages(role);

-- ============================================================
-- 4. USER_ANALYTICS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  time_spent_minutes INTEGER DEFAULT 0,
  articles_viewed INTEGER DEFAULT 0,
  queries_made INTEGER DEFAULT 0,
  knowledge_score DECIMAL(5,2), -- Percentage 0-100
  topics_studied JSONB, -- Array of topic IDs
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, date) -- One record per user per day
);

-- Indexes for user_analytics
DROP INDEX IF EXISTS idx_user_analytics_user_id;
CREATE INDEX idx_user_analytics_user_id ON user_analytics(user_id);
DROP INDEX IF EXISTS idx_user_analytics_date;
CREATE INDEX idx_user_analytics_date ON user_analytics(date DESC);
DROP INDEX IF EXISTS idx_user_analytics_user_date;
CREATE INDEX idx_user_analytics_user_date ON user_analytics(user_id, date DESC);

-- Trigger for user_analytics updated_at
DROP TRIGGER IF EXISTS update_user_analytics_updated_at ON user_analytics;
CREATE TRIGGER update_user_analytics_updated_at
  BEFORE UPDATE ON user_analytics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 5. USER_FAVORITES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  article_id UUID, -- Foreign key to legal_articles (nullable)
  topic_id UUID REFERENCES legal_topics(id) ON DELETE CASCADE, -- Foreign key to legal_topics (nullable)
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (
    -- Ensure at least one of article_id or topic_id is set
    (article_id IS NOT NULL AND topic_id IS NULL) OR
    (article_id IS NULL AND topic_id IS NOT NULL)
  )
);

-- Indexes for user_favorites
DROP INDEX IF EXISTS idx_user_favorites_user_id;
CREATE INDEX idx_user_favorites_user_id ON user_favorites(user_id);
DROP INDEX IF EXISTS idx_user_favorites_article_id;
CREATE INDEX idx_user_favorites_article_id ON user_favorites(article_id);
DROP INDEX IF EXISTS idx_user_favorites_topic_id;
CREATE INDEX idx_user_favorites_topic_id ON user_favorites(topic_id);
DROP INDEX IF EXISTS idx_user_favorites_created_at;
CREATE INDEX idx_user_favorites_created_at ON user_favorites(created_at DESC);

-- Prevent duplicate favorites (unique constraints)
DROP INDEX IF EXISTS idx_user_favorites_unique_article;
CREATE UNIQUE INDEX idx_user_favorites_unique_article 
  ON user_favorites(user_id, article_id) 
  WHERE article_id IS NOT NULL;

DROP INDEX IF EXISTS idx_user_favorites_unique_topic;
CREATE UNIQUE INDEX idx_user_favorites_unique_topic 
  ON user_favorites(user_id, topic_id) 
  WHERE topic_id IS NOT NULL;

-- ============================================================
-- 6. USER_TOPIC_INTERESTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_topic_interests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES legal_topics(id) ON DELETE CASCADE,
  interest_score DECIMAL(5,2) DEFAULT 0.0, -- 0-100, calculated from query frequency
  query_count INTEGER DEFAULT 0, -- Number of queries related to this topic
  last_queried_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, topic_id) -- One record per user per topic
);

-- Indexes for user_topic_interests
DROP INDEX IF EXISTS idx_user_topic_interests_user_id;
CREATE INDEX idx_user_topic_interests_user_id ON user_topic_interests(user_id);
DROP INDEX IF EXISTS idx_user_topic_interests_topic_id;
CREATE INDEX idx_user_topic_interests_topic_id ON user_topic_interests(topic_id);
DROP INDEX IF EXISTS idx_user_topic_interests_interest_score;
CREATE INDEX idx_user_topic_interests_interest_score ON user_topic_interests(interest_score DESC);
DROP INDEX IF EXISTS idx_user_topic_interests_last_queried;
CREATE INDEX idx_user_topic_interests_last_queried ON user_topic_interests(last_queried_at DESC);

-- Trigger for user_topic_interests updated_at
DROP TRIGGER IF EXISTS update_user_topic_interests_updated_at ON user_topic_interests;
CREATE TRIGGER update_user_topic_interests_updated_at
  BEFORE UPDATE ON user_topic_interests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- AUTO-CREATE PROFILE TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, name, about, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'about', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (user_id) DO NOTHING; -- Prevent errors if profile already exists
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- AUTO-CREATE PROFILE TRIGGER
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY (RLS) - ENABLE ON ALL TABLES
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_topic_interests ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES: PROFILES
-- ============================================================
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;

-- Users can read their own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can read all profiles
CREATE POLICY "Admins can read all profiles" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- RLS POLICIES: LEGAL_TOPICS
-- ============================================================
DROP POLICY IF EXISTS "Anyone can read active topics" ON legal_topics;
DROP POLICY IF EXISTS "Admins can insert topics" ON legal_topics;
DROP POLICY IF EXISTS "Admins can update topics" ON legal_topics;
DROP POLICY IF EXISTS "Admins can delete topics" ON legal_topics;

-- Everyone can read active topics (public)
CREATE POLICY "Anyone can read active topics" ON legal_topics
  FOR SELECT USING (is_active = TRUE);

-- Only admins can insert topics
CREATE POLICY "Admins can insert topics" ON legal_topics
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Only admins can update topics
CREATE POLICY "Admins can update topics" ON legal_topics
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Only admins can delete topics
CREATE POLICY "Admins can delete topics" ON legal_topics
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- RLS POLICIES: CHAT_MESSAGES
-- ============================================================
DROP POLICY IF EXISTS "Users can read own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete own messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can read all messages" ON chat_messages;

-- Users can read their own messages
CREATE POLICY "Users can read own messages" ON chat_messages
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own messages
CREATE POLICY "Users can insert own messages" ON chat_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own messages
CREATE POLICY "Users can delete own messages" ON chat_messages
  FOR DELETE USING (auth.uid() = user_id);

-- Admins can read all messages
CREATE POLICY "Admins can read all messages" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- RLS POLICIES: USER_ANALYTICS
-- ============================================================
DROP POLICY IF EXISTS "Users can read own analytics" ON user_analytics;
DROP POLICY IF EXISTS "Users can insert own analytics" ON user_analytics;
DROP POLICY IF EXISTS "Users can update own analytics" ON user_analytics;
DROP POLICY IF EXISTS "Admins can read all analytics" ON user_analytics;

-- Users can read their own analytics
CREATE POLICY "Users can read own analytics" ON user_analytics
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own analytics
CREATE POLICY "Users can insert own analytics" ON user_analytics
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own analytics
CREATE POLICY "Users can update own analytics" ON user_analytics
  FOR UPDATE USING (auth.uid() = user_id);

-- Admins can read all analytics
CREATE POLICY "Admins can read all analytics" ON user_analytics
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- RLS POLICIES: USER_FAVORITES
-- ============================================================
DROP POLICY IF EXISTS "Users can read own favorites" ON user_favorites;
DROP POLICY IF EXISTS "Users can insert own favorites" ON user_favorites;
DROP POLICY IF EXISTS "Users can delete own favorites" ON user_favorites;
DROP POLICY IF EXISTS "Admins can read all favorites" ON user_favorites;

-- Users can read their own favorites
CREATE POLICY "Users can read own favorites" ON user_favorites
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own favorites
CREATE POLICY "Users can insert own favorites" ON user_favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own favorites
CREATE POLICY "Users can delete own favorites" ON user_favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Admins can read all favorites
CREATE POLICY "Admins can read all favorites" ON user_favorites
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- RLS POLICIES: USER_TOPIC_INTERESTS
-- ============================================================
DROP POLICY IF EXISTS "Users can read own interests" ON user_topic_interests;
DROP POLICY IF EXISTS "Users can insert own interests" ON user_topic_interests;
DROP POLICY IF EXISTS "Users can update own interests" ON user_topic_interests;
DROP POLICY IF EXISTS "Admins can read all interests" ON user_topic_interests;

-- Users can read their own interests
CREATE POLICY "Users can read own interests" ON user_topic_interests
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own interests
CREATE POLICY "Users can insert own interests" ON user_topic_interests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own interests
CREATE POLICY "Users can update own interests" ON user_topic_interests
  FOR UPDATE USING (auth.uid() = user_id);

-- Admins can read all interests
CREATE POLICY "Admins can read all interests" ON user_topic_interests
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT INSERT, SELECT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.legal_topics TO authenticated;
GRANT INSERT, SELECT, DELETE ON public.chat_messages TO authenticated;
GRANT INSERT, SELECT, UPDATE ON public.user_analytics TO authenticated;
GRANT INSERT, SELECT, DELETE ON public.user_favorites TO authenticated;
GRANT INSERT, SELECT, UPDATE ON public.user_topic_interests TO authenticated;

-- ============================================================
-- SEED DATA: Initial Legal Topics
-- ============================================================
INSERT INTO legal_topics (name, slug, description, order_index, color_hex) VALUES
  ('Criminal Law', 'criminal-law', 'Criminal law and procedures', 1, '#FF6B6B'),
  ('Civil Law', 'civil-law', 'Civil law and disputes', 2, '#4ECDC4'),
  ('Business Law', 'business-law', 'Business and commercial law', 3, '#45B7D1'),
  ('Human Rights', 'human-rights', 'Human rights and freedoms', 4, '#FFA07A'),
  ('Taxation Law', 'taxation-law', 'Tax laws and regulations', 5, '#98D8C8')
ON CONFLICT (slug) DO UPDATE 
SET 
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  order_index = EXCLUDED.order_index,
  color_hex = EXCLUDED.color_hex;

-- ============================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================
COMMENT ON TABLE profiles IS 'Extended user profiles beyond auth.users';
COMMENT ON TABLE legal_topics IS 'Legal topic categories (criminal, civil, business, etc.)';
COMMENT ON TABLE chat_messages IS 'Individual chat messages between users and AI assistant';
COMMENT ON TABLE user_analytics IS 'Daily learning analytics and progress tracking per user';
COMMENT ON TABLE user_favorites IS 'User favorites/bookmarks for articles and topics';
COMMENT ON TABLE user_topic_interests IS 'Tracks user interests in topics based on query patterns';

-- ============================================================
-- SUCCESS MESSAGE
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '✅✅✅ LegalEase Database Setup Complete! ✅✅✅';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Created Tables:';
  RAISE NOTICE '   ✅ profiles';
  RAISE NOTICE '   ✅ legal_topics';
  RAISE NOTICE '   ✅ chat_messages';
  RAISE NOTICE '   ✅ user_analytics';
  RAISE NOTICE '   ✅ user_favorites';
  RAISE NOTICE '   ✅ user_topic_interests';
  RAISE NOTICE '';
  RAISE NOTICE '🔐 Row Level Security (RLS) enabled on all tables';
  RAISE NOTICE '🔄 Auto-profile creation trigger enabled';
  RAISE NOTICE '🌱 Initial legal topics seeded';
  RAISE NOTICE '';
  RAISE NOTICE '✨ Setup complete! You can now use the app.';
END $$;


