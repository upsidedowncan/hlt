-- Function to find or create a conversation between two users
CREATE OR REPLACE FUNCTION find_or_create_conversation(
  p_user_id UUID,
  p_other_user_id UUID,
  p_conversation_name TEXT DEFAULT NULL
)
RETURNS TABLE(
  conversation_id UUID,
  conversation_name TEXT,
  conversation_avatar_url TEXT,
  is_group BOOLEAN,
  created BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id UUID;
  v_existing_conversation RECORD;
  v_other_user_avatar TEXT;
BEGIN
  -- Check if conversation already exists between these two users
  SELECT c.id, c.name, c.avatar_url, c.is_group
  INTO v_existing_conversation
  FROM conversations c
  WHERE c.is_group = false
    AND EXISTS (
      SELECT 1 FROM participants p1
      WHERE p1.conversation_id = c.id AND p1.user_id = p_user_id
    )
    AND EXISTS (
      SELECT 1 FROM participants p2
      WHERE p2.conversation_id = c.id AND p2.user_id = p_other_user_id
    )
  LIMIT 1;

  -- If conversation exists, return it
  IF v_existing_conversation.id IS NOT NULL THEN
    RETURN QUERY SELECT
      v_existing_conversation.id,
      v_existing_conversation.name,
      v_existing_conversation.avatar_url,
      v_existing_conversation.is_group,
      false::BOOLEAN as created;
    RETURN;
  END IF;

  -- Get other user's avatar
  SELECT avatar_url INTO v_other_user_avatar
  FROM users
  WHERE id = p_other_user_id;

  -- Create new conversation
  INSERT INTO conversations (name, avatar_url, is_group, created_by)
  VALUES (
    COALESCE(p_conversation_name, (SELECT display_name FROM users WHERE id = p_other_user_id)),
    v_other_user_avatar,
    false,
    p_user_id
  )
  RETURNING id INTO v_conversation_id;

  -- Add participants
  INSERT INTO participants (conversation_id, user_id)
  VALUES
    (v_conversation_id, p_user_id),
    (v_conversation_id, p_other_user_id);

  -- Return the new conversation
  RETURN QUERY SELECT
    v_conversation_id,
    COALESCE(p_conversation_name, (SELECT display_name FROM users WHERE id = p_other_user_id)),
    v_other_user_avatar,
    false::BOOLEAN as is_group,
    true::BOOLEAN as created;

END;
$$;