-- Create secure user search function
-- This function provides server-side user search functionality

CREATE OR REPLACE FUNCTION search_users(search_query TEXT)
RETURNS TABLE (
  id UUID,
  email TEXT,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT,
  is_online BOOLEAN,
  last_seen TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id,
    u.email,
    u.username,
    u.display_name,
    u.avatar_url,
    u.is_online,
    u.last_seen,
    u.created_at,
    u.updated_at
  FROM public.users u
  WHERE
    -- Exclude current user
    u.id != auth.uid()
    -- Search in username or display_name (case-insensitive)
    AND (
      u.username ILIKE '%' || search_query || '%' OR
      u.display_name ILIKE '%' || search_query || '%'
    )
    -- Ensure search query is not empty
    AND search_query != ''
  ORDER BY
    -- Prioritize exact matches, then prefix matches
    CASE
      WHEN lower(u.username) = lower(search_query) THEN 1
      WHEN lower(u.display_name) = lower(search_query) THEN 1
      WHEN lower(u.username) LIKE lower(search_query) || '%' THEN 2
      WHEN lower(u.display_name) LIKE lower(search_query) || '%' THEN 2
      ELSE 3
    END,
    -- Then by online status and last seen
    u.is_online DESC,
    u.last_seen DESC NULLS LAST,
    u.created_at DESC
  LIMIT 20;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION search_users(TEXT) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION search_users(TEXT) IS 'Securely search for users by username or display name, excluding the current user';