-- Migration: Add function to get conversation display info for specific users
-- This function returns the correct display name and avatar for a conversation
-- based on the current user viewing it (for direct messages)

CREATE OR REPLACE FUNCTION get_conversation_display_info(
  p_conversation_id UUID,
  p_current_user_id UUID
)
RETURNS TABLE(
  display_name TEXT,
  display_avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation RECORD;
  v_other_participant RECORD;
BEGIN
  -- Get conversation info
  SELECT c.name, c.avatar_url, c.is_group
  INTO v_conversation
  FROM conversations c
  WHERE c.id = p_conversation_id;

  -- If conversation not found, return null
  IF v_conversation IS NULL THEN
    RETURN QUERY SELECT NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  -- For group conversations, return stored name and avatar
  IF v_conversation.is_group THEN
    RETURN QUERY SELECT
      COALESCE(v_conversation.name, 'Group Chat'::TEXT),
      v_conversation.avatar_url;
    RETURN;
  END IF;

  -- For direct conversations, find the other participant
  SELECT u.display_name, u.username, u.email, u.avatar_url
  INTO v_other_participant
  FROM participants p
  JOIN users u ON p.user_id = u.id
  WHERE p.conversation_id = p_conversation_id
    AND p.user_id != p_current_user_id
  LIMIT 1;

  -- Return the other participant's info
  IF v_other_participant IS NOT NULL THEN
    RETURN QUERY SELECT
      COALESCE(v_other_participant.display_name, v_other_participant.username, v_other_participant.email, 'Unknown User'::TEXT),
      v_other_participant.avatar_url;
  ELSE
    -- Fallback if no other participant found
    RETURN QUERY SELECT 'Unknown User'::TEXT, NULL::TEXT;
  END IF;

END;
$$;