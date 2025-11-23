-- ============================================================
-- Add Chat Sessions Table
-- ============================================================
-- This migration adds the chat_sessions table for managing multiple chat conversations

-- Create chat_sessions table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  title TEXT,
  language TEXT DEFAULT 'en' CHECK (language IN ('en', 'rw', 'fr')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for chat_sessions
DROP INDEX IF EXISTS idx_chat_sessions_user_id;
CREATE INDEX idx_chat_sessions_user_id ON chat_sessions(user_id);
DROP INDEX IF EXISTS idx_chat_sessions_updated_at;
CREATE INDEX idx_chat_sessions_updated_at ON chat_sessions(updated_at DESC);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_chat_sessions_updated_at ON chat_sessions;
CREATE TRIGGER update_chat_sessions_updated_at
  BEFORE UPDATE ON chat_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update foreign key in chat_messages to reference chat_sessions
-- First, drop the old constraint if it exists (if any)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'chat_messages_session_id_fkey'
  ) THEN
    ALTER TABLE chat_messages DROP CONSTRAINT chat_messages_session_id_fkey;
  END IF;
END $$;

-- Add foreign key constraint
ALTER TABLE chat_messages
  ADD CONSTRAINT chat_messages_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE;

-- Row Level Security (RLS) Policies
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own chat sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can create their own chat sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can update their own chat sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can delete their own chat sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can view all chat sessions" ON chat_sessions;

-- Users can view their own chat sessions
CREATE POLICY "Users can view their own chat sessions"
  ON chat_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own chat sessions
CREATE POLICY "Users can create their own chat sessions"
  ON chat_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own chat sessions
CREATE POLICY "Users can update their own chat sessions"
  ON chat_sessions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own chat sessions
CREATE POLICY "Users can delete their own chat sessions"
  ON chat_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can view all chat sessions (for support)
CREATE POLICY "Admins can view all chat sessions"
  ON chat_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

