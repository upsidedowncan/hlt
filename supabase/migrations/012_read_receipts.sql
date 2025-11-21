-- Migration: Add read receipts functionality
-- Tracks when users have read messages

-- Create message_reads table for tracking read status
CREATE TABLE message_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure one read per user per message
  UNIQUE(message_id, user_id)
);

-- Add indexes for performance
CREATE INDEX idx_message_reads_message_id ON message_reads(message_id);
CREATE INDEX idx_message_reads_user_id ON message_reads(user_id);
CREATE INDEX idx_message_reads_read_at ON message_reads(read_at);

-- Add RLS policies
ALTER TABLE message_reads ENABLE ROW LEVEL SECURITY;

-- Users can only see read receipts for messages in conversations they're part of
CREATE POLICY "Users can view read receipts for messages in their conversations" ON message_reads
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM participants p
      JOIN messages m ON m.id = message_reads.message_id
      WHERE p.conversation_id = m.conversation_id
      AND p.user_id = auth.uid()
    )
  );

-- Users can only insert read receipts for themselves
CREATE POLICY "Users can insert their own read receipts" ON message_reads
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(
  p_conversation_id UUID,
  p_user_id UUID,
  p_last_read_message_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  messages_read_count INTEGER;
BEGIN
  -- If specific message ID provided, mark only that message
  IF p_last_read_message_id IS NOT NULL THEN
    INSERT INTO message_reads (message_id, user_id)
    VALUES (p_last_read_message_id, p_user_id)
    ON CONFLICT (message_id, user_id) DO NOTHING;

    -- Also mark all previous messages in the conversation as read
    INSERT INTO message_reads (message_id, user_id)
    SELECT m.id, p_user_id
    FROM messages m
    WHERE m.conversation_id = p_conversation_id
      AND m.created_at <= (
        SELECT created_at FROM messages WHERE id = p_last_read_message_id
      )
      AND NOT EXISTS (
        SELECT 1 FROM message_reads mr
        WHERE mr.message_id = m.id AND mr.user_id = p_user_id
      )
    ON CONFLICT (message_id, user_id) DO NOTHING;

    GET DIAGNOSTICS messages_read_count = ROW_COUNT;
    RETURN messages_read_count;
  END IF;

  -- Mark all unread messages in conversation as read
  INSERT INTO message_reads (message_id, user_id)
  SELECT m.id, p_user_id
  FROM messages m
  WHERE m.conversation_id = p_conversation_id
    AND m.sender_id != p_user_id  -- Don't mark own messages as read
    AND NOT EXISTS (
      SELECT 1 FROM message_reads mr
      WHERE mr.message_id = m.id AND mr.user_id = p_user_id
    )
  ON CONFLICT (message_id, user_id) DO NOTHING;

  GET DIAGNOSTICS messages_read_count = ROW_COUNT;
  RETURN messages_read_count;
END;
$$;