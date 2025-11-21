-- Fix RLS policies for conversations and participants
-- Add missing policies for creating conversations and managing participants

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "Users can view conversations they participate in" ON public.conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON public.conversations;
DROP POLICY IF EXISTS "Users can update conversations they created" ON public.conversations;
DROP POLICY IF EXISTS "Users can delete conversations they created" ON public.conversations;
DROP POLICY IF EXISTS "Users can view conversations" ON public.conversations;

DROP POLICY IF EXISTS "Users can view participants in their conversations" ON public.participants;
DROP POLICY IF EXISTS "Users can insert participants" ON public.participants;
DROP POLICY IF EXISTS "Users can update participants" ON public.participants;
DROP POLICY IF EXISTS "Users can update participants" ON public.participants;
DROP POLICY IF EXISTS "Users can remove themselves from conversations" ON public.participants;
DROP POLICY IF EXISTS "Conversation creators can manage participants" ON public.participants;
DROP POLICY IF EXISTS "Users can add participants to conversations they created" ON public.participants;
DROP POLICY IF EXISTS "Users can add participants to conversations" ON public.participants;
DROP POLICY IF EXISTS "Users can view participants in conversations" ON public.participants;

DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages to their conversations" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can view messages in conversations" ON public.messages;

-- Recreate all policies with proper permissions

-- Create new policies with unique names to avoid conflicts

-- Conversations policies
CREATE POLICY "view_conversations_v2" ON public.conversations
  FOR SELECT USING (
    auth.role() = 'authenticated'
  );

CREATE POLICY "create_conversations_v2" ON public.conversations
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    created_by = auth.uid()
  );

CREATE POLICY "update_conversations_v2" ON public.conversations
  FOR UPDATE USING (
    auth.role() = 'authenticated' AND
    created_by = auth.uid()
  );

CREATE POLICY "delete_conversations_v2" ON public.conversations
  FOR DELETE USING (
    auth.role() = 'authenticated' AND
    created_by = auth.uid()
  );

-- Participants policies
CREATE POLICY "view_participants_v2" ON public.participants
  FOR SELECT USING (
    auth.role() = 'authenticated'
  );

CREATE POLICY "insert_participants_v2" ON public.participants
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
  );

CREATE POLICY "update_participants_v2" ON public.participants
  FOR UPDATE USING (
    auth.role() = 'authenticated' AND
    user_id = auth.uid()
  );

CREATE POLICY "delete_participants_v2" ON public.participants
  FOR DELETE USING (
    auth.role() = 'authenticated' AND
    user_id = auth.uid()
  );

CREATE POLICY "manage_participants_v2" ON public.participants
  FOR DELETE USING (
    auth.role() = 'authenticated' AND
    conversation_id IN (
      SELECT id FROM public.conversations
      WHERE created_by = auth.uid()
    )
  );

-- Messages policies
CREATE POLICY "view_messages_v2" ON public.messages
  FOR SELECT USING (
    auth.role() = 'authenticated'
  );

CREATE POLICY "insert_messages_v2" ON public.messages
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    sender_id = auth.uid()
  );

CREATE POLICY "update_messages_v2" ON public.messages
  FOR UPDATE USING (
    auth.role() = 'authenticated' AND
    sender_id = auth.uid()
  );

CREATE POLICY "delete_messages_v2" ON public.messages
  FOR DELETE USING (
    auth.role() = 'authenticated' AND
    sender_id = auth.uid()
  );
